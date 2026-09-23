class_name CollectionCallPoint
extends StaticBody3D

signal feedback_requested(message: String)

@export var station_id: StringName = &"S1"

var service: CollectionService
var player: BeachPlayer


func configure(collection_service: CollectionService, player_body: BeachPlayer) -> void:
	service = collection_service
	player = player_body
	var target_id := StringName("collection:%s" % station_id)
	set_meta(&"target_id", target_id)
	set_meta(&"display_name", "Collection hotline")
	set_meta(&"interaction_actions", PackedStringArray(["interact"]))
	set_meta(&"interaction_reason", "E: collect all deposited bags")
	if not player.interactor.interact_requested.is_connected(_on_interact_requested):
		player.interactor.interact_requested.connect(_on_interact_requested)


func _on_interact_requested(target: Dictionary) -> void:
	if StringName(str(target.get("id", ""))) != StringName("collection:%s" % station_id):
		return
	var result := service.try_collect_containers(&"local")
	if not result.ok:
		feedback_requested.emit(result.message)
