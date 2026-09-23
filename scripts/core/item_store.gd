class_name ItemStore
extends RefCounted

const ITEM_REF_KIND := "item"

var _session: RunSession
var _definitions: Dictionary


func _init(session: RunSession, item_definitions: Dictionary) -> void:
	_session = session
	_definitions = item_definitions


func try_collect(player_id: StringName, item_id: StringName, target_context: Dictionary = {}) -> ActionResult:
	if _session.is_publishing():
		return _session.defer_action(try_collect.bind(player_id, item_id, target_context))
	var player_result: Variant = _player_or_error(player_id)
	if player_result is ActionResult:
		return player_result as ActionResult
	var player := player_result as Dictionary
	var record_result: Variant = _record_or_error(item_id)
	if record_result is ActionResult:
		return record_result as ActionResult
	var record := record_result as ItemRecord
	var definition_result: Variant = _definition_or_error(record)
	if definition_result is ActionResult:
		return definition_result as ActionResult
	var definition := definition_result as ItemDefinition

	if record.location != ItemRecord.Location.WORLD:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "%s is not in the world" % item_id)
	if definition.kind != ItemDefinition.Kind.WASTE and definition.kind != ItemDefinition.Kind.VALUABLE:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "%s cannot enter a collection bag" % item_id)
	var target_error := _validate_target_context(item_id, target_context)
	if target_error != null:
		return target_error
	var required_tool := collection_tool_for(record, definition)
	if not required_tool.is_empty() and _active_tool(player) != required_tool:
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "%s requires %s" % [definition.display_name, required_tool])

	var bag_key := &"valuable_bag" if definition.kind == ItemDefinition.Kind.VALUABLE else &"trash_bag"
	var bag := player[bag_key] as Array[StringName]
	var total_bagged := (player[&"trash_bag"] as Array).size() + (player[&"valuable_bag"] as Array).size()
	if total_bagged >= int(player.get("bag_capacity", 20)):
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Player %s bag is full" % player_id)

	bag.append(item_id)
	player[bag_key] = bag
	(player[&"bag_order"] as Array[StringName]).append(item_id)
	_commit_record_transfer(record, ItemRecord.Location.BAG, player_id)
	discover_definition(player, definition)
	if definition.kind == ItemDefinition.Kind.VALUABLE and item_id not in _session.state.optional_finds:
		_session.state.optional_finds.append(item_id)
	var changed := PackedStringArray([str(item_id)])
	_session.finalize_action(changed)
	return ActionResult.accepted(changed, {"item_id": str(item_id), "destination": str(bag_key)})


static func collection_tool_for(record: ItemRecord, definition: ItemDefinition) -> StringName:
	if record.location == ItemRecord.Location.WORLD:
		if definition.required_tool == &"detector" and record.revealed:
			return &"stick"
		if definition.required_tool == &"knife" and not record.rescuer_id.is_empty():
			return &"stick"
	return definition.required_tool


func try_hold(player_id: StringName, item_id: StringName, target_context: Dictionary = {}) -> ActionResult:
	if _session.is_publishing():
		return _session.defer_action(try_hold.bind(player_id, item_id, target_context))
	var player_result: Variant = _player_or_error(player_id)
	if player_result is ActionResult:
		return player_result as ActionResult
	var player := player_result as Dictionary
	var record_result: Variant = _record_or_error(item_id)
	if record_result is ActionResult:
		return record_result as ActionResult
	var record := record_result as ItemRecord
	var definition_result: Variant = _definition_or_error(record)
	if definition_result is ActionResult:
		return definition_result as ActionResult
	var definition := definition_result as ItemDefinition

	if record.location == ItemRecord.Location.SLOTTED:
		if _session.placement_service == null:
			return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "%s has no active placement service" % item_id)
		return _session.placement_service.try_remove(player_id, record.slot_id, target_context)
	if record.location != ItemRecord.Location.WORLD:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "%s cannot be held from its current state" % item_id)
	if definition.kind != ItemDefinition.Kind.PROP:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "%s is not a reusable prop" % item_id)
	var target_error := _validate_target_context(item_id, target_context)
	if target_error != null:
		return target_error
	if _current_hand_cost(player) + definition.hand_cost > int(player.get("hand_capacity", 2)):
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Player %s hands are full" % player_id)

	var held := player[&"held_objects"] as Array[Dictionary]
	held.append({"kind": ITEM_REF_KIND, "id": item_id})
	player[&"held_objects"] = held
	player[&"selected_held_index"] = held.size() - 1
	_commit_record_transfer(record, ItemRecord.Location.HELD, player_id)
	discover_definition(player, definition)
	var changed := PackedStringArray([str(item_id)])
	_session.finalize_action(changed, PackedStringArray([str(player_id)]))
	return ActionResult.accepted(changed, {"item_id": str(item_id), "destination": "held"})


