class_name ResultsView
extends Control

signal continued

const FEEL := preload("res://data/feel/feel_tuning.tres")

@onready var title_label: Label = %Title
@onready var summary_label: Label = %Summary
@onready var details_label: Label = %Details
@onready var continue_button: Button = %Continue
@onready var shade: ColorRect = $Shade
# The panel scales in through its CenterContainer: containers reset their children's scale and
# rotation when they sort, so the stamped title and the tilted card sit in plain holders too.
@onready var center: Control = $Center
@onready var panel: Control = $Center/Panel
@onready var flash: ColorRect = %Flash
@onready var title_holder: Control = %TitleHolder
@onready var postcard_holder: Control = %PostcardHolder
@onready var postcard: PanelContainer = %Postcard
@onready var postcard_image: TextureRect = %PostcardImage
@onready var confetti: CPUParticles2D = %Confetti

var player: BeachPlayer
var session: RunSession
var _previous_pause := false
var _shade_alpha := 0.88
var _receipt := {}
var _final := {}
# HUD nodes the finale tucked away, with the visibility each had.
var _hud_states := {}
var _hands_were_visible := false
var _hands_hidden := false
var _intro_running := false
var _intro_serial := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(continue_roaming)
	_shade_alpha = shade.color.a
	title_holder.custom_minimum_size.y = title_label.get_combined_minimum_size().y
	confetti.amount = FEEL.confetti_amount
	# Hard colour stops, so each piece of confetti is one of the palette colours.
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for index in FEEL.confetti_colors.size():
		offsets.append(float(index) / float(FEEL.confetti_colors.size()))
		colors.append(FEEL.confetti_colors[index])
	ramp.offsets = offsets
	ramp.colors = colors
	confetti.color_initial_ramp = ramp
	hide()


