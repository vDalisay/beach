extends Node3D

const CITY_WINDOW := preload("res://art/synty/wrappers/world_city_window.tscn")
const LOWRISE_WINDOW := preload("res://art/synty/wrappers/world_lowrise_window.tscn")
const DECO_WINDOW := preload("res://art/synty/wrappers/world_deco_window.tscn")
const VILLA_WINDOW := preload("res://art/synty/wrappers/world_villa_window.tscn")
const TOWER_WINDOW := preload("res://art/synty/wrappers/world_tower_window.tscn")
const FLAT_ROOF := preload("res://art/synty/wrappers/world_roof_flat.tscn")
const TOWER_ROOF := preload("res://art/synty/wrappers/world_roof_tower.tscn")
const CITY_ROOF_CAP := preload("res://art/synty/wrappers/world_city_roof_cap.tscn")
const DECO_BALCONY := preload("res://art/synty/wrappers/world_deco_balcony.tscn")
const MOUNTAIN := preload("res://art/synty/wrappers/world_mountain_range.tscn")
const PALM := preload("res://art/synty/wrappers/foliage_palm.tscn")
const SIDEWALK := preload("res://art/synty/wrappers/world_sidewalk.tscn")
const PLANTER := preload("res://art/synty/wrappers/world_planter_bench.tscn")
const ROAD_TRIM := preload("res://art/synty/wrappers/world_road_trim.tscn")
const CLOUD_RING := preload("res://art/synty/wrappers/world_cloud_ring.tscn")
const DECO_AWNING := preload("res://art/synty/wrappers/world_pier_awning.tscn")

const BUILDINGS := [
	[-68.0, -80.0, 4, 10, 3],
	[-46.0, -92.0, 5, 14, 4],
	[-24.0, -77.0, 4, 9, 3],
	[-3.0, -93.0, 5, 7, 4],
	[20.0, -79.0, 4, 6, 3],
	[43.0, -94.0, 5, 5, 4],
	[65.0, -75.0, 4, 4, 3],
]


