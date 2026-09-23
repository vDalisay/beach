extends Node3D


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.56, 0.48)
	material.roughness = 0.82
	for index in range(-3, 4):
		_add_strand(material, Vector3(float(index) * 0.1, 0, 0), Vector3(0.0, 0.0, 0.72))
		_add_strand(material, Vector3(0, 0, float(index) * 0.1), Vector3(0.72, 0.0, 0.0))


func _add_strand(material: Material, center: Vector3, direction: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.008
	mesh.bottom_radius = 0.008
	mesh.height = direction.length()
	mesh.radial_segments = 6
	mesh.material = material
	var strand := MeshInstance3D.new()
	strand.mesh = mesh
	strand.position = center
	strand.quaternion = Quaternion(Vector3.UP, direction.normalized())
	add_child(strand)
