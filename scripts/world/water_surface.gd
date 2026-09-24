extends Node3D
const Coastline = preload("res://scripts/world/coastline.gd")

const MATERIAL := preload("res://shaders/beach_water.tres")
const SHORE_ROWS := [0.0, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 28.0, 55.0, 90.0, 150.0, 250.0, 450.0]
const SURFACE_Y := 0.08


func _ready() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var shore_values := PackedVector2Array()
	var depths := PackedColorArray()
	var indices := PackedInt32Array()
	var rows := SHORE_ROWS.size() + 1
	for index in 401:
		var x := float(index * 2.5 - 500)
		var near_z := Coastline.shore_z(x)
		for row in rows:
			var z: float = 800.0 if row == rows - 1 else near_z + SHORE_ROWS[row]
			vertices.append(Vector3(x, SURFACE_Y, z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(x, z) * 0.01)
			# UV2 keeps the visual gradient tied to the same authored shoreline as the mesh.
			shore_values.append(Vector2(near_z, Coastline.shore_slope(x)))
			depths.append(Color(clampf((SURFACE_Y - Coastline.surface_y(x, z)) / 8.0, 0.0, 1.0), 0.0, 0.0))
		if index > 0:
			for strip in rows - 1:
				var a := (index - 1) * rows + strip
				indices.append_array(PackedInt32Array([a, a + rows, a + 1, a + rows, a + rows + 1, a + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = shore_values
	arrays[Mesh.ARRAY_COLOR] = depths
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, MATERIAL)
	var surface := MeshInstance3D.new()
	surface.name = "SyntyWaterSurface"
	surface.mesh = mesh
	add_child(surface)