func try_hold_bag(player_id: StringName, bag_id: StringName, target_context: Dictionary = {}) -> ActionResult:
	if _session.is_publishing():
		return _session.defer_action(try_hold_bag.bind(player_id, bag_id, target_context))
	var player_result: Variant = _player_or_error(player_id)
	if player_result is ActionResult:
		return player_result as ActionResult
	var player := player_result as Dictionary
	if not _session.state.bag_records.has(bag_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing disposal bag")
	var bag := _session.state.bag_records[bag_id] as Dictionary
	if str(bag.location) not in ["RACK", "WORLD", "CONTAINER"]:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Disposal bag is not available to carry")
	var target_error := _validate_target_context(bag_id, target_context)
	if target_error != null:
		return target_error
	if _current_hand_cost(player) + 1 > int(player.get("hand_capacity", 2)):
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Hands are full")
	var source_station := _session.sorting_stations.get(StringName(str(bag.station_id))) as SortingStation
	if source_station == null:
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Disposal bag has no source station")
	var freed_rack := false
	var source_location := str(bag.location)
	match source_location:
		"RACK":
			var slot := int(bag.rack_slot)
			var rack_slots := source_station.rack_record().slots as Dictionary
			if rack_slots.get(slot) != bag_id:
				return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Rack slot disagrees with bag")
			rack_slots.erase(slot)
			freed_rack = true
		"CONTAINER":
			var container_id := StringName(str(bag.container_id))
			if not _session.state.container_records.has(container_id):
				return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Missing bag container")
			var contents := (_session.state.container_records[container_id] as Dictionary).bags as Array
			if bag_id not in contents:
				return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Container disagrees with bag")
			contents.erase(bag_id)
		"WORLD":
			var view := source_station.bag_view_for(bag_id)
			if view != null:
				view.synchronize_record()
	var held := player.held_objects as Array[Dictionary]
	held.append({"kind": "bag", "id": bag_id})
	player.held_objects = held
	player.selected_held_index = held.size() - 1
	bag.location = "HELD"
	bag.holder_id = player_id
	bag.container_id = &""
	bag.rack_slot = -1
	var changed_items := PackedStringArray()
	var changed_bags := PackedStringArray([str(bag_id)])
	if freed_rack:
		var waiting := source_station.seal_waiting_full_bin()
		if not waiting.is_empty():
			for item_id in waiting.item_ids:
				changed_items.append(str(item_id))
			changed_bags.append(str(waiting.bag_id))
	_session.finalize_action(changed_items, PackedStringArray([str(player_id)]), PackedStringArray(), changed_bags)
	if freed_rack:
		source_station.contents_changed.emit()
	return ActionResult.accepted(changed_items, {"bag_id": str(bag_id), "source": source_location})


func try_throw(player_id: StringName, spawn_transform: Transform3D, impulse: Vector3, spawn_clear := true) -> ActionResult:
	if _session.is_publishing():
		return _session.defer_action(try_throw.bind(player_id, spawn_transform, impulse, spawn_clear))
	if not spawn_transform.is_finite() or not impulse.is_finite():
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Throw transform or impulse is invalid")
	if not spawn_clear:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Throw path is blocked")
	var player_result: Variant = _player_or_error(player_id)
	if player_result is ActionResult:
		return player_result as ActionResult
	var player := player_result as Dictionary
	var item_id: StringName
	var hands_changed := false
	var held := player[&"held_objects"] as Array[Dictionary]
	var source_key: StringName
	if not held.is_empty():
		var object_ref := held[held.size() - 1] as Dictionary
		if str(object_ref.get("kind", "")) == "bag":
			var bag_id := StringName(str(object_ref.get("id", "")))
			if not _session.state.bag_records.has(bag_id):
				return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Missing held disposal bag")
			var bag := _session.state.bag_records[bag_id] as Dictionary
			if str(bag.location) != "HELD" or StringName(str(bag.holder_id)) != player_id:
				return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Held disposal bag owner disagrees")
			held.pop_back()
			player.held_objects = held
			player.selected_held_index = mini(int(player.get("selected_held_index", -1)), held.size() - 1)
			bag.location = "WORLD"
			bag.holder_id = &""
			bag.world_transform = ItemRecord._transform_to_array(spawn_transform)
			bag.linear_velocity = ItemRecord._vector_to_array(impulse)
			bag.angular_velocity = ItemRecord._vector_to_array(Vector3.ZERO)
			bag.sleeping = false
			_session.finalize_action(PackedStringArray(), PackedStringArray([str(player_id)]), PackedStringArray(), PackedStringArray([str(bag_id)]))
			return ActionResult.accepted(PackedStringArray(), {"bag_id": str(bag_id), "source": "held_objects"})
		if str(object_ref.get("kind", "")) != ITEM_REF_KIND:
			return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Latest held object has an invalid kind")
		item_id = StringName(str(object_ref.get("id", "")))
		hands_changed = true
		source_key = &"held_objects"
	else:
		var trash_bag := player[&"trash_bag"] as Array[StringName]
		var valuable_bag := player[&"valuable_bag"] as Array[StringName]
		var bag_order := player[&"bag_order"] as Array[StringName]
		if bag_order.is_empty():
			return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Player %s has nothing to throw" % player_id)
		item_id = bag_order.back()
		if item_id in trash_bag and trash_bag.back() == item_id:
			source_key = &"trash_bag"
		elif item_id in valuable_bag and valuable_bag.back() == item_id:
			source_key = &"valuable_bag"
		else:
			return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Bag order disagrees with owner list")

	var record_result: Variant = _record_or_error(item_id)
	if record_result is ActionResult:
		return record_result as ActionResult
	var record := record_result as ItemRecord
	var expected_location := ItemRecord.Location.HELD if hands_changed else ItemRecord.Location.BAG
	if record.location != expected_location or record.holder_id != player_id:
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Owner list disagrees with item %s" % item_id)
	var definition_result: Variant = _definition_or_error(record)
	if definition_result is ActionResult:
		return definition_result as ActionResult

	if source_key == &"held_objects":
		held.pop_back()
		player[source_key] = held
		player[&"selected_held_index"] = mini(int(player.get("selected_held_index", -1)), held.size() - 1)
	else:
		var bag := player[source_key] as Array[StringName]
		bag.pop_back()
		player[source_key] = bag
		(player[&"bag_order"] as Array[StringName]).pop_back()
	_commit_record_transfer(record, ItemRecord.Location.WORLD, &"")
	record.last_world_transform = spawn_transform
	record.linear_velocity = impulse
	record.angular_velocity = Vector3.ZERO
	record.sleeping = false
	var changed := PackedStringArray([str(item_id)])
	var hand_players := PackedStringArray([str(player_id)]) if hands_changed else PackedStringArray()
	_session.finalize_action(changed, hand_players)
	return ActionResult.accepted(changed, {"item_id": str(item_id), "source": str(source_key)})


func peek_throw_item(player_id: StringName) -> StringName:
	if not _session.state.players.has(player_id):
		return StringName()
	var player := _session.state.players[player_id] as Dictionary
	var held := player[&"held_objects"] as Array[Dictionary]
	if not held.is_empty():
		var last := held.back() as Dictionary
		return StringName(str(last.get("id", ""))) if str(last.get("kind", "")) == ITEM_REF_KIND else StringName()
	var bag_order := player[&"bag_order"] as Array[StringName]
	return bag_order.back() if not bag_order.is_empty() else StringName()


func peek_throw_ref(player_id: StringName) -> Dictionary:
	if not _session.state.players.has(player_id):
		return {}
	var player := _session.state.players[player_id] as Dictionary
	var held := player.held_objects as Array[Dictionary]
	if not held.is_empty():
		return held.back() as Dictionary
	var item_id := peek_throw_item(player_id)
	return {"kind": ITEM_REF_KIND, "id": item_id} if not item_id.is_empty() else {}


func try_release_all_items(player_id: StringName, world_transforms: Dictionary) -> ActionResult:
	if _session.is_publishing():
		return _session.defer_action(try_release_all_items.bind(player_id, world_transforms))
	var player_result: Variant = _player_or_error(player_id)
	if player_result is ActionResult:
		return player_result as ActionResult
	var player := player_result as Dictionary
	var item_ids: Array[StringName] = []
	var bag_ids: Array[StringName] = []
	for object_value in player[&"held_objects"]:
		var object_ref := object_value as Dictionary
		if str(object_ref.get("kind", "")) == ITEM_REF_KIND:
			item_ids.append(StringName(str(object_ref.get("id", ""))))
		elif str(object_ref.get("kind", "")) == "bag":
			bag_ids.append(StringName(str(object_ref.get("id", ""))))
	item_ids.append_array(player[&"bag_order"] as Array[StringName])
	for item_id in item_ids + bag_ids:
		if not world_transforms.has(item_id) or not (world_transforms[item_id] as Transform3D).is_finite():
			return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Missing safe release pose for %s" % item_id)
		if item_id in item_ids:
			var record_result: Variant = _record_or_error(item_id)
			if record_result is ActionResult:
				return record_result as ActionResult
		elif not _session.state.bag_records.has(item_id):
			return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing disposal bag %s" % item_id)
	player[&"held_objects"] = [] as Array[Dictionary]
	player[&"trash_bag"] = [] as Array[StringName]
	player[&"valuable_bag"] = [] as Array[StringName]
	player[&"bag_order"] = [] as Array[StringName]
	player[&"selected_held_index"] = -1
	for item_id in item_ids:
		var record := _session.state.items[item_id] as ItemRecord
		_commit_record_transfer(record, ItemRecord.Location.WORLD, &"")
		record.last_world_transform = world_transforms[item_id]
		record.linear_velocity = Vector3.ZERO
		record.angular_velocity = Vector3.ZERO
		record.sleeping = false
	for bag_id in bag_ids:
		var bag := _session.state.bag_records[bag_id] as Dictionary
		bag.location = "WORLD"
		bag.holder_id = &""
		bag.world_transform = ItemRecord._transform_to_array(world_transforms[bag_id] as Transform3D)
		bag.linear_velocity = ItemRecord._vector_to_array(Vector3.ZERO)
		bag.angular_velocity = ItemRecord._vector_to_array(Vector3.ZERO)
		bag.sleeping = false
	var changed := PackedStringArray()
	for item_id in item_ids:
		changed.append(str(item_id))
	if not changed.is_empty() or not bag_ids.is_empty():
		var changed_bags := PackedStringArray()
		for bag_id in bag_ids:
			changed_bags.append(str(bag_id))
		_session.finalize_action(changed, PackedStringArray([str(player_id)]), PackedStringArray(), changed_bags)
	return ActionResult.accepted(changed)


func _commit_record_transfer(record: ItemRecord, destination: ItemRecord.Location, owner_id: StringName) -> void:
	record.location = destination
	record.holder_id = owner_id
	record.container_id = &""
	record.slot_id = &""


func _current_hand_cost(player: Dictionary) -> int:
	var cost := 0
	for object_value in player.get("held_objects", []):
		var object_ref := object_value as Dictionary
		if str(object_ref.get("kind", "")) == "bag":
			cost += 1
			continue
		if str(object_ref.get("kind", "")) != ITEM_REF_KIND:
			continue
		var item_id := StringName(str(object_ref.get("id", "")))
		if not _session.state.items.has(item_id):
			continue
		var record := _session.state.items[item_id] as ItemRecord
		if _definitions.has(record.definition_id):
			cost += (_definitions[record.definition_id] as ItemDefinition).hand_cost
	return cost


func _active_tool(player: Dictionary) -> StringName:
	var equipped := player.get("equipped_handheld_ids", []) as Array[StringName]
	var active_slot := int(player.get("active_slot", 0))
	return equipped[active_slot] if active_slot >= 0 and active_slot < equipped.size() else StringName()


func _validate_target_context(item_id: StringName, context: Dictionary) -> ActionResult:
	if context.is_empty():
		return null
	if StringName(str(context.get("target_id", ""))) != item_id or not bool(context.get("visible", false)):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "%s is not the visible target" % item_id)
	if float(context.get("distance", INF)) > float(context.get("reach", 0.0)) + 0.01:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "%s is out of reach" % item_id)
	return null


func discover_definition(player: Dictionary, definition: ItemDefinition) -> void:
	var discoveries := player[&"discoveries"] as Array[StringName]
	var keys: Array[StringName] = [StringName("definition:%s" % definition.definition_id)]
	for tag in definition.material_tags:
		keys.append(StringName("material:%s" % tag))
	for key in keys:
		if key not in discoveries:
			discoveries.append(key)
		if key not in _session.state.discoveries:
			_session.state.discoveries.append(key)


func _player_or_error(player_id: StringName) -> Variant:
	if not _session.state.players.has(player_id):
		return ActionResult.rejected(ActionResult.Reason.INVALID_OWNER, "Missing player: %s" % player_id)
	return _session.state.players[player_id]


func _record_or_error(item_id: StringName) -> Variant:
	if not _session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing item: %s" % item_id)
	return _session.state.items[item_id]


func _definition_or_error(record: ItemRecord) -> Variant:
	if not _definitions.has(record.definition_id):
		return ActionResult.rejected(ActionResult.Reason.DEFINITION_MISSING, "Missing definition: %s" % record.definition_id)
	return _definitions[record.definition_id]
