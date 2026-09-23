class_name SwimService
extends Node3D

signal faint_completed(receipt: Dictionary)

const PLAYER_ID := &"local"
const GOLDEN_ANGLE := 2.399963229728653
const UNDERWATER_ENVIRONMENT := preload("res://scenes/world/underwater_environment.tres")

var session: RunSession
var player: BeachPlayer
var water: WaterVolume
var meter: Control
var fade: ColorRect
var recovery_anchors: Dictionary
var _air_label: Label
var _air_bar: ProgressBar
var _air_hint: Label
var _above_seconds := 0.0
var _recovering := false
var _markers: Dictionary = {}


func configure(run_session: RunSession, player_body: BeachPlayer, water_volume: WaterVolume, oxygen_meter: Control, faint_fade: ColorRect, anchors: Dictionary) -> void:
	session = run_session
	player = player_body
	water = water_volume
	meter = oxygen_meter
	fade = faint_fade
	recovery_anchors = anchors
	_air_label = meter.get_node("Panel/Content/AirLabel") as Label
	_air_bar = meter.get_node("Panel/Content/AirBar") as ProgressBar
	_air_hint = meter.get_node("Panel/Content/Hint") as Label
	fade.process_mode = Node.PROCESS_MODE_ALWAYS
	fade.hide()
	meter.hide()
	session.save_requested.connect(_on_state_saved)
	_refresh_markers()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if get_tree().paused or _recovering or not player.input_enabled:
		return
	step_environment(delta)


func step_environment(delta: float) -> void:
	var record := session.state.players[PLAYER_ID] as Dictionary
	var swimming := water.should_swim(player.global_position)
	if swimming != player.movement.is_swimming:
		if swimming:
			player.enter_swimming()
		else:
			player.exit_swimming()
	var submerged := water.head_submerged(player.camera.global_position, bool(record.immersed))
	record.immersed = submerged
	player.camera.environment = UNDERWATER_ENVIRONMENT if submerged else null
	var maximum := session.progression.max_air_seconds(PLAYER_ID)
	if submerged and is_finite(maximum):
		_above_seconds = 0.0
		record.air_remaining = maxf(0.0, float(record.air_remaining) - delta)
		if float(record.air_remaining) <= 0.0:
			try_faint()
	elif not submerged:
		_above_seconds += delta
		if _above_seconds >= 1.0:
			record.air_remaining = 60.0 if not is_finite(maximum) else maximum
	_update_meter(record, maximum, swimming)


func try_faint() -> ActionResult:
	if _recovering:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Already recovering")
	if session.is_publishing():
		return ActionResult.rejected(ActionResult.Reason.DEFERRED, "Faint waits for the current action")
	var player_record := session.state.players[PLAYER_ID] as Dictionary
	if not bool(player_record.immersed) or float(player_record.air_remaining) > 0.0:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Player still has air")
	var state_errors := session.state.validate_invariants(session.definitions)
	if not state_errors.is_empty():
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, state_errors[0])
	var plan := _build_drop_plan(player_record)
	if not bool(plan.get("ok", false)):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, str(plan.get("error", "No safe recovery plan")))
	_recovering = true
	player.set_input_enabled(false)
	fade.color.a = 0.0
	fade.show()
	await fade.create_tween().tween_property(fade, "color:a", 1.0, 0.2).finished
	var receipt := _commit_faint(player_record, plan)
	await fade.create_tween().tween_property(fade, "color:a", 0.0, 0.35).finished
	fade.hide()
	player.set_input_enabled(true)
	_recovering = false
	faint_completed.emit(receipt)
	return ActionResult.accepted(PackedStringArray(), receipt)


