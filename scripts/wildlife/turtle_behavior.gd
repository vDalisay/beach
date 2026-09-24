class_name TurtleBehavior
extends Node

## Behaviour for a route turtle. It cruises its loop, surfaces every minute or two to
## breathe, now and then drops to the bottom to graze, and is friendly with swimmers: it
## often leaves the loop to swim alongside or just ahead of a nearby swimmer, watching
## them, then returns to where it left off. Its bubble trail speeds up a player swimming
## along it. Travel pulses with the animator's flipper strokes, so the turtle surges on
## each downstroke and slows while gliding.

enum Mode { ROUTE, COMPANION, BREATHE, GRAZE, RETURNING }
enum Breath { ASCEND, SURFACE }

const ENGAGE_RADIUS := 11.0
const RELEASE_RADIUS := 18.0
const ENGAGE_CHANCE := 0.6
const ENGAGE_CHECK_SECONDS := 1.2
const COMPANION_SECONDS := Vector2(16.0, 30.0)
const COOLDOWN_SECONDS := Vector2(3.0, 7.0)
const FIRST_BREATH_SECONDS := Vector2(20.0, 45.0)
const BREATH_INTERVAL := Vector2(60.0, 110.0)
const SURFACE_SECONDS := Vector2(2.5, 3.8)
const FIRST_GRAZE_SECONDS := Vector2(35.0, 70.0)
const GRAZE_INTERVAL := Vector2(70.0, 130.0)
const GRAZE_SECONDS := Vector2(8.0, 14.0)
# Plastron height above the bottom while feeding.
const GRAZE_CLEARANCE := 0.14
# Plastron depth that puts the head and nostrils just out of the water with the head raised.
const BREATHING_DEPTH := 0.16
const WATCH_RADIUS := 7.0
const PERSONAL_SPACE := 1.1
const ORBIT_RADIUS := 1.9
const LEAD_DISTANCE := 2.4
const TRAIL_SAMPLE_SECONDS := 0.1
const TRAIL_LIFETIME := 2.4
const TRAIL_MAX_POINTS := 24
const BOOST_RADIUS := 1.3
const BOOST_MULTIPLIER := 1.6
const BOOST_HOLD_SECONDS := 0.45

var session: RunSession
var route: PathAnimal
var animator: TurtleAnimator
var mode := Mode.ROUTE
var breath_phase := Breath.ASCEND
var trail: Array[Dictionary] = []
var _velocity := Vector3.ZERO
var _resume_mode := Mode.ROUTE
var _companion_left := 0.0
var _cooldown := 0.0
var _check_timer := 0.0
var _breath_timer := 0.0
var _surface_timer := 0.0
var _exhaled := false
var _graze_timer := 0.0
var _feed_timer := -1.0
var _feed_spot := Vector3.ZERO
var _look := 0.0
var _orbit_angle := 0.0
var _sample_timer := 0.0
var _last_sample := Vector3.INF
var _rng := RandomNumberGenerator.new()


func configure(run_session: RunSession, turtle_animator: TurtleAnimator) -> void:
	session = run_session
	animator = turtle_animator


func _ready() -> void:
	route = get_parent() as PathAnimal
	_rng.seed = hash(str(route.get_path()))
	_orbit_angle = _rng.randf() * TAU
	_breath_timer = _rng.randf_range(FIRST_BREATH_SECONDS.x, FIRST_BREATH_SECONDS.y)
	_graze_timer = _rng.randf_range(FIRST_GRAZE_SECONDS.x, FIRST_GRAZE_SECONDS.y)


