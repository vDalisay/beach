class_name Starfish
extends Node3D

const MODELS := [
	preload("res://art/models/starfish_orange.glb"),
	preload("res://art/models/starfish_purple.glb"),
]


func _ready() -> void:
	var visual := MODELS[get_index() % MODELS.size()].instantiate() as Node3D
	visual.name = "Visual"
	visual.rotation.y = float(get_index()) * 1.7
	add_child(visual)
