class_name RunState
extends RefCounted

const LOCAL_PLAYER_ID: StringName = &"local"

var schema_version := 1
var game_version := "0.1.0"
var content_version := "1"
var generator_version := "1"
var run_id := ""
var seed_text := ""
var initial_manifest: Array[Dictionary] = []
var initial_manifest_hash := ""
var items: Dictionary = {}
var players: Dictionary = {}
var table_records: Dictionary = {}
var bin_records: Dictionary = {}
var bag_records: Dictionary = {}
var container_records: Dictionary = {}
var recovery_piles: Dictionary = {}
var next_recovery_serial := 1
var rescue_states: Dictionary = {}
var section_states: Dictionary = {}
var group_states: Dictionary = {}
var zone_states: Dictionary = {}
var discoveries: Array[StringName] = []
var guidance_seen: Array[StringName] = []
var optional_finds: Array[StringName] = []
var valuable_sales: Array[Dictionary] = []
var elapsed_active_seconds := 0.0
var completion_receipt: Dictionary = {}
var next_runtime_bag_serial := 1
var collection_receipts: Array[Dictionary] = []
var next_collection_serial := 1
var revision := 0
var required_total := 0


func add_player(player_id: StringName = LOCAL_PLAYER_ID) -> Dictionary:
	var trash_bag: Array[StringName] = []
	var valuable_bag: Array[StringName] = []
	var held_objects: Array[Dictionary] = []
	var equipped: Array[StringName] = [&"stick"]
	var owned_tools: Array[StringName] = [&"stick"]
	var owned_gear: Array[StringName] = []
	var player_discoveries: Array[StringName] = []
	var player := {
		"player_id": player_id,
		"trash_bag": trash_bag,
		"valuable_bag": valuable_bag,
		"held_objects": held_objects,
		"bag_capacity": 20,
		"hand_capacity": 2,
		"equipped_handheld_ids": equipped,
		"active_slot": 0,
		"selected_held_index": -1,
		"owned_tools": owned_tools,
		"owned_gear": owned_gear,
		"upgrade_levels": {},
		"money": 0,
		"discoveries": player_discoveries,
		"scanner_filter": StringName(),
		"transform": Transform3D.IDENTITY,
		"velocity": Vector3.ZERO,
		"air_remaining": 10.0,
		"immersed": false,
		"fainted": false,
	}
	players[player_id] = player
	return player


func add_item(record: ItemRecord) -> void:
	items[record.item_id] = record
	if record.required:
		required_total += 1


func to_snapshot() -> Dictionary:
	var item_ids: Array[String] = []
	for item_key in items:
		item_ids.append(str(item_key))
	item_ids.sort()
	var item_rows: Array[Dictionary] = []
	for item_id in item_ids:
		item_rows.append((items[StringName(item_id)] as ItemRecord).to_snapshot())

	var player_ids: Array[String] = []
	for player_key in players:
		player_ids.append(str(player_key))
	player_ids.sort()
	var player_rows: Array[Dictionary] = []
	for player_id in player_ids:
		player_rows.append(_player_to_snapshot(players[StringName(player_id)] as Dictionary))

	return {
		"schema_version": schema_version,
		"game_version": game_version,
		"content_version": content_version,
		"generator_version": generator_version,
		"run_id": run_id,
		"seed_text": seed_text,
		"initial_manifest": initial_manifest.duplicate(true),
		"initial_manifest_hash": initial_manifest_hash,
		"items": item_rows,
		"players": player_rows,
		"table_records": table_records.duplicate(true),
		"bin_records": bin_records.duplicate(true),
		"bag_records": bag_records.duplicate(true),
		"container_records": container_records.duplicate(true),
		"recovery_piles": recovery_piles.duplicate(true),
		"next_recovery_serial": next_recovery_serial,
		"rescue_states": rescue_states.duplicate(true),
		"section_states": section_states.duplicate(true),
		"group_states": group_states.duplicate(true),
		"zone_states": zone_states.duplicate(true),
		"discoveries": _string_names_to_array(discoveries),
		"guidance_seen": _string_names_to_array(guidance_seen),
		"optional_finds": _string_names_to_array(optional_finds),
		"valuable_sales": valuable_sales.duplicate(true),
		"elapsed_active_seconds": elapsed_active_seconds,
		"completion_receipt": completion_receipt.duplicate(true),
		"next_runtime_bag_serial": next_runtime_bag_serial,
		"collection_receipts": collection_receipts.duplicate(true),
		"next_collection_serial": next_collection_serial,
		"revision": revision,
		"required_total": required_total,
	}


