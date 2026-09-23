class_name ManifestValidator
extends RefCounted


static func validate_content(beach: BeachDefinition, quotas: Resource, anchors: Resource, definitions: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if beach == null or quotas == null or anchors == null:
		errors.append("Beach, quota, or anchor content is missing.")
		return errors
	for error in beach.validation_errors():
		errors.append(error)
	var section_quotas := quotas.get_meta(&"sections", {}) as Dictionary
	var family_matrix := quotas.get_meta(&"prop_families_by_zone", {}) as Dictionary
	var totals := quotas.get_meta(&"global_totals", {}) as Dictionary
	var packs := anchors.get_meta(&"packs", {}) as Dictionary
	var category_totals := {&"pmd": 0, &"organic": 0, &"general": 0, &"glass": 0, &"props": 0}
	var seen_sections := {}
	for section_id in beach.ordered_sections:
		seen_sections[section_id] = true
		if not section_quotas.has(section_id):
			errors.append("Missing quota for section %s." % section_id)
			continue
		if not packs.has(section_id):
			errors.append("Missing anchor pack for section %s." % section_id)
			continue
		var quota := section_quotas[section_id] as Dictionary
		var waste := 0
		for category in [&"pmd", &"organic", &"general", &"glass"]:
			waste += int(quota.get(category, -1))
			category_totals[category] = int(category_totals[category]) + int(quota.get(category, 0))
		category_totals[&"props"] = int(category_totals[&"props"]) + int(quota.get(&"props", 0))
		var budget := beach.section_budgets[section_id] as Dictionary
		if waste != int(budget.waste) or int(quota.get(&"props", -1)) != int(budget.props):
			errors.append("Quota does not match section budget for %s." % section_id)
		if waste > 640 or int(quota.get(&"props", 0)) > 100:
			errors.append("Anchor capacity is too small for section %s." % section_id)
	for section_id in section_quotas:
		if not seen_sections.has(section_id):
			errors.append("Quota references unknown section %s." % section_id)
	for category in category_totals:
		if int(category_totals[category]) != int(totals.get(category, -1)):
			errors.append("Global %s quota is %d, expected %d." % [category, category_totals[category], totals.get(category, -1)])

	var family_totals := {}
	for zone_id in beach.ordered_zones:
		var zone_sum := 0
		var zone_families := family_matrix.get(zone_id, {}) as Dictionary
		for family_id in zone_families:
			var count := int(zone_families[family_id])
			zone_sum += count
			family_totals[family_id] = int(family_totals.get(family_id, 0)) + count
		if zone_sum != int((beach.zone_budgets[zone_id] as Dictionary).props):
			errors.append("Prop family matrix does not match zone %s." % zone_id)
	_validate_destinations(errors, beach, family_totals)

	if definitions.is_empty():
		errors.append("Item catalog is empty.")
	var known_families := {}
	for definition_id in definitions:
		var definition := definitions[definition_id] as ItemDefinition
		for error in definition.validation_errors():
			errors.append(error)
		if definition.kind == ItemDefinition.Kind.PROP:
			if definition.sorting_family.is_empty():
				errors.append("Prop %s has no sorting family." % definition_id)
			elif known_families.has(definition.sorting_family):
				errors.append("Multiple definitions claim prop family %s." % definition.sorting_family)
			else:
				known_families[definition.sorting_family] = true
		if definition.visual_scene_path.is_empty() or not ResourceLoader.exists(definition.visual_scene_path, "PackedScene"):
			errors.append("Definition %s has no loadable visual." % definition_id)
	for family_id in family_totals:
		if not known_families.has(family_id):
			errors.append("No definition exists for prop family %s." % family_id)
	for required_id in [&"waste_buried_metal", &"waste_buried_scrap", &"waste_rescue_ring", &"waste_rescue_net", &"waste_residue", &"valuable_keys"]:
		if not definitions.has(required_id):
			errors.append("Required catalog definition is missing: %s." % required_id)
	if int(anchors.get_meta(&"grid_columns", 0)) * int(anchors.get_meta(&"grid_rows", 0)) < 768:
		errors.append("Anchor grid must provide at least 768 authored cells per section.")
	if int(anchors.get_meta(&"grid_spacing_mm", 0)) < 700:
		errors.append("Anchor grid spacing is below the 700 mm clearance requirement.")
	return errors


static func validate_manifest(
	generation: Dictionary,
	beach: BeachDefinition,
	quotas: Resource,
	anchors: Resource,
	definitions: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	var rows := generation.get("rows", []) as Array
	var expected := quotas.get_meta(&"global_totals") as Dictionary
	if rows.size() != int(expected.required) + int(expected.valuables):
		errors.append("Manifest has %d rows, expected %d." % [rows.size(), int(expected.required) + int(expected.valuables)])
	var ids := {}
	var poses := {}
	var counts := {"pmd": 0, "organic": 0, "general": 0, "glass": 0, "props": 0, "required": 0, "valuables": 0, "buried_waste": 0, "attachments": 0, "residue": 0, "dirty_props": 0}
	var section_counts := {}
	var family_zone_counts := {}
	var packs := anchors.get_meta(&"packs") as Dictionary
	var last_id := ""
	var starter_locked := 0
	var exposed_dry := 0
	var rescue_pairs := {}
	var walk_route := beach.starting_state.get("walk_route", []) as Array
	for row_value in rows:
		var row := row_value as Dictionary
		var item_id := str(row.get("id", ""))
		if item_id.is_empty() or ids.has(item_id):
			errors.append("Manifest item IDs must be nonempty and unique: %s." % item_id)
		ids[item_id] = true
		if not last_id.is_empty() and item_id < last_id:
			errors.append("Manifest rows are not sorted by item ID.")
		last_id = item_id
		var definition_id := StringName(str(row.get("definition_id", "")))
		if not definitions.has(definition_id):
			errors.append("Manifest item %s uses missing definition %s." % [item_id, definition_id])
			continue
		var definition := definitions[definition_id] as ItemDefinition
		var section_id := StringName(str(row.get("section_id", "")))
		if not packs.has(section_id):
			errors.append("Manifest item %s uses missing section anchor %s." % [item_id, section_id])
			continue
		var pack := packs[section_id] as Dictionary
		if str(row.get("anchor_id", "")) != str(pack.anchor_id):
			errors.append("Manifest item %s has the wrong anchor pack." % item_id)
		var position := row.get("position_mm", []) as Array
		if position.size() != 3 or int(row.get("orientation_index", -1)) not in range(16):
			errors.append("Manifest item %s has an invalid integer pose." % item_id)
		else:
			var pose_key := "%d/%d/%d" % [position[0], position[1], position[2]]
			if poses.has(pose_key):
				errors.append("Manifest items %s and %s share an unsupported pose." % [poses[pose_key], item_id])
			poses[pose_key] = item_id
			if str(row.location) == "WORLD" and definition.collision_profile == ItemDefinition.CollisionProfile.LARGE and absf(float(position[1])) <= 1800.0 and _walk_route_distance_mm(Vector2(float(position[0]), float(position[2])), walk_route) < 1800.0:
				errors.append("Large item %s blocks the authored walking route." % item_id)
		if bool(row.get("required", false)):
			counts.required += 1
			if definition.kind == ItemDefinition.Kind.PROP:
				counts.props += 1
			else:
				counts[str(row.category)] = int(counts.get(str(row.category), 0)) + 1
		else:
			counts.valuables += 1
		if str(row.location) == "BURIED" and bool(row.required):
			counts.buried_waste += 1
		if str(row.location) == "ATTACHED":
			counts.attachments += 1
			var site_id := str(row.attachment_id).get_slice("/", 0)
			if not rescue_pairs.has(site_id):
				rescue_pairs[site_id] = []
			(rescue_pairs[site_id] as Array).append(row)
		if definition_id == &"waste_residue":
			counts.residue += 1
		if int(row.dirty_patch_count) > 0:
			counts.dirty_props += 1
		var section_entry := section_counts.get(section_id, {"pmd": 0, "organic": 0, "general": 0, "glass": 0, "props": 0}) as Dictionary
		if bool(row.required):
			var key := "props" if definition.kind == ItemDefinition.Kind.PROP else str(row.category)
			section_entry[key] = int(section_entry[key]) + 1
		section_counts[section_id] = section_entry
		if definition.kind == ItemDefinition.Kind.PROP:
			var family_zone_key := "%s/%s" % [row.zone_id, row.family]
			family_zone_counts[family_zone_key] = int(family_zone_counts.get(family_zone_key, 0)) + 1
		if section_id == &"arrival:start" and not definition.required_tool.is_empty():
			starter_locked += 1
		if bool(row.required) and definition.kind == ItemDefinition.Kind.WASTE and str(row.location) == "WORLD" and definition.required_tool.is_empty() and ("sand" in pack.tags or "deck" in pack.tags):
			exposed_dry += 1
		if str(row.location) == "ATTACHED" and "attachment" not in pack.tags:
			errors.append("Attached item %s is outside an attachment pack." % item_id)
		if str(row.location) == "BURIED" and "buried" not in pack.tags:
			errors.append("Buried item %s is outside a buried pack." % item_id)
		if not _tags_intersect(definition.eligible_spawn_tags, pack.tags):
			errors.append("Manifest item %s is incompatible with anchor %s." % [item_id, pack.anchor_id])
		if "water_surface" in pack.tags:
			var water_depth := absi(int(pack.origin_mm[1]))
			if water_depth < int(pack.min_depth_mm) or water_depth > int(pack.max_depth_mm):
				errors.append("Section %s has an illegal authored water depth." % section_id)
	if rescue_pairs.size() != int(expected.attachments) / 2:
		errors.append("Manifest has %d rescue sites, expected %d." % [rescue_pairs.size(), int(expected.attachments) / 2])
	for site_id in rescue_pairs:
		var pair := rescue_pairs[site_id] as Array
		if pair.size() != 2:
			errors.append("Rescue site %s must have exactly two attachments." % site_id)
			continue
		var first := pair[0] as Dictionary
		var second := pair[1] as Dictionary
		var a := first.position_mm as Array
		var b := second.position_mm as Array
		if first.section_id != second.section_id or absf(float(a[0]) - float(b[0])) > 800.0 or absf(float(a[2]) - float(b[2])) > 800.0:
			errors.append("Rescue site %s attachments are not co-located in one section." % site_id)
	if starter_locked > 0:
		errors.append("Starter section contains %d tool-locked objectives." % starter_locked)
	if exposed_dry < 1000:
		errors.append("Only %d exposed dry waste items fund the mandatory tool route; 1000 required." % exposed_dry)
	for key in [&"pmd", &"organic", &"general", &"glass", &"props", &"required", &"valuables", &"buried_waste", &"attachments", &"residue", &"dirty_props"]:
		if int(counts[str(key)]) != int(expected[key]):
			errors.append("Manifest %s count is %d, expected %d." % [key, counts[str(key)], expected[key]])
	var section_quotas := quotas.get_meta(&"sections") as Dictionary
	for section_id in beach.ordered_sections:
		var actual := section_counts.get(section_id, {}) as Dictionary
		var quota := section_quotas[section_id] as Dictionary
		for key in [&"pmd", &"organic", &"general", &"glass", &"props"]:
			if int(actual.get(key, 0)) != int(quota[key]):
				errors.append("Manifest section %s %s count is wrong." % [section_id, key])
	var matrix := quotas.get_meta(&"prop_families_by_zone") as Dictionary
	for zone_id in matrix:
		for family_id in matrix[zone_id]:
			var key := "%s/%s" % [zone_id, family_id]
			if int(family_zone_counts.get(key, 0)) != int(matrix[zone_id][family_id]):
				errors.append("Manifest prop family count is wrong for %s." % key)
	if str(generation.get("manifest_hash", "")) != str(generation.get("canonical", "")).sha256_text():
		errors.append("Manifest hash does not match its canonical payload.")
	return errors


static func _validate_destinations(errors: PackedStringArray, beach: BeachDefinition, family_totals: Dictionary) -> void:
	var shared := beach.slot_inventories.get(&"shared_small_shelves", {}) as Dictionary
	var shared_demand := 0
	for family_id in shared.get(&"families", PackedStringArray()):
		shared_demand += int(family_totals.get(StringName(family_id), 0))
	if shared_demand > int(shared.get(&"capacity", 0)):
		errors.append("Shared small-shelf capacity is %d for %d props." % [shared.get(&"capacity", 0), shared_demand])
	for family_id in family_totals:
		if family_id in shared.get(&"families", PackedStringArray()):
			continue
		if not beach.slot_inventories.has(family_id):
			errors.append("No destination inventory exists for prop family %s." % family_id)
			continue
		var capacity := int((beach.slot_inventories[family_id] as Dictionary).get(&"capacity", 0))
		if capacity < int(family_totals[family_id]):
			errors.append("Destination capacity for %s is %d, needs %d." % [family_id, capacity, family_totals[family_id]])


static func _tags_intersect(required_tags: Array[StringName], available_tags: Variant) -> bool:
	for tag in required_tags:
		if tag in available_tags:
			return true
	return false


static func _walk_route_distance_mm(point: Vector2, route: Array) -> float:
	var closest := INF
	for index in range(route.size() - 1):
		var start := route[index] as Vector3
		var finish := route[index + 1] as Vector3
		var a := Vector2(start.x, start.z) * 1000.0
		var segment := (Vector2(finish.x, finish.z) - Vector2(start.x, start.z)) * 1000.0
		var fraction := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
		closest = minf(closest, point.distance_to(a + segment * fraction))
	return closest
