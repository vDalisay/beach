# J00 — Feel foundations and baseline

Dependencies: none (current `main`). Read first: [game-feel plan](../12-game-feel.md) §0, §4 and §5, plus the [architecture](../02-architecture.md) "One item, one location" and "Mutation entry points" sections.

**Outcome:** every later J packet has shared tuning, motion helpers, particle kinds, ring and floater effects, and a single player cue entry point. A measured baseline exists before any visible change. This packet changes nothing visible except that new effects can be spawned.

**Own files:**

| File | Change |
|---|---|
| `scripts/data/feel_tuning.gd` | New |
| `data/feel/feel_tuning.tres` | New |
| `scripts/feel/feel_motion.gd` | New |
| `scripts/feel/feel_ring.gd` | New |
| `scripts/feel/feel_floater.gd` | New |
| `shaders/feel_sparkle.gdshader`, `shaders/feel_dust.gdshader`, `shaders/feel_ring.gdshader` | New |
| `scripts/wildlife/particle_pool.gd` | Extend |
| `scripts/player/player.gd` | Add the cue entry point |
| `docs/handoffs/J-feel.md` | Baseline |

## Steps

### 1. Record the baseline before touching code

On the current commit:

1. Run the crowded profile: `& $beachGodot --path . --script res://tests/validate_physics.gd -- --profile --c04-dense`. Record frame median, mean and p95, max draws, node count and awake bodies.
2. Take stills of the current look, at 1920×1080 and FOV 85 in `scenes/main.tscn` with seed `feedback-sequence`:
   - hover on a can
   - hover on a glass bottle
   - the ghost over a chair slot
   - a group sweep mid-way
   - the stick at rest
   - the HUD

   `tests/record_feedback.gd` already stages that scene and can be reused or copied into a temporary probe.
3. Write both into `docs/handoffs/J-feel.md` under "Baseline". These are the "before" images for J14.

### 2. Create the tuning resource

Create `scripts/data/feel_tuning.gd` exactly as below, then create `data/feel/feel_tuning.tres` as a resource of that script with default values. All later packets read these names. If a packet needs a new value, add it to the matching group here rather than hardcoding it.

