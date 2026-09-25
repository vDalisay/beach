extends Node3D
const Coastline = preload("res://scripts/world/coastline.gd")

const DUNE := preload("res://art/synty/wrappers/world_reef_ridge.tscn")
const GRASS := preload("res://art/synty/wrappers/foliage_grass_clump.tscn")
## Dry sand rows per column: an even spread up to the berm, then half-metre rows over the berm so
## the tideline litter lies on sand that follows the relief closely.
const BACK_ROWS := 60
const BERM_ROWS := 24
const BERM_BAND := 12.0
const DRY_ROWS := BACK_ROWS + BERM_ROWS
const DETAIL_HALF_WIDTH := 130.0
## Scenery that stands on the sand and follows its relief. Level-pad features (huts, the shop,
## the pier approach, lookouts, shades, the court) sit where the relief is flattened to zero.
const GROUNDED_GROUPS := ["Foliage", "ActivityAreas"]

@export var sand_material: Material

var _outer_palms: Array[Node3D] = []
# The sand and dune grass depend only on authored data, so the title backdrop and the run share them.
static var _sand_cache: Dictionary = {}
static var _grass_cache: MultiMesh


func _ready() -> void:
	_build_sand_surface()
	_build_outer_dunes()
	_build_dune_grass()
	_build_outer_palms()
	_ground_scenery()


## Raises authored scenery by the relief under it, before anything reads or batches its pose.
## Runs once when the beach enters the tree: the Terrain node comes before the scenery in the scene,
## so their own _ready (placement shelves, capture volumes) already sees the grounded pose.
func _ground_scenery() -> void:
	var beach := get_parent() as Node3D
	if beach == null or not BeachRelief.enabled:
		return
	var targets: Array[Node3D] = []
	for group_name in GROUNDED_GROUPS:
		var group := beach.get_node_or_null(group_name)
		if group == null:
			continue
		for child in group.get_children():
			if child is Node3D:
				targets.append(child as Node3D)
	var zones := beach.get_node_or_null("Zones")
	if zones != null:
		for node in zones.find_children("*", "Marker3D", true, false):
			# Placement pools and spawn anchors; recovery anchors sit on level pads.
			targets.append(node as Node3D)
	for node in _outer_palms:
		targets.append(node)
	for node in targets:
		var at := node.global_position
		if at.y < -0.5 or at.y > 1.0:
			continue
		var lift := BeachRelief.height(at.x, at.z)
		if lift != 0.0:
			node.global_position = at + Vector3.UP * lift


func _build_outer_dunes() -> void:
	var wrapper := DUNE.instantiate() as Node3D
	var source := wrapper.get_node("Visual/Ridge") as MeshInstance3D
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = source.mesh
	var dunes := [
		Vector3(-104, 0, 4), Vector3(-135, 0, 20), Vector3(-145, 0, 33),
		Vector3(105, 0, 9), Vector3(137, 0, 28), Vector3(145, 0, 33),
	]
	for side in [-1.0, 1.0]:
		for distance in [180.0, 218.0, 256.0]:
			var x: float = side * distance
			dunes.append(Vector3(x, 0, lerpf(Coastline.inland_z(x), Coastline.shore_z(x), 0.37)))
	instances.instance_count = dunes.size()
	for index in dunes.size():
		var basis := Basis(Vector3.UP, float(index) * 0.8).scaled(Vector3(6.0, 16.0, 6.0))
		instances.set_instance_transform(index, Transform3D(basis, dunes[index]))
	var visual := MultiMeshInstance3D.new()
	visual.name = "OuterDunes"
	visual.multimesh = instances
	var dry_sand := sand_material.duplicate() as ShaderMaterial
	dry_sand.set_shader_parameter("use_shore_data", false)
	# Outside the play area: no grain or shells (and no copy of the Beach detail setting to follow).
	dry_sand.set_shader_parameter("beach_detail", false)
	visual.material_override = dry_sand
	add_child(visual)
	wrapper.free()


