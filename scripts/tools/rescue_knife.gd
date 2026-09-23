class_name RescueKnife
extends Node3D

signal feedback_requested(message: String)

const TOOL_ID := &"knife"
const SITE_SCENE := preload("res://scenes/wildlife/rescue_site.tscn")

var session: RunSession
var player: BeachPlayer
var definition: ToolDefinition
var sites: Dictionary = {}


func configure(run_session: RunSession, player_body: BeachPlayer) -> void:
	session = run_session
	player = player_body
	definition = session.progression.offers[TOOL_ID] as ToolDefinition
	session.rescue_knife = self
	var site_ids: Array[String] = []
	for site_id in session.state.rescue_states:
		site_ids.append(str(site_id))
	site_ids.sort()
	for site_text in site_ids:
		var site_id := StringName(site_text)
		var site := SITE_SCENE.instantiate() as RescueSite
		add_child(site)
		site.configure(session, site_id)
		sites[site_id] = site


func is_active() -> bool:
	return session != null and player.input_enabled and session.progression.active_tool_id(&"local") == TOOL_ID and session.progression.is_owned(&"local", TOOL_ID) and (session.state.players[&"local"].held_objects as Array).is_empty()


func try_click() -> ActionResult:
	var target := player.interactor.current_target
	var item_id := StringName(str(target.get("id", "")))
	if item_id.is_empty() or not session.state.items.has(item_id) or (session.state.items[item_id] as ItemRecord).location != ItemRecord.Location.ATTACHED:
		feedback_requested.emit("Aim at an animal attachment")
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Aim at an animal attachment")
	var result := try_cut(item_id)
	feedback_requested.emit("Animal freed; attached litter retained for collection" if result.ok and bool(result.receipt.get("animal_freed", false)) else ("Attachment cut into bag" if result.ok and str(result.receipt.destination) == "bag" else ("Bag full — switch to stick to collect dropped attachment" if result.ok else result.message)))
	return result


func try_cut(item_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_cut.bind(item_id))
	if not is_active():
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "Equip the rescue knife")
	if not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing attachment")
	var record := session.state.items[item_id] as ItemRecord
	if record.location != ItemRecord.Location.ATTACHED:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Attachment was already removed")
	var item_definition := session.definitions.get(record.definition_id) as ItemDefinition
	if item_definition == null or item_definition.kind != ItemDefinition.Kind.WASTE or item_definition.required_tool != TOOL_ID:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Item is not a knife attachment")
	var site_id := StringName(str(record.attachment_id).get_slice("/", 0))
	if not session.state.rescue_states.has(site_id) or not sites.has(site_id):
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Attachment has no rescue site")
	var rescue := session.state.rescue_states[site_id] as Dictionary
	if bool(rescue.released) or str(item_id) not in (rescue.attachment_ids as Array):
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Rescue site disagrees with attachment")
	var site := sites[site_id] as RescueSite
	var area := site.attachment_area(item_id)
	if area == null:
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Attachment view is missing")
	var camera_origin := player.camera.global_position
	if camera_origin.distance_to(area.global_position) > definition.range or player.global_position.distance_to(area.global_position) > definition.range + 0.5:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Move within knife reach")
	var query := PhysicsRayQueryParameters3D.create(camera_origin, area.global_position, PlayerInteractor.TARGET_MASK, [player.get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != area:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Attachment is obscured")
	var player_record := session.state.players[&"local"] as Dictionary
	var free_capacity := int(player_record.bag_capacity) - (player_record.trash_bag as Array).size() - (player_record.valuable_bag as Array).size()
	var destination := "bag" if free_capacity > 0 else "world"
	var drop_pose := Transform3D.IDENTITY
	if destination == "world":
		drop_pose = _nearby_drop_pose(site, area.global_position, item_definition)
	if destination == "bag":
		(player_record.trash_bag as Array[StringName]).append(item_id)
		record.location = ItemRecord.Location.BAG
		record.holder_id = &"local"
		session.item_store.discover_definition(player_record, item_definition)
	else:
		record.location = ItemRecord.Location.WORLD
		record.holder_id = &""
		record.last_world_transform = drop_pose
		record.linear_velocity = Vector3.ZERO
		record.angular_velocity = Vector3.ZERO
		record.sleeping = false
	record.container_id = &""
	record.slot_id = &""
	record.rescuer_id = &"local"
	site.remove_attachment(item_id)
	var remaining := 0
	for attachment_text in rescue.attachment_ids:
		if (session.state.items[StringName(str(attachment_text))] as ItemRecord).location == ItemRecord.Location.ATTACHED:
			remaining += 1
	var freed := remaining == 0
	if freed:
		rescue.released = true
		site.release_animal()
	session.finalize_action(PackedStringArray([str(item_id)]))
	player.interactor.clear_target()
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {"site_id": str(site_id), "item_id": str(item_id), "destination": destination, "animal_freed": freed, "remaining": remaining})


func _nearby_drop_pose(site: RescueSite, point: Vector3, item_definition: ItemDefinition) -> Transform3D:
	var size := WorldItem.profile_size(item_definition.collision_profile)
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 4 | 8
	query.exclude = [player.get_rid()]
	for offset in [Vector3(0.7, 0, 0), Vector3(-0.7, 0, 0), Vector3(0, 0, 0.7), Vector3(0, 0, -0.7), Vector3(1.0, 0, 0.5)]:
		var candidate: Vector3 = point + offset + Vector3.UP * 0.12
		if session.item_view_manager.recovery_bounds.is_outside(candidate):
			continue
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * size.y * 0.5)
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return Transform3D(Basis.IDENTITY, candidate)
	return Transform3D(Basis.IDENTITY, site.global_position + Vector3.UP * 0.45)
