class_name FishSchool
extends Node3D

const FISH_COUNT := 6
const SPECIES := [
	"res://art/models/fish_blue_tang.glb",
	"res://art/models/fish_blue_tang.glb",
	"res://art/models/fish_yellow_tang.glb",
	"res://art/models/fish_clown.glb",
]

var school_id: StringName
var mover: PathAnimal
var _bodies: Array[MeshInstance3D] = []
var _phase := 0.0


func _ready() -> void:
	mover = PathAnimal.new()
	mover.name = "Route"
	add_child(mover)
	# One species per school, chosen from the school's stable node name.
	var species := ModelLibrary.mesh(SPECIES[absi(str(name).hash()) % SPECIES.size()])
	for index in range(FISH_COUNT):
		var fish := Node3D.new()
		fish.name = "Fish_%02d" % (index + 1)
		fish.position = Vector3((index % 2) * 0.55 + (index / 4) * 0.25, (index / 2) * 0.18 - 0.1, (index % 3) * 0.35)
		fish.rotation.y = -PI * 0.5
		fish.scale = Vector3.ONE * (1.25 + (index % 3) * 0.15)
		mover.add_child(fish)
		var body := MeshInstance3D.new()
		body.name = "Body"
		body.mesh = species
		# The model's head faces -Z; the Fish node swims along its +X.
		body.rotation.y = -PI * 0.5
		body.visibility_range_end = 55.0
		fish.add_child(body)
		_bodies.append(body)
	_phase = float(absi(str(name).hash()) % 100) * 0.1


func _process(delta: float) -> void:
	_phase += delta * 6.0
	for index in _bodies.size():
		_bodies[index].rotation.y = -PI * 0.5 + sin(_phase + float(index) * 1.3) * 0.12


func configure(id: StringName, points: Array[Vector3], reduced_motion := false) -> void:
	school_id = id
	mover.configure(id, [], points, 1.0 if reduced_motion else 1.7, reduced_motion)


func start_school() -> void:
	mover.resume_loop()
