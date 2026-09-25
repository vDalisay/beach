class_name SandCleaner
extends Node

signal feedback_requested(message: String)

const TOOL_ID := &"sand_cleaner"
const FEEL := preload("res://data/feel/feel_tuning.tres")
const RING_SHADER := preload("res://shaders/feel_ring.gdshader")

var session: RunSession
var player: BeachPlayer
var definition: ToolDefinition
var preview: MeshInstance3D
var _ring_material: ShaderMaterial
var _hint_elapsed := 0.0
var _contract_until := 0


func configure(run_session: RunSession, player_body: BeachPlayer) -> void:
	session = run_session
	player = player_body
	definition = session.progression.offers[TOOL_ID] as ToolDefinition
	session.sand_cleaner = self
	preview = MeshInstance3D.new()
	preview.name = "SandCleanerPatchPreview"
	# A rotating dashed ring on a size-2 plane: scale by the radius gives the patch diameter.
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	preview.mesh = plane
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = RING_SHADER
	_ring_material.set_shader_parameter("ring_color", FEEL.sand_ring_color)
	_ring_material.set_shader_parameter("dashes", FEEL.sand_ring_dashes)
	_ring_material.set_shader_parameter("intensity", 0.55)
	preview.material_override = _ring_material
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
		_reject("Aim at exposed sand within reach")
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Aim at exposed sand within reach")
	var record := session.state.players[&"local"] as Dictionary
	var free_capacity := int(record.bag_capacity) - (record.trash_bag as Array).size() - (record.valuable_bag as Array).size()
	if free_capacity <= 0:
		feedback_requested.emit("Bag full")
		_reject("Bag full")
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
		_reject("No exposed sand litter in patch")
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "No exposed sand litter in patch")
	_present_sift(point, changed.size())
	return ActionResult.accepted(changed, {"count": changed.size(), "center": point})


## Presentation only: the sift clip, a sand puff and the ring pulling in over the patch.
func _present_sift(point: Vector3, count: int) -> void:
	var reduced := FeelMotion.reduced(player.settings_store)
	player.play_cue(&"sift", {"count": count})
	var manager := session.item_view_manager
	if manager.dust != null:
		manager.dust.burst(point + Vector3.UP * 0.03, Vector3.UP, 8 if reduced else 16, 1.0, 0.8, Vector2(0.04, 0.08), 0.6, FEEL.sand_color)
	if reduced:
		return
	_contract_until = Time.get_ticks_msec() + 300
	var full := Vector3.ONE * radius()
	var t := FeelMotion.replace(preview, &"contract", FeelMotion.tween(preview).set_parallel(true))
	t.tween_property(preview, "scale", full * 0.2, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_method(func(value: float) -> void: _ring_material.set_shader_parameter("intensity", value), 1.0, 0.0, 0.3)
	t.chain().tween_callback(func() -> void:
		preview.scale = Vector3.ONE * radius()
		_ring_material.set_shader_parameter("intensity", 0.55)
	)


func _reject(reason: String) -> void:
	player.play_cue(&"rejected", {"reason": reason})
	_ring_material.set_shader_parameter("ring_color", FEEL.hover_blocked_color)
	var t := FeelMotion.replace(preview, &"tint", FeelMotion.tween(preview))
	t.tween_interval(0.2)
	t.tween_callback(func() -> void: _ring_material.set_shader_parameter("ring_color", FEEL.sand_ring_color))


func _physics_process(delta: float) -> void:
	if not is_active():
		preview.visible = false
		return
	var target := _ground_target()
	preview.visible = not target.is_empty()
	player.hand_rig.set_tool_activity(&"sand_cleaner", 0.4 if preview.visible else 0.0)
	if not preview.visible or Time.get_ticks_msec() < _contract_until:
		return
	var point := target.position as Vector3
	preview.global_position = point + Vector3.UP * 0.04
	preview.scale = Vector3.ONE * radius()
	_ring_material.set_shader_parameter("thickness", 0.04 / radius())
	if not FeelMotion.reduced(player.settings_store):
		_ring_material.set_shader_parameter("dash_phase", fmod(Time.get_ticks_msec() * 0.001 * 0.15, 1.0))
	_hint_elapsed += delta
	if _hint_elapsed >= 0.1:
		_hint_elapsed = 0.0
		# A presentation hint only: litter nearby brightens the ring (no visibility rays).
		var litter := CleanupTargetQuery.nearby_waste(session, player, point + Vector3.UP * 0.15, radius()).size()
		_ring_material.set_shader_parameter("intensity", 1.0 if litter > 0 else 0.55)


func _ground_target() -> Dictionary:
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * definition.range, 1 | 8, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit.collider as Node).is_in_group("sand_surfaces"):
		return {}
	return hit
