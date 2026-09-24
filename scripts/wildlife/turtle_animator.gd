class_name TurtleAnimator
extends Node3D
## Procedural animation for the modelled sea turtle. It watches how the turtle actually
## moves, so any mover (a route, the companion behaviour, a rescue tween) gets a matching
## gait: front-flipper power strokes with glides, slow alternating sculls when hovering or
## breathing at the surface, the symmetrical beach crawl with pauses, and struggling while
## entangled. `surge` reports the stroke rhythm so movers can pulse their speed with it.
## Head and tail turn in the body shader; bubbles and sand kicks are CPU particles.

enum Gait { SWIM, HOVER, CRAWL, REST, ENTANGLED }

const BODY_SHADER := preload("res://shaders/turtle_body.gdshader")
const CAUSTICS_SOURCE := preload("res://shaders/seabed_caustics.tres")
const FLIPPER_NAMES := ["FlipperFL", "FlipperFR", "FlipperBL", "FlipperBR"]
const CRAWL_PERIOD := 1.35
# Share of a crawl cycle spent pushing the body forward.
const CRAWL_PUSH := 0.45
# Share of a swim stroke spent on the downstroke (the power phase).
const DOWNSTROKE := 0.55
# Beyond this camera distance the gait and surge keep running but nothing is posed.
const POSE_RANGE := 70.0
# Poses sweep from these headings (radians forward of straight out to the side), whatever
# angle a model's flippers happen to rest at.
const FRONT_REFERENCE_SWEEP := 0.52
const REAR_REFERENCE_SWEEP := -0.61
# Model space of art/models/turtle.glb; the same pivot is set in turtle_body.gdshader.
const NECK_PIVOT := Vector3(0.0, 0.068, -0.36)
const HEAD_OFFSET := Vector3(0.0, 0.09, -0.6)

static var _flipper_material: ShaderMaterial

@export var water_surface_y := 0.08
## Turn the whole turtle toward its direction of travel, for movers that only set position.
@export var face_motion := false

var reduced_motion := false
var entangled := false
## Held at the surface with the head raised to breathe.
var breathing := false
## Hovering at the bottom, nibbling with the head down.
var grazing := false
## Puff bubbles off the shell with each power stroke.
var trail_bubbles := false
var look_target := Vector3.ZERO
var look_weight := 0.0
var gait := Gait.SWIM
var surge := 1.0
var velocity := Vector3.ZERO
var bubbles: ParticlePool
var sand: ParticlePool

var _root: Node3D
var _visual: Node3D
var _body: MeshInstance3D
var _material: ShaderMaterial
var _flippers: Array[Node3D] = []
var _sides := PackedFloat32Array()
var _front: Array[bool] = []
var _axes: Array[Vector3] = []
var _hinges: Array[Vector3] = []
var _sweep_offsets := PackedFloat32Array()
var _tips := PackedFloat32Array()
var _last_position := Vector3.ZERO
var _last_heading := 0.0
var _yaw_rate := 0.0
var _stroke_phase := 0.0
var _crawl_phase := 0.0
var _glide := 0.0
var _glide_weight := 0.0
var _strokes_until_glide := 2
var _crawl_weight := 0.0
var _hover_weight := 0.0
var _strokes_until_rest := 6
var _rest := 0.0
var _struggle := 0.0
var _struggle_wait := 1.5
var _pitch := 0.0
var _roll := 0.0
var _head := Vector2.ZERO
var _tail := 0.0
var _bite := 0.0
var _bite_wait := 1.0
var _time := 0.0
var _seed := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_root = get_parent() as Node3D
	_visual = _root.get_node("Visual") as Node3D
	_rng.seed = hash(str(_root.get_path()))
	_seed = _rng.randf() * TAU
	for mesh_instance in _visual.find_children("*", "MeshInstance3D", true, false):
		if not str(mesh_instance.name).begins_with("Flipper"):
			_body = mesh_instance as MeshInstance3D
			break
	_material = ShaderMaterial.new()
	_material.shader = BODY_SHADER
	_material.set_shader_parameter(&"neck_enabled", true)
	_material.set_shader_parameter(&"caustic_texture", CAUSTICS_SOURCE.get_shader_parameter(&"caustic_texture"))
	_body.material_override = _material
	if _flipper_material == null:
		_flipper_material = ShaderMaterial.new()
		_flipper_material.shader = BODY_SHADER
		_flipper_material.set_shader_parameter(&"caustic_texture", CAUSTICS_SOURCE.get_shader_parameter(&"caustic_texture"))
	for part_name in FLIPPER_NAMES:
		var flipper := _visual.find_child(part_name, true, false) as MeshInstance3D
		if flipper == null:
			continue
		flipper.material_override = _flipper_material
		# The flipper's long axis runs from its joint (the node origin) to its farthest tip.
		var tip := Vector3.ZERO
		for vertex in flipper.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var flat := Vector3(vertex.x, 0.0, vertex.z)
			if flat.length_squared() > tip.length_squared():
				tip = flat
		var front := flipper.position.z < 0.0
		var rest_sweep := atan2(-tip.z, absf(tip.x))
		_flippers.append(flipper)
		_sides.append(1.0 if flipper.position.x >= 0.0 else -1.0)
		_front.append(front)
		_axes.append(tip.normalized())
		_hinges.append(tip.normalized().cross(Vector3.UP).normalized())
		_sweep_offsets.append((FRONT_REFERENCE_SWEEP if front else REAR_REFERENCE_SWEEP) - rest_sweep)
		_tips.append(tip.length())
	bubbles = ParticlePool.create(ParticlePool.Kind.BUBBLE, 140)
	add_child(bubbles)
	sand = ParticlePool.create(ParticlePool.Kind.SAND, 90)
	add_child(sand)
	_last_position = _root.global_position
	_last_heading = _heading()
	_strokes_until_rest = _rng.randi_range(5, 8)


