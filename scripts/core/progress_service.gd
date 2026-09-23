class_name ProgressService
extends RefCounted

const GROUP_REWARD := 15

var session: RunSession
var section_items: Dictionary = {}
var group_items: Dictionary = {}
var zone_sections: Dictionary = {}
var completed_waste := 0
var completed_props := 0


func configure(run_session: RunSession) -> void:
	session = run_session
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if not record.required:
			continue
		var definition := session.definitions.get(record.definition_id) as ItemDefinition
		if definition == null:
			continue
		if not section_items.has(record.home_section_id):
			section_items[record.home_section_id] = []
			if not zone_sections.has(record.home_zone_id):
				zone_sections[record.home_zone_id] = []
			(zone_sections[record.home_zone_id] as Array).append(record.home_section_id)
		(section_items[record.home_section_id] as Array).append(record.item_id)
		if definition.kind == ItemDefinition.Kind.PROP:
			var group_id := _group_id(record, definition)
			if not group_items.has(group_id):
				group_items[group_id] = []
			(group_items[group_id] as Array).append(record.item_id)
	for group_id in group_items:
		var first := session.state.items[(group_items[group_id] as Array)[0]] as ItemRecord
		var definition := session.definitions[first.definition_id] as ItemDefinition
		var group := session.state.group_states.get(group_id, {}) as Dictionary
		group["group_id"] = group_id
		group["home_section_id"] = first.home_section_id
		group["family_id"] = definition.sorting_family
		group["required_count"] = (group_items[group_id] as Array).size()
		group["current_count"] = _group_count(group_id)
		group["complete"] = int(group.current_count) == int(group.required_count)
		group["reward_claimed"] = bool(group.get("reward_claimed", false))
		group["reward_amount"] = int(group.get("reward_amount", GROUP_REWARD if bool(group.reward_claimed) else 0))
		group["reward_player_id"] = StringName(str(group.get("reward_player_id", "local" if bool(group.reward_claimed) else "")))
		group["completion_transitions"] = int(group.get("completion_transitions", 0))
		session.state.group_states[group_id] = group
	for section_id in section_items:
		var first := session.state.items[(section_items[section_id] as Array)[0]] as ItemRecord
		var section := session.state.section_states.get(section_id, {}) as Dictionary
		section["home_zone_id"] = first.home_zone_id
		section["restored_once"] = bool(section.get("restored_once", false))
		_update_section_counts(section_id, section)
		session.state.section_states[section_id] = section
		completed_waste += int(section.collected_waste)
		completed_props += int(section.slotted_props)
	for zone_id in zone_sections:
		var zone := session.state.zone_states.get(zone_id, {}) as Dictionary
		zone["restored_once"] = bool(zone.get("restored_once", false))
		zone["complete"] = _zone_complete(zone_id)
		session.state.zone_states[zone_id] = zone


