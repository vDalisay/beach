class_name TargetLabel
extends Control
## The name of what the player is aiming at, straight under the reticle, with one chip per thing
## they can do to it: the input icon for the current device and binding plus a verb. Blocked
## targets show the reason in amber instead of the actions they cannot take. Pops in when the
## target changes, shakes and flashes amber on a rejected press. Presentation only.

const FEEL := preload("res://data/feel/feel_tuning.tres")
const P := preload("res://scripts/ui/kit/ui_palette.gd")
## Gap between the aim point and the top of the name.
const BELOW_AIM := 22.0
## Chip wording where the full prompt text is too long for a chip.
const SHORT_VERBS := {"Cut with rescue knife": "Cut free", "Carry sealed bag": "Carry"}

@onready var panel: VBoxContainer = %Panel
@onready var name_label: Label = %Name
@onready var prompts: HBoxContainer = %Prompts
@onready var reason_label: Label = %Reason

var camera: Camera3D
var interactor: PlayerInteractor
var player: BeachPlayer
var target: Dictionary = {}
var _shown_id := ""
var _rise := 0.0
var _shake_elapsed := 99.0
var _flash_serial := 0
var _blocked := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## What the prompt says, in words: the name, then the reason or "Verb [binding]" per action.
func prompt_text() -> String:
	if target.is_empty():
		return ""
	var detail := str(target.get("reason", ""))
	if detail.is_empty():
		var parts := PackedStringArray()
		for entry in _actions_for(target):
			parts.append("%s [%s]" % [entry[0], interactor.binding_text(entry[1])])
		detail = " · ".join(parts)
	return str(target.get("display_name", "")) + ("\n" + detail if not detail.is_empty() else "")


func _process(delta: float) -> void:
	if target.is_empty() or camera == null or not is_instance_valid(target.get("collider")):
		clear_target()
		return
	if camera.is_position_behind(target.hit_point as Vector3):
		hide()
		return
	show()
	var viewport_size := get_viewport_rect().size
	var reduced := _reduced()
	_shake_elapsed += delta
	var shake := 0.0 if reduced else FeelMotion.shake_offset(_shake_elapsed, FEEL.reticle_shake_seconds, FEEL.label_shake_px)
	var panel_size := panel.get_combined_minimum_size()
	panel.size = panel_size
	panel.position = Vector2(
		clampf((viewport_size.x - panel_size.x) * 0.5 + shake, 12.0, viewport_size.x - panel_size.x - 12.0),
		clampf(viewport_size.y * 0.5 + BELOW_AIM + _rise, 12.0, viewport_size.y - panel_size.y - 12.0)
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
		_play_in()
	show()
	set_process(true)


func _play_in() -> void:
	if _reduced():
		FeelMotion.replace(panel, &"label_in", null)
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
		_rise = 0.0
		return
	panel.pivot_offset = Vector2(panel.get_combined_minimum_size().x * 0.5, 0.0)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	_rise = FEEL.label_rise_px
	var t := FeelMotion.replace(panel, &"label_in", FeelMotion.tween(panel).set_parallel(true))
	t.tween_property(panel, "modulate:a", 1.0, FEEL.label_in_seconds)
	t.tween_property(panel, "scale", Vector2.ONE, FEEL.label_in_seconds * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(func(value: float) -> void: _rise = value, FEEL.label_rise_px, 0.0, FEEL.label_in_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _is_blocked() -> bool:
	if target.is_empty() or interactor == null:
		return false
	var actions := target.get("actions", PackedStringArray()) as PackedStringArray
	return interactor.style_for(target) == HoverHighlight.Style.BLOCKED or (str(target.get("kind", "")) == "slot" and not actions.has("place"))


func _apply_style(force_blocked := false) -> void:
	var blocked := force_blocked or _blocked
	name_label.add_theme_color_override(&"font_color", P.AMBER if blocked else P.WHITE)


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
	_blocked = _is_blocked()
	name_label.text = str(target.get("display_name", "")).to_upper()
	for child in prompts.get_children():
		prompts.remove_child(child)
		child.queue_free()
	var entries := _actions_for(target)
	var store := player.settings_store if player != null else null
	for entry in entries:
		# A blocked primary action is not offered; secondary ones (carry a dirty prop) still are.
		if _blocked and entry[1] == &"primary":
			continue
		prompts.add_child(PromptChip.new().setup(store, entry[1], SHORT_VERBS.get(entry[0], entry[0])))
	prompts.visible = prompts.get_child_count() > 0
	var reason := _reason_line(str(target.get("reason", "")), prompts.visible)
	reason_label.text = reason
	reason_label.visible = not reason.is_empty()
	reason_label.theme_type_variation = &"HudWarn" if _blocked else &"HudCaption"
	_apply_style()


## A reason that only repeats a chip's binding ("Needs cloth · E: Carry") keeps its first part.
static func _reason_line(reason: String, has_chips: bool) -> String:
	if has_chips and reason.contains(" · ") and reason.get_slice(" · ", 1).contains(":"):
		return reason.get_slice(" · ", 0)
	return reason


## [verb, action] pairs for the target, in the order the old text prompt listed them.
func _actions_for(result: Dictionary) -> Array:
	var actions := result.get("actions", PackedStringArray()) as PackedStringArray
	var verb := str(result.get("verb", ""))
	if not verb.is_empty() and actions.has("interact"):
		return [[verb, &"interact"]]
	if actions.has("clean"):
		return [["Clean", &"primary"], ["Carry", &"interact"]] if actions.has("carry_dirty") else [["Clean", &"primary"]]
	if actions.has("carry_dirty"):
		return [["Carry", &"interact"]]
	if actions.has("place"):
		return [["Place", &"primary"]]
	if actions.has("collect"):
		return [["Collect", &"primary"]]
	if actions.has("cut"):
		return [["Cut with rescue knife", &"primary"]]
	if actions.has("hold"):
		return [["Pick up", &"primary"]]
	if actions.has("hold_bag"):
		return [["Carry sealed bag", &"primary"]]
	if actions.has("interact"):
		return [["Interact", &"interact"]]
	return []