func _process(delta: float) -> void:
	if delta <= 0.0 or not _root.is_visible_in_tree():
		return
	_time += delta
	var at := _root.global_position
	var measured := (at - _last_position) / delta
	_last_position = at
	# Teleports (loads, resets) must not read as a burst of speed.
	if measured.length() > 12.0:
		measured = velocity
	velocity = velocity.lerp(measured, 1.0 - exp(-8.0 * delta))
	if face_motion:
		_face_travel(delta)
	var heading := _heading()
	_yaw_rate = lerpf(_yaw_rate, wrapf(heading - _last_heading, -PI, PI) / delta, 1.0 - exp(-6.0 * delta))
	_last_heading = heading
	var speed := Vector2(velocity.x, velocity.z).length()
	var ground := Coastline.surface_y(at.x, at.z)
	# The dry beach sits a little below the water plane, so the shoreline decides what is sea.
	var in_sea := at.z >= Coastline.shore_z(at.x)
	var afloat := at.y - ground > 0.12
	bubbles.surface_y = water_surface_y
	# On the beach, or touching bottom in the shallows, a sea turtle crawls; otherwise it swims.
	var crawl_target := 1.0 if not in_sea or (not afloat and water_surface_y - ground < 0.35) else 0.0
	_crawl_weight = move_toward(_crawl_weight, crawl_target, delta * 2.5)
	_hover_weight = move_toward(_hover_weight, 1.0 if speed < 0.22 or breathing or grazing else 0.0, delta * 2.0)
	if entangled:
		gait = Gait.ENTANGLED
	elif _crawl_weight > 0.5:
		gait = Gait.REST if _rest > 0.0 else Gait.CRAWL
	else:
		gait = Gait.HOVER if _hover_weight > 0.5 else Gait.SWIM
	var poses: Array[Vector3] = []
	poses.resize(_flippers.size())
	var body := Vector3.ZERO
	if entangled:
		surge = 0.0
		_animate_struggle(delta, poses)
	else:
		var swim_body := _animate_swim(delta, speed, poses)
		var swim_surge := surge
		if _crawl_weight > 0.0:
			var crawl_poses: Array[Vector3] = []
			crawl_poses.resize(_flippers.size())
			var crawl_body := _animate_crawl(delta, in_sea, crawl_poses)
			for index in range(poses.size()):
				poses[index] = poses[index].lerp(crawl_poses[index], _crawl_weight)
			body = swim_body.lerp(crawl_body, _crawl_weight)
			surge = lerpf(swim_surge, surge, _crawl_weight)
			_tail *= 1.0 - _crawl_weight
		else:
			body = swim_body
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_squared_to(at) > POSE_RANGE * POSE_RANGE:
		return
	for index in range(_flippers.size()):
		_pose_flipper(index, poses[index])
	_pose_body(delta, speed, body)
	_pose_head(delta)


