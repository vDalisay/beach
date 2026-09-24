class_name ViewmodelAnimator
extends Node
## Procedural first-person motion: locomotion sway, one-shot arm clips, tool activity and the
## bag's fill spring. HandRig composes the result into the visual layer every frame; gameplay
## sockets, the camera and every gameplay state stay untouched.
## Clips are sampled here (not SceneTree tweens) so a cue raised during physics shows in the
## very next rendered frame.

const FEEL := preload("res://data/feel/feel_tuning.tres")
const E := 2.718281828
## Arm pivots ("elbows") in rig space; clip rotations swing hands and tools about these.
const PIVOTS := {&"left": Vector3(-0.3, -0.5, -0.45), &"right": Vector3(0.3, -0.5, -0.45)}

## Clip key: [seconds, position offset (m, arm space), rotation offset (deg), transition, ease].
## 0 seconds snaps. The last key returns to zero. Values are for the RIGHT arm; the left mirrors X.
const CLIPS := {
	&"poke": [
		[0.05, Vector3(0.0, 0.015, -0.13), Vector3(-8, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.03, Vector3(0.0, 0.015, -0.14), Vector3(-9, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.16, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"catch": [
		[0.05, Vector3(0.0, -0.012, 0.0), Vector3(3, 0, 0), Tween.TRANS_QUAD, Tween.EASE_OUT],
		[0.14, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]],
	&"reach": [
		[0.08, Vector3(-0.02, 0.03, -0.09), Vector3(-6, 4, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"place": [
		[0.08, Vector3(0.0, 0.02, -0.10), Vector3(-5, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.18, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"toss": [
		[0.07, Vector3(0.01, -0.02, 0.05), Vector3(10, 0, -4), Tween.TRANS_QUAD, Tween.EASE_OUT],
		[0.07, Vector3(-0.01, 0.05, -0.12), Vector3(-18, 0, 6), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"wipe": [
		[0.05, Vector3(0.03, 0.0, -0.04), Vector3(0, 0, 6), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.06, Vector3(0.0, 0.03, -0.05), Vector3(0, 0, -4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.06, Vector3(-0.03, 0.0, -0.04), Vector3(0, 0, 6), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.06, Vector3(0.0, -0.02, -0.03), Vector3(0, 0, -3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.12, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"slash": [
		[0.06, Vector3(0.04, 0.03, 0.02), Vector3(0, -10, 20), Tween.TRANS_QUAD, Tween.EASE_OUT],
		[0.08, Vector3(-0.08, -0.02, -0.06), Vector3(0, 12, -35), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"dig": [
		[0.08, Vector3(0.0, -0.05, -0.06), Vector3(-14, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.06, Vector3(0.0, -0.045, -0.05), Vector3(-12, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]],
	&"sift": [
		[0.07, Vector3(0.0, -0.04, -0.06), Vector3(-10, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.04, Vector3(0.012, -0.04, -0.06), Vector3(-10, 0, 3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.04, Vector3(-0.012, -0.04, -0.06), Vector3(-10, 0, -3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.04, Vector3(0.012, -0.04, -0.06), Vector3(-10, 0, 3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.18, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"recoil": [
		[0.03, Vector3(0.0, 0.0, 0.012), Vector3(2, 0, 0), Tween.TRANS_QUAD, Tween.EASE_OUT],
		[0.08, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_QUAD, Tween.EASE_IN_OUT]],
	&"choke": [
		[0.05, Vector3(0.006, 0.0, 0.0), Vector3(0, 0, 4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.05, Vector3(-0.006, 0.0, 0.0), Vector3(0, 0, -4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.05, Vector3(0.004, 0.0, 0.0), Vector3(0, 0, 3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.10, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"reject": [
		[0.05, Vector3.ZERO, Vector3(0, 4, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.05, Vector3.ZERO, Vector3(0, -4, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.05, Vector3.ZERO, Vector3(0, 2, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.08, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"equip_raise": [
		[0.0, Vector3(0.0, -0.25, 0.05), Vector3(35, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.22, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]],
	&"bag_raise": [
		[0.0, Vector3(0.0, -0.20, 0.04), Vector3(30, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]],
}

var rig: HandRig
var body: CharacterBody3D
var movement: PlayerMovement
var input_reader: InputReader
var settings: SettingsStore

var _bob_phase := 0.0
var _bob_weight := 0.0
var _look_rate := Vector2.ZERO
var _sway := Vector2.ZERO
var _sway_velocity := Vector2.ZERO
var _land := 0.0
var _land_velocity := 0.0
var _was_grounded := true
var _air_time := 0.0
var _activity_kind := StringName()
var _activity := 0.0
var _activity_target := 0.0
var _activity_until := 0
var _bag_fill_target := 0.0
var _bag_fill := 0.88
var _bag_fill_velocity := 0.0
var _bag_squash := Vector3.ZERO
var _bag_squash_velocity := Vector3.ZERO
var _bag_roll := 0.0
var _bag_roll_velocity := 0.0
## Per arm: current clip offset (position m, rotation deg) and the clip being sampled.
var _arm_position := {&"left": Vector3.ZERO, &"right": Vector3.ZERO}
var _arm_rotation := {&"left": Vector3.ZERO, &"right": Vector3.ZERO}
var _clips := {}


func configure(hand_rig: HandRig, player_body: CharacterBody3D, player_movement: PlayerMovement, reader: InputReader) -> void:
	rig = hand_rig
	body = player_body
	movement = player_movement
	input_reader = reader
	_bag_fill = lerpf(FEEL.bag_fill_scale_empty, FEEL.bag_fill_scale_full, _bag_fill_target)


func on_cue(cue: StringName, info: Dictionary) -> void:
	if rig == null:
		return
	var arm := StringName(str(info.get("arm", "right")))
	match cue:
		&"poke":
			play(&"poke", &"right")
		&"whiff":
			match rig.active_tool_id():
				&"stick": play(&"poke", &"right", 0.6)
				&"cloth": play(&"wipe", &"right", 0.5)
				&"knife": play(&"slash", &"right", 0.6)
		&"bag_catch":
			bag_catch(float(info.get("strength", 1.0)))
			play(&"catch", &"left", 0.6)
		&"rejected":
			if str(info.get("reason", "")).contains("Bag full") or str(info.get("reason", "")).contains("bag is full"):
				bag_wobble()
				play(&"reject", &"left")
			else:
				play(&"reject", &"right")
		&"hold", &"hold_bag":
			play(&"reach", &"both", 1.3 if bool(info.get("large", false)) else 1.0)
		&"throw":
			play(&"toss", arm)
		&"place", &"deposit":
			play(&"place", arm)
		&"clean", &"clean_done":
			play(&"wipe", &"right")
		&"cut":
			play(&"slash", &"right")
		&"reveal":
			play(&"dig", &"right")
		&"sift":
			play(&"sift", &"right")
		&"vacuum_tick":
			play(&"recoil", &"right")
		&"vacuum_full":
			play(&"choke", &"right")


func play(clip: StringName, arm: StringName, strength := 1.0) -> void:
	var keys: Array = CLIPS.get(clip, [])
	if keys.is_empty() or rig == null:
		return
	var reduced := FeelMotion.reduced(settings)
	var amount := strength * (FEEL.reduced_clip_strength if reduced else 1.0)
	if arm == &"left" or arm == &"both":
		_play_on(&"left", keys, amount, true, reduced)
	if arm == &"right" or arm == &"both":
		_play_on(&"right", keys, amount, false, reduced)
	_compose(reduced, Time.get_ticks_msec() * 0.001)


func set_activity(kind: StringName, amount: float) -> void:
	_activity_kind = kind
	_activity_target = clampf(amount, 0.0, 1.0)
	_activity_until = Time.get_ticks_msec() + 120


func set_bag_fill(ratio: float) -> void:
	_bag_fill_target = clampf(ratio, 0.0, 1.0)


func bag_catch(strength := 1.0) -> void:
	var omega := TAU * FEEL.bag_spring_hz * 1.5
	_bag_squash_velocity += FEEL.bag_squash_kick * omega * E * strength


func bag_wobble() -> void:
	_bag_roll_velocity += deg_to_rad(10.0) * TAU * 3.0 * E


## True while a clip is still playing on either arm (used by probes and the finale).
func is_playing() -> bool:
	return not _clips.is_empty()


func _play_on(side: StringName, keys: Array, amount: float, mirrored: bool, reduced: bool) -> void:
	var segments: Array = []
	var from_position: Vector3 = _arm_position[side]
	var from_rotation: Vector3 = _arm_rotation[side]
	for key in keys:
		var position := (key[1] as Vector3) * amount
		var rotation := (key[2] as Vector3) * amount
		if mirrored:
			position.x = -position.x
			rotation.y = -rotation.y
			rotation.z = -rotation.z
		var trans: int = key[3]
		if reduced and trans == Tween.TRANS_BACK:
			trans = Tween.TRANS_QUAD
		if float(key[0]) <= 0.0:
			from_position = position
			from_rotation = rotation
			_arm_position[side] = position
			_arm_rotation[side] = rotation
			continue
		segments.append({
			"seconds": float(key[0]), "trans": trans, "ease": int(key[4]),
			"from_position": from_position, "from_rotation": from_rotation,
			"to_position": position, "to_rotation": rotation,
		})
		from_position = position
		from_rotation = rotation
	_clips[side] = {"segments": segments, "elapsed": 0.0}


func _physics_process(delta: float) -> void:
	if input_reader == null or delta <= 0.0:
		return
	var player := body as BeachPlayer
	var looking := player == null or (player.input_enabled and not get_tree().paused)
	_look_rate = _look_rate.lerp(input_reader.look_delta / delta if looking else Vector2.ZERO, 0.5)


func _process(delta: float) -> void:
	if rig == null or body == null or delta <= 0.0 or not rig.is_visible_in_tree():
		return
	var reduced := FeelMotion.reduced(settings)
	var time := Time.get_ticks_msec() * 0.001
	var paused := get_tree().paused
	_update_clips(delta)
	if not paused:
		_update_locomotion(delta, reduced, time)
		_update_bag(delta, reduced)
		if Time.get_ticks_msec() > _activity_until:
			_activity_target = 0.0
		_activity = move_toward(_activity, _activity_target, 6.0 * delta)
	_compose(reduced, time)


func _update_clips(delta: float) -> void:
	for side in _clips.keys():
		var clip := _clips[side] as Dictionary
		clip.elapsed = float(clip.elapsed) + delta
		var remaining := float(clip.elapsed)
		var sampled := false
		for segment_value in clip.segments as Array:
			var segment := segment_value as Dictionary
			var seconds := float(segment.seconds)
			if remaining <= seconds:
				var weight := float(Tween.interpolate_value(0.0, 1.0, remaining, seconds, segment.trans, segment.ease))
				_arm_position[side] = (segment.from_position as Vector3).lerp(segment.to_position, weight)
				_arm_rotation[side] = (segment.from_rotation as Vector3).lerp(segment.to_rotation, weight)
				sampled = true
				break
			remaining -= seconds
		if not sampled:
			_arm_position[side] = Vector3.ZERO
			_arm_rotation[side] = Vector3.ZERO
			_clips.erase(side)


func _update_locomotion(delta: float, reduced: bool, time: float) -> void:
	var horizontal := Vector2(body.velocity.x, body.velocity.z).length()
	var speed_ratio := clampf(horizontal / maxf(movement.walk_speed, 0.1), 0.0, 1.6)
	var grounded := body.is_on_floor() and not movement.is_swimming
	var hz := FEEL.bob_hz
	if speed_ratio > 1.2:
		hz *= FEEL.bob_sprint_scale
	if movement.is_crouched:
		hz *= FEEL.bob_crouch_scale
	if grounded and speed_ratio > 0.05:
		_bob_phase = fmod(_bob_phase + delta * TAU * hz, TAU * 2.0)
	var target_weight := 0.0
	if grounded:
		target_weight = FEEL.bob_amplitude * minf(speed_ratio, 1.3) * (FEEL.bob_carry_large_scale if movement.carry_speed_multiplier < 0.99 else 1.0)
	_bob_weight = lerpf(_bob_weight, target_weight, 1.0 - exp(-8.0 * delta))
	# Weight lags the look: turning right swings the hands slightly left, looking down lifts them.
	var limit := deg_to_rad(FEEL.sway_max_degrees)
	var target := Vector2(clampf(_look_rate.y * FEEL.sway_gain, -limit, limit), clampf(_look_rate.x * FEEL.sway_gain, -limit, limit))
	var pitch := FeelMotion.spring(_sway.x, _sway_velocity.x, target.x, FEEL.sway_spring_hz, delta)
	var yaw := FeelMotion.spring(_sway.y, _sway_velocity.y, target.y, FEEL.sway_spring_hz, delta)
	_sway = Vector2(pitch.x, yaw.x)
	_sway_velocity = Vector2(pitch.y, yaw.y)
	if grounded and not _was_grounded and _air_time > 0.12:
		var peak := FEEL.land_kick * clampf(_air_time / 0.5, 0.25, 1.0)
		_land_velocity -= peak * TAU * FEEL.land_spring_hz * E
	if grounded or movement.is_swimming:
		_air_time = 0.0
	else:
		_air_time += delta
	_was_grounded = grounded
	var land := FeelMotion.spring(_land, _land_velocity, 0.0, FEEL.land_spring_hz, delta)
	_land = land.x
	_land_velocity = land.y
	if reduced:
		_sway = Vector2.ZERO
		_sway_velocity = Vector2.ZERO
		_land = 0.0
		_land_velocity = 0.0


func _update_bag(delta: float, reduced: bool) -> void:
	var fill := FeelMotion.spring(_bag_fill, _bag_fill_velocity, lerpf(FEEL.bag_fill_scale_empty, FEEL.bag_fill_scale_full, _bag_fill_target), FEEL.bag_spring_hz, delta)
	_bag_fill = fill.x
	_bag_fill_velocity = fill.y
	var squash := FeelMotion.spring3(_bag_squash, _bag_squash_velocity, Vector3.ZERO, FEEL.bag_spring_hz * 1.5, delta)
	_bag_squash = squash[0]
	_bag_squash_velocity = squash[1]
	var roll := FeelMotion.spring(_bag_roll, _bag_roll_velocity, 0.0, 3.0, delta)
	_bag_roll = roll.x
	_bag_roll_velocity = roll.y
	if reduced:
		_bag_squash = Vector3.ZERO
		_bag_squash_velocity = Vector3.ZERO
		_bag_roll = 0.0
		_bag_roll_velocity = 0.0


## Hands the current motion to the rig: sway (camera space), each arm's clip about its pivot,
## the tool's working motion (socket space) and the bag's shape.
func _compose(reduced: bool, time: float) -> void:
	if rig == null:
		return
	var sway := Transform3D.IDENTITY
	if not reduced:
		var bob := Vector3(sin(_bob_phase * 0.5) * _bob_weight, -absf(sin(_bob_phase * 0.5)) * _bob_weight * 0.8, 0.0)
		var breathe := Vector3(0.0, sin(time * TAU * FEEL.idle_breath_hz) * FEEL.idle_breath_amplitude, 0.0)
		if movement != null and movement.is_swimming:
			var float_y := sin(time * TAU * FEEL.swim_float_hz) * FEEL.swim_float_amplitude
			breathe = Vector3(sin(time * TAU * FEEL.swim_float_hz * 0.8 + 0.7) * FEEL.swim_float_amplitude * 0.6, float_y, 0.0)
		sway = Transform3D(Basis.from_euler(Vector3(_sway.x, _sway.y, _sway.y * 0.5)), bob + breathe + Vector3(0.0, _land, 0.0))
	var tool_position := Vector3.ZERO
	var tool_rotation := Vector3.ZERO
	if not reduced and _activity > 0.0:
		match _activity_kind:
			&"vacuum":
				var jitter := FEEL.vacuum_jitter * _activity
				tool_position = Vector3(sin(time * TAU * FEEL.vacuum_jitter_hz) * jitter, sin(time * TAU * FEEL.vacuum_jitter_hz * 1.37 + 1.1) * jitter, -0.015 * _activity)
			&"detector":
				tool_rotation.y = sin(time * TAU * FEEL.detector_sweep_hz) * deg_to_rad(FEEL.detector_sweep_degrees) * (0.6 + 0.4 * _activity) * minf(_activity / 0.3, 1.0)
			&"sand_cleaner":
				tool_rotation.x = sin(time * TAU * 1.2) * deg_to_rad(2.0) * _activity
	var tool_motion := Transform3D(Basis.from_euler(tool_rotation), tool_position)
	rig.apply_motion(sway, _arm_motion(&"left"), _arm_motion(&"right"), tool_motion)
	var fill_t := _bag_fill_target
	var width := lerpf(0.94, 1.06, fill_t)
	rig.bag_placeholder.scale = Vector3(width + _bag_squash.x, _bag_fill + _bag_squash.y, width + _bag_squash.z)
	rig.bag_placeholder.rotation.z = _bag_roll


func _arm_motion(side: StringName) -> Transform3D:
	var offset: Vector3 = _arm_position[side]
	var rotation: Vector3 = _arm_rotation[side]
	if offset == Vector3.ZERO and rotation == Vector3.ZERO:
		return Transform3D.IDENTITY
	var pivot: Vector3 = PIVOTS[side]
	var basis := Basis.from_euler(rotation * (PI / 180.0), EULER_ORDER_YXZ)
	# Rotate about the elbow, then offset: x' = R (x - pivot) + pivot + offset.
	return Transform3D(basis, pivot + offset - basis * pivot)