```gdscript
class_name FeelTuning
extends Resource
## Presentation-only tuning for hover, hands, placement, tools and completion.
## Nothing here may change ownership, payment, completion, saves, reach or timing of commits.

@export_group("Hover")
@export var hover_outline_px := 2.5
@export var hover_outline_peak_px := 3.5
@export var hover_backing_px := 1.5
@export var hover_max_world_width := 0.03
@export var hover_in_seconds := 0.12
@export var hover_out_seconds := 0.06
@export var hover_action_color := Color("ffffff")
@export var hover_backing_color := Color("0b1a1f")
@export var hover_blocked_color := Color("e8b45a")
@export var hover_blocked_dash_px := 5.0
@export var hover_rim_strength := 0.3
@export var hover_rim_breath := 0.2
@export var hover_rim_hz := 1.4
@export var hover_soft_rim_strength := 0.16
@export var hover_see_through_rim_strength := 0.6
@export var hover_lift_small := 1.06
@export var hover_lift_large := 1.02
@export var hover_hop_height := 0.015
@export var hover_wiggle_degrees := 4.0

@export_group("Reticle and label")
@export var reticle_dot_px := 2.5
@export var reticle_ring_px := 9.0
@export var reticle_ring_width_px := 2.0
@export var reticle_place_px := 10.0
@export var reticle_spring_hz := 7.0
@export var reticle_pop_px := 5.0
@export var reticle_shake_px := 4.0
@export var reticle_shake_seconds := 0.2
@export var reticle_idle_alpha := 0.7
@export var label_in_seconds := 0.1
@export var label_rise_px := 6.0
@export var label_follow_hz := 18.0
@export var label_shake_px := 5.0

@export_group("Viewmodel")
@export var bob_hz := 1.8
@export var bob_sprint_scale := 1.35
@export var bob_crouch_scale := 0.75
@export var bob_amplitude := 0.012
@export var bob_carry_large_scale := 1.4
@export var idle_breath_amplitude := 0.004
@export var idle_breath_hz := 0.25
@export var sway_gain := 0.012
@export var sway_max_degrees := 4.0
@export var sway_spring_hz := 4.5
@export var land_kick := 0.05
@export var land_spring_hz := 5.0
@export var swim_float_amplitude := 0.012
@export var swim_float_hz := 0.5
@export var reduced_clip_strength := 0.5
## The equip raise duration lives in ViewmodelAnimator.CLIPS[&"equip_raise"].
@export var equip_drop_seconds := 0.14
@export var bag_fill_scale_empty := 0.88
@export var bag_fill_scale_full := 1.12
@export var bag_squash_kick := Vector3(0.10, -0.12, 0.10)
@export var bag_spring_hz := 4.0
@export var held_selected_lift := Vector3(0.0, 0.035, -0.03)
@export var vacuum_jitter := 0.0015
@export var vacuum_jitter_hz := 22.0
@export var detector_sweep_degrees := 8.0
@export var detector_sweep_hz := 0.6
## Tool tip positions in ToolSocket space after the grip transform; tune in J03/J06 and after art swaps.
@export var tool_tips: Dictionary[StringName, Vector3] = {
	&"stick": Vector3(0.0, -0.32, -0.34),
	&"cloth": Vector3(0.0, -0.02, -0.06),
	&"knife": Vector3(0.0, 0.02, -0.12),
	&"detector": Vector3(0.0, -0.20, -0.62),
	&"sand_cleaner": Vector3(0.0, -0.10, -0.20),
	&"vacuum": Vector3(0.0, -0.02, -0.46),
}

@export_group("Pickup and throw")
@export var yoink_seconds := 0.06
@export var yoink_height := 0.06
@export var yoink_scale := 1.15
@export var bag_travel_base := 0.2
@export var bag_travel_per_meter := 0.04
@export var bag_travel_max := 0.3
@export var bag_arc_height := 0.25
@export var bag_mouth := Vector3(0.0, 0.12, 0.0)
@export var bag_shrink_from := 0.55
@export var bag_end_scale := 0.12
@export var bag_spin_turns := 0.6
@export var stick_tip_fraction := 0.3
@export var vacuum_travel_seconds := 0.2
@export var vacuum_stretch := Vector3(0.7, 0.7, 1.5)
@export var sand_cleaner_stagger := 0.035
@export var prop_yoink_seconds := 0.07
@export var prop_yoink_height := 0.1
@export var prop_wiggle_degrees := 3.0
@export var prop_travel_seconds := 0.26
@export var prop_arc_height := 0.12
@export var pickup_sparkles := 4
@export var pickup_dust := 6
@export var dust_color := Color("e8dcc2")
@export var sand_color := Color("d8c39a")
@export var throw_spin := 6.0
@export var impact_min_speed := 2.0
@export var impact_squash := Vector3(1.12, 0.85, 1.12)
@export var impact_seconds := 0.14

@export_group("Placement")
@export var ghost_color := Color("7ff5c8")
@export var ghost_fill_alpha := 0.16
@export var ghost_rim_alpha := 0.85
@export var ghost_scan_density := 14.0
@export var ghost_breath := 0.12
@export var ghost_appear_seconds := 0.1
@export var ghost_glide_seconds := 0.08
@export var ghost_blob_alpha := 0.28
@export var place_travel_base := 0.2
@export var place_travel_per_meter := 0.04
@export var place_travel_max := 0.3
@export var place_arc_height := 0.18
@export var place_drop_height := 0.06
@export var capture_travel_seconds := 0.18
@export var land_squash := Vector3(1.06, 0.92, 1.06)
@export var land_rebound := Vector3(0.98, 1.06, 0.98)
@export var land_seconds := 0.22
@export var land_sparkles := 6
@export var neighbor_wobble_degrees := 2.0
@export var neighbor_wobble_radius := 1.2
@export var remove_lift := 0.06

@export_group("Tools")
@export var detector_ping_far_seconds := 1.1
@export var detector_ping_near_seconds := 0.22
@export var detector_ring_radius := 0.9
@export var detector_color := Color("ffc24d")
@export var sand_ring_color := Color("7ff5c8")
@export var sand_ring_dashes := 24.0
@export var vacuum_mote_rate := 24.0
@export var vacuum_mote_speed := 3.5
@export var scanner_ring_radius := 30.0
@export var scanner_ring_seconds := 0.9
@export var scanner_color := Color("8ff3e0")
@export var freed_label_seconds := 1.6
@export var reveal_pop_height := 0.06

@export_group("Completion")
## validate_placement.gd waits 0.9 s for the overlay to clear; keep this at or below 0.8.
@export var group_sweep_seconds := 0.8
@export var shine_angle_degrees := 20.0
@export var shine_band_width := 0.22
@export var shine_core_color := Color("fff8e6")
@export var shine_fringe_color := Color("8ff3e0")
@export var shine_intensity := 1.0
@export var clean_gleam_seconds := 0.6
@export var clean_sparkles := 8
@export var set_sparkles_per_item := 3
@export var floater_rise := 0.35
@export var floater_seconds := 1.1
@export var sparkle_colors: Array[Color] = [Color("fff6d8"), Color("ffd86a"), Color("a6f5ee")]

@export_group("Sorting table")
@export var unload_drop_height := 0.45
@export var unload_fall_seconds := 0.22
@export var unload_cascade_max := 0.9
@export var unload_stagger := 0.012
@export var sort_travel_seconds := 0.22
@export var proxy_hover_lift := 0.03
@export var proxy_hover_scale := 1.12
@export var drag_height := 0.12
@export var drag_tilt_degrees := 15.0
@export var cursor_follow_hz := 30.0
@export var bin_bump := Vector3(1.04, 0.92, 1.04)
@export var rack_drop_height := 0.5
@export var stamp_seconds := 0.8

@export_group("HUD")
@export var count_min_seconds := 0.25
@export var count_max_seconds := 0.8
@export var bump_scale := 1.12
@export var bump_seconds := 0.16
@export var bar_shine_seconds := 0.6
@export var notice_in_seconds := 0.18
@export var notice_out_seconds := 0.12
@export var notice_rise_px := 10.0
@export var bag_warn_ratio := 0.8
@export var bag_color_normal := Color("9fe6d6")
@export var bag_color_warn := Color("e8b45a")
@export var bag_color_full := Color("e2725b")
@export var money_color := Color("ffd85a")
@export var money_float_seconds := 0.9

@export_group("Collection and money")
@export var coin_min := 3
@export var coin_max := 10
@export var coin_value := 10
@export var coin_seconds := 0.55
@export var coin_stagger := 0.05
@export var receipt_slide_px := 48.0
@export var receipt_in_seconds := 0.22
@export var receipt_type_seconds := 0.45
@export var receipt_count_seconds := 0.6
@export var phone_ring_degrees := 8.0
@export var phone_ring_seconds := 0.45
@export var container_lift_seconds := 0.35

@export_group("Restoration")
@export var wave_seconds := 1.8
@export var wave_radius_section := 12.0
@export var wave_radius_zone := 22.0
@export var wave_height := 1.2
@export var wave_color_shore := Color("fff1c9")
@export var wave_color_reef := Color("7ff0e0")
@export var wave_sparkle_interval := 0.08
@export var wave_sparkles_per_step := 6
@export var bloom_pop_seconds := 0.45
@export var pointer_seconds := 4.0
@export var pointer_far_distance := 25.0
@export var beacon_seconds := 3.5
@export var beacon_height := 12.0
@export var max_concurrent_waves := 4
@export var banner_batch_threshold := 3

@export_group("Finale")
@export var finale_capture_seconds := 1.1
@export var finale_flash_alpha := 0.55
@export var finale_count_seconds := 0.6
@export var confetti_amount := 80
@export var confetti_colors: Array[Color] = [Color("f2d49b"), Color("5fd6c8"), Color("ff8f8a"), Color("ffffff")]
@export var postcard_size := Vector2(384, 216)

@export_group("Rumble")
## weak, strong, seconds. Only used when the vibration setting is on and the last input was a controller.
@export var rumble: Dictionary[StringName, Vector3] = {
	&"poke": Vector3(0.10, 0.0, 0.04),
	&"bag_catch": Vector3(0.08, 0.0, 0.03),
	&"rejected": Vector3(0.0, 0.30, 0.06),
	&"hold": Vector3(0.15, 0.05, 0.06),
	&"hold_bag": Vector3(0.15, 0.05, 0.06),
	&"throw": Vector3(0.12, 0.0, 0.05),
	&"place": Vector3(0.20, 0.12, 0.08),
	&"deposit": Vector3(0.18, 0.10, 0.08),
	&"clean": Vector3(0.10, 0.0, 0.05),
	&"clean_done": Vector3(0.25, 0.10, 0.12),
	&"cut": Vector3(0.20, 0.15, 0.06),
	&"animal_freed": Vector3(0.30, 0.10, 0.25),
	&"reveal": Vector3(0.25, 0.20, 0.12),
	&"sift": Vector3(0.20, 0.15, 0.10),
	&"vacuum_tick": Vector3(0.05, 0.0, 0.02),
	&"vacuum_full": Vector3(0.0, 0.35, 0.12),
	&"equip": Vector3(0.08, 0.05, 0.05),
	&"scanner_pulse": Vector3(0.10, 0.0, 0.08),
	&"collect_call": Vector3(0.20, 0.10, 0.15),
	&"set_complete": Vector3(0.30, 0.10, 0.18),
	&"section_restored": Vector3(0.35, 0.20, 0.30),
	&"zone_restored": Vector3(0.40, 0.25, 0.45),
	&"run_complete": Vector3(0.30, 0.10, 0.60),
}
```