## Breath out through the nostrils: a burst of larger bubbles from the head.
func exhale() -> void:
	bubbles.burst(head_world_position(), Vector3(0.0, 0.6, -0.2), _rng.randi_range(14, 20), 0.35, 0.2, Vector2(0.008, 0.024), 3.0)


func head_world_position() -> Vector3:
	return _body.global_transform * HEAD_OFFSET


func _animate_swim(delta: float, speed: float, poses: Array[Vector3]) -> Vector3:
	var effort := clampf(speed / 1.6, 0.0, 1.0)
	var strength := lerpf(0.4, 1.0, effort)
	if _glide > 0.0:
		_glide -= delta
	else:
		_stroke_phase += lerpf(0.42, 1.0, effort) * lerpf(1.0, 0.8, _hover_weight) * delta
		if _stroke_phase >= 1.0:
			_stroke_phase = fmod(_stroke_phase, 1.0)
			_strokes_until_glide -= 1
			# Cruising turtles take a few strokes, then glide with the flippers swept back.
			if _strokes_until_glide <= 0 and speed > 0.45 and _hover_weight < 0.5 and not breathing:
				_glide = _rng.randf_range(0.7, 1.6)
				_strokes_until_glide = _rng.randi_range(2, 4)
			elif _hover_weight < 0.5 and trail_bubbles:
				# A new downstroke begins; it shakes a few bubbles off the shell.
				var rear := _root.global_transform * Vector3(0.0, 0.14, 0.38)
				bubbles.burst(rear, _root.global_basis.z, 3, 0.35, 0.1, Vector2(0.006, 0.013), 2.6)
	_glide_weight = move_toward(_glide_weight, 1.0 if _glide > 0.0 else 0.0, delta * 3.0)
	var p := _stroke_phase
	var rudder := clampf(-_yaw_rate * 0.35, -0.45, 0.45)
	for index in range(_flippers.size()):
		var side := _sides[index]
		var stroke: Vector3
		var glide_pose: Vector3
		var hover_pose: Vector3
		var scull := TAU * p + (0.0 if side > 0.0 else PI)
		if _front[index]:
			stroke = _front_stroke(p, strength)
			glide_pose = Vector3(-1.15, -0.12, 0.15)
			hover_pose = Vector3(-0.3 + 0.3 * sin(scull), 0.28 * sin(scull + PI * 0.5), 0.5 * cos(scull))
		else:
			stroke = Vector3(-0.25 + rudder * side, -0.05 + 0.18 * sin(TAU * p + 1.2) * strength, 0.25 * sin(TAU * p) * strength)
			glide_pose = Vector3(-0.35 + rudder * side, -0.05, 0.0)
			hover_pose = Vector3(-0.2 + 0.15 * sin(scull + 1.0), -0.1 + 0.12 * sin(scull), 0.2 * cos(scull))
		poses[index] = stroke.lerp(glide_pose, _glide_weight).lerp(hover_pose, _hover_weight)
	var beat := (1.0 - _glide_weight) * (1.0 - _hover_weight)
	surge = 1.0 + 0.25 * strength * sin(TAU * (p - 0.05)) * beat - 0.18 * _glide_weight * (1.0 - _hover_weight)
	_tail = 0.15 * sin(TAU * p) * strength * beat + rudder * 0.5
	var bob := 0.012 * sin(_time * 1.3 + _seed) * _hover_weight
	# Each downstroke lifts the body a little and noses it up.
	return Vector3(0.035 * sin(TAU * p + 0.3) * strength * beat, 0.018 * sin(TAU * p + 0.6) * strength * beat + bob, 0.0)


