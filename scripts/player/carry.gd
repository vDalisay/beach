class_name PlayerCarry
extends Node

signal feedback_requested(message: String)
signal tool_switch_requested

const PLAYER_ID := &"local"
const THROW_MASK := 1 | 4 | 8
const DISPOSAL_BAG_SCENE := preload("res://scenes/items/disposal_bag.tscn")

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
	refresh_hand_visuals()


func cycle_selected(step: int = 1) -> void:
	var player_record := _player_record()
	var held := player_record[&"held_objects"] as Array[Dictionary]
	if held.size() < 2:
		return
	var selected := int(player_record.get("selected_held_index", 0))
	player_record[&"selected_held_index"] = posmod(selected + step, held.size())
	session.finalize_action(PackedStringArray(), PackedStringArray([str(PLAYER_ID)]))


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
	movement.set_carry_speed_multiplier(0.8 if has_large else 1.0)


func present_collected(item_id: StringName) -> void:
	var manager := _view_manager()
	var view := manager.take_view_for_presentation(item_id) if manager != null else null
	if view == null:
		return
	if _presentation_views.size() >= 12 or (player.settings_store != null and bool(player.settings_store.get_value(&"reduced_motion"))):
		view.queue_free()
		return
	_presentation_views[item_id] = view
	view.travel_to(hand_rig.bag_socket, 0.22, true, func() -> void:
		_presentation_views.erase(item_id)
		if is_instance_valid(view):
			view.queue_free()
	, hand_rig.view_offset(hand_rig.bag_socket))


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
		return
	var object_id := StringName(str(object_ref.get("id", "")))
	var is_bag := str(object_ref.get("kind", "")) == "bag"
	var definition := _definition_for_item(object_id) if not is_bag else null
	var forward := -camera.global_basis.z.normalized()
	var spawn_origin := camera.global_position + forward * 1.0 - Vector3.UP * 0.28
	var spawn_transform := Transform3D(Basis.IDENTITY, spawn_origin)
	if not _throw_spawn_is_clear(Vector3(0.46, 0.5, 0.32) if is_bag else WorldItem.profile_size(definition.collision_profile), spawn_transform):
		feedback_requested.emit("Not enough room to throw")
		return
	var launch_velocity := forward * (5.5 if definition != null and definition.hand_cost == 2 else 8.0) + Vector3.UP * 1.2
	var result := session.item_store.try_throw(PLAYER_ID, spawn_transform, launch_velocity, true)
	if not result.ok:
		feedback_requested.emit(result.message)
		return
	_cancel_presentation(object_id)
	refresh_hand_visuals()
	if not is_bag:
		var manager := _view_manager()
		if manager != null:
			manager.restore_world_view(object_id)
	interactor.clear_target()


func _hold_bag_target(target: Dictionary) -> void:
	var bag_id := StringName(str(target.id))
	var result := session.item_store.try_hold_bag(PLAYER_ID, bag_id, _target_context(target))
	if not result.ok:
		feedback_requested.emit(result.message)
		return
	interactor.clear_target()
	refresh_hand_visuals()


func _collect_target(target: Dictionary) -> void:
	var item_id := StringName(str(target.id))
	var result := session.item_store.try_collect(PLAYER_ID, item_id, _target_context(target))
	if not result.ok:
		feedback_requested.emit(result.message)
		return
	interactor.clear_target()
	present_collected(item_id)


func _hold_target(target: Dictionary) -> void:
	var item_id := StringName(str(target.id))
	var result := session.item_store.try_hold(PLAYER_ID, item_id, _target_context(target))
	if not result.ok:
		feedback_requested.emit(result.message)
		return
	interactor.clear_target()
	hand_rig.show_bag(false)
	hand_rig.clear_tool()
	var definition := _definition_for_item(item_id)
	var manager := _view_manager()
	var view := manager.take_view_for_presentation(item_id) if manager != null else null
	if view == null:
		refresh_hand_visuals()
		return
	var destination := hand_rig.large_prop_socket if definition.hand_cost == 2 else _next_small_socket()
	_presentation_views[item_id] = view
	view.travel_to(destination, 0.24, false, func() -> void:
		_presentation_views.erase(item_id)
		if is_instance_valid(view):
			view.queue_free()
		refresh_hand_visuals()
	, hand_rig.view_offset(destination))


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


func _next_small_socket() -> Marker3D:
	var held_count := (_player_record()[&"held_objects"] as Array).size()
	return hand_rig.left_prop_socket if held_count <= 1 else hand_rig.right_prop_socket


func _cancel_presentation(item_id: StringName) -> void:
	if not _presentation_views.has(item_id):
		return
	var view: Variant = _presentation_views[item_id]
	_presentation_views.erase(item_id)
	if is_instance_valid(view):
		(view as WorldItem).cancel_travel()


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
