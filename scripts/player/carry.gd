class_name PlayerCarry
extends Node

signal feedback_requested(message: String)
signal tool_switch_requested

const PLAYER_ID := &"local"
const THROW_MASK := 1 | 4 | 8
const DISPOSAL_BAG_SCENE := preload("res://scenes/items/disposal_bag.tscn")
const FEEL := preload("res://data/feel/feel_tuning.tres")

var session: RunSession
var player: BeachPlayer
var interactor: PlayerInteractor
var hand_rig: HandRig
var camera: Camera3D
var movement: PlayerMovement
var _presentation_views: Dictionary = {}


func configure(
	run_session: RunSession,
	player_body: BeachPlayer,
	player_interactor: PlayerInteractor,
	rig: HandRig,
	view_camera: Camera3D,
	player_movement: PlayerMovement
) -> void:
	session = run_session
	player = player_body
	interactor = player_interactor
	hand_rig = rig
	camera = view_camera
	movement = player_movement
	if not interactor.primary_requested.is_connected(_on_primary_requested):
		interactor.primary_requested.connect(_on_primary_requested)
		interactor.interact_requested.connect(_on_interact_requested)
		interactor.throw_requested.connect(_on_throw_requested)
	if not session.items_changed.is_connected(_on_bag_items_changed):
		session.items_changed.connect(_on_bag_items_changed)
	refresh_hand_visuals()
	_on_bag_items_changed(PackedStringArray())


func cycle_selected(step: int = 1) -> void:
	var player_record := _player_record()
	var held := player_record[&"held_objects"] as Array[Dictionary]
	if held.size() < 2:
		return
	var selected := int(player_record.get("selected_held_index", 0))
	player_record[&"selected_held_index"] = posmod(selected + step, held.size())
	session.finalize_action(PackedStringArray(), PackedStringArray([str(PLAYER_ID)]))
	hand_rig.mark_selected(int(player_record.get("selected_held_index", 0)), FeelMotion.reduced(player.settings_store))


func selected_held_item() -> StringName:
	var player_record := _player_record()
	var held := player_record[&"held_objects"] as Array[Dictionary]
	var selected := int(player_record.get("selected_held_index", -1))
	if selected < 0 or selected >= held.size():
		return StringName()
	return StringName(str(held[selected].get("id", "")))


func request_tool_switch() -> bool:
	if not (_player_record()[&"held_objects"] as Array).is_empty():
		feedback_requested.emit("Place or throw the carried object first")
		return false
	tool_switch_requested.emit()
	return true


func release_all_items(world_transforms: Dictionary) -> ActionResult:
	var result := session.item_store.try_release_all_items(PLAYER_ID, world_transforms)
	if result.ok:
		for item_id_text in result.changed_ids:
			_cancel_presentation(StringName(item_id_text))
		refresh_hand_visuals()
	return result


func cancel_all_presentations() -> void:
	for item_id in _presentation_views.keys():
		_cancel_presentation(StringName(str(item_id)))


func refresh_hand_visuals() -> void:
	if session == null:
		return
	var held := _player_record()[&"held_objects"] as Array[Dictionary]
	hand_rig.clear_carry_visuals()
	if held.is_empty():
		hand_rig.show_bag(true)
		movement.set_carry_speed_multiplier(1.0)
		return
	hand_rig.show_bag(false)
	hand_rig.clear_tool()
	var visible_refs: Array[Dictionary] = []
	var has_large := false
	for object_ref in held:
		var object_id := StringName(str(object_ref.get("id", "")))
		var definition := _definition_for_item(object_id) if str(object_ref.get("kind", "")) == "item" else null
		has_large = has_large or (definition != null and definition.hand_cost == 2)
		if _presentation_views.has(object_id):
			continue
		visible_refs.append(object_ref)
	if has_large and not visible_refs.is_empty():
		var large_id := StringName(str(visible_refs[0].get("id", "")))
		var large_definition := _definition_for_item(large_id)
		var large_visual := hand_rig.set_large_prop_scene(large_definition.visual_scene())
		_scale_hand_visual(large_visual, large_definition)
		_attach_dirt_visuals(large_visual, large_id, large_definition)
	else:
		var left_ref := visible_refs[0] if visible_refs.size() > 0 else {}
		var right_ref := visible_refs[1] if visible_refs.size() > 1 else {}
		var visuals := hand_rig.set_small_prop_scenes(
			_scene_for_ref(left_ref),
			_scene_for_ref(right_ref)
		)
		_style_hand_visual(visuals[0], left_ref)
		_style_hand_visual(visuals[1], right_ref)
		hand_rig.mark_selected(int(_player_record().get("selected_held_index", 0)), FeelMotion.reduced(player.settings_store))
	movement.set_carry_speed_multiplier(0.8 if has_large else 1.0)


