class_name RestorationSection
extends Node

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
const CORAL_MODELS := [
	"res://art/models/coral_branching.glb",
	"res://art/models/coral_tube.glb",
	"res://art/models/coral_fan.glb",
	"res://art/models/coral_brain.glb",
]
const CORAL_COLORS := [Color("ef8b91"), Color("f2a65a"), Color("c99be0"), Color("95c7a1"), Color("e8667a")]
const SEAWEED_MODELS := ["res://art/models/seagrass_tuft.glb", "res://art/models/seaweed_kelp.glb"]
const SHORE_BIRD_SCENE := preload("res://art/replacements/wildlife/shore_bird.tscn")
const GARDEN_SHADER := preload("res://shaders/reef_garden.gdshader")
# Restoration coral gardens: coral, kelp and seagrass on and around every reef rock.
const GARDEN_MODELS := [
	"res://art/models/coral_branching.glb", "res://art/models/coral_fan.glb", "res://art/models/coral_tube.glb",
	"res://art/models/coral_brain.glb", "res://art/models/seaweed_kelp.glb", "res://art/models/seagrass_tuft.glb",
]
# Cumulative model shares on rock tops, around rock bases and across the open seabed.
const GARDEN_TOP_SHARES := [0.18, 0.32, 0.48, 0.76, 0.82, 1.0]
const GARDEN_BASE_SHARES := [0.18, 0.3, 0.44, 0.6, 0.76, 1.0]
const GARDEN_FILL_SHARES := [0.14, 0.24, 0.34, 0.64, 0.7, 1.0]
const GARDEN_EXTRA_CORAL := [Color("c24d96"), Color("46559a")]
const GARDEN_PLANT_COLORS := [Color(0.42, 0.73, 0.57), Color(0.66, 0.8, 0.52), Color(0.36, 0.6, 0.62)]
const GARDEN_SPACING := 0.32
const GARDEN_BASE_SPACING := 0.42
# Open-seabed planting keeps this far from every litter item placed in the run.
const GARDEN_LITTER_CLEARANCE := 1.1
const FLYING_BIRD_SCENE := preload("res://art/replacements/wildlife/shore_bird_flying.tscn")
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
var reef_habitat_anchors: Dictionary = {}
var reef_garden_points: Dictionary = {}
var _garden_cells: Dictionary = {}
var _reef_litter_cells: Dictionary = {}
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
			_start_section_population(section_id, true)
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
	if node.has_meta(&"reef_habitat_anchors"):
		var world := node as Node3D
		for index in node.get_meta(&"reef_habitat_anchors") as Dictionary:
			var points: Array[Vector3] = []
			for point in (node.get_meta(&"reef_habitat_anchors") as Dictionary)[index]:
				points.append(world.to_global(point))
			reef_habitat_anchors[index] = points
	if node.has_meta(&"reef_garden_points"):
		var world := node as Node3D
		var garden := node.get_meta(&"reef_garden_points") as Dictionary
		for index in garden:
			var points: Array[Vector4] = []
			for value in garden[index]:
				var point := value as Vector4
				var at := world.to_global(Vector3(point.x, point.y, point.z))
				points.append(Vector4(at.x, at.y, at.z, point.w))
			reef_garden_points[index] = points
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
			if str(section.zone_id).begins_with("reef_"):
				coral.global_position.y = Coastline.surface_y(coral.global_position.x, coral.global_position.z) - 0.015
				coral.scale = Vector3.ONE * [0.95, 1.35, 1.75][(index / 2) % 3]
				var rocks := REEF_PLANT_ROCKS[section.section_id] as Array
				var rock_index: int = rocks[(index / 2) % rocks.size()]
				var points := reef_habitat_anchors.get(rock_index, []) as Array
				if index % 2 == 1 and not points.is_empty():
					coral.global_position = (points[index % points.size()] as Vector3) - Vector3.UP * 0.015
					# Low, medium and tall groups on the existing rocks, kept below the surface.
					var size: float = [0.95, 1.35, 1.85][index % 3]
					size = minf(size, maxf(0.25, (0.08 - 0.30 - coral.global_position.y) / 0.95))
					coral.scale = Vector3.ONE * size
					coral.rotation.y = float(index) * 1.17
		for index in range(2):
			var starfish := STARFISH_SCENE.instantiate() as Node3D
			section.restoration_visual_root.add_child(starfish)
			starfish.global_position = origin + Vector3(index * 2.1 - 1.0, 0.07, 5.0)
		if str(section.zone_id).begins_with("reef_"):
			_build_reef_plants(section)
			_build_coral_garden(section)
			_spawn_school(section.restoration_visual_root, StringName("section:%s:fish" % section.section_id), origin + Vector3(0, 1.2, 3.0))
	elif kind == "buoy":
		var buoy := BUOY_SCENE.instantiate() as Node3D
		section.restoration_visual_root.add_child(buoy)
		buoy.global_position = origin + Vector3(1.4, 0.7, -1.5)
	elif kind == "palm":
		var palm := FoliageVariants.instance_palm(section.section_id.hash())
		palm.name = "FoliagePalm"
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
			route.configure(StringName("zone:%s:turtle" % zone_id), [Vector3(0, -0.85, 0), Vector3(2, -0.75, 3)], [Vector3(2, -0.75, 3), Vector3(4, -0.7, 6), Vector3(1, -0.8, 10), Vector3(-2, -0.75, 7)], 1.0, _reduced_motion())
			_add_turtle_behavior(route, turtle_visual)
			populations[route.route_id] = route
	elif kind == "buoy":
		var buoy := BUOY_SCENE.instantiate() as Node3D
		root.add_child(buoy)
		buoy.global_position = origin + Vector3(-2.0, 0.7, -1.0)
	elif kind == "palm":
		var palm := FoliageVariants.instance_palm(zone_id.hash())
		palm.name = "FoliagePalm"
		root.add_child(palm)
		palm.global_position = origin + Vector3(-2.8, -0.15, -4.0)
	if kind in ["palm", "buoy"]:
		_add_shore_birds(zone_id, root, origin)
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
		route.configure(&"zone:lounges:turtle", [Vector3.ZERO, Vector3(0, 0, 8), Vector3(0, 0, 16), Vector3(0, -0.8, 28)], [Vector3(0, -0.8, 28), Vector3(2, -0.9, 30), Vector3(-2, -0.95, 32)], 1.1, _reduced_motion())
		_add_turtle_behavior(route, turtle_visual)
		populations[route.route_id] = route


