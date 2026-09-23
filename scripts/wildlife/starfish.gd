class_name Starfish
extends Node3D

static var _arm_mesh: CylinderMesh
static var _center_mesh: SphereMesh
static var _material: StandardMaterial3D


func _ready() -> void:
	if _arm_mesh == null:
		_arm_mesh = CylinderMesh.new()
		_arm_mesh.top_radius = 0.0
		_arm_mesh.bottom_radius = 0.12
		_arm_mesh.height = 0.42
		_center_mesh = SphereMesh.new()
		_center_mesh.radius = 0.15
		_center_mesh.height = 0.12
		_center_mesh.radial_segments = 10
		_center_mesh.rings = 5
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color("e88962")
	var center := MeshInstance3D.new()
	center.mesh = _center_mesh
	center.material_override = _material
	add_child(center)
	for index in range(5):
		var arm := MeshInstance3D.new()
		arm.mesh = _arm_mesh
		arm.material_override = _material
		arm.rotation.z = PI * 0.5
		arm.rotation.y = index * TAU / 5.0
		arm.position = Vector3(cos(index * TAU / 5.0) * 0.18, 0, sin(index * TAU / 5.0) * 0.18)
		add_child(arm)
