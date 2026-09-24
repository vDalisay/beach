# J11 — Nature returns: restoration bloom, beacon and pointer

Dependencies: J07 (shine vocabulary, floaters) and J09 (notice glyphs, `main.gd` sequence). Read first: [plan](../12-game-feel.md) §0 (no forced camera motion), §4 rule 3 (never replay on load), §6 tiers 3–4, §8 and §9 (wave cap). Also R22 and R23, D04, and [P27](P27-feel-accessibility.md) step 3: *"Nature-return events should be visible from sensible nearby viewpoints without forcing camera movement."*

**Outcome:**

- **Section restored:** a soft wall of light rises at the section centre and expands across about 12 m in 1.8 s. It is warm cream on the shore and turquoise on the reef, brightest at the ground and fading upward, with sparkles along its front.
- **Staged reveal:** the restored dressing (palms, coral, starfish, buoys, clarity patch) pops in as the wave reaches each piece. Coral warms to its restored colour on the same schedule, and fish burst out (existing).
- **Zone restored:** the same effect, larger (22 m), plus the existing wildlife intros.
- **When the player is far or looking away:** a soft light column (beacon) marks the spot for about 3.5 s. A screen-edge arrow points to it with the distance. The banner adds distance and direction ("…restored · 42 m ahead-left").
- **Batching:** three or more sections in one commit (a big truck collection) produce one "N areas restored" banner.
- **Load:** loading a save shows restored areas instantly, with no replay.

**Own files:**

| File | Change |
|---|---|
| `shaders/feel_wave.gdshader`, `scripts/feel/restoration_wave.gd` | New |
| `scripts/world/restoration_section.gd` | Live-signal handlers and helpers only |
| `scripts/ui/restoration_pointer.gd` | New |
| `scenes/main.tscn` | Add `RestorationPointer` under `UI`, above the HUD and below modal views |
| `scripts/main.gd` | Restoration notices and pointer |
| `scripts/tools/scanner.gd` | Rename `_direction` to the public `direction_words` |

## Steps

### 1. Wave shader and node

`shaders/feel_wave.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Expanding "life returns" light wall (open cylinder). Brightest at its base.
uniform vec4 wave_color : source_color = vec4(1.0, 0.945, 0.788, 1.0);
uniform float intensity = 1.0;
uniform float wall_height = 1.2;
uniform float shimmer = 0.35;

varying vec3 local_position;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float height = clamp(local_position.y / wall_height + 0.5, 0.0, 1.0);
	float fade = pow(1.0 - height, 2.2);
	float angle = atan(local_position.z, local_position.x);
	float streak = hash12(vec2(floor(angle * 40.0), floor(TIME * 8.0)));
	ALBEDO = wave_color.rgb * fade * (1.0 - shimmer + shimmer * streak) * intensity;
}
```

`scripts/feel/restoration_wave.gd`:

```gdscript
class_name RestorationWave
extends MeshInstance3D
## Self-freeing expanding light wall (restoration) and vertical light column (beacon).

const FEEL := preload("res://data/feel/feel_tuning.tres")
const SHADER := preload("res://shaders/feel_wave.gdshader")

static var _mesh: CylinderMesh
static var _live := 0


static func spawn(parent: Node, ground: Vector3, radius: float, seconds: float, color: Color) -> RestorationWave:
	var wave := _make(parent, color)
	if wave == null:
		return null
	wave.global_position = ground + Vector3.UP * (FEEL.wave_height * 0.5 - 0.35)
	var material := wave.material_override as ShaderMaterial
	var t := FeelMotion.tween(wave)
	t.tween_method(func(p: float) -> void:
		var r := lerpf(0.4, radius, 1.0 - pow(1.0 - p, 2.0))
		wave.scale = Vector3(r, 1.0, r)
		material.set_shader_parameter("intensity", smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.6, 1.0, p)))
	, 0.0, 1.0, seconds)
	t.tween_callback(wave.queue_free)
	return wave


static func spawn_beacon(parent: Node, ground: Vector3, color: Color) -> RestorationWave:
	var beacon := _make(parent, color)
	if beacon == null:
		return null
	var stretch := FEEL.beacon_height / FEEL.wave_height
	beacon.scale = Vector3(0.6, stretch, 0.6)
	beacon.global_position = ground + Vector3.UP * (FEEL.beacon_height * 0.5 - 0.2)
	var material := beacon.material_override as ShaderMaterial
	var t := FeelMotion.tween(beacon)
	t.tween_method(func(p: float) -> void:
		material.set_shader_parameter("intensity", 0.8 * smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.7, 1.0, p)))
	, 0.0, 1.0, FEEL.beacon_seconds)
	t.tween_callback(beacon.queue_free)
	return beacon


static func _make(parent: Node, color: Color) -> RestorationWave:
	if _live >= FEEL.max_concurrent_waves or parent == null or not parent.is_inside_tree():
		return null
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 1.0
		_mesh.bottom_radius = 1.0
		_mesh.height = FEEL.wave_height
		_mesh.radial_segments = 48
		_mesh.rings = 1
		_mesh.cap_top = false
		_mesh.cap_bottom = false
	var node := RestorationWave.new()
	node.mesh = _mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("wave_color", color)
	material.set_shader_parameter("wall_height", FEEL.wave_height)
	node.material_override = material
	parent.add_child(node)
	_live += 1
	return node


func _exit_tree() -> void:
	_live = maxi(_live - 1, 0)
```