func _add_turtle_behavior(route: PathAnimal, turtle_visual: Node3D) -> void:
	var animator := turtle_visual.get_node("Animator") as TurtleAnimator
	animator.reduced_motion = _reduced_motion()
	var behavior := TurtleBehavior.new()
	behavior.name = "Behavior"
	behavior.configure(session, animator)
	route.add_child(behavior)


func _coral_cluster(index: int) -> Node3D:
	var cluster := Node3D.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	var target := CORAL_COLORS[index % CORAL_COLORS.size()] as Color
	# Bleached grey before restoration; the tween brings back the coral's colour.
	material.albedo_color = Color("405257")
	cluster.set_meta(&"target_color", target)
	cluster.set_meta(&"material", material)
	var main := MeshInstance3D.new()
	main.name = "Coral"
	main.mesh = ModelLibrary.mesh(CORAL_MODELS[index % CORAL_MODELS.size()])
	main.material_override = material
	cluster.add_child(main)
	var companion := MeshInstance3D.new()
	companion.name = "Companion"
	companion.mesh = ModelLibrary.mesh(CORAL_MODELS[(index + 2) % CORAL_MODELS.size()])
	companion.material_override = material
	companion.position = Vector3(0.32, 0.0, -0.18)
	companion.rotation.y = float(index) * 0.9
	companion.scale = Vector3.ONE * 0.55
	cluster.add_child(companion)
	return cluster


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
		plant.global_position.y = Coastline.surface_y(plant.global_position.x, plant.global_position.z) - 0.015
		plant.rotation.y = float(rock_index) * 0.73
		plant.scale = Vector3(0.9, [0.60, 1.00, 1.42][rock_index % 3], 0.9)


