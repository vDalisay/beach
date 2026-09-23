extends Node3D
const Coastline = preload("res://scripts/world/coastline.gd")

const EDGE := preload("res://art/synty/wrappers/world_sand_edge_02.tscn")
const DUNE := preload("res://art/synty/wrappers/world_reef_ridge.tscn")

@export var sand_material: Material


func _ready() -> void:
	_build_sand_surface()
	_build_outer_dunes()
	var wrapper := EDGE.instantiate() as Node3D
	var source := wrapper.get_node("Visual/Edge") as MeshInstance3D
	var mesh := source.mesh.duplicate() as ArrayMesh
	for surface in mesh.get_surface_count():
		var material := source.get_surface_override_material(surface)
		if material != null:
			mesh.surface_set_material(surface, material)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = 21
	for index in 21:
		var x := float(index * 8 - 80)
		var shore_z := Coastline.shore_z(x)
		var gradient := (Coastline.shore_z(x + 1.0) - Coastline.shore_z(x - 1.0)) * 0.5
		var edge_basis := Basis(Vector3.UP, -atan(gradient)).scaled(Vector3(1, 0.3, 0.5))
		instances.set_instance_transform(index, Transform3D(edge_basis, Vector3(x, 0.12, shore_z)))
	var visual := MultiMeshInstance3D.new()
	visual.name = "SyntySandEdges"
	visual.multimesh = instances
	visual.material_override = source.material_override
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	wrapper.free()


func _build_outer_dunes() -> void:
	var wrapper := DUNE.instantiate() as Node3D
	var source := wrapper.get_node("Visual/Ridge") as MeshInstance3D
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = source.mesh
	var dunes := [
		Vector3(-104, 0, 4), Vector3(-135, 0, 20), Vector3(-167, 0, 5),
		Vector3(105, 0, 9), Vector3(137, 0, 28), Vector3(170, 0, 8),
	]
	instances.instance_count = dunes.size()
	for index in dunes.size():
		var basis := Basis(Vector3.UP, float(index) * 0.8).scaled(Vector3(6.0, 16.0, 6.0))
		instances.set_instance_transform(index, Transform3D(basis, dunes[index]))
	var visual := MultiMeshInstance3D.new()
	visual.name = "OuterDunes"
	visual.multimesh = instances
	visual.material_override = sand_material
	add_child(visual)
	wrapper.free()


func _build_sand_surface() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in 241:
		var x := float(index * 2.5 - 300)
		var shore_z := Coastline.shore_z(x)
		var points := [Vector2(-36.0, 0.012), Vector2(shore_z - 2.0, 0.012), Vector2(shore_z + 28.0, -2.5), Vector2(shore_z + 55.0, -3.2), Vector2(800.0, -3.2)]
		var tints := [Color.WHITE, Color.WHITE, Color(0.8, 0.95, 1), Color(0.35, 0.75, 0.85), Color(0.35, 0.75, 0.85)]
		for point_index in points.size():
			var point := points[point_index] as Vector2
			vertices.append(Vector3(x, point.y, point.x))
			normals.append(Vector3.UP)
			colors.append(tints[point_index])
			uvs.append(Vector2(x / 160.0, point.x / 70.0))
		if index > 0:
			var a := (index - 1) * 5
			for strip in 4:
				indices.append_array(PackedInt32Array([a + strip, a + strip + 5, a + strip + 1, a + strip + 5, a + strip + 6, a + strip + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface_material := sand_material.duplicate() as StandardMaterial3D
	surface_material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, surface_material)
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