Create the resource file:

```text
[gd_resource type="Resource" script_class="FeelTuning" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/feel_tuning.gd" id="1_feel"]

[resource]
script = ExtResource("1_feel")
```

Typed `Dictionary[...]` exports need Godot 4.4 or later, so they work in 4.6.1. If the editor rewrites the file with explicit values after a save, that is fine.

### 3. Create the motion helpers

Create `scripts/feel/feel_motion.gd`:

```gdscript
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
## options: arc, drop, via (Node3D), via_fraction, spin_turns, spin_axis, visual (Node3D),
## shrink_to, shrink_from, stretch (Vector3), ease (&"in_out" | &"in" | &"out").
static func travel(node: Node3D, space: Node3D, end_local: Transform3D, seconds: float, options: Dictionary, finished: Callable, existing: Tween = null) -> Tween:
	var t := existing if existing != null else tween(node)
	var visual: Node3D = options.get("visual", node)
	var arc := float(options.get("arc", 0.0))
	var drop := float(options.get("drop", 0.0))
	var via: Node3D = options.get("via")
	var via_fraction := clampf(float(options.get("via_fraction", 0.3)), 0.05, 0.9)
	var spin_turns := float(options.get("spin_turns", 0.0))
	var spin_axis: Vector3 = options.get("spin_axis", Vector3.UP)
	var shrink_to := float(options.get("shrink_to", 1.0))
	var shrink_from := float(options.get("shrink_from", 0.55))
	var stretch: Vector3 = options.get("stretch", Vector3.ZERO)
	var easing := StringName(str(options.get("ease", "in_out")))
	var state := {}
	t.tween_callback(func() -> void:
		state["start"] = node.transform
		state["visual_scale"] = visual.scale
		state["visual_position"] = visual.position
	)
	t.tween_method(func(progress: float) -> void:
		if not is_instance_valid(node) or not is_instance_valid(space) or not state.has("start"):
			return
		var start: Transform3D = state["start"]
		var e := ease_named(progress, easing)
		var p0 := start.origin
		var p1 := end_local.origin
		var up := Vector3.UP
		var position := Vector3.ZERO
		if via != null and is_instance_valid(via):
			var tip := space.global_transform.affine_inverse() * via.global_position
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


## Count-up duration for a numeric change.
static func count_seconds(delta_value: float) -> float:
	return clampf(FEEL.count_min_seconds + log(maxf(absf(delta_value), 1.0)) * 0.1, FEEL.count_min_seconds, FEEL.count_max_seconds)
```