func _seagrass_bed(index: int) -> Node3D:
	var bed := Node3D.new()
	bed.name = "SeagrassBed%02d" % index
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	material.albedo_color = Color(0.27, 0.35, 0.36)
	bed.set_meta(&"material", material)
	bed.set_meta(&"target_color", Color(0.42, 0.73, 0.57))
	for tuft in 3:
		var blades := MeshInstance3D.new()
		blades.name = "Blades" if tuft == 0 else "Blades%d" % tuft
		# Kelp in every other bed gives the tall layer; tufts fill around it.
		var tall := tuft == 0 and index % 2 == 0
		blades.mesh = ModelLibrary.mesh(SEAWEED_MODELS[1 if tall else 0])
		blades.material_override = material
		var angle := float(tuft) * TAU / 3.0 + float(index) * 0.5
		blades.position = Vector3.ZERO if tuft == 0 else Vector3(cos(angle), 0.0, sin(angle)) * 0.32
		blades.rotation.y = angle
		blades.scale = Vector3.ONE * (1.0 if tuft == 0 else 0.7)
		bed.add_child(blades)
	return bed


func _build_coral_garden(section: BeachSection) -> void:
	# Dense coral and weed on and around this section's rocks and across its open seabed, clear
	# of this run's litter so pickups stay in view. Bleached until the section is restored.
	var rocks: Array[int] = []
	for index in reef_garden_points:
		if _garden_section(int(index)) == section.section_id:
			rocks.append(int(index))
	rocks.sort()
	var random := RandomNumberGenerator.new()
	random.seed = hash(section.section_id)
	var placed := _garden_cells
	var transforms: Array = []
	var tints: Array = []
	for model in GARDEN_MODELS.size():
		transforms.append([])
		tints.append([])
	for rock_index in rocks:
		for value in reef_garden_points[rock_index]:
			var point := value as Vector4
			var at := Vector3(point.x, point.y, point.z)
			# Background ridges have no litter margin, so only their upper faces are planted.
			if rock_index >= 100 and at.y < Coastline.surface_y(at.x, at.z) + 0.5:
				continue
			if rock_index < 100 and not REEF_DRESSING.blocks_point([at.x * 1000.0, at.y * 1000.0, at.z * 1000.0], 700.0):
				continue
			_plant_garden_piece(at, GARDEN_TOP_SHARES, random, placed, transforms, tints)
		if rock_index < 100:
			for at in _rock_base_points(rock_index, random):
				if REEF_DRESSING.blocks_point([at.x * 1000.0, at.y * 1000.0, at.z * 1000.0], 700.0):
					_plant_garden_piece(at, GARDEN_BASE_SHARES, random, placed, transforms, tints)
	for at in _garden_fill_points(section, rocks, random):
		_plant_garden_piece(at, GARDEN_FILL_SHARES, random, placed, transforms, tints, 1.2)
	var garden := _garden_batches(section, "CoralGarden", transforms, tints)
	if garden != null:
		garden.set_meta(&"material", garden.get_meta(&"garden_material"))
	# Restoration clears the litter strip; coral then grows back across it.
	var regrowth_transforms: Array = []
	var regrowth_tints: Array = []
	for model in GARDEN_MODELS.size():
		regrowth_transforms.append([])
		regrowth_tints.append([])
	for at in _regrowth_points(section, random):
		_plant_garden_piece(at, GARDEN_FILL_SHARES, random, placed, regrowth_transforms, regrowth_tints, 1.2)
	var regrowth := _garden_batches(section, "CoralRegrowth", regrowth_transforms, regrowth_tints)
	if regrowth != null:
		(regrowth.get_meta(&"garden_material") as ShaderMaterial).set_shader_parameter("growth", 0.0)
		regrowth.set_meta(&"regrowth_material", regrowth.get_meta(&"garden_material"))
		regrowth.hide()


func _garden_batches(section: BeachSection, label: String, transforms: Array, tints: Array) -> Node3D:
	# One MultiMesh per model under a node at the pieces' centre, sharing one fade material.
	var center := Vector3.ZERO
	var count := 0
	for list in transforms:
		for transform in list:
			center += (transform as Transform3D).origin
			count += 1
	if count == 0:
		return null
	center /= float(count)
	var material := ShaderMaterial.new()
	material.shader = GARDEN_SHADER
	material.set_shader_parameter("restored", 0.0)
	var root := Node3D.new()
	root.name = label
	root.set_meta(&"garden_material", material)
	section.add_child(root)
	root.global_transform = Transform3D(Basis.IDENTITY, center)
	for model in GARDEN_MODELS.size():
		var list := transforms[model] as Array
		if list.is_empty():
			continue
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		# Vertex colour is multiplied by the instance colour in the Compatibility renderer.
		instances.use_colors = true
		instances.mesh = ModelLibrary.mesh(GARDEN_MODELS[model])
		instances.instance_count = list.size()
		for index in list.size():
			var transform := list[index] as Transform3D
			instances.set_instance_transform(index, Transform3D(transform.basis, transform.origin - center))
			instances.set_instance_custom_data(index, tints[model][index])
			instances.set_instance_color(index, Color.WHITE)
		var batch := MultiMeshInstance3D.new()
		batch.name = "%s%d" % [label, model]
		batch.multimesh = instances
		batch.material_override = material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 75.0
		root.add_child(batch)
	return root


