class_name FishSchool
extends Node3D

## A school of reef fish flocking with boids (separation, alignment, cohesion) around an
## invisible route leader. Fish cruise with burst-and-glide strokes, keep off the seabed
## and surface, give a calm diver room and get used to one, and flash-expand away from a
## sudden approach: the startle spreads through the school and each darting fish throws
## bubbles. All fish draw in one MultiMesh; the swim shader bends every body from
## per-fish tail-beat data.

const FISH_COUNT := 9
const SPECIES := [
	"res://art/models/fish_blue_tang.glb",
	"res://art/models/fish_blue_tang.glb",
	"res://art/models/fish_yellow_tang.glb",
	"res://art/models/fish_clown.glb",
]
# Cruise and burst speeds (m/s), how tightly the species schools, whether it swims in
# burst-and-glide strokes, and its tail-beat rate multiplier.
const TRAITS := {
	"fish_blue_tang": {"cruise": 0.85, "burst": 4.2, "tightness": 1.0, "glides": true, "beat": 1.0},
	"fish_yellow_tang": {"cruise": 0.75, "burst": 3.8, "tightness": 0.85, "glides": true, "beat": 1.0},
	"fish_clown": {"cruise": 0.45, "burst": 3.0, "tightness": 0.55, "glides": false, "beat": 1.7},
}
const SWIM_SHADER := preload("res://shaders/fish_swim.gdshader")
const CAUSTICS_SOURCE := preload("res://shaders/seabed_caustics.tres")
const NEIGHBOR_RADIUS := 1.6
const SEPARATION_RADIUS := 0.5
# Neighbours further behind than about 125 degrees are outside a fish's view.
const BLIND_ANGLE_COS := -0.58
const SIMULATION_RANGE := 60.0
const SURFACE_MARGIN := 0.35
const SEABED_MARGIN := 0.45
const TURN_ACCELERATION := 3.5
const BURST_ACCELERATION := 28.0
const BURST_SECONDS := Vector2(0.35, 0.55)
const STARTLE_COOLDOWN := Vector2(1.8, 2.8)
const CASCADE_RADIUS := 1.5
const CASCADE_DELAY := Vector2(0.03, 0.13)
const REGROUP_SECONDS := 3.5

static var _materials: Dictionary = {}

var school_id: StringName
var mover: PathAnimal
var session: RunSession
var bubbles: ParticlePool
var species := ""
var fish: Array[Node3D] = []
var velocities: Array[Vector3] = []
var cruise_speed := 0.85
var burst_speed := 4.2
var tightness := 1.0
var glides := true
var beat_scale := 1.0
var body_length := 0.33
var reduced_motion := false
var _bodies: MultiMeshInstance3D
var _scales := PackedFloat32Array()
var _speed_bias := PackedFloat32Array()
var _tail_phase := PackedFloat32Array()
var _amplitude := PackedFloat32Array()
var _bend := PackedFloat32Array()
var _burst := PackedFloat32Array()
var _burst_dirs: Array[Vector3] = []
var _cooldown := PackedFloat32Array()
var _pending := PackedFloat32Array()
var _stroke := PackedFloat32Array()
var _brightness := PackedFloat32Array()
var _wander := PackedFloat32Array()
var _up: Array[Vector3] = []
var _pending_threat := Vector3.ZERO
var _calm := 0.0
var _regroup := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = absi(str(name).hash())
	mover = PathAnimal.new()
	mover.name = "Route"
	add_child(mover)
	# One species per school, chosen from the school's stable node name.
	var model_path := SPECIES[absi(str(name).hash()) % SPECIES.size()] as String
	species = model_path.get_file().get_basename()
	var traits := TRAITS[species] as Dictionary
	cruise_speed = float(traits.cruise)
	burst_speed = float(traits.burst)
	tightness = float(traits.tightness)
	glides = bool(traits.glides)
	beat_scale = float(traits.beat)
	var mesh := ModelLibrary.mesh(model_path)
	body_length = mesh.get_aabb().size.z
	_bodies = MultiMeshInstance3D.new()
	_bodies.name = "Bodies"
	_bodies.visibility_range_end = 55.0
	var buffer := MultiMesh.new()
	buffer.transform_format = MultiMesh.TRANSFORM_3D
	# Instance colours carry each fish's shade; the Compatibility renderer multiplies them
	# into the vertex colours, so they must be present.
	buffer.use_colors = true
	buffer.use_custom_data = true
	buffer.mesh = mesh
	buffer.instance_count = FISH_COUNT
	_bodies.multimesh = buffer
	_bodies.material_override = _material_for(model_path, mesh)
	add_child(_bodies)
	bubbles = ParticlePool.create(ParticlePool.Kind.BUBBLE, 120)
	add_child(bubbles)
	for index in range(FISH_COUNT):
		var member := Node3D.new()
		member.name = "Fish_%02d" % (index + 1)
		# Loose ball around the leader; the flock sorts itself out within a few seconds.
		var angle := float(index) * 2.399963
		member.position = Vector3(cos(angle), 0.0, sin(angle)) * (0.3 + 0.12 * index) + Vector3.UP * ((index % 3) - 1) * 0.18
		add_child(member)
		fish.append(member)
		var heading := Vector3(cos(angle + PI * 0.5), 0.0, sin(angle + PI * 0.5))
		velocities.append(heading * cruise_speed)
		member.basis = Basis.looking_at(heading, Vector3.UP)
		_scales.append(_rng.randf_range(1.15, 1.55))
		_speed_bias.append(_rng.randf_range(0.9, 1.12))
		_tail_phase.append(_rng.randf() * TAU)
		_amplitude.append(0.08)
		_bend.append(0.0)
		_burst.append(0.0)
		_burst_dirs.append(heading)
		_cooldown.append(0.0)
		_pending.append(-1.0)
		_stroke.append(-_rng.randf_range(0.3, 1.2))
		# Individuals differ slightly in shade.
		_brightness.append(_rng.randf_range(0.9, 1.06))
		_wander.append(_rng.randf() * TAU)
		_up.append(Vector3.UP)
		buffer.set_instance_color(index, Color(_brightness[index], _brightness[index], _brightness[index]))
	_write_instances()


