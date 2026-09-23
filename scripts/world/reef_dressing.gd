extends Node3D

const RIDGE := preload("res://art/synty/wrappers/world_reef_ridge.tscn")
const POSITIONS := [
	Vector2(0.5, 95), Vector2(7.5, 91), Vector2(15.5, 98),
	Vector2(2, 137), Vector2(9.25, 142), Vector2(17, 132),
	Vector2(36.25, 110), Vector2(44, 106), Vector2(52.75, 112),
	Vector2(37, 153), Vector2(45.75, 154), Vector2(54.25, 142),
]


func _ready() -> void:
	var wrapper := RIDGE.instantiate() as Node3D
	var source := wrapper.get_node("Visual/Ridge") as MeshInstance3D
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
	wrapper.free()