func _ready() -> void:
	_add_inland_ground()
	var city_walls: Array[Transform3D] = []
	var lowrise_walls: Array[Transform3D] = []
	var deco_walls: Array[Transform3D] = []
	var villa_walls: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var red_awnings: Array[Transform3D] = []
	var cream_awnings: Array[Transform3D] = []
	var deco_balconies: Array[Transform3D] = []
	for index in BUILDINGS.size():
		var spec: Array = BUILDINGS[index]
		var floors := int(spec[3])
		var walls: Array[Transform3D] = city_walls
		if floors <= 7 and index % 2 == 0:
			walls = villa_walls
		elif floors <= 8:
			walls = lowrise_walls
		elif index % 2 == 0:
			walls = deco_walls
		_add_building(walls, roofs, float(spec[0]), float(spec[1]), int(spec[2]), int(spec[3]), int(spec[4]))
		if floors <= 9:
			var west := float(spec[0]) - float(spec[2]) * 1.25
			var south := float(spec[1]) + float(spec[4]) * 1.25
			for column in int(spec[2]):
				var transforms := red_awnings if (index + column) % 2 == 0 else cream_awnings
				transforms.append(Transform3D(Basis.IDENTITY, Vector3(west + column * 2.5, 2.65, south + 0.08)))
		if index == 0 or index == 2:
			var west := float(spec[0]) - float(spec[2]) * 1.25
			var south := float(spec[1]) + float(spec[4]) * 1.25
			for floor_index in [2, 4, 6]:
				for column in [0, 2]:
					deco_balconies.append(Transform3D(Basis.IDENTITY, Vector3(west + column * 2.5, floor_index * 3.0 + 0.27, south + 0.1)))
	_add_multimesh("SyntyCityFacades", CITY_WINDOW, city_walls)
	var glass_finish := StandardMaterial3D.new()
	glass_finish.albedo_color = Color(0.13, 0.27, 0.34)
	glass_finish.roughness = 0.22
	glass_finish.metallic = 0.08
	_add_multimesh("SyntyCityWindows", CITY_WINDOW, city_walls, 1, glass_finish)
	_add_multimesh("SyntyLowriseFacades", LOWRISE_WINDOW, lowrise_walls)
	_add_multimesh("SyntyLowriseWindows", LOWRISE_WINDOW, lowrise_walls, 1, glass_finish)
	_add_multimesh("SyntyDecoFacades", DECO_WINDOW, deco_walls, 0, null, Color(0.92, 0.75, 0.61))
	_add_multimesh("SyntyDecoWindows", DECO_WINDOW, deco_walls, 1, glass_finish)
	_add_multimesh("SyntyVillaFacades", VILLA_WINDOW, villa_walls, 0, null, Color(0.92, 0.63, 0.47))
	_add_multimesh("SyntyVillaWindows", VILLA_WINDOW, villa_walls, 1, glass_finish)
	_add_multimesh("SyntyCityRoofs", FLAT_ROOF, roofs)
	var awning_red := StandardMaterial3D.new()
	awning_red.albedo_color = Color(0.79, 0.14, 0.11)
	awning_red.roughness = 0.9
	var awning_cream := StandardMaterial3D.new()
	awning_cream.albedo_color = Color(1.0, 0.93, 0.77)
	awning_cream.roughness = 0.9
	_add_multimesh("SyntyCityAwningsRed", DECO_AWNING, red_awnings, 0, awning_red)
	_add_multimesh("SyntyCityAwningsCream", DECO_AWNING, cream_awnings, 0, awning_cream)
	_add_multimesh("SyntyDecoBalconies", DECO_BALCONY, deco_balconies)
	var roof_cap := CITY_ROOF_CAP.instantiate() as Node3D
	roof_cap.name = "SyntyCityRoofCap"
	roof_cap.position = Vector3(20, 18, -79)
	add_child(roof_cap)

	var tower_walls: Array[Transform3D] = []
	for floor_index in 15:
		tower_walls.append(Transform3D(Basis.IDENTITY, Vector3(-46, floor_index * 3.0, -115)))
	_add_multimesh("SyntyTower", TOWER_WINDOW, tower_walls)
	_add_multimesh("SyntyTowerGlass", TOWER_WINDOW, tower_walls, 1, glass_finish)
	var tower_roof := TOWER_ROOF.instantiate() as Node3D
	tower_roof.position = Vector3(-46, 45, -115)
	add_child(tower_roof)

	for placement in [Vector3(180, -10, 365), Vector3(145, -14, -300)]:
		var island := MOUNTAIN.instantiate() as Node3D
		island.position = placement
		island.scale = Vector3(8, 8, 8)
		add_child(island)
		for mesh in island.find_children("*", "MeshInstance3D", true, false):
			var mountain_mesh := mesh as MeshInstance3D
			mountain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if placement.z < 0.0:
				var source_material := mountain_mesh.get_surface_override_material(0) as ShaderMaterial
				if source_material != null:
					var backdrop_material := source_material.duplicate() as ShaderMaterial
					backdrop_material.set_shader_parameter("color_tint", Color(1.65, 1.65, 1.5))
					mountain_mesh.set_surface_override_material(0, backdrop_material)
	for index in 10:
		var palm := PALM.instantiate() as Node3D
		palm.position = Vector3(-72.0 + index * 16.0, 0, -31.0 - float(index % 3) * 3.5)
		palm.rotation.y = float(index % 5) * 0.7
		var size := 0.75 + float(index % 4) * 0.1
		palm.scale = Vector3.ONE * size
		add_child(palm)
	_add_boulevard_details()
	_add_clouds()