func _regrowth_points(section: BeachSection, random: RandomNumberGenerator) -> Array[Vector3]:
	# The section's litter strip, with sand channels; optional finds keep a clear margin.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var keep_clear: Array[Vector2] = []
	for value in session.state.items.values():
		var record := value as ItemRecord
		if record.home_section_id != section.section_id:
			continue
		var spot := record.last_world_transform.origin
		if record.required:
			low = low.min(Vector2(spot.x, spot.z))
			high = high.max(Vector2(spot.x, spot.z))
		else:
			keep_clear.append(Vector2(spot.x, spot.z))
	var result: Array[Vector3] = []
	if not is_finite(low.x):
		return result
	for grid_x in range(floori(low.x), ceili(high.x) + 1):
		for grid_z in range(floori(low.y), ceili(high.y) + 1):
			var spot := Vector2(grid_x + random.randf_range(0.1, 0.9), grid_z + random.randf_range(0.1, 0.9))
			if _garden_patch(spot) < -0.3 or REEF_DRESSING.blocks_point([spot.x * 1000.0, 0.0, spot.y * 1000.0], 0.0):
				continue
			var clear := true
			for other in keep_clear:
				if spot.distance_to(other) < GARDEN_LITTER_CLEARANCE:
					clear = false
					break
			if clear:
				result.append(Vector3(spot.x, Coastline.surface_y(spot.x, spot.y), spot.y))
	return result


func _garden_patch(spot: Vector2) -> float:
	# Low-frequency value in [-2, 2]; below -0.3 leaves winding sand channels between thickets.
	return sin(spot.x * 0.41 + 1.3 * sin(spot.y * 0.23)) + cos(spot.y * 0.37 - 0.8 * sin(spot.x * 0.19))


func _garden_fill_points(section: BeachSection, rocks: Array[int], random: RandomNumberGenerator) -> Array[Vector3]:
	# Patchy thickets across the section's pocket, clear of this run's litter and the rocks.
	if _reef_litter_cells.is_empty():
		for value in session.state.items.values():
			var record := value as ItemRecord
			if str(record.home_section_id).begins_with("reef_"):
				var spot := record.last_world_transform.origin
				var cell := Vector2i(floori(spot.x / GARDEN_LITTER_CLEARANCE), floori(spot.z / GARDEN_LITTER_CLEARANCE))
				if not _reef_litter_cells.has(cell):
					_reef_litter_cells[cell] = []
				(_reef_litter_cells[cell] as Array).append(Vector2(spot.x, spot.z))
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for value in session.state.items.values():
		var record := value as ItemRecord
		if record.home_section_id == section.section_id:
			var spot := record.last_world_transform.origin
			low = low.min(Vector2(spot.x, spot.z))
			high = high.max(Vector2(spot.x, spot.z))
	for rock_index in rocks:
		if rock_index < 100:
			var rock := REEF_DRESSING.STRUCTURES[rock_index] as Vector4
			low = low.min(Vector2(rock.x, rock.y))
			high = high.max(Vector2(rock.x, rock.y))
	var result: Array[Vector3] = []
	if not is_finite(low.x):
		return result
	low -= Vector2(3.0, 3.0)
	high += Vector2(3.0, 3.0)
	for grid_x in range(floori(low.x), ceili(high.x)):
		for grid_z in range(floori(low.y), ceili(high.y)):
			var spot := Vector2(grid_x + random.randf_range(0.15, 0.85), grid_z + random.randf_range(0.15, 0.85))
			if _garden_patch(spot) < -0.3:
				continue
			if REEF_DRESSING.blocks_point([spot.x * 1000.0, 0.0, spot.y * 1000.0], 0.0) or _near_reef_litter(spot):
				continue
			result.append(Vector3(spot.x, Coastline.surface_y(spot.x, spot.y), spot.y))
	return result


