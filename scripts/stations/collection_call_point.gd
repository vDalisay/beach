class_name CollectionCallPoint
extends StaticBody3D

signal feedback_requested(message: String)

const FEEL := preload("res://data/feel/feel_tuning.tres")

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
	set_meta(&"interaction_verb", "Collect all deposited bags")
	set_meta(&"highlight_root", get_node("SyntyPhone"))
	if not player.interactor.interact_requested.is_connected(_on_interact_requested):
		player.interactor.interact_requested.connect(_on_interact_requested)


func _on_interact_requested(target: Dictionary) -> void:
	if StringName(str(target.get("id", ""))) != StringName("collection:%s" % station_id):
		return
	var result := service.try_collect_containers(&"local")
	_ring(result.ok)
	if result.ok:
		player.play_cue(&"collect_call")
	else:
		feedback_requested.emit(result.message)
		player.play_cue(&"rejected", {"reason": result.message})


## The hotline rings: the phone wobbles and the label pops; a failed call only shakes once.
func _ring(success: bool) -> void:
	var label := get_node_or_null("Label") as Node3D
	if label != null:
		FeelMotion.pop(label, Vector3.ONE * 1.15, 0.06, 0.14)
	if FeelMotion.reduced(player.settings_store):
		return
	var phone := get_node_or_null("SyntyPhone") as Node3D
	if phone != null:
		var angle := deg_to_rad(FEEL.phone_ring_degrees) * (1.0 if success else 0.5)
		var seconds := FEEL.phone_ring_seconds if success else 0.15
		var rings := 6.0 if success else 1.0
		var t := FeelMotion.replace(phone, &"ring", FeelMotion.tween(phone))
		t.tween_method(func(p: float) -> void: phone.rotation.z = sin(p * TAU * rings) * angle * (1.0 - p), 0.0, 1.0, seconds)
		t.tween_callback(func() -> void: phone.rotation.z = 0.0)
	if success:
		FeelRing.spawn(self, global_position + Vector3.UP * 0.05, 0.3, 1.2, 0.45, FEEL.money_color, 0.06)
		FeelBurst.spawn(self, global_position + Vector3.UP * 1.1, FeelBurst.Kind.COINS)
