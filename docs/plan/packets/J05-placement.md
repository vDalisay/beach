# J05 — Placement that glides, drops and settles

Dependencies: J04. Read first: [plan](../12-game-feel.md) §4, §6 tier 0, §8 and §11.2 (`validate_placement.gd`, `validate_full_run.gd`). Also [P10](P10-placement.md) and R09: *"show an object-shaped placement ghost… move the prop into place, orient it to the slot front, and pulse its visual scale"*.

**Outcome:**

- **Ghost:** the ghost is a living mint hologram of the actual prop, with a fresnel rim, slow rising scan lines and a gentle breath. It materializes when first shown, glides magnetically between adjacent slots instead of popping, and fades when the aim leaves. An optional soft contact blob grounds it.
- **Placement:** the prop leaves the hand at its in-hand scale, grows to full size along an arc, and drops the last few centimetres onto the slot. It lands with a squash, a rebound and a settle, plus a small contact ring, dust and sparkles. Neighbours on the same shelf wobble slightly, like books settling.
- **Physical capture:** a thrown prop that lands in a valid slot gets a quicker "magnet" travel and a bigger sparkle, as a reward for a good throw.
- **Removal:** taking a prop off a shelf also nudges its neighbours.

**Own files:**

| File | Change |
|---|---|
| `shaders/placement_ghost.gdshader` | Rewrite |
| `scripts/items/placement_service.gd` | Ghost, travel, landing, pools, cues |
| `scripts/items/world_item.gd` | Delete the unused `pulse()` if J01 has not |

## Steps

### 1. Ghost shader

```glsl
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

// Placement hologram: soft fill, bright fresnel rim, rising scan lines, gentle breath.
uniform vec4 ghost_color : source_color = vec4(0.5, 0.96, 0.78, 1.0);
uniform float fill_alpha = 0.16;
uniform float rim_alpha = 0.85;
uniform float rim_power = 2.0;
uniform float scan_density = 14.0;  // lines per metre
uniform float scan_speed = 0.35;    // metres per second
uniform float breath_amount = 0.12; // 0 under reduced motion
uniform float appear = 1.0;         // script animates 0 -> 1 on show, 1 -> 0 on fade

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float line = 1.0 - smoothstep(0.0, 0.08, fract(world_position.y * scan_density - TIME * scan_speed * scan_density));
	float breath = 1.0 + breath_amount * sin(TIME * 6.2831853 * 1.2);
	float alpha = (fill_alpha + line * 0.08 + rim * rim_alpha) * breath;
	ALBEDO = mix(ghost_color.rgb, vec3(1.0), rim * 0.5 + line * 0.3);
	ALPHA = clamp(alpha, 0.0, 1.0) * appear;
}
```

This build switches from `cull_disabled` + `depth_prepass_alpha` to `cull_back` + `depth_draw_never`. Inner faces no longer muddy the hologram, and the ghost never occludes the shelf behind it.

### 2. One ghost that glides (`PlacementService`)

Replace `static var _ghost_material` with per-ghost state:

```gdscript
var _ghost_visual: Node3D
var _ghost_item_id: StringName
var _ghost_blob: MeshInstance3D
```

Rewrite `_show_ghost(slot_id, item_id)`:

1. If `_preview_slot_id == slot_id`, return, as today.
2. Compute `ghost_root` and its `offset` exactly as today (`area.global_basis.inverse() * Vector3.UP * _upright_offset(...)`).
3. **Glide:** if `_ghost_visual` is valid, `_ghost_item_id == item_id` and reduced motion is off:
   1. Remember the previous `GhostRoot`.
   2. `_ghost_visual.reparent(ghost_root, true)`, keeping the world pose.
   3. Set `ghost_root.position = offset` and `ghost_root.show()`.
   4. Hide the previous root if it is a different node.
   5. Run a `FeelMotion.replace(_ghost_visual, &"glide", FeelMotion.tween(_ghost_visual))` tween of `transform` to `Transform3D.IDENTITY` over `FEEL.ghost_glide_seconds` (`TRANS_CUBIC`/`EASE_OUT`).
4. **New ghost (otherwise):**
   1. Call `clear_preview()` (instant).
   2. Set `ghost_root.position = offset`.
   3. `_ghost_visual = _create_visual(definition)` and add it to `ghost_root`.
   4. Create a new `ShaderMaterial` with `GHOST_SHADER` for this ghost and set its uniforms from `FEEL`:

      | Uniform | Value |
      |---|---|
      | `ghost_color` | `FEEL.ghost_color` |
      | `fill_alpha` | `FEEL.ghost_fill_alpha` |
      | `rim_alpha` | `FEEL.ghost_rim_alpha` |
      | `scan_density` | `FEEL.ghost_scan_density` |
      | `breath_amount` | `0.0` when reduced, otherwise `FEEL.ghost_breath` |
      | `scan_speed` | `0.0` when reduced |
   5. Apply it recursively with `_apply_ghost_material(_ghost_visual, material)`, store it as `_ghost_visual.set_meta(&"ghost_material", material)`, then call `ghost_root.show()` and set `_ghost_item_id = item_id`.
   6. Unless reduced: set `_ghost_visual.scale = Vector3.ONE * 0.92`, then tween `scale` to ONE (`TRANS_BACK`/`EASE_OUT`) together with a `tween_method` setting `appear` 0 → 1, both over `FEEL.ghost_appear_seconds`. When reduced, `appear = 1` and the scale stays at ONE.