## Presentation of an item already committed to the bag. `source` picks the path: the stick
## stabs and flicks it in over the stick tip, the vacuum pulls it into the nozzle, and other
## sources (hand, sand cleaner) arc it straight into the bag mouth.
func present_collected(item_id: StringName, source: StringName = &"stick", delay := 0.0) -> void:
	var manager := _view_manager()
	var view := manager.take_view_for_presentation(item_id) if manager != null else null
	if view == null:
		return
	var reduced := FeelMotion.reduced(player.settings_store)
	manager.feel_puff(view.global_position, reduced)
	_prune_presentations()
	if _presentation_views.size() >= 12 or reduced:
		view.queue_free()
		return
	_presentation_views[item_id] = view
	var distance := view.global_position.distance_to(hand_rig.bag_socket.global_position)
	var seconds := FeelMotion.travel_seconds(distance, FEEL.bag_travel_base, FEEL.bag_travel_per_meter, FEEL.bag_travel_max)
	var destination: Node3D = hand_rig.bag_socket
	var options := {
		"delay": delay, "end_local": Transform3D(Basis.IDENTITY, _socket_end(hand_rig.bag_socket)),
		"spin_axis": FeelMotion.cosmetic_axis(item_id), "shrink_from": FEEL.bag_shrink_from,
	}
	var shrink := true
	match source:
		&"stick":
			options.merge({"yoink_seconds": FEEL.yoink_seconds, "via": hand_rig.tool_tip(), "via_anchor": hand_rig.tool_socket,
				"via_fraction": FEEL.stick_tip_fraction, "arc": FEEL.bag_arc_height, "spin_turns": FEEL.bag_spin_turns}, true)
		&"vacuum":
			# Into the visible nozzle; the socket is unscaled, so the tip is given in its space.
			destination = hand_rig.tool_socket
			seconds = FEEL.vacuum_travel_seconds
			shrink = false
			var nozzle := hand_rig.tool_socket.global_transform.affine_inverse() * hand_rig.tool_tip().global_position
			options.merge({"ease": &"in", "stretch": FEEL.vacuum_stretch, "shrink_from": 0.4, "end_local": Transform3D(Basis.IDENTITY, nozzle)}, true)
		_:
			options.merge({"yoink_seconds": FEEL.yoink_seconds * 0.7, "arc": FEEL.bag_arc_height, "spin_turns": FEEL.bag_spin_turns * 0.5}, true)
	view.travel_to(destination, seconds, shrink, func() -> void:
		_presentation_views.erase(item_id)
		if is_instance_valid(view):
			view.queue_free()
		if source == &"vacuum":
			hand_rig.bag_catch(0.35)
		else:
			player.play_cue(&"bag_catch", {"strength": 1.0})
	, options)


