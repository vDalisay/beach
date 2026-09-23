extends SceneTree

var failures := 0
var lab: Node3D
var player: BeachPlayer


func _init() -> void:
	call_deferred("run")


func run() -> void:
	lab = (load("res://tests/scenes/movement_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	await _physics_frames(5)
	player = lab.get_node("Player") as BeachPlayer
	(lab.get_node("SettingsStore") as SettingsStore).reset_all()

	var straight := await _travel(Vector2(0, -1), 60)
	var diagonal := await _travel(Vector2(1, -1), 60)
	check(absf(straight - diagonal) < 0.08, "diagonal speed is normalized")

	_place(Vector3(0, 0.05, -4.8))
	Input.action_press(&"move_forward")
	await _physics_frames(120)
	Input.action_release(&"move_forward")
	check(player.global_position.z > -6.7, "wall blocks movement")

	_place(Vector3(7, 0.05, 7))
	await _physics_frames(5)
	Input.action_press(&"jump")
	await physics_frame
	Input.action_release(&"jump")
	var peak := player.global_position.y
	for frame in 120:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	check(peak > 0.8 and player.is_on_floor(), "jump rises and lands")

	var ramp_peak := await _forward_peak(Vector3(4, 0.05, 2.9), 85)
	check(ramp_peak > 0.65, "walkable ramp gains height")
	var stair_peak := await _forward_peak(Vector3(-4, 0.05, 2.9), 70)
	check(stair_peak > 0.65, "pier-height stairs traverse their authored ramp collision")

	_place(Vector3(0, 0.05, 1))
	Input.action_press(&"crouch")
	await _physics_frames(30)
	Input.action_release(&"crouch")
	await _physics_frames(30)
	check(player.movement.capsule.height < 1.3, "low ceiling refuses standing")
	_place(Vector3(7, 0.05, 7))
	await _physics_frames(30)
	check(is_equal_approx(player.movement.capsule.height, player.movement.standing_height), "player stands after clearing ceiling")

	_place(Vector3(7, 0.05, 7))
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	Input.parse_input_event(stick)
	await _physics_frames(60)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	check(player.global_position.z < 4.0, "controller stick traverses the lab")

	_send_joy_button(JOY_BUTTON_START, true)
	await process_frame
	await process_frame
	check(paused, "controller pauses")
	_send_joy_button(JOY_BUTTON_START, false)
	await process_frame
	_send_joy_button(JOY_BUTTON_START, true)
	await process_frame
	await process_frame
	check(not paused, "controller resumes")
	_send_joy_button(JOY_BUTTON_START, false)

	var store := lab.get_node("SettingsStore") as SettingsStore
	store.set_value(&"fov", 70.0)
	check(is_equal_approx(player.camera.fov, 70.0), "minimum FOV applies")
	store.set_value(&"fov", 110.0)
	check(is_equal_approx(player.camera.fov, 110.0), "maximum FOV applies")
	check(player.hand_rig.socket_transform(&"left_prop").origin.x < 0.0 and player.hand_rig.socket_transform(&"right_prop").origin.x > 0.0, "hand sockets stay on their intended sides")
	player.enter_swimming()
	check(player.movement.is_swimming and is_zero_approx(player.floor_snap_length), "swim entry disables floor snap")
	player.exit_swimming()
	check(not player.movement.is_swimming and player.floor_snap_length > 0.0, "swim exit restores floor handling")

	print("P04_VALIDATION straight=%.3f diagonal=%.3f jump_peak=%.3f ramp_peak=%.3f stair_peak=%.3f failures=%d" % [straight, diagonal, peak, ramp_peak, stair_peak, failures])
	quit(failures)


func _travel(input: Vector2, frames: int) -> float:
	_place(Vector3(7, 0.05, 7))
	await _physics_frames(5)
	var start := player.global_position
	Input.action_press(&"move_right", input.x)
	Input.action_press(&"move_forward", -input.y)
	await _physics_frames(frames)
	Input.action_release(&"move_right")
	Input.action_release(&"move_forward")
	return Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()


func _forward_peak(start: Vector3, frames: int) -> float:
	_place(start)
	await _physics_frames(5)
	var peak := player.global_position.y
	Input.action_press(&"move_forward")
	for frame in frames:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	Input.action_release(&"move_forward")
	return peak


func _place(position: Vector3) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO


func _physics_frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _send_joy_button(button: JoyButton, pressed_value: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed_value
	Input.parse_input_event(event)


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P04 FAIL: %s" % message)