The wall is an intersection-based effect: wherever it passes through sand or seabed, a bright line shows along the ground, so it follows uneven terrain without decals (unavailable in Compatibility). Verify its look from above the water, from underwater, and when it crosses the water surface. If the additive wall draws over the water surface unconvincingly from above, lower its intensity when the camera is above water and the wave is below `WorldItem.WATER_LEVEL`, and record the change.

### 2. `RestorationSection` bloom (live signals only)

- Add `const FEEL := preload(...)`, `var _sparkles: ParticlePool` (SPARKLE, 192, `process_always`, a child of this node, created in `configure`) and `var _rng := RandomNumberGenerator.new()` (cosmetic; seed 7).
- Add public origins used by `main.gd`:
  - `section_origin(section_id) -> Vector3`: the centroid of `anchors[section_id]`, falling back to `sections[section_id].global_position`.
  - `zone_origin(zone_id) -> Vector3`: the centroid of that zone's section origins.
- Rewrite the two handlers, keeping the "already visible → return" guard and the population starts:

```gdscript
func _on_section_restored(section_id: StringName) -> void:
	if not sections.has(section_id):
		return
	var section := sections[section_id] as BeachSection
	if section.restoration_visual_root.visible:
		return
	section.restoration_visual_root.show()
	if _reduced_motion():
		_set_section_colors(section, false)
	else:
		var origin := section_origin(section_id)
		var reef := str(section.zone_id).begins_with("reef_")
		_bloom(section.restoration_visual_root, origin, FEEL.wave_radius_section)
		_set_section_colors(section, true, origin, FEEL.wave_radius_section)
		RestorationWave.spawn(section, origin, FEEL.wave_radius_section, FEEL.wave_seconds, FEEL.wave_color_reef if reef else FEEL.wave_color_shore)
		_sparkle_front(origin, FEEL.wave_radius_section, reef)
		_beacon_if_unseen(section, origin, reef)
	_start_section_population(section_id, false)
```

`_on_zone_restored(zone_id)` follows the same shape:

1. Show the zone root.
2. Unless reduced: `_bloom(root, zone_origin(zone_id), FEEL.wave_radius_zone)`, the wave with `wave_radius_zone`, the sparkle front and the beacon.
3. Then `_start_zone_population(zone_id, false)`.

`configure()` (the load path) is unchanged: it shows restored roots instantly with no effects.

Helpers:

- **`_bloom(root, origin, radius)`**:
  - Use `speed = radius / (FEEL.wave_seconds * 0.8)`.
  - For each direct `Node3D` child, skip it if it is a `FishSchool`, a `PathAnimal`, or contains one (`not child.find_children("*", "PathAnimal", true, false).is_empty()`). Scaling an animal's anchor would squash its route.
  - For each other child:
    1. Store `rest = child.scale` and set `child.scale = rest * 0.01`.
    2. Create a `FeelMotion.tween(child)`: `tween_interval(child.global_position.distance_to(origin) / speed)`.
    3. Tween `scale` to `rest` over `FEEL.bloom_pop_seconds` (`TRANS_BACK`/`EASE_OUT`).
    4. Then burst three sparkles at `child.global_position + Vector3.UP * 0.3`.
- **`_set_section_colors(section, animate, origin := Vector3.INF, radius := 0.0)`**: when `animate` and `origin` is finite, delay each child's existing 1.2 s albedo tween by its distance / speed, using the same speed as `_bloom`. Otherwise keep the current behaviour. This covers the reef coral that is already visible under `section` and only recolours.
- **`_sparkle_front(origin, radius, reef)`**:
  - Take `steps = int(FEEL.wave_seconds / FEEL.wave_sparkle_interval)`.
  - For each step `i`, create `get_tree().create_timer(i * interval)` (process-always by default). Its timeout emits `FEEL.wave_sparkles_per_step` sparkles at radius `r = lerp(0.4, radius, 1 - (1 - p)^2)`, where `p = i / steps`, at random angles from `_rng`.
  - Sparkle height: `reef ? origin.y + 0.2 : Coastline.surface_y(x, z) + 0.2`.
  - Colour: `FEEL.wave_color_reef` or a random `FEEL.sparkle_colors` entry.