func _add_inland_ground() -> void:
	var land := MeshInstance3D.new()
	land.name = "InlandGround"
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var x_positions := [-100.0, -80.0, -60.0, -30.0, 0.0, 30.0, 60.0, 80.0, 100.0]
	var back_positions := [-92.0, -108.0, -122.0, -137.0, -145.0, -140.0, -126.0, -110.0, -92.0]
	for column in x_positions.size():
		var x: float = x_positions[column]
		var back: float = back_positions[column]
		var front := maxf(-44.0, -34.0 + (absf(x) - 80.0) * 0.9)
		for point in [Vector2(front, 0.15), Vector2(back + 10.0, 0.15), Vector2(back, -2.6), Vector2(back - 25.0, -3.2)]:
			vertices.append(Vector3(x, point.y, point.x))
			normals.append(Vector3.UP)
		if column > 0:
			var a := (column - 1) * 4
			for strip in 3:
				indices.append_array(PackedInt32Array([a + strip, a + strip + 4, a + strip + 1, a + strip + 4, a + strip + 5, a + strip + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var ground_mesh := ArrayMesh.new()
	ground_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	land.mesh = ground_mesh
	var land_finish := StandardMaterial3D.new()
	land_finish.albedo_color = Color(0.83, 0.73, 0.57)
	land_finish.roughness = 0.96
	land_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	land_finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	land.material_override = land_finish
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)
	var pavement := StandardMaterial3D.new()
	pavement.albedo_color = Color(0.36, 0.3, 0.25)
	pavement.roughness = 0.96
	var tile := _mesh(SIDEWALK)
	var bounds := tile.get_aabb()
	var tiles: Array[Transform3D] = []
	var across := ceili(160.0 / bounds.size.x)
	for column in across:
		for row in 3:
			tiles.append(Transform3D(Basis.IDENTITY, Vector3(-80.0 + column * bounds.size.x - bounds.position.x, 0.03, -46.0 - row * bounds.size.z - bounds.position.z)))
	_add_multimesh("SyntyCitySidewalk", SIDEWALK, tiles, 0, pavement)
	var promenade_tiles: Array[Transform3D] = []
	for column in across:
		for row in 5:
			promenade_tiles.append(Transform3D(Basis.IDENTITY, Vector3(-80.0 + column * bounds.size.x - bounds.position.x, 0.36, -44.0 + row * bounds.size.z - bounds.position.z)))
	var paver_finish := StandardMaterial3D.new()
	paver_finish.albedo_color = Color(0.42, 0.38, 0.34)
	paver_finish.roughness = 0.95
	_add_multimesh("SyntyPromenadePavers", SIDEWALK, promenade_tiles, 0, paver_finish)
	var road := MeshInstance3D.new()
	road.name = "BoulevardSurface"
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(180, 0.08, 8)
	road.mesh = road_mesh
	road.position = Vector3(0, -0.01, -58)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.28, 0.25, 0.23)
	asphalt.roughness = 0.94
	road.material_override = asphalt
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)


func _add_boulevard_details() -> void:
	var curbs: Array[Transform3D] = []
	for index in 64:
		var x := -80.0 + index * 2.5
		for z in [-54.0, -62.0]:
			curbs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1, 0.4, 1)), Vector3(x, 0.15, z)))
	_add_multimesh("SyntyRoadCurbs", ROAD_TRIM, curbs)
	for index in 6:
		var x := -70.0 + index * 28.0
		var planter := PLANTER.instantiate() as Node3D
		planter.name = "SyntyPlanter%02d" % index
		planter.position = Vector3(x, 0.16, -49.0)
		planter.rotation.y = float(index % 2) * PI
		add_child(planter)
	for index in 11:
		var x := -75.0 + index * 15.0
		var z := -52.0 - float(index % 3) * 4.5
		var size := 0.68 + float(index % 5) * 0.08
		var palm := PALM.instantiate() as Node3D
		palm.name = "SyntyBoulevardPalm%02d" % index
		palm.position = Vector3(x, 0.15, z)
		palm.rotation.y = float(index % 7) * 0.48
		palm.scale = Vector3.ONE * size
		add_child(palm)