func _process(delta: float) -> void:
	if delta <= 0.0 or animator == null or not route.is_visible_in_tree():
		return
	# Travel along the route pulses with the stroke rhythm (and pauses while crawling turtles rest).
	route.speed_scale = animator.surge
	var swim: SwimService = session.swim_service if session != null else null
	if swim == null or swim.water == null:
		return
	var water := swim.water
	animator.water_surface_y = water.surface_y
	var here := route.global_position
	var in_water := water.contains_horizontal(here) and here.y < water.surface_y - 0.1
	var player: BeachPlayer = swim.player if is_instance_valid(swim.player) else null
	var player_in_water := player != null and player.movement.is_swimming and player.input_enabled
	var swimmer := player.global_position + Vector3.UP * 0.9 if player != null else Vector3.INF
	var distance := here.distance_to(swimmer) if player != null else INF
	_cooldown = maxf(0.0, _cooldown - delta)
	if route.looping and in_water:
		_breath_timer -= delta
		_graze_timer -= delta
	match mode:
		Mode.ROUTE:
			_check_timer -= delta
			if route.looping and in_water and _breath_timer <= 0.0:
				_begin_breath(Mode.ROUTE)
			elif route.looping and in_water and _graze_timer <= 0.0:
				_begin_graze()
			elif route.looping and in_water and player_in_water and _cooldown <= 0.0 and distance < ENGAGE_RADIUS and _check_timer <= 0.0:
				_check_timer = ENGAGE_CHECK_SECONDS
				if _rng.randf() < ENGAGE_CHANCE:
					begin_companion()
		Mode.COMPANION:
			_companion_left -= delta
			if _breath_timer <= 0.0:
				_begin_breath(Mode.COMPANION)
			elif _companion_left <= 0.0 or not player_in_water or distance > RELEASE_RADIUS:
				mode = Mode.RETURNING
			else:
				# Match the swimmer's velocity so a boosted player trails the turtle instead of overtaking it.
				var cruise := maxf(3.2, player.movement.swim_speed * BOOST_MULTIPLIER + 0.8)
				_swim_toward(_companion_target(player, swimmer, water, delta), cruise, delta, player.velocity, swimmer)
		Mode.BREATHE:
			_breathe(water, delta, player_in_water and distance < RELEASE_RADIUS, swimmer)
		Mode.GRAZE:
			_graze(delta, swimmer)
		Mode.RETURNING:
			var home := (route.get_parent() as Node3D).to_global(route.route_position())
			if here.distance_to(home) < 0.25:
				route.position = route.route_position()
				_velocity = Vector3.ZERO
				mode = Mode.ROUTE
				_cooldown = _rng.randf_range(COOLDOWN_SECONDS.x, COOLDOWN_SECONDS.y)
				route.resume_route()
			else:
				_swim_toward(home, 1.4, delta, Vector3.ZERO, swimmer)
	# Friendly curiosity: a turtle watches a nearby swimmer.
	var watching := player_in_water and distance < WATCH_RADIUS and breath_phase != Breath.SURFACE
	_look = move_toward(_look, 1.0 if watching else 0.0, delta * 1.5)
	animator.look_weight = _look
	if player != null:
		animator.look_target = player.camera.global_position
	_update_trail(water, delta)
	if player_in_water:
		_apply_trail_boost(player)


func begin_companion() -> void:
	if mode != Mode.ROUTE:
		return
	route.pause_route()
	_companion_left = _rng.randf_range(COMPANION_SECONDS.x, COMPANION_SECONDS.y)
	_velocity = Vector3.ZERO
	mode = Mode.COMPANION


func _begin_breath(resume: Mode) -> void:
	route.pause_route()
	_resume_mode = resume
	mode = Mode.BREATHE
	breath_phase = Breath.ASCEND
	_exhaled = false


func _breathe(water: WaterVolume, delta: float, player_nearby: bool, swimmer: Vector3) -> void:
	var here := route.global_position
	var breathing_y := water.surface_y - BREATHING_DEPTH
	if breath_phase == Breath.ASCEND:
		# Swim up at an angle, still heading the way it was going.
		var ahead := route.global_basis.z
		ahead.y = 0.0
		var target := water.clamp_inside(here + ahead.normalized() * 1.6, 1.0)
		target.y = breathing_y
		_swim_toward(target, 0.9, delta, Vector3.ZERO, swimmer)
		if not _exhaled and here.y > water.surface_y - 0.7:
			# Turtles breathe out on the way up; the bubbles break at the surface.
			animator.exhale()
			_exhaled = true
		if absf(here.y - breathing_y) < 0.08:
			breath_phase = Breath.SURFACE
			_surface_timer = _rng.randf_range(SURFACE_SECONDS.x, SURFACE_SECONDS.y)
			animator.breathing = true
		return
	# At the surface: hold still with the head up, drifting a little.
	_surface_timer -= delta
	_swim_toward(Vector3(here.x, breathing_y, here.z), 0.3, delta, Vector3.ZERO, swimmer)
	if _surface_timer > 0.0:
		return
	animator.breathing = false
	breath_phase = Breath.ASCEND
	_breath_timer = _rng.randf_range(BREATH_INTERVAL.x, BREATH_INTERVAL.y)
	mode = Mode.COMPANION if _resume_mode == Mode.COMPANION and player_nearby and _companion_left > 0.0 else Mode.RETURNING


