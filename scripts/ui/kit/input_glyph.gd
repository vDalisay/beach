class_name InputGlyph
extends Control
## Draws the icon for an action's first binding on the active prompt device, using the Synty
## Interface input icons: the mouse with the pressed button marked, a keycap with the key's name,
## Xbox face buttons, bumpers, triggers, D-pad and sticks. Every glyph gets the navy sticker rim
## so it reads on sand, sea and paper alike. It follows device switches and rebinding live.

const P := preload("res://scripts/ui/kit/ui_palette.gd")
const ROOT := "res://art/synty/ui/input/ICON_Input_%s_Underlay.png"
const KEYCAP := "PC_Button"

@export var action: StringName:
	set(value):
		action = value
		_rebuild()
@export var glyph_height := 26.0:
	set(value):
		glyph_height = value
		_rebuild()
## Paper and dark cards want the glyph without the navy rim doubling their own border.
@export var rimmed := true

var store: SettingsStore
var _texture: Texture2D
var _cap_text := ""
var _font: Font = P.FONT_DISPLAY


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func configure(settings: SettingsStore, action_name: StringName) -> void:
	if store != settings and store != null:
		if store.prompt_device_changed.is_connected(_on_device_changed):
			store.prompt_device_changed.disconnect(_on_device_changed)
		if store.bindings_changed.is_connected(_rebuild):
			store.bindings_changed.disconnect(_rebuild)
	store = settings
	if store != null:
		if not store.prompt_device_changed.is_connected(_on_device_changed):
			store.prompt_device_changed.connect(_on_device_changed)
		if not store.bindings_changed.is_connected(_rebuild):
			store.bindings_changed.connect(_rebuild)
	action = action_name


## The binding as words, for checks, tooltips and screen readers.
func text() -> String:
	return store.binding_text(action) if store != null else str(action)


func _on_device_changed(_device: SettingsStore.PromptDevice) -> void:
	_rebuild()


