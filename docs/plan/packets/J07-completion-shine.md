# J07 — The "done" gleam: set shine and clean gleam

Dependencies: J05. It uses J00's floaters and pools and J06's cloth cue. Read first: [plan](../12-game-feel.md) §3 (PowerWash-style part shimmer; A Little to the Left solved glint), §4 rule 6, §6 tiers 1–2, §8 and §11.2 (`validate_placement.gd` sweep contract).

**Outcome.** One recognizable "done" treatment, applied at two sizes:

- **Set complete (tier 2):** when a logical prop group completes, including replays, a bright warm-white band with a turquoise fringe sweeps diagonally across every prop in the set, left to right on screen. A rim flash travels with the band and small glints sparkle inside it. Sparkles pop above each prop as the band passes. A floater rises from the set: `+$15` on the first completion, `Tidy!` on replays.
- **Object clean (tier 1):** when the last stain on a prop is wiped, the prop gets the same band (0.6 s), eight sparkles and a `Clean!` floater.

This replaces the mint world-X band in `group_sweep.gdshader`.

**Own files:**

| File | Change |
|---|---|
| `shaders/feel_shine.gdshader`, `scripts/feel/feel_shine.gd` | New |
| `shaders/group_sweep.gdshader` | Delete once unused |
| `scripts/items/placement_service.gd` | `_on_group_completed`, `_show_group_sweep` |
| `scripts/items/world_item.gd` | `play_gleam` |
| `scripts/tools/cloth_tool.gd` | Call the gleam |

## Steps

### 1. Shine shader

```glsl
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// "Done" gleam applied as a per-effect material_overlay. A diagonal band crosses the
// object set; a rim flash and sparse glints ride with it. Additive: output is light only.
uniform vec3 sweep_origin;
uniform vec3 sweep_direction = vec3(1.0, 0.0, 0.0);
uniform float sweep_distance = 1.0;
uniform float progress = 0.0;       // -0.15 .. 1.15 animated by FeelShine
uniform float band_width = 0.22;    // fraction of sweep_distance
uniform vec4 core_color : source_color = vec4(1.0, 0.973, 0.902, 1.0);
uniform vec4 fringe_color : source_color = vec4(0.561, 0.953, 0.878, 1.0);
uniform float intensity = 1.0;
uniform float rim_strength = 0.45;
uniform float glint_density = 18.0;

varying vec3 world_position;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = dot(world_position - sweep_origin, sweep_direction) / max(sweep_distance, 0.01);
	float d = along - progress;
	float core = 1.0 - smoothstep(0.0, band_width * 0.35, abs(d));
	float fringe = 1.0 - smoothstep(band_width * 0.2, band_width, abs(d));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5) * rim_strength * (1.0 - smoothstep(0.0, 0.6, abs(d)));
	float glint = step(0.93, hash13(floor(world_position * glint_density))) * fringe;
	vec3 light = core_color.rgb * (core * 1.2 + glint * 0.8) + fringe_color.rgb * (fringe * 0.35 + rim);
	ALBEDO = light * intensity;
}
```

### 2. `FeelShine` helper

```gdscript
class_name FeelShine
extends RefCounted
## Sweeps the shine band across `meshes`. Every call creates its own material, so no other
## instance of the same mesh ever flashes; overlays are cleared only if still ours.

const FEEL := preload("res://data/feel/feel_tuning.tres")
const SHADER := preload("res://shaders/feel_shine.gdshader")


## Returns {"material", "origin", "direction", "distance"} or {} when there is nothing to shine.
static func play(owner: Node, meshes: Array[MeshInstance3D], seconds: float) -> Dictionary:
	if meshes.is_empty() or owner == null or not owner.is_inside_tree():
		return {}
	var camera := owner.get_viewport().get_camera_3d()
	var angle := deg_to_rad(FEEL.shine_angle_degrees)
	var direction := Vector3.RIGHT
	if camera != null:
		direction = (camera.global_basis.x * cos(angle) + camera.global_basis.y * sin(angle)).normalized()
	var origin := meshes[0].global_position
	var minimum := INF
	var maximum := -INF
	for mesh in meshes:
		var box := mesh.global_transform * mesh.get_aabb()
		for corner in 8:
			var offset := (box.get_endpoint(corner) - origin).dot(direction)
			minimum = minf(minimum, offset)
			maximum = maxf(maximum, offset)
	var distance := maxf(maximum - minimum, 0.1)
	var start := origin + direction * minimum
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("sweep_origin", start)
	material.set_shader_parameter("sweep_direction", direction)
	material.set_shader_parameter("sweep_distance", distance)
	material.set_shader_parameter("band_width", FEEL.shine_band_width)
	material.set_shader_parameter("core_color", FEEL.shine_core_color)
	material.set_shader_parameter("fringe_color", FEEL.shine_fringe_color)
	for mesh in meshes:
		mesh.material_overlay = material
	var t := FeelMotion.tween(owner)
	t.tween_method(func(p: float) -> void:
		material.set_shader_parameter("progress", p)
		material.set_shader_parameter("intensity", FEEL.shine_intensity * smoothstep(-0.15, 0.0, p) * (1.0 - smoothstep(1.0, 1.15, p)))
	, -0.15, 1.15, seconds)
	t.tween_callback(func() -> void:
		for mesh in meshes:
			if is_instance_valid(mesh) and mesh.material_overlay == material:
				mesh.material_overlay = null
	)
	return {"material": material, "origin": start, "direction": direction, "distance": distance}
```

