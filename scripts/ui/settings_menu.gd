class_name SettingsMenu
extends PanelContainer

signal closed

const PRESET_ORDER: Array[StringName] = [&"low", &"medium", &"high", &"ultra"]
const PRESET_NAMES := ["Low", "Medium", "High", "Ultra", "Custom"]
const MSAA_NAMES := ["Off", "2×", "4×", "8×"]
const SHADOW_NAMES := ["Off", "Low", "Medium", "High", "Ultra"]

@onready var tabs: TabContainer = %Tabs
@onready var controls_tab: ScrollContainer = %Controls
@onready var graphics_tab: ScrollContainer = %Graphics
@onready var device_label: Label = %DeviceLabel
@onready var mouse_sensitivity: HSlider = %MouseSensitivity
@onready var mouse_sensitivity_value: Label = %MouseSensitivityValue
@onready var controller_sensitivity: HSlider = %ControllerSensitivity
@onready var controller_sensitivity_value: Label = %ControllerSensitivityValue
@onready var deadzone: HSlider = %Deadzone
@onready var deadzone_value: Label = %DeadzoneValue
@onready var fov: HSlider = %Fov
@onready var fov_value: Label = %FovValue
@onready var ui_scale: HSlider = %UiScale
@onready var ui_scale_value: Label = %UiScaleValue
@onready var invert_y: CheckButton = %InvertY
@onready var reduced_motion: CheckButton = %ReducedMotion
@onready var sprint_toggle: CheckButton = %SprintToggle
@onready var crouch_toggle: CheckButton = %CrouchToggle
@onready var bindings: VBoxContainer = %Bindings
@onready var graphics_preset: OptionButton = %GraphicsPreset
@onready var msaa: OptionButton = %Msaa
@onready var render_scale: HSlider = %RenderScale
@onready var render_scale_value: Label = %RenderScaleValue
@onready var shadow_quality: OptionButton = %ShadowQuality
@onready var view_distance: HSlider = %ViewDistance
@onready var view_distance_value: Label = %ViewDistanceValue
@onready var ssao: CheckButton = %Ssao
@onready var glow: CheckButton = %Glow
@onready var vsync: CheckButton = %Vsync
@onready var frame_cap: OptionButton = %FrameCap
@onready var notice_label: Label = %NoticeLabel
@onready var reset_button: Button = %ResetButton
@onready var close_button: Button = %CloseButton

var store: SettingsStore
var _capture_action := StringName()
var _binding_buttons: Dictionary = {}
var _was_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _syncing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_sensitivity.value_changed.connect(_on_slider_changed.bind(&"mouse_sensitivity", mouse_sensitivity_value))
	controller_sensitivity.value_changed.connect(_on_slider_changed.bind(&"controller_sensitivity", controller_sensitivity_value))
	deadzone.value_changed.connect(_on_slider_changed.bind(&"deadzone", deadzone_value))
	fov.value_changed.connect(_on_slider_changed.bind(&"fov", fov_value))
	ui_scale.value_changed.connect(_on_slider_changed.bind(&"ui_scale", ui_scale_value))
	render_scale.value_changed.connect(_on_slider_changed.bind(&"render_scale", render_scale_value))
	view_distance.value_changed.connect(_on_slider_changed.bind(&"view_distance", view_distance_value))
	invert_y.toggled.connect(_on_toggle_changed.bind(&"invert_y"))
	reduced_motion.toggled.connect(_on_toggle_changed.bind(&"reduced_motion"))
	sprint_toggle.toggled.connect(_on_toggle_changed.bind(&"sprint_toggle"))
	crouch_toggle.toggled.connect(_on_toggle_changed.bind(&"crouch_toggle"))
	ssao.toggled.connect(_on_toggle_changed.bind(&"ssao"))
	glow.toggled.connect(_on_toggle_changed.bind(&"glow"))
	vsync.toggled.connect(_on_toggle_changed.bind(&"vsync"))
	for label in PRESET_NAMES:
		graphics_preset.add_item(label)
	# Custom only reports a mixed selection; it cannot be picked.
	graphics_preset.set_item_disabled(PRESET_NAMES.size() - 1, true)
	for label in MSAA_NAMES:
		msaa.add_item(label)
	for label in SHADOW_NAMES:
		shadow_quality.add_item(label)
	for cap in SettingsStore.FRAME_CAPS:
		frame_cap.add_item("Unlimited" if cap == 0 else "%d fps" % cap)
	graphics_preset.item_selected.connect(_on_preset_selected)
	msaa.item_selected.connect(_on_option_changed.bind(&"msaa"))
	shadow_quality.item_selected.connect(_on_option_changed.bind(&"shadow_quality"))
	frame_cap.item_selected.connect(func(index: int) -> void: _on_option_changed(SettingsStore.FRAME_CAPS[index], &"max_fps"))
	tabs.tab_changed.connect(func(_tab: int) -> void:
		notice_label.text = _tab_notice()
		if visible:
			_link_focus()
	)
	reset_button.pressed.connect(_reset_all)
	close_button.pressed.connect(close_menu)
	hide()


