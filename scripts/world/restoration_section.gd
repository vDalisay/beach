class_name RestorationSection
extends Node

const PALM_SCENE := preload("res://art/synty/wrappers/foliage_palm.tscn")
const BUOY_SCENE := preload("res://art/synty/wrappers/prop_lifebuoy.tscn")
const FISH_SCENE := preload("res://scenes/wildlife/fish_school.tscn")
const TURTLE_SCENE := preload("res://scenes/wildlife/turtle.tscn")
const STARFISH_SCENE := preload("res://scenes/wildlife/starfish.tscn")
const RECIPES := preload("res://data/world/restoration_recipes.tres")
const REEF_DRESSING := preload("res://scripts/world/reef_dressing.gd")
const REEF_PLANT_ROCKS := {
	&"reef_west:outer": [0, 1, 3, 4],
	&"reef_west:coral": [2, 5, 6, 7, 8],
	&"reef_east:outer": [9, 12, 16],
	&"reef_east:coral": [11, 13, 14, 17],
}
const CORAL_OFFSETS := [
	Vector2(-2.4, 1.1), Vector2(-1.7, 1.7), Vector2(-2.1, 3.4), Vector2(-2.6, 4.8),
	Vector2(-0.6, 2.6), Vector2(0.2, 1.1), Vector2(0.5, 4.5), Vector2(0.0, 3.3),
	Vector2(1.7, 1.4), Vector2(2.5, 2.4), Vector2(1.4, 3.6), Vector2(2.2, 4.8),
]

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
			_start_section_population(section_id)
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
		for index in CORAL_OFFSETS.size():
			var coral := _coral_cluster(index)
			coral.name = "CoralCluster%02d" % index
			if str(section.zone_id).begins_with("reef_"):
				section.add_child(coral)
			else:
				section.restoration_visual_root.add_child(coral)
			var offset := CORAL_OFFSETS[index] as Vector2
			coral.global_position = origin + Vector3(offset.x, 0.0, offset.y)
			coral.scale = Vector3.ONE * [1.25, 0.85, 0.65][index % 3]
		for index in range(2):
			var starfish := STARFISH_SCENE.instantiate() as Node3D
			section.restoration_visual_root.add_child(starfish)
			starfish.global_position = origin + Vector3(index * 2.1 - 1.0, 0.07, 5.0)
		if str(section.zone_id).begins_with("reef_"):
			_build_reef_plants(section)
			_spawn_school(section.restoration_visual_root, StringName("section:%s:fish" % section.section_id), origin + Vector3(0, 1.2, 3.0))
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
		if str(zone_id).begins_with("reef_"):
			var turtle_anchor := Node3D.new()
			turtle_anchor.name = "ReefTurtleRouteAnchor"
			root.add_child(turtle_anchor)
			turtle_anchor.global_position = Vector3(2.5, 0, 112) if zone_id == &"reef_west" else Vector3(40, 0, 128)
			var route := PathAnimal.new()
			route.name = "ReefTurtleWaterLoop"
			turtle_anchor.add_child(route)
			var turtle_visual := TURTLE_SCENE.instantiate() as Node3D
			turtle_visual.rotation.y = PI
			route.add_child(turtle_visual)
			route.configure(StringName("zone:%s:turtle" % zone_id), [Vector3(0, -0.85, 0), Vector3(2, -0.75, 3)], [Vector3(2, -0.75, 3), Vector3(4, -0.7, 6), Vector3(1, -0.8, 10), Vector3(-2, -0.75, 7)], 1.5, _reduced_motion())
			populations[route.route_id] = route
	elif kind == "buoy":
		var buoy := BUOY_SCENE.instantiate() as Node3D
		root.add_child(buoy)
		buoy.global_position = origin + Vector3(-2.0, 0.7, -1.0)
	elif kind == "palm":
		var palm := PALM_SCENE.instantiate() as Node3D
		root.add_child(palm)
		palm.global_position = origin + Vector3(-2.8, -0.15, -4.0)
	if zone_id == &"lounges":
		var turtle_anchor := Node3D.new()
		turtle_anchor.name = "TurtleRouteAnchor"
		root.add_child(turtle_anchor)
		# Gap between the eastern lounge seating groups, heading straight into the bay.
		turtle_anchor.global_position = Vector3(-2.5, 0, 20)
		var route := PathAnimal.new()
		route.name = "TurtleBeachToWater"
		turtle_anchor.add_child(route)
		var turtle_visual := TURTLE_SCENE.instantiate() as Node3D
		turtle_visual.rotation.y = PI
		route.add_child(turtle_visual)
		route.configure(&"zone:lounges:turtle", [Vector3.ZERO, Vector3(0, 0, 8), Vector3(0, 0, 16), Vector3(0, -0.8, 28)], [Vector3(0, -0.8, 28), Vector3(2, -0.9, 30), Vector3(-2, -0.95, 32)], 2.0, _reduced_motion())
		populations[route.route_id] = route


