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
	counter.set_meta(&"interaction_verb", "Browse equipment")
	rack.set_meta(&"target_id", &"shop:rack")
	rack.set_meta(&"display_name", "Tool rack")
	rack.set_meta(&"interaction_actions", PackedStringArray(["interact"]))
	rack.set_meta(&"interaction_verb", "Equip owned tools")
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
		if definition == null or (not definition.handheld and definition.scene_path.is_empty()):
			continue
		var anchor := Node3D.new()
		anchor.position = Vector3(-0.7 + float(display_index % 3) * 0.7, 0.0, -0.12 - float(display_index / 3) * 0.28)
		owned_tools_root.add_child(anchor)
		if not definition.scene_path.is_empty():
			var visual := definition.scene().instantiate() as Node3D
			visual.scale = Vector3.ONE * 0.6
			anchor.add_child(visual)
			var size := _bounds_in(anchor, visual).size
			if definition.handheld and size.y > maxf(size.x, size.z):
				# Long tools hang from their grip in the hand; stand them on it like a tool rack.
				visual.rotation = Vector3(PI, float(display_index) * 0.4, 0.0)
			# Rest every model on the counter top, whatever its pivot.
			visual.position.y -= _bounds_in(anchor, visual).position.y
		var label := Label3D.new()
		label.position = Vector3(0, 0.78 + float(display_index / 3) * 0.14, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.text = definition.display_name
		label.font_size = 32
		label.pixel_size = 0.002
		label.outline_size = 7
		# Small counter text: no sun shadow, and not drawn from where it cannot be read.
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.visibility_range_end = 20.0
		anchor.add_child(label)
		display_index += 1


func _bounds_in(space: Node3D, node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		var box := space.global_transform.affine_inverse() * instance.global_transform * instance.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _on_interact_requested(target: Dictionary) -> void:
	match StringName(str(target.get("id", ""))):
		&"shop:counter": view.open_shop()
		&"shop:rack": view.open_rack()