func open_menu(settings: SettingsStore) -> void:
	store = settings
	_was_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	notice_label.text = _tab_notice()
	_sync_controls()
	_build_bindings()
	if not store.prompt_device_changed.is_connected(_on_prompt_device_changed):
		store.prompt_device_changed.connect(_on_prompt_device_changed)
	show()
	_link_focus()
	call_deferred("_focus_first")


func close_menu() -> void:
	if not visible:
		return
	_capture_action = StringName()
	store.save_settings()
	hide()
	get_tree().paused = _was_paused
	Input.mouse_mode = _previous_mouse_mode
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _capture_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			_capture_action = StringName()
			notice_label.text = "Binding unchanged."
			get_viewport().set_input_as_handled()
			return
		if store.is_bindable_event(event):
			var block_reason := store.binding_block_reason(_capture_action, event)
			if not block_reason.is_empty():
				notice_label.text = block_reason
				get_viewport().set_input_as_handled()
				return
			var conflicts := store.rebind(_capture_action, event)
			notice_label.text = "Replaced %s." % ", ".join(conflicts) if not conflicts.is_empty() else "Binding updated."
			_capture_action = StringName()
			store.save_settings()
			_refresh_bindings()
			_link_focus()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		# Shoulder buttons switch tabs, as in most controller menus.
		tabs.current_tab = posmod(tabs.current_tab + (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1), tabs.get_tab_count())
		call_deferred("_focus_first")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_menu()
		get_viewport().set_input_as_handled()


func _sync_controls() -> void:
	_syncing = true
	mouse_sensitivity.value = float(store.get_value(&"mouse_sensitivity"))
	controller_sensitivity.value = float(store.get_value(&"controller_sensitivity"))
	deadzone.value = float(store.get_value(&"deadzone"))
	fov.value = float(store.get_value(&"fov"))
	ui_scale.value = float(store.get_value(&"ui_scale"))
	invert_y.button_pressed = bool(store.get_value(&"invert_y"))
	reduced_motion.button_pressed = bool(store.get_value(&"reduced_motion"))
	sprint_toggle.button_pressed = bool(store.get_value(&"sprint_toggle"))
	crouch_toggle.button_pressed = bool(store.get_value(&"crouch_toggle"))
	msaa.select(int(store.get_value(&"msaa")))
	render_scale.value = float(store.get_value(&"render_scale"))
	shadow_quality.select(int(store.get_value(&"shadow_quality")))
	view_distance.value = float(store.get_value(&"view_distance"))
	ssao.button_pressed = bool(store.get_value(&"ssao"))
	glow.button_pressed = bool(store.get_value(&"glow"))
	vsync.button_pressed = bool(store.get_value(&"vsync"))
	frame_cap.select(maxi(SettingsStore.FRAME_CAPS.find(int(store.get_value(&"max_fps"))), 0))
	_syncing = false
	_update_value_labels()
	_sync_preset()


func _sync_preset() -> void:
	var preset := store.graphics_preset()
	graphics_preset.select(PRESET_ORDER.find(preset) if preset != &"custom" else PRESET_NAMES.size() - 1)


func _build_bindings() -> void:
	for child in bindings.get_children():
		child.queue_free()
	_binding_buttons.clear()
	device_label.text = "Showing: %s" % ("Controller" if store.prompt_device == SettingsStore.PromptDevice.CONTROLLER else "Keyboard & mouse")
	for action in SettingsStore.REMAPPABLE_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(action).replace("_", " ").capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.custom_minimum_size.x = 300.0
		button.text = store.binding_text(action)
		button.pressed.connect(_begin_capture.bind(action, button))
		row.add_child(label)
		row.add_child(button)
		bindings.add_child(row)
		_binding_buttons[action] = button


func _refresh_bindings() -> void:
	device_label.text = "Showing: %s" % ("Controller" if store.prompt_device == SettingsStore.PromptDevice.CONTROLLER else "Keyboard & mouse")
	for action in _binding_buttons:
		(_binding_buttons[action] as Button).text = store.binding_text(action)


