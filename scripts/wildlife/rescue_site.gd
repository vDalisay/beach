class_name RescueSite
extends Node3D

@onready var animal: Node3D = %Animal
@onready var attachment_root: Node3D = %Attachments
@onready var status_label: Label3D = %Status

var session: RunSession
var site_id: StringName
var attachment_areas: Dictionary = {}
var _route_tween: Tween


func configure(run_session: RunSession, id: StringName) -> void:
	session = run_session
	site_id = id
	var rescue := session.state.rescue_states[site_id] as Dictionary
	var attachment_ids := rescue.attachment_ids as Array
	var first := session.state.items[StringName(str(attachment_ids[0]))] as ItemRecord
	var second := session.state.items[StringName(str(attachment_ids[1]))] as ItemRecord
	global_position = (first.last_world_transform.origin + second.last_world_transform.origin) * 0.5
	for item_text in attachment_ids:
		var item_id := StringName(str(item_text))
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.ATTACHED:
			_create_attachment(record)
	refresh()
	if bool(rescue.released):
		_start_route()


func attachment_area(item_id: StringName) -> Area3D:
	return attachment_areas.get(item_id) as Area3D


func remove_attachment(item_id: StringName) -> void:
	var area := attachment_area(item_id)
	if area != null:
		attachment_areas.erase(item_id)
		area.queue_free()
	refresh()


func refresh() -> void:
	var rescue := session.state.rescue_states[site_id] as Dictionary
	var animator := animal.get_node_or_null("Animator") as TurtleAnimator
	if animator != null:
		# Tangled animals struggle in fits until both attachments are cut.
		animator.entangled = not bool(rescue.released)
	if bool(rescue.released):
		status_label.text = "FREED"
		status_label.modulate = Color("94e7a8")
		return
	status_label.text = "RESCUE  %d/2" % (2 - attachment_areas.size())
	status_label.modulate = Color("ffdd8a")


func release_animal() -> void:
	refresh()
	_start_route()


func _create_attachment(record: ItemRecord) -> void:
	var area := Area3D.new()
	area.name = "Attachment_%s" % str(record.attachment_id).get_slice("/", 1).replace(":", "_")
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitorable = true
	area.set_meta(&"target_id", record.item_id)
	area.set_meta(&"display_name", (session.definitions[record.definition_id] as ItemDefinition).display_name)
	area.set_meta(&"interaction_actions", PackedStringArray(["cut"]))
	attachment_root.add_child(area)
	area.global_position = record.last_world_transform.origin
	var shape := SphereShape3D.new()
	shape.radius = 0.31
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	var scene := load((session.definitions[record.definition_id] as ItemDefinition).visual_scene_path) as PackedScene
	if scene != null:
		area.add_child(scene.instantiate())
	attachment_areas[record.item_id] = area


func _start_route() -> void:
	if _route_tween != null and _route_tween.is_running():
		return
	status_label.hide()
	var animator := animal.get_node_or_null("Animator") as TurtleAnimator
	if animator != null:
		animator.face_motion = true
	# A slow, level circuit around the site: easing in and out of each leg reads as the
	# turtle choosing its way rather than sliding between corners.
	_route_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_route_tween.tween_property(animal, "position", Vector3(1.6, 0.0, 0.8), 4.0)
	_route_tween.tween_property(animal, "position", Vector3(-1.2, 0.0, 1.6), 5.0)
	_route_tween.tween_property(animal, "position", Vector3.ZERO, 4.0)