func _rebuild() -> void:
	_texture = null
	_cap_text = ""
	var event := first_event(store, action)
	if event != null:
		var icon := icon_name(event)
		if icon.is_empty():
			_cap_text = key_label(event)
			_texture = _load(KEYCAP)
		else:
			_texture = _load(icon)
	elif not str(action).is_empty():
		_cap_text = "?"
		_texture = _load(KEYCAP)
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	if _texture == null:
		return Vector2.ZERO
	var height := glyph_height
	if not _cap_text.is_empty():
		var font_size := _cap_font_size()
		var text_width := _font.get_string_size(_cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return Vector2(maxf(height, text_width + height * 0.62), height)
	var aspect := float(_texture.get_width()) / maxf(float(_texture.get_height()), 1.0)
	return Vector2(height * aspect, height)


func _cap_font_size() -> int:
	return maxi(8, roundi(glyph_height * (0.46 if _cap_text.length() <= 2 else 0.36)))


func _draw() -> void:
	if _texture == null:
		return
	var box := Rect2(Vector2.ZERO, _get_minimum_size())
	box.position = (size - box.size) * 0.5
	if _cap_text.is_empty():
		_draw_rimmed(box, func(rect: Rect2, tint: Color) -> void: draw_texture_rect(_texture, rect, false, tint))
		return
	# A keycap stretched to the label: both rounded ends from the square cap, the middle stretched.
	_draw_rimmed(box, func(rect: Rect2, tint: Color) -> void: _draw_cap(rect, tint))
	var font_size := _cap_font_size()
	var text_size := _font.get_string_size(_cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := box.position.y + (box.size.y - _font.get_height(font_size)) * 0.5 + _font.get_ascent(font_size) - glyph_height * 0.03
	draw_string(_font, Vector2(box.position.x + (box.size.x - text_size.x) * 0.5, baseline), _cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, P.NAVY)


func _draw_rimmed(rect: Rect2, painter: Callable) -> void:
	if rimmed:
		var r := maxf(glyph_height * 0.06, 1.2)
		painter.call(Rect2(rect.position + Vector2(0.0, r * 1.6), rect.size), Color(P.NAVY, 0.45))
		for offset: Vector2 in [Vector2(-r, 0), Vector2(r, 0), Vector2(0, -r), Vector2(0, r)]:
			painter.call(Rect2(rect.position + offset, rect.size), P.NAVY)
	painter.call(rect, Color.WHITE)


func _draw_cap(rect: Rect2, tint: Color) -> void:
	var tw := float(_texture.get_width())
	var th := float(_texture.get_height())
	if rect.size.x <= rect.size.y + 0.5:
		draw_texture_rect(_texture, rect, false, tint)
		return
	var edge := rect.size.y * 0.5
	var src_edge := tw * 0.5
	draw_texture_rect_region(_texture, Rect2(rect.position, Vector2(edge, rect.size.y)), Rect2(0, 0, src_edge * 0.98, th), tint)
	draw_texture_rect_region(_texture, Rect2(rect.position + Vector2(edge, 0), Vector2(rect.size.x - edge * 2.0, rect.size.y)), Rect2(src_edge * 0.98, 0, tw * 0.04, th), tint)
	draw_texture_rect_region(_texture, Rect2(rect.end.x - edge, rect.position.y, edge, rect.size.y), Rect2(src_edge * 1.02, 0, src_edge * 0.98, th), tint)


static func _load(icon: String) -> Texture2D:
	var path := ROOT % icon
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The first binding of `action` for the store's prompt device (keyboard/mouse or controller).
static func first_event(settings: SettingsStore, action_name: StringName) -> InputEvent:
	if str(action_name).is_empty() or not InputMap.has_action(action_name):
		return null
	var wants_controller := settings != null and settings.prompt_device == SettingsStore.PromptDevice.CONTROLLER
	for event in InputMap.action_get_events(action_name):
		if SettingsStore.is_controller_event(event) == wants_controller:
			return event
	return null


## The staged icon for `event`, or "" when it is drawn as a keycap with a label.
static func icon_name(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "PC_MouseColor_Left"
			MOUSE_BUTTON_RIGHT: return "PC_MouseColor_Right"
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN: return "PC_MouseColor_Middle"
		return "PC_Mouse_Master"
	if event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A: return "Xbox_ButtonColor_A"
			JOY_BUTTON_B: return "Xbox_ButtonColor_B"
			JOY_BUTTON_X: return "Xbox_ButtonColor_X"
			JOY_BUTTON_Y: return "Xbox_ButtonColor_Y"
			JOY_BUTTON_LEFT_SHOULDER: return "Xbox_Button_LB"
			JOY_BUTTON_RIGHT_SHOULDER: return "Xbox_Button_RB"
			JOY_BUTTON_START: return "Xbox_Button_Menu"
			JOY_BUTTON_BACK: return "Xbox_Button_Share"
			JOY_BUTTON_GUIDE: return "Xbox_Button_Home"
			JOY_BUTTON_LEFT_STICK: return "Stick_L3_01"
			JOY_BUTTON_RIGHT_STICK: return "Stick_R3_01"
			JOY_BUTTON_DPAD_UP: return "Xbox_DpadColor_Up"
			JOY_BUTTON_DPAD_DOWN: return "Xbox_DpadColor_Down"
			JOY_BUTTON_DPAD_LEFT: return "Xbox_DpadColor_Left"
			JOY_BUTTON_DPAD_RIGHT: return "Xbox_DpadColor_Right"
		return "Xbox_Button_Master"
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var negative := motion.axis_value < 0.0
		match motion.axis:
			JOY_AXIS_TRIGGER_LEFT: return "Xbox_Button_LT"
			JOY_AXIS_TRIGGER_RIGHT: return "Xbox_Button_RT"
			JOY_AXIS_LEFT_X: return "Stick_Left_Left" if negative else "Stick_Left_Right"
			JOY_AXIS_LEFT_Y: return "Stick_Left_Up" if negative else "Stick_Left_Down"
			JOY_AXIS_RIGHT_X: return "Stick_Right_Left" if negative else "Stick_Right_Right"
			JOY_AXIS_RIGHT_Y: return "Stick_Right_Up" if negative else "Stick_Right_Down"
		return "Stick_Master_01"
	return ""


## Short keycap label for a key event: "E", "SHIFT", "ESC", "↑".
static func key_label(event: InputEvent) -> String:
	if not event is InputEventKey:
		return event.as_text().to_upper()
	var key := event as InputEventKey
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	match code:
		KEY_ESCAPE: return "ESC"
		KEY_SHIFT: return "SHIFT"
		KEY_CTRL: return "CTRL"
		KEY_ALT: return "ALT"
		KEY_SPACE: return "SPACE"
		KEY_ENTER, KEY_KP_ENTER: return "ENTER"
		KEY_TAB: return "TAB"
		KEY_BACKSPACE: return "BKSP"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
	# The key's printed label on the player's layout (AZERTY shows A for physical Q); a display
	# server without layout support (headless) falls back to the US label.
	var layout_aware := key.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless"
	var label := OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(code) if layout_aware else code)
	return label.to_upper() if not label.is_empty() else key.as_text().to_upper()
