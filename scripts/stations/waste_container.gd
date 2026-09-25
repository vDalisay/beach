class_name WasteContainer
extends StaticBody3D

signal feedback_requested(message: String)

const COLORS := DisposalBag.COLORS
const FEEL := preload("res://data/feel/feel_tuning.tres")

@export var container_id: StringName = &"container:S1:pmd"
@export var category: StringName = &"pmd"
@onready var opening: Area3D = %Opening
@onready var fill: MeshInstance3D = %Fill
@onready var label: Label3D = %Label

var session: RunSession
var player: BeachPlayer
## Presentation only: the bag count the fill currently shows.
var _shown_count := -1


func _ready() -> void:
	_build_shell()
	opening.body_entered.connect(_on_body_entered)


func configure(run_session: RunSession, player_body: BeachPlayer) -> void:
	session = run_session
	player = player_body
	set_meta(&"target_id", container_id)
	set_meta(&"display_name", "%s container" % str(category).to_upper())
	set_meta(&"interaction_actions", PackedStringArray(["interact"]))
	opening.set_meta(&"target_id", container_id)
	opening.set_meta(&"display_name", "%s container" % str(category).to_upper())
	opening.set_meta(&"interaction_actions", PackedStringArray(["interact"]))
	set_meta(&"highlight_root", get_node("SyntyContainer"))
	opening.set_meta(&"highlight_root", get_node("SyntyContainer"))
	if not session.state.container_records.has(container_id):
		session.state.container_records[container_id] = {"kind": "waste_container", "category": category, "bags": []}
	if not player.interactor.interact_requested.is_connected(_on_interact_requested):
		player.interactor.interact_requested.connect(_on_interact_requested)
	if not session.bags_changed.is_connected(_on_bags_changed):
		session.bags_changed.connect(_on_bags_changed)
	_update_visuals()


func contents() -> Array:
	return (session.state.container_records[container_id] as Dictionary).bags as Array


