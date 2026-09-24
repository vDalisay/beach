class_name PlacementService
extends Node3D

signal feedback_requested(message: String)
signal group_completed(payload: Dictionary)

const SLOT_SCENE := preload("res://scenes/items/placement_slot.tscn")
const WORLD_ITEM_SCENE := preload("res://scenes/items/world_item.tscn")
const GHOST_SHADER := preload("res://shaders/placement_ghost.gdshader")
const GROUP_SWEEP_SHADER := preload("res://shaders/group_sweep.gdshader")
const PLAYER_ID := &"local"
const CLEARANCE_MASK := 1 | 4 | 8

static var _ghost_material: ShaderMaterial

var session: RunSession
var world_root: Node3D
var player: BeachPlayer
var carry: PlayerCarry
var slots: Dictionary = {}
var pools: Dictionary = {}
var slotted_views: Dictionary = {}
var validation_errors: PackedStringArray = []
var _preview_slot_id: StringName
var _group_sweep_serials: Dictionary = {}
var _pending_group_sweeps: Dictionary = {}


func configure(run_session: RunSession, beach_root: Node3D, player_body: BeachPlayer = null) -> void:
	session = run_session
	world_root = beach_root
	player = player_body
	carry = player.carry if player != null else null
	session.placement_service = self
	_register_authored_pools()
	_rebuild_slotted_views()
	session.group_completed.connect(_on_group_completed)
	if player != null:
		if not player.interactor.primary_requested.is_connected(_on_primary_requested):
			player.interactor.primary_requested.connect(_on_primary_requested)
			player.interactor.target_changed.connect(_on_target_changed)


func preview_slot(player_id: StringName, slot_id: StringName) -> ActionResult:
	var item_id := _selected_held_item(player_id)
	var result := _validate_placement(player_id, item_id, slot_id, ItemRecord.Location.HELD, true)
	if result.ok:
		_show_ghost(slot_id, item_id)
	else:
		clear_preview()
	return result


func try_place(player_id: StringName, slot_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_place.bind(player_id, slot_id))
	var item_id := _selected_held_item(player_id)
	var validation := _validate_placement(player_id, item_id, slot_id, ItemRecord.Location.HELD, true)
	if not validation.ok:
		return validation
	var player_record := session.state.players[player_id] as Dictionary
	var held := player_record[&"held_objects"] as Array[Dictionary]
	var selected := int(player_record.get("selected_held_index", -1))
	var source_transform := _held_source_transform(item_id)
	held.remove_at(selected)
	player_record[&"held_objects"] = held
	player_record[&"selected_held_index"] = mini(selected, held.size() - 1) if not held.is_empty() else -1
	_commit_to_slot(item_id, slot_id)
	clear_preview()
	session.finalize_action(PackedStringArray([str(item_id)]), PackedStringArray([str(player_id)]))
	_animate_to_slot(item_id, slot_id, source_transform)
	if carry != null:
		carry.refresh_hand_visuals()
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {
		"item_id": str(item_id),
		"slot_id": str(slot_id),
		"pool_id": str((slots[slot_id] as Dictionary).pool_id),
	})


func try_capture(item_id: StringName, slot_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_capture.bind(item_id, slot_id))
	var validation := _validate_placement(&"", item_id, slot_id, ItemRecord.Location.WORLD, false)
	if not validation.ok:
		return validation
	var view := session.item_view_manager.view_for(item_id) if session.item_view_manager != null else null
	if view == null or view.freeze or view.sleeping or not _capture_entry_is_valid(view, slot_id):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Prop has not entered the slot opening")
	var source_transform := view.global_transform
	_commit_to_slot(item_id, slot_id)
	session.finalize_action(PackedStringArray([str(item_id)]))
	var presentation := session.item_view_manager.take_view_for_presentation(item_id)
	_animate_to_slot(item_id, slot_id, source_transform, presentation)
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {
		"item_id": str(item_id),
		"slot_id": str(slot_id),
		"source": "physical_capture",
	})


