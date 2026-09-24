class_name PlayerMovement
extends Node

@export var walk_speed := 3.5
@export var sprint_multiplier := 1.45
@export var crouch_multiplier := 0.5
@export var swim_speed := 2.5
@export var jump_velocity := 5.2
@export var ground_acceleration := 24.0
@export var air_acceleration := 8.0
@export var swim_acceleration := 10.0
@export var standing_height := 1.8
@export var crouching_height := 1.2
@export var standing_eye_height := 1.65
@export var crouching_eye_height := 1.05

var body: CharacterBody3D
var collision_shape: CollisionShape3D
var head: Node3D
var capsule: CapsuleShape3D
var is_crouched := false
var is_swimming := false
var carry_speed_multiplier := 1.0
var swim_boost_multiplier := 1.0
var swim_boost_seconds := 0.0

var _gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func configure(character: CharacterBody3D, shape: CollisionShape3D, camera_head: Node3D) -> void:
	body = character
	collision_shape = shape
	head = camera_head
	capsule = (shape.shape as CapsuleShape3D).duplicate(true) as CapsuleShape3D
	collision_shape.shape = capsule
	capsule.height = standing_height
	collision_shape.position.y = standing_height * 0.5
	head.position.y = standing_eye_height
	body.floor_snap_length = 0.3
	body.floor_max_angle = deg_to_rad(46.0)
	body.floor_stop_on_slope = true


func physics_step(
	move_input: Vector2,
	jump_pressed: bool,
	sprint: bool,
	crouch: bool,
	delta: float,
	swim_up: bool = false,
	swim_down: bool = false
) -> void:
	if body == null:
		return

	_update_crouch(crouch, delta)
	swim_boost_seconds = maxf(0.0, swim_boost_seconds - delta)
	if is_swimming:
		_move_in_water(move_input, swim_up, swim_down, delta)
		return

	if not body.is_on_floor():
		body.velocity.y -= _gravity * delta
	elif jump_pressed:
		body.velocity.y = jump_velocity

	var local_direction := Vector3(move_input.x, 0.0, move_input.y)
	if local_direction.length_squared() > 1.0:
		local_direction = local_direction.normalized()
	var direction := body.global_basis * local_direction
	direction.y = 0.0
	direction = direction.normalized() if not direction.is_zero_approx() else Vector3.ZERO

	var speed := walk_speed * carry_speed_multiplier
	if sprint and not is_crouched:
		speed *= sprint_multiplier
	elif is_crouched:
		speed *= crouch_multiplier
	var target := direction * speed
	var acceleration := ground_acceleration if body.is_on_floor() else air_acceleration
	var horizontal_velocity := Vector3(body.velocity.x, 0.0, body.velocity.z).move_toward(target, acceleration * delta)
	body.velocity.x = horizontal_velocity.x
	body.velocity.z = horizontal_velocity.z
	body.move_and_slide()


func enter_swimming() -> void:
	is_swimming = true
	body.floor_snap_length = 0.0


func exit_swimming() -> void:
	is_swimming = false
	body.floor_snap_length = 0.3


func set_swim_speed(value: float) -> void:
	swim_speed = maxf(value, 0.0)


## Short-lived swim speed bonus, refreshed each frame while the player rides a boost source.
func apply_swim_boost(multiplier: float, seconds: float) -> void:
	swim_boost_multiplier = maxf(multiplier, 1.0)
	swim_boost_seconds = maxf(swim_boost_seconds, seconds)


func is_swim_boosted() -> bool:
	return is_swimming and swim_boost_seconds > 0.0


func set_carry_speed_multiplier(value: float) -> void:
	carry_speed_multiplier = clampf(value, 0.1, 1.0)


func can_stand() -> bool:
	if body == null or capsule == null:
		return false
	var extra_height := standing_height - capsule.height
	if extra_height <= 0.01:
		return true
	var clearance := BoxShape3D.new()
	clearance.size = Vector3(capsule.radius * 1.9, extra_height, capsule.radius * 1.9)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = clearance
	query.transform = Transform3D(body.global_basis, body.global_position + Vector3.UP * (capsule.height + extra_height * 0.5))
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_crouch(requested: bool, delta: float) -> void:
	var target_height := crouching_height if requested else standing_height
	if not requested and not can_stand():
		target_height = crouching_height
	var target_eye := crouching_eye_height if target_height == crouching_height else standing_eye_height
	capsule.height = move_toward(capsule.height, target_height, 3.5 * delta)
	collision_shape.position.y = capsule.height * 0.5
	head.position.y = move_toward(head.position.y, target_eye, 3.5 * delta)
	is_crouched = capsule.height < standing_height - 0.05


func _move_in_water(move_input: Vector2, swim_up: bool, swim_down: bool, delta: float) -> void:
	var local_direction := Vector3(move_input.x, 0.0, move_input.y)
	local_direction.y = float(swim_up) - float(swim_down)
	if local_direction.length_squared() > 1.0:
		local_direction = local_direction.normalized()
	var direction := body.global_basis * Vector3(local_direction.x, 0.0, local_direction.z)
	direction.y = local_direction.y
	var boost := swim_boost_multiplier if swim_boost_seconds > 0.0 else 1.0
	var target := direction.normalized() * swim_speed * carry_speed_multiplier * boost if not direction.is_zero_approx() else Vector3.ZERO
	body.velocity = body.velocity.move_toward(target, swim_acceleration * boost * delta)
	body.move_and_slide()
