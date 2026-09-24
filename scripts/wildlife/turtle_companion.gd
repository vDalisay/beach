class_name TurtleCompanion
extends Node3D

## Makes a looping turtle route friendly: it often leaves its loop to swim with a nearby
## swimmer, and it leaves a short bubble trail that speeds up a player following it.

enum Mode { ROUTE, COMPANION, RETURNING }

const ENGAGE_RADIUS := 11.0
const RELEASE_RADIUS := 18.0
const ENGAGE_CHANCE := 0.6
const ENGAGE_CHECK_SECONDS := 1.2
const COMPANION_SECONDS := Vector2(16.0, 30.0)
const COOLDOWN_SECONDS := Vector2(3.0, 7.0)
const ORBIT_RADIUS := 1.9
const LEAD_DISTANCE := 2.4
const TRAIL_SAMPLE_SECONDS := 0.1
const TRAIL_LIFETIME := 2.4
const TRAIL_MAX_POINTS := 24
const BUBBLES_PER_POINT := 3
const BOOST_RADIUS := 1.3
const BOOST_MULTIPLIER := 1.6
const BOOST_HOLD_SECONDS := 0.45

var session: RunSession
var route: PathAnimal
var mode := Mode.ROUTE
var trail: Array[Dictionary] = []
var _velocity := Vector3.ZERO
var _return_point := Vector3.ZERO
var _companion_left := 0.0
var _cooldown := 0.0
var _check_timer := 0.0
var _orbit_angle := 0.0
var _sample_timer := 0.0
var _last_sample := Vector3.INF
var _bubbles: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()


func configure(run_session: RunSession) -> void:
	session = run_session


func _ready() -> void:
	route = get_parent() as PathAnimal
	_rng.seed = hash(route.name + str(route.get_path()))
	_orbit_angle = _rng.randf() * TAU
	_bubbles = MultiMeshInstance3D.new()
	_bubbles.name = "BubbleTrail"
	_bubbles.top_level = true
	_bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.86, 0.97, 1.0, 0.55)
	material.emission_enabled = true
	material.emission = Color(0.55, 0.85, 0.95)
	material.emission_energy_multiplier = 0.5
	material.roughness = 0.05
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = TRAIL_MAX_POINTS * BUBBLES_PER_POINT
	multimesh.visible_instance_count = 0
	_bubbles.multimesh = multimesh
	add_child(_bubbles)
	_bubbles.global_transform = Transform3D.IDENTITY


func _physics_process(delta: float) -> void:
	if session == null or session.swim_service == null or not route.is_visible_in_tree() or not route.looping:
		return
	var swim := session.swim_service
	var player := swim.player
	if not is_instance_valid(player):
		return
	var swimmer := player.global_position + Vector3.UP * 0.9
	var distance := route.global_position.distance_to(swimmer)
	var player_in_water := player.movement.is_swimming and player.input_enabled
	_cooldown = maxf(0.0, _cooldown - delta)
	match mode:
		Mode.ROUTE:
			_check_timer -= delta
			if player_in_water and _cooldown <= 0.0 and distance < ENGAGE_RADIUS and _check_timer <= 0.0:
				_check_timer = ENGAGE_CHECK_SECONDS
				if _rng.randf() < ENGAGE_CHANCE:
					begin_companion()
		Mode.COMPANION:
			_companion_left -= delta
			if _companion_left <= 0.0 or not player_in_water or distance > RELEASE_RADIUS:
				mode = Mode.RETURNING
			else:
				# Match the swimmer's velocity so a boosted player trails the turtle instead of overtaking it.
				_swim_toward(_companion_target(player, swimmer, swim.water, delta), maxf(3.2, player.movement.swim_speed * BOOST_MULTIPLIER + 0.8), delta, player.velocity)
		Mode.RETURNING:
			var home := (route.get_parent() as Node3D).to_global(_return_point)
			if route.global_position.distance_to(home) < 0.25:
				route.position = _return_point
				_velocity = Vector3.ZERO
				mode = Mode.ROUTE
				_cooldown = _rng.randf_range(COOLDOWN_SECONDS.x, COOLDOWN_SECONDS.y)
				route.resume_route()
			else:
				_swim_toward(home, 2.6, delta)
	_update_trail(swim.water, delta)
	if player_in_water:
		_apply_trail_boost(player)


func begin_companion() -> void:
	if mode != Mode.ROUTE:
		return
	route.pause_route()
	_return_point = route.position
	_companion_left = _rng.randf_range(COMPANION_SECONDS.x, COMPANION_SECONDS.y)
	_velocity = Vector3.ZERO
	mode = Mode.COMPANION