## Animates a temporary visual from `from_global` into `destination` (hand socket or bag socket).
## `on_arrival` runs after the visual is freed (the knife uses it for the bag catch of cut
## attachments); without it the hands refresh so the held visual appears as this one lands.
func present_visual(item_id: StringName, visual: Node3D, from_global: Transform3D, destination: Node3D, end_scale: float, on_arrival := Callable()) -> void:
	_prune_presentations()
	_cancel_presentation(item_id)
	var reduced := FeelMotion.reduced(player.settings_store)
	destination.add_child(visual)
	visual.global_transform = from_global
	_presentation_views[item_id] = visual
	var t := FeelMotion.tween(visual)
	if not reduced:
		var up_local := (destination.global_basis.orthonormalized().inverse() * Vector3.UP).normalized()
		t.tween_property(visual, "position", visual.position + up_local * FEEL.remove_lift, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var end := Transform3D(Basis.IDENTITY, _socket_end(destination)) if destination is Marker3D else Transform3D.IDENTITY
	var arrived := func() -> void:
		_presentation_views.erase(item_id)
		if is_instance_valid(visual):
			visual.queue_free()
		if on_arrival.is_valid():
			on_arrival.call()
		else:
			refresh_hand_visuals()
	FeelMotion.travel(visual, destination, end, FEEL.prop_travel_seconds, {"arc": 0.0 if reduced else FEEL.prop_arc_height, "shrink_to": end_scale, "shrink_from": 0.2}, arrived, t)


## Where a presentation should land in `socket`'s space: the visible bag mouth, or the visible
## hand for the prop sockets (they carry the view-model FOV correction and motion).
func _socket_end(socket: Marker3D) -> Vector3:
	if socket == hand_rig.bag_socket:
		return hand_rig.visual_parent(socket).transform * FEEL.bag_mouth
	return hand_rig.view_offset(socket)


func _prune_presentations() -> void:
	for key in _presentation_views.keys():
		if not is_instance_valid(_presentation_views[key]):
			_presentation_views.erase(key)


## Presentation only: the bag in hand swells with its fill level.
func _on_bag_items_changed(_ids: PackedStringArray) -> void:
	if session == null or not session.state.players.has(PLAYER_ID):
		return
	var record := _player_record()
	var capacity := maxi(int(record.get("bag_capacity", 20)), 1)
	hand_rig.set_bag_fill(float((record.trash_bag as Array).size() + (record.valuable_bag as Array).size()) / float(capacity))


func _on_primary_requested(target: Dictionary) -> void:
	var actions := target.get("actions", PackedStringArray()) as PackedStringArray
	if actions.has("collect"):
		_collect_target(target)
	elif actions.has("hold"):
		_hold_target(target)
	elif actions.has("hold_bag"):
		_hold_bag_target(target)


func _on_interact_requested(target: Dictionary) -> void:
	if (target.get("actions", PackedStringArray()) as PackedStringArray).has("carry_dirty"):
		_hold_target(target)


func _on_throw_requested() -> void:
	var object_ref := session.item_store.peek_throw_ref(PLAYER_ID)
	if object_ref.is_empty():
		feedback_requested.emit("Nothing to throw")
		player.play_cue(&"rejected", {"reason": "Nothing to throw"})
		return
	var object_id := StringName(str(object_ref.get("id", "")))
	var is_bag := str(object_ref.get("kind", "")) == "bag"
	var definition := _definition_for_item(object_id) if not is_bag else null
	var forward := -camera.global_basis.z.normalized()
	var spawn_origin := camera.global_position + forward * 1.0 - Vector3.UP * 0.28
	var spawn_transform := Transform3D(Basis.IDENTITY, spawn_origin)
	if not _throw_spawn_is_clear(Vector3(0.46, 0.5, 0.32) if is_bag else WorldItem.profile_size(definition.collision_profile), spawn_transform):
		feedback_requested.emit("Not enough room to throw")
		player.play_cue(&"rejected", {"reason": "Not enough room to throw"})
		return
	# Which hand throws: held objects are in pickup order and slot 0 is the left hand; items
	# thrown back out of the bag leave from the bag hand.
	var held := _player_record()[&"held_objects"] as Array
	var arm := &"left"
	if not held.is_empty():
		var last_index := held.size() - 1
		var last_definition := _definition_for_item(StringName(str((held[last_index] as Dictionary).get("id", ""))))
		arm = &"both" if last_definition != null and last_definition.hand_cost == 2 else (&"right" if last_index == 1 else &"left")
	var launch_velocity := forward * (5.5 if definition != null and definition.hand_cost == 2 else 8.0) + Vector3.UP * 1.2
	var result := session.item_store.try_throw(PLAYER_ID, spawn_transform, launch_velocity, true)
	if not result.ok:
		feedback_requested.emit(result.message)
		player.play_cue(&"rejected", {"reason": result.message})
		return
	player.play_cue(&"throw", {"arm": arm})
	_cancel_presentation(object_id)
	refresh_hand_visuals()
	if not is_bag:
		var manager := _view_manager()
		if manager != null:
			var thrown := manager.restore_world_view(object_id)
			if thrown != null:
				# The record already holds the launch velocity; Jolt drops a velocity set while the
				# body is still frozen, so apply it again now that the view is active.
				thrown.linear_velocity = (session.state.items[object_id] as ItemRecord).linear_velocity
				thrown.arm_impact()
				if definition.collision_profile == ItemDefinition.CollisionProfile.SMALL and FEEL.throw_spin > 0.0:
					# A forward tumble: rotation only, the launch velocity is unchanged.
					thrown.angular_velocity = -camera.global_basis.x * FEEL.throw_spin
	interactor.clear_target()


func _hold_bag_target(target: Dictionary) -> void:
	var bag_id := StringName(str(target.id))
	var from := (target.collider as Node3D).global_transform if target.get("collider") is Node3D else Transform3D.IDENTITY
	var result := session.item_store.try_hold_bag(PLAYER_ID, bag_id, _target_context(target))
	if not result.ok:
		feedback_requested.emit(result.message)
		player.play_cue(&"rejected", {"reason": result.message})
		return
	interactor.clear_target()
	present_bag(bag_id, from)
	player.play_cue(&"hold_bag")
	refresh_hand_visuals()


## A copy of the sealed bag travels from where it was taken into the next free hand.
func present_bag(bag_id: StringName, from: Transform3D) -> void:
	if not session.state.bag_records.has(bag_id) or from == Transform3D.IDENTITY:
		return
	var copy := DISPOSAL_BAG_SCENE.instantiate() as DisposalBag
	present_visual(bag_id, copy, from, next_small_socket(), 0.55)
	copy.configure(session.state.bag_records[bag_id] as Dictionary, Callable(), true)


func _collect_target(target: Dictionary) -> void:
	var item_id := StringName(str(target.id))
	var result := session.item_store.try_collect(PLAYER_ID, item_id, _target_context(target))
	if not result.ok:
		feedback_requested.emit(result.message)
		player.play_cue(&"rejected", {"reason": result.message})
		return
	interactor.clear_target()
	var with_stick := hand_rig.active_tool_id() == &"stick"
	player.play_cue(&"poke" if with_stick else &"hold", {"item_id": str(item_id)})
	present_collected(item_id, &"stick" if with_stick else &"hand")


func _hold_target(target: Dictionary) -> void:
	var item_id := StringName(str(target.id))
	var result := session.item_store.try_hold(PLAYER_ID, item_id, _target_context(target))
	if not result.ok:
		feedback_requested.emit(result.message)
		player.play_cue(&"rejected", {"reason": result.message})
		return
	interactor.clear_target()
	if str(result.receipt.get("source", "")) == "slot":
		# Taken off a placement slot: PlacementService presents that pickup and sends its cue.
		return
	var definition := _definition_for_item(item_id)
	var large := definition.hand_cost == 2
	player.play_cue(&"hold", {"large": large})
	var manager := _view_manager()
	var view := manager.take_view_for_presentation(item_id) if manager != null else null
	if view == null:
		refresh_hand_visuals()
		return
	var reduced := FeelMotion.reduced(player.settings_store)
	manager.feel_puff(view.global_position, reduced)
	var destination := hand_rig.large_prop_socket if large else next_small_socket()
	_presentation_views[item_id] = view
	# Stow the bag and tool and apply the carry speed now; the flying view is skipped until it lands.
	refresh_hand_visuals()
	view.travel_to(destination, FEEL.prop_travel_seconds, false, func() -> void:
		_presentation_views.erase(item_id)
		if is_instance_valid(view):
			view.queue_free()
		refresh_hand_visuals()
		if hand_rig.animator != null:
			hand_rig.animator.play(&"catch", &"both" if large else (&"left" if destination == hand_rig.left_prop_socket else &"right"), 0.8)
	, {
		"reduced": reduced, "yoink_seconds": FEEL.prop_yoink_seconds, "yoink_height": FEEL.prop_yoink_height,
		"yoink_scale": 1.05, "wiggle_degrees": FEEL.prop_wiggle_degrees, "arc": FEEL.prop_arc_height,
		"end_scale": 0.4 if large else 0.35, "shrink_from": 0.2,
		"end_local": Transform3D(Basis.IDENTITY, _socket_end(destination)),
	})


func _target_context(target: Dictionary) -> Dictionary:
	return {
		"target_id": str(target.id),
		"visible": true,
		"distance": float(target.distance),
		"reach": interactor.reach,
	}


func _throw_spawn_is_clear(size: Vector3, spawn_transform: Transform3D) -> bool:
	var space := camera.get_world_3d().direct_space_state
	var excluded: Array[RID] = [player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, spawn_transform.origin, THROW_MASK, excluded)
	if not space.intersect_ray(ray).is_empty():
		return false
	var shape := BoxShape3D.new()
	shape.size = size
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(spawn_transform.basis, spawn_transform.origin + Vector3.UP * size.y * 0.5)
	shape_query.collision_mask = THROW_MASK
	shape_query.exclude = excluded
	return space.intersect_shape(shape_query, 1).is_empty()


func next_small_socket() -> Marker3D:
	var held_count := (_player_record()[&"held_objects"] as Array).size()
	return hand_rig.left_prop_socket if held_count <= 1 else hand_rig.right_prop_socket


## Ends an in-flight presentation at once; the committed location is what the game shows.
func cancel_presentation(item_id: StringName) -> void:
	_cancel_presentation(item_id)


func _cancel_presentation(item_id: StringName) -> void:
	if not _presentation_views.has(item_id):
		return
	var view: Variant = _presentation_views[item_id]
	_presentation_views.erase(item_id)
	if not is_instance_valid(view):
		return
	if view is WorldItem:
		(view as WorldItem).cancel_travel()
	else:
		(view as Node).queue_free()


func _definition_for_item(item_id: StringName) -> ItemDefinition:
	if not session.state.items.has(item_id):
		return null
	var definition_id := (session.state.items[item_id] as ItemRecord).definition_id
	return session.definitions.get(definition_id) as ItemDefinition


func _player_record() -> Dictionary:
	return session.state.players[PLAYER_ID] as Dictionary


func _view_manager() -> ItemViewManager:
	return session.item_view_manager


func _scale_hand_visual(node: Node3D, definition: ItemDefinition) -> void:
	if node == null:
		return
	var scale_value := 0.4 if definition.hand_cost == 2 else 0.35
	node.scale = Vector3.ONE * scale_value


func _attach_dirt_visuals(node: Node3D, item_id: StringName, definition: ItemDefinition) -> void:
	if node == null or not session.state.items.has(item_id):
		return
	DirtVisual.attach_remaining(node, session.state.items[item_id] as ItemRecord, definition, false)


func _scene_for_ref(object_ref: Dictionary) -> PackedScene:
	if object_ref.is_empty():
		return null
	if str(object_ref.get("kind", "")) == "bag":
		return DISPOSAL_BAG_SCENE
	var definition := _definition_for_item(StringName(str(object_ref.get("id", ""))))
	return definition.visual_scene() if definition != null else null


func _style_hand_visual(node: Node3D, object_ref: Dictionary) -> void:
	if node == null or object_ref.is_empty():
		return
	var object_id := StringName(str(object_ref.get("id", "")))
	if str(object_ref.get("kind", "")) == "bag":
		(node as DisposalBag).configure(session.state.bag_records[object_id] as Dictionary, Callable(), true)
		node.scale = Vector3.ONE * 0.55
		return
	var definition := _definition_for_item(object_id)
	_scale_hand_visual(node, definition)
	_attach_dirt_visuals(node, object_id, definition)
