class_name ShaderWarmup
extends SubViewport
## Draws every material the run can show once, in a small offscreen view that shares the beach's
## world (sun, shadow cascades, environment), then frees itself. The Compatibility renderer
## compiles a shader variant the first time it draws it: with a cold shader cache one mid-walk
## frame stalled for 971 ms. Warming up as the run loads moves those compiles to the load, and the
## renderer's disk cache makes later runs fast. Presentation only; nothing here has collision.

signal finished

# Beneath the sand surface, which hides the grid from every gameplay camera above it.
const GRID_ORIGIN := Vector3(0.0, -2000.0, 0.0)
const CELL := 1.25
const FRAMES := 3
const HOVER_SHADER := preload("res://shaders/hover_outline.gdshader")
const GHOST_SHADER := preload("res://shaders/placement_ghost.gdshader")
const GROUP_SWEEP_SHADER := preload("res://shaders/group_sweep.gdshader")

var proxy_count := 0
var _frames_left := FRAMES


## Collects the materials under `source_root` plus the given scenes (drawn later, such as streamed
## item views and tools), and draws them over the next few frames.
func start(source_root: Node, extra_scenes: Array[PackedScene] = []) -> void:
	size = Vector2i(512, 512)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var seen := {}
	var proxies: Array[GeometryInstance3D] = []
	for node in source_root.find_children("*", "GeometryInstance3D", true, false):
		# Scenery replaced by a batch never draws on its own.
		if not node.has_meta(&"batched"):
			_add_proxy(node as GeometryInstance3D, seen, proxies)
	for scene in extra_scenes:
		if scene == null:
			continue
		var instance := scene.instantiate()
		for node in instance.find_children("*", "GeometryInstance3D", true, false):
			_add_proxy(node as GeometryInstance3D, seen, proxies)
		instance.free()
	# Materials that scripts create on demand: hover outline, placement ghost and group sweep.
	for shader in [HOVER_SHADER, GHOST_SHADER]:
		var material := ShaderMaterial.new()
		material.shader = shader
		proxies.append(_box_proxy(material, null))
	var sweep := ShaderMaterial.new()
	sweep.shader = GROUP_SWEEP_SHADER
	proxies.append(_box_proxy(StandardMaterial3D.new(), sweep))
	proxy_count = proxies.size()
	var columns := ceili(sqrt(float(proxies.size())))
	var extent := float(columns) * CELL
	# Three copies of the grid: sunlight only, plus a hut-style light with its cube shadow, plus one
	# beyond its shadow fade distance. Each lighting case compiles its own shader variant.
	var stride := extent * 1.8
	var fits: Array[Transform3D] = []
	for proxy in proxies:
		fits.append(proxy.transform)
	for region in 3:
		var region_origin := GRID_ORIGIN + Vector3(float(region) * stride, 0.0, 0.0)
		for index in proxies.size():
			var proxy := proxies[index] if region == 0 else proxies[index].duplicate() as GeometryInstance3D
			proxy.transform = Transform3D(Basis.IDENTITY, region_origin + Vector3(float(index % columns) * CELL, 0.0, float(index / columns) * CELL)) * fits[index]
			add_child(proxy)
		if region > 0:
			var lamp := OmniLight3D.new()
			lamp.position = region_origin + Vector3(extent * 0.5, 1.5, extent * 0.5)
			lamp.omni_range = extent * 0.75
			lamp.shadow_enabled = region == 1
			add_child(lamp)
	# One orthographic view over all three regions.
	size = Vector2i(roundi(512.0 * (stride * 2.0 + extent + CELL * 2.0) / (extent + CELL * 2.0)), 512)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent + CELL * 2.0
	camera.near = 0.5
	camera.far = 60.0
	camera.position = GRID_ORIGIN + Vector3(stride + extent * 0.5, 25.0, extent * 0.5)
	camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(camera)
	camera.current = true


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	set_process(false)
	finished.emit()
	queue_free()


func _add_proxy(source: GeometryInstance3D, seen: Dictionary, proxies: Array[GeometryInstance3D]) -> void:
	if source is Label3D:
		# Text draws with an internal material chosen by these flags.
		var label := source as Label3D
		var label_key := [&"label", label.billboard, label.alpha_cut, label.shaded, label.double_sided, label.no_depth_test, label.fixed_size, label.texture_filter, label.outline_size > 0, label.font, label.cast_shadow]
		if not seen.has(label_key):
			seen[label_key] = true
			var text := label.duplicate(0) as Label3D
			text.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.25), Vector3.ZERO)
			text.visible = true
			text.visibility_range_end = 0.0
			proxies.append(text)
		return
	var mesh: Mesh
	var multimesh: MultiMesh
	if source is MeshInstance3D:
		if (source as MeshInstance3D).skin != null:
			return
		mesh = (source as MeshInstance3D).mesh
	elif source is MultiMeshInstance3D and (source as MultiMeshInstance3D).multimesh != null:
		multimesh = (source as MultiMeshInstance3D).multimesh
		mesh = multimesh.mesh
	if mesh == null:
		return
	var surface_materials: Array = []
	if source is MeshInstance3D:
		for surface in mesh.get_surface_count():
			surface_materials.append((source as MeshInstance3D).get_surface_override_material(surface))
	var instancing := [] if multimesh == null else [multimesh.transform_format, multimesh.use_colors, multimesh.use_custom_data]
	var key := [mesh, source.material_override, source.material_overlay, surface_materials, source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, instancing]
	if seen.has(key):
		return
	seen[key] = true
	# Scale each model into one grid cell; tiny or huge, it still issues the same shader draw.
	var bounds := mesh.get_aabb()
	var fit := CELL * 0.8 / maxf(maxf(bounds.size.x, bounds.size.y), maxf(bounds.size.z, 0.001))
	var pose := Transform3D(Basis.from_scale(Vector3.ONE * fit), -bounds.get_center() * fit)
	var proxy: GeometryInstance3D
	if multimesh == null:
		var copy := MeshInstance3D.new()
		copy.mesh = mesh
		for surface in surface_materials.size():
			copy.set_surface_override_material(surface, surface_materials[surface])
		copy.transform = pose
		proxy = copy
	else:
		var single := MultiMesh.new()
		single.transform_format = multimesh.transform_format
		single.use_colors = multimesh.use_colors
		single.use_custom_data = multimesh.use_custom_data
		single.mesh = mesh
		single.instance_count = 1
		single.set_instance_transform(0, pose)
		if single.use_colors:
			single.set_instance_color(0, Color.WHITE)
		var copy := MultiMeshInstance3D.new()
		copy.multimesh = single
		proxy = copy
	proxy.material_override = source.material_override
	proxy.material_overlay = source.material_overlay
	proxy.cast_shadow = source.cast_shadow
	proxy.layers = source.layers
	proxies.append(proxy)


func _box_proxy(material: Material, overlay: Material) -> GeometryInstance3D:
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.material_override = material
	box.material_overlay = overlay
	box.transform = Transform3D(Basis.from_scale(Vector3.ONE * CELL * 0.5), Vector3.ZERO)
	return box