func try_remove(player_id: StringName, slot_id: StringName, target_context: Dictionary = {}) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_remove.bind(player_id, slot_id, target_context))
	if not slots.has(slot_id) or not session.state.players.has(player_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing player or placement slot")
	var item_id := occupant_for(slot_id)
	if item_id.is_empty() or not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Placement slot is empty")
	var target_error := _validate_target_context(item_id, target_context)
	if target_error != null:
		return target_error
	var player_record := session.state.players[player_id] as Dictionary
	var definition := _definition_for_item(item_id)
	if _held_hand_cost(player_record) + definition.hand_cost > int(player_record.get("hand_capacity", 2)):
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Player %s hands are full" % player_id)
	var held := player_record[&"held_objects"] as Array[Dictionary]
	held.append({"kind": "item", "id": item_id})
	player_record[&"held_objects"] = held
	player_record[&"selected_held_index"] = held.size() - 1
	var record := session.state.items[item_id] as ItemRecord
	_release_slot(slot_id)
	record.location = ItemRecord.Location.HELD
	record.holder_id = player_id
	record.slot_id = &""
	record.container_id = &""
	_remove_slotted_view(item_id)
	clear_preview()
	session.finalize_action(PackedStringArray([str(item_id)]), PackedStringArray([str(player_id)]))
	if carry != null:
		carry.refresh_hand_visuals()
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {
		"item_id": str(item_id),
		"source": "slot",
		"slot_id": str(slot_id),
	})


func target_result(slot_id: StringName, collider: CollisionObject3D, hit_point: Vector3, distance: float) -> Dictionary:
	if not slots.has(slot_id):
		return {}
	var occupant := occupant_for(slot_id)
	if not occupant.is_empty():
		clear_preview()
		var definition := _definition_for_item(occupant)
		var actions := PackedStringArray()
		var reason := ""
		var player_record := session.state.players.get(PLAYER_ID, {}) as Dictionary
		if definition == null:
			reason = "Missing item definition"
		elif _held_hand_cost(player_record) + definition.hand_cost > int(player_record.get("hand_capacity", 2)):
			reason = "Hands full"
		else:
			actions.append("hold")
		return {
			"actions": actions,
			"collider": collider,
			"display_name": definition.display_name if definition != null else str(occupant),
			"distance": distance,
			"hit_point": hit_point,
			"id": occupant,
			"kind": "item",
			"reason": reason,
			"slot_id": slot_id,
		}
	var preview := preview_slot(PLAYER_ID, slot_id)
	var selected := _selected_held_item(PLAYER_ID)
	var selected_definition := _definition_for_item(selected)
	return {
		"actions": PackedStringArray(["place"]) if preview.ok else PackedStringArray(),
		"collider": collider,
		"display_name": "Place %s" % selected_definition.display_name if selected_definition != null else "Placement slot",
		"distance": distance,
		"hit_point": hit_point,
		"id": slot_id,
		"kind": "slot",
		"reason": preview.message,
		"slot_id": slot_id,
	}


func clear_preview() -> void:
	if _preview_slot_id.is_empty() or not slots.has(_preview_slot_id):
		_preview_slot_id = &""
		return
	var ghost := ((slots[_preview_slot_id] as Dictionary).area as Area3D).get_node("GhostRoot") as Node3D
	ghost.hide()
	for child in ghost.get_children():
		child.queue_free()
	_preview_slot_id = &""


func occupant_for(slot_id: StringName) -> StringName:
	if not slots.has(slot_id):
		return StringName()
	var pool_id := StringName(str((slots[slot_id] as Dictionary).pool_id))
	var pool_record := session.state.container_records.get(pool_id, {}) as Dictionary
	return StringName(str((pool_record.get("occupants", {}) as Dictionary).get(slot_id, "")))


func slot_transform(slot_id: StringName) -> Transform3D:
	return (slots[slot_id] as Dictionary).transform as Transform3D if slots.has(slot_id) else Transform3D.IDENTITY


