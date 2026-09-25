class_name FeelBurst
extends CPUParticles3D
## Self-freeing one-shot 3D bursts built from POLYGON Particle FX pieces: paper confetti when a
## prop set is finished, the pack's hearts when an animal swims free, its coins when the truck
## pays out at a hotline. Presentation only; callers skip it under reduced motion.

enum Kind { CONFETTI, HEARTS, COINS }

const FEEL := preload("res://data/feel/feel_tuning.tres")
const HEART_SCENE := preload("res://art/synty/fx/FX_Heart_01.fbx")
const COIN_SCENE := preload("res://art/synty/fx/FX_Money_Coin_01.fbx")
const LIVE_CAP := 6

static var _live := 0
static var _meshes := {}


static func spawn(parent: Node, at: Vector3, kind: Kind) -> FeelBurst:
	if _live >= LIVE_CAP or parent == null or not parent.is_inside_tree():
		return null
	var burst := FeelBurst.new()
	burst.name = "FeelBurst"
	burst._setup(kind)
	parent.add_child(burst)
	burst.global_position = at
	_live += 1
	burst.restart()
	burst.emitting = true
	burst.get_tree().create_timer(burst.lifetime + 0.4, true).timeout.connect(burst.queue_free)
	return burst


func _exit_tree() -> void:
	_live = maxi(_live - 1, 0)


func _setup(kind: Kind) -> void:
	one_shot = true
	explosiveness = 0.92
	local_coords = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	match kind:
		Kind.CONFETTI:
			amount = 36
			lifetime = 2.2
			mesh = _quad()
			direction = Vector3.UP
			spread = 42.0
			initial_velocity_min = 3.2
			initial_velocity_max = 5.0
			gravity = Vector3(0.0, -4.5, 0.0)
			damping_min = 1.2
			damping_max = 2.2
			angular_velocity_min = -540.0
			angular_velocity_max = 540.0
			angle_min = 0.0
			angle_max = 360.0
			particle_flag_rotate_y = true
			scale_amount_min = 0.8
			scale_amount_max = 1.3
			var ramp := Gradient.new()
			ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			var colors := PackedColorArray(FEEL.confetti_colors)
			colors.append(Color("ffd257"))
			var offsets := PackedFloat32Array()
			for index in colors.size():
				offsets.append(float(index) / float(colors.size()))
			ramp.offsets = offsets
			ramp.colors = colors
			color_initial_ramp = ramp
			color_ramp = fade
		Kind.HEARTS:
			amount = 7
			lifetime = 1.8
			explosiveness = 0.6
			mesh = _mesh_from(HEART_SCENE, _tinted_material())
			direction = Vector3.UP
			spread = 30.0
			initial_velocity_min = 0.8
			initial_velocity_max = 1.4
			gravity = Vector3(0.0, 0.35, 0.0)
			damping_min = 0.4
			damping_max = 0.8
			scale_amount_min = 0.35
			scale_amount_max = 0.55
			var grow := Curve.new()
			grow.add_point(Vector2(0.0, 0.2))
			grow.add_point(Vector2(0.2, 1.0))
			grow.add_point(Vector2(0.8, 1.0))
			grow.add_point(Vector2(1.0, 0.0))
			scale_amount_curve = grow
			# The pack tints its hearts per particle, white to pink; ours stay in the warm pinks.
			var pinks := Gradient.new()
			pinks.offsets = PackedFloat32Array([0.0, 1.0])
			pinks.colors = PackedColorArray([Color("ff5f7e"), Color("ffa3c4")])
			color_initial_ramp = pinks
		Kind.COINS:
			amount = 14
			lifetime = 1.3
			mesh = _mesh_from(COIN_SCENE, _gold_material())
			direction = Vector3.UP
			spread = 35.0
			initial_velocity_min = 3.0
			initial_velocity_max = 4.5
			gravity = Vector3(0.0, -9.0, 0.0)
			angular_velocity_min = -720.0
			angular_velocity_max = 720.0
			particle_flag_rotate_y = true
			scale_amount_min = 4.0
			scale_amount_max = 5.0
			color_ramp = fade


static func _quad() -> Mesh:
	if not _meshes.has(&"quad"):
		var quad := QuadMesh.new()
		quad.size = Vector2(0.05, 0.08)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		quad.material = material
		_meshes[&"quad"] = quad
	return _meshes[&"quad"]


## The first mesh of a Particle FX model with `material` on every surface. The pack colours these
## meshes in its particle shader, so they carry no texture of their own.
static func _mesh_from(scene: PackedScene, material: Material) -> Mesh:
	var key := scene.resource_path
	if not _meshes.has(key):
		var node := scene.instantiate()
		var source := node.find_children("*", "MeshInstance3D", true, false)
		var mesh := (source[0] as MeshInstance3D).mesh.duplicate() as Mesh if not source.is_empty() else SphereMesh.new()
		node.free()
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface, material)
		_meshes[key] = mesh
	return _meshes[key]


## Flat pieces (the heart) turn to face the camera, as the pack's billboarded particles do.
static func _tinted_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _gold_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffd257")
	material.metallic = 0.35
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = Color("ff9f1c")
	material.emission_energy_multiplier = 0.25
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