## Marram-style grass on the back dunes, thicker toward the crests, so the relief reads from eye
## level. Visual only (no collision), one batch, clear of level pads and of the litter at the toe.
func _build_dune_grass() -> void:
	if _grass_cache == null:
		_grass_cache = _dune_grass_instances()
	if _grass_cache == null:
		return
	var visual := MultiMeshInstance3D.new()
	visual.name = "DuneGrass"
	visual.multimesh = _grass_cache
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


func _dune_grass_instances() -> MultiMesh:
	var wrapper := GRASS.instantiate() as Node3D
	var meshes := wrapper.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		wrapper.free()
		return null
	var source := meshes[0] as MeshInstance3D
	var mesh := source.mesh
	for surface in mesh.get_surface_count():
		var material := source.get_surface_override_material(surface)
		if material != null:
			if mesh == source.mesh:
				mesh = mesh.duplicate() as Mesh
			(mesh as ArrayMesh).surface_set_material(surface, material)
	var pads: Array[Rect2] = []
	var layout := load(BeachRelief.LAYOUT_PATH) as Resource
	if layout != null:
		for pad in layout.get_meta(&"pads", []) as Array:
			var rect := Rect2(Vector2(pad.center[0], pad.center[1]) - Vector2.ONE * float(pad.radius), Vector2.ONE * float(pad.radius) * 2.0) if str(pad.shape) == "circle" else Rect2(Vector2(pad.min[0], pad.min[1]), Vector2(pad.max[0] - pad.min[0], pad.max[1] - pad.min[1]))
			pads.append(rect.grow(1.5))
	var transforms: Array[Transform3D] = []
	var x := -150.0
	while x <= 150.0:
		var inland := Coastline.inland_z(x)
		var toe := BeachRelief.dune_toe(x)
		var terms := BeachRelief.column(x)
		var z := inland + 4.2
		while z < inland + toe - 2.0:
			var jx := x + (BeachRelief.noise(x * 7.1, z * 3.3, 1.0, 31) - 0.5) * 0.9
			var jz := z + (BeachRelief.noise(x * 5.3, z * 6.7, 1.0, 32) - 0.5) * 0.9
			var patch := BeachRelief.noise(jx, jz, 4.0, 33)
			# Patchiness first: most points fail it, and it is cheaper than the relief.
			var rise := BeachRelief.height_at(terms, jx, jz) if patch > 0.4 else 0.0
			var keep := rise > 0.35 and patch > 0.62 - 0.22 * clampf((rise - 0.35) / 1.2, 0.0, 1.0)
			if keep:
				for rect in pads:
					if rect.has_point(Vector2(jx, jz)):
						keep = false
						break
			if keep:
				var size := 1.0 + BeachRelief.noise(jx, jz, 0.7, 34) * 0.9
				var basis := Basis(Vector3.UP, BeachRelief.noise(jx, jz, 0.5, 35) * TAU).scaled(Vector3.ONE * size)
				transforms.append(Transform3D(basis, Vector3(jx, Coastline.surface_y(jx, jz) - 0.04, jz)))
			z += 1.1
		x += 1.1
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for index in transforms.size():
		instances.set_instance_transform(index, transforms[index])
	wrapper.free()
	return instances


func _build_outer_palms() -> void:
	var positions := [
		Vector3(-98, 0, 11), Vector3(-108, 0, 27), Vector3(-119, 0, 10),
		Vector3(-124, 0, 35), Vector3(-137, 0, 27), Vector3(-146, 0, 39),
		Vector3(98, 0, 11), Vector3(108, 0, 27), Vector3(119, 0, 10),
		Vector3(124, 0, 35), Vector3(137, 0, 27), Vector3(146, 0, 39),
	]
	for side in [-1.0, 1.0]:
		for distance in [168.0, 177.0, 195.0, 211.0, 222.0, 240.0, 250.0, 267.0]:
			var x: float = side * distance
			var across := 0.38 + 0.12 * float(positions.size() % 4)
			positions.append(Vector3(x, 0, lerpf(Coastline.inland_z(x), Coastline.shore_z(x), across)))
	for index in positions.size():
		var palm := FoliageVariants.instance_palm(index + 1, 0.78 + float(index % 4) * 0.11)
		palm.position = positions[index]
		palm.rotation.y = float(index) * 1.13
		add_child(palm)
		_outer_palms.append(palm)


