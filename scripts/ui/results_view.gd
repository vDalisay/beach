class_name ResultsView
extends Control

signal continued

@onready var title_label: Label = %Title
@onready var summary_label: Label = %Summary
@onready var details_label: Label = %Details
@onready var continue_button: Button = %Continue

var player: BeachPlayer
var session: RunSession
var _previous_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(continue_roaming)
	hide()


func show_receipt(receipt: Dictionary, player_body: BeachPlayer, run_session: RunSession) -> void:
	if visible:
		return
	player = player_body
	session = run_session
	_previous_pause = get_tree().paused
	title_label.text = "COAST RESTORED"
	summary_label.text = "%d / %d required objects complete" % [int(receipt.collected_waste) + int(receipt.slotted_props), int(receipt.required_total)]
	details_label.text = "Waste collected  %d    •    Props placed  %d\nSorted correctly  %d    •    Active time  %s\nSeed  %s" % [int(receipt.collected_waste), int(receipt.slotted_props), int(receipt.correctly_sorted), _duration(float(receipt.active_seconds)), str(receipt.seed)]
	session.results_open = true
	player.set_input_enabled(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	continue_button.grab_focus()


func continue_roaming() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = _previous_pause
	if session != null:
		session.results_open = false
	if player != null:
		player.set_input_enabled(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	continued.emit()


func reset_view() -> void:
	hide()
	player = null
	session = null


func _duration(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