func finalize(changed_ids: PackedStringArray) -> Dictionary:
	var affected_sections: Dictionary = {}
	var affected_groups: Dictionary = {}
	for item_text in changed_ids:
		var item_id := StringName(item_text)
		if not session.state.items.has(item_id):
			continue
		var record := session.state.items[item_id] as ItemRecord
		if not record.required:
			continue
		affected_sections[record.home_section_id] = true
		var definition := session.definitions.get(record.definition_id) as ItemDefinition
		if definition != null and definition.kind == ItemDefinition.Kind.PROP:
			affected_groups[_group_id(record, definition)] = true
	var notices := {"groups": [], "sections": [], "zones": [], "wallet_players": [], "completed": {}}
	for group_id in affected_groups:
		var group := session.state.group_states[group_id] as Dictionary
		var was_complete := bool(group.complete)
		group.current_count = _group_count(group_id)
		group.complete = int(group.current_count) == int(group.required_count)
		if not was_complete and bool(group.complete):
			group.completion_transitions = int(group.completion_transitions) + 1
			var first_time := not bool(group.reward_claimed)
			if first_time:
				group.reward_claimed = true
				group.reward_amount = GROUP_REWARD
				group.reward_player_id = &"local"
				var player := session.state.players[&"local"] as Dictionary
				player.money = int(player.money) + GROUP_REWARD
				(notices.wallet_players as Array).append(&"local")
			(notices.groups as Array).append({"group_id": str(group_id), "home_section_id": str(group.home_section_id), "family_id": str(group.family_id), "current_count": int(group.current_count), "required_count": int(group.required_count), "transition_count": int(group.completion_transitions), "first_time": first_time, "reward": GROUP_REWARD if first_time else 0})
	var affected_zones: Dictionary = {}
	for section_id in affected_sections:
		var section := session.state.section_states[section_id] as Dictionary
		completed_waste -= int(section.collected_waste)
		completed_props -= int(section.slotted_props)
		_update_section_counts(section_id, section)
		completed_waste += int(section.collected_waste)
		completed_props += int(section.slotted_props)
		if bool(section.complete) and not bool(section.restored_once):
			section.restored_once = true
			(notices.sections as Array).append(str(section_id))
		affected_zones[StringName(str(section.home_zone_id))] = true
	for zone_id in affected_zones:
		var zone := session.state.zone_states[zone_id] as Dictionary
		zone.complete = _zone_complete(zone_id)
		if bool(zone.complete) and not bool(zone.restored_once):
			zone.restored_once = true
			(notices.zones as Array).append(str(zone_id))
	if completed_waste + completed_props == session.state.required_total and session.state.completion_receipt.is_empty():
		var correct := 0
		for receipt in session.state.collection_receipts:
			correct += int(receipt.get("correct_count", 0))
		var player := session.state.players[&"local"] as Dictionary
		session.state.completion_receipt = {
			"run_id": session.state.run_id,
			"seed": session.state.seed_text,
			"game_version": session.state.game_version,
			"content_version": session.state.content_version,
			"generator_version": session.state.generator_version,
			"manifest_hash": session.state.initial_manifest_hash,
			"revision": session.state.revision + 1,
			"active_seconds": session.state.elapsed_active_seconds,
			"required_total": session.state.required_total,
			"collected_waste": completed_waste,
			"slotted_props": completed_props,
			"correctly_sorted": correct,
			"collection_count": session.state.collection_receipts.size(),
			"money": int(player.money),
			"owned_tools": Array(player.owned_tools).duplicate(),
			"owned_gear": Array(player.owned_gear).duplicate(),
			"upgrade_levels": (player.upgrade_levels as Dictionary).duplicate(true),
			"optional_finds": session.state.optional_finds.size(),
			"valuable_sales": session.state.valuable_sales.size(),
		}
		notices.completed = session.state.completion_receipt.duplicate(true)
	return notices


func _update_section_counts(section_id: StringName, section: Dictionary) -> void:
	var required_waste := 0
	var collected_waste := 0
	var required_props := 0
	var slotted_props := 0
	var rescues_released := true
	for item_id in section_items[section_id]:
		var record := session.state.items[item_id] as ItemRecord
		var definition := session.definitions[record.definition_id] as ItemDefinition
		if definition.kind == ItemDefinition.Kind.WASTE:
			required_waste += 1
			if record.location == ItemRecord.Location.COLLECTED:
				collected_waste += 1
		elif definition.kind == ItemDefinition.Kind.PROP:
			required_props += 1
			if record.location == ItemRecord.Location.SLOTTED and record.dirty_patches_remaining.is_empty():
				slotted_props += 1
	for rescue_value in session.state.rescue_states.values():
		var rescue := rescue_value as Dictionary
		if StringName(str(rescue.home_section_id)) == section_id and not bool(rescue.released):
			rescues_released = false
	section.required_waste = required_waste
	section.collected_waste = collected_waste
	section.required_props = required_props
	section.slotted_props = slotted_props
	section.rescues_released = rescues_released
	section.complete = collected_waste == required_waste and slotted_props == required_props and rescues_released


func _group_count(group_id: StringName) -> int:
	var count := 0
	for item_id in group_items[group_id]:
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.SLOTTED and record.dirty_patches_remaining.is_empty():
			count += 1
	return count


func _group_id(record: ItemRecord, definition: ItemDefinition) -> StringName:
	return StringName("%s/%s" % [record.home_section_id, definition.sorting_family])


func _zone_complete(zone_id: StringName) -> bool:
	for section_id in zone_sections[zone_id]:
		if not bool((session.state.section_states[section_id] as Dictionary).complete):
			return false
	return true