Notes for implementers:

- Keep the helpers static and stateless. `replace` stores the active tween in node metadata so a new effect on the same channel kills the old one.
- `travel` reads the start transform when its step begins, not when the tween is built, so a yoink placed before it is respected.

### 4. Extend `ParticlePool` without changing `BUBBLE` or `SAND`

Edit `scripts/wildlife/particle_pool.gd` in the order below. The code blocks use tabs, like the script.

**4a. Kinds.** Change `enum Kind { BUBBLE, SAND }` to `enum Kind { BUBBLE, SAND, SPARKLE, DUST }`.

**4b. Fields.** Add:

```gdscript
const SPARKLE_SHADER := preload("res://shaders/feel_sparkle.gdshader")
const DUST_SHADER := preload("res://shaders/feel_dust.gdshader")
static var _sparkle_mesh: QuadMesh
static var _dust_mesh: QuadMesh
var tint := Color.WHITE      ## colour for emits that pass no colour
var drag := 4.0              ## DUST velocity decay per second (0 for suction motes)
var rise := 0.12             ## SPARKLE/DUST upward drift, m/s
var grow := 1.5              ## DUST size gained over life (negative shrinks)
var _colors := PackedColorArray()
```

**4c. `create()`:**

```gdscript
static func create(particle_kind: Kind, max_particles := 160, process_always := false) -> ParticlePool:
	var pool := ParticlePool.new()
	pool.kind = particle_kind
	pool.capacity = max_particles
	pool.name = ["Bubbles", "SandKicks", "Sparkles", "Dust"][particle_kind]
	if process_always:
		pool.process_mode = Node.PROCESS_MODE_ALWAYS
	return pool
```

