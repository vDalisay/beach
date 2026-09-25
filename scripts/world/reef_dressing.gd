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
# One restoration-garden point per this many square metres of upward-facing rock.
const GARDEN_AREA := 0.42


## Rocks the provisional seagrass beds grow beside, per reef section (RestorationSection draws
## them); reef litter keeps clear of the beds as it does of the rocks.
const SEAGRASS_ROCKS := {
	&"reef_west:outer": [0, 1, 3, 4],
	&"reef_west:coral": [2, 5, 6, 7, 8],
	&"reef_east:outer": [9, 12, 16],
	&"reef_east:coral": [11, 13, 14, 17],
}
## Litter keeps this far (m) from a seagrass bed centre.
const SEAGRASS_CLEARANCE := 1.0


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
	var garden_points := {}
	for index in POSITIONS.size():
		var point := POSITIONS[index] as Vector2
		var basis := Basis(Vector3.UP, float(index) * 1.37).scaled(Vector3(1.1, 2.5, 1.1))
		var ridge_pose := Transform3D(basis, Vector3(point.x, -2.95, point.y))
		instances.set_instance_transform(index, ridge_pose)
		garden_points[100 + index] = _garden_points(source.mesh, ridge_pose, 100 + index)
	var stone := preload("res://shaders/seabed_caustics.tres")
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
	var habitat_anchors := {}
	var ridge_index := 0
	var mound_index := 0
	for index in STRUCTURES.size():
		var rock := STRUCTURES[index] as Vector4
		var width := 0.52 + float(index % 3) * 0.04
		var depth := 0.7 + float(index % 2) * 0.08
		var shelf_scale := structure_scale(index)
		var visual_pose: Transform3D
		var habitat_mesh: Mesh
		if index % 3 == 2:
			var mound_basis := Basis(Vector3.UP, rock.z).scaled(Vector3(width * 4.2 * shelf_scale, rock.w * 2.2 * shelf_scale, depth * 2.1 * shelf_scale))
			visual_pose = Transform3D(mound_basis, Vector3(rock.x, -2.65, rock.y))
			habitat_mesh = mound_source.mesh
			mound_meshes.set_instance_transform(mound_index, visual_pose)
			mound_index += 1
		else:
			var basis := Basis(Vector3.UP, rock.z).scaled(Vector3(width * shelf_scale, rock.w * shelf_scale, depth * shelf_scale))
			visual_pose = Transform3D(basis, Vector3(rock.x, -2.65, rock.y))
			habitat_mesh = source.mesh
			structure_meshes.set_instance_transform(ridge_index, visual_pose)
			ridge_index += 1
		habitat_anchors[index] = _surface_anchors(habitat_mesh, visual_pose)
		garden_points[index] = _garden_points(habitat_mesh, visual_pose, index)
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
	# Composition anchors follow rendered rock faces, not the simplified collision boxes.
	set_meta(&"reef_habitat_anchors", habitat_anchors)
	# Structures keep their index; background ridges are 100 + their index.
	set_meta(&"reef_garden_points", garden_points)
	wrapper.free()
	mound_wrapper.free()


func _surface_anchors(mesh: Mesh, pose: Transform3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var faces := mesh.get_faces()
	var size := mesh.get_aabb().size
	for offset in [Vector2(-0.23, 0.06), Vector2(0.04, -0.12), Vector2(0.26, 0.10)]:
		var origin := Vector3(offset.x * size.x, 10.0, offset.y * size.z)
		var highest := Vector3(origin.x, -INF, origin.z)
		for triangle in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN, faces[triangle], faces[triangle + 1], faces[triangle + 2])
			if hit is Vector3 and hit.y > highest.y:
				highest = hit
		if is_finite(highest.y):
			result.append(pose * highest)
	return result


## Random points on the rock's upward-facing rendered faces (xyz, with the face normal's y).
func _garden_points(mesh: Mesh, pose: Transform3D, seed_value: int) -> Array[Vector4]:
	var result: Array[Vector4] = []
	var faces := mesh.get_faces()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value * 7919 + 17
	for triangle in range(0, faces.size(), 3):
		var a := pose * faces[triangle]
		var b := pose * faces[triangle + 1]
		var c := pose * faces[triangle + 2]
		# Front faces wind clockwise, so this normal points out of the rock.
		var normal := (c - a).cross(b - a)
		var area := normal.length() * 0.5
		if area < 0.001:
			continue
		normal /= area * 2.0
		if normal.y < 0.45:
			continue
		for sample in int(area / GARDEN_AREA + random.randf()):
			var u := random.randf()
			var v := random.randf()
			if u + v > 1.0:
				u = 1.0 - u
				v = 1.0 - v
			var point := a + (b - a) * u + (c - a) * v
			result.append(Vector4(point.x, point.y, point.z, normal.y))
	return result


## Where the seagrass bed beside `rock_index` grows (x, z): off the rock's side facing away from
## the swim channel, beyond the ridge visual.
static func seagrass_spot(section_id: StringName, rock_index: int) -> Vector2:
	var rock := STRUCTURES[rock_index] as Vector4
	# The Synty ridge visual extends farther than its pickup-safe collider.
	var clearance := 4.5 * (0.52 + float(rock_index % 3) * 0.04) * structure_scale(rock_index) + 0.5
	var channel_x := 2.5 if str(section_id).begins_with("reef_west") else 40.0
	var side := -1.0 if rock.x > channel_x else 1.0
	var local_direction := Vector3(side, 0, 0)
	# These two beds turn toward open seabed.
	if rock_index == 0:
		local_direction = Vector3.BACK
	elif rock_index == 1:
		local_direction = Vector3.FORWARD
	var offset := Basis(Vector3.UP, rock.z) * local_direction * clearance
	return Vector2(rock.x + offset.x, rock.y + offset.z)


static var _seagrass_spots: PackedVector2Array = PackedVector2Array()


static func near_seagrass(position_mm: Array) -> bool:
	if _seagrass_spots.is_empty():
		for section_id in SEAGRASS_ROCKS:
			for rock_index in SEAGRASS_ROCKS[section_id]:
				_seagrass_spots.append(seagrass_spot(section_id, int(rock_index)))
	var point := Vector2(float(position_mm[0]), float(position_mm[2])) / 1000.0
	for spot in _seagrass_spots:
		if point.distance_to(spot) < SEAGRASS_CLEARANCE:
			return true
	return false