5. Set `_preview_slot_id = slot_id`. `GhostRoot.visible` must be true synchronously after `preview_slot()` returns ok; both checks read it immediately.

Rewrite `clear_preview(fade := false)`:

- **No preview:** reset the ids and free any orphaned ghost.
- **Otherwise:** get the current root and clear `_preview_slot_id`.
  - If `fade` is true, the ghost is valid and motion is not reduced:
    1. Reparent the visual to `self`, keeping its global pose.
    2. Hide the old root at once.
    3. Tween its `ghost_material` `appear` 1 → 0 over 0.06 s, then `queue_free()` it.
    4. Null the fields.
  - Otherwise, hide the root, free its children and null the fields.

Call sites:

- `_on_target_changed` calls `clear_preview(true)`: the aim left the slot.
- `try_place`, `try_remove` and `target_result` for occupied slots keep instant clears.

**Optional contact blob (grounding).** A world-space `MeshInstance3D` owned by `PlacementService`:

- a `PlaneMesh` sized to the prop's footprint (`WorldItem.profile_size(...)` x/z × 1.3)
- an unshaded, alpha, depth-draw-disabled `StandardMaterial3D` with a radial `GradientTexture2D` (black at alpha 1 → alpha 0) and `albedo_color = Color(0, 0, 0, FEEL.ghost_blob_alpha)`

Show it at `(slots[slot_id].transform as Transform3D).origin + Vector3.UP * 0.006` with a world-horizontal basis. Tween its position with the glide and hide it on clear. Skip it for `UPRIGHT` and `MOORING` layouts if it looks wrong there, and record that.

### 3. Travel that arcs and drops

Rewrite `_animate_to_slot(item_id, slot_id, source_transform, physical_view := null)`:

```gdscript
func _animate_to_slot(item_id: StringName, slot_id: StringName, source_transform: Transform3D, physical_view: WorldItem = null) -> void:
	var descriptor := slots[slot_id] as Dictionary
	var area := descriptor.area as Area3D
	var definition := _definition_for_item(item_id)
	var destination := Marker3D.new()
	area.add_child(destination)
	destination.position = area.global_basis.inverse() * Vector3.UP * _upright_offset((descriptor.transform as Transform3D).basis, WorldItem.profile_size(definition.collision_profile))
	var reduced := _reduced_motion()
	var capture := physical_view != null
	var finish := func() -> void:
		if is_instance_valid(destination):
			destination.queue_free()
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.SLOTTED and record.slot_id == slot_id:
			_ensure_slotted_view(item_id)
			_land_slotted_view(item_id, slot_id, capture)
			_try_start_pending_sweeps()
	var distance := source_transform.origin.distance_to(destination.global_position)
	var seconds := FEEL.capture_travel_seconds if capture else FeelMotion.travel_seconds(distance, FEEL.place_travel_base, FEEL.place_travel_per_meter, FEEL.place_travel_max)
	var options := {} if reduced else {"arc": FEEL.place_arc_height * (0.5 if capture else 1.0), "drop": FEEL.place_drop_height}
	if capture:
		options["reduced"] = reduced
		physical_view.travel_to(destination, seconds, false, finish, options)
		return
	var presentation := _create_visual(definition)
	add_child(presentation)
	presentation.global_transform = source_transform
	presentation.scale = Vector3.ONE * (0.4 if definition.hand_cost == 2 else 0.35)
	options["shrink_to"] = 1.0
	options["shrink_from"] = 0.0
	FeelMotion.travel(presentation, self, global_transform.affine_inverse() * destination.global_transform, seconds, options, func() -> void:
		presentation.queue_free()
		finish.call()
	)
```

- The presentation starts at the in-hand scale (0.35, or 0.4 for two-hand props, matching `PlayerCarry._scale_hand_visual`) and grows to full scale on the way. This removes the old size pop at the hand.
- The cubic path uses the `drop` option (J00): it rises, then comes down vertically onto the slot.
- **Timing contract:** `validate_placement.gd` waits 35 physics frames (~0.58 s) after `try_place` and then requires `VisualRoot.scale == ONE`. Keep `place_travel_max + land_seconds ≤ 0.52` (defaults: 0.30 + 0.22). If tuning needs more, change that wait to 45 frames in the same commit and say so in the handoff.

### 4. Land, contact and neighbours

