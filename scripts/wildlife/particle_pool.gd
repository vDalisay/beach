class_name ParticlePool
extends MultiMeshInstance3D
## Small CPU particle pool for wildlife and feel effects, drawn as one MultiMesh in world space.
## BUBBLE particles rise to a size-dependent terminal speed, wobble, and pop at the water
## surface. SAND grains fly ballistically and settle on the beach. SPARKLE stars and DUST
## puffs are camera-facing quads that drift and fade. Presentation only.

enum Kind { BUBBLE, SAND, SPARKLE, DUST }

const BUBBLE_SHADER := preload("res://shaders/bubble.gdshader")
const SPARKLE_SHADER := preload("res://shaders/feel_sparkle.gdshader")
const DUST_SHADER := preload("res://shaders/feel_dust.gdshader")
const GRAVITY := 9.8

static var _bubble_mesh: SphereMesh
static var _sand_mesh: BoxMesh
static var _sparkle_mesh: QuadMesh
static var _dust_mesh: QuadMesh

var kind := Kind.BUBBLE
var capacity := 160
var surface_y := 0.08
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _seeds := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var tint := Color.WHITE      ## colour for emits that pass no colour
var drag := 4.0              ## DUST velocity decay per second (0 for suction motes)
var rise := 0.12             ## SPARKLE/DUST upward drift, m/s
var grow := 1.5              ## DUST size gained over life (negative shrinks)
var _colors := PackedColorArray()


static func create(particle_kind: Kind, max_particles := 160, process_always := false) -> ParticlePool:
	var pool := ParticlePool.new()
	pool.kind = particle_kind
	pool.capacity = max_particles
	pool.name = ["Bubbles", "SandKicks", "Sparkles", "Dust"][particle_kind]
	if process_always:
		pool.process_mode = Node.PROCESS_MODE_ALWAYS
	return pool


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rng.seed = hash(get_path())
	var buffer := MultiMesh.new()
	buffer.transform_format = MultiMesh.TRANSFORM_3D
	buffer.use_colors = true
	buffer.mesh = _shared_mesh()
	buffer.instance_count = capacity
	buffer.visible_instance_count = 0
	multimesh = buffer
	set_process(false)


func live_count() -> int:
	return _positions.size()


## Emits one particle. Bubbles above the water surface are discarded (there is no air to
## trap); `size` is the bubble radius, sand grain edge or quad size in metres. A colour with
## zero alpha uses the pool's `tint`; BUBBLE and SAND ignore colour.
func emit(at: Vector3, velocity: Vector3, size: float, lifetime := 3.5, color := Color(0, 0, 0, 0)) -> void:
	if kind == Kind.BUBBLE and at.y >= surface_y - size:
		return
	if _positions.size() >= capacity:
		_remove(0)
	_positions.append(at)
	_velocities.append(velocity)
	_ages.append(0.0)
	_lifetimes.append(lifetime)
	_sizes.append(size)
	_seeds.append(_rng.randf() * TAU)
	_colors.append(tint if color.a <= 0.0 else color)
	set_process(true)


## Emits `count` particles around `at`, thrown along `direction` with some spread.
func burst(at: Vector3, direction: Vector3, count: int, speed: float, spread: float, size_range: Vector2, lifetime := 3.5, color := Color(0, 0, 0, 0)) -> void:
	for index in range(count):
		var jitter := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		var throw := direction * speed * _rng.randf_range(0.5, 1.0) + jitter * spread
		emit(at + jitter * size_range.y, throw, _rng.randf_range(size_range.x, size_range.y), lifetime * _rng.randf_range(0.8, 1.2), color)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var index := _positions.size() - 1
	while index >= 0:
		_ages[index] += delta
		match kind:
			Kind.BUBBLE:
				_step_bubble(index, delta)
			Kind.SAND:
				_step_sand(index, delta)
			_:
				_step_drift(index, delta)
		if _ages[index] >= _lifetimes[index]:
			_remove(index)
		index -= 1
	if _positions.is_empty():
		_write_instances()
		set_process(false)
		return
	# Particles age every frame, but off-screen or distant pools rewrite their instances less often.
	# A pool's particles stay within a few metres of their emitter.
	if PresentationLOD.due(PresentationLOD.interval(get_viewport().get_camera_3d(), _positions[0], 4.0, 70.0), get_instance_id()):
		_write_instances()


func _step_bubble(index: int, delta: float) -> void:
	var size := _sizes[index]
	# Small bubbles settle at roughly 0.2-0.35 m/s; the initial throw is lost within a
	# fraction of a second to drag.
	var terminal := Vector3(0.0, 0.18 + size * 9.0, 0.0)
	_velocities[index] = _velocities[index].lerp(terminal, 1.0 - exp(-4.5 * delta))
	_positions[index] += _velocities[index] * delta
	if _positions[index].y + size >= surface_y:
		# Popped at the surface.
		_lifetimes[index] = _ages[index]


func _step_sand(index: int, delta: float) -> void:
	var at := _positions[index]
	var ground := Coastline.surface_y(at.x, at.z)
	if at.y <= ground + _sizes[index] * 0.5:
		# Settled: rest on the sand and fade out.
		_velocities[index] = Vector3.ZERO
		_positions[index] = Vector3(at.x, ground + _sizes[index] * 0.5, at.z)
		_lifetimes[index] = minf(_lifetimes[index], _ages[index] + 0.35)
		return
	_velocities[index] += Vector3.DOWN * GRAVITY * delta
	_velocities[index] *= exp(-0.8 * delta)
	_positions[index] += _velocities[index] * delta


