class_name FeelMotion
extends RefCounted
## Stateless presentation helpers. Never read or write RunState here.

const FEEL := preload("res://data/feel/feel_tuning.tres")


static func reduced(settings: SettingsStore) -> bool:
	return settings != null and bool(settings.get_value(&"reduced_motion"))


## Presentation tween that keeps running while the SceneTree is paused, so effects
## always reach their terminal state (results and pause can open mid-effect).
static func tween(node: Node) -> Tween:
	return node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


## Kills the tween stored on `node` for `channel`, stores `next` (may be null), returns it.
static func replace(node: Node, channel: StringName, next: Tween) -> Tween:
	var key := StringName("feel_tween_%s" % channel)
	if node.has_meta(key):
		var old: Variant = node.get_meta(key)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	if next == null:
		if node.has_meta(key):
			node.remove_meta(key)
	else:
		node.set_meta(key, next)
	return next


## Uniform pop ONE -> peak -> ONE. Ends exactly at ONE.
static func pop(node: Node3D, peak: Vector3, up_seconds: float, down_seconds: float) -> Tween:
	var t := replace(node, &"scale", tween(node))
	t.tween_property(node, "scale", peak, up_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector3.ONE, down_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Contact squash -> rebound stretch -> rest. Ends exactly at ONE.
static func squash_land(node: Node3D, squash: Vector3, rebound: Vector3, seconds: float) -> Tween:
	node.scale = squash
	var t := replace(node, &"scale", tween(node))
	t.tween_property(node, "scale", rebound, seconds * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector3.ONE, seconds * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


static func bezier2(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u) + control * (2.0 * u * t) + b * (t * t)


static func bezier3(a: Vector3, c1: Vector3, c2: Vector3, b: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + b * (t * t * t)


static func ease_in_out_cubic(t: float) -> float:
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5


static func ease_named(t: float, kind: StringName) -> float:
	match kind:
		&"in":
			return t * t
		&"out":
			return 1.0 - (1.0 - t) * (1.0 - t)
	return ease_in_out_cubic(t)


static func travel_seconds(distance: float, base: float, per_meter: float, maximum: float) -> float:
	return clampf(base + distance * per_meter, base, maximum)


## Moves `node` (a child of `space`) from its transform at the moment this step starts to
## `end_local` (in `space`), along an arc. Appends to `existing` when given (after a yoink).
## options: arc, drop, via (Node3D), via_anchor (Node3D), via_fraction, spin_turns, spin_axis,
## visual (Node3D), shrink_to, shrink_from, stretch (Vector3), ease (&"in_out" | &"in" | &"out").
## With `via_anchor` (e.g. the grip), a `via` point below the start height is replaced by where
## the anchor-to-via segment crosses that height, so a tool tip buried in sand still gives a
## visible stab point.
## Arcs rise along world up, expressed in `space`, so hand sockets on a pitched camera still
## lift items upward in the world.
static func travel(node: Node3D, space: Node3D, end_local: Transform3D, seconds: float, options: Dictionary, finished: Callable, existing: Tween = null) -> Tween:
	var t := existing if existing != null else tween(node)
	var visual: Node3D = options.get("visual", node)
	var arc := float(options.get("arc", 0.0))
	var drop := float(options.get("drop", 0.0))
	var via: Node3D = options.get("via")
	var via_anchor: Node3D = options.get("via_anchor")
	var via_fraction := clampf(float(options.get("via_fraction", 0.3)), 0.05, 0.9)
	var spin_turns := float(options.get("spin_turns", 0.0))
	var spin_axis: Vector3 = options.get("spin_axis", Vector3.UP)
	var shrink_to := float(options.get("shrink_to", 1.0))
	var shrink_from := float(options.get("shrink_from", 0.55))
	var stretch: Vector3 = options.get("stretch", Vector3.ZERO)
	var easing := StringName(str(options.get("ease", "in_out")))
	var state := {}
	t.tween_callback(func() -> void:
		if not is_instance_valid(node) or not is_instance_valid(space):
			return
		state["start"] = node.transform
		state["visual_scale"] = visual.scale if is_instance_valid(visual) else Vector3.ONE
		state["visual_position"] = visual.position if is_instance_valid(visual) else Vector3.ZERO
		var up := space.global_basis.orthonormalized().inverse() * Vector3.UP
		state["up"] = up.normalized() if up.length_squared() > 0.0001 else Vector3.UP
		state["floor"] = node.global_position.y + 0.03
	)
	t.tween_method(func(progress: float) -> void:
		if not is_instance_valid(node) or not is_instance_valid(space) or not state.has("start"):
			return
		var start: Transform3D = state["start"]
		var up: Vector3 = state["up"]
		var e := ease_named(progress, easing)
		var p0 := start.origin
		var p1 := end_local.origin
		var position := Vector3.ZERO
		if via != null:
			if is_instance_valid(via) and via.is_inside_tree():
				var tip_world := via.global_position
				var floor_y := float(state["floor"])
				if via_anchor != null and is_instance_valid(via_anchor) and tip_world.y < floor_y:
					var grip := via_anchor.global_position
					tip_world = grip.lerp(tip_world, clampf((grip.y - floor_y) / maxf(grip.y - tip_world.y, 0.001), 0.0, 1.0)) if grip.y > floor_y else Vector3(tip_world.x, floor_y, tip_world.z)
				state["tip"] = space.global_transform.affine_inverse() * tip_world
			var tip: Vector3 = state.get("tip", p0)
			if progress < via_fraction:
				position = p0.lerp(tip, ease_named(progress / via_fraction, &"out"))
			else:
				var b := ease_named((progress - via_fraction) / (1.0 - via_fraction), easing)
				position = bezier2(tip, (tip + p1) * 0.5 + up * arc, p1, b)
		elif drop > 0.0:
			position = bezier3(p0, p0 + up * arc, p1 + up * (arc * 0.6 + drop), p1, e)
		else:
			position = bezier2(p0, (p0 + p1) * 0.5 + up * arc, p1, e)
		var rotation := start.basis.orthonormalized().slerp(end_local.basis.orthonormalized(), e)
		if spin_turns != 0.0:
			rotation = rotation * Basis(spin_axis.normalized(), TAU * spin_turns * e)
		node.transform = Transform3D(rotation, position)
		if is_instance_valid(visual):
			var shrink := smoothstep(shrink_from, 1.0, progress)
			var target_scale := stretch if stretch != Vector3.ZERO else Vector3.ONE * shrink_to
			visual.scale = (state["visual_scale"] as Vector3).lerp(target_scale, shrink)
			if visual != node:
				# A child visual root (after a yoink) settles back onto the travelling node.
				visual.position = (state["visual_position"] as Vector3).lerp(Vector3.ZERO, e)
	, 0.0, 1.0, maxf(seconds, 0.01))
	if finished.is_valid():
		t.tween_callback(finished)
	return t


## Exact critically damped spring. Returns Vector2(value, velocity).
static func spring(value: float, velocity: float, target: float, frequency_hz: float, delta: float) -> Vector2:
	var omega := TAU * frequency_hz
	var offset := value - target
	var decay := exp(-omega * delta)
	var next_offset := (offset + (velocity + omega * offset) * delta) * decay
	var next_velocity := (velocity - omega * (velocity + omega * offset) * delta) * decay
	return Vector2(target + next_offset, next_velocity)


## Component-wise spring. Returns [value: Vector3, velocity: Vector3].
static func spring3(value: Vector3, velocity: Vector3, target: Vector3, frequency_hz: float, delta: float) -> Array:
	var x := spring(value.x, velocity.x, target.x, frequency_hz, delta)
	var y := spring(value.y, velocity.y, target.y, frequency_hz, delta)
	var z := spring(value.z, velocity.z, target.z, frequency_hz, delta)
	return [Vector3(x.x, y.x, z.x), Vector3(x.y, y.y, z.y)]


## Stable 0..1 value from an id. Cosmetic only; never gameplay RNG.
static func cosmetic_random(id: Variant, salt: int = 0) -> float:
	return float(absi(hash([id, salt])) % 10007) / 10006.0


static func cosmetic_axis(id: Variant) -> Vector3:
	return Vector3(cosmetic_random(id, 1) * 2.0 - 1.0, 1.0, cosmetic_random(id, 2) * 2.0 - 1.0).normalized()


## UI pop around the control's centre. Ends exactly at ONE.
static func bump_control(control: Control, peak: float, seconds: float) -> Tween:
	control.pivot_offset = control.size * 0.5
	var t := replace(control, &"bump", tween(control))
	t.tween_property(control, "scale", Vector2.ONE * peak, seconds * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(control, "scale", Vector2.ONE, seconds * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Horizontal shake offset for time `elapsed` of `seconds`; returns 0 when done.
static func shake_offset(elapsed: float, seconds: float, pixels: float) -> float:
	if elapsed >= seconds or seconds <= 0.0:
		return 0.0
	var decay := 1.0 - elapsed / seconds
	return sin(elapsed * 55.0) * pixels * decay


## An anchored control's offsets as its scene lays them out. UI slides and shakes move relative
## to these instead of a cached position, so a resize or UI-scale change never strands a panel.
static func layout_offsets(control: Control) -> Vector4:
	if not control.has_meta(&"feel_layout"):
		control.set_meta(&"feel_layout", Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom))
	return control.get_meta(&"feel_layout")


## Shifts an anchored control sideways from its laid-out place; 0 puts it back exactly.
static func nudge_x(control: Control, pixels: float) -> void:
	var layout := layout_offsets(control)
	control.offset_left = layout.x + pixels
	control.offset_right = layout.z + pixels


## Shifts an anchored control up or down from its laid-out place; 0 puts it back exactly.
static func nudge_y(control: Control, pixels: float) -> void:
	var layout := layout_offsets(control)
	control.offset_top = layout.y + pixels
	control.offset_bottom = layout.w + pixels


## Count-up duration for a numeric change.
static func count_seconds(delta_value: float) -> float:
	return clampf(FEEL.count_min_seconds + log(maxf(absf(delta_value), 1.0)) * 0.1, FEEL.count_min_seconds, FEEL.count_max_seconds)