func _companion_target(player: BeachPlayer, swimmer: Vector3, water: WaterVolume, delta: float) -> Vector3:
	var player_velocity := player.velocity
	var target: Vector3
	if player_velocity.length() > 0.6:
		# Lead a little ahead of a moving swimmer so its bubble trail lies on their path.
		var heading := player_velocity.normalized()
		var side := heading.cross(Vector3.UP).normalized() if absf(heading.y) < 0.95 else Vector3.RIGHT
		target = swimmer + heading * LEAD_DISTANCE + side * sin(Time.get_ticks_msec() * 0.0012) * 0.5
	else:
		_orbit_angle = wrapf(_orbit_angle + delta * 0.55, 0.0, TAU)
		target = swimmer + Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * ORBIT_RADIUS + Vector3.UP * sin(_orbit_angle * 2.0) * 0.25
	target = water.clamp_inside(target, 1.0)
	target.y = clampf(target.y, maxf(water.seabed_y + 0.4, player.global_position.y + 0.3), water.surface_y - 0.35)
	if not water.contains_horizontal(target):
		target = Vector3(swimmer.x, target.y, swimmer.z)
	return target


func _swim_toward(target: Vector3, max_speed: float, delta: float, carry := Vector3.ZERO) -> void:
	# Arrive smoothly instead of overshooting and circling the target.
	var desired := (carry + (target - route.global_position) * 1.6).limit_length(max_speed)
	_velocity = _velocity.move_toward(desired, 6.0 * delta)
	route.global_position += _velocity * delta


func _update_trail(water: WaterVolume, delta: float) -> void:
	for point in trail:
		point.age = float(point.age) + delta
	while not trail.is_empty() and float(trail[0].age) > TRAIL_LIFETIME:
		trail.pop_front()
	_sample_timer -= delta
	var here := route.global_position
	var submerged := water.contains_horizontal(here) and here.y < water.surface_y - 0.15
	if _sample_timer <= 0.0 and submerged:
		_sample_timer = TRAIL_SAMPLE_SECONDS
		if _last_sample == Vector3.INF or _last_sample.distance_squared_to(here) > 0.01:
			var direction := (here - _last_sample).normalized() if _last_sample != Vector3.INF else Vector3.ZERO
			# Bubbles stream off the back of the shell rather than the turtle's centre.
			var origin := here - direction * 0.35 + Vector3.UP * 0.08
			trail.append({"position": origin, "direction": direction, "age": 0.0, "seed": _rng.randf() * TAU})
			if trail.size() > TRAIL_MAX_POINTS:
				trail.pop_front()
		_last_sample = here
	_draw_trail(water)


func _draw_trail(water: WaterVolume) -> void:
	var multimesh := _bubbles.multimesh
	var index := 0
	for point in trail:
		var age := float(point.age)
		var life := age / TRAIL_LIFETIME
		var origin := point.position as Vector3
		var phase_seed := float(point.seed)
		for bubble in range(BUBBLES_PER_POINT):
			var phase := phase_seed + bubble * 2.1
			var rise := age * (0.35 + 0.15 * bubble)
			var drift := Vector3(sin(phase + age * 3.0), 0.0, cos(phase * 1.3 + age * 2.5)) * (0.06 + 0.05 * bubble)
			var bubble_position := origin + drift + Vector3.UP * rise
			bubble_position.y = minf(bubble_position.y, water.surface_y - 0.05)
			var size := (0.55 + 0.35 * sin(phase)) * (1.0 - life * 0.7) * (0.6 + life * 0.4 if bubble == 0 else 1.0)
			multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * maxf(size, 0.05)), bubble_position))
			index += 1
	multimesh.visible_instance_count = index


func _apply_trail_boost(player: BeachPlayer) -> void:
	if trail.is_empty():
		return
	var chest := player.global_position + Vector3.UP * 0.9
	var heading := player.velocity
	for point in trail:
		if (point.position as Vector3).distance_squared_to(chest) > BOOST_RADIUS * BOOST_RADIUS:
			continue
		var direction := point.direction as Vector3
		# Only a swimmer travelling with the trail rides it; crossing or swimming against it does nothing.
		if heading.length() > 0.5 and (direction == Vector3.ZERO or heading.normalized().dot(direction) > 0.3):
			player.movement.apply_swim_boost(BOOST_MULTIPLIER, BOOST_HOLD_SECONDS)
			return
