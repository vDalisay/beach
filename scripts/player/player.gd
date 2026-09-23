class_name BeachPlayer
extends CharacterBody3D

signal pause_changed(paused: bool)
signal booklet_requested
signal scanner_requested

@export var input_reader: InputReader
@export var movement: PlayerMovement
@export var hand_rig: HandRig
@export var interactor: PlayerInteractor
@export var carry: PlayerCarry

@onready var collision_shape: CollisionShape3D = %CollisionShape
@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera

var settings_store: SettingsStore
var input_enabled := true
var pitch_limit := deg_to_rad(88.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	movement.configure(self, collision_shape, head)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func configure(settings: SettingsStore, run_session: RunSession = null) -> void:
	settings_store = settings
	input_reader.settings_store = settings
	_apply_fov()
	if run_session != null:
		interactor.configure(run_session)
		carry.configure(run_session, self, interactor, hand_rig, camera, movement)
	if not settings.settings_changed.is_connected(_on_setting_changed):
		settings.settings_changed.connect(_on_setting_changed)


func _physics_process(delta: float) -> void:
	if not input_enabled or get_tree().paused:
		return
	input_reader.sample(delta)
	_apply_look(input_reader.look_delta)
	movement.physics_step(
		input_reader.movement,
		input_reader.jump_pressed,
		input_reader.sprint_active,
		input_reader.crouch_active,
		delta,
		input_reader.pressed(&"jump"),
		input_reader.pressed(&"crouch")
	)
	interactor.update_target()
	if input_reader.primary_pressed:
		var session := interactor.session
		if session != null and session.sand_cleaner != null and session.sand_cleaner.is_active():
			session.sand_cleaner.try_click()
		elif session != null and session.metal_detector != null and session.metal_detector.is_active():
			session.metal_detector.try_click()
		elif session != null and session.rescue_knife != null and session.rescue_knife.is_active():
			session.rescue_knife.try_click()
		elif session == null or session.vacuum_tool == null or not session.vacuum_tool.is_active():
			interactor.request_primary()
	if input_reader.interact_pressed:
		interactor.request_interact()
	if input_reader.throw_pressed:
		interactor.request_throw()
	if input_reader.just_pressed(&"select_held_prop"):
		carry.cycle_selected()
	if input_reader.just_pressed(&"switch_tool"):
		carry.request_tool_switch()
	if input_reader.just_pressed(&"booklet"):
		booklet_requested.emit()
	if input_reader.just_pressed(&"scanner_pulse"):
		scanner_requested.emit()


func _input(event: InputEvent) -> void:
	if not input_enabled or not event.is_action_pressed(&"pause") or event.is_echo():
		return
	set_paused(not get_tree().paused)
	get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	input_reader.set_context(InputReader.Context.MODAL if paused else InputReader.Context.WORLD)
	if paused:
		interactor.clear_target()
	pause_changed.emit(paused)


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO
		interactor.clear_target()


func enter_swimming() -> void:
	movement.enter_swimming()


func exit_swimming() -> void:
	movement.exit_swimming()


func set_swim_speed(value: float) -> void:
	movement.set_swim_speed(value)


func _apply_look(delta_radians: Vector2) -> void:
	rotate_y(-delta_radians.x)
	head.rotation.x = clampf(head.rotation.x - delta_radians.y, -pitch_limit, pitch_limit)


func _apply_fov() -> void:
	if settings_store:
		camera.fov = float(settings_store.get_value(&"fov"))


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key == &"fov":
		_apply_fov()