func _register_authored_pools() -> void:
	var authored: Array[PlacementSlot] = []
	_collect_pools(world_root, authored)
	authored.sort_custom(func(a: PlacementSlot, b: PlacementSlot) -> bool: return str(a.pool_id) < str(b.pool_id))
	var shared_capacity := -1
	var shared_families := PackedStringArray()
	for pool in authored:
		if pools.has(pool.pool_id):
			validation_errors.append("Duplicate placement pool: %s" % pool.pool_id)
			continue
		pools[pool.pool_id] = pool
		if pool.accepted_families.size() > 1:
			if shared_capacity < 0:
				shared_capacity = pool.capacity
				shared_families = pool.accepted_families
			elif pool.capacity != shared_capacity or pool.accepted_families != shared_families:
				validation_errors.append("Shared shelf pools must use uniform capacity and families")
		_ensure_pool_record(pool)
		for index in range(pool.capacity):
			_register_slot(pool, index)
	_reconcile_slotted_records()


func _collect_pools(node: Node, result: Array[PlacementSlot]) -> void:
	if node is PlacementSlot:
		result.append(node as PlacementSlot)
	for child in node.get_children():
		_collect_pools(child, result)


func _ensure_pool_record(pool: PlacementSlot) -> void:
	if not session.state.container_records.has(pool.pool_id):
		session.state.container_records[pool.pool_id] = {
			"kind": "placement_pool",
			"accepted_families": Array(pool.accepted_families),
			"capacity": pool.capacity,
			"claim": StringName(),
			"occupants": {},
		}
		return
	var record := session.state.container_records[pool.pool_id] as Dictionary
	record["kind"] = "placement_pool"
	record["accepted_families"] = Array(pool.accepted_families)
	record["capacity"] = pool.capacity
	if not record.has("claim"):
		record["claim"] = StringName()
	if not record.has("occupants"):
		record["occupants"] = {}


func _register_slot(pool: PlacementSlot, index: int) -> void:
	var slot_id := pool.derived_slot_id(index)
	if slots.has(slot_id):
		validation_errors.append("Duplicate placement slot: %s" % slot_id)
		return
	var area := SLOT_SCENE.instantiate() as Area3D
	area.name = "Slot_%03d" % index
	pool.add_child(area)
	area.transform = pool.local_slot_transform(index)
	area.set_meta(&"placement_slot_id", slot_id)
	area.set_meta(&"target_id", slot_id)
	area.set_meta(&"display_name", "Placement slot")
	var collision := area.get_node("CaptureShape") as CollisionShape3D
	var shape := collision.shape.duplicate() as BoxShape3D
	shape.size = pool.capture_size()
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	area.body_entered.connect(_on_slot_body_entered.bind(slot_id))
	slots[slot_id] = {
		"area": area,
		"index": index,
		"pool_id": pool.pool_id,
		"transform": pool.global_transform * pool.local_slot_transform(index),
	}


func _reconcile_slotted_records() -> void:
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if record.location != ItemRecord.Location.SLOTTED or not slots.has(record.slot_id):
			continue
		var pool_id := StringName(str((slots[record.slot_id] as Dictionary).pool_id))
		var pool_record := session.state.container_records[pool_id] as Dictionary
		var occupants := pool_record["occupants"] as Dictionary
		if not occupants.has(record.slot_id):
			occupants[record.slot_id] = record.item_id
		if StringName(str(pool_record.get("claim", ""))).is_empty():
			pool_record["claim"] = _definition_for_item(record.item_id).sorting_family