func _build_drop_plan(player_record: Dictionary) -> Dictionary:
	var refs: Array[Dictionary] = []
	for item_id in player_record.bag_order as Array[StringName]:
		refs.append({"kind": "item", "id": item_id, "location": ItemRecord.Location.BAG, "expected_kind": ItemDefinition.Kind.WASTE if item_id in (player_record.trash_bag as Array) else ItemDefinition.Kind.VALUABLE})
	for held_value in player_record.held_objects as Array[Dictionary]:
		var held := held_value as Dictionary
		refs.append({"kind": str(held.get("kind", "")), "id": StringName(str(held.get("id", ""))), "location": ItemRecord.Location.HELD, "expected_kind": ItemDefinition.Kind.PROP})
	var seen := {}
	for ref in refs:
		var object_id := ref.id as StringName
		if object_id.is_empty() or seen.has(object_id):
			return {"error": "Duplicate or empty carried reference"}
		seen[object_id] = true
		if ref.kind == "item":
			if not session.state.items.has(object_id):
				return {"error": "Missing carried item %s" % object_id}
			var item := session.state.items[object_id] as ItemRecord
			if item.location != int(ref.location) or item.holder_id != PLAYER_ID or not session.definitions.has(item.definition_id) or (session.definitions[item.definition_id] as ItemDefinition).kind != int(ref.expected_kind):
				return {"error": "Carried item owner disagrees: %s" % object_id}
		elif ref.kind == "bag":
			var bag := session.state.bag_records.get(object_id, {}) as Dictionary
			if bag.is_empty() or str(bag.get("location", "")) != "HELD" or StringName(str(bag.get("holder_id", ""))) != PLAYER_ID or not bool(bag.get("sealed", false)):
				return {"error": "Carried sealed bag disagrees: %s" % object_id}
		else:
			return {"error": "Invalid carried object kind"}
	var anchor := _nearest_dry_anchor(player.global_position)
	if anchor.is_empty():
		return {"error": "No safe dry recovery anchor"}
	var transforms := {}
	var planned: Array[Dictionary] = []
	var drop_center := water.clamp_inside(player.global_position, 8.0)
	for ref in refs:
		var object_id := ref.id as StringName
		var size := Vector3(0.46, 0.5, 0.32) if ref.kind == "bag" else WorldItem.profile_size((session.definitions[(session.state.items[object_id] as ItemRecord).definition_id] as ItemDefinition).collision_profile)
		var pose := _find_drop_pose(drop_center, size, planned)
		if pose == Transform3D.IDENTITY:
			return {"error": "No clear underwater drop pose for %s" % object_id}
		transforms[object_id] = pose
		planned.append({"position": pose.origin, "radius": maxf(size.x, size.z) * 0.5})
	return {"ok": true, "refs": refs, "transforms": transforms, "anchor": anchor, "origin": drop_center}


func _find_drop_pose(origin: Vector3, size: Vector3, planned: Array[Dictionary]) -> Transform3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 4 | 8
	query.exclude = [player.get_rid()]
	for attempt in range(700):
		var radius := 0.58 * sqrt(float(attempt))
		var angle := float(attempt) * GOLDEN_ANGLE
		var point := origin + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		if not water.contains_horizontal(point):
			continue
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 10.0, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or not (hit.collider as Node).is_in_group("sand_surfaces") or float((hit.position as Vector3).y) >= water.surface_y - 0.25:
			continue
		point = (hit.position as Vector3) + Vector3.UP * 0.06
		if session.item_view_manager.recovery_bounds.is_outside(point):
			continue
		var clear := true
		for prior in planned:
			var other := prior.position as Vector3
			if Vector2(point.x - other.x, point.z - other.z).length() < maxf(size.x, size.z) * 0.5 + float(prior.radius) + 0.08:
				clear = false
				break
		if not clear:
			continue
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * size.y * 0.5)
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return Transform3D(Basis.IDENTITY, point)
	return Transform3D.IDENTITY


func _nearest_dry_anchor(origin: Vector3) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for anchor_id in recovery_anchors:
		var position := recovery_anchors[anchor_id] as Vector3
		if water.contains_horizontal(position) or session.item_view_manager.recovery_bounds.is_outside(position):
			continue
		candidates.append({"id": str(anchor_id), "position": position})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_distance := (a.position as Vector3).distance_squared_to(origin)
		var b_distance := (b.position as Vector3).distance_squared_to(origin)
		return str(a.id) < str(b.id) if is_equal_approx(a_distance, b_distance) else a_distance < b_distance
	)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 4 | 8
	query.exclude = [player.get_rid()]
	for candidate in candidates:
		query.transform = Transform3D(Basis.IDENTITY, (candidate.position as Vector3) + Vector3.UP * 0.92)
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return {}


