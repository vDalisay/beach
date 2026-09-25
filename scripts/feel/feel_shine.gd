class_name FeelShine
extends RefCounted
## Sweeps the shine band across `meshes`. Every call creates its own material, so no other
## instance of the same mesh ever flashes; overlays are cleared only if still ours.

const FEEL := preload("res://data/feel/feel_tuning.tres")
const SHADER := preload("res://shaders/feel_shine.gdshader")


## Returns {"material", "origin", "direction", "distance"} or {} when there is nothing to shine.
static func play(owner: Node, meshes: Array[MeshInstance3D], seconds: float) -> Dictionary:
	if meshes.is_empty() or owner == null or not owner.is_inside_tree():
		return {}
	var camera := owner.get_viewport().get_camera_3d()
	var angle := deg_to_rad(FEEL.shine_angle_degrees)
	var direction := Vector3.RIGHT
	if camera != null:
		direction = (camera.global_basis.x * cos(angle) + camera.global_basis.y * sin(angle)).normalized()
	var origin := meshes[0].global_position
	var minimum := INF
	var maximum := -INF
	for mesh in meshes:
		var box := mesh.global_transform * mesh.get_aabb()
		for corner in 8:
			var offset := (box.get_endpoint(corner) - origin).dot(direction)
			minimum = minf(minimum, offset)
			maximum = maxf(maximum, offset)
	var distance := maxf(maximum - minimum, 0.1)
	var start := origin + direction * minimum
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("sweep_origin", start)
	material.set_shader_parameter("sweep_direction", direction)
	material.set_shader_parameter("sweep_distance", distance)
	material.set_shader_parameter("band_width", FEEL.shine_band_width)
	material.set_shader_parameter("core_color", FEEL.shine_core_color)
	material.set_shader_parameter("fringe_color", FEEL.shine_fringe_color)
	for mesh in meshes:
		mesh.material_overlay = material
	var t := FeelMotion.tween(owner)
	t.tween_method(func(p: float) -> void:
		material.set_shader_parameter("progress", p)
		material.set_shader_parameter("intensity", FEEL.shine_intensity * smoothstep(-0.15, 0.0, p) * (1.0 - smoothstep(1.0, 1.15, p)))
	, -0.15, 1.15, seconds)
	t.tween_callback(func() -> void:
		for mesh in meshes:
			if is_instance_valid(mesh) and mesh.material_overlay == material:
				mesh.material_overlay = null
	)
	return {"material": material, "origin": start, "direction": direction, "distance": distance}