func _validate_placement(player_id: StringName, item_id: StringName, slot_id: StringName, source: ItemRecord.Location, require_range: bool) -> ActionResult:
	if item_id.is_empty():
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Hold a prop to place")
	if not slots.has(slot_id) or not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing item or placement slot")
	var record := session.state.items[item_id] as ItemRecord
	var definition := _definition_for_item(item_id)
	if definition == null or definition.kind != ItemDefinition.Kind.PROP:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Only reusable props use placement slots")
	if record.location != source:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "%s is not available for placement" % definition.display_name)
	if source == ItemRecord.Location.HELD and record.holder_id != player_id:
		return ActionResult.rejected(ActionResult.Reason.INVALID_OWNER, "%s is held by another player" % definition.display_name)
	if not record.dirty_patches_remaining.is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Needs cloth before placement")
	if not occupant_for(slot_id).is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Placement slot is occupied")
	var descriptor := slots[slot_id] as Dictionary
	var pool_id := StringName(str(descriptor.pool_id))
	var pool_record := session.state.container_records[pool_id] as Dictionary
	var accepted := pool_record["accepted_families"] as Array
	if definition.sorting_family not in accepted:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "This slot does not accept %s" % definition.sorting_family)
	var claim := StringName(str(pool_record.get("claim", "")))
	if not claim.is_empty() and claim != definition.sorting_family:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Shelf is reserved for %s" % str(claim).replace("_", " "))
	if claim.is_empty() and accepted.size() > 1 and not _shared_claim_is_safe(pool_id, definition.sorting_family, item_id):
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Use an existing %s section with room" % str(definition.sorting_family).replace("_", " "))
	if require_range and (player == null or player.global_position.distance_to((descriptor.transform as Transform3D).origin) > player.interactor.reach):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Placement slot is out of reach")
	if not _slot_clear_for(item_id, slot_id, source == ItemRecord.Location.WORLD):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Placement slot is blocked")
	return ActionResult.accepted(PackedStringArray(), {
		"item_id": str(item_id),
		"slot_id": str(slot_id),
		"transform": descriptor.transform,
	})


func _shared_claim_is_safe(candidate_pool_id: StringName, family: StringName, placing_item_id: StringName) -> bool:
	var shared_pools: Array[StringName] = []
	var families: Array[StringName] = []
	var section_capacity := 0
	for pool_key in pools:
		var pool := pools[pool_key] as PlacementSlot
		if pool.accepted_families.size() <= 1:
			continue
		shared_pools.append(StringName(pool_key))
		section_capacity = pool.capacity
		for accepted_family in pool.accepted_families:
			var accepted_name := StringName(accepted_family)
			if accepted_name not in families:
				families.append(accepted_name)
	var unclaimed := 0
	var free_by_family: Dictionary = {}
	for pool_id in shared_pools:
		var pool_record := session.state.container_records[pool_id] as Dictionary
		var claim := StringName(str(pool_record.get("claim", "")))
		var occupant_count := (pool_record["occupants"] as Dictionary).size()
		if pool_id == candidate_pool_id and claim.is_empty():
			claim = family
			occupant_count += 1
		if claim.is_empty():
			unclaimed += 1
		else:
			free_by_family[claim] = int(free_by_family.get(claim, 0)) + int(pool_record.capacity) - occupant_count
	var needed_sections := 0
	for family_id in families:
		var remaining := 0
		for item_value in session.state.items.values():
			var record := item_value as ItemRecord
			var definition := _definition_for_item(record.item_id)
			if record.required and definition != null and definition.sorting_family == family_id and record.location != ItemRecord.Location.SLOTTED:
				remaining += 1
		if family_id == family and (session.state.items[placing_item_id] as ItemRecord).location != ItemRecord.Location.SLOTTED:
			remaining -= 1
		var deficit := maxi(0, remaining - int(free_by_family.get(family_id, 0)))
		needed_sections += ceili(float(deficit) / float(section_capacity)) if deficit > 0 else 0
	return needed_sections <= unclaimed