func _near_reef_litter(spot: Vector2) -> bool:
	var cell := Vector2i(floori(spot.x / GARDEN_LITTER_CLEARANCE), floori(spot.y / GARDEN_LITTER_CLEARANCE))
	for offset_x in range(-1, 2):
		for offset_z in range(-1, 2):
			for litter in _reef_litter_cells.get(cell + Vector2i(offset_x, offset_z), []):
				if spot.distance_to(litter as Vector2) < GARDEN_LITTER_CLEARANCE:
					return true
	return false


func _garden_section(index: int) -> StringName:
	for section_id in REEF_PLANT_ROCKS:
		if index in (REEF_PLANT_ROCKS[section_id] as Array):
			return section_id
	# Unlisted rocks and background ridges join the nearest reef section.
	var rock := REEF_DRESSING.STRUCTURES[index] as Vector4 if index < 100 else Vector4()
	var spot := REEF_DRESSING.POSITIONS[index - 100] as Vector2 if index >= 100 else Vector2(rock.x, rock.y)
	var nearest := StringName()
	var nearest_distance := INF
	for section_id in REEF_PLANT_ROCKS:
		var positions := anchors.get(section_id, []) as Array
		if positions.is_empty():
			continue
		var origin := positions[0] as Vector3
		var distance := Vector2(origin.x, origin.z).distance_to(spot)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = section_id
	return nearest


func _rock_base_points(rock_index: int, random: RandomNumberGenerator) -> Array[Vector3]:
	# Seabed points along the rock's footprint edge, in the same frame as blocks_point.
	var rock := REEF_DRESSING.STRUCTURES[rock_index] as Vector4
	var shelf := REEF_DRESSING.structure_scale(rock_index)
	var half := Vector2(3.5 + float(rock_index % 3) * 0.3, 2.5 + float(rock_index % 2) * 0.3) * shelf * 0.5
	var perimeter := 4.0 * (half.x + half.y)
	var steps := int(perimeter / GARDEN_BASE_SPACING)
	var result: Array[Vector3] = []
	for step in steps:
		var along := (float(step) + random.randf() * 0.6) / float(steps) * perimeter
		var local: Vector2
		var outward: Vector2
		if along < 2.0 * half.x:
			local = Vector2(-half.x + along, -half.y)
			outward = Vector2(0, -1)
		elif along < 2.0 * (half.x + half.y):
			local = Vector2(half.x, -half.y + along - 2.0 * half.x)
			outward = Vector2(1, 0)
		elif along < 4.0 * half.x + 2.0 * half.y:
			local = Vector2(half.x - (along - 2.0 * (half.x + half.y)), half.y)
			outward = Vector2(0, 1)
		else:
			local = Vector2(-half.x, half.y - (along - 4.0 * half.x - 2.0 * half.y))
			outward = Vector2(-1, 0)
		local += outward * lerpf(-0.15, 0.55, random.randf())
		var spot := Vector2(rock.x, rock.y) + local.rotated(rock.z)
		result.append(Vector3(spot.x, Coastline.surface_y(spot.x, spot.y), spot.y))
	return result


func _plant_garden_piece(at: Vector3, shares: Array, random: RandomNumberGenerator, placed: Dictionary, transforms: Array, tints: Array, size_scale := 1.0) -> void:
	var cell := Vector2i(floori(at.x / GARDEN_SPACING), floori(at.z / GARDEN_SPACING))
	if placed.has(cell):
		return
	var roll := random.randf()
	var model := 0
	while model < shares.size() - 1 and roll > float(shares[model]):
		model += 1
	var top := ModelLibrary.mesh(GARDEN_MODELS[model]).get_aabb().end.y
	var size := lerpf(0.55, 1.2, random.randf()) * (0.7 if model == 4 else 1.0) * size_scale
	# Every piece stays below the water surface.
	size = minf(size, (-0.28 - at.y) / maxf(top, 0.05))
	if size < 0.3:
		return
	placed[cell] = true
	(transforms[model] as Array).append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size), at - Vector3.UP * 0.03))
	var palette: Array = GARDEN_PLANT_COLORS if model >= 4 else CORAL_COLORS + GARDEN_EXTRA_CORAL
	(tints[model] as Array).append((palette[random.randi() % palette.size()] as Color).srgb_to_linear())