The direction is camera-relative: screen-right tilted 20° up. The band therefore always reads as a left-to-right diagonal glint, whatever the shelf orientation. This fixes the old world-X sweep, which ran toward or away from the camera on some shelves.

### 3. Set shine in `PlacementService`

1. Add `var _group_rewards: Dictionary = {}`. In `_on_group_completed(payload)`, add `_group_rewards[group_id] = int(payload.get("reward", 0))`. Keep the serial logic.
2. Restructure `_show_group_sweep(group_id, serial)`:

```gdscript
func _show_group_sweep(group_id: StringName, serial: int) -> void:
	if not is_inside_tree() or int(_group_sweep_serials.get(group_id, 0)) != serial:
		return
	if not session.state.group_states.has(group_id) or not bool((session.state.group_states[group_id] as Dictionary).complete):
		return
	var meshes: Array[MeshInstance3D] = []
	var tops: Array[Vector3] = []
	for item_id in session.progress_service.group_items.get(group_id, []):
		var root := slotted_visual_root(item_id)
		if root == null:
			continue
		_collect_sweep_meshes(root, meshes)
		tops.append(root.global_position + Vector3.UP * WorldItem.profile_size(_definition_for_item(item_id).collision_profile).y)
	if tops.is_empty():
		return
	var reduced := _reduced_motion()
	var reward := int(_group_rewards.get(group_id, 0))
	var center := Vector3.ZERO
	var highest := -INF
	for top in tops:
		center += top
		highest = maxf(highest, top.y)
	center /= float(tops.size())
	FeelFloater.spawn(self, Vector3(center.x, highest + 0.35, center.z), "+$%d" % reward if reward > 0 else "Tidy!", FEEL.money_color if reward > 0 else FEEL.shine_core_color, reduced)
	if reduced:
		return
	var shine := FeelShine.play(self, meshes, FEEL.group_sweep_seconds)
	if shine.is_empty():
		return
	for top in tops:
		var along := clampf((top - (shine.origin as Vector3)).dot(shine.direction as Vector3) / float(shine.distance), 0.0, 1.0)
		get_tree().create_timer(along * FEEL.group_sweep_seconds).timeout.connect(func() -> void:
			if is_instance_valid(sparkles):
				sparkles.burst(top, Vector3.UP, FEEL.set_sparkles_per_item, 0.4, 0.3, Vector2(0.05, 0.09), 0.6)
		)
```

- `create_timer` runs with `process_always = true` by default, so sparkles still fire if the results screen pauses the tree mid-sweep.
- Keep `group_sweep_seconds` at or below 0.8. `validate_placement.gd` waits 0.9 s for the overlay to clear, requires overlays only on that group's meshes, and requires none under reduced motion. All three still hold.
- Remove `GROUP_SWEEP_SHADER` and delete `shaders/group_sweep.gdshader` once nothing references it (`git grep group_sweep`).

### 4. Clean gleam

Add to `WorldItem`:

```gdscript
func play_gleam(reduced: bool) -> void:
	var top := global_position + Vector3.UP * profile_size(definition.collision_profile).y
	if effects != null:
		FeelFloater.spawn(effects, top + Vector3.UP * 0.25, "Clean!", FEEL.shine_core_color, reduced)
		effects.feel_sparkles(top, FEEL.clean_sparkles / (2 if reduced else 1))
	if reduced:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_gleam_meshes(visual_root, meshes)
	FeelShine.play(self, meshes, FEEL.clean_gleam_seconds)


func _collect_gleam_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is DirtVisual or child.has_meta(HoverHighlight.MARK):
			continue
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null and (child as MeshInstance3D).visible:
			result.append(child as MeshInstance3D)
		_collect_gleam_meshes(child, result)
```

In `ClothTool.try_clean`, after J06's cue, add `if done and view != null: view.play_gleam(FeelMotion.reduced(player.settings_store))`. Ownership and completion are unaffected: the prop is still `WORLD` and only becomes complete when placed.

## Reduced motion

- No shine overlay. This is the existing check: "reduced motion omits the group sweep".
- No sparkle line.
- Floaters still appear and fade in place, without rising or popping.
- The clean gleam becomes `Clean!` plus half the sparkles.

## Validation

1. `validate_placement.gd` passes unchanged:
   - the sweep is present on the completed group only
   - an unrelated slotted ball does not share the material
   - the overlay clears within 0.9 s
   - there is no overlay under reduced motion

   Use `-- --capture` to replace `P27-group-sweep.png` with the new look.
2. `validate_completion.gd` and `validate_dirt.gd` pass.
3. In the placement lab and the main scene, record:
   - a first-time bucket set (with `+$15`)
   - the same set re-completed (`Tidy!`, no second payment)
   - a lounge chair row seen from the front and from the side (the band still reads left to right)
   - a two-stain chair cleaned to `Clean!`

   Check readability on bright sand and in hut shade, and check the glow threshold.
4. Glass props are not placeable, but glass litter can be near a set. Confirm the band never touches unrelated items.

## Done when

- Sets and cleaned props gleam with the shared vocabulary.
- Money floaters appear only on the first completion.
- The overlays are per-effect and self-clearing.
- Checks pass.
- Reduced motion is observed.
- Clips and stills are in J-feel.
