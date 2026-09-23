class_name FishSchool
extends Node3D

const FISH_COUNT := 4

static var _body_mesh: SphereMesh
static var _tail_mesh: CylinderMesh
static var _materials: Array[StandardMaterial3D] = []

var school_id: StringName
var mover: PathAnimal


func _ready() -> void:
	_prepare_shared_assets()
	mover = PathAnimal.new()
	mover.name = "Route"
	add_child(mover)
	for index in range(FISH_COUNT):
		var fish := Node3D.new()
		fish.name = "Fish_%02d" % (index + 1)
		fish.position = Vector3((index % 2) * 0.55, (index / 2) * 0.18, (index % 3) * 0.35)
		fish.rotation.y = -PI * 0.5
		fish.scale = Vector3.ONE * (0.8 + index * 0.09)
		mover.add_child(fish)
		var body := MeshInstance3D.new()
		body.name = "Body"
		body.mesh = _body_mesh
		body.material_override = _materials[index % _materials.size()]
		body.visibility_range_end = 55.0
		body.scale = Vector3(1.5, 0.7, 0.75)
		fish.add_child(body)
		var tail := MeshInstance3D.new()
		tail.name = "Tail"
		tail.mesh = _tail_mesh
		tail.material_override = body.material_override
		tail.visibility_range_end = 55.0
		tail.position.x = -0.25
		tail.rotation.z = PI * 0.5
		fish.add_child(tail)


func configure(id: StringName, points: Array[Vector3], reduced_motion := false) -> void:
	school_id = id
	mover.configure(id, [], points, 1.0 if reduced_motion else 1.7, reduced_motion)


func start_school() -> void:
	mover.resume_loop()


func _prepare_shared_assets() -> void:
	if _body_mesh != null:
		return
	_body_mesh = SphereMesh.new()
	_body_mesh.radius = 0.18
	_body_mesh.height = 0.27
	_body_mesh.radial_segments = 10
	_body_mesh.rings = 5
	_tail_mesh = CylinderMesh.new()
	_tail_mesh.top_radius = 0.0
	_tail_mesh.bottom_radius = 0.14
	_tail_mesh.height = 0.22
	for color in [Color("528ed1"), Color("dcb866"), Color("5eabc0"), Color("b0d3da")]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.75
		_materials.append(material)
