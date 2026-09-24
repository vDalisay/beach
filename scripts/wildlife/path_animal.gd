class_name PathAnimal
extends Node3D
## Moves wildlife along a smooth intro path and closed loop at a steady speed. The route
## points are joined with centripetal Catmull-Rom curves so animals swim through them
## instead of stopping at each corner. An animator can set `speed_scale` every frame to
## couple travel to flipper strokes or gait.

signal entered_loop

const SAMPLES_PER_SEGMENT := 12

var route_id: StringName
var intro_points: Array[Vector3] = []
var loop_points: Array[Vector3] = []
var speed := 1.5
var speed_scale := 1.0
var reduced_motion := false
var looping := false
## Another component (for example a turtle's behaviour) is steering this node directly.
var paused := false
var _travelling := false
var _closed := false
var _samples := PackedVector3Array()
var _lengths := PackedFloat32Array()
var _cursor := 0
var _distance := 0.0
var _last_position := Vector3.ZERO


func _process(delta: float) -> void:
	if _travelling and not paused and delta > 0.0:
		_advance(speed * maxf(speed_scale, 0.0) * delta)
	var movement := position - _last_position
	_last_position = position
	movement.y = 0.0
	if movement.length_squared() > 0.000001:
		rotation.y = lerp_angle(rotation.y, atan2(movement.x, movement.z), minf(delta * 6.0, 1.0))


func configure(id: StringName, intro: Array[Vector3], loop: Array[Vector3], movement_speed: float, reduce_motion: bool) -> void:
	route_id = id
	intro_points = intro.duplicate()
	loop_points = loop.duplicate()
	speed = maxf(0.1, movement_speed)
	reduced_motion = reduce_motion
	position = intro_points[0] if not intro_points.is_empty() else loop_points[0] if not loop_points.is_empty() else Vector3.ZERO
	_last_position = position


func start_intro() -> void:
	if looping or _travelling or loop_points.is_empty():
		return
	if reduced_motion or intro_points.size() < 2:
		resume_loop()
		return
	# The intro ends heading toward the loop's second point so the hand-over is seamless.
	var after: Vector3 = loop_points[1] if loop_points.size() > 1 else intro_points[intro_points.size() - 1] * 2.0 - intro_points[intro_points.size() - 2]
	_build_curve(intro_points, false, after)
	position = intro_points[0]
	_last_position = position
	_travelling = true


func resume_loop() -> void:
	if loop_points.is_empty() or (looping and _travelling):
		return
	_build_curve(loop_points, true, Vector3.ZERO)
	position = loop_points[0]
	_last_position = position
	looping = true
	paused = false
	_travelling = true
	entered_loop.emit()


## Freezes route progress so another component can steer this animal for a while.
func pause_route() -> void:
	paused = true


## Continues route progress. Callers first bring the animal back to `route_position()`.
func resume_route() -> void:
	paused = false


## Point on the current curve where route progress stopped or will continue from.
func route_position() -> Vector3:
	return _sample_at(_distance) if _travelling else position


func _advance(step: float) -> void:
	var total := _lengths[_lengths.size() - 1]
	_distance += step
	if _closed:
		if _distance >= total:
			_distance = fmod(_distance, total)
			_cursor = 0
	elif _distance >= total:
		_travelling = false
		resume_loop()
		return
	position = _sample_at(_distance)


func _sample_at(distance: float) -> Vector3:
	if _samples.size() < 2:
		return _samples[0] if not _samples.is_empty() else position
	if distance < _lengths[_cursor]:
		_cursor = 0
	while _cursor < _lengths.size() - 2 and _lengths[_cursor + 1] < distance:
		_cursor += 1
	var span := _lengths[_cursor + 1] - _lengths[_cursor]
	var t := 0.0 if span <= 0.0 else clampf((distance - _lengths[_cursor]) / span, 0.0, 1.0)
	return _samples[_cursor].lerp(_samples[_cursor + 1], t)


func _build_curve(points: Array[Vector3], closed: bool, after_end: Vector3) -> void:
	_closed = closed
	_samples = PackedVector3Array()
	_lengths = PackedFloat32Array()
	_cursor = 0
	_distance = 0.0
	var count := points.size()
	var segments := count if closed else count - 1
	for segment in range(segments):
		var p1 := points[segment]
		var p2 := points[(segment + 1) % count]
		var p0 := points[(segment - 1 + count) % count] if closed or segment > 0 else p1 * 2.0 - p2
		var p3 := points[(segment + 2) % count] if closed or segment + 2 < count else after_end
		for step in range(SAMPLES_PER_SEGMENT):
			_samples.append(_catmull_rom(p0, p1, p2, p3, float(step) / SAMPLES_PER_SEGMENT))
	_samples.append(points[0] if closed else points[count - 1])
	var length := 0.0
	_lengths.append(0.0)
	for index in range(1, _samples.size()):
		length += _samples[index - 1].distance_to(_samples[index])
		_lengths.append(length)
	if length <= 0.0:
		_lengths[_lengths.size() - 1] = 0.001


## Centripetal Catmull-Rom (alpha 0.5): no cusps or self-loops between unevenly spaced points.
static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t1 := sqrt(maxf(p0.distance_to(p1), 0.0001))
	var t2 := t1 + sqrt(maxf(p1.distance_to(p2), 0.0001))
	var t3 := t2 + sqrt(maxf(p2.distance_to(p3), 0.0001))
	var u := lerpf(t1, t2, t)
	var a1 := p0 * ((t1 - u) / t1) + p1 * (u / t1)
	var a2 := p1 * ((t2 - u) / (t2 - t1)) + p2 * ((u - t1) / (t2 - t1))
	var a3 := p2 * ((t3 - u) / (t3 - t2)) + p3 * ((u - t2) / (t3 - t2))
	var b1 := a1 * ((t2 - u) / t2) + a2 * (u / t2)
	var b2 := a2 * ((t3 - u) / (t3 - t1)) + a3 * ((u - t1) / (t3 - t1))
	return b1 * ((t2 - u) / (t2 - t1)) + b2 * ((u - t1) / (t2 - t1))