func _slot_clear_for(item_id: StringName, slot_id: StringName, exclude_world_item: bool) -> bool:
	var definition := _definition_for_item(item_id)
	var size := WorldItem.profile_size(definition.collision_profile)
	var descriptor := slots[slot_id] as Dictionary
	var destination := descriptor.transform as Transform3D
	var offset := _upright_offset(destination.basis, size)
	var shape := BoxShape3D.new()
	shape.size = size * 0.92
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(destination.basis, destination.origin + Vector3.UP * offset + destination.basis * Vector3(0, size.y * 0.5, 0))
	query.collision_mask = CLEARANCE_MASK
	if exclude_world_item and session.item_view_manager != null:
		var view := session.item_view_manager.view_for(item_id)
		if view != null:
			query.exclude = [view.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _capture_entry_is_valid(view: WorldItem, slot_id: StringName) -> bool:
	var area := (slots[slot_id] as Dictionary).area as Area3D
	if view not in area.get_overlapping_bodies():
		return false
	var destination := slot_transform(slot_id).origin + Vector3.UP * 0.15
	var ray := PhysicsRayQueryParameters3D.create(view.global_position + Vector3.UP * 0.15, destination, 1 | 8, [view.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _commit_to_slot(item_id: StringName, slot_id: StringName) -> void:
	var record := session.state.items[item_id] as ItemRecord
	var definition := _definition_for_item(item_id)
	var descriptor := slots[slot_id] as Dictionary
	var pool_id := StringName(str(descriptor.pool_id))
	var pool_record := session.state.container_records[pool_id] as Dictionary
	var occupants := pool_record["occupants"] as Dictionary
	occupants[slot_id] = item_id
	pool_record["claim"] = definition.sorting_family
	record.location = ItemRecord.Location.SLOTTED
	record.holder_id = &""
	record.container_id = &""
	record.slot_id = slot_id
	record.last_world_transform = descriptor.transform
	record.linear_velocity = Vector3.ZERO
	record.angular_velocity = Vector3.ZERO
	record.sleeping = true


func _release_slot(slot_id: StringName) -> void:
	var pool_id := StringName(str((slots[slot_id] as Dictionary).pool_id))
	var pool_record := session.state.container_records[pool_id] as Dictionary
	var occupants := pool_record["occupants"] as Dictionary
	occupants.erase(slot_id)
	if occupants.is_empty():
		pool_record["claim"] = StringName()


func _show_ghost(slot_id: StringName, item_id: StringName) -> void:
	if _preview_slot_id == slot_id:
		return
	clear_preview()
	var descriptor := slots[slot_id] as Dictionary
	var area := descriptor.area as Area3D
	var ghost := area.get_node("GhostRoot") as Node3D
	var definition := _definition_for_item(item_id)
	ghost.position = area.global_basis.inverse() * Vector3.UP * _upright_offset((descriptor.transform as Transform3D).basis, WorldItem.profile_size(definition.collision_profile))
	var visual := _create_visual(definition)
	ghost.add_child(visual)
	_apply_ghost_material(visual)
	ghost.show()
	_preview_slot_id = slot_id


func _animate_to_slot(item_id: StringName, slot_id: StringName, source_transform: Transform3D, physical_view: WorldItem = null) -> void:
	var descriptor := slots[slot_id] as Dictionary
	var area := descriptor.area as Area3D
	var definition := _definition_for_item(item_id)
	var destination := Marker3D.new()
	area.add_child(destination)
	destination.position = area.global_basis.inverse() * Vector3.UP * _upright_offset((descriptor.transform as Transform3D).basis, WorldItem.profile_size(definition.collision_profile))
	var finish := func() -> void:
		if is_instance_valid(destination):
			destination.queue_free()
		if (session.state.items[item_id] as ItemRecord).location == ItemRecord.Location.SLOTTED and (session.state.items[item_id] as ItemRecord).slot_id == slot_id:
			_ensure_slotted_view(item_id)
			_pulse_slotted_view(item_id)
			_try_start_pending_sweeps()
	if physical_view != null:
		physical_view.travel_to(destination, 0.25, false, finish)
		return
	var presentation := _create_visual(definition)
	add_child(presentation)
	presentation.global_transform = source_transform
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(presentation, "global_transform", destination.global_transform, 0.25)
	tween.tween_callback(func() -> void:
		presentation.queue_free()
		finish.call()
	)


func _ensure_slotted_view(item_id: StringName) -> void:
	if slotted_views.has(item_id) or not session.state.items.has(item_id):
		return
	var record := session.state.items[item_id] as ItemRecord
	if record.location != ItemRecord.Location.SLOTTED or not slots.has(record.slot_id):
		return
	var definition := _definition_for_item(item_id)
	var descriptor := slots[record.slot_id] as Dictionary
	var area := descriptor.area as Area3D
	var body := StaticBody3D.new()
	body.name = "Placed_%s" % str(item_id).replace(":", "_")
	body.collision_layer = 4 | (8 if definition.collision_profile == ItemDefinition.CollisionProfile.LARGE else 0)
	body.collision_mask = 0
	body.set_meta(&"placement_slot_id", record.slot_id)
	area.add_child(body)
	var size := WorldItem.profile_size(definition.collision_profile)
	var offset_local := area.global_basis.inverse() * Vector3.UP * _upright_offset((descriptor.transform as Transform3D).basis, size)
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.position = offset_local
	body.add_child(visual_root)
	visual_root.add_child(_create_visual(definition))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = offset_local + Vector3(0, size.y * 0.5, 0)
	body.add_child(collision)
	slotted_views[item_id] = body


func _remove_slotted_view(item_id: StringName) -> void:
	if not slotted_views.has(item_id):
		return
	var view: Variant = slotted_views[item_id]
	slotted_views.erase(item_id)
	if is_instance_valid(view):
		if view is CollisionObject3D:
			(view as CollisionObject3D).collision_layer = 0
			(view as CollisionObject3D).collision_mask = 0
		(view as Node).queue_free()


func _pulse_slotted_view(item_id: StringName) -> void:
	if not slotted_views.has(item_id):
		return
	var visual_root := (slotted_views[item_id] as Node3D).get_node("VisualRoot") as Node3D
	if _reduced_motion():
		return
	visual_root.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3.ONE * 1.08, 0.125)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.125)


func _on_group_completed(payload: Dictionary) -> void:
	group_completed.emit(payload)
	var group_id := StringName(str(payload.get("group_id", "")))
	_group_sweep_serials[group_id] = int(_group_sweep_serials.get(group_id, 0)) + 1
	_pending_group_sweeps[group_id] = int(_group_sweep_serials[group_id])
	call_deferred("_try_start_pending_sweeps")


func _try_start_pending_sweeps() -> void:
	for group_id in _pending_group_sweeps.keys():
		if not session.state.group_states.has(group_id) or not bool((session.state.group_states[group_id] as Dictionary).complete):
			_pending_group_sweeps.erase(group_id)
			continue
		var ready := true
		for item_id in session.progress_service.group_items.get(group_id, []):
			if not slotted_views.has(item_id):
				ready = false
				break
		if ready:
			var serial := int(_pending_group_sweeps[group_id])
			_pending_group_sweeps.erase(group_id)
			_show_group_sweep(group_id, serial)


func _show_group_sweep(group_id: StringName, serial: int) -> void:
	if not is_inside_tree() or _reduced_motion() or int(_group_sweep_serials.get(group_id, 0)) != serial:
		return
	if not session.state.group_states.has(group_id) or not bool((session.state.group_states[group_id] as Dictionary).complete):
		return
	var meshes: Array[MeshInstance3D] = []
	var positions: Array[Vector3] = []
	for item_id in session.progress_service.group_items.get(group_id, []):
		if not slotted_views.has(item_id):
			continue
		var root := (slotted_views[item_id] as Node3D).get_node("VisualRoot") as Node3D
		positions.append(root.global_position)
		_collect_sweep_meshes(root, meshes)
	if meshes.is_empty():
		return
	var origin := positions[0]
	var direction := Vector3.RIGHT
	var minimum := 0.0
	var maximum := 0.0
	for position in positions:
		var offset := (position - origin).dot(direction)
		minimum = minf(minimum, offset)
		maximum = maxf(maximum, offset)
	var material := ShaderMaterial.new()
	material.shader = GROUP_SWEEP_SHADER
	material.set_shader_parameter("sweep_origin", origin + direction * (minimum - 0.5))
	material.set_shader_parameter("sweep_direction", direction)
	material.set_shader_parameter("sweep_distance", maximum - minimum + 1.0)
	for mesh in meshes:
		mesh.material_overlay = material
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("sweep_progress", value), 0.0, 1.0, 0.7)
	tween.finished.connect(func() -> void:
		for mesh in meshes:
			if is_instance_valid(mesh) and mesh.material_overlay == material:
				mesh.material_overlay = null
	)


