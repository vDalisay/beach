class_name InputReader
extends Node

enum Context {
	WORLD,
	RESULTS,
	TABLE,
	BOOKLET,
	MODAL,
}

@export var settings_store: SettingsStore

var context := Context.WORLD
var movement := Vector2.ZERO
var look_delta := Vector2.ZERO
var primary_pressed := false
var throw_pressed := false
var interact_pressed := false
var jump_pressed := false
var sprint_active := false
var crouch_active := false

var _mouse_delta := Vector2.ZERO
var _sprint_toggled := false
var _crouch_toggled := false
var _blocked_actions: Dictionary = {}


func _unhandled_input(event: InputEvent) -> void:
	if context == Context.WORLD and event is InputEventMouseMotion:
		_mouse_delta += event.relative


func sample(delta: float) -> void:
	_release_unblocked_actions()
	if context != Context.WORLD:
		movement = Vector2.ZERO
		look_delta = Vector2.ZERO
		primary_pressed = false
		throw_pressed = false
		interact_pressed = false
		jump_pressed = false
		_mouse_delta = Vector2.ZERO
		return

	var deadzone := float(settings_store.get_value(&"deadzone")) if settings_store else 0.2
	movement = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", deadzone)
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", deadzone)
	var invert := -1.0 if settings_store and bool(settings_store.get_value(&"invert_y")) else 1.0
	var mouse_sensitivity := float(settings_store.get_value(&"mouse_sensitivity")) if settings_store else 0.0025
	var controller_sensitivity := float(settings_store.get_value(&"controller_sensitivity")) if settings_store else 2.5
	look_delta = Vector2(_mouse_delta.x, _mouse_delta.y * invert) * mouse_sensitivity
	look_delta += Vector2(stick.x, stick.y * invert) * controller_sensitivity * delta
	_mouse_delta = Vector2.ZERO

	primary_pressed = just_pressed(&"primary")
	throw_pressed = just_pressed(&"throw")
	interact_pressed = just_pressed(&"interact")
	jump_pressed = just_pressed(&"jump")
	_sprint_toggled = _toggle_value(&"sprint", &"sprint_toggle", _sprint_toggled)
	_crouch_toggled = _toggle_value(&"crouch", &"crouch_toggle", _crouch_toggled)
	sprint_active = _sprint_toggled
	crouch_active = _crouch_toggled


func set_context(next_context: Context) -> void:
	if next_context == context:
		return
	context = next_context
	_mouse_delta = Vector2.ZERO
	_blocked_actions.clear()
	if context == Context.WORLD:
		for action in SettingsStore.REQUIRED_ACTIONS:
			if Input.is_action_pressed(action):
				_blocked_actions[action] = true


func pressed(action: StringName) -> bool:
	return _context_allows(action) and not _blocked_actions.has(action) and Input.is_action_pressed(action)


func just_pressed(action: StringName) -> bool:
	return _context_allows(action) and not _blocked_actions.has(action) and Input.is_action_just_pressed(action)


func _toggle_value(action: StringName, setting: StringName, current: bool) -> bool:
	if settings_store and bool(settings_store.get_value(setting)):
		return not current if just_pressed(action) else current
	return pressed(action)


func _context_allows(action: StringName) -> bool:
	var action_context := SettingsStore.context_for_action(action)
	match context:
		Context.WORLD:
			return action_context == &"world"
		Context.TABLE:
			return action_context == &"table" or action_context == &"modal"
		_:
			return action_context == &"modal"


func _release_unblocked_actions() -> void:
	for action in _blocked_actions.keys():
		if not Input.is_action_pressed(action):
			_blocked_actions.erase(action)
