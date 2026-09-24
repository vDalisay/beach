class_name TargetLabel
extends Control

@onready var panel: PanelContainer = %Panel
@onready var text_label: Label = %Text

var camera: Camera3D
var interactor: PlayerInteractor
var target: Dictionary = {}


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
	var player := interactor.get_parent() as BeachPlayer
	if player != null and player.settings_store != null:
		if not player.settings_store.prompt_device_changed.is_connected(_on_prompt_changed):
			player.settings_store.prompt_device_changed.connect(_on_prompt_changed)
		if not player.settings_store.bindings_changed.is_connected(_refresh_text):
			player.settings_store.bindings_changed.connect(_refresh_text)


func clear_target() -> void:
	target = {}
	hide()
	set_process(false)


func _process(_delta: float) -> void:
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
	panel.position = Vector2(
		clampf(projected.x, 12.0, viewport_size.x - panel_size.x - 12.0),
		clampf(projected.y - panel_size.y, 12.0, viewport_size.y - panel_size.y - 12.0)
	)


func _on_target_changed(result: Dictionary) -> void:
	target = result
	if target.is_empty():
		clear_target()
		return
	_refresh_text()
	show()
	set_process(true)


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
