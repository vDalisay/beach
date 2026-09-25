extends SceneTree

const REQUIRED_TAGS := [&"sand", &"pile", &"water_surface", &"seabed", &"buried", &"attachment"]
const SMALL_FAMILIES := ["beach_ball", "bucket", "spade", "speaker", "volleyball"]
const FAMILY_CAPACITIES := {
	&"beach_chair": 70,
	&"lounger": 50,
	&"parasol": 20,
	&"cooler": 16,
	&"surfboard": 16,
	&"portable_inflatable": 12,
	&"lifebuoy": 8,
	&"portable_tent": 4,
	&"small_rowboat": 4,
	&"paddle": 4,
}

var failures := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var definition := load("res://data/world/beach_01.tres") as BeachDefinition
	check(definition != null, "beach definition loads")
	if definition == null:
		quit(failures)
		return
	for error in definition.validation_errors():
		check(false, "definition: %s" % error)

	var beach := (load(definition.scene_path) as PackedScene).instantiate() as Node3D
	root.add_child(beach)
	await physics_frame
	await physics_frame

	var section_nodes: Array[BeachSection] = []
	_collect_typed(beach, BeachSection, section_nodes)
	var section_ids := {}
	var zone_counts := {}
	var waste_total := 0
	var prop_total := 0
	for section in section_nodes:
		check(not section_ids.has(section.section_id), "unique section ID: %s" % section.section_id)
		section_ids[section.section_id] = true
		zone_counts[section.zone_id] = int(zone_counts.get(section.zone_id, 0)) + 1
		waste_total += section.required_waste
		prop_total += section.required_props
		var budget := definition.section_budgets.get(section.section_id, {}) as Dictionary
		check(int(budget.get("waste", -1)) == section.required_waste and int(budget.get("props", -1)) == section.required_props, "scene budget matches data: %s" % section.section_id)
		check(section.restoration_visual_root != null and section.restoration_visual_root != section, "section has separate restoration visuals: %s" % section.section_id)
	check(section_ids.size() == definition.ordered_sections.size(), "all ordered sections exist exactly once")
	for section_id in definition.ordered_sections:
		check(section_ids.has(section_id), "ordered section exists: %s" % section_id)
	for zone_id in definition.ordered_zones:
		check(int(zone_counts.get(zone_id, 0)) >= 2 and int(zone_counts.get(zone_id, 0)) <= 4, "zone has 2–4 sections: %s" % zone_id)
	check(waste_total == 5400 and prop_total == 300, "world section budgets total 5,400 waste and 300 props")

	var anchor_ids := {}
	var covered_sections := {}
	var present_tags := {}
	var clearance_classes := {}
	for node in get_nodes_in_group(&"spawn_anchors"):
		if not beach.is_ancestor_of(node):
			continue
		var anchor := node as SpawnAnchor
		check(not anchor_ids.has(anchor.anchor_id), "unique spawn anchor ID: %s" % anchor.anchor_id)
		anchor_ids[anchor.anchor_id] = true
		covered_sections[anchor.section_id] = true
		clearance_classes[anchor.clearance_class] = true
		for tag in anchor.tags:
			present_tags[StringName(tag)] = true
	for section_id in definition.ordered_sections:
		check(covered_sections.has(section_id), "section has spawn coverage: %s" % section_id)
	for tag in REQUIRED_TAGS:
		check(present_tags.has(tag), "spawn tag exists: %s" % tag)
	check(clearance_classes.size() == 3, "small, medium and large anchor clearances exist")

	var pool_ids := {}
	var derived_ids := {}
	var total_capacity := 0
	var shelf_sections := 0
	var shelf_capacity := 0
	var family_capacity := {}
	for node in get_nodes_in_group(&"placement_pools"):
		if not beach.is_ancestor_of(node):
			continue
		var pool := node as PlacementSlot
		check(not pool_ids.has(pool.pool_id), "unique placement pool ID: %s" % pool.pool_id)
		pool_ids[pool.pool_id] = true
		total_capacity += pool.capacity
		if str(pool.pool_id).begins_with("shelf:"):
			shelf_sections += 1
			shelf_capacity += pool.capacity
			var families := Array(pool.accepted_families)
			families.sort()
			check(families == SMALL_FAMILIES, "shared shelf accepts all small families: %s" % pool.pool_id)
		else:
			for family_text in pool.accepted_families:
				var family := StringName(family_text)
				family_capacity[family] = int(family_capacity.get(family, 0)) + pool.capacity
		for index in pool.capacity:
			var slot_id := pool.derived_slot_id(index)
			check(not derived_ids.has(slot_id), "derived placement slot ID is unique: %s" % slot_id)
			derived_ids[slot_id] = true
	check(total_capacity >= 300, "placement capacity covers all reusable props")
	check(shelf_sections == 20 and shelf_capacity == 120, "twenty uniform six-place shelf sections exist")
	for family_value in FAMILY_CAPACITIES:
		var family := family_value as StringName
		check(int(family_capacity.get(family, 0)) >= int(FAMILY_CAPACITIES[family]), "family capacity is sufficient: %s" % family)

	var service_ids := {}
	for node in get_nodes_in_group(&"service_points"):
		if beach.is_ancestor_of(node):
			service_ids[StringName(node.get_meta("service_id", ""))] = true
	check(service_ids.keys().size() == 3 and service_ids.has(&"S1") and service_ids.has(&"S2") and service_ids.has(&"S3"), "S1, S2 and S3 service points exist")
	check(_count_beach_group(beach, &"equipment_shops") == 1, "one equipment shop exists")
	check(_count_beach_group(beach, &"spawn_exclusions") >= 3, "service spawn exclusions exist")
	check(_count_beach_group(beach, &"water_volumes") == 1, "bounded water volume exists")
	check(_count_beach_group(beach, &"swim_lanes") == 2, "both reefs reserve swim lanes")
	check(_count_beach_group(beach, &"wildlife_routes") == 2, "both reefs reserve turtle routes")
	check(beach.has_node("Boundaries/Rear") and beach.has_node("Boundaries/Ocean") and beach.has_node("Boundaries/West") and beach.has_node("Boundaries/East"), "all non-enterable world bounds exist")

	var recovery_ids := {}
	for node in get_nodes_in_group(&"recovery_anchors"):
		if not beach.is_ancestor_of(node):
			continue
		var recovery := node as RecoveryAnchor
		check(not recovery_ids.has(recovery.anchor_id), "unique recovery anchor ID: %s" % recovery.anchor_id)
		recovery_ids[recovery.anchor_id] = true
		check(recovery.dry and _has_ground_below(recovery.global_position) and _capsule_clear(recovery.global_position), "recovery anchor is dry, grounded and clear: %s" % recovery.anchor_id)
	check(recovery_ids.size() == 6, "six land recovery anchors exist")
	var player_spawn := beach.get_node_or_null("%PlayerSpawn") as Marker3D
	check(player_spawn != null and _has_ground_below(player_spawn.global_position) and _capsule_clear(player_spawn.global_position), "S1 player spawn exists, is grounded and clear")
	for clearance in get_nodes_in_group(&"hut_clearances"):
		if beach.is_ancestor_of(clearance):
			check(_capsule_clear((clearance as Node3D).global_position), "hut interior and three-metre door remain clear")

	var route := definition.starting_state.get("walk_route", []) as Array
	var route_length := 0.0
	for index in range(1, route.size()):
		route_length += (route[index] as Vector3).distance_to(route[index - 1] as Vector3)
	var walk_seconds := route_length / 3.5
	check(route_length >= 140.0 and route_length <= 160.0, "compact route spans roughly one quarter of the original beach")

	# Beach terrain pass: the baked layout still matches the scene, level places are level, the
	# playable relief stays walkable and generated loose items rest on the sand, not above it.
	var stale := BeachLayoutBaker.compare(beach, load(BeachLayoutBaker.LAYOUT_PATH))
	check(stale.is_empty(), "beach layout data matches the scene (re-run tools/bake_beach_layout.gd): %s" % stale)
	var steepest := 0.0
	for x in range(-79, 80):
		var z := -31.0
		while z < Coastline.shore_z(float(x)) - 2.0:
			steepest = maxf(steepest, rad_to_deg(Vector3.UP.angle_to(BeachRelief.land_normal(float(x), z))))
			z += 1.0
	check(steepest <= 20.0, "playable sand relief stays walkable (steepest %.1f°)" % steepest)
	var level_pads := 0
	for pad in (load(BeachLayoutBaker.LAYOUT_PATH) as Resource).get_meta(&"pads", []) as Array:
		if str(pad.mode) != "zero":
			continue
		var centre := Vector2(pad.center[0], pad.center[1]) if str(pad.shape) == "circle" else (Vector2(pad.min[0], pad.min[1]) + Vector2(pad.max[0], pad.max[1])) * 0.5
		check(absf(BeachRelief.height(centre.x, centre.y)) < 0.005, "level pad stays level: %s" % pad.id)
		level_pads += 1
	var generation := ManifestGenerator.new().generate("first-shore")
	var grounded := 0
	for row_value in generation.get("rows", []):
		var row := row_value as Dictionary
		var at := Vector3(row.position_mm[0], row.position_mm[1], row.position_mm[2]) / 1000.0
		if str(row.location) != "WORLD" or str(row.spawn_mode) == "pile" or at.z >= Coastline.shore_z(at.x) - 2.0 or not is_nan(BeachGround.pier_top(at.x, at.z)):
			continue
		check(absf(at.y - Coastline.surface_y(at.x, at.z)) <= 0.02, "loose land item rests on the sand: %s" % row.id)
		grounded += 1
	check(grounded > 2000, "most dry-sand litter is checked for resting on the sand (%d)" % grounded)
	print("B_TERRAIN steepest=%.1f level_pads=%d grounded=%d" % [steepest, level_pads, grounded])
	print("P05_WORLD sections=%d anchors=%d pools=%d slots=%d route=%.1fm walk=%.1fs failures=%d" % [section_ids.size(), anchor_ids.size(), pool_ids.size(), total_capacity, route_length, walk_seconds, failures])
	quit(failures)


func _collect_typed(node: Node, script_class: Variant, output: Array) -> void:
	for child in node.get_children():
		if is_instance_of(child, script_class):
			output.append(child)
		_collect_typed(child, script_class, output)


func _count_beach_group(beach: Node, group: StringName) -> int:
	var count := 0
	for node in get_nodes_in_group(group):
		if beach.is_ancestor_of(node):
			count += 1
	return count


func _has_ground_below(position: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 2.0, position + Vector3.DOWN * 3.0, 1)
	return not root.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _capsule_clear(position: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.9)
	query.collision_mask = 1
	return root.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P05 FAIL: %s" % message)
