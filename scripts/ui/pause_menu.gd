class_name PauseMenu
extends Control

signal resume_requested
signal settings_requested
signal save_requested
signal save_quit_requested
signal quit_without_save_requested

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var save_button: Button = %SaveButton
@onready var slot_picker: OptionButton = %SlotPicker
@onready var save_quit_button: Button = %SaveQuitButton
@onready var quit_without_save_button: Button = %QuitWithoutSaveButton
@onready var note: Label = %Note


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	save_button.pressed.connect(func() -> void: save_requested.emit())
	save_quit_button.pressed.connect(func() -> void: save_quit_requested.emit())
	quit_without_save_button.pressed.connect(func() -> void: quit_without_save_requested.emit())
	hide()


func open_menu() -> void:
	show()
	quit_without_save_button.hide()
	note.text = "Choose a checkpoint. Autosave is separate."
	resume_button.grab_focus()


func set_slot_summaries(summaries: Array[Dictionary]) -> void:
	var selected := maxi(slot_picker.selected, 0)
	slot_picker.clear()
	for index in range(3):
		var label := "Checkpoint %d — empty" % (index + 1)
		if index < summaries.size() and not summaries[index].is_empty():
			var summary := summaries[index]
			label = "Checkpoint %d — %s — %d/%d" % [index + 1, Time.get_datetime_string_from_unix_time(int(summary.saved_at), true), int(summary.completed), int(summary.required)]
		slot_picker.add_item(label, index)
	slot_picker.select(mini(selected, 2))


func selected_slot_id() -> StringName:
	return [&"manual", &"manual_2", &"manual_3"][maxi(slot_picker.selected, 0)]


func close_menu() -> void:
	hide()


func show_save_failure(message: String) -> void:
	note.text = "Save failed: %s\nRetry Save and quit, or quit without saving." % message
	quit_without_save_button.show()
	save_quit_button.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		if slot_picker.get_popup().visible:
			slot_picker.get_popup().hide()
		else:
			resume_requested.emit()
		get_viewport().set_input_as_handled()
