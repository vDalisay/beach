class_name SettingsStore
extends Node

signal settings_changed(key: StringName, value: Variant)
signal prompt_device_changed(device: PromptDevice)
signal controller_disconnected(device_id: int)
signal controller_reconnected(device_id: int)
signal bindings_changed

enum PromptDevice {
	KEYBOARD_MOUSE,
	CONTROLLER,
}

const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_VALUES := {
	&"mouse_sensitivity": 0.0025,
	&"controller_sensitivity": 2.5,
	&"deadzone": 0.2,
	&"invert_y": false,
	&"fov": 85.0,
	&"ui_scale": 1.0,
	&"reduced_motion": false,
	&"sprint_toggle": false,
	&"crouch_toggle": false,
}
const REQUIRED_ACTIONS := [
	&"move_left", &"move_right", &"move_forward", &"move_back",
	&"look_left", &"look_right", &"look_up", &"look_down",
	&"primary", &"throw", &"interact", &"jump", &"crouch", &"sprint",
	&"switch_tool", &"select_held_prop", &"booklet", &"scanner_pulse", &"pause",
	&"table_bin_previous", &"table_bin_next",
	&"table_bin_1", &"table_bin_2", &"table_bin_3", &"table_bin_4",
	&"table_focus_left", &"table_focus_right", &"table_focus_up", &"table_focus_down",
	&"table_select", &"table_inspect_bin", &"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"ui_accept", &"ui_cancel",
]
const REMAPPABLE_ACTIONS := [
	&"move_left", &"move_right", &"move_forward", &"move_back",
	&"primary", &"throw", &"interact", &"jump", &"crouch", &"sprint",
	&"switch_tool", &"select_held_prop", &"booklet", &"scanner_pulse", &"pause",
	&"table_bin_previous", &"table_bin_next",
	&"table_focus_left", &"table_focus_right", &"table_focus_up", &"table_focus_down",
	&"table_select", &"table_inspect_bin", &"ui_accept", &"ui_cancel",
]

@export_file("*.cfg") var settings_path := DEFAULT_SETTINGS_PATH

var prompt_device := PromptDevice.KEYBOARD_MOUSE
var values := DEFAULT_VALUES.duplicate()
var _project_defaults: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_project_defaults()
	load_settings()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	note_input(event)


func get_value(key: StringName) -> Variant:
	return values.get(key, DEFAULT_VALUES.get(key))


func set_value(key: StringName, value: Variant) -> bool:
	if not DEFAULT_VALUES.has(key):
		return false

	match key:
		&"mouse_sensitivity":
			value = clampf(float(value), 0.0005, 0.01)
		&"controller_sensitivity":
			value = clampf(float(value), 0.5, 6.0)
		&"deadzone":
			value = clampf(float(value), 0.05, 0.5)
		&"fov":
			value = clampf(float(value), 70.0, 110.0)
		&"ui_scale":
			value = clampf(float(value), 1.0, 1.5)
		_:
			value = bool(value)

	values[key] = value
	_apply_display_settings()
	settings_changed.emit(key, value)
	return true


func load_settings() -> Error:
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error

	for key_value in DEFAULT_VALUES:
		var key := key_value as StringName
		set_value(key, config.get_value("settings", str(key), DEFAULT_VALUES[key]))

	for action in REQUIRED_ACTIONS:
		if not config.has_section_key("bindings", str(action)):
			continue
		var encoded_events: Variant = config.get_value("bindings", str(action))
		if encoded_events is not Array:
			continue
		var decoded_events: Array[InputEvent] = []
		for encoded_event in encoded_events as Array:
			if encoded_event is Dictionary:
				var event := event_from_dict(encoded_event as Dictionary)
				if event != null:
					decoded_events.append(event)
		if not decoded_events.is_empty():
			InputMap.action_erase_events(action)
			for event in decoded_events:
				InputMap.action_add_event(action, event)

	_apply_display_settings()
	bindings_changed.emit()
	return OK


func save_settings() -> Error:
	var config := ConfigFile.new()
	for key_value in DEFAULT_VALUES:
		var key := key_value as StringName
		config.set_value("settings", str(key), values[key])
	for action in REQUIRED_ACTIONS:
		var encoded_events: Array[Dictionary] = []
		for event in InputMap.action_get_events(action):
			var encoded := event_to_dict(event)
			if not encoded.is_empty():
				encoded_events.append(encoded)
		config.set_value("bindings", str(action), encoded_events)
	return config.save(settings_path)


func reset_all() -> void:
	values = DEFAULT_VALUES.duplicate()
	for action in REQUIRED_ACTIONS:
		InputMap.action_erase_events(action)
		for event in _project_defaults.get(action, []):
			InputMap.action_add_event(action, (event as InputEvent).duplicate(true))
	_apply_display_settings()
	for key_value in DEFAULT_VALUES:
		var key := key_value as StringName
		settings_changed.emit(key, values[key])
	bindings_changed.emit()