## Columns across the beach: 1 m where the relief is detailed, then coarser toward the horizon.
static func sand_columns() -> PackedFloat32Array:
	var columns := PackedFloat32Array()
	var x := -500.0
	while x <= 500.0:
		columns.append(x)
		var ax := absf(x)
		x += 1.0 if ax < DETAIL_HALF_WIDTH else 2.5 if ax < 250.0 else 5.0
	return columns


func _build_sand_surface() -> void:
	if _sand_cache.get("material") == sand_material:
		_add_sand(_sand_cache.mesh as ArrayMesh, _sand_cache.shape as Shape3D)
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var shore_values := PackedVector2Array()
	var indices := PackedInt32Array()
	# Every column has the same rows: DRY_ROWS strips from the inland edge to 2 m above the
	# waterline carry the relief, then the unchanged wet, shallow and seabed rows.
	var rows := DRY_ROWS + 4
	var columns := sand_columns()
	for index in columns.size():
		var x := columns[index]
		var shore_z := Coastline.shore_z(x)
		var inland_z := Coastline.inland_z(x)
		var shore_value := Vector2(shore_z, Coastline.shore_slope(x))
		var terms := BeachRelief.column(x)
		var row_z := PackedFloat32Array()
		var berm_start := maxf(inland_z + 1.0, shore_z - 2.0 - BERM_BAND)
		for row in BACK_ROWS:
			row_z.append(lerpf(inland_z, berm_start, float(row) / float(BACK_ROWS)))
		for row in BERM_ROWS + 1:
			row_z.append(lerpf(berm_start, shore_z - 2.0, float(row) / float(BERM_ROWS)))
		row_z.append_array(PackedFloat32Array([shore_z + 28.0, shore_z + 55.0, 800.0]))
		for row in row_z.size():
			var z := row_z[row]
			# Dry rows reuse the column's relief terms; the wet rows keep the plain shore profile.
			vertices.append(Vector3(x, Coastline.DRY_SAND + BeachRelief.height_at(terms, x, z) if row <= DRY_ROWS else Coastline.surface_y(x, z), z))
			normals.append(Vector3.ZERO)
			uvs.append(Vector2(x / 160.0, z / 70.0))
			shore_values.append(shore_value)
		if index > 0:
			var a := (index - 1) * rows
			for strip in rows - 1:
				indices.append_array(PackedInt32Array([a + strip, a + strip + rows, a + strip + 1, a + strip + rows, a + strip + rows + 1, a + strip + 1]))
	# Godot's clockwise front faces: accumulate area-weighted triangle normals.
	for triangle in range(0, indices.size(), 3):
		var a := indices[triangle]
		var b := indices[triangle + 1]
		var c := indices[triangle + 2]
		var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		for vertex in [a, b, c]:
			normals[vertex] += normal
	for index in normals.size():
		normals[index] = normals[index].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = shore_values
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, sand_material)
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	_sand_cache = {"material": sand_material, "mesh": mesh, "shape": shape}
	_add_sand(mesh, shape)


func _add_sand(mesh: ArrayMesh, shape: Shape3D) -> void:
	var surface := MeshInstance3D.new()
	surface.name = "CurvedSandSurface"
	surface.mesh = mesh
	add_child(surface)
	var ground := StaticBody3D.new()
	ground.name = "CurvedSandCollision"
	ground.add_to_group("sand_surfaces")
	add_child(ground)
	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	collider.shape = shape
	ground.add_child(collider)
