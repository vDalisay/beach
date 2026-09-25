class_name RescueSite
extends Node3D

const FEEL := preload("res://data/feel/feel_tuning.tres")

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


## Removes and returns the attachment's visual (not its Area3D) so it can be presented.
func detach_attachment_visual(item_id: StringName) -> Node3D:
	var area := attachment_area(item_id)
	if area == null:
		return null
	for child in area.get_children():
		if child is Node3D and not (child is CollisionShape3D):
			var from := (child as Node3D).global_transform
			area.remove_child(child)
			child.set_meta(&"from_transform", from)
			return child as Node3D
	return null


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


## The rescue lands: "FREED" pops, the animal breathes out a stream of bubbles and a ring
## spreads, then the label fades while the animal sets off. Loads never replay this.
func release_animal(reduced := false) -> void:
	refresh()
	var animator := animal.get_node_or_null("Animator") as TurtleAnimator
	if animator != null:
		animator.exhale()
	FeelRing.spawn(self, animal.global_position + Vector3.UP * 0.05, 0.3, 1.4, 0.6, FEEL.wave_color_reef, 0.08)
	if not reduced:
		FeelBurst.spawn(self, animal.global_position + Vector3.UP * 0.35, FeelBurst.Kind.HEARTS)
	var t := FeelMotion.replace(status_label, &"freed", FeelMotion.tween(status_label))
	if not reduced:
		status_label.scale = Vector3.ONE * 0.4
		t.tween_property(status_label, "scale", Vector3.ONE * 1.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(status_label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(FEEL.freed_label_seconds)
	t.tween_property(status_label, "modulate:a", 0.0, 0.4)
	t.tween_callback(func() -> void:
		status_label.hide()
		status_label.modulate.a = 1.0
	)
	_start_route(false)


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
	var scene := (session.definitions[record.definition_id] as ItemDefinition).visual_scene()
	if scene != null:
		var visual := scene.instantiate() as Node3D
		area.add_child(visual)
		# Drape the loose-waste model over its side of the shell so the entanglement reads.
		var side := signf(to_local(area.global_position).x)
		visual.position = Vector3(side * 0.05, 0.14, 0.0)
		visual.rotation = Vector3(0.0, 0.0, -side * 0.55)
	attachment_areas[record.item_id] = area


func _start_route(hide_label := true) -> void:
	if _route_tween != null and _route_tween.is_running():
		return
	if hide_label:
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
