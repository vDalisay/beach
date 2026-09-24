extends Node3D
const Coastline = preload("res://scripts/world/coastline.gd")

const MATERIAL := preload("res://shaders/beach_water.tres")


func _ready() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var shore_values := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in 241:
		var x := float(index * 2.5 - 300)
		var near_z := Coastline.shore_z(x)
		for z in [near_z, 800.0]:
			vertices.append(Vector3(x, 0.08, z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(x, z) * 0.01)
			# UV2 keeps the visual gradient tied to the same authored shoreline as the mesh.
			shore_values.append(Vector2(near_z, 0.0))
		if index > 0:
			var a := (index - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 2, a + 3, a + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = shore_values
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, MATERIAL)
	var surface := MeshInstance3D.new()
	surface.name = "SyntyWaterSurface"
	surface.mesh = mesh
	add_child(surface)