func _collect_sweep_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			result.append(child as MeshInstance3D)
		_collect_sweep_meshes(child, result)


func _reduced_motion() -> bool:
	return player != null and player.settings_store != null and bool(player.settings_store.get_value(&"reduced_motion"))


func _rebuild_slotted_views() -> void:
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if record.location == ItemRecord.Location.SLOTTED:
			_ensure_slotted_view(record.item_id)


func _create_visual(definition: ItemDefinition) -> Node3D:
	var root := Node3D.new()
	var packed := load(definition.visual_scene_path) as PackedScene
	if packed != null and definition.visual_scene_path != "res://art/placeholders/missing_asset.tscn":
		root.add_child(packed.instantiate())
		return root
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	var size := WorldItem.profile_size(definition.collision_profile)
	box.size = size
	mesh.mesh = box
	mesh.position.y = size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("efad47")
	material.roughness = 0.78
	mesh.material_override = material
	root.add_child(mesh)
	return root


func _apply_ghost_material(node: Node) -> void:
	if _ghost_material == null:
		_ghost_material = ShaderMaterial.new()
		_ghost_material.shader = GHOST_SHADER
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _ghost_material
	for child in node.get_children():
		_apply_ghost_material(child)


func _upright_offset(basis: Basis, size: Vector3) -> float:
	var minimum_y := INF
	for x in [-size.x * 0.5, size.x * 0.5]:
		for y in [0.0, size.y]:
			for z in [-size.z * 0.5, size.z * 0.5]:
				minimum_y = minf(minimum_y, (basis * Vector3(x, y, z)).y)
	return -minimum_y + 0.015