func configure(id: StringName, points: Array[Vector3], reduce_motion := false) -> void:
	school_id = id
	reduced_motion = reduce_motion
	mover.configure(id, [], points, cruise_speed * (0.7 if reduced_motion else 1.1), reduced_motion)


## Starts the school on its loop. A freshly restored school bursts out of the reef first.
func start_school(release := false) -> void:
	mover.resume_loop()
	if release and not reduced_motion:
		_pending_threat = _center() + Vector3(0.0, -0.5, 0.0)
		for index in range(fish.size()):
			_pending[index] = _rng.randf_range(0.0, 0.35)


## Number of fish currently darting away.
func bursting_count() -> int:
	var count := 0
	for remaining in _burst:
		if remaining > 0.0:
			count += 1
	return count


func _process(delta: float) -> void:
	if not is_visible_in_tree() or delta <= 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_squared_to(global_position + mover.position) > SIMULATION_RANGE * SIMULATION_RANGE:
		return
	# Large frame steps (slow frames, time scale) are split to keep the flock stable.
	var steps := ceili(delta / 0.034)
	for step in range(steps):
		step_flock(delta / steps)
	_write_instances()


func step_flock(delta: float) -> void:
	_time += delta
	var surface := 0.08
	var threat := Vector3.INF
	var threat_velocity := Vector3.ZERO
	if session != null and session.swim_service != null and is_instance_valid(session.swim_service.player):
		var player := session.swim_service.player
		threat = player.global_position + Vector3.UP * 0.9 - global_position
		threat_velocity = player.velocity
		surface = session.swim_service.water.surface_y
	bubbles.surface_y = surface
	var center := _center()
	_update_calm(center, threat, threat_velocity, delta)
	_regroup = maxf(0.0, _regroup - delta)
	var goal := mover.position
	var count := fish.size()
	for i in range(count):
		var at := fish[i].position
		var velocity := velocities[i]
		var speed := velocity.length()
		var forward := velocity / speed if speed > 0.001 else -fish[i].basis.z
		_cooldown[i] = maxf(0.0, _cooldown[i] - delta)
		if _pending[i] >= 0.0:
			_pending[i] -= delta
			if _pending[i] < 0.0:
				_startle(i, _pending_threat, center)
		if threat != Vector3.INF and not reduced_motion and _cooldown[i] <= 0.0 and _burst[i] <= 0.0 and _is_threatened(at, threat, threat_velocity):
			_startle(i, threat, center)
			# Only a diver who moves at the school undoes its trust; brushing past a still one barely does.
			_calm = 0.0 if threat_velocity.length() > 0.6 else _calm * 0.7
		var world := global_position + at
		var ceiling := surface - SURFACE_MARGIN - global_position.y
		var floor_y := Coastline.surface_y(world.x, world.z) + SEABED_MARGIN - global_position.y
		var bounds := 0.0
		if at.y > ceiling:
			bounds = -(at.y - ceiling) * 8.0 - 1.0
		elif at.y < floor_y:
			bounds = (floor_y - at.y) * 8.0 + 1.0
		var next: Vector3
		if _burst[i] > 0.0:
			_burst[i] -= delta
			next = velocity.move_toward(_burst_dirs[i] * burst_speed, BURST_ACCELERATION * delta)
			next.y += bounds * delta
			# A darting fish sheds a thin trail of bubbles for the first part of its sprint.
			if _rng.randf() < delta * 10.0:
				bubbles.emit(_tail_position(i), -next.normalized() * 0.3, _rng.randf_range(0.006, 0.012), 2.6)
			if _burst[i] <= 0.0:
				_stroke[i] = -_rng.randf_range(0.5, 1.0)
		else:
			var steering := _flock_steering(i, at, velocity, forward, goal, threat)
			# Schools spread out flat: fish change depth far less readily than heading.
			steering.y = steering.y * 0.4 + bounds
			next = velocity + steering.limit_length(TURN_ACCELERATION * (1.8 if _regroup > 0.0 else 1.0)) * delta
			next.y *= exp(-1.2 * delta)
			next = _level(next, forward).normalized() * _regulate_speed(i, speed, goal.distance_to(at), delta)
		_orient(i, velocity, next, delta)
		velocities[i] = next
		fish[i].position = at + next * delta