func _add_shore_birds(zone_id: StringName, root: Node3D, origin: Vector3) -> void:
	var ground := origin.y - 0.15
	for index in 3:
		var bird := SHORE_BIRD_SCENE.instantiate() as Node3D
		bird.name = "ShoreBird%02d" % index
		root.add_child(bird)
		var angle := float(index) * 2.1 + float(absi(str(zone_id).hash()) % 7)
		bird.global_position = Vector3(origin.x + 1.8 + cos(angle) * 1.4, ground, origin.z + 1.5 + sin(angle) * 1.1)
		bird.rotation.y = angle * 1.7
	var circle := PathAnimal.new()
	circle.name = "ShoreBirdCircle"
	root.add_child(circle)
	circle.global_position = Vector3(origin.x, ground + 9.0, origin.z + 4.0)
	for index in 2:
		var flyer := FLYING_BIRD_SCENE.instantiate() as Node3D
		flyer.name = "Flyer%02d" % index
		flyer.rotation.y = PI
		flyer.position = Vector3(float(index) * 1.6, float(index) * 0.8, float(index) * -1.2)
		circle.add_child(flyer)
	var loop: Array[Vector3] = []
	for step in 8:
		var angle := float(step) * TAU / 8.0
		loop.append(Vector3(cos(angle) * 7.0, sin(angle * 2.0) * 0.6, sin(angle) * 5.0))
	circle.configure(StringName("birds:%s" % zone_id), [], loop, 3.0, _reduced_motion())
	circle.resume_loop()


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
	school.session = session
	# A wide, gently rising and falling loop the school roams around rather than a tight circuit.
	school.configure(key, [Vector3.ZERO, Vector3(2.6, 0.15, 1.3), Vector3(0.4, -0.1, 3.0), Vector3(-2.2, 0.1, 1.5)], _reduced_motion())
	populations[key] = school
	return school


func _set_section_colors(section: BeachSection, animate: bool) -> void:
	for child in section.get_children() + section.restoration_visual_root.get_children():
		if child.has_meta(&"regrowth_material"):
			var regrowth := child.get_meta(&"regrowth_material") as ShaderMaterial
			(child as Node3D).show()
			if animate and not _reduced_motion():
				var grow := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				grow.tween_property(regrowth, "shader_parameter/growth", 1.0, 2.4)
				grow.tween_property(regrowth, "shader_parameter/restored", 1.0, 2.4)
			else:
				regrowth.set_shader_parameter("growth", 1.0)
				regrowth.set_shader_parameter("restored", 1.0)
			continue
		if not child.has_meta(&"material"):
			continue
		var material := child.get_meta(&"material") as Material
		# Coral gardens fade their shader weight; the other habitat pieces tween a colour.
		var property := "shader_parameter/restored" if material is ShaderMaterial else "albedo_color"
		var target: Variant = 1.0 if material is ShaderMaterial else child.get_meta(&"target_color")
		if animate and not _reduced_motion():
			create_tween().tween_property(material, property, target, 1.2)
		else:
			material.set(property, target)


func _start_zone_population(zone_id: StringName, loaded: bool) -> void:
	for key in populations:
		if str(key).begins_with("zone:%s:" % zone_id) and populations[key] is FishSchool:
			(populations[key] as FishSchool).start_school(not loaded)
	var turtle_key := StringName("zone:%s:turtle" % zone_id)
	if populations.has(turtle_key):
		var turtle := populations[turtle_key] as PathAnimal
		if loaded:
			turtle.resume_loop()
		else:
			turtle.start_intro()


func _start_section_population(section_id: StringName, loaded: bool) -> void:
	var key := StringName("section:%s:fish" % section_id)
	if populations.has(key):
		(populations[key] as FishSchool).start_school(not loaded)


func _reduced_motion() -> bool:
	return settings != null and bool(settings.get_value(&"reduced_motion"))


func _on_section_restored(section_id: StringName) -> void:
	if sections.has(section_id):
		var section := sections[section_id] as BeachSection
		if section.restoration_visual_root.visible:
			return
		section.restoration_visual_root.show()
		_set_section_colors(section, true)
		_start_section_population(section_id, false)


func _on_zone_restored(zone_id: StringName) -> void:
	if zone_roots.has(zone_id):
		(zone_roots[zone_id] as Node3D).show()
		_start_zone_population(zone_id, false)
