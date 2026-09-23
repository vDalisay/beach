class_name BuriedFind
extends Node3D

const DIG_REACH := 1.5

var session: RunSession
var player: BeachPlayer
var missing_surfaces: PackedStringArray
var blocked_reveals: PackedStringArray


func configure(run_session: RunSession, player_body: BeachPlayer) -> void:
	session = run_session
	player = player_body
	missing_surfaces.clear()
	blocked_reveals.clear()
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if record.location != ItemRecord.Location.BURIED:
			continue
		var authored := record.dig_surface_position
		var query := PhysicsRayQueryParameters3D.create(authored + Vector3.UP * 3.0, authored + Vector3.DOWN * 8.0, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.collider as Node).is_in_group("sand_surfaces"):
			record.dig_surface_position = hit.position
		else:
			missing_surfaces.append(str(record.item_id))
		record.reveal_transform = Transform3D(record.reveal_transform.basis, record.dig_surface_position + Vector3.UP * 0.035)
		var clear_pose := _clear_reveal_pose(record)
		if clear_pose == Transform3D.IDENTITY:
			blocked_reveals.append(str(record.item_id))
		else:
			record.reveal_transform = clear_pose


func nearest(origin: Vector3, maximum_range: float) -> ItemRecord:
	var nearest_record: ItemRecord
	var best_distance := maximum_range
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if record.location != ItemRecord.Location.BURIED:
			continue
		var distance := origin.distance_to(record.dig_surface_position)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and nearest_record != null and str(record.item_id) < str(nearest_record.item_id)):
			nearest_record = record
			best_distance = distance
	return nearest_record


func try_reveal(player_id: StringName, item_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_reveal.bind(player_id, item_id))
	if not session.state.players.has(player_id) or not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Unknown player or find")
	var record := session.state.items[item_id] as ItemRecord
	if record.location != ItemRecord.Location.BURIED or not record.buried or record.revealed:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Find has already been revealed")
	if session.progression.active_tool_id(player_id) != &"detector" or not session.progression.is_owned(player_id, &"detector"):
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "Equip the metal detector")
	var point := record.dig_surface_position
	if player.global_position.distance_to(point) > DIG_REACH:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Move within 1.5 m of the signal")
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z.normalized()
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + forward * 4.5, 1 | 8, [player.get_rid()]))
	if hit.is_empty() or (hit.position as Vector3).distance_to(point) > 0.65 or not (hit.collider as Node).is_in_group("sand_surfaces"):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Aim at the visible dig surface; obstacles block digging")
	var pose := _clear_reveal_pose(record)
	if pose == Transform3D.IDENTITY:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "No clear place to lift the find")
	record.location = ItemRecord.Location.WORLD
	record.buried = false
	record.revealed = true
	record.last_world_transform = pose
	record.linear_velocity = Vector3.ZERO
	record.angular_velocity = Vector3.ZERO
	record.sleeping = true
	session.finalize_action(PackedStringArray([str(item_id)]))
	_animate_lift.call_deferred(item_id)
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {"item_id": str(item_id)})


func _clear_reveal_pose(record: ItemRecord) -> Transform3D:
	var definition := session.definitions[record.definition_id] as ItemDefinition
	var size := WorldItem.profile_size(definition.collision_profile)
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 4 | 8
	for offset in [Vector3.ZERO, Vector3(0.32, 0, 0), Vector3(-0.32, 0, 0), Vector3(0, 0, 0.32), Vector3(0, 0, -0.32)]:
		var candidate := record.reveal_transform.translated(offset)
		query.transform = candidate.translated(Vector3.UP * (size.y * 0.5))
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return Transform3D.IDENTITY


func _animate_lift(item_id: StringName) -> void:
	await get_tree().physics_frame
	var view := session.item_view_manager.view_for(item_id)
	if view == null or (player.settings_store != null and bool(player.settings_store.get_value(&"reduced_motion"))):
		return
	view.visual_root.position.y = -0.3
	view.create_tween().tween_property(view.visual_root, "position:y", 0.0, 0.35)
