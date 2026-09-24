class_name FeelRing
extends MeshInstance3D
## Self-freeing flat ring pulse (scanner sonar, detector ping, landing contact).

const SHADER := preload("res://shaders/feel_ring.gdshader")
const LIVE_CAP := 8

static var _mesh: PlaneMesh
static var _live := 0


static func spawn(parent: Node, at: Vector3, from_radius: float, to_radius: float, seconds: float, color: Color, thickness_m := 0.08, dashes := 0.0) -> FeelRing:
	if _live >= LIVE_CAP or parent == null or not parent.is_inside_tree():
		return null
	if _mesh == null:
		_mesh = PlaneMesh.new()
		_mesh.size = Vector2.ONE
	var ring := FeelRing.new()
	ring.name = "FeelRing"
	ring.mesh = _mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.process_mode = Node.PROCESS_MODE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("ring_color", color)
	material.set_shader_parameter("dashes", dashes)
	ring.material_override = material
	parent.add_child(ring)
	ring.global_transform = Transform3D(Basis.IDENTITY, at)
	_live += 1
	ring._play(from_radius, to_radius, seconds, thickness_m, material)
	return ring


func _play(from_radius: float, to_radius: float, seconds: float, thickness_m: float, material: ShaderMaterial) -> void:
	var t := FeelMotion.tween(self)
	t.tween_method(func(progress: float) -> void:
		var radius := lerpf(from_radius, to_radius, 1.0 - (1.0 - progress) * (1.0 - progress))
		var diameter := maxf(radius * 2.0, 0.01)
		scale = Vector3(diameter, 1.0, diameter)
		material.set_shader_parameter("thickness", clampf(thickness_m / diameter, 0.002, 0.25))
		material.set_shader_parameter("intensity", 1.0 - smoothstep(0.55, 1.0, progress))
	, 0.0, 1.0, maxf(seconds, 0.05))
	t.tween_callback(queue_free)


func _exit_tree() -> void:
	_live = maxi(_live - 1, 0)
