class_name WaterVolume
extends Area3D
const Coastline = preload("res://scripts/world/coastline.gd")

@export var surface_y := 0.08
@export var seabed_y := -3.0
@export var swim_depth := 0.55
@onready var collision_shape: CollisionShape3D = $Collision


func contains_horizontal(world_point: Vector3) -> bool:
	var shape := collision_shape.shape as BoxShape3D
	var point := to_local(world_point)
	return absf(point.x) <= shape.size.x * 0.5 and absf(point.z) <= shape.size.z * 0.5 and world_point.z >= Coastline.shore_z(world_point.x)


func clamp_inside(world_point: Vector3, margin: float) -> Vector3:
	var shape := collision_shape.shape as BoxShape3D
	var point := to_local(world_point)
	point.x = clampf(point.x, -shape.size.x * 0.5 + margin, shape.size.x * 0.5 - margin)
	point.z = clampf(point.z, -shape.size.z * 0.5 + margin, shape.size.z * 0.5 - margin)
	return to_global(point)


func should_swim(feet: Vector3) -> bool:
	return contains_horizontal(feet) and feet.y < surface_y - swim_depth


func head_submerged(eye: Vector3, was_submerged: bool) -> bool:
	if not contains_horizontal(eye):
		return false
	return eye.y < surface_y + (0.08 if was_submerged else -0.12)