func _coral_cluster(index: int) -> Node3D:
	var cluster := Node3D.new()
	var material := StandardMaterial3D.new()
	var target := [Color("ef8b91"), Color("95c7a1"), Color("d3a1d5")][index % 3] as Color
	material.albedo_color = Color("405257")
	material.emission_enabled = true
	material.emission = target * 0.25
	material.emission_energy_multiplier = 0.35
	cluster.set_meta(&"target_color", target)
	cluster.set_meta(&"material", material)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for stem in 5:
		var angle := (float(stem) + float(index) * 0.31) * TAU / 5.0
		var outward := Vector3(cos(angle), 0, sin(angle))
		var base := outward * 0.19
		var fork := base + outward * 0.12 + Vector3.UP * (0.75 + float(stem % 3) * 0.14)
		var crown := fork + outward * (0.16 + float(stem % 2) * 0.1) + Vector3.UP * (0.48 + float(index % 3) * 0.12)
		_append_coral_branch(vertices, normals, indices, base, fork, 0.048, 0.028)
		_append_coral_branch(vertices, normals, indices, fork, crown, 0.028, 0.006)
		_append_coral_branch(vertices, normals, indices, fork - Vector3.UP * 0.12, fork - outward * 0.17 + Vector3.UP * 0.33, 0.022, 0.005)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	cluster.add_child(visual)
	return cluster


func _append_coral_branch(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, base: Vector3, tip: Vector3, base_radius: float, tip_radius: float) -> void:
	var axis := (tip - base).normalized()
	var side := Vector3.RIGHT if absf(axis.y) > 0.9 else axis.cross(Vector3.UP).normalized()
	var depth := axis.cross(side).normalized()
	var first := vertices.size()
	for face in 6:
		var angle := float(face) * TAU / 6.0
		var radial := side * cos(angle) + depth * sin(angle)
		vertices.append(base + radial * base_radius)
		vertices.append(tip + radial * tip_radius)
		normals.append(radial)
		normals.append(radial)
	for face in 6:
		var bottom := first + face * 2
		var top := bottom + 1
		var next_bottom := first + ((face + 1) % 6) * 2
		var next_top := next_bottom + 1
		indices.append_array(PackedInt32Array([bottom, next_bottom, top, next_bottom, next_top, top]))


func _build_reef_plants(section: BeachSection) -> void:
	for rock_index in REEF_PLANT_ROCKS.get(section.section_id, []):
		var rock := REEF_DRESSING.STRUCTURES[rock_index] as Vector4
		# The Synty ridge visual extends farther than its pickup-safe collider.
		var clearance := 4.5 * (0.52 + float(rock_index % 3) * 0.04) * REEF_DRESSING.structure_scale(rock_index) + 0.5
		var channel_x := 2.5 if str(section.zone_id) == "reef_west" else 40.0
		var side := -1.0 if rock.x > channel_x else 1.0
		var local_direction := Vector3(side, 0, 0)
		# These two sides contain generated litter on the wildlife fixture seed.
		if rock_index == 0:
			local_direction = Vector3.BACK
		elif rock_index == 1:
			local_direction = Vector3.FORWARD
		var offset := Basis(Vector3.UP, rock.z) * local_direction * clearance
		var plant := _seagrass_bed(rock_index)
		section.add_child(plant)
		plant.global_position = Vector3(rock.x, -2.95, rock.y) + offset


func _seagrass_bed(index: int) -> Node3D:
	var bed := Node3D.new()
	bed.name = "SeagrassBed%02d" % index
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.27, 0.35, 0.36)
	bed.set_meta(&"material", material)
	bed.set_meta(&"target_color", Color(0.42, 0.73, 0.57))
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for blade in 9:
		var angle := float(blade) * TAU / 9.0 + float(index) * 0.37
		var outward := Vector3(cos(angle), 0, sin(angle))
		var across := Vector3(-outward.z, 0, outward.x)
		var height := 0.68 + float((blade * 3 + index) % 7) * 0.14
		var width := 0.065 + float(blade % 3) * 0.018
		var base := outward * (0.08 + float(blade % 2) * 0.12)
		var tip := base + outward * (0.17 + float(index % 2) * 0.1) + Vector3.UP * height
		var start := vertices.size()
		vertices.append_array(PackedVector3Array([base - across * width, base + across * width, tip + across * 0.012, tip - across * 0.012]))
		colors.append_array(PackedColorArray([Color(0.65, 0.72, 0.67), Color(0.65, 0.72, 0.67), Color.WHITE, Color.WHITE]))
		indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.name = "Blades"
	visual.mesh = mesh
	visual.material_override = material
	bed.add_child(visual)
	return bed


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
	for child in section.get_children() + section.restoration_visual_root.get_children():
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
	var turtle_key := StringName("zone:%s:turtle" % zone_id)
	if populations.has(turtle_key):
		var turtle := populations[turtle_key] as PathAnimal
		if loaded:
			turtle.resume_loop()
		else:
			turtle.start_intro()


func _start_section_population(section_id: StringName) -> void:
	var key := StringName("section:%s:fish" % section_id)
	if populations.has(key):
		(populations[key] as FishSchool).start_school()


func _reduced_motion() -> bool:
	return settings != null and bool(settings.get_value(&"reduced_motion"))


func _on_section_restored(section_id: StringName) -> void:
	if sections.has(section_id):
		var section := sections[section_id] as BeachSection
		if section.restoration_visual_root.visible:
			return
		section.restoration_visual_root.show()
		_set_section_colors(section, true)
		_start_section_population(section_id)


func _on_zone_restored(zone_id: StringName) -> void:
	if zone_roots.has(zone_id):
		(zone_roots[zone_id] as Node3D).show()
		_start_zone_population(zone_id, false)