- **`_beacon_if_unseen(parent, origin, reef)`**: take `camera = get_viewport().get_camera_3d()`. If the camera is null, or `camera.global_position.distance_to(origin) > FEEL.pointer_far_distance`, or `not camera.is_position_in_frustum(origin)`, call `RestorationWave.spawn_beacon(parent, origin, ...)`.

### 3. Pointer UI

`scripts/ui/restoration_pointer.gd` is a full-rect `Control` with `mouse_filter = IGNORE`. Its children are an `Arrow` (`FeelIcon`, kind ARROW, 28×28, gold) and a `Distance` label (gold, outlined, size 16).

- **API:** `point_to(world_position: Vector3, camera: Camera3D, seconds := FEEL.pointer_seconds)`.
- **`_process`** (hide and stop processing when expired or when the camera is invalid):
  1. `projected = camera.unproject_position(target)`. If `camera.is_position_behind(target)`, mirror it through the screen centre.
  2. `on_screen` means the projected point lies inside the viewport rect inset by 40 px.
  3. If `on_screen` and the distance is under `pointer_far_distance`, hide and stop: the player can see it.
  4. If `on_screen` but far, place the arrow above the projected point pointing down (`rotation = PI / 2`).
  5. Otherwise, clamp the direction from centre to an inset rectangle (left and right 80 px, top 140 px, bottom 150 px, which keeps it off the HUD lanes). Place the arrow there with `rotation = dir.angle()`.
  6. The label shows `"%d m" % distance` next to the arrow.
  7. Unless reduced, pulse the arrow's scale 1.0 ↔ 1.15 at 1.5 Hz.

### 4. Banner, batching and pointer in `main.gd`

1. Keep the `RestorationSection` created in `_open_run` in a field `_restoration`.
2. Replace the `section_restored` notice lambda with `_on_section_restored_notice(section_id)`. It appends to `_pending_sections` and `call_deferred("_flush_section_notices")` when the list was empty. J09's `play_cue(&"section_restored")` stays.
3. `_flush_section_notices()`:
   - If `count >= FEEL.banner_batch_threshold`, queue one notice: `"%d areas restored" % count`, priority 2, 3.0 s.
   - Otherwise, for each section, queue the existing text `"%s restored" % name`. Append `" · %d m %s" % [distance, session.scanner.direction_words(origin)]` when the distance exceeds `FEEL.pointer_far_distance`.
   - Point the pointer at the nearest unseen origin: `restoration_pointer.point_to(origin, player.camera)`.
   - The text must still contain "restored": `validate_completion.gd` checks it.
4. Do the same for zones (the "nature returns" text), with no batching needed.
5. In `ScannerService`, rename `_direction(position)` to the public `direction_words(position)` and update its internal call.
6. `clear_run()` hides the pointer.

## Reduced motion

- Restored dressing appears at once and colours set at once (existing behaviour).
- No wave, sparkles, pop-in or beacon.
- The banner still shows, with distance and direction. The pointer still shows, without the pulse.

## Validation

1. Re-run:
   - `validate_completion.gd`: full-beach and deep-reef restoration, 720p lanes, "restored" text
   - `validate_wildlife.gd`: populations and turtles are unaffected by the bloom exclusions
   - `validate_save.gd`: a restored load shows no replay
2. In `scenes/main.tscn` (seed `restoration-fixture`, the same staging `validate_completion.gd` uses), record:
   - the arrival section restoring while the player stands in it (the wave passes the player; pop-ins follow it)
   - the same from 40 m away at the S1 hotline (beacon, arrow, distance banner)
   - a reef section from underwater
   - a zone restore
   - a truck collection that restores three or more sections at once (one batched banner, at most 4 waves, sparkles within the pool cap)
3. Save right after a restoration and reload: no replay, and everything is in its final state.
4. **Profile:** stand in a restoring section with the crowded view. Record p95 and draws during the wave against the J00 baseline (budget: +1.5 ms p95 at most during the burst). Node count returns to baseline within 3 s.

## Done when

- Restoration reads as a clear event near and far, without moving the camera.
- The reveal follows the wave.
- Batching and the pointer work.
- Loads never replay.
- Checks and budget pass.
- Reduced motion is observed.
- Clips are in J-feel.
