class_name SandCleaner
extends Node

signal feedback_requested(message: String)

const TOOL_ID := &"sand_cleaner"
const FEEL := preload("res://data/feel/feel_tuning.tres")

var session: RunSession
var player: BeachPlayer
var definition: ToolDefinition
var preview: MeshInstance3D


func configure(run_session: RunSession, player_body: BeachPlayer) -> void:
	session = run_session
	player = player_body
	definition = session.progression.offers[TOOL_ID] as ToolDefinition
	session.sand_cleaner = self
	preview = MeshInstance3D.new()
	preview.name = "SandCleanerPatchPreview"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.96
	ring.outer_radius = 1.0
	ring.rings = 12
	ring.ring_segments = 28
	preview.mesh = ring
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.27, 0.92, 0.86, 0.8)
	preview.material_override = material
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.visible = false
	session.item_view_manager.add_child(preview)
	set_physics_process(true)


func is_active() -> bool:
	return session != null and session.progression.active_tool_id(&"local") == TOOL_ID and session.progression.is_owned(&"local", TOOL_ID) and (session.state.players[&"local"].held_objects as Array).is_empty()


func radius() -> float:
	if session.progression.is_owned(&"local", &"sand_cleaner_2"):
		return (session.progression.offers[&"sand_cleaner_2"] as UpgradeDefinition).secondary_value
	return definition.radius


func max_count() -> int:
	if session.progression.is_owned(&"local", &"sand_cleaner_2"):
		return int((session.progression.offers[&"sand_cleaner_2"] as UpgradeDefinition).exact_value)
	return definition.max_items_per_use


func try_click() -> ActionResult:
	if not is_active():
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "Equip the sand cleaner")
	var point_result := _ground_target()
	if point_result.is_empty():
		feedback_requested.emit("Aim at exposed sand within reach")
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Aim at exposed sand within reach")
	var record := session.state.players[&"local"] as Dictionary
	var free_capacity := int(record.bag_capacity) - (record.trash_bag as Array).size() - (record.valuable_bag as Array).size()
	if free_capacity <= 0:
		feedback_requested.emit("Bag full")
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Bag full")
	var point := point_result.position as Vector3
	var changed := PackedStringArray()
	for view in CleanupTargetQuery.nearby_waste(session, player, point + Vector3.UP * 0.15, radius() + 0.35):
		if changed.size() >= mini(max_count(), free_capacity):
			break
		var offset := view.global_position - point
		if Vector2(offset.x, offset.z).length() > radius() or absf(offset.y) > 0.55 or not CleanupTargetQuery.visible_from_camera(player, view):
			continue
		var result := session.item_store.try_collect(&"local", view.item_id, {
			"target_id": str(view.item_id), "visible": true,
			"distance": player.camera.global_position.distance_to(view.global_position),
			"reach": definition.range + radius() + 0.5,
		})
		if result.ok:
			changed.append(str(view.item_id))
			player.carry.present_collected(view.item_id, &"sand_cleaner", float(changed.size() - 1) * FEEL.sand_cleaner_stagger)
	if changed.is_empty():
		feedback_requested.emit("No exposed sand litter in patch")
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "No exposed sand litter in patch")
	return ActionResult.accepted(changed, {"count": changed.size(), "center": point})


func _physics_process(_delta: float) -> void:
	if not is_active():
		preview.visible = false
		return
	var target := _ground_target()
	preview.visible = not target.is_empty()
	if preview.visible:
		preview.global_position = (target.position as Vector3) + Vector3.UP * 0.04
		preview.scale = Vector3.ONE * radius()


func _ground_target() -> Dictionary:
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * definition.range, 1 | 8, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit.collider as Node).is_in_group("sand_surfaces"):
		return {}
	return hit
