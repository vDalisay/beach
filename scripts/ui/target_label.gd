class_name TargetLabel
extends Control

const FEEL := preload("res://data/feel/feel_tuning.tres")

@onready var panel: PanelContainer = %Panel
@onready var text_label: Label = %Text

var camera: Camera3D
var interactor: PlayerInteractor
var player: BeachPlayer
var target: Dictionary = {}
var _shown_id := ""
var _position := Vector2.ZERO
var _rise := 0.0
var _shake_elapsed := 99.0
var _normal_style: StyleBox
var _blocked_style: StyleBoxFlat
var _flash_serial := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_normal_style = panel.get_theme_stylebox(&"panel")
	if _normal_style is StyleBoxFlat:
		_blocked_style = (_normal_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		_blocked_style.border_color = FEEL.hover_blocked_color
	hide()
	set_process(false)


func configure(player_interactor: PlayerInteractor, view_camera: Camera3D) -> void:
	clear_target()
	interactor = player_interactor
	camera = view_camera
	if not interactor.target_changed.is_connected(_on_target_changed):
		interactor.target_changed.connect(_on_target_changed)
	player = interactor.get_parent() as BeachPlayer
	if player != null and not player.cue_played.is_connected(_on_cue):
		player.cue_played.connect(_on_cue)
	if player != null and player.settings_store != null:
		if not player.settings_store.prompt_device_changed.is_connected(_on_prompt_changed):
			player.settings_store.prompt_device_changed.connect(_on_prompt_changed)
		if not player.settings_store.bindings_changed.is_connected(_refresh_text):
			player.settings_store.bindings_changed.connect(_refresh_text)


func clear_target() -> void:
	target = {}
	_shown_id = ""
	_flash_serial += 1
	if panel != null:
		FeelMotion.replace(panel, &"label_in", null)
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
	_rise = 0.0
	hide()
	set_process(false)


func _process(delta: float) -> void:
	if target.is_empty() or camera == null or not is_instance_valid(target.get("collider")):
		clear_target()
		return
	var world_point := target.hit_point as Vector3
	if camera.is_position_behind(world_point):
		hide()
		return
	show()
	var viewport_size := get_viewport_rect().size
	var projected := camera.unproject_position(world_point) + Vector2(18, -18)
	var panel_size := panel.size
	var reduced := _reduced()
	_position = projected if reduced else _position.lerp(projected, 1.0 - exp(-FEEL.label_follow_hz * delta))
	_shake_elapsed += delta
	var shake := 0.0 if reduced else FeelMotion.shake_offset(_shake_elapsed, FEEL.reticle_shake_seconds, FEEL.label_shake_px)
	panel.position = Vector2(
		clampf(_position.x + shake, 12.0, viewport_size.x - panel_size.x - 12.0),
		clampf(_position.y - panel_size.y + _rise, 12.0, viewport_size.y - panel_size.y - 12.0)
	)


func _on_target_changed(result: Dictionary) -> void:
	target = result
	if target.is_empty():
		clear_target()
		return
	_refresh_text()
	var id := str(result.get("id", ""))
	if id != _shown_id:
		_shown_id = id
		if camera != null and result.has("hit_point") and not camera.is_position_behind(result.hit_point as Vector3):
			_position = camera.unproject_position(result.hit_point as Vector3) + Vector2(18, -18)
		_play_in()
	_apply_style()
	show()
	set_process(true)


func _play_in() -> void:
	if _reduced():
		FeelMotion.replace(panel, &"label_in", null)
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
		_rise = 0.0
		return
	panel.pivot_offset = Vector2(0.0, panel.size.y)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	_rise = FEEL.label_rise_px
	var t := FeelMotion.replace(panel, &"label_in", FeelMotion.tween(panel).set_parallel(true))
	t.tween_property(panel, "modulate:a", 1.0, FEEL.label_in_seconds)
	t.tween_property(panel, "scale", Vector2.ONE, FEEL.label_in_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(func(value: float) -> void: _rise = value, FEEL.label_rise_px, 0.0, FEEL.label_in_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_style(force_blocked := false) -> void:
	if _blocked_style == null:
		return
	var blocked := force_blocked
	if not blocked and not target.is_empty() and interactor != null:
		var actions := target.get("actions", PackedStringArray()) as PackedStringArray
		blocked = interactor.style_for(target) == HoverHighlight.Style.BLOCKED or (str(target.get("kind", "")) == "slot" and not actions.has("place"))
	panel.add_theme_stylebox_override(&"panel", _blocked_style if blocked else _normal_style)


func _on_cue(cue: StringName, _info: Dictionary) -> void:
	if cue != &"rejected" or not visible:
		return
	_shake_elapsed = 0.0
	_apply_style(true)
	_flash_serial += 1
	var serial := _flash_serial
	get_tree().create_timer(0.35, true).timeout.connect(func() -> void:
		if is_instance_valid(self) and serial == _flash_serial:
			_apply_style()
	)


func _reduced() -> bool:
	return FeelMotion.reduced(player.settings_store) if player != null else true


func _on_prompt_changed(_device: SettingsStore.PromptDevice) -> void:
	_refresh_text()


func _refresh_text() -> void:
	if target.is_empty():
		return
	var reason := str(target.get("reason", ""))
	var verb := str(target.get("verb", ""))
	var actions := target.get("actions", PackedStringArray()) as PackedStringArray
	var detail := reason
	if detail.is_empty():
		detail = "%s [%s]" % [verb, interactor.binding_text(&"interact")] if not verb.is_empty() and actions.has("interact") else _action_text(actions)
	text_label.text = str(target.get("display_name", "")) + ("\n" + detail if not detail.is_empty() else "")


func _action_text(actions: PackedStringArray) -> String:
	var primary := interactor.binding_text(&"primary")
	var interact := interactor.binding_text(&"interact")
	if actions.has("clean"):
		return "Clean [%s] · Carry [%s]" % [primary, interact] if actions.has("carry_dirty") else "Clean [%s]" % primary
	if actions.has("place"):
		return "Place [%s]" % primary
	if actions.has("collect"):
		return "Collect [%s]" % primary
	if actions.has("cut"):
		return "Cut with rescue knife [%s]" % primary
	if actions.has("hold"):
		return "Pick up [%s]" % primary
	if actions.has("hold_bag"):
		return "Carry sealed bag [%s]" % primary
	if actions.has("interact"):
		return "Interact [%s]" % interact
	return ""
