extends Node3D
const Coastline = preload("res://scripts/world/coastline.gd")

const DUNE := preload("res://art/synty/wrappers/world_reef_ridge.tscn")

@export var sand_material: Material


func _ready() -> void:
	_build_sand_surface()
	_build_outer_dunes()
	_build_outer_palms()


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
	visual.material_override = dry_sand
	add_child(visual)
	wrapper.free()


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


func _build_sand_surface() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var shore_values := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in 401:
		var x := float(index * 2.5 - 500)
		var shore_z := Coastline.shore_z(x)
		var inland_z := Coastline.inland_z(x)
		for z in [inland_z, shore_z - 2.0, shore_z + 28.0, shore_z + 55.0, 800.0]:
			vertices.append(Vector3(x, Coastline.surface_y(x, z), z))
			normals.append(Vector3.ZERO)
			uvs.append(Vector2(x / 160.0, z / 70.0))
			shore_values.append(Vector2(shore_z, Coastline.shore_slope(x)))
		if index > 0:
			var a := (index - 1) * 5
			for strip in 4:
				indices.append_array(PackedInt32Array([a + strip, a + strip + 5, a + strip + 1, a + strip + 5, a + strip + 6, a + strip + 1]))
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
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collider.shape = shape
	ground.add_child(collider)
