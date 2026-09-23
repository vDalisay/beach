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
	note.text = "Autosave and manual save use separate slots."
	resume_button.grab_focus()


func close_menu() -> void:
	hide()


func show_save_failure(message: String) -> void:
	note.text = "Save failed: %s\nRetry Save and quit, or quit without saving." % message
	quit_without_save_button.show()
	save_quit_button.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and not event.is_echo() and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