func _flock_steering(i: int, at: Vector3, velocity: Vector3, forward: Vector3, goal: Vector3, threat: Vector3) -> Vector3:
	var separation := Vector3.ZERO
	var alignment := Vector3.ZERO
	var cohesion := Vector3.ZERO
	var neighbors := 0
	for j in range(fish.size()):
		if j == i:
			continue
		var offset := fish[j].position - at
		var distance_squared := offset.length_squared()
		if distance_squared > NEIGHBOR_RADIUS * NEIGHBOR_RADIUS:
			continue
		var distance := sqrt(distance_squared)
		if distance_squared < SEPARATION_RADIUS * SEPARATION_RADIUS:
			separation -= offset / maxf(distance_squared, 0.01)
		elif distance > 0.001 and forward.dot(offset / distance) < BLIND_ANGLE_COS:
			continue
		alignment += velocities[j]
		cohesion += fish[j].position
		neighbors += 1
	var desired := cruise_speed
	var steering := _steer(velocity, separation, desired) * 2.2
	if neighbors > 0:
		steering += _steer(velocity, alignment / neighbors, desired) * tightness
		steering += _steer(velocity, cohesion / neighbors - at, desired) * 0.8 * tightness * (2.0 if _regroup > 0.0 else 1.0)
	# The route leader is a loose attraction that grows once a fish strays from it.
	var to_goal := goal - at
	steering += _steer(velocity, to_goal, desired) * clampf((to_goal.length() - 0.6) / 1.8, 0.0, 1.6) * 1.1
	# Individual meandering keeps the school from moving like one rigid block.
	var wander := _wander[i] + _time * 0.35
	steering += Vector3(sin(wander * 1.3), sin(wander * 0.7) * 0.3, cos(wander * 1.1)) * 0.35
	if threat != Vector3.INF:
		# Personal space around a calm diver; it shrinks as the school gets used to them.
		var away := at - threat
		var distance := away.length()
		var comfort := lerpf(1.9, 1.1, _calm)
		if distance < comfort and distance > 0.001:
			steering += away / distance * TURN_ACCELERATION * 1.6 * (1.0 - distance / comfort)
	return steering