func _step_drift(index: int, delta: float) -> void:
	var decay := 3.0 if kind == Kind.SPARKLE else drag
	_velocities[index] *= exp(-decay * delta)
	_positions[index] += (_velocities[index] + Vector3.UP * rise) * delta


func _write_instances() -> void:
	var count := _positions.size()
	var bounds := AABB()
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var facing := camera.global_basis.orthonormalized() if camera != null else Basis.IDENTITY
	var largest := 0.0
	for index in range(count):
		var age := _ages[index]
		var remaining := _lifetimes[index] - age
		var size := _sizes[index]
		var at := _positions[index]
		var shape := Basis.IDENTITY
		var alpha := 1.0
		if kind == Kind.BUBBLE:
			# Zigzag wobble of rising bubbles; tiny ones rise straight.
			var phase_seed := _seeds[index]
			var wobble := minf(age * 4.0, 1.0) * size * 1.4
			at += Vector3(sin(age * 11.0 + phase_seed), 0.0, cos(age * 8.5 + phase_seed * 1.7)) * wobble
			var grow := minf(age / 0.06, 1.0) * (1.0 + 0.12 * minf(age, 2.0))
			# Slightly flattened, the way larger bubbles rise.
			shape = Basis.from_scale(Vector3(1.0, 0.82, 1.0) * size * 2.0 * grow)
			alpha = clampf(remaining / 0.25, 0.0, 1.0)
		elif kind == Kind.SAND:
			# Grains shrink away once they have settled.
			var tumble := _seeds[index]
			shape = Basis.from_euler(Vector3(tumble, tumble * 1.9, 0.0)).scaled(Vector3.ONE * size * clampf(remaining / 0.35, 0.0, 1.0))
		elif kind == Kind.SPARKLE:
			var life := clampf(age / _lifetimes[index], 0.0, 1.0)
			var envelope := sin(PI * life)
			var twinkle := 0.65 + 0.35 * sin(age * 19.0 + _seeds[index] * 3.0)
			shape = (facing * Basis(Vector3.BACK, _seeds[index])).scaled(Vector3.ONE * size * (0.55 + 0.45 * envelope))
			alpha = envelope * twinkle
			largest = maxf(largest, size)
		else:
			var life := clampf(age / _lifetimes[index], 0.0, 1.0)
			var extent := maxf(size * (1.0 + grow * life), 0.005)
			shape = facing.scaled(Vector3.ONE * extent)
			alpha = (1.0 - life) * (1.0 - life) * minf(life * 8.0, 1.0)
			largest = maxf(largest, extent)
		multimesh.set_instance_transform(index, Transform3D(shape, at))
		var c := _colors[index]
		multimesh.set_instance_color(index, Color(1.0, 1.0, 1.0, alpha) if kind == Kind.BUBBLE or kind == Kind.SAND else Color(c.r, c.g, c.b, c.a * alpha))
		bounds = AABB(at, Vector3.ZERO) if index == 0 else bounds.expand(at)
	multimesh.visible_instance_count = count
	if count > 0:
		custom_aabb = bounds.grow(maxf(0.1, largest))


func _remove(index: int) -> void:
	var last := _positions.size() - 1
	if index != last:
		_positions[index] = _positions[last]
		_velocities[index] = _velocities[last]
		_ages[index] = _ages[last]
		_lifetimes[index] = _lifetimes[last]
		_sizes[index] = _sizes[last]
		_seeds[index] = _seeds[last]
		_colors[index] = _colors[last]
	_positions.resize(last)
	_velocities.resize(last)
	_ages.resize(last)
	_lifetimes.resize(last)
	_sizes.resize(last)
	_seeds.resize(last)
	_colors.resize(last)


func _shared_mesh() -> Mesh:
	if kind == Kind.BUBBLE:
		if _bubble_mesh == null:
			_bubble_mesh = SphereMesh.new()
			_bubble_mesh.radius = 0.5
			_bubble_mesh.height = 1.0
			_bubble_mesh.radial_segments = 10
			_bubble_mesh.rings = 5
			var material := ShaderMaterial.new()
			material.shader = BUBBLE_SHADER
			_bubble_mesh.material = material
		return _bubble_mesh
	if kind == Kind.SPARKLE:
		if _sparkle_mesh == null:
			_sparkle_mesh = QuadMesh.new()
			_sparkle_mesh.size = Vector2.ONE
			var material := ShaderMaterial.new()
			material.shader = SPARKLE_SHADER
			_sparkle_mesh.material = material
		return _sparkle_mesh
	if kind == Kind.DUST:
		if _dust_mesh == null:
			_dust_mesh = QuadMesh.new()
			_dust_mesh.size = Vector2.ONE
			var material := ShaderMaterial.new()
			material.shader = DUST_SHADER
			_dust_mesh.material = material
		return _dust_mesh
	if _sand_mesh == null:
		_sand_mesh = BoxMesh.new()
		_sand_mesh.size = Vector3.ONE
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d8c39a")
		material.roughness = 1.0
		_sand_mesh.material = material
	return _sand_mesh