func _selected_held_item(player_id: StringName) -> StringName:
	if not session.state.players.has(player_id):
		return StringName()
	var player_record := session.state.players[player_id] as Dictionary
	var held := player_record[&"held_objects"] as Array[Dictionary]
	var selected := int(player_record.get("selected_held_index", -1))
	if selected < 0 or selected >= held.size():
		return StringName()
	return StringName(str(held[selected].get("id", "")))


func _held_source_transform(item_id: StringName) -> Transform3D:
	if carry == null:
		return Transform3D.IDENTITY
	var definition := _definition_for_item(item_id)
	if definition.hand_cost == 2:
		return carry.hand_rig.presentation_transform(carry.hand_rig.large_prop_socket)
	var player_record := session.state.players[PLAYER_ID] as Dictionary
	return carry.hand_rig.presentation_transform(carry.hand_rig.left_prop_socket if int(player_record.get("selected_held_index", 0)) == 0 else carry.hand_rig.right_prop_socket)


func _held_hand_cost(player_record: Dictionary) -> int:
	var cost := 0
	for object_value in player_record.get("held_objects", []):
		var item_id := StringName(str((object_value as Dictionary).get("id", "")))
		var definition := _definition_for_item(item_id)
		if definition != null:
			cost += definition.hand_cost
	return cost


func _definition_for_item(item_id: StringName) -> ItemDefinition:
	if not session.state.items.has(item_id):
		return null
	return session.definitions.get((session.state.items[item_id] as ItemRecord).definition_id) as ItemDefinition


func _validate_target_context(item_id: StringName, context: Dictionary) -> ActionResult:
	if context.is_empty():
		return null
	if StringName(str(context.get("target_id", ""))) != item_id or not bool(context.get("visible", false)):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "%s is not the visible target" % item_id)
	if float(context.get("distance", INF)) > float(context.get("reach", 0.0)) + 0.01:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "%s is out of reach" % item_id)
	return null


func _on_slot_body_entered(body: Node3D, slot_id: StringName) -> void:
	var view := body as WorldItem
	if view == null or view.record == null or view.record.location != ItemRecord.Location.WORLD:
		return
	try_capture(view.item_id, slot_id)


func _on_primary_requested(target: Dictionary) -> void:
	if not (target.get("actions", PackedStringArray()) as PackedStringArray).has("place"):
		return
	var result := try_place(PLAYER_ID, StringName(str(target.get("slot_id", target.get("id", "")))))
	if not result.ok:
		feedback_requested.emit(result.message)


func _on_target_changed(target: Dictionary) -> void:
	var actions := target.get("actions", PackedStringArray()) as PackedStringArray
	if not actions.has("place") or StringName(str(target.get("slot_id", ""))) != _preview_slot_id:
		clear_preview()