**4d. `emit()` and `burst()`.** The existing callers pass 4 or 7 arguments and keep working:

```gdscript
func emit(at: Vector3, velocity: Vector3, size: float, lifetime := 3.5, color := Color(0, 0, 0, 0)) -> void:
	if kind == Kind.BUBBLE and at.y >= surface_y - size:
		return
	if _positions.size() >= capacity:
		_remove(0)
	_positions.append(at)
	_velocities.append(velocity)
	_ages.append(0.0)
	_lifetimes.append(lifetime)
	_sizes.append(size)
	_seeds.append(_rng.randf() * TAU)
	_colors.append(tint if color.a <= 0.0 else color)
	set_process(true)


func burst(at: Vector3, direction: Vector3, count: int, speed: float, spread: float, size_range: Vector2, lifetime := 3.5, color := Color(0, 0, 0, 0)) -> void:
	for index in range(count):
		var jitter := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		var throw := direction * speed * _rng.randf_range(0.5, 1.0) + jitter * spread
		emit(at + jitter * size_range.y, throw, _rng.randf_range(size_range.x, size_range.y), lifetime * _rng.randf_range(0.8, 1.2), color)
```

**4e. Stepping.** In `_process`, replace the per-kind step call with a dispatch, and add the new step function:

```gdscript
match kind:
	Kind.BUBBLE:
		_step_bubble(index, delta)
	Kind.SAND:
		_step_sand(index, delta)
	_:
		_step_drift(index, delta)
```

```gdscript
func _step_drift(index: int, delta: float) -> void:
	var decay := 3.0 if kind == Kind.SPARKLE else drag
	_velocities[index] *= exp(-decay * delta)
	_positions[index] += (_velocities[index] + Vector3.UP * rise) * delta
```

**4f. `_write_instances`.** Make three changes:

1. Before the loop, add:

```gdscript
var camera := get_viewport().get_camera_3d()
var facing := camera.global_basis.orthonormalized() if camera != null else Basis.IDENTITY
```

2. The loop currently has `if kind == Kind.BUBBLE: … else: …`, where the `else` is sand. Restructure it to `if kind == Kind.BUBBLE: <existing> elif kind == Kind.SAND: <existing else body> elif kind == Kind.SPARKLE: … else: …`. Keep the BUBBLE and SAND bodies byte-for-byte. QuadMesh faces +Z, the same as the camera basis Z, so the new quads face the viewer. The two new branches:

```gdscript
elif kind == Kind.SPARKLE:
	var life := clampf(age / _lifetimes[index], 0.0, 1.0)
	var envelope := sin(PI * life)
	var twinkle := 0.65 + 0.35 * sin(age * 19.0 + _seeds[index] * 3.0)
	shape = (facing * Basis(Vector3.BACK, _seeds[index])).scaled(Vector3.ONE * size * (0.55 + 0.45 * envelope))
	alpha = envelope * twinkle
else:
	var life := clampf(age / _lifetimes[index], 0.0, 1.0)
	shape = facing.scaled(Vector3.ONE * maxf(size * (1.0 + grow * life), 0.005))
	alpha = (1.0 - life) * (1.0 - life) * minf(life * 8.0, 1.0)
```