## Opens the results. Everything the checks read (texts, `results_open`, the pause and
## visibility) is set before this returns; the finale intro only animates presentation. A loaded,
## already-finished run passes `animate = false` and gets the final layout at once.
func show_receipt(receipt: Dictionary, player_body: BeachPlayer, run_session: RunSession, animate := true, hud: Array[CanvasItem] = []) -> void:
	if visible:
		return
	player = player_body
	session = run_session
	_previous_pause = get_tree().paused
	_receipt = receipt
	_final = _texts_at(1.0)
	_write_texts(_final)
	session.results_open = true
	player.set_input_enabled(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	continue_button.grab_focus()
	postcard_image.texture = null
	if not animate:
		_apply_final_state(false)
		return
	_hide_hud(hud)
	_play_intro(FeelMotion.reduced(player.settings_store))


func continue_roaming() -> void:
	if not visible:
		return
	_end_presentation(true)
	hide()
	get_tree().paused = _previous_pause
	if session != null:
		session.results_open = false
	if player != null:
		player.set_input_enabled(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	continued.emit()


func reset_view() -> void:
	# The run is being cleared: drop the tucked-away HUD states instead of restoring them.
	_end_presentation(false)
	hide()
	postcard_image.texture = null
	player = null
	session = null


func _input(event: InputEvent) -> void:
	if not _intro_running or not visible:
		return
	var mouse := event as InputEventMouseButton
	if (mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(&"ui_accept"):
		# The first confirm skips to the final layout; the next one reaches Continue.
		_finish_intro()
		get_viewport().set_input_as_handled()


func _hide_hud(hud: Array[CanvasItem]) -> void:
	_hud_states.clear()
	for item in hud:
		if is_instance_valid(item):
			_hud_states[item] = item.visible
			item.hide()


## The held breath: the final action's effects play on under the pause for the beat, then the
## frame is taken as the postcard and the results reveal themselves.
func _play_intro(reduced: bool) -> void:
	_intro_running = true
	_intro_serial += 1
	shade.color.a = 0.0
	panel.modulate.a = 0.0
	flash.color.a = 0.0
	continue_button.modulate.a = 0.0
	postcard_holder.hide()
	if not reduced:
		_write_texts(_texts_at(0.0))
	var beat := FeelMotion.replace(self, &"intro", FeelMotion.tween(self))
	beat.tween_interval(FEEL.finale_capture_seconds)
	beat.tween_callback(_capture_and_reveal.bind(_intro_serial, reduced))


func _capture_and_reveal(serial: int, reduced: bool) -> void:
	# The hands step out of the photo; they come back on Continue.
	if player != null and is_instance_valid(player.hand_rig):
		_hands_were_visible = player.hand_rig.visible
		_hands_hidden = true
		player.hand_rig.hide()
	await RenderingServer.frame_post_draw
	if serial != _intro_serial or not visible:
		return
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		var height := int(FEEL.postcard_size.y * 2.0)
		image.resize(int(float(height) * float(image.get_width()) / float(image.get_height())), height, Image.INTERPOLATE_BILINEAR)
		postcard_image.texture = ImageTexture.create_from_image(image)
	_reveal(reduced)


func _reveal(reduced: bool) -> void:
	if postcard_image.texture != null:
		_fit_postcard()
		postcard_holder.show()
		postcard.pivot_offset = postcard_holder.custom_minimum_size * 0.5
		postcard.modulate.a = 0.0
		postcard.scale = Vector2.ONE if reduced else Vector2.ONE * 0.8
		postcard.rotation_degrees = -2.0 if reduced else -4.0
	var t := FeelMotion.replace(self, &"intro", FeelMotion.tween(self).set_parallel(true))
	# Flash, while the shade settles in.
	if not reduced:
		t.tween_property(flash, "color:a", FEEL.finale_flash_alpha, 0.06)
		t.tween_property(flash, "color:a", 0.0, 0.35).set_delay(0.06)
	t.tween_property(shade, "color:a", _shade_alpha, 0.4)
	# The panel scales in.
	center.pivot_offset = center.size * 0.5
	if not reduced:
		center.scale = Vector2.ONE * 0.94
		t.tween_property(center, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	t.tween_property(panel, "modulate:a", 1.0, 0.25).set_delay(0.1)
	# "COAST RESTORED" stamps down, with confetti.
	var at := 0.35
	if not reduced:
		title_label.pivot_offset = title_label.size * 0.5
		title_label.scale = Vector2.ONE * 1.6
		title_label.rotation = -0.1
		t.tween_property(title_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(at)
		t.tween_property(title_label, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(at)
		t.tween_callback(_burst_confetti).set_delay(at + 0.22)
	at += 0.22
	# The postcard settles, tilted.
	if postcard_image.texture != null:
		t.tween_property(postcard, "modulate:a", 1.0, 0.15).set_delay(at)
		if not reduced:
			t.tween_property(postcard, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(at)
			t.tween_property(postcard, "rotation_degrees", -2.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(at)
		at += 0.2
	# The stats count up.
	if reduced:
		_write_texts(_final)
	else:
		t.tween_method(_count_to, 0.0, 1.0, FEEL.finale_count_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(at)
		at += FEEL.finale_count_seconds
	# Continue fades in and starts to pulse.
	t.tween_property(continue_button, "modulate:a", 1.0, 0.2).set_delay(at)
	t.tween_callback(func() -> void:
		_intro_running = false
		_write_texts(_final)
		_start_pulse()
	).set_delay(at + 0.2)


## The card takes the height the panel's other rows leave on screen, up to FEEL.postcard_size.
func _fit_postcard() -> void:
	var rest := ($Center/Panel/Margin as Control).get_combined_minimum_size().y
	var room := get_viewport_rect().size.y - rest - 48.0 - 20.0 - 18.0
	var height := clampf(room, 96.0, FEEL.postcard_size.y)
	postcard_image.custom_minimum_size = Vector2(height * FEEL.postcard_size.x / FEEL.postcard_size.y, height)
	postcard_holder.custom_minimum_size = postcard_image.custom_minimum_size + Vector2(20.0, 20.0)


func _burst_confetti() -> void:
	confetti.show()
	confetti.position = Vector2(size.x * 0.5, -12.0)
	confetti.emission_rect_extents = Vector2(size.x * 0.5, 8.0)
	confetti.restart()


func _count_to(progress: float) -> void:
	_write_texts(_final if progress >= 1.0 else _texts_at(progress))


func _start_pulse() -> void:
	if player == null or FeelMotion.reduced(player.settings_store):
		return
	continue_button.pivot_offset = continue_button.size * 0.5
	var pulse := FeelMotion.replace(continue_button, &"pulse", FeelMotion.tween(continue_button).set_loops())
	pulse.tween_property(continue_button, "scale", Vector2.ONE * 1.03, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(continue_button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Skip: the final layout at once, keeping any postcard already taken.
func _finish_intro() -> void:
	_intro_serial += 1
	_intro_running = false
	FeelMotion.replace(self, &"intro", null)
	_apply_final_state(true)


func _apply_final_state(pulse: bool) -> void:
	_write_texts(_final)
	shade.color.a = _shade_alpha
	flash.color.a = 0.0
	panel.modulate.a = 1.0
	center.scale = Vector2.ONE
	title_label.scale = Vector2.ONE
	title_label.rotation = 0.0
	continue_button.modulate.a = 1.0
	confetti.emitting = false
	if postcard_image.texture != null and not postcard_holder.visible:
		_fit_postcard()
		postcard.pivot_offset = postcard_holder.custom_minimum_size * 0.5
	postcard_holder.visible = postcard_image.texture != null
	postcard.modulate.a = 1.0
	postcard.scale = Vector2.ONE
	postcard.rotation_degrees = -2.0
	if pulse:
		_start_pulse()


## Ends the intro and pulse; on Continue the tucked-away HUD and hands come back as they were.
func _end_presentation(restore: bool) -> void:
	_intro_serial += 1
	_intro_running = false
	FeelMotion.replace(self, &"intro", null)
	FeelMotion.replace(continue_button, &"pulse", null)
	continue_button.scale = Vector2.ONE
	continue_button.modulate.a = 1.0
	center.scale = Vector2.ONE
	# Pieces still falling would reappear the next time the view shows (a reload opens it at once).
	confetti.emitting = false
	confetti.hide()
	flash.color.a = 0.0
	if restore:
		for item in _hud_states:
			if is_instance_valid(item):
				(item as CanvasItem).visible = bool(_hud_states[item])
		if _hands_hidden and player != null and is_instance_valid(player.hand_rig):
			player.hand_rig.visible = _hands_were_visible
	_hud_states.clear()
	_hands_hidden = false


## Today's exact results strings at `progress` 1.0; smaller values count the numbers up from 0.
func _texts_at(progress: float) -> Dictionary:
	var receipt := _receipt
	var waste := roundi(float(receipt.get("collected_waste", 0)) * progress)
	var props := roundi(float(receipt.get("slotted_props", 0)) * progress)
	var sorted := roundi(float(receipt.get("correctly_sorted", 0)) * progress)
	return {
		"title": "COAST RESTORED",
		"summary": "%d / %d required objects complete" % [waste + props, int(receipt.get("required_total", 0))],
		"details": "Waste collected  %d    •    Props placed  %d\nSorted correctly  %d    •    Active time  %s\nSeed  %s" % [waste, props, sorted, _duration(float(receipt.get("active_seconds", 0.0)) * progress), str(receipt.get("seed", ""))],
	}


func _write_texts(texts: Dictionary) -> void:
	title_label.text = str(texts.title)
	summary_label.text = str(texts.summary)
	details_label.text = str(texts.details)


func _duration(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