Replace `_pulse_slotted_view` with `_land_slotted_view(item_id, slot_id, capture)`:

1. Get the slotted view's `VisualRoot` (`slotted_visual_root`).
2. If reduced, set its scale to ONE and return. R09's pulse is intentionally removed under reduced motion (P27), and placement travel is kept.
3. Otherwise:
   - `FeelMotion.squash_land(root, FEEL.land_squash, FEEL.land_rebound, FEEL.land_seconds)`. The peak deviation stays within the architecture's 8% pulse.
   - `FeelRing.spawn(self, base + Vector3.UP * 0.02, 0.15, 0.8 if capture else 0.55, 0.28, FEEL.shine_core_color if capture else FEEL.ghost_color, 0.05)`, where `base` is the slot origin.
   - `sparkles.burst(base + Vector3.UP * 0.1, Vector3.UP, FEEL.land_sparkles * (2 if capture else 1), 0.6, 0.5, Vector2(0.05, 0.08), 0.5)` and `dust.burst(base + Vector3.UP * 0.03, Vector3.UP, 5, 0.5, 0.4, Vector2(0.04, 0.07), 0.45)`.
   - `_wobble_neighbors(slot_id, 1.0)`.

Create the pools in `configure()` when `player != null`: `sparkles` (SPARKLE, 128, `process_always`) and `dust` (DUST, 32, `process_always`, `tint = FEEL.dust_color`), both children of the service.

Add:

```gdscript
func _wobble_neighbors(slot_id: StringName, strength: float) -> void:
	if _reduced_motion() or not slots.has(slot_id):
		return
	var origin := (slots[slot_id].transform as Transform3D).origin
	var pool_id := StringName(str((slots[slot_id] as Dictionary).pool_id))
	var occupants := (session.state.container_records[pool_id] as Dictionary).get("occupants", {}) as Dictionary
	for other_key in occupants:
		var other_slot := StringName(str(other_key))
		if other_slot == slot_id or not slots.has(other_slot):
			continue
		var root := slotted_visual_root(StringName(str(occupants[other_key])))
		var distance := origin.distance_to((slots[other_slot].transform as Transform3D).origin)
		if root == null or distance > FEEL.neighbor_wobble_radius:
			continue
		var angle := deg_to_rad(FEEL.neighbor_wobble_degrees) * strength * (1.0 - distance / FEEL.neighbor_wobble_radius)
		var t := FeelMotion.replace(root, &"wobble", FeelMotion.tween(root))
		t.tween_interval(distance * 0.04)
		t.tween_property(root, "rotation:z", angle, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(root, "rotation:z", -angle * 0.5, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(root, "rotation:z", 0.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
```

Call `_wobble_neighbors(slot_id, 0.6)` from `try_remove` after the commit.

### 5. Cues

- `try_place` on success: before removing the prop from `held`, compute `arm`:
  - `&"both"` for `hand_cost == 2`
  - `&"left"` when `selected_held_index == 0`
  - `&"right"` otherwise

  After `finalize_action`, call `player.play_cue(&"place", {"arm": arm})` if `player != null`.
- `_on_primary_requested` on failure: `player.play_cue(&"rejected", {"reason": result.message})`.
- `try_capture` does not send a player cue: it is not an input action. It only gets the capture landing.

## Reduced motion

- **Ghost:** appears at rest and snaps between slots. No breath. The scan lines still move slowly; set `scan_speed = 0` when reduced.
- **Travel:** straight, with no arc or drop.
- **Landing:** no squash, ring or wobble. Sparkles at half count. Group sweeps stay with J07.

## Validation

1. `validate_placement.gd` must pass unchanged:
   - `GhostRoot` visible
   - claim, occupancy and family behaviour
   - the capture path
   - scale back to ONE within 35 frames
   - sweeps

   Also run `validate_completion.gd`. Run `validate_full_run.gd` once at the end of the packet; it is heavy.
2. In `tests/scenes/placement_lab.tscn`, run `validate_placement.gd -- --capture`. Then use a probe to walk the aim across the two shared shelves slowly: the ghost glides between slots and fades when the aim leaves. Record a clip.
3. In `scenes/main.tscn` (seed `feedback-sequence`, which `tests/record_feedback.gd` already stages), record:
   - placing a chair in a lounge row
   - two buckets on a shelf (neighbour wobble)
   - an upright surfboard
   - throwing a ball into an empty shelf slot (capture magnet)
   - removing a bucket

   Take stills of the ghost on bright sand, in the hut and at 2.5 m.
4. Confirm the ghost never occludes the shelf and that no ghost or presentation node remains afterwards (node count before and after).
5. Toggle reduced motion and repeat one placement.

## Done when

- The ghost materializes, glides and fades.
- Placement arcs, drops and settles with contact and neighbour feedback, and captures feel rewarded.
- The existing placement, completion and full-run checks pass within their timing.
- Reduced motion keeps travel only.
- Clips are in J-feel.
