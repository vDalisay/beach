class_name EquipmentShop
extends Node3D

@onready var counter: StaticBody3D = %Counter
@onready var rack: StaticBody3D = %ToolRack
@onready var owned_tools_root: Node3D = %OwnedTools

var service: ProgressionService
var player: BeachPlayer
var view: ProgressionView


func configure(progression: ProgressionService, player_body: BeachPlayer, progression_view: ProgressionView) -> void:
	service = progression
	player = player_body
	view = progression_view
	service.shop = self
	counter.set_meta(&"target_id", &"shop:counter")
	counter.set_meta(&"display_name", "Equipment shop")
	counter.set_meta(&"interaction_actions", PackedStringArray(["interact"]))
	counter.set_meta(&"interaction_reason", "E: browse equipment")
	rack.set_meta(&"target_id", &"shop:rack")
	rack.set_meta(&"display_name", "Tool rack")
	rack.set_meta(&"interaction_actions", PackedStringArray(["interact"]))
	rack.set_meta(&"interaction_reason", "E: equip owned tools")
	player.interactor.interact_requested.connect(_on_interact_requested)
	refresh_rack()


func player_near_counter() -> bool:
	return player != null and player.global_position.distance_to(counter.global_position) <= 3.2


func player_near_rack() -> bool:
	return player != null and player.global_position.distance_to(rack.global_position) <= 3.2


func refresh_rack() -> void:
	for child in owned_tools_root.get_children():
		child.queue_free()
	if service == null:
		return
	var owned := (service.session.state.players[&"local"] as Dictionary).owned_tools as Array[StringName]
	var display_index := 0
	for tool_id in owned:
		if tool_id == &"stick" or not service.offers.has(tool_id):
			continue
		var definition := service.offers[tool_id] as ToolDefinition
		if definition == null or not definition.handheld:
			continue
		var anchor := Node3D.new()
		anchor.position = Vector3(-0.7 + float(display_index % 3) * 0.7, 0.0, -0.12 - float(display_index / 3) * 0.28)
		owned_tools_root.add_child(anchor)
		if not definition.scene_path.is_empty():
			var visual := (load(definition.scene_path) as PackedScene).instantiate() as Node3D
			visual.scale = Vector3.ONE * 0.6
			anchor.add_child(visual)
		var label := Label3D.new()
		label.position = Vector3(0, 0.38, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.text = definition.display_name
		label.font_size = 32
		label.pixel_size = 0.002
		label.outline_size = 7
		anchor.add_child(label)
		display_index += 1


func _on_interact_requested(target: Dictionary) -> void:
	match StringName(str(target.get("id", ""))):
		&"shop:counter": view.open_shop()
		&"shop:rack": view.open_rack()
