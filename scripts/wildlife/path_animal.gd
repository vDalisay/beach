class_name PathAnimal
extends Node3D

signal entered_loop

var route_id: StringName
var intro_points: Array[Vector3] = []
var loop_points: Array[Vector3] = []
var speed := 1.5
var reduced_motion := false
var looping := false
var _route_tween: Tween
var _last_position := Vector3.ZERO


func _process(delta: float) -> void:
	var movement := position - _last_position
	_last_position = position
	movement.y = 0.0
	if movement.length_squared() > 0.000001:
		rotation.y = lerp_angle(rotation.y, atan2(movement.x, movement.z), minf(delta * 8.0, 1.0))


func configure(id: StringName, intro: Array[Vector3], loop: Array[Vector3], movement_speed: float, reduce_motion: bool) -> void:
	route_id = id
	intro_points = intro.duplicate()
	loop_points = loop.duplicate()
	speed = maxf(0.1, movement_speed)
	reduced_motion = reduce_motion
	position = intro_points[0] if not intro_points.is_empty() else loop_points[0] if not loop_points.is_empty() else Vector3.ZERO
	_last_position = position


func start_intro() -> void:
	if looping or (_route_tween != null and _route_tween.is_running()) or loop_points.is_empty():
		return
	if reduced_motion or intro_points.size() < 2:
		resume_loop()
		return
	position = intro_points[0]
	_last_position = position
	_route_tween = create_tween().set_trans(Tween.TRANS_SINE)
	for index in range(1, intro_points.size()):
		_route_tween.tween_property(self, "position", intro_points[index], intro_points[index - 1].distance_to(intro_points[index]) / speed)
	_route_tween.tween_callback(resume_loop)


func resume_loop() -> void:
	if loop_points.is_empty() or (looping and _route_tween != null and _route_tween.is_running()):
		return
	if _route_tween != null and _route_tween.is_running():
		_route_tween.kill()
	position = loop_points[0]
	_last_position = position
	looping = true
	entered_loop.emit()
	_route_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	for index in range(1, loop_points.size()):
		_route_tween.tween_property(self, "position", loop_points[index], loop_points[index - 1].distance_to(loop_points[index]) / speed)
	if loop_points.size() > 1:
		_route_tween.tween_property(self, "position", loop_points[0], loop_points.back().distance_to(loop_points[0]) / speed)
