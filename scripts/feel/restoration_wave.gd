class_name RestorationWave
extends MeshInstance3D
## Self-freeing expanding light wall (restoration) and vertical light column (beacon).

const FEEL := preload("res://data/feel/feel_tuning.tres")
const SHADER := preload("res://shaders/feel_wave.gdshader")
# Seen from above the water, a wall that lies wholly under the surface glowed through it as if it
# floated on top; it is dimmed to this share while the camera is above the water.
const ABOVE_WATER_DIM := 0.5
# The beacon keeps its light higher up than the wall, so it reads above rooftops from afar.
const BEACON_FADE_POWER := 0.7

static var _mesh: CylinderMesh
static var _live := 0


static func spawn(parent: Node, ground: Vector3, radius: float, seconds: float, color: Color) -> RestorationWave:
	var wave := _make(parent, color)
	if wave == null:
		return null
	wave.global_position = ground + Vector3.UP * (FEEL.wave_height * 0.5 - 0.35)
	var submerged := ground.y + FEEL.wave_height - 0.35 < WorldItem.WATER_LEVEL
	var material := wave.material_override as ShaderMaterial
	var t := FeelMotion.tween(wave)
	t.tween_method(func(p: float) -> void:
		var r := lerpf(0.4, radius, 1.0 - pow(1.0 - p, 2.0))
		wave.scale = Vector3(r, 1.0, r)
		var shown := smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.6, 1.0, p))
		var camera := wave.get_viewport().get_camera_3d()
		if submerged and camera != null:
			shown *= lerpf(1.0, ABOVE_WATER_DIM, smoothstep(WorldItem.WATER_LEVEL - 0.1, WorldItem.WATER_LEVEL + 0.1, camera.global_position.y))
		material.set_shader_parameter("intensity", shown)
	, 0.0, 1.0, seconds)
	t.tween_callback(wave.queue_free)
	return wave


static func spawn_beacon(parent: Node, ground: Vector3, color: Color) -> RestorationWave:
	var beacon := _make(parent, color)
	if beacon == null:
		return null
	var stretch := FEEL.beacon_height / FEEL.wave_height
	beacon.scale = Vector3(0.6, stretch, 0.6)
	beacon.global_position = ground + Vector3.UP * (FEEL.beacon_height * 0.5 - 0.2)
	var material := beacon.material_override as ShaderMaterial
	material.set_shader_parameter("fade_power", BEACON_FADE_POWER)
	var t := FeelMotion.tween(beacon)
	t.tween_method(func(p: float) -> void:
		material.set_shader_parameter("intensity", 0.8 * smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.7, 1.0, p)))
	, 0.0, 1.0, FEEL.beacon_seconds)
	t.tween_callback(beacon.queue_free)
	return beacon


static func live_count() -> int:
	return _live


static func _make(parent: Node, color: Color) -> RestorationWave:
	if _live >= FEEL.max_concurrent_waves or parent == null or not parent.is_inside_tree():
		return null
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 1.0
		_mesh.bottom_radius = 1.0
		_mesh.height = FEEL.wave_height
		_mesh.radial_segments = 48
		_mesh.rings = 1
		_mesh.cap_top = false
		_mesh.cap_bottom = false
	var node := RestorationWave.new()
	node.mesh = _mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("wave_color", color)
	material.set_shader_parameter("wall_height", FEEL.wave_height)
	# Starts dark: the first tween step sets the real intensity.
	material.set_shader_parameter("intensity", 0.0)
	node.material_override = material
	parent.add_child(node)
	_live += 1
	return node


func _exit_tree() -> void:
	_live = maxi(_live - 1, 0)