3. Replace the colour write with the following, so BUBBLE and SAND keep exactly `Color(1, 1, 1, alpha)`:

```gdscript
var c := _colors[index]
multimesh.set_instance_color(index, Color(1.0, 1.0, 1.0, alpha) if kind == Kind.BUBBLE or kind == Kind.SAND else Color(c.r, c.g, c.b, c.a * alpha))
```

**4g. `_remove()`** must also swap and resize `_colors`.

**4h. `_shared_mesh()`:** add cached `QuadMesh` instances of size (1, 1) whose `material` is a `ShaderMaterial` with `SPARKLE_SHADER` or `DUST_SHADER`.

### 5. Particle shaders

`shaders/feel_sparkle.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Four-point star for ParticlePool.SPARKLE. Instance colour alpha fades it.
uniform float ray_sharpness = 9.0;
uniform float core_tightness = 14.0;
uniform float brightness = 1.4;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float core = exp(-dot(p, p) * core_tightness);
	float ray_x = max(0.0, 1.0 - abs(p.y) * ray_sharpness) * (1.0 - abs(p.x));
	float ray_y = max(0.0, 1.0 - abs(p.x) * ray_sharpness) * (1.0 - abs(p.y));
	float star = clamp(core + (ray_x + ray_y) * 0.7, 0.0, 1.0);
	ALBEDO = COLOR.rgb * star * COLOR.a * brightness;
}
```

`shaders/feel_dust.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Soft round puff for ParticlePool.DUST. Instance colour alpha fades it.
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float soft = 1.0 - smoothstep(0.15, 1.0, dot(p, p));
	ALBEDO = COLOR.rgb;
	ALPHA = soft * COLOR.a * 0.8;
}
```

### 6. Ring pulse

`shaders/feel_ring.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 ring_color : source_color = vec4(1.0);
uniform float thickness = 0.04;   // UV units of the unit plane (0..0.5)
uniform float intensity = 1.0;
uniform float dashes = 0.0;       // 0 = solid ring
uniform float dash_phase = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	float t = max(thickness, 0.001);
	float band = 1.0 - smoothstep(0.0, t, abs(r - (0.5 - t)));
	if (dashes > 0.0) {
		float a = atan(p.y, p.x) / 6.2831853 + 0.5;
		band *= step(0.45, fract(a * dashes + dash_phase));
	}
	ALBEDO = ring_color.rgb * band * intensity;
}
```

`scripts/feel/feel_ring.gd`:

```gdscript
class_name FeelRing
extends MeshInstance3D
## Self-freeing flat ring pulse (scanner sonar, detector ping, landing contact).

const SHADER := preload("res://shaders/feel_ring.gdshader")
const LIVE_CAP := 8

static var _mesh: PlaneMesh
static var _live := 0


static func spawn(parent: Node, at: Vector3, from_radius: float, to_radius: float, seconds: float, color: Color, thickness_m := 0.08, dashes := 0.0) -> FeelRing:
	if _live >= LIVE_CAP or parent == null or not parent.is_inside_tree():
		return null
	if _mesh == null:
		_mesh = PlaneMesh.new()
		_mesh.size = Vector2.ONE
	var ring := FeelRing.new()
	ring.mesh = _mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.process_mode = Node.PROCESS_MODE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("ring_color", color)
	material.set_shader_parameter("dashes", dashes)
	ring.material_override = material
	parent.add_child(ring)
	ring.global_position = at
	_live += 1
	ring._play(from_radius, to_radius, seconds, thickness_m, material)
	return ring


func _play(from_radius: float, to_radius: float, seconds: float, thickness_m: float, material: ShaderMaterial) -> void:
	var t := FeelMotion.tween(self)
	t.tween_method(func(progress: float) -> void:
		var radius := lerpf(from_radius, to_radius, 1.0 - (1.0 - progress) * (1.0 - progress))
		var diameter := maxf(radius * 2.0, 0.01)
		scale = Vector3(diameter, 1.0, diameter)
		material.set_shader_parameter("thickness", clampf(thickness_m / diameter, 0.002, 0.25))
		material.set_shader_parameter("intensity", 1.0 - smoothstep(0.55, 1.0, progress))
	, 0.0, 1.0, maxf(seconds, 0.05))
	t.tween_callback(queue_free)


func _exit_tree() -> void:
	_live = maxi(_live - 1, 0)
```