func _begin_graze() -> void:
	_graze_timer = _rng.randf_range(GRAZE_INTERVAL.x, GRAZE_INTERVAL.y)
	# Find the real bottom (sand or reef rock) a little ahead of the turtle.
	var ahead := route.global_basis.z
	ahead.y = 0.0
	var above := route.global_position + ahead.normalized() * 1.0
	var query := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 6.0, 1)
	var hit := route.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	route.pause_route()
	_feed_spot = (hit.position as Vector3) + Vector3.UP * GRAZE_CLEARANCE
	_feed_timer = -1.0
	mode = Mode.GRAZE


func _graze(delta: float, swimmer: Vector3) -> void:
	if _feed_timer < 0.0:
		# Glide down to the bottom.
		_swim_toward(_feed_spot, 0.7, delta, Vector3.ZERO, swimmer)
		if route.global_position.distance_to(_feed_spot) < 0.12:
			_feed_timer = _rng.randf_range(GRAZE_SECONDS.x, GRAZE_SECONDS.y)
			animator.grazing = true
		return
	# Feeding: hold station just above the bottom while the head nibbles.
	_feed_timer -= delta
	_swim_toward(_feed_spot, 0.2, delta, Vector3.ZERO, swimmer)
	if _feed_timer <= 0.0:
		animator.grazing = false
		mode = Mode.RETURNING


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


func _swim_toward(target: Vector3, max_speed: float, delta: float, carry: Vector3, swimmer: Vector3) -> void:
	var here := route.global_position
	# Arrive smoothly instead of overshooting, never faster than the current stroke allows.
	var desired := carry + (target - here) * 1.6
	if swimmer != Vector3.INF and here.distance_to(swimmer) < PERSONAL_SPACE:
		# Keep clear of the swimmer's body and camera.
		desired += (here - swimmer).normalized() * 1.5
	desired = desired.limit_length(max_speed * maxf(animator.surge, 0.35))
	_velocity = _velocity.move_toward(desired, 3.0 * delta)
	route.global_position = here + _velocity * delta


func _update_trail(water: WaterVolume, delta: float) -> void:
	for point in trail:
		point.age = float(point.age) + delta
	while not trail.is_empty() and float(trail[0].age) > TRAIL_LIFETIME:
		trail.pop_front()
	var here := route.global_position
	var submerged := water.contains_horizontal(here) and here.y < water.surface_y - 0.15
	animator.trail_bubbles = submerged
	_sample_timer -= delta
	if _sample_timer > 0.0 or not submerged:
		return
	_sample_timer = TRAIL_SAMPLE_SECONDS
	if _last_sample == Vector3.INF or _last_sample.distance_squared_to(here) > 0.01:
		var direction := (here - _last_sample).normalized() if _last_sample != Vector3.INF else Vector3.ZERO
		# Bubbles stream off the back of the shell rather than the turtle's centre.
		var origin := here - direction * 0.35 + Vector3.UP * 0.08
		trail.append({"position": origin, "direction": direction, "age": 0.0})
		if trail.size() > TRAIL_MAX_POINTS:
			trail.pop_front()
		animator.bubbles.burst(origin, -direction, _rng.randi_range(1, 2), 0.12, 0.05, Vector2(0.006, 0.014), TRAIL_LIFETIME)
	_last_sample = here


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
