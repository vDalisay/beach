class_name ManifestGenerator
extends RefCounted

const GENERATOR_VERSION := "manifest-1"
const CONTENT_VERSION := "beach-content-7"
const REEF_DRESSING := preload("res://scripts/world/reef_dressing.gd")
const BEACH_PATH := "res://data/world/beach_01.tres"
const QUOTAS_PATH := "res://data/world/section_quotas.tres"
const ANCHORS_PATH := "res://data/world/spawn_anchors.tres"
const CATALOG_DIR := "res://data/items"
const CATEGORY_KEYS := [&"pmd", &"organic", &"general", &"glass"]
const WALK_ROUTE_CLEARANCE_MM := 1800
const RESCUE_COUNTS := {
	&"pier:moorings": 4,
	&"shallows:west": 4,
	&"shallows:east": 4,
	&"reef_west:outer": 4,
	&"reef_west:coral": 4,
	&"reef_east:outer": 2,
	&"reef_east:coral": 2,
}


func generate(
	seed_input: String,
	beach_override: BeachDefinition = null,
	quotas_override: Resource = null,
	anchors_override: Resource = null
) -> Dictionary:
	var normalized := normalize_seed(seed_input)
	if not normalized.ok:
		return _failure([normalized.error])

	var beach := beach_override if beach_override != null else load(BEACH_PATH) as BeachDefinition
	var quotas := quotas_override if quotas_override != null else load(QUOTAS_PATH) as Resource
	var anchors := anchors_override if anchors_override != null else load(ANCHORS_PATH) as Resource
	if quotas == null or anchors == null or str(quotas.get_meta(&"content_version", "")) != CONTENT_VERSION or str(anchors.get_meta(&"content_version", "")) != CONTENT_VERSION:
		return _failure(["Generator content version does not match %s." % CONTENT_VERSION])
	var definitions := load_catalog()
	var content_errors := ManifestValidator.validate_content(beach, quotas, anchors, definitions)
	if not content_errors.is_empty():
		return _failure(content_errors)

	var seed_text := str(normalized.seed)
	var content_hash := compute_content_hash(definitions, beach, quotas, anchors)
	var rows: Array[Dictionary] = []
	var rows_by_section := {}
	var section_quotas := quotas.get_meta(&"sections") as Dictionary
	var packs := anchors.get_meta(&"packs") as Dictionary
	var columns := int(anchors.get_meta(&"grid_columns"))
	var spacing := int(anchors.get_meta(&"grid_spacing_mm"))
	var family_queues := _build_family_queues(beach, quotas)

	for section_id in beach.ordered_sections:
		var quota := section_quotas[section_id] as Dictionary
		var pack := packs[section_id] as Dictionary
		var zone_id := StringName(str((beach.section_budgets[section_id] as Dictionary).zone))
		var litter_rng := stream_rng(seed_text, str(section_id), "litter", content_hash)
		var props_rng := stream_rng(seed_text, str(section_id), "props", content_hash)
		var sand_pack: bool = "sand" in pack.tags
		var prop_cells := _integer_range(480 if sand_pack else 640, 740)
		_shuffle(prop_cells, props_rng)
		var assigned_prop_cells: Array[int] = []
		var reserved := {}
		for _index in range(int(quota.props)):
			var cell: int = prop_cells.pop_back()
			assigned_prop_cells.append(cell)
			reserved[cell] = true
		var waste_cells: Array[int] = []
		for cell in (740 if sand_pack else 640):
			if not reserved.has(cell):
				waste_cells.append(cell)
		_shuffle(waste_cells, litter_rng)
		var section_rows: Array[Dictionary] = []
		var ordinal := 1

		for category_key in CATEGORY_KEYS:
			for _index in range(int(quota[category_key])):
				var definition := _pick_waste_definition(definitions, category_key, pack.tags, litter_rng)
				var row := _new_row(
					"item:%s:%05d" % [section_id, ordinal], definition, section_id, zone_id,
					pack, waste_cells.pop_back(), columns, spacing, litter_rng
				)
				row["category"] = str(category_key)
				section_rows.append(row)
				ordinal += 1

		var queue := family_queues[zone_id] as Array
		for _index in range(int(quota.props)):
			var family_id := StringName(str(queue.pop_front()))
			var definition := _definition_for_family(definitions, family_id)
			var row := _new_row(
				"item:%s:%05d" % [section_id, ordinal], definition, section_id, zone_id,
				pack, assigned_prop_cells.pop_back(), columns, spacing, props_rng, true
			)
			row["family"] = str(family_id)
			section_rows.append(row)
			ordinal += 1
		family_queues[zone_id] = queue
		rows_by_section[section_id] = section_rows
		rows.append_array(section_rows)

	_assign_rescues(rows_by_section, definitions, seed_text, content_hash)
	_assign_buried(rows_by_section, anchors, definitions, seed_text, content_hash)
	_assign_residue(rows_by_section, anchors, definitions, seed_text, content_hash)
	_assign_dirty_props(rows_by_section, seed_text, content_hash)
	_assign_piles(rows_by_section, anchors, definitions, seed_text, content_hash)
	_add_valuables(rows, rows_by_section, beach, anchors, definitions, seed_text, content_hash)
	_clear_walk_route(rows, beach.starting_state.get("walk_route", []) as Array, anchors, definitions)
	_clear_walk_route(rows, beach.starting_state.get("pier_carry_route", []) as Array, anchors, definitions)
	for service_value in (beach.starting_state.get("service_points", {}) as Dictionary).values():
		var service := service_value as Vector3
		_clear_walk_route(rows, [service + Vector3(0, 0, 5), service + Vector3(0, 0, -2)], anchors, definitions)
	if not _clear_reef_structures(rows, packs, columns, int(anchors.get_meta(&"grid_rows")), spacing):
		return _failure(["No clear reef anchor for required item."])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))

	var canonical_data := {
		"content_hash": content_hash,
		"content_version": CONTENT_VERSION,
		"generator_version": GENERATOR_VERSION,
		"rows": rows,
		"seed": seed_text,
	}
	var canonical := canonical_json(canonical_data)
	var result := {
		"ok": true,
		"seed": seed_text,
		"generator_version": GENERATOR_VERSION,
		"content_version": CONTENT_VERSION,
		"content_hash": content_hash,
		"manifest_hash": canonical.sha256_text(),
		"canonical": canonical,
		"rows": rows,
		"definitions": definitions,
	}
	var manifest_errors := ManifestValidator.validate_manifest(result, beach, quotas, anchors, definitions)
	if not manifest_errors.is_empty():
		return _failure(manifest_errors)
	return result