static func from_snapshot(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.schema_version = int(data.get("schema_version", 1))
	state.game_version = str(data.get("game_version", ""))
	state.content_version = str(data.get("content_version", ""))
	state.generator_version = str(data.get("generator_version", ""))
	state.run_id = str(data.get("run_id", ""))
	state.seed_text = str(data.get("seed_text", ""))
	state.initial_manifest.assign(data.get("initial_manifest", []))
	state.initial_manifest_hash = str(data.get("initial_manifest_hash", ""))
	for item_value in data.get("items", []):
		var record := ItemRecord.from_snapshot(item_value as Dictionary)
		state.items[record.item_id] = record
	for player_value in data.get("players", []):
		var player := _player_from_snapshot(player_value as Dictionary)
		state.players[player["player_id"]] = player
	state.table_records = (data.get("table_records", {}) as Dictionary).duplicate(true)
	state.bin_records = (data.get("bin_records", {}) as Dictionary).duplicate(true)
	state.bag_records = (data.get("bag_records", {}) as Dictionary).duplicate(true)
	state.container_records = (data.get("container_records", {}) as Dictionary).duplicate(true)
	for container in state.container_records.values():
		if str((container as Dictionary).get("kind", "")) == "output_rack":
			var slots := (container as Dictionary).get("slots", {}) as Dictionary
			var integer_slots := {}
			for key in slots:
				integer_slots[int(key)] = StringName(str(slots[key]))
			(container as Dictionary)["slots"] = integer_slots
	state.recovery_piles = (data.get("recovery_piles", {}) as Dictionary).duplicate(true)
	state.next_recovery_serial = int(data.get("next_recovery_serial", 1))
	state.rescue_states = (data.get("rescue_states", {}) as Dictionary).duplicate(true)
	state.section_states = (data.get("section_states", {}) as Dictionary).duplicate(true)
	state.group_states = (data.get("group_states", {}) as Dictionary).duplicate(true)
	state.zone_states = (data.get("zone_states", {}) as Dictionary).duplicate(true)
	state.discoveries = _array_to_string_names(data.get("discoveries", []) as Array)
	state.guidance_seen = _array_to_string_names(data.get("guidance_seen", []) as Array)
	state.optional_finds = _array_to_string_names(data.get("optional_finds", []) as Array)
	state.valuable_sales.assign(data.get("valuable_sales", []))
	state.elapsed_active_seconds = float(data.get("elapsed_active_seconds", 0.0))
	state.completion_receipt = (data.get("completion_receipt", {}) as Dictionary).duplicate(true)
	state.next_runtime_bag_serial = int(data.get("next_runtime_bag_serial", 1))
	state.collection_receipts.assign(data.get("collection_receipts", []))
	state.next_collection_serial = int(data.get("next_collection_serial", 1))
	state.revision = int(data.get("revision", 0))
	state.required_total = int(data.get("required_total", 0))
	return state


func validate_invariants(definitions: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var ownership_counts: Dictionary = {}
	var bag_counts: Dictionary = {}
	for item_key in items:
		ownership_counts[item_key] = 0
	for bag_key in bag_records:
		bag_counts[bag_key] = 0

	for player_key in players:
		var player_id := StringName(player_key)
		var player := players[player_key] as Dictionary
		if int(player.get("money", 0)) < 0:
			errors.append("player %s has negative money" % player_id)
		var equipped := player.get("equipped_handheld_ids", []) as Array[StringName]
		var owned_tools := player.get("owned_tools", []) as Array[StringName]
		if equipped.is_empty() or equipped.size() > 2 or int(player.get("active_slot", 0)) < 0 or int(player.get("active_slot", 0)) >= equipped.size():
			errors.append("player %s has invalid handheld slots" % player_id)
		for tool_id in equipped:
			if tool_id not in owned_tools or equipped.count(tool_id) != 1:
				errors.append("player %s has unowned or duplicate equipped tool %s" % [player_id, tool_id])
		for purchase_id in (player.get("upgrade_levels", {}) as Dictionary):
			if int((player.upgrade_levels as Dictionary)[purchase_id]) < 0:
				errors.append("player %s has negative upgrade level %s" % [player_id, purchase_id])
		var selected_filter := StringName(str(player.get("scanner_filter", "")))
		if not selected_filter.is_empty() and (selected_filter not in (player.get("discoveries", []) as Array[StringName]) or int((player.upgrade_levels as Dictionary).get(&"scanner", 0)) < 1):
			errors.append("player %s has an unowned scanner filter" % player_id)
		var player_transform := player.get("transform", Transform3D.IDENTITY) as Transform3D
		var player_velocity := player.get("velocity", Vector3.ZERO) as Vector3
		var air_remaining := float(player.get("air_remaining", 10.0))
		if not player_transform.is_finite() or not player_velocity.is_finite() or not is_finite(air_remaining) or air_remaining < 0.0:
			errors.append("player %s contains invalid movement or air values" % player_id)
		for bag_key in [&"trash_bag", &"valuable_bag"]:
			for item_value in player.get(bag_key, []):
				_count_ownership(errors, ownership_counts, StringName(item_value), "%s:%s" % [player_id, bag_key])

		var hand_cost := 0
		var held_objects := player.get("held_objects", []) as Array
		var selected_held_index := int(player.get("selected_held_index", -1))
		if (held_objects.is_empty() and selected_held_index != -1) or (not held_objects.is_empty() and (selected_held_index < 0 or selected_held_index >= held_objects.size())):
			errors.append("player %s has an invalid held selection" % player_id)
		for object_value in held_objects:
			var object_ref := object_value as Dictionary
			if str(object_ref.get("kind", "")) == "bag":
				var bag_id := StringName(str(object_ref.get("id", "")))
				_count_ownership(errors, bag_counts, bag_id, "%s:held" % player_id)
				hand_cost += 1
				continue
			if str(object_ref.get("kind", "")) != "item":
				errors.append("player %s has invalid held object kind" % player_id)
				continue
			var item_id := StringName(str(object_ref.get("id", "")))
			_count_ownership(errors, ownership_counts, item_id, "%s:held" % player_id)
			if items.has(item_id):
				var record := items[item_id] as ItemRecord
				if definitions.has(record.definition_id):
					hand_cost += (definitions[record.definition_id] as ItemDefinition).hand_cost
		if hand_cost > int(player.get("hand_capacity", 2)):
			errors.append("player %s exceeds hand capacity" % player_id)

	for container_key in container_records:
		var container := container_records[container_key] as Dictionary
		if str(container.get("kind", "")) == "output_rack":
			var rack_slots := container.get("slots", {}) as Dictionary
			if rack_slots.size() > int(container.get("capacity", 8)):
				errors.append("output rack %s exceeds capacity" % container_key)
			for slot_key in rack_slots:
				_count_ownership(errors, bag_counts, StringName(str(rack_slots[slot_key])), "%s:%s" % [container_key, slot_key])
			continue
		if str(container.get("kind", "")) == "waste_container":
			for bag_value in container.get("bags", []):
				_count_ownership(errors, bag_counts, StringName(str(bag_value)), str(container_key))
			continue
		if str(container.get("kind", "")) != "placement_pool":
			continue
		var occupants := container.get("occupants", {}) as Dictionary
		var claim := StringName(str(container.get("claim", "")))
		if occupants.size() > int(container.get("capacity", 0)):
			errors.append("placement pool %s exceeds capacity" % container_key)
		if occupants.is_empty() and not claim.is_empty():
			errors.append("empty placement pool %s retained claim %s" % [container_key, claim])
		if not occupants.is_empty() and claim.is_empty():
			errors.append("occupied placement pool %s has no claim" % container_key)
		for slot_key in occupants:
			var item_id := StringName(str(occupants[slot_key]))
			_count_ownership(errors, ownership_counts, item_id, "%s:%s" % [container_key, slot_key])
			if not items.has(item_id):
				continue
			var slotted_record := items[item_id] as ItemRecord
			if slotted_record.location != ItemRecord.Location.SLOTTED or slotted_record.slot_id != StringName(str(slot_key)):
				errors.append("placement pool %s disagrees with item %s" % [container_key, item_id])
			elif definitions.has(slotted_record.definition_id) and (definitions[slotted_record.definition_id] as ItemDefinition).sorting_family != claim:
				errors.append("placement pool %s claim disagrees with item %s family" % [container_key, item_id])

	for station_key in table_records:
		var table := table_records[station_key] as Dictionary
		var cells := table.get("cells", {}) as Dictionary
		if cells.size() > 240:
			errors.append("sorting table %s exceeds 240 cells" % station_key)
		for cell_key in cells:
			var item_id := StringName(str(cells[cell_key]))
			_count_ownership(errors, ownership_counts, item_id, "%s:%s" % [station_key, cell_key])
			if items.has(item_id):
				var table_item := items[item_id] as ItemRecord
				if table_item.location != ItemRecord.Location.TABLE or table_item.container_id != StringName(str(station_key)) or table_item.slot_id != StringName(str(cell_key)):
					errors.append("sorting table %s disagrees with item %s" % [station_key, item_id])
		for item_value in table.get("tray", []):
			var item_id := StringName(str(item_value))
			_count_ownership(errors, ownership_counts, item_id, "%s:tray" % station_key)
			if items.has(item_id):
				var tray_item := items[item_id] as ItemRecord
				if tray_item.location != ItemRecord.Location.VALUABLE_TRAY or tray_item.container_id != StringName(str(station_key)):
					errors.append("valuable tray %s disagrees with item %s" % [station_key, item_id])
	for bin_key in bin_records:
		var bin := bin_records[bin_key] as Dictionary
		var contents := bin.get("items", []) as Array
		if contents.size() > int(bin.get("capacity", 50)):
			errors.append("sorting bin %s exceeds capacity" % bin_key)
		for item_value in contents:
			var item_id := StringName(str(item_value))
			_count_ownership(errors, ownership_counts, item_id, str(bin_key))
			if items.has(item_id):
				var bin_item := items[item_id] as ItemRecord
				if bin_item.location != ItemRecord.Location.BIN or bin_item.container_id != StringName(str(bin_key)):
					errors.append("sorting bin %s disagrees with item %s" % [bin_key, item_id])
	for bag_key in bag_records:
		var bag := bag_records[bag_key] as Dictionary
		var bag_id := StringName(str(bag_key))
		var contents := bag.get("item_ids", []) as Array
		if str(bag.get("bag_id", "")) != str(bag_id) or not bool(bag.get("sealed", false)) or contents.is_empty() or contents.size() > 50:
			errors.append("disposal bag %s has invalid identity or contents" % bag_id)
		if int(bag.get("correct_count", -1)) < 0 or int(bag.get("correct_count", -1)) > contents.size():
			errors.append("disposal bag %s has invalid correctness count" % bag_id)
		for item_value in contents:
			var item_id := StringName(str(item_value))
			if str(bag.get("location", "")) != "COLLECTED":
				_count_ownership(errors, ownership_counts, item_id, str(bag_id))
			if items.has(item_id):
				var sealed_item := items[item_id] as ItemRecord
				if str(bag.get("location", "")) == "COLLECTED":
					if sealed_item.location != ItemRecord.Location.COLLECTED or sealed_item.container_id != StringName(str(bag.get("collection_receipt_id", ""))):
						errors.append("collected bag %s disagrees with item %s" % [bag_id, item_id])
				elif sealed_item.location != ItemRecord.Location.SEALED or sealed_item.container_id != bag_id:
					errors.append("disposal bag %s disagrees with item %s" % [bag_id, item_id])
		var location := str(bag.get("location", ""))
		var count := int(bag_counts[bag_id])
		match location:
			"RACK":
				var station_id := StringName(str(bag.get("station_id", "")))
				var rack_id := StringName("%s:rack" % station_id)
				var slot := int(bag.get("rack_slot", -1))
				if count != 1 or not container_records.has(rack_id) or (container_records[rack_id] as Dictionary).get("slots", {}).get(slot) != bag_id:
					errors.append("disposal bag %s disagrees with rack slot" % bag_id)
			"HELD":
				if count != 1 or not _player_holds_bag(StringName(str(bag.get("holder_id", ""))), bag_id):
					errors.append("disposal bag %s disagrees with holder" % bag_id)
			"CONTAINER":
				if count != 1:
					errors.append("disposal bag %s disagrees with container" % bag_id)
			"WORLD", "COLLECTED":
				if count != 0:
					errors.append("disposal bag %s has extra owner" % bag_id)
				if location == "COLLECTED" and str(bag.get("collection_receipt_id", "")).is_empty():
					errors.append("collected bag %s has no receipt" % bag_id)
			_:
				errors.append("disposal bag %s has invalid location" % bag_id)

	var counted_required := 0
	for item_key in items:
		var record := items[item_key] as ItemRecord
		if record.required:
			counted_required += 1
		if record.item_id != item_key:
			errors.append("item dictionary key disagrees with record ID: %s" % item_key)
		if not definitions.has(record.definition_id):
			errors.append("item %s has missing definition %s" % [record.item_id, record.definition_id])
		if not record.finite_numbers():
			errors.append("item %s contains non-finite physics data" % record.item_id)
		if record.location == ItemRecord.Location.BURIED and (not record.buried or record.revealed or record.dig_surface_position == Vector3.ZERO):
			errors.append("buried item %s has invalid dig state" % record.item_id)
		if record.location == ItemRecord.Location.SOLD and record.required:
			errors.append("required item %s was sold" % record.item_id)

		var count := int(ownership_counts.get(record.item_id, 0))
		match record.location:
			ItemRecord.Location.BAG:
				if count != 1 or record.holder_id.is_empty():
					errors.append("bag item %s does not have exactly one holder" % record.item_id)
				elif not _player_bag_contains(record.holder_id, record.item_id):
					errors.append("bag item %s disagrees with holder %s" % [record.item_id, record.holder_id])
			ItemRecord.Location.HELD:
				if count != 1 or record.holder_id.is_empty():
					errors.append("held item %s does not have exactly one holder" % record.item_id)
				elif not _player_holds(record.holder_id, record.item_id):
					errors.append("held item %s disagrees with holder %s" % [record.item_id, record.holder_id])
			ItemRecord.Location.WORLD, ItemRecord.Location.BURIED, ItemRecord.Location.ATTACHED:
				if count != 0:
					errors.append("unowned item %s appears in an owner list" % record.item_id)
			ItemRecord.Location.TABLE, ItemRecord.Location.BIN, ItemRecord.Location.VALUABLE_TRAY:
				if record.container_id.is_empty() or count != 1:
					errors.append("contained item %s does not have exactly one station owner" % record.item_id)
			ItemRecord.Location.SEALED:
				if record.container_id.is_empty() or count != 1:
					errors.append("sealed item %s does not have exactly one bag" % record.item_id)
			ItemRecord.Location.SLOTTED:
				if record.slot_id.is_empty() or count != 1:
					errors.append("slotted item %s does not have exactly one slot" % record.item_id)
			ItemRecord.Location.COLLECTED, ItemRecord.Location.SOLD:
				if count != 0:
					errors.append("terminal item %s appears in an owner list" % record.item_id)

	if counted_required != required_total:
		errors.append("required denominator changed: expected %d, found %d" % [required_total, counted_required])
	var sold_ids := {}
	for sale in valuable_sales:
		var sold_id := StringName(str(sale.get("item_id", "")))
		if sold_ids.has(sold_id) or not items.has(sold_id) or (items[sold_id] as ItemRecord).location != ItemRecord.Location.SOLD or int(sale.get("amount", 0)) <= 0:
			errors.append("invalid or duplicate valuable sale %s" % sold_id)
		elif definitions.has((items[sold_id] as ItemRecord).definition_id):
			var sold_record := items[sold_id] as ItemRecord
			var sold_definition := definitions[sold_record.definition_id] as ItemDefinition
			if sold_definition.kind != ItemDefinition.Kind.VALUABLE or sold_record.required or str(sale.get("definition_id", "")) != str(sold_record.definition_id) or int(sale.get("amount", 0)) != sold_definition.base_sale_value or not players.has(StringName(str(sale.get("player_id", "")))):
				errors.append("valuable sale %s disagrees with authored item or player" % sold_id)
		sold_ids[sold_id] = true
	for item_value in items.values():
		var sold_record := item_value as ItemRecord
		if sold_record.location == ItemRecord.Location.SOLD and not sold_ids.has(sold_record.item_id):
			errors.append("sold item %s has no sale receipt" % sold_record.item_id)
	var piled_refs := {}
	if next_recovery_serial < 1:
		errors.append("invalid recovery pile serial")
	for pile_key in recovery_piles:
		var pile := recovery_piles[pile_key] as Dictionary
		if (pile.get("origin", []) as Array).size() != 3 or not ItemRecord._array_to_vector(pile.get("origin", []) as Array).is_finite():
			errors.append("recovery pile %s has invalid origin" % pile_key)
		for item_text in pile.get("item_ids", []):
			var piled_id := StringName(str(item_text))
			if piled_refs.has(piled_id) or not items.has(piled_id) or (items[piled_id] as ItemRecord).location != ItemRecord.Location.WORLD:
				errors.append("recovery pile %s has invalid item %s" % [pile_key, piled_id])
			piled_refs[piled_id] = true
		for bag_text in pile.get("bag_ids", []):
			var piled_bag := StringName(str(bag_text))
			if piled_refs.has(piled_bag) or not bag_records.has(piled_bag) or str((bag_records[piled_bag] as Dictionary).get("location", "")) != "WORLD":
				errors.append("recovery pile %s has invalid bag %s" % [pile_key, piled_bag])
			piled_refs[piled_bag] = true
	for site_key in rescue_states:
		var rescue := rescue_states[site_key] as Dictionary
		var attachments := rescue.get("attachment_ids", []) as Array
		if attachments.size() != 2 or str(rescue.get("home_section_id", "")).is_empty():
			errors.append("rescue site %s has invalid attachment roster" % site_key)
		var still_attached := 0
		for item_text in attachments:
			var item_id := StringName(str(item_text))
			if not items.has(item_id):
				errors.append("rescue site %s references missing item %s" % [site_key, item_id])
				continue
			var attachment := items[item_id] as ItemRecord
			if not attachment.required or not str(attachment.attachment_id).begins_with("%s/" % site_key) or str(attachment.home_section_id) != str(rescue.home_section_id):
				errors.append("rescue site %s disagrees with attachment %s" % [site_key, item_id])
			if attachment.location == ItemRecord.Location.ATTACHED:
				still_attached += 1
		if bool(rescue.get("released", false)) != (still_attached == 0):
			errors.append("rescue site %s release latch disagrees with attachments" % site_key)
	if not is_finite(elapsed_active_seconds) or elapsed_active_seconds < 0.0:
		errors.append("elapsed active time is invalid")
	errors.append_array(_progress_errors(definitions))
	return errors


func _progress_errors(definitions: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if section_states.is_empty() and group_states.is_empty() and zone_states.is_empty() and completion_receipt.is_empty():
		return errors
	var actual_sections: Dictionary = {}
	var actual_groups: Dictionary = {}
	var actual_zones: Dictionary = {}
	var total_waste := 0
	var total_props := 0
	for item_value in items.values():
		var record := item_value as ItemRecord
		if not record.required or not definitions.has(record.definition_id):
			continue
		var definition := definitions[record.definition_id] as ItemDefinition
		if not actual_sections.has(record.home_section_id):
			actual_sections[record.home_section_id] = {"waste": 0, "collected": 0, "props": 0, "slotted": 0, "zone": record.home_zone_id}
		var section := actual_sections[record.home_section_id] as Dictionary
		actual_zones[record.home_zone_id] = true
		if definition.kind == ItemDefinition.Kind.WASTE:
			section.waste = int(section.waste) + 1
			total_waste += 1
			if record.location == ItemRecord.Location.COLLECTED:
				section.collected = int(section.collected) + 1
		elif definition.kind == ItemDefinition.Kind.PROP:
			section.props = int(section.props) + 1
			total_props += 1
			var group_id := StringName("%s/%s" % [record.home_section_id, definition.sorting_family])
			if not actual_groups.has(group_id):
				actual_groups[group_id] = {"required": 0, "current": 0}
			var group := actual_groups[group_id] as Dictionary
			group.required = int(group.required) + 1
			if record.location == ItemRecord.Location.SLOTTED and record.dirty_patches_remaining.is_empty():
				section.slotted = int(section.slotted) + 1
				group.current = int(group.current) + 1
	if section_states.size() != actual_sections.size() or group_states.size() != actual_groups.size() or zone_states.size() != actual_zones.size():
		errors.append("progress lookup size disagrees with required objectives")
	for section_id in actual_sections:
		if not section_states.has(section_id):
			errors.append("missing progress section %s" % section_id)
			continue
		var expected := actual_sections[section_id] as Dictionary
		var section := section_states[section_id] as Dictionary
		var rescues_released := true
		for rescue_value in rescue_states.values():
			var rescue := rescue_value as Dictionary
			if StringName(str(rescue.home_section_id)) == section_id and not bool(rescue.released):
				rescues_released = false
		var complete := int(expected.collected) == int(expected.waste) and int(expected.slotted) == int(expected.props) and rescues_released
		if int(section.get("required_waste", -1)) != int(expected.waste) or int(section.get("collected_waste", -1)) != int(expected.collected) or int(section.get("required_props", -1)) != int(expected.props) or int(section.get("slotted_props", -1)) != int(expected.slotted) or bool(section.get("complete", false)) != complete or bool(section.get("rescues_released", false)) != rescues_released or StringName(str(section.get("home_zone_id", ""))) != expected.zone:
			errors.append("progress section %s disagrees with item state" % section_id)
	for group_id in actual_groups:
		if not group_states.has(group_id):
			errors.append("missing progress group %s" % group_id)
			continue
		var expected := actual_groups[group_id] as Dictionary
		var group := group_states[group_id] as Dictionary
		if int(group.get("required_count", -1)) != int(expected.required) or int(group.get("current_count", -1)) != int(expected.current) or bool(group.get("complete", false)) != (int(expected.current) == int(expected.required)):
			errors.append("progress group %s disagrees with item state" % group_id)
		if bool(group.get("reward_claimed", false)) != (int(group.get("reward_amount", 0)) == 15) or (bool(group.get("reward_claimed", false)) and (int(group.get("completion_transitions", 0)) < 1 or not players.has(StringName(str(group.get("reward_player_id", "")))))):
			errors.append("progress group %s has invalid reward latch" % group_id)
	for zone_id in actual_zones:
		if not zone_states.has(zone_id):
			errors.append("missing progress zone %s" % zone_id)
			continue
		var complete := true
		for section_id in actual_sections:
			if (actual_sections[section_id] as Dictionary).zone == zone_id and not bool((section_states.get(section_id, {}) as Dictionary).get("complete", false)):
				complete = false
		if bool((zone_states[zone_id] as Dictionary).get("complete", false)) != complete:
			errors.append("progress zone %s disagrees with sections" % zone_id)
	if not completion_receipt.is_empty():
		if int(completion_receipt.get("required_total", -1)) != required_total or int(completion_receipt.get("collected_waste", -1)) != total_waste or int(completion_receipt.get("slotted_props", -1)) != total_props or str(completion_receipt.get("manifest_hash", "")) != initial_manifest_hash or int(completion_receipt.get("revision", -1)) > revision:
			errors.append("completion receipt disagrees with immutable run identity or totals")
	return errors


func prune_recovery_piles() -> void:
	for pile_key in recovery_piles.keys():
		var pile := recovery_piles[pile_key] as Dictionary
		var live_items: Array[String] = []
		var live_bags: Array[String] = []
		for item_text in pile.get("item_ids", []):
			var item_id := StringName(str(item_text))
			if items.has(item_id) and (items[item_id] as ItemRecord).location == ItemRecord.Location.WORLD:
				live_items.append(str(item_id))
		for bag_text in pile.get("bag_ids", []):
			var bag_id := StringName(str(bag_text))
			if bag_records.has(bag_id) and str((bag_records[bag_id] as Dictionary).get("location", "")) == "WORLD":
				live_bags.append(str(bag_id))
		if live_items.is_empty() and live_bags.is_empty():
			recovery_piles.erase(pile_key)
		else:
			pile.item_ids = live_items
			pile.bag_ids = live_bags


func _player_bag_contains(player_id: StringName, item_id: StringName) -> bool:
	if not players.has(player_id):
		return false
	var player := players[player_id] as Dictionary
	return item_id in player.get("trash_bag", []) or item_id in player.get("valuable_bag", [])


func _player_holds(player_id: StringName, item_id: StringName) -> bool:
	if not players.has(player_id):
		return false
	for object_value in (players[player_id] as Dictionary).get("held_objects", []):
		var object_ref := object_value as Dictionary
		if str(object_ref.get("kind", "")) == "item" and StringName(str(object_ref.get("id", ""))) == item_id:
			return true
	return false


func _player_holds_bag(player_id: StringName, bag_id: StringName) -> bool:
	if not players.has(player_id):
		return false
	for object_value in (players[player_id] as Dictionary).get("held_objects", []):
		var object_ref := object_value as Dictionary
		if str(object_ref.get("kind", "")) == "bag" and StringName(str(object_ref.get("id", ""))) == bag_id:
			return true
	return false


static func _count_ownership(errors: PackedStringArray, counts: Dictionary, item_id: StringName, owner: String) -> void:
	if not counts.has(item_id):
		errors.append("owner %s references missing item %s" % [owner, item_id])
		return
	counts[item_id] = int(counts[item_id]) + 1
	if int(counts[item_id]) > 1:
		errors.append("item %s appears in multiple owner lists" % item_id)


static func _player_to_snapshot(player: Dictionary) -> Dictionary:
	return {
		"player_id": str(player.get("player_id", "")),
		"trash_bag": _string_names_to_array(player.get("trash_bag", []) as Array[StringName]),
		"valuable_bag": _string_names_to_array(player.get("valuable_bag", []) as Array[StringName]),
		"held_objects": (player.get("held_objects", []) as Array).duplicate(true),
		"bag_capacity": int(player.get("bag_capacity", 20)),
		"hand_capacity": int(player.get("hand_capacity", 2)),
		"equipped_handheld_ids": _string_names_to_array(player.get("equipped_handheld_ids", []) as Array[StringName]),
		"active_slot": int(player.get("active_slot", 0)),
		"selected_held_index": int(player.get("selected_held_index", -1)),
		"owned_tools": _string_names_to_array(player.get("owned_tools", []) as Array[StringName]),
		"owned_gear": _string_names_to_array(player.get("owned_gear", []) as Array[StringName]),
		"upgrade_levels": (player.get("upgrade_levels", {}) as Dictionary).duplicate(true),
		"money": int(player.get("money", 0)),
		"discoveries": _string_names_to_array(player.get("discoveries", []) as Array[StringName]),
		"scanner_filter": str(player.get("scanner_filter", &"")),
		"transform": ItemRecord._transform_to_array(player.get("transform", Transform3D.IDENTITY) as Transform3D),
		"velocity": ItemRecord._vector_to_array(player.get("velocity", Vector3.ZERO) as Vector3),
		"air_remaining": float(player.get("air_remaining", 10.0)),
		"immersed": bool(player.get("immersed", false)),
		"fainted": bool(player.get("fainted", false)),
	}


static func _player_from_snapshot(data: Dictionary) -> Dictionary:
	var held_objects: Array[Dictionary] = []
	for value in data.get("held_objects", []):
		held_objects.append(value as Dictionary)
	return {
		"player_id": StringName(str(data.get("player_id", ""))),
		"trash_bag": _array_to_string_names(data.get("trash_bag", []) as Array),
		"valuable_bag": _array_to_string_names(data.get("valuable_bag", []) as Array),
		"held_objects": held_objects,
		"bag_capacity": int(data.get("bag_capacity", 20)),
		"hand_capacity": int(data.get("hand_capacity", 2)),
		"equipped_handheld_ids": _array_to_string_names(data.get("equipped_handheld_ids", []) as Array),
		"active_slot": int(data.get("active_slot", 0)),
		"selected_held_index": int(data.get("selected_held_index", -1)),
		"owned_tools": _array_to_string_names(data.get("owned_tools", []) as Array),
		"owned_gear": _array_to_string_names(data.get("owned_gear", []) as Array),
		"upgrade_levels": (data.get("upgrade_levels", {}) as Dictionary).duplicate(true),
		"money": int(data.get("money", 0)),
		"discoveries": _array_to_string_names(data.get("discoveries", []) as Array),
		"scanner_filter": StringName(str(data.get("scanner_filter", ""))),
		"transform": ItemRecord._array_to_transform(data.get("transform", []) as Array),
		"velocity": ItemRecord._array_to_vector(data.get("velocity", []) as Array),
		"air_remaining": float(data.get("air_remaining", 10.0)),
		"immersed": bool(data.get("immersed", false)),
		"fainted": bool(data.get("fainted", false)),
	}


static func _string_names_to_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func _array_to_string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(str(value)))
	return result
