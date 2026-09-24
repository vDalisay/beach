class_name FishSchool
extends Node3D

## Fish flock with boids (separation, alignment, cohesion). The route mover is an
## invisible leader the flock seeks, so the school still follows its restored loop.

const FISH_COUNT := 9
const NEIGHBOR_RADIUS := 1.6
const SEPARATION_RADIUS := 0.55
const PLAYER_FLEE_RADIUS := 2.6
const SIMULATION_RANGE := 60.0
const SEPARATION_WEIGHT := 2.4
const ALIGNMENT_WEIGHT := 1.0
const COHESION_WEIGHT := 0.9
const SEEK_WEIGHT := 1.1
const FLEE_WEIGHT := 5.0
const SURFACE_WEIGHT := 4.0

static var _body_mesh: SphereMesh
static var _tail_mesh: CylinderMesh
static var _materials: Array[StandardMaterial3D] = []

var school_id: StringName
var mover: PathAnimal
var session: RunSession
var fish: Array[Node3D] = []
var velocities: Array[Vector3] = []
var max_speed := 2.4
var min_speed := 0.7
var max_force := 4.0
var reduced_motion := false
var _phases: Array[float] = []
var _time := 0.0


func _ready() -> void:
	_prepare_shared_assets()
	mover = PathAnimal.new()
	mover.name = "Route"
	add_child(mover)
	for index in range(FISH_COUNT):
		var member := Node3D.new()
		member.name = "Fish_%02d" % (index + 1)
		# Loose ball around the leader; boids spread it into a school on the first frames.
		var angle := float(index) * 2.399963
		member.position = Vector3(cos(angle), 0.0, sin(angle)) * (0.3 + 0.12 * index) + Vector3.UP * ((index % 3) - 1) * 0.18
		member.scale = Vector3.ONE * (0.8 + (index % 4) * 0.09)
		add_child(member)
		var body := MeshInstance3D.new()
		body.name = "Body"
		body.mesh = _body_mesh
		body.material_override = _materials[index % _materials.size()]
		body.visibility_range_end = 55.0
		body.scale = Vector3(1.5, 0.7, 0.75)
		member.add_child(body)
		var tail := MeshInstance3D.new()
		tail.name = "Tail"
		tail.mesh = _tail_mesh
		tail.material_override = body.material_override
		tail.visibility_range_end = 55.0
		tail.position.x = -0.25
		tail.rotation.z = PI * 0.5
		member.add_child(tail)
		fish.append(member)
		velocities.append(Vector3(cos(angle + PI * 0.5), 0.0, sin(angle + PI * 0.5)) * min_speed)
		_phases.append(float(index) * 1.7)
		_orient(index, 1.0)


func configure(id: StringName, points: Array[Vector3], reduce_motion := false) -> void:
	school_id = id
	reduced_motion = reduce_motion
	max_speed = 1.5 if reduced_motion else 2.4
	min_speed = 0.5 if reduced_motion else 0.7
	mover.configure(id, [], points, 1.0 if reduced_motion else 1.7, reduced_motion)


func start_school() -> void:
	mover.resume_loop()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or delta <= 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_squared_to(global_position + mover.position) > SIMULATION_RANGE * SIMULATION_RANGE:
		return
	_time += delta
	step_flock(minf(delta, 0.05))


func step_flock(delta: float) -> void:
	var threat := Vector3.INF
	var surface_local := INF
	if session != null and session.swim_service != null and is_instance_valid(session.swim_service.player):
		var player := session.swim_service.player
		threat = to_local(player.global_position + Vector3.UP * 0.9)
		surface_local = session.swim_service.water.surface_y - 0.3 - global_position.y
	var goal := mover.position
	var count := fish.size()
	var steering: Array[Vector3] = []
	steering.resize(count)
	for i in range(count):
		var position_i := fish[i].position
		var separation := Vector3.ZERO
		var alignment := Vector3.ZERO
		var center := Vector3.ZERO
		var neighbors := 0
		for j in range(count):
			if i == j:
				continue
			var offset := position_i - fish[j].position
			var distance_squared := offset.length_squared()
			if distance_squared > NEIGHBOR_RADIUS * NEIGHBOR_RADIUS:
				continue
			neighbors += 1
			alignment += velocities[j]
			center += fish[j].position
			if distance_squared < SEPARATION_RADIUS * SEPARATION_RADIUS:
				separation += offset / maxf(distance_squared, 0.0025)
		var force := Vector3.ZERO
		if neighbors > 0:
			force += _steer(i, separation) * SEPARATION_WEIGHT
			force += _steer(i, alignment / neighbors) * ALIGNMENT_WEIGHT
			force += _steer(i, center / neighbors - position_i) * COHESION_WEIGHT
		# The leader pull grows with distance so the school drifts loosely around the route.
		var to_goal := goal - position_i
		force += _steer(i, to_goal) * SEEK_WEIGHT * clampf(to_goal.length() / 1.5, 0.3, 2.5)
		if threat != Vector3.INF:
			var away := position_i - threat
			var threat_distance := away.length()
			if threat_distance < PLAYER_FLEE_RADIUS:
				force += _steer(i, away) * FLEE_WEIGHT * (1.0 - threat_distance / PLAYER_FLEE_RADIUS)
		if position_i.y > surface_local:
			force += Vector3.DOWN * max_force * SURFACE_WEIGHT
		steering[i] = force.limit_length(max_force * 2.0)
	for i in range(count):
		var velocity := velocities[i] + steering[i] * delta
		var speed := velocity.length()
		if speed > max_speed:
			velocity = velocity / speed * max_speed
		elif speed < min_speed:
			velocity = (velocity / speed if speed > 0.0001 else Vector3.RIGHT) * min_speed
		# Fish mostly school on a plane; damp vertical drift so they do not corkscrew.
		velocity.y *= 0.96
		velocities[i] = velocity
		fish[i].position += velocity * delta
		_orient(i, delta)


func _steer(index: int, desired: Vector3) -> Vector3:
	if desired.length_squared() < 0.000001:
		return Vector3.ZERO
	return (desired.normalized() * max_speed - velocities[index]).limit_length(max_force)


func _orient(index: int, delta: float) -> void:
	var velocity := velocities[index]
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal < 0.0001:
		return
	var member := fish[index]
	# Fish meshes face local +X; yaw so +X follows velocity, then pitch with the climb.
	var yaw := atan2(velocity.x, velocity.z) - PI * 0.5
	member.rotation.y = lerp_angle(member.rotation.y, yaw, minf(delta * 8.0, 1.0))
	member.rotation.z = lerpf(member.rotation.z, clampf(atan2(velocity.y, horizontal), -0.6, 0.6), minf(delta * 6.0, 1.0))
	if not reduced_motion:
		(member.get_node("Tail") as Node3D).rotation.y = sin(_time * 12.0 + _phases[index]) * 0.45


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