func normalize_seed(seed_input: String) -> Dictionary:
	var seed_text := seed_input.strip_edges()
	if seed_text.is_empty():
		seed_text = Crypto.new().generate_random_bytes(16).hex_encode()
	if seed_text.to_utf8_buffer().size() > 64:
		return {"ok": false, "error": "Seed must be at most 64 UTF-8 bytes."}
	for index in range(seed_text.length()):
		var codepoint := seed_text.unicode_at(index)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159):
			return {"ok": false, "error": "Seed cannot contain control characters."}
	return {"ok": true, "seed": seed_text}


func derive_stream(seed_text: String, section_id: String, stream_name: String, content_hash: String) -> Dictionary:
	if stream_name not in ["litter", "props", "piles", "dirt", "buried", "rescue", "valuables"]:
		return {"ok": false, "error": "Unknown generator stream: %s" % stream_name}
	var canonical := canonical_json([GENERATOR_VERSION, content_hash, seed_text, section_id, stream_name])
	var digest := canonical.sha256_text()
	return {
		"ok": true,
		"canonical": canonical,
		"hash": digest,
		"rng_seed": digest.substr(0, 15).hex_to_int(),
	}


func stream_rng(seed_text: String, section_id: String, stream_name: String, content_hash: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(derive_stream(seed_text, section_id, stream_name, content_hash).rng_seed)
	return rng


func canonical_json(value: Variant) -> String:
	return JSON.stringify(_plain(value), "", true, true)


func load_catalog() -> Dictionary:
	var result := {}
	var files := DirAccess.get_files_at(CATALOG_DIR)
	files.sort()
	for file_name in files:
		var resource_name := file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		var definition := load("%s/%s" % [CATALOG_DIR, resource_name]) as ItemDefinition
		if definition == null or definition.definition_id.is_empty() or result.has(definition.definition_id):
			continue
		result[definition.definition_id] = definition
	return result


func compute_content_hash(definitions: Dictionary, beach: BeachDefinition, quotas: Resource, anchors: Resource) -> String:
	var definition_rows: Array[Dictionary] = []
	var definition_ids := _sorted_string_keys(definitions)
	for definition_id in definition_ids:
		var definition := definitions[StringName(definition_id)] as ItemDefinition
		var dirt_anchors: Array[Array] = []
		for anchor in definition.dirt_patch_anchors:
			dirt_anchors.append([anchor.x, anchor.y, anchor.z])
		definition_rows.append({
			"base_sale_value": definition.base_sale_value,
			"collision_profile": definition.collision_profile,
			"definition_id": str(definition.definition_id),
			"display_name": definition.display_name,
			"dirt_patch_anchors": dirt_anchors,
			"eligible_spawn_tags": definition.eligible_spawn_tags,
			"float_mode": definition.float_mode,
			"hand_cost": definition.hand_cost,
			"kind": definition.kind,
			"material_tags": definition.material_tags,
			"required_tool": str(definition.required_tool),
			"sorting_family": str(definition.sorting_family),
			"spawn_weight": definition.spawn_weight,
			"visual_scene_path": definition.visual_scene_path,
			"waste_category": definition.waste_category,
		})
	return canonical_json([
		CONTENT_VERSION,
		definition_rows,
		beach.ordered_zones,
		beach.ordered_sections,
		beach.slot_inventories,
		beach.starting_state.get("walk_route", []),
		beach.starting_state.get("pier_carry_route", []),
		beach.starting_state.get("service_points", {}),
		quotas.get_meta(&"sections"),
		quotas.get_meta(&"prop_families_by_zone"),
		quotas.get_meta(&"global_totals"),
		anchors.get_meta(&"grid_columns"),
		anchors.get_meta(&"grid_rows"),
		anchors.get_meta(&"grid_spacing_mm"),
		anchors.get_meta(&"packs"),
		anchors.get_meta(&"pile_patterns"),
		RESCUE_COUNTS,
		WALK_ROUTE_CLEARANCE_MM,
	]).sha256_text()


func _clear_walk_route(rows: Array[Dictionary], route: Array, anchors: Resource, definitions: Dictionary) -> void:
	if route.size() < 2:
		return
	var packs := anchors.get_meta(&"packs") as Dictionary
	var columns := int(anchors.get_meta(&"grid_columns"))
	var grid_rows := int(anchors.get_meta(&"grid_rows"))
	var spacing := int(anchors.get_meta(&"grid_spacing_mm"))
	var occupied := {}
	for row in rows:
		occupied[_pose_key(row.position_mm as Array)] = true
	for row in rows:
		if str(row.location) != "WORLD":
			continue
		var definition := definitions[StringName(str(row.definition_id))] as ItemDefinition
		if definition.collision_profile != ItemDefinition.CollisionProfile.LARGE:
			continue
		var position := row.position_mm as Array
		if absf(float(position[1])) > 1800.0:
			continue
		var point := Vector2(float(position[0]), float(position[2]))
		if _route_distance_mm(point, route) >= WALK_ROUTE_CLEARANCE_MM:
			continue
		var pack := packs[StringName(str(row.section_id))] as Dictionary
		var origin := pack.get("prop_origin_mm", pack.origin_mm) as PackedInt32Array if str(row.kind) == "prop" else pack.origin_mm as PackedInt32Array
		var tangent := _route_tangent(point, route)
		var normal := Vector2(-tangent.y, tangent.x)
		for distance in [3000.0, 4500.0, 6000.0, 7500.0, 9000.0, 10500.0]:
			if _route_distance_mm(point, route) >= WALK_ROUTE_CLEARANCE_MM:
				break
			for side in [1.0, -1.0]:
				var candidate: Vector2 = point + normal * float(distance) * float(side)
				if candidate.x < float(origin[0]) - 700.0 or candidate.x > float(origin[0]) + float(columns - 1) * spacing + 700.0 or candidate.y < float(origin[2]) - 700.0 or candidate.y > float(origin[2]) + float(grid_rows - 1) * spacing + 700.0:
					continue
				if _route_distance_mm(candidate, route) < WALK_ROUTE_CLEARANCE_MM:
					continue
				var moved := [roundi(candidate.x), int(position[1]), roundi(candidate.y)]
				if occupied.has(_pose_key(moved)) or _large_near(rows, row, candidate, definitions):
					continue
				occupied.erase(_pose_key(position))
				row.position_mm = moved
				occupied[_pose_key(moved)] = true
				point = candidate
				break
		if _route_distance_mm(point, route) < WALK_ROUTE_CLEARANCE_MM:
			for grid_index in columns * grid_rows:
				var candidate := Vector2(float(origin[0] + (grid_index % columns) * spacing), float(origin[2] + (grid_index / columns) * spacing))
				if _route_distance_mm(candidate, route) < WALK_ROUTE_CLEARANCE_MM:
					continue
				var moved := [roundi(candidate.x), int(position[1]), roundi(candidate.y)]
				if occupied.has(_pose_key(moved)) or _large_near(rows, row, candidate, definitions):
					continue
				occupied.erase(_pose_key(position))
				row.position_mm = moved
				occupied[_pose_key(moved)] = true
				break


func _large_near(rows: Array[Dictionary], moving: Dictionary, candidate: Vector2, definitions: Dictionary) -> bool:
	for other in rows:
		if other == moving or str(other.location) != "WORLD":
			continue
		var definition := definitions[StringName(str(other.definition_id))] as ItemDefinition
		if definition.collision_profile != ItemDefinition.CollisionProfile.LARGE:
			continue
		var position := other.position_mm as Array
		if candidate.distance_to(Vector2(float(position[0]), float(position[2]))) < 1500.0:
			return true
	return false


func _route_distance_mm(point: Vector2, route: Array) -> float:
	var closest := INF
	for index in range(route.size() - 1):
		var start := route[index] as Vector3
		var finish := route[index + 1] as Vector3
		var a := Vector2(start.x, start.z) * 1000.0
		var b := Vector2(finish.x, finish.z) * 1000.0
		var segment := b - a
		var fraction := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
		closest = minf(closest, point.distance_to(a + segment * fraction))
	return closest


func _route_tangent(point: Vector2, route: Array) -> Vector2:
	var closest := INF
	var tangent := Vector2.RIGHT
	for index in range(route.size() - 1):
		var start := route[index] as Vector3
		var finish := route[index + 1] as Vector3
		var a := Vector2(start.x, start.z) * 1000.0
		var b := Vector2(finish.x, finish.z) * 1000.0
		var segment := b - a
		var fraction := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var distance := point.distance_to(a + segment * fraction)
		if distance < closest:
			closest = distance
			tangent = segment.normalized()
	return tangent


func _pose_key(position: Array) -> String:
	return "%d/%d/%d" % [position[0], position[1], position[2]]


func _clear_reef_structures(rows: Array[Dictionary], packs: Dictionary, columns: int, grid_rows: int, spacing: int) -> bool:
	var groups := {}
	var occupied := {}
	for row in rows:
		var position := row.reveal_position_mm as Array if not (row.reveal_position_mm as Array).is_empty() else row.position_mm as Array
		occupied[_pose_key(position)] = true
		if not str(row.section_id).begins_with("reef_"):
			continue
		var group_id := str(row.pile_id) if not str(row.pile_id).is_empty() else str(row.attachment_id).get_slice("/", 0) if not str(row.attachment_id).is_empty() else str(row.id)
		if not groups.has(group_id):
			groups[group_id] = []
		(groups[group_id] as Array).append(row)
	for group_value in groups.values():
		var group := group_value as Array
		var blocked := false
		for row_value in group:
			var row := row_value as Dictionary
			var position := row.reveal_position_mm as Array if not (row.reveal_position_mm as Array).is_empty() else row.position_mm as Array
			if REEF_DRESSING.blocks_point(position):
				blocked = true
				break
		if not blocked:
			continue
		for row_value in group:
			var row := row_value as Dictionary
			var position := row.reveal_position_mm as Array if not (row.reveal_position_mm as Array).is_empty() else row.position_mm as Array
			occupied.erase(_pose_key(position))
		var first := group[0] as Dictionary
		var first_position := first.reveal_position_mm as Array if not (first.reveal_position_mm as Array).is_empty() else first.position_mm as Array
		var pack := packs[StringName(str(first.section_id))] as Dictionary
		var origin := pack.origin_mm as PackedInt32Array
		var best_distance := INF
		var best_offset := Vector2i.ZERO
		var found := false
		for cell in columns * grid_rows:
			var candidate := Vector2i(origin[0] + (cell % columns) * spacing, origin[2] + (cell / columns) * spacing)
			var offset := candidate - Vector2i(int(first_position[0]), int(first_position[2]))
			var distance := offset.length_squared()
			if distance >= best_distance:
				continue
			var clear := true
			for row_value in group:
				var row := row_value as Dictionary
				var position := row.reveal_position_mm as Array if not (row.reveal_position_mm as Array).is_empty() else row.position_mm as Array
				var moved := [int(position[0]) + offset.x, int(position[1]), int(position[2]) + offset.y]
				if REEF_DRESSING.blocks_point(moved) or occupied.has(_pose_key(moved)):
					clear = false
					break
			if clear:
				best_distance = distance
				best_offset = offset
				found = true
		if not found:
			return false
		for row_value in group:
			var row := row_value as Dictionary
			row.position_mm[0] = int(row.position_mm[0]) + best_offset.x
			row.position_mm[2] = int(row.position_mm[2]) + best_offset.y
			if not (row.reveal_position_mm as Array).is_empty():
				row.reveal_position_mm[0] = int(row.reveal_position_mm[0]) + best_offset.x
				row.reveal_position_mm[2] = int(row.reveal_position_mm[2]) + best_offset.y
			var new_surface := row.reveal_position_mm as Array if not (row.reveal_position_mm as Array).is_empty() else row.position_mm as Array
			occupied[_pose_key(new_surface)] = true
	return true


func create_run_state(generation: Dictionary, run_id: String) -> RunState:
	var state := RunState.new()
	state.run_id = run_id
	state.seed_text = str(generation.seed)
	state.content_version = str(generation.content_version)
	state.generator_version = str(generation.generator_version)
	state.initial_manifest = (generation.rows as Array).duplicate(true)
	state.initial_manifest_hash = str(generation.manifest_hash)
	state.add_player()
	for row_value in generation.rows:
		var row := row_value as Dictionary
		var record := ItemRecord.new()
		record.item_id = StringName(str(row.id))
		record.definition_id = StringName(str(row.definition_id))
		record.home_section_id = StringName(str(row.section_id))
		record.home_zone_id = StringName(str(row.zone_id))
		record.required = bool(row.required)
		record.location = ItemRecord.location_from_name(StringName(str(row.location)))
		record.attachment_id = StringName(str(row.attachment_id))
		var position := row.position_mm as Array
		var basis := Basis(Vector3.UP, float(row.orientation_index) * TAU / 16.0)
		record.last_world_transform = Transform3D(basis, Vector3(float(position[0]), float(position[1]), float(position[2])) / 1000.0)
		record.buried = record.location == ItemRecord.Location.BURIED
		record.revealed = not record.buried
		if record.buried:
			var reveal_mm := row.reveal_position_mm as Array
			record.dig_surface_position = Vector3(float(reveal_mm[0]), float(reveal_mm[1]), float(reveal_mm[2])) / 1000.0
			record.reveal_transform = Transform3D(basis, record.dig_surface_position)
		for patch_index in range(int(row.dirty_patch_count)):
			record.dirty_patches_remaining.append(StringName("patch_%d" % (patch_index + 1)))
		state.add_item(record)
		if record.location == ItemRecord.Location.ATTACHED:
			var site_id := StringName(str(record.attachment_id).get_slice("/", 0))
			if not state.rescue_states.has(site_id):
				state.rescue_states[site_id] = {"attachment_ids": [], "released": false, "home_section_id": str(record.home_section_id)}
			(state.rescue_states[site_id].attachment_ids as Array).append(str(record.item_id))
	for site_id in state.rescue_states:
		(state.rescue_states[site_id].attachment_ids as Array).sort()
	return state


func _new_row(
	item_id: String,
	definition: ItemDefinition,
	section_id: StringName,
	zone_id: StringName,
	pack: Dictionary,
	cell: int,
	columns: int,
	spacing: int,
	rng: RandomNumberGenerator,
	use_prop_origin := false
) -> Dictionary:
	var position := _cell_position(pack, cell, columns, spacing, use_prop_origin)
	if "water_surface" in pack.tags and definition.float_mode == ItemDefinition.FloatMode.FLOAT and not (use_prop_origin and pack.has("prop_origin_mm")):
		position[1] = 80
	return {
		"anchor_id": str(pack.anchor_id),
		"attachment_id": "",
		"buried_depth_mm": 0,
		"category": "",
		"definition_id": str(definition.definition_id),
		"dirty_patch_count": 0,
		"family": str(definition.sorting_family),
		"id": item_id,
		"kind": _kind_name(definition.kind),
		"location": "WORLD",
		"orientation_index": rng.randi_range(0, 15),
		"pile_id": "",
		"pile_pattern_id": "",
		"pile_pattern_index": -1,
		"position_mm": position,
		"required": true,
		"reveal_position_mm": [],
		"section_id": str(section_id),
		"spawn_mode": "single",
		"zone_id": str(zone_id),
	}


func _build_family_queues(beach: BeachDefinition, quotas: Resource) -> Dictionary:
	var result := {}
	var matrix := quotas.get_meta(&"prop_families_by_zone") as Dictionary
	for zone_id in beach.ordered_zones:
		var queue: Array = []
		if matrix.has(zone_id):
			var zone_families := matrix[zone_id] as Dictionary
			for family_id in _sorted_string_keys(zone_families):
				for _index in range(int(zone_families[StringName(family_id)])):
					queue.append(StringName(family_id))
		result[zone_id] = queue
	return result


func _pick_waste_definition(
	definitions: Dictionary,
	category_key: StringName,
	pack_tags: Variant,
	rng: RandomNumberGenerator
) -> ItemDefinition:
	var candidates: Array[ItemDefinition] = []
	var total_weight := 0
	for definition_id in _sorted_string_keys(definitions):
		var definition := definitions[StringName(definition_id)] as ItemDefinition
		if definition.kind != ItemDefinition.Kind.WASTE:
			continue
		if definition.waste_category != _category_enum(category_key) or not definition.required_tool.is_empty():
			continue
		if not _tags_intersect(definition.eligible_spawn_tags, pack_tags):
			continue
		candidates.append(definition)
		total_weight += definition.spawn_weight
	var roll := rng.randi_range(1, total_weight)
	for definition in candidates:
		roll -= definition.spawn_weight
		if roll <= 0:
			return definition
	return candidates.back()


func _definition_for_family(definitions: Dictionary, family_id: StringName) -> ItemDefinition:
	for definition_id in _sorted_string_keys(definitions):
		var definition := definitions[StringName(definition_id)] as ItemDefinition
		if definition.kind == ItemDefinition.Kind.PROP and definition.sorting_family == family_id:
			return definition
	return null


func _assign_rescues(rows_by_section: Dictionary, definitions: Dictionary, seed_text: String, content_hash: String) -> void:
	var selected: Array[Dictionary] = []
	for section_text in _sorted_string_keys(RESCUE_COUNTS):
		var section_id := StringName(section_text)
		var rng := stream_rng(seed_text, str(section_id), "rescue", content_hash)
		var pmd: Array = []
		var general: Array = []
		for row_value in rows_by_section[section_id]:
			var row := row_value as Dictionary
			if row.category == "pmd":
				pmd.append(row)
			elif row.category == "general":
				general.append(row)
		_shuffle(pmd, rng)
		_shuffle(general, rng)
		for _index in range(int(RESCUE_COUNTS[section_id])):
			selected.append(pmd.pop_back() if selected.size() % 2 == 0 else general.pop_back())
	for index in range(selected.size()):
		var row := selected[index]
		if index % 2 == 1:
			var first := selected[index - 1] as Dictionary
			row.position_mm = [int(first.position_mm[0]) + 350, int(first.position_mm[1]), int(first.position_mm[2])]
		var definition_id := &"waste_rescue_ring" if index % 2 == 0 else &"waste_rescue_net"
		row.definition_id = str((definitions[definition_id] as ItemDefinition).definition_id)
		row.location = "ATTACHED"
		row.attachment_id = "rescue:%02d/piece:%d" % [index / 2 + 1, index % 2 + 1]


func _assign_buried(
	rows_by_section: Dictionary,
	anchors: Resource,
	definitions: Dictionary,
	seed_text: String,
	content_hash: String
) -> void:
	var packs := anchors.get_meta(&"packs") as Dictionary
	for category_data in [["pmd", 200, &"waste_buried_metal"], ["general", 100, &"waste_buried_scrap"]]:
		var selected := _select_round_robin(rows_by_section, packs, str(category_data[0]), int(category_data[1]), seed_text, content_hash, "buried")
		var rng_by_section := {}
		for row_value in selected:
			var row := row_value as Dictionary
			var section_id := StringName(str(row.section_id))
			if not rng_by_section.has(section_id):
				rng_by_section[section_id] = stream_rng(seed_text, str(section_id), "buried", content_hash)
			var rng := rng_by_section[section_id] as RandomNumberGenerator
			var pack := packs[section_id] as Dictionary
			var max_bury := maxi(120, int(pack.max_depth_mm)) if "water_surface" not in pack.tags else 450
			var depth := rng.randi_range(120, mini(450, max_bury))
			row.definition_id = str((definitions[category_data[2]] as ItemDefinition).definition_id)
			row.location = "BURIED"
			row.buried_depth_mm = depth
			row.reveal_position_mm = (row.position_mm as Array).duplicate()
			row.position_mm[1] = int(row.position_mm[1]) - depth


func _assign_residue(rows_by_section: Dictionary, anchors: Resource, definitions: Dictionary, seed_text: String, content_hash: String) -> void:
	var packs := anchors.get_meta(&"packs") as Dictionary
	var selected := _select_round_robin(rows_by_section, packs, "general", 120, seed_text, content_hash, "litter", true)
	for row_value in selected:
		(row_value as Dictionary).definition_id = str((definitions[&"waste_residue"] as ItemDefinition).definition_id)


func _assign_dirty_props(rows_by_section: Dictionary, seed_text: String, content_hash: String) -> void:
	var queues := {}
	var section_ids := _sorted_string_keys(rows_by_section)
	for section_text in section_ids:
		var candidates: Array = []
		for row_value in rows_by_section[StringName(section_text)]:
			var row := row_value as Dictionary
			if row.family in ["beach_chair", "lounger"]:
				candidates.append(row)
		var rng := stream_rng(seed_text, section_text, "dirt", content_hash)
		_shuffle(candidates, rng)
		queues[StringName(section_text)] = {"rows": candidates, "rng": rng}
	var selected := _round_robin_queues(queues, 60)
	for row_value in selected:
		var row := row_value as Dictionary
		var entry := queues[StringName(str(row.section_id))] as Dictionary
		row.dirty_patch_count = (entry.rng as RandomNumberGenerator).randi_range(1, 3)


func _assign_piles(rows_by_section: Dictionary, anchors: Resource, definitions: Dictionary, seed_text: String, content_hash: String) -> void:
	var patterns := anchors.get_meta(&"pile_patterns") as Dictionary
	var packs := anchors.get_meta(&"packs") as Dictionary
	var pattern_ids := _sorted_string_keys(patterns)
	for section_text in _sorted_string_keys(rows_by_section):
		if "water_surface" in (packs[StringName(section_text)] as Dictionary).tags:
			continue
		var candidates: Array = []
		for row_value in rows_by_section[StringName(section_text)]:
			var row := row_value as Dictionary
			var definition := definitions[StringName(str(row.definition_id))] as ItemDefinition
			if row.kind == "waste" and row.location == "WORLD" and row.definition_id != "waste_residue" and definition.collision_profile != ItemDefinition.CollisionProfile.LARGE:
				candidates.append(row)
		var rng := stream_rng(seed_text, section_text, "piles", content_hash)
		_shuffle(candidates, rng)
		var remaining := int(candidates.size() * 0.25)
		var cursor := 0
		var pile_serial := 1
		while remaining >= 4:
			var pattern_id := pattern_ids[rng.randi_range(0, pattern_ids.size() - 1)]
			var offsets := patterns[StringName(pattern_id)] as Array
			if offsets.size() > remaining:
				pattern_id = "scatter_4"
				offsets = patterns[&"scatter_4"] as Array
			var base_position := (candidates[cursor] as Dictionary).position_mm as Array
			for pattern_index in range(offsets.size()):
				var row := candidates[cursor + pattern_index] as Dictionary
				var offset: Variant = offsets[pattern_index]
				row.position_mm = [int(base_position[0]) + int(offset[0]), int(base_position[1]) + int(offset[1]), int(base_position[2]) + int(offset[2])]
				row.spawn_mode = "pile"
				row.pile_id = "pile:%s:%03d" % [section_text, pile_serial]
				row.pile_pattern_id = pattern_id
				row.pile_pattern_index = pattern_index
			cursor += offsets.size()
			remaining -= offsets.size()
			pile_serial += 1


func _add_valuables(
	rows: Array[Dictionary],
	rows_by_section: Dictionary,
	beach: BeachDefinition,
	anchors: Resource,
	definitions: Dictionary,
	seed_text: String,
	content_hash: String
) -> void:
	var packs := anchors.get_meta(&"packs") as Dictionary
	var columns := int(anchors.get_meta(&"grid_columns"))
	var spacing := int(anchors.get_meta(&"grid_spacing_mm"))
	for zone_id in beach.ordered_zones:
		var section_id := _first_buried_section(beach, packs, zone_id)
		var pack := packs[section_id] as Dictionary
		var rng := stream_rng(seed_text, str(section_id), "valuables", content_hash)
		var cells := _integer_range(740, int(anchors.get_meta(&"grid_columns")) * int(anchors.get_meta(&"grid_rows")))
		_shuffle(cells, rng)
		for ordinal in range(1, 6):
			var row := _new_row(
				"valuable:%s:%05d" % [section_id, ordinal], definitions[&"valuable_keys"], section_id, zone_id,
				pack, cells.pop_back(), columns, spacing, rng
			)
			var max_bury := maxi(120, int(pack.max_depth_mm)) if "water_surface" not in pack.tags else 450
			var depth := rng.randi_range(120, mini(450, max_bury))
			row.required = false
			row.location = "BURIED"
			row.buried_depth_mm = depth
			row.reveal_position_mm = (row.position_mm as Array).duplicate()
			row.position_mm[1] = int(row.position_mm[1]) - depth
			rows.append(row)
			(rows_by_section[section_id] as Array).append(row)


func _select_round_robin(
	rows_by_section: Dictionary,
	packs: Dictionary,
	category: String,
	target: int,
	seed_text: String,
	content_hash: String,
	stream_name: String,
	land_only := false
) -> Array:
	var queues := {}
	for section_text in _sorted_string_keys(rows_by_section):
		var section_id := StringName(section_text)
		var pack := packs[section_id] as Dictionary
		if "buried" not in pack.tags or section_id == &"arrival:start":
			continue
		if land_only and "sand" not in pack.tags and "deck" not in pack.tags:
			continue
		var candidates: Array = []
		for row_value in rows_by_section[section_id]:
			var row := row_value as Dictionary
			if row.category == category and row.location == "WORLD":
				candidates.append(row)
		var rng := stream_rng(seed_text, section_text, stream_name, content_hash)
		_shuffle(candidates, rng)
		queues[section_id] = {"rows": candidates, "rng": rng}
	return _round_robin_queues(queues, target)


func _round_robin_queues(queues: Dictionary, target: int) -> Array:
	var selected: Array = []
	var keys := _sorted_string_keys(queues)
	while selected.size() < target:
		var progressed := false
		for key_text in keys:
			var queue := (queues[StringName(key_text)] as Dictionary).rows as Array
			if queue.is_empty():
				continue
			selected.append(queue.pop_back())
			progressed = true
			if selected.size() == target:
				break
		if not progressed:
			break
	return selected


func _first_buried_section(beach: BeachDefinition, packs: Dictionary, zone_id: StringName) -> StringName:
	for section_id in beach.ordered_sections:
		if StringName(str((beach.section_budgets[section_id] as Dictionary).zone)) == zone_id and "buried" in (packs[section_id] as Dictionary).tags:
			return section_id
	return StringName()


func _cell_position(pack: Dictionary, cell: int, columns: int, spacing: int, use_prop_origin: bool) -> Array[int]:
	var origin: Variant = pack.get("prop_origin_mm", pack.origin_mm) if use_prop_origin else pack.origin_mm
	return [int(origin[0]) + (cell % columns) * spacing, int(origin[1]), int(origin[2]) + (cell / columns) * spacing]


func _integer_range(from: int, to_exclusive: int) -> Array:
	var values: Array = []
	for value in range(from, to_exclusive):
		values.append(value)
	return values


func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _tags_intersect(required_tags: Array[StringName], available_tags: Variant) -> bool:
	for tag in required_tags:
		if tag in available_tags:
			return true
	return false


func _category_enum(category_key: StringName) -> ItemDefinition.WasteCategory:
	match category_key:
		&"pmd": return ItemDefinition.WasteCategory.PMD
		&"organic": return ItemDefinition.WasteCategory.ORGANIC
		&"general": return ItemDefinition.WasteCategory.GENERAL
		&"glass": return ItemDefinition.WasteCategory.GLASS
	return ItemDefinition.WasteCategory.NONE


func _kind_name(kind: ItemDefinition.Kind) -> String:
	match kind:
		ItemDefinition.Kind.WASTE: return "waste"
		ItemDefinition.Kind.PROP: return "prop"
		ItemDefinition.Kind.VALUABLE: return "valuable"
	return "unknown"


func _sorted_string_keys(dictionary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in dictionary:
		result.append(str(key))
	result.sort()
	return result


func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return str(value)
		TYPE_DICTIONARY:
			var result := {}
			for key in value:
				result[str(key)] = _plain(value[key])
			return result
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY:
			var result: Array = []
			for child in value:
				result.append(_plain(child))
			return result
	return value


func _failure(errors: Variant) -> Dictionary:
	var messages := PackedStringArray()
	for error in errors:
		messages.append(str(error))
	return {"ok": false, "error": messages[0] if not messages.is_empty() else "Manifest generation failed.", "errors": messages}