func _begin_capture(action: StringName, button: Button) -> void:
	_capture_action = action
	button.text = "Press a key, button or axis…"
	notice_label.text = "Escape cancels. Conflicts are replaced only in this context."


func _reset_all() -> void:
	store.reset_all()
	store.save_settings()
	_sync_controls()
	_refresh_bindings()
	notice_label.text = "Defaults restored."


func _on_slider_changed(value: float, key: StringName, value_label: Label) -> void:
	if _syncing:
		return
	store.set_value(key, value)
	value_label.text = _format_value(key, value)
	_sync_preset()


func _on_toggle_changed(pressed: bool, key: StringName) -> void:
	if not _syncing:
		store.set_value(key, pressed)
		_sync_preset()


func _on_option_changed(value: int, key: StringName) -> void:
	if not _syncing:
		store.set_value(key, value)
		_sync_preset()


func _on_preset_selected(index: int) -> void:
	if _syncing or index >= PRESET_ORDER.size():
		return
	store.apply_graphics_preset(PRESET_ORDER[index])
	_sync_controls()
	notice_label.text = "%s graphics applied." % PRESET_NAMES[index]


func _on_prompt_device_changed(_device: SettingsStore.PromptDevice) -> void:
	_refresh_bindings()


func _update_value_labels() -> void:
	mouse_sensitivity_value.text = _format_value(&"mouse_sensitivity", mouse_sensitivity.value)
	controller_sensitivity_value.text = _format_value(&"controller_sensitivity", controller_sensitivity.value)
	deadzone_value.text = _format_value(&"deadzone", deadzone.value)
	fov_value.text = _format_value(&"fov", fov.value)
	ui_scale_value.text = _format_value(&"ui_scale", ui_scale.value)
	render_scale_value.text = _format_value(&"render_scale", render_scale.value)
	view_distance_value.text = _format_value(&"view_distance", view_distance.value)


func _format_value(key: StringName, value: float) -> String:
	match key:
		&"mouse_sensitivity":
			return "%.4f" % value
		&"deadzone", &"ui_scale", &"render_scale", &"view_distance":
			return "%d%%" % roundi(value * 100.0)
		&"fov":
			return "%d°" % roundi(value)
		_:
			return "%.1f" % value


func _link_focus() -> void:
	# One vertical chain per tab: the tab bar, that tab's controls, then the shared buttons.
	var controls: Array[Control] = [tabs.get_tab_bar()]
	if tabs.get_current_tab_control() == graphics_tab:
		controls.append_array([graphics_preset, msaa, render_scale, shadow_quality, view_distance, ssao, glow, vsync, frame_cap] as Array[Control])
	else:
		controls.append_array([mouse_sensitivity, controller_sensitivity, deadzone, fov, ui_scale, invert_y, reduced_motion, sprint_toggle, crouch_toggle] as Array[Control])
		for action in SettingsStore.REMAPPABLE_ACTIONS:
			if _binding_buttons.has(action):
				controls.append(_binding_buttons[action] as Control)
	controls.append(reset_button)
	controls.append(close_button)
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_width_left = 4
	focus_style.border_width_top = 4
	focus_style.border_width_right = 4
	focus_style.border_width_bottom = 4
	focus_style.border_color = Color.WHITE
	for index in controls.size():
		var control := controls[index]
		var previous := controls[posmod(index - 1, controls.size())]
		var next := controls[(index + 1) % controls.size()]
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.add_theme_stylebox_override("focus", focus_style)
		_add_focus_outline(control, focus_style)


func _add_focus_outline(control: Control, style: StyleBoxFlat) -> void:
	if control.has_node("FocusOutline"):
		return
	var outline := Panel.new()
	outline.name = "FocusOutline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = 10
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.offset_left = -4.0
	outline.offset_top = -4.0
	outline.offset_right = 4.0
	outline.offset_bottom = 4.0
	outline.add_theme_stylebox_override("panel", style)
	outline.hide()
	control.add_child(outline)
	control.focus_entered.connect(outline.show)
	control.focus_exited.connect(outline.hide)


func _tab_notice() -> String:
	if tabs.get_current_tab_control() == graphics_tab:
		return "Graphics changes apply immediately. LB/RB switch tabs."
	return "Select a binding to change it."


func _focus_first() -> void:
	if not visible:
		return
	if tabs.get_current_tab_control() == graphics_tab:
		graphics_preset.grab_focus()
	else:
		mouse_sensitivity.grab_focus()