func _front_stroke(p: float, strength: float) -> Vector3:
	# Downstroke: down and back with the leading edge pitched down (power). Upstroke:
	# up and forward, feathered edge-on to slice through the water.
	if p < DOWNSTROKE:
		var u := smoothstep(0.0, 1.0, p / DOWNSTROKE)
		return Vector3(-0.35 + lerpf(0.55, -0.55, u) * strength, lerpf(0.72, -0.72, u) * strength, lerpf(-0.2, -0.4, u))
	var u := smoothstep(0.0, 1.0, (p - DOWNSTROKE) / (1.0 - DOWNSTROKE))
	return Vector3(-0.35 + lerpf(-0.55, 0.55, u) * strength, lerpf(-0.72, 0.72, u) * strength, -0.3 + sin(u * PI) * 0.9)


func _animate_crawl(delta: float, in_sea: bool, poses: Array[Vector3]) -> Vector3:
	var lift := 0.0
	var pitch := 0.0
	if _rest > 0.0:
		# Catching breath: flippers planted, the body rises and falls.
		_rest -= delta
		surge = 0.0
		for index in range(_flippers.size()):
			poses[index] = Vector3(0.2, -0.1, 0.0) if _front[index] else Vector3(-0.25, -0.08, 0.0)
		return Vector3(0.0, 0.004 * sin(_time * 2.4), 0.0)
	var previous := _crawl_phase
	_crawl_phase += delta / CRAWL_PERIOD
	if _crawl_phase >= 1.0:
		_crawl_phase = fmod(_crawl_phase, 1.0)
		_strokes_until_rest -= 1
		if _strokes_until_rest <= 0:
			_rest = _rng.randf_range(1.0, 1.8)
			_strokes_until_rest = _rng.randi_range(5, 8)
	var q := _crawl_phase
	if previous > q and not in_sea and not reduced_motion:
		_kick_sand()
	var pushing := q < CRAWL_PUSH
	var u := smoothstep(0.0, 1.0, q / CRAWL_PUSH if pushing else (q - CRAWL_PUSH) / (1.0 - CRAWL_PUSH))
	for index in range(_flippers.size()):
		if _front[index]:
			# Green turtles crawl with both front flippers together: reach, plant, heave.
			poses[index] = Vector3(lerpf(0.55, -0.7, u), -0.1 + 0.04 * u, -0.45) if pushing else Vector3(lerpf(-0.7, 0.55, u), -0.08 + 0.3 * sin(PI * u), 0.35 * sin(PI * u))
		else:
			poses[index] = Vector3(lerpf(-0.05, -0.6, u), -0.08, 0.0) if pushing else Vector3(lerpf(-0.6, -0.05, u), -0.08 + 0.18 * sin(PI * u), 0.0)
	if pushing:
		var push := sin(PI * q / CRAWL_PUSH)
		surge = 2.1 * push
		lift = 0.014 * push
		pitch = 0.05 * push
	else:
		surge = 0.12
	return Vector3(pitch, lift, 0.0)


func _animate_struggle(delta: float, poses: Array[Vector3]) -> void:
	_struggle_wait -= delta
	if _struggle_wait <= 0.0:
		_struggle = _rng.randf_range(0.7, 1.3)
		_struggle_wait = _struggle + _rng.randf_range(2.5, 5.5)
	_struggle = maxf(0.0, _struggle - delta)
	var effort := smoothstep(0.0, 0.2, _struggle) * (0.5 if reduced_motion else 1.0)
	var t := _time
	for index in range(_flippers.size()):
		var side := _sides[index]
		if _front[index]:
			poses[index] = Vector3(-0.3 + effort * 0.55 * sin(TAU * 3.1 * t + side * 1.3), -0.25 + effort * 0.5 * sin(TAU * 2.7 * t + side * 2.1 + index), effort * 0.4 * sin(TAU * 3.4 * t))
		else:
			poses[index] = Vector3(-0.25 + effort * 0.3 * sin(TAU * 2.9 * t + side), -0.2 + effort * 0.25 * sin(TAU * 3.3 * t + index), 0.0)
	_tail = effort * 0.3 * sin(TAU * 2.2 * t)
	_roll = effort * 0.07 * sin(t * 17.0)