func _regulate_speed(i: int, speed: float, goal_distance: float, delta: float) -> float:
	var cruise := cruise_speed * _speed_bias[i] * (0.65 if reduced_motion else 1.0)
	# Hurry to catch up with the leader or to rejoin the school after a scare.
	var target := cruise * clampf(1.0 + (goal_distance - 2.0) * 0.25, 1.0, 1.8) * (1.3 if _regroup > 0.0 else 1.0)
	# Negative stroke time counts down a tail-beating bout; positive counts up a glide.
	_stroke[i] += delta
	if _stroke[i] > 0.0:
		if glides and _regroup <= 0.0 and speed > cruise * 0.55 and _stroke[i] < 0.9:
			# Gliding: tail still, the fish coasts and slows until the next bout.
			return maxf(speed * exp(-0.9 * delta), 0.1)
		_stroke[i] = -_rng.randf_range(0.5, 1.3)
	return move_toward(speed, target * (1.12 if glides else 1.0), 2.2 * delta)


func _orient(i: int, previous: Vector3, next: Vector3, delta: float) -> void:
	var speed := next.length()
	if speed < 0.02:
		return
	# Fish swim level; climbs and dives are limited to about 30 degrees.
	var flat := Vector3(next.x, 0.0, next.z)
	if flat.length_squared() < 0.0001:
		flat = -fish[i].basis.z
		flat.y = 0.0
	var pitch := clampf(atan2(next.y, flat.length()), -0.5, 0.5)
	var forward := flat.normalized() * cos(pitch) + Vector3.UP * sin(pitch)
	# Bank into turns: the body's up leans toward the centre of the curve.
	var acceleration := (next - previous) / delta
	var sideways := acceleration - forward * acceleration.dot(forward)
	sideways.y = 0.0
	sideways = sideways.limit_length(8.0)
	var up_target := (Vector3.UP * 6.0 + sideways * (0.25 if reduced_motion else 0.6)).normalized()
	_up[i] = _up[i].lerp(up_target, 1.0 - exp(-6.0 * delta)).normalized()
	var current := fish[i].basis.orthonormalized()
	var old_forward := -current.z
	var target := Basis.looking_at(forward, _up[i])
	fish[i].basis = Basis(Quaternion(current).slerp(Quaternion(target), 1.0 - exp(-14.0 * delta)))
	var new_forward := -fish[i].basis.z
	var yaw_rate := atan2(old_forward.cross(new_forward).y, old_forward.dot(new_forward)) / delta
	# Turning curls the body into a C with the tail toward the inside of the turn.
	var bend_target := clampf(-yaw_rate * 0.07, -0.45, 0.45)
	_bend[i] = lerpf(_bend[i], bend_target, 1.0 - exp(-18.0 * delta))
	var length := body_length * _scales[i]
	# Tail-beat frequency rises with speed in body lengths per second.
	var frequency := clampf((speed / length + 0.9) / 0.8, 1.2, 13.0) * beat_scale
	var amplitude := 0.22
	if _burst[i] <= 0.0:
		var gliding := glides and _stroke[i] > 0.0
		amplitude = 0.02 if gliding else clampf(0.09 + 0.06 * (speed / cruise_speed - 1.0), 0.06, 0.15) * (0.75 if not glides else 1.0)
		if gliding:
			frequency *= 0.25
	_tail_phase[i] = fmod(_tail_phase[i] + TAU * frequency * delta, TAU * 64.0)
	_amplitude[i] = lerpf(_amplitude[i], amplitude, 1.0 - exp(-10.0 * delta))


## Limits a heading to about 26 degrees of climb or dive; fish do not swim vertically.
func _level(heading: Vector3, fallback: Vector3) -> Vector3:
	var flat := Vector3(heading.x, 0.0, heading.z)
	if flat.length_squared() < 0.000001:
		flat = Vector3(fallback.x, 0.0, fallback.z)
		if flat.length_squared() < 0.000001:
			flat = Vector3.FORWARD
	var pitch := clampf(atan2(heading.y, flat.length()), -0.45, 0.45)
	return flat.normalized() * cos(pitch) + Vector3.UP * sin(pitch)