func _add_clouds() -> void:
	var cloud_finish := StandardMaterial3D.new()
	cloud_finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_finish.albedo_color = Color(0.95, 0.98, 1)
	cloud_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in 2:
		var clouds := CLOUD_RING.instantiate() as Node3D
		clouds.name = "SyntyCloudRing" if index == 0 else "SyntyCloudRingUpper"
		clouds.position = Vector3.ZERO if index == 0 else Vector3(0, 40, 0)
		clouds.rotation.y = 0.0 if index == 0 else 0.7
		clouds.scale = Vector3(3, 6, 3) if index == 0 else Vector3(2.2, 5, 2.2)
		for mesh in clouds.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = cloud_finish
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(clouds)


func _add_building(walls: Array[Transform3D], roofs: Array[Transform3D], center_x: float, center_z: float, columns: int, floors: int, depth: int) -> void:
	var core := MeshInstance3D.new()
	core.name = "BuildingCore"
	var mass := BoxMesh.new()
	mass.size = Vector3(columns * 2.5 - 0.8, floors * 3.0 - 0.2, depth * 2.5 - 0.8)
	core.mesh = mass
	core.position = Vector3(center_x, floors * 1.5, center_z)
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color(0.66, 0.68, 0.66) if floors > 9 else Color(0.77, 0.71, 0.62)
	finish.roughness = 0.9
	core.material_override = finish
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var west := center_x - columns * 1.25
	var east := center_x + columns * 1.25
	var north := center_z - depth * 1.25
	var south := center_z + depth * 1.25
	for floor_index in floors:
		var height := floor_index * 3.0
		for column in columns:
			walls.append(Transform3D(Basis.IDENTITY, Vector3(west + column * 2.5, height, south)))
		for column in depth:
			walls.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(west, height, north + column * 2.5)))
			walls.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(east, height, south - column * 2.5)))
	for column in columns:
		for row in depth:
			roofs.append(Transform3D(Basis.IDENTITY, Vector3(west + column * 2.5, floors * 3.0, north + row * 2.5)))


func _mesh(scene: PackedScene, component: int = 0, plaster_tint: Color = Color.WHITE) -> Mesh:
	var wrapper := scene.instantiate()
	var source := wrapper.find_children("*", "MeshInstance3D", true, false)[component] as MeshInstance3D
	var mesh := source.mesh.duplicate() as ArrayMesh
	for surface in mesh.get_surface_count():
		var material := source.get_surface_override_material(surface)
		if material is ShaderMaterial and (material as ShaderMaterial).shader.resource_path.ends_with("polygon.gdshader"):
			var is_plaster := material.resource_path.contains("/Plaster_")
			material = material.duplicate() as ShaderMaterial
			(material as ShaderMaterial).set_shader_parameter("enable_emission", false)
			(material as ShaderMaterial).set_shader_parameter("enable_emission_texture", false)
			if is_plaster:
				(material as ShaderMaterial).set_shader_parameter("color_tint", plaster_tint)
		if material != null:
			mesh.surface_set_material(surface, material)
	wrapper.free()
	return mesh


func _add_multimesh(label: String, scene: PackedScene, transforms: Array[Transform3D], component: int = 0, override_material: Material = null, plaster_tint: Color = Color.WHITE) -> void:
	var wrapper := scene.instantiate()
	var source := wrapper.find_children("*", "MeshInstance3D", true, false)[component] as MeshInstance3D
	var mesh := _mesh(scene, component, plaster_tint)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for index in transforms.size():
		instances.set_instance_transform(index, transforms[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = label
	visual.multimesh = instances
	visual.material_override = override_material
	if override_material == null:
		visual.material_override = source.material_override
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	wrapper.free()
