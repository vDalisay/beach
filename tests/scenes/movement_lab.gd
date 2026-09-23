extends Node3D

@onready var settings_store: SettingsStore = %SettingsStore
@onready var player: BeachPlayer = %Player
@onready var status: Label = %Status


func _ready() -> void:
	player.configure(settings_store)
	player.pause_changed.connect(_on_pause_changed)
	_on_pause_changed(false)


func _process(_delta: float) -> void:
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	status.text = "Speed %.2f m/s  |  %s  |  FOV %d°" % [
		horizontal_speed,
		"CROUCHED" if player.movement.is_crouched else "STANDING",
		roundi(player.camera.fov),
	]


func _on_pause_changed(paused: bool) -> void:
	%PauseLabel.visible = paused