func try_deposit_bag(player_id: StringName, bag_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_deposit_bag.bind(player_id, bag_id))
	if not session.state.players.has(player_id) or not session.state.bag_records.has(bag_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing player or disposal bag")
	var bag := session.state.bag_records[bag_id] as Dictionary
	if StringName(str(bag.category)) != category:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Bag belongs in the %s container" % str(bag.category).to_upper())
	if str(bag.location) != "HELD" or StringName(str(bag.holder_id)) != player_id:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Carry the sealed bag to deposit it")
	var player_record := session.state.players[player_id] as Dictionary
	var held := player_record.held_objects as Array[Dictionary]
	var object_ref := {"kind": "bag", "id": bag_id}
	if object_ref not in held:
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Hands disagree with disposal bag")
	held.erase(object_ref)
	player_record.selected_held_index = mini(int(player_record.selected_held_index), held.size() - 1)
	contents().append(bag_id)
	bag.location = "CONTAINER"
	bag.holder_id = &""
	bag.container_id = container_id
	session.finalize_action(PackedStringArray(), PackedStringArray([str(player_id)]), PackedStringArray(), PackedStringArray([str(bag_id)]))
	player.carry.refresh_hand_visuals()
	_update_visuals()
	player.play_cue(&"deposit", {"arm": &"right"})
	return ActionResult.accepted(PackedStringArray(), {"bag_id": str(bag_id), "container_id": str(container_id)})


func try_capture_bag(bag_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_capture_bag.bind(bag_id))
	if not session.state.bag_records.has(bag_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing disposal bag")
	var bag := session.state.bag_records[bag_id] as Dictionary
	if StringName(str(bag.category)) != category:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Wrong disposal container")
	if str(bag.location) != "WORLD":
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Bag is not in the world")
	var station := session.sorting_stations.get(StringName(str(bag.station_id))) as SortingStation
	var view := station.bag_view_for(bag_id) if station != null else null
	if view == null or not opening.overlaps_body(view) or view.linear_velocity.y >= -0.1 or view.global_position.y < opening.global_position.y - 0.02:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Bag has not entered the open top")
	contents().append(bag_id)
	bag.location = "CONTAINER"
	bag.container_id = container_id
	bag.holder_id = &""
	session.finalize_action(PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray([str(bag_id)]))
	_update_visuals()
	# The swish: a thrown bag dropping through the open top.
	FeelRing.spawn(self, opening.global_position + Vector3.UP * 0.1, 0.25, 0.8, 0.3, FEEL.shine_core_color, 0.05)
	if session.item_view_manager != null:
		session.item_view_manager.feel_sparkles(opening.global_position + Vector3.UP * 0.2, 4 if _reduced() else 8)
	return ActionResult.accepted(PackedStringArray(), {"bag_id": str(bag_id), "container_id": str(container_id), "source": "physical"})


func try_take_last_bag(player_id: StringName) -> ActionResult:
	if contents().is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Container is empty")
	var bag_id := StringName(str(contents().back()))
	var from := opening.global_transform
	var result := session.item_store.try_hold_bag(player_id, bag_id)
	if result.ok:
		player.carry.present_bag(bag_id, from)
		player.play_cue(&"hold_bag")
		player.carry.refresh_hand_visuals()
		_update_visuals()
	return result


func _on_interact_requested(target: Dictionary) -> void:
	if StringName(str(target.get("id", ""))) != container_id:
		return
	var selected := player.carry.selected_held_item()
	var bag_id := selected if session.state.bag_records.has(selected) else StringName()
	var result := try_deposit_bag(&"local", bag_id) if not bag_id.is_empty() else try_take_last_bag(&"local")
	feedback_requested.emit("Bag deposited" if result.ok and not bag_id.is_empty() else "Bag retrieved" if result.ok else result.message)
	if not result.ok:
		player.play_cue(&"rejected", {"reason": result.message})


func _on_body_entered(body: Node3D) -> void:
	if body is not DisposalBag or session == null:
		return
	var result := try_capture_bag((body as DisposalBag).bag_id)
	feedback_requested.emit("Bag deposited" if result.ok else result.message)
	if not result.ok:
		player.play_cue(&"rejected", {"reason": result.message})


func _on_bags_changed(bag_ids: PackedStringArray) -> void:
	_update_visuals(bag_ids)


func _update_visuals(changed := PackedStringArray()) -> void:
	var color: Color = COLORS.get(category, Color.MAGENTA)
	for child in get_children():
		if child is MeshInstance3D and child != fill:
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			(child as MeshInstance3D).material_override = material
	var count := contents().size()
	label.text = "%s\n%d bags" % [str(category).to_upper(), count]
	set_meta(&"interaction_verb", "Deposit or retrieve sealed bag")
	opening.set_meta(&"interaction_verb", "Deposit or retrieve sealed bag")
	if count == _shown_count:
		return
	var target := minf(float(count) / 10.0, 1.0)
	if _shown_count < 0 or _reduced():
		FeelMotion.replace(fill, &"fill", null)
		fill.visible = count > 0
		fill.scale.y = maxf(target, 0.001)
		_shown_count = count
		return
	var collected := false
	for bag_text in changed:
		var bag := session.state.bag_records.get(StringName(bag_text), {}) as Dictionary
		if str(bag.get("location", "")) == "COLLECTED":
			collected = true
	if count < _shown_count and collected:
		_lift_off()
	elif count < _shown_count:
		_set_fill(target, 0.15, Tween.TRANS_QUAD, Tween.EASE_OUT)
		FeelMotion.pop(label, Vector3.ONE * 1.2, 0.06, 0.14)
	else:
		fill.visible = true
		_set_fill(target, 0.25, Tween.TRANS_BACK, Tween.EASE_OUT)
		_wobble(0.3)
		if session.item_view_manager != null and session.item_view_manager.dust != null:
			session.item_view_manager.dust.burst(opening.global_position, Vector3.UP, 4, 0.5, 0.4, Vector2(0.04, 0.07), 0.45)
	_shown_count = count


## Collection day: the fill dips and sinks away with a whoosh of glints and dust, the container
## shakes and its label pops.
func _lift_off() -> void:
	_set_fill(0.0, FEEL.container_lift_seconds, Tween.TRANS_BACK, Tween.EASE_IN)
	var manager := session.item_view_manager
	if manager != null:
		manager.feel_sparkles(opening.global_position + Vector3.UP * 0.4, 10)
		if manager.dust != null:
			manager.dust.burst(opening.global_position + Vector3.UP * 0.2, Vector3.UP, 6, 0.9, 0.5, Vector2(0.04, 0.08), 0.5)
	_wobble(0.3)
	FeelMotion.pop(label, Vector3.ONE * 1.2, 0.06, 0.14)


func _set_fill(target: float, seconds: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	var t := FeelMotion.replace(fill, &"fill", FeelMotion.tween(fill))
	t.tween_property(fill, "scale:y", maxf(target, 0.001), seconds).set_trans(trans).set_ease(ease_type)
	if target <= 0.0:
		t.tween_callback(fill.hide)


func _wobble(seconds: float) -> void:
	var body := get_node_or_null("SyntyContainer") as Node3D
	if body == null:
		return
	var angle := deg_to_rad(2.0)
	var t := FeelMotion.replace(body, &"wobble", FeelMotion.tween(body))
	t.tween_method(func(p: float) -> void: body.rotation.z = sin(p * TAU * 2.0) * angle * (1.0 - p), 0.0, 1.0, seconds)
	t.tween_callback(func() -> void: body.rotation.z = 0.0)


func _reduced() -> bool:
	return player != null and FeelMotion.reduced(player.settings_store)


func _build_shell() -> void:
	for part in [
		{"position": Vector3(0, 0.08, 0), "size": Vector3(1.4, 0.16, 1.2)},
		{"position": Vector3(-0.66, 0.72, 0), "size": Vector3(0.08, 1.28, 1.2)},
		{"position": Vector3(0.66, 0.72, 0), "size": Vector3(0.08, 1.28, 1.2)},
		{"position": Vector3(0, 0.72, -0.56), "size": Vector3(1.4, 1.28, 0.08)},
		{"position": Vector3(0, 0.72, 0.56), "size": Vector3(1.4, 1.28, 0.08)},
	]:
		var mesh := BoxMesh.new()
		var front_band: bool = part.position.z > 0.5
		mesh.size = Vector3(1.12, 0.11, 0.035) if front_band else part.size
		var visual := MeshInstance3D.new()
		visual.position = Vector3(0, 1.2, 0.64) if front_band else part.position
		visual.mesh = mesh
		visual.visible = front_band
		add_child(visual)
		var shape := BoxShape3D.new()
		shape.size = part.size
		var collision := CollisionShape3D.new()
		collision.position = part.position
		collision.shape = shape
		add_child(collision)