func rebind(action: StringName, event: InputEvent) -> PackedStringArray:
	if not REMAPPABLE_ACTIONS.has(action) or not is_bindable_event(event):
		return PackedStringArray()

	var normalized := _normalized_event(event)
	var conflicts := binding_conflicts(action, normalized)
	for conflict in conflicts:
		_remove_matching_event(StringName(conflict), normalized)

	var controller_event := is_controller_event(normalized)
	for existing in InputMap.action_get_events(action):
		if is_controller_event(existing) == controller_event:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, normalized)
	bindings_changed.emit()
	return conflicts


func binding_conflicts(action: StringName, event: InputEvent) -> PackedStringArray:
	var conflicts := PackedStringArray()
	var context := context_for_action(action)
	for other in REMAPPABLE_ACTIONS:
		if other == action or context_for_action(other) != context:
			continue
		for existing in InputMap.action_get_events(other):
			if event.is_match(existing, true):
				conflicts.append(str(other))
				break
	return conflicts


func binding_text(action: StringName, device: PromptDevice = prompt_device) -> String:
	var labels := PackedStringArray()
	var wants_controller := device == PromptDevice.CONTROLLER
	for event in InputMap.action_get_events(action):
		if is_controller_event(event) == wants_controller:
			labels.append(event.as_text())
	return " / ".join(labels) if not labels.is_empty() else "Unbound"


func note_input(event: InputEvent) -> void:
	var next_device := prompt_device
	if event is InputEventJoypadButton and event.pressed:
		next_device = PromptDevice.CONTROLLER
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= float(get_value(&"deadzone")):
		next_device = PromptDevice.CONTROLLER
	elif event is InputEventKey and event.pressed and not event.echo:
		next_device = PromptDevice.KEYBOARD_MOUSE
	elif event is InputEventMouseButton and event.pressed:
		next_device = PromptDevice.KEYBOARD_MOUSE
	elif event is InputEventMouseMotion and event.relative.length_squared() >= 4.0:
		next_device = PromptDevice.KEYBOARD_MOUSE

	if next_device != prompt_device:
		prompt_device = next_device
		prompt_device_changed.emit(prompt_device)


func is_bindable_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.physical_keycode != KEY_NONE
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= float(get_value(&"deadzone"))
	return false


static func is_controller_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func context_for_action(action: StringName) -> StringName:
	if str(action).begins_with("table_"):
		return &"table"
	if str(action).begins_with("ui_"):
		return &"modal"
	return &"world"


static func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"physical_keycode": event.physical_keycode,
			"alt": event.alt_pressed,
			"ctrl": event.ctrl_pressed,
			"meta": event.meta_pressed,
			"shift": event.shift_pressed,
		}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button_index": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": event.axis, "axis_value": signf(event.axis_value)}
	return {}


static func event_from_dict(data: Dictionary) -> InputEvent:
	match str(data.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data.get("physical_keycode", KEY_NONE)) as Key
			key.alt_pressed = bool(data.get("alt", false))
			key.ctrl_pressed = bool(data.get("ctrl", false))
			key.meta_pressed = bool(data.get("meta", false))
			key.shift_pressed = bool(data.get("shift", false))
			return key
		"mouse_button":
			var mouse_button := InputEventMouseButton.new()
			mouse_button.button_index = int(data.get("button_index", MOUSE_BUTTON_NONE)) as MouseButton
			return mouse_button
		"joy_button":
			var joy_button := InputEventJoypadButton.new()
			joy_button.button_index = int(data.get("button_index", JOY_BUTTON_INVALID)) as JoyButton
			return joy_button
		"joy_axis":
			var joy_axis := InputEventJoypadMotion.new()
			joy_axis.axis = int(data.get("axis", JOY_AXIS_INVALID)) as JoyAxis
			joy_axis.axis_value = signf(float(data.get("axis_value", 0.0)))
			return joy_axis
	return null


func _capture_project_defaults() -> void:
	for action in REQUIRED_ACTIONS:
		var setting: Variant = ProjectSettings.get_setting("input/%s" % action, {})
		var events: Array[InputEvent] = []
		if setting is Dictionary:
			for event in (setting as Dictionary).get("events", []):
				if event is InputEvent:
					events.append((event as InputEvent).duplicate(true))
		_project_defaults[action] = events


func _normalized_event(event: InputEvent) -> InputEvent:
	var normalized := event.duplicate(true) as InputEvent
	normalized.device = -1
	if normalized is InputEventJoypadMotion:
		normalized.axis_value = signf(normalized.axis_value)
	return normalized


func _remove_matching_event(action: StringName, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if event.is_match(existing, true):
			InputMap.action_erase_event(action, existing)


func _apply_display_settings() -> void:
	if is_inside_tree():
		get_tree().root.content_scale_factor = float(get_value(&"ui_scale"))


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if not connected and prompt_device == PromptDevice.CONTROLLER:
		controller_disconnected.emit(device_id)
	elif connected and prompt_device == PromptDevice.CONTROLLER:
		controller_reconnected.emit(device_id)