func _commit_faint(player_record: Dictionary, plan: Dictionary) -> Dictionary:
	var item_ids: Array[String] = []
	var bag_ids: Array[String] = []
	var transforms := plan.transforms as Dictionary
	player.carry.cancel_all_presentations()
	for ref in plan.refs as Array[Dictionary]:
		var object_id := ref.id as StringName
		var pose := transforms[object_id] as Transform3D
		if ref.kind == "bag":
			var bag := session.state.bag_records[object_id] as Dictionary
			bag.location = "WORLD"
			bag.holder_id = &""
			bag.container_id = &""
			bag.rack_slot = -1
			bag.world_transform = ItemRecord._transform_to_array(pose)
			bag.linear_velocity = ItemRecord._vector_to_array(Vector3.ZERO)
			bag.angular_velocity = ItemRecord._vector_to_array(Vector3.ZERO)
			bag.sleeping = false
			bag_ids.append(str(object_id))
		else:
			var item := session.state.items[object_id] as ItemRecord
			item.location = ItemRecord.Location.WORLD
			item.holder_id = &""
			item.container_id = &""
			item.slot_id = &""
			item.last_world_transform = pose
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO
			item.sleeping = false
			item_ids.append(str(object_id))
	player_record.trash_bag = [] as Array[StringName]
	player_record.valuable_bag = [] as Array[StringName]
	player_record.bag_order = [] as Array[StringName]
	if session.state.faint_count >= 0:
		session.state.faint_count += 1
	player_record.held_objects = [] as Array[Dictionary]
	player_record.selected_held_index = -1
	var pile_id := StringName("recovery:%06d" % session.state.next_recovery_serial)
	session.state.next_recovery_serial += 1
	if not item_ids.is_empty() or not bag_ids.is_empty():
		session.state.recovery_piles[pile_id] = {"origin": ItemRecord._vector_to_array(plan.origin as Vector3), "item_ids": item_ids, "bag_ids": bag_ids}
	var anchor := plan.anchor as Dictionary
	var anchor_position := anchor.position as Vector3
	player.global_position = anchor_position
	player.velocity = Vector3.ZERO
	player.exit_swimming()
	player_record.transform = player.global_transform
	player_record.velocity = Vector3.ZERO
	player_record.air_remaining = 60.0 if not is_finite(session.progression.max_air_seconds(PLAYER_ID)) else session.progression.max_air_seconds(PLAYER_ID)
	player_record.immersed = false
	player_record.fainted = false
	_above_seconds = 0.0
	var receipt := {"pile_id": str(pile_id) if not item_ids.is_empty() or not bag_ids.is_empty() else "", "item_ids": item_ids, "bag_ids": bag_ids, "anchor_id": str(anchor.id), "air_restored": float(player_record.air_remaining)}
	session.finalize_action(PackedStringArray(item_ids), PackedStringArray([str(PLAYER_ID)]), PackedStringArray(), PackedStringArray(bag_ids))
	player.carry.refresh_hand_visuals()
	_update_meter(player_record, session.progression.max_air_seconds(PLAYER_ID), false)
	return receipt


func _update_meter(record: Dictionary, maximum: float, swimming: bool) -> void:
	var air := float(record.air_remaining)
	meter.visible = swimming or bool(record.immersed) or (is_finite(maximum) and air < maximum - 0.01)
	if not meter.visible:
		return
	_air_label.text = "AIR  ∞" if not is_finite(maximum) else "AIR  %.1f s" % air
	_air_bar.value = 100.0 if not is_finite(maximum) else 100.0 * air / maxf(maximum, 0.01)
	_air_hint.text = "SURFACE NOW" if is_finite(maximum) and air <= 3.0 else "Jump: rise  •  Crouch: dive"
	_air_label.add_theme_color_override("font_color", Color("ff695d") if is_finite(maximum) and air <= 3.0 else Color("bcebf2"))


func _on_state_saved(_revision: int) -> void:
	_refresh_markers()


func _refresh_markers() -> void:
	for pile_id in _markers.keys():
		if not session.state.recovery_piles.has(pile_id):
			(_markers[pile_id] as Node3D).queue_free()
			_markers.erase(pile_id)
	for pile_id in session.state.recovery_piles:
		var pile := session.state.recovery_piles[pile_id] as Dictionary
		var marker := _markers.get(pile_id) as Node3D
		if marker == null:
			marker = Node3D.new()
			marker.name = "Recovery_%s" % str(pile_id).replace(":", "_")
			add_child(marker)
			var ring := MeshInstance3D.new()
			var mesh := TorusMesh.new()
			mesh.inner_radius = 0.62
			mesh.outer_radius = 0.68
			ring.mesh = mesh
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color("ffcf70")
			ring.material_override = material
			marker.add_child(ring)
			var label := Label3D.new()
			label.name = "Label"
			label.position.y = 0.6
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 32
			label.pixel_size = 0.004
			marker.add_child(label)
			_markers[pile_id] = marker
		marker.global_position = ItemRecord._array_to_vector(pile.origin as Array) + Vector3.UP * 0.08
		(marker.get_node("Label") as Label3D).text = "RECOVER %d" % ((pile.item_ids as Array).size() + (pile.bag_ids as Array).size())
