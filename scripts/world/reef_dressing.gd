extends Node3D

const RIDGE := preload("res://art/synty/wrappers/world_reef_ridge.tscn")
const MOUND := preload("res://art/synty/wrappers/world_reef_mound.tscn")
const POSITIONS := [
	Vector2(0.5, 95), Vector2(7.5, 91), Vector2(15.5, 98),
	Vector2(2, 137), Vector2(9.25, 142), Vector2(17, 132),
	Vector2(36.25, 110), Vector2(44, 106), Vector2(52.75, 112),
	Vector2(37, 153), Vector2(45.75, 154), Vector2(54.25, 142),
]
const STRUCTURES := [
	# West pocket: near frame, middle channel, rear ridge.
	Vector4(-3, 99, 0.2, 4.8), Vector4(8, 102, -0.4, 5.1), Vector4(-6, 107, 0.8, 4.0),
	Vector4(-1, 112, -0.6, 5.4), Vector4(6, 113, 0.5, 4.5), Vector4(13, 117, 1.1, 4.9),
	Vector4(-2, 127, 0.3, 5.5), Vector4(5, 131, -0.9, 4.3), Vector4(13, 128, 0.7, 5.0),
	# East pocket repeats the three-layer structure without closing its swim lanes.
	Vector4(31, 115, -0.5, 4.6), Vector4(47, 118, 0.8, 5.2), Vector4(53, 114, -0.9, 4.0),
	Vector4(35, 129, 0.4, 5.3), Vector4(44, 132, -0.6, 4.4), Vector4(53, 128, 1.0, 5.0),
	Vector4(30, 148, 0.9, 5.1), Vector4(39, 152, -0.3, 4.2), Vector4(50, 149, 0.5, 5.4),
]
const REAR_SHELF_ROCKS := [6, 7, 8, 17]


static func structure_scale(index: int) -> float:
	return 1.4 if index in REAR_SHELF_ROCKS else 1.0


static func blocks_point(position_mm: Array, margin_mm := 1200.0) -> bool:
	var point := Vector2(float(position_mm[0]), float(position_mm[2])) / 1000.0
	for index in STRUCTURES.size():
		var rock := STRUCTURES[index] as Vector4
		var local := (point - Vector2(rock.x, rock.y)).rotated(-rock.z)
		var shelf_scale := structure_scale(index)
		if absf(local.x) <= (3.5 + float(index % 3) * 0.3) * shelf_scale * 0.5 + margin_mm / 1000.0 and absf(local.y) <= (2.5 + float(index % 2) * 0.3) * shelf_scale * 0.5 + margin_mm / 1000.0:
			return true
	return false


func _ready() -> void:
	var wrapper := RIDGE.instantiate() as Node3D
	var source := wrapper.get_node("Visual/Ridge") as MeshInstance3D
	var mound_wrapper := MOUND.instantiate() as Node3D
	var mound_source := mound_wrapper.get_node("Visual/Mound") as MeshInstance3D
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = source.mesh
	instances.instance_count = POSITIONS.size()
	for index in POSITIONS.size():
		var point := POSITIONS[index] as Vector2
		var basis := Basis(Vector3.UP, float(index) * 1.37).scaled(Vector3(1.1, 2.5, 1.1))
		instances.set_instance_transform(index, Transform3D(basis, Vector3(point.x, -2.95, point.y)))
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.2, 0.37, 0.35)
	stone.roughness = 0.95
	var visual := MultiMeshInstance3D.new()
	visual.name = "SyntyReefRidges"
	visual.multimesh = instances
	visual.material_override = stone
	add_child(visual)
	var structure_meshes := MultiMesh.new()
	structure_meshes.transform_format = MultiMesh.TRANSFORM_3D
	structure_meshes.mesh = source.mesh
	structure_meshes.instance_count = STRUCTURES.size() * 2 / 3
	var mound_meshes := MultiMesh.new()
	mound_meshes.transform_format = MultiMesh.TRANSFORM_3D
	mound_meshes.mesh = mound_source.mesh
	mound_meshes.instance_count = STRUCTURES.size() / 3
	var ridge_index := 0
	var mound_index := 0
	for index in STRUCTURES.size():
		var rock := STRUCTURES[index] as Vector4
		var width := 0.52 + float(index % 3) * 0.04
		var depth := 0.7 + float(index % 2) * 0.08
		var shelf_scale := structure_scale(index)
		if index % 3 == 2:
			var mound_basis := Basis(Vector3.UP, rock.z).scaled(Vector3(width * 4.2 * shelf_scale, rock.w * 2.2 * shelf_scale, depth * 2.1 * shelf_scale))
			mound_meshes.set_instance_transform(mound_index, Transform3D(mound_basis, Vector3(rock.x, -2.65, rock.y)))
			mound_index += 1
		else:
			var basis := Basis(Vector3.UP, rock.z).scaled(Vector3(width * shelf_scale, rock.w * shelf_scale, depth * shelf_scale))
			structure_meshes.set_instance_transform(ridge_index, Transform3D(basis, Vector3(rock.x, -2.65, rock.y)))
			ridge_index += 1
		var body := StaticBody3D.new()
		body.name = "ReefRock%02d" % (index + 1)
		body.position = Vector3(rock.x, -2.25, rock.y)
		body.rotation.y = rock.z
		add_child(body)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = Vector3((3.5 + float(index % 3) * 0.3) * shelf_scale, 1.8 * shelf_scale, (2.5 + float(index % 2) * 0.3) * shelf_scale)
		collision.shape = shape
		body.add_child(collision)
	var structures := MultiMeshInstance3D.new()
	structures.name = "StructuralReefRocks"
	structures.multimesh = structure_meshes
	structures.material_override = stone
	add_child(structures)
	var mounds := MultiMeshInstance3D.new()
	mounds.name = "StructuralReefMounds"
	mounds.multimesh = mound_meshes
	mounds.material_override = stone
	add_child(mounds)
	wrapper.free()
	mound_wrapper.free()
