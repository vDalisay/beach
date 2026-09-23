class_name CollectionService
extends Node

signal receipt_created(receipt: Dictionary)

var session: RunSession


func configure(run_session: RunSession) -> void:
	session = run_session


func try_collect_containers(player_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_collect_containers.bind(player_id))
	if not session.state.players.has(player_id):
		return ActionResult.rejected(ActionResult.Reason.INVALID_OWNER, "Missing player")

	var container_ids: Array[String] = []
	for key in session.state.container_records:
		if str((session.state.container_records[key] as Dictionary).get("kind", "")) == "waste_container":
			container_ids.append(str(key))
	container_ids.sort()
	var bag_ids: Array[StringName] = []
	var item_ids: Array[StringName] = []
	var seen_bags: Dictionary = {}
	var seen_items: Dictionary = {}
	var correct_count := 0
	var home_sections: Dictionary = {}
	for container_id in container_ids:
		var container := session.state.container_records[StringName(container_id)] as Dictionary
		var category := StringName(str(container.get("category", "")))
		if not SortingStation.CATEGORIES.has(category):
			return _corrupt("container %s has invalid category" % container_id)
		for bag_value in container.get("bags", []):
			var bag_id := StringName(str(bag_value))
			if seen_bags.has(bag_id) or not session.state.bag_records.has(bag_id):
				return _corrupt("container %s has duplicate or missing bag %s" % [container_id, bag_id])
			seen_bags[bag_id] = true
			var bag := session.state.bag_records[bag_id] as Dictionary
			if not bool(bag.get("sealed", false)) or str(bag.get("location", "")) != "CONTAINER" or StringName(str(bag.get("container_id", ""))) != StringName(container_id) or StringName(str(bag.get("category", ""))) != category:
				return _corrupt("bag %s disagrees with container %s" % [bag_id, container_id])
			var contents := bag.get("item_ids", []) as Array
			if contents.is_empty() or contents.size() > SortingStation.BIN_CAPACITY:
				return _corrupt("bag %s has invalid contents" % bag_id)
			var bag_correct := 0
			for item_value in contents:
				var item_id := StringName(str(item_value))
				if seen_items.has(item_id) or not session.state.items.has(item_id):
					return _corrupt("bag %s has duplicate or missing item %s" % [bag_id, item_id])
				seen_items[item_id] = true
				var record := session.state.items[item_id] as ItemRecord
				var definition := session.definitions.get(record.definition_id) as ItemDefinition
				if definition == null or definition.kind != ItemDefinition.Kind.WASTE or record.location != ItemRecord.Location.SEALED or record.container_id != bag_id:
					return _corrupt("bag %s disagrees with sealed waste %s" % [bag_id, item_id])
				if definition.waste_category == SortingStation.CATEGORIES.find(category):
					bag_correct += 1
				var section := str(record.home_section_id)
				home_sections[section] = int(home_sections.get(section, 0)) + 1
				item_ids.append(item_id)
			if bag_correct != int(bag.get("correct_count", -1)):
				return _corrupt("bag %s correctness disagrees with definitions" % bag_id)
			correct_count += bag_correct
			bag_ids.append(bag_id)
	if bag_ids.is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Nothing to collect")
	var ownership_errors := session.state.validate_invariants(session.definitions)
	if not ownership_errors.is_empty():
		return _corrupt("run ownership invalid before collection: %s" % ownership_errors[0])

	var receipt_id := StringName("collection:%06d" % session.state.next_collection_serial)
	var changed_ids := PackedStringArray()
	var changed_bags := PackedStringArray()
	for item_id in item_ids:
		var record := session.state.items[item_id] as ItemRecord
		record.location = ItemRecord.Location.COLLECTED
		record.container_id = receipt_id
		record.holder_id = &""
		record.slot_id = &""
		changed_ids.append(str(item_id))
	for bag_id in bag_ids:
		var bag := session.state.bag_records[bag_id] as Dictionary
		var container := session.state.container_records[StringName(str(bag.container_id))] as Dictionary
		(container.bags as Array).erase(bag_id)
		bag.location = "COLLECTED"
		bag.container_id = &""
		bag.collection_receipt_id = receipt_id
		changed_bags.append(str(bag_id))
	var player := session.state.players[player_id] as Dictionary
	var base_pay := item_ids.size()
	var total_pay := base_pay + correct_count
	player.money = int(player.money) + total_pay
	var receipt := {
		"receipt_id": str(receipt_id),
		"player_id": str(player_id),
		"bag_ids": _names_to_strings(bag_ids),
		"item_ids": _names_to_strings(item_ids),
		"item_count": item_ids.size(),
		"correct_count": correct_count,
		"base_pay": base_pay,
		"bonus_pay": correct_count,
		"total_pay": total_pay,
		"home_sections": home_sections,
		"revision": session.state.revision + 1,
	}
	session.state.collection_receipts.append(receipt)
	session.state.next_collection_serial += 1
	session.finalize_action(changed_ids, PackedStringArray(), PackedStringArray([str(player_id)]), changed_bags)
	receipt_created.emit(receipt.duplicate(true))
	return ActionResult.accepted(changed_ids, receipt.duplicate(true))


func _corrupt(message: String) -> ActionResult:
	push_error("Collection refused: " + message)
	return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Collection unavailable; see developer log")


func _names_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
