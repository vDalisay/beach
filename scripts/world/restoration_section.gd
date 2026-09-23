class_name RestorationSection
extends Node

const PALM_SCENE := preload("res://art/synty/wrappers/foliage_palm.tscn")
const BUOY_SCENE := preload("res://art/synty/wrappers/prop_lifebuoy.tscn")
const FISH_SCENE := preload("res://scenes/wildlife/fish_school.tscn")
const TURTLE_SCENE := preload("res://scenes/wildlife/turtle.tscn")
const STARFISH_SCENE := preload("res://scenes/wildlife/starfish.tscn")
const RECIPES := preload("res://data/world/restoration_recipes.tres")

var session: RunSession
var sections: Dictionary = {}
var zone_roots: Dictionary = {}
var anchors: Dictionary = {}
var populations: Dictionary = {}
var settings: SettingsStore


func configure(run_session: RunSession, beach: Node3D, settings_store: SettingsStore = null) -> void:
	session = run_session
	settings = settings_store
	_find_nodes(beach)
	for section_id in sections:
		var section := sections[section_id] as BeachSection
		_build_section(section)
		var restored := bool((session.state.section_states[section_id] as Dictionary).restored_once)
		section.restoration_visual_root.visible = restored
		if restored:
			_set_section_colors(section, false)
	_build_ambient(beach)
	for zone_id in zone_roots:
		var root := zone_roots[zone_id] as Node3D
		_build_zone(zone_id, root)
		var restored := bool((session.state.zone_states[zone_id] as Dictionary).restored_once)
		root.visible = restored
		if restored:
			_start_zone_population(zone_id, true)
	session.section_restored.connect(_on_section_restored)
	session.zone_restored.connect(_on_zone_restored)


func _find_nodes(node: Node) -> void:
	if node is BeachSection:
		var section := node as BeachSection
		sections[section.section_id] = section
		if not zone_roots.has(section.zone_id):
			var root := Node3D.new()
			root.name = "ZoneReturn"
			section.get_parent().get_parent().add_child(root)
			zone_roots[section.zone_id] = root
	elif node is SpawnAnchor:
		var anchor := node as SpawnAnchor
		if not anchors.has(anchor.section_id):
			anchors[anchor.section_id] = []
		(anchors[anchor.section_id] as Array).append(anchor.global_position)
	for child in node.get_children():
		_find_nodes(child)