func _pose_flipper(index: int, pose: Vector3) -> void:
	# pose = (sweep forward, elevation up, feather leading-edge up), about the flipper's
	# own joint: sweep around the body's up axis, elevation around the hinge across the
	# flipper, feather around its long axis.
	var side := _sides[index]
	_flippers[index].basis = Basis(Vector3.UP, (pose.x + _sweep_offsets[index]) * side) * Basis(_hinges[index], pose.y) * Basis(_axes[index], pose.z * side)


func _pose_body(delta: float, speed: float, stroke: Vector3) -> void:
	var swim := 1.0 - _crawl_weight
	var climb := clampf(atan2(velocity.y, maxf(speed, 0.3)), -0.6, 0.6) * swim
	var pitch_target := climb + (0.28 if breathing else 0.0) - (0.12 if grazing else 0.0)
	var bank := clampf(_yaw_rate * speed * 0.35, -0.45, 0.45) * swim * (0.4 if reduced_motion else 1.0)
	_pitch = lerpf(_pitch, pitch_target, 1.0 - exp(-3.0 * delta))
	if gait != Gait.ENTANGLED:
		_roll = lerpf(_roll, bank, 1.0 - exp(-3.0 * delta))
	var motion := 0.4 if reduced_motion else 1.0
	_visual.rotation = Vector3(_pitch + stroke.x * motion, 0.0, _roll)
	_visual.position = Vector3(0.0, stroke.y * motion, 0.0)


func _pose_head(delta: float) -> void:
	# Idle glances; a turtle watching something turns its head toward it.
	var idle := Vector2(0.3 * sin(_time * 0.31 + _seed) + 0.12 * sin(_time * 0.77), 0.08 * sin(_time * 0.43 + _seed))
	var target := idle
	if look_weight > 0.0:
		var local := _body.global_transform.affine_inverse() * look_target - NECK_PIVOT
		var look := Vector2(atan2(-local.x, -local.z), atan2(local.y, Vector2(local.x, local.z).length()))
		target = idle.lerp(look, clampf(look_weight, 0.0, 1.0))
	match gait:
		Gait.CRAWL:
			target.y += 0.28
		Gait.REST:
			target.y += 0.15 + 0.05 * sin(_time * 1.7)
		Gait.ENTANGLED:
			target += Vector2(0.35 * sin(TAU * 1.1 * _time), 0.2 + 0.25 * sin(TAU * 1.7 * _time)) * smoothstep(0.0, 0.2, _struggle)
		_:
			# Swimming, the head stays level while the body pitches with each stroke.
			target.y -= _pitch * 0.5
	if breathing:
		target.y += 0.5
	if grazing:
		# Head down to the bottom with a quick dip and pull for each bite.
		_bite_wait -= delta
		if _bite_wait <= 0.0:
			_bite = 0.35
			_bite_wait = _rng.randf_range(0.8, 1.7)
		_bite = maxf(0.0, _bite - delta)
		target = Vector2(0.25 * sin(_time * 0.6 + _seed), -0.4 - 0.25 * sin(PI * _bite / 0.35))
	target = Vector2(clampf(target.x, -0.9, 0.9), clampf(target.y, -0.7, 0.75))
	# Bites are quick; ordinary glances are slow.
	_head = _head.lerp(target, 1.0 - exp(-(10.0 if grazing else 3.0) * delta))
	_material.set_shader_parameter(&"head_yaw", _head.x)
	_material.set_shader_parameter(&"head_pitch", _head.y)
	_material.set_shader_parameter(&"tail_yaw", _tail)


func _kick_sand() -> void:
	var back := _root.global_basis.z
	for index in range(_flippers.size()):
		var tip := _flippers[index].global_transform * (_axes[index] * _tips[index])
		var count := 3 if _front[index] else 2
		for grain in range(count):
			var throw := back * _rng.randf_range(0.6, 1.3) + Vector3.UP * _rng.randf_range(0.9, 1.6) + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
			sand.emit(tip + Vector3.UP * 0.02, throw, _rng.randf_range(0.01, 0.018), 1.4)


func _face_travel(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.08:
		return
	var rotation_now := _root.global_rotation
	rotation_now.y = lerp_angle(rotation_now.y, atan2(-flat.x, -flat.z), 1.0 - exp(-3.0 * delta))
	_root.global_rotation = rotation_now


func _heading() -> float:
	var forward := -_root.global_basis.z
	return atan2(forward.x, forward.z)