func _is_threatened(at: Vector3, threat: Vector3, threat_velocity: Vector3) -> bool:
	var offset := at - threat
	var distance := offset.length()
	if distance > 3.2:
		return false
	# Closing speed: a looming diver is far scarier than one drifting past.
	var approach := threat_velocity.dot(offset / maxf(distance, 0.001))
	return distance < lerpf(0.95, 0.6, _calm) or approach > lerpf(1.4, 2.2, _calm) or (distance < 1.8 and approach > lerpf(0.7, 1.3, _calm))


func _startle(i: int, threat: Vector3, center: Vector3) -> void:
	if _cooldown[i] > 0.0 or _burst[i] > 0.0:
		_pending[i] = -1.0
		return
	var at := fish[i].position
	var away := at - threat
	away.y *= 0.35
	if away.length_squared() < 0.0001:
		away = -fish[i].basis.z
	away = away.normalized()
	# Flash expansion: away from the threat and outward from the school, each fish to its own side.
	var side := away.cross(Vector3.UP).normalized()
	var outward := (at - center)
	outward = outward.normalized() * 0.5 if outward.length_squared() > 0.0001 else Vector3.ZERO
	var direction := (away + side * _rng.randf_range(-0.8, 0.8) + outward).normalized()
	direction.y = clampf(direction.y + _rng.randf_range(-0.15, 0.25), -0.4, 0.5)
	direction = direction.normalized()
	var forward := -fish[i].basis.z
	# C-start: the body snaps into a curl toward the escape side before the sprint.
	_bend[i] = -0.45 * signf(forward.cross(direction).y)
	_burst_dirs[i] = direction
	_burst[i] = _rng.randf_range(BURST_SECONDS.x, BURST_SECONDS.y)
	_cooldown[i] = _rng.randf_range(STARTLE_COOLDOWN.x, STARTLE_COOLDOWN.y)
	_pending[i] = -1.0
	_regroup = REGROUP_SECONDS
	# The tail's first hard beat throws a puff of bubbles.
	bubbles.burst(_tail_position(i), -direction, _rng.randi_range(3, 5), 0.7, 0.18, Vector2(0.007, 0.016), 3.0)
	for j in range(fish.size()):
		if j != i and _pending[j] < 0.0 and _cooldown[j] <= 0.0 and _burst[j] <= 0.0 and fish[j].position.distance_to(at) < CASCADE_RADIUS:
			_pending[j] = _rng.randf_range(CASCADE_DELAY.x, CASCADE_DELAY.y)
	_pending_threat = threat


func _update_calm(center: Vector3, threat: Vector3, threat_velocity: Vector3, delta: float) -> void:
	if threat == Vector3.INF or threat.distance_to(center) > 4.5:
		_calm = maxf(0.0, _calm - delta / 30.0)
	elif threat_velocity.length() < 0.6:
		# A slow, steady diver nearby gradually stops being a threat.
		_calm = minf(1.0, _calm + delta / 8.0)


func _steer(velocity: Vector3, desired: Vector3, speed: float) -> Vector3:
	if desired.length_squared() < 0.000001:
		return Vector3.ZERO
	return desired.normalized() * speed - velocity


func _center() -> Vector3:
	var center := Vector3.ZERO
	for member in fish:
		center += member.position
	return center / maxf(fish.size(), 1)


func _tail_position(i: int) -> Vector3:
	return global_position + fish[i].position + fish[i].basis.z * body_length * _scales[i] * 0.45


func _write_instances() -> void:
	var buffer := _bodies.multimesh
	for i in range(fish.size()):
		buffer.set_instance_transform(i, Transform3D(fish[i].basis.scaled(Vector3.ONE * _scales[i]), fish[i].position))
		buffer.set_instance_custom_data(i, Color(fmod(_tail_phase[i], TAU), _amplitude[i], _bend[i], 0.0))


static func _material_for(model_path: String, mesh: Mesh) -> ShaderMaterial:
	if not _materials.has(model_path):
		var material := ShaderMaterial.new()
		material.shader = SWIM_SHADER
		var bounds := mesh.get_aabb()
		material.set_shader_parameter(&"head_z", bounds.position.z)
		material.set_shader_parameter(&"tail_z", bounds.end.z)
		material.set_shader_parameter(&"caustic_texture", CAUSTICS_SOURCE.get_shader_parameter(&"caustic_texture"))
		_materials[model_path] = material
	return _materials[model_path] as ShaderMaterial