func _build_section(section: BeachSection) -> void:
	var positions := anchors.get(section.section_id, []) as Array
	var origin := positions[0] as Vector3 if not positions.is_empty() else section.global_position
	var kind := str(RECIPES.section_kinds.get(section.zone_id, ""))
	if kind == "coral":
		var clarity := MeshInstance3D.new()
		clarity.name = "LocalClarityPatch"
		var vertices := PackedVector3Array([Vector3.ZERO])
		var colors := PackedColorArray([Color(1, 1, 1, 0.14)])
		var indices := PackedInt32Array()
		for edge in range(17):
			var angle := float(edge) * TAU / 16.0
			vertices.append(Vector3(cos(angle) * 6.0, 0, sin(angle) * 6.0))
			colors.append(Color(1, 1, 1, 0))
			if edge > 0:
				indices.append_array(PackedInt32Array([0, edge + 1, edge]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var patch := ArrayMesh.new()
		patch.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		clarity.mesh = patch
		var patch_material := StandardMaterial3D.new()
		patch_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		patch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		patch_material.vertex_color_use_as_albedo = true
		patch_material.albedo_color = Color(0.8, 0.88, 0.73, 0.0)
		clarity.material_override = patch_material
		clarity.set_meta(&"material", patch_material)
		clarity.set_meta(&"target_color", Color(0.8, 0.88, 0.73, 1.0))
		section.restoration_visual_root.add_child(clarity)
		clarity.global_position = origin + Vector3(0, 0.04, 3.0)
		for index in range(12):
			var coral := _coral_cluster(index)
			section.restoration_visual_root.add_child(coral)
			coral.global_position = origin + Vector3((index % 4 - 1.5) * 1.7, 0.0, 1.0 + (index / 4) * 1.8)
			coral.scale = Vector3.ONE * (0.9 + (index % 3) * 0.18)
		for index in range(2):
			var starfish := STARFISH_SCENE.instantiate() as Node3D
			section.restoration_visual_root.add_child(starfish)
			starfish.global_position = origin + Vector3(index * 2.1 - 1.0, 0.07, 5.0)
	elif kind == "buoy":
		var buoy := BUOY_SCENE.instantiate() as Node3D
		section.restoration_visual_root.add_child(buoy)
		buoy.global_position = origin + Vector3(1.4, 0.7, -1.5)
	elif kind == "palm":
		var palm := PALM_SCENE.instantiate() as Node3D
		section.restoration_visual_root.add_child(palm)
		palm.global_position = origin + Vector3(2.4, -0.15, -3.0)


func _build_zone(zone_id: StringName, root: Node3D) -> void:
	var kind := str(RECIPES.zone_kinds.get(zone_id, ""))
	var section: BeachSection
	for section_value in sections.values():
		if (section_value as BeachSection).zone_id == zone_id:
			section = section_value as BeachSection
			break
	if section == null:
		return
	var positions := anchors.get(section.section_id, []) as Array
	var origin := positions[1] as Vector3 if zone_id == &"sandplay" and positions.size() > 1 else positions[0] as Vector3 if not positions.is_empty() else section.global_position
	if kind == "fish":
		for index in range(2):
			_spawn_school(root, StringName("zone:%s:%02d" % [zone_id, index + 1]), origin + Vector3(index * 2.2, 1.0, 3.0))
	elif kind == "buoy":
		var buoy := BUOY_SCENE.instantiate() as Node3D
		root.add_child(buoy)
		buoy.global_position = origin + Vector3(-2.0, 0.7, -1.0)
	elif kind == "palm":
		var palm := PALM_SCENE.instantiate() as Node3D
		root.add_child(palm)
		palm.global_position = origin + Vector3(-2.8, -0.15, -4.0)
	if zone_id == &"sandplay":
		var turtle_anchor := Node3D.new()
		turtle_anchor.name = "TurtleRouteAnchor"
		root.add_child(turtle_anchor)
		turtle_anchor.global_position = origin + Vector3(0, 0, 3.0)
		var route := PathAnimal.new()
		route.name = "TurtleBeachToWater"
		turtle_anchor.add_child(route)
		var turtle_visual := TURTLE_SCENE.instantiate() as Node3D
		turtle_visual.rotation.y = PI
		route.add_child(turtle_visual)
		route.configure(&"zone:sandplay:turtle", [Vector3.ZERO, Vector3(0, 0, 12), Vector3(0, 0, 22), Vector3(0, -0.8, 33)], [Vector3(0, -0.8, 33), Vector3(2, -0.9, 35), Vector3(-2, -0.95, 37)], 2.0, _reduced_motion())
		populations[route.route_id] = route


func _coral_cluster(index: int) -> Node3D:
	var cluster := Node3D.new()
	var material := StandardMaterial3D.new()
	var target := [Color("ef8b91"), Color("95c7a1"), Color("d3a1d5")][index % 3] as Color
	material.albedo_color = Color("405257")
	material.emission_enabled = true
	material.emission = target * 0.55
	material.emission_energy_multiplier = 0.6
	cluster.set_meta(&"target_color", target)
	cluster.set_meta(&"material", material)
	for branch in range(5):
		var stem := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.055
		mesh.bottom_radius = 0.11
		mesh.height = 0.45 + branch * 0.11
		stem.mesh = mesh
		stem.material_override = material
		stem.position = Vector3(cos(branch * TAU / 5.0) * 0.2, mesh.height * 0.5, sin(branch * TAU / 5.0) * 0.2)
		stem.rotation.z = 0.18 * (branch - 2)
		cluster.add_child(stem)
	return cluster


func _build_ambient(beach: Node3D) -> void:
	var root := Node3D.new()
	root.name = "AmbientWildlife"
	beach.add_child(root)
	for zone_id in [&"reef_west", &"reef_east"]:
		var section_id := StringName("%s:outer" % zone_id)
		var positions := anchors.get(section_id, []) as Array
		if positions.is_empty():
			continue
		var school := _spawn_school(root, StringName("ambient:%s" % zone_id), positions[0] as Vector3 + Vector3(0, 1.2, 3.0))
		school.start_school()


func _spawn_school(root: Node3D, key: StringName, origin: Vector3) -> FishSchool:
	if populations.has(key):
		return populations[key] as FishSchool
	var school := FISH_SCENE.instantiate() as FishSchool
	school.name = str(key).replace(":", "_")
	root.add_child(school)
	school.global_position = origin
	school.configure(key, [Vector3.ZERO, Vector3(2.4, 0.12, 1.2), Vector3(-1.0, -0.08, 1.8)], _reduced_motion())
	populations[key] = school
	return school


func _set_section_colors(section: BeachSection, animate: bool) -> void:
	for child in section.restoration_visual_root.get_children():
		if not child.has_meta(&"material"):
			continue
		var material := child.get_meta(&"material") as StandardMaterial3D
		var target := child.get_meta(&"target_color") as Color
		if animate and not _reduced_motion():
			create_tween().tween_property(material, "albedo_color", target, 1.2)
		else:
			material.albedo_color = target


func _start_zone_population(zone_id: StringName, loaded: bool) -> void:
	for key in populations:
		if str(key).begins_with("zone:%s:" % zone_id) and populations[key] is FishSchool:
			(populations[key] as FishSchool).start_school()
	if zone_id == &"sandplay" and populations.has(&"zone:sandplay:turtle"):
		var turtle := populations[&"zone:sandplay:turtle"] as PathAnimal
		if loaded:
			turtle.resume_loop()
		else:
			turtle.start_intro()


func _reduced_motion() -> bool:
	return settings != null and bool(settings.get_value(&"reduced_motion"))


func _on_section_restored(section_id: StringName) -> void:
	if sections.has(section_id):
		var section := sections[section_id] as BeachSection
		if section.restoration_visual_root.visible:
			return
		section.restoration_visual_root.show()
		_set_section_colors(section, true)


func _on_zone_restored(zone_id: StringName) -> void:
	if zone_roots.has(zone_id):
		(zone_roots[zone_id] as Node3D).show()
		_start_zone_population(zone_id, false)