### 7. Floating text

`scripts/feel/feel_floater.gd`:

```gdscript
class_name FeelFloater
extends Label3D
## Self-freeing billboard text that rises and fades ("+$15", "Clean!", "Freed!").
## Use ASCII text: Label3D glyph coverage for symbols such as a check mark is not guaranteed.

const FEEL := preload("res://data/feel/feel_tuning.tres")
const LIVE_CAP := 3

static var _live: Array[FeelFloater] = []


static func spawn(parent: Node, at: Vector3, message: String, color: Color, reduced := false) -> FeelFloater:
	if parent == null or not parent.is_inside_tree():
		return null
	while _live.size() >= LIVE_CAP:
		var oldest: FeelFloater = _live.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var floater := FeelFloater.new()
	floater.text = message
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.font_size = 56
	floater.pixel_size = 0.0035
	floater.outline_size = 12
	floater.modulate = color
	floater.outline_modulate = Color(0.04, 0.08, 0.1, 0.9)
	floater.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(floater)
	floater.global_position = at
	_live.append(floater)
	floater._play(reduced)
	return floater


func _play(reduced: bool) -> void:
	var t := FeelMotion.tween(self)
	if not reduced:
		scale = Vector3.ONE * 0.6
		t.tween_property(self, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "position:y", position.y + FEEL.floater_rise, FEEL.floater_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(maxf(FEEL.floater_seconds - 0.4, 0.0))
	t.chain().tween_callback(queue_free)


func _exit_tree() -> void:
	_live.erase(self)
```

### 8. Player cue entry point

In `scripts/player/player.gd`, add:

```gdscript
signal cue_played(cue: StringName, info: Dictionary)

const CUES: Array[StringName] = [
	&"whiff", &"poke", &"bag_catch", &"rejected", &"hold", &"hold_bag", &"throw", &"place",
	&"deposit", &"clean", &"clean_done", &"cut", &"animal_freed", &"detector_ping", &"reveal",
	&"sift", &"vacuum_tick", &"vacuum_full", &"equip", &"scanner_pulse", &"collect_call",
	&"sort", &"seal", &"unload", &"sell", &"set_complete", &"section_restored",
	&"zone_restored", &"run_complete",
]


## Presentation-only feedback for something the player did or tried. Never changes state.
func play_cue(cue: StringName, info: Dictionary = {}) -> void:
	if OS.is_debug_build() and cue not in CUES:
		push_warning("Unknown feel cue: %s" % cue)
	if hand_rig != null and hand_rig.has_method(&"play_cue"):
		hand_rig.play_cue(cue, info)
	cue_played.emit(cue, info)
```

No caller exists yet. Later packets add the calls listed in [plan §7](../12-game-feel.md#7-cue--effect-matrix).

### 9. Smoke-test the effects in the real scene

Write a temporary probe (do not commit it) that starts `scenes/main.tscn` with seed `first-shore`, then near the player:

- spawns one of each: a SPARKLE burst, a DUST burst, a `FeelRing` and a `FeelFloater`
- pauses the tree while they play

Observe that:

- sparkles and dust face the camera and fade
- the ring expands and frees itself
- the floater rises and frees itself
- all of them keep animating while paused
- the node count returns to its starting value
- the log shows no shader compile errors

Also confirm that fish bubbles and turtle sand kicks look unchanged: run `tests/validate_wildlife.gd` and view a reef school.

## Reduced motion

Nothing visible is enabled by this packet. The `FeelFloater.spawn(..., reduced)` path must already fade in place.

## Checks

- `tests/run_checks.gd`: boot, asset closure, input and ownership.
- `tests/validate_wildlife.gd`: `ParticlePool` callers are unchanged.
- Launch `scenes/main.tscn` and confirm there are no errors in the log.

## Done when

- The baseline is recorded.
- The shared resource, helpers, pools, ring, floater and cue method exist and compile.
- The smoke probe shows each effect rendering, running under pause and freeing itself.
- Wildlife particles are unchanged.
- The handoff lists files and results.
