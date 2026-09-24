# J06 — Every tool moves and answers back

Dependencies: J04, which provides J03's clips and J04's presentation paths. Read first: [plan](../12-game-feel.md) §7 (cue matrix), §7.1 (rejection sites) and §8. Tools are defined in `data/tools/*.tres`, and their handlers are the scripts under `scripts/tools/`.

**Outcome.** Each tool has three layers:

- a hand clip for its action
- a continuous "working" motion while in use
- a world response at the point of work

The player can tell which tool is active and whether it did anything without reading text.

| Tool | Hand | Continuous | World |
|---|---|---|---|
| Stick | Poke (J04); whiff on empty air | — | Stab-and-flick into bag (J04) |
| Cloth | Circular wipe | — | Stain smears and fades, two sparkles; last stain adds a gleam (J07) |
| Knife | Slash | — | Snip sparkles (bubbles underwater); cut litter flies to the bag or pops away as it drops; freed animal gets "FREED" pop, bubbles and ring |
| Detector | Dig on reveal | Sweep yaw while active; coil flash each ping | Ping rings speed up near finds; sand burst, pop-up and glint on reveal |
| Sand cleaner | Sift (push, dip, shake) | Gentle rock while aiming at sand | Rotating dashed area ring that brightens over litter; sand puff; ring contracts; items stream into the bag |
| Vacuum | Recoil per item; choke when the bag fills | Hum jitter | Suction motes flowing into the nozzle; items stretch into the nozzle |
| Scanner (booklet skill) | — | — | Sonar ring from the player; markers pop in |

**Own files:**

| File | Change |
|---|---|
| `scripts/tools/cloth_tool.gd`, `rescue_knife.gd`, `metal_detector.gd`, `sand_cleaner.gd`, `vacuum_tool.gd`, `scanner.gd` | Presentation and cue calls only |
| `scripts/items/dirt_visual.gd` | `clean()` |
| `scripts/items/world_item.gd` | `clean_dirt_patch` sparkle |
| `scripts/items/buried_find.gd` | `_animate_lift` |
| `scripts/wildlife/rescue_site.gd` | Detach visual, release celebration |
| `scripts/player/hand_rig.gd` | `flash_tool` |
| `scripts/items/item_view_manager.gd` | `reduced_motion()` helper |

Domain methods (`try_clean`, `try_cut`, `try_reveal`, `try_collect`, `pulse`) keep their validation and commit order exactly. Presentation calls go after `finalize_action`.

## Steps

### 1. Shared additions

- **`ItemViewManager.reduced_motion() -> bool`:** returns `FeelMotion.reduced((player as BeachPlayer).settings_store)` when the player is a `BeachPlayer`, otherwise false.
- **`HandRig.flash_tool(color: Color, seconds := 0.12)`:**
  - Return early when there is no tool or reduced motion is on.
  - Create one unshaded, additive, alpha `StandardMaterial3D` with `albedo_color = color`.
  - Set it as `material_overlay` on every `MeshInstance3D` under the current tool instance.
  - Tween its `albedo_color:a` to 0 over `seconds` with `FeelMotion.tween`.
  - Then clear each overlay that still equals this material.

### 2. Stick

- J04 already provides the poke and the tip path. Here, only verify and tune `FEEL.tool_tips[&"stick"]`, `stick_tip_fraction` and `bag_mouth` at FOV 70 and 110, including collecting from knee height (crouched) and from a pile edge.
- **Whiff:** J03 maps `whiff` to a 60% poke. Confirm that clicking empty air pokes without a reticle pop, and that clicking a blocked target ("Bag full") plays the reject clip instead.

### 3. Cloth

In `ClothTool.try_clean`, after `view.clean_dirt_patch(patch_id)`:

```gdscript
var done := record.dirty_patches_remaining.is_empty()
if player != null:
	player.play_cue(&"clean_done" if done else &"clean", {"item_id": str(item_id)})
```

J07 adds the gleam for `done`. In `_on_primary_requested`, on failure, add `player.play_cue(&"rejected", {"reason": result.message})`.

`WorldItem.clean_dirt_patch(patch_id)`:

- Before `patch.clean()`, if `effects != null`, call `effects.feel_sparkles(patch.global_position + Vector3.UP * 0.03, 2)`.
- Call `patch.clean(effects.reduced_motion() if effects != null else false)`.

Rewrite `DirtVisual.clean(reduced := false)` as a smear, not a shrink:

```gdscript
func clean(reduced := false) -> void:
	collision_layer = 0
	collision_mask = 0
	var t := FeelMotion.tween(self)
	if reduced:
		t.tween_property(mesh, "transparency", 1.0, 0.18)
	else:
		t.set_parallel(true)
		t.tween_property(mesh, "transparency", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", _base_scale * Vector3(1.35, 0.6, 1.0), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "position", position + transform.basis.x.normalized() * 0.03, 0.22)
	t.chain().tween_callback(queue_free)
```

`validate_dirt.gd` checks counts and IDs, not the tween, so it keeps passing. Re-run it.

### 4. Knife

In `RescueSite`, add:

```gdscript
## Removes and returns the attachment's visual (not its Area3D) so it can be presented.
func detach_attachment_visual(item_id: StringName) -> Node3D:
	var area := attachment_area(item_id)
	if area == null:
		return null
	for child in area.get_children():
		if child is Node3D and not (child is CollisionShape3D):
			var from := (child as Node3D).global_transform
			area.remove_child(child)
			child.set_meta(&"from_transform", from)
			return child as Node3D
	return null
```

In `RescueKnife.try_cut`:

1. Directly before `site.remove_attachment(item_id)`, add `var at := area.global_position` and `var visual := site.detach_attachment_visual(item_id)`.
2. After `finalize_action`, add:

```gdscript
var reduced := FeelMotion.reduced(player.settings_store)
var manager := session.item_view_manager
if at.y < WorldItem.WATER_LEVEL - 0.05:
	manager.bubbles.burst(at, Vector3.UP, 3 if reduced else 6, 0.5, 0.2, Vector2(0.01, 0.025), 1.4)
manager.feel_sparkles(at, 3 if reduced else 6, Color.WHITE)
player.play_cue(&"cut", {"item_id": str(item_id)})
if visual != null:
	var from: Transform3D = visual.get_meta(&"from_transform")
	if destination == "bag":
		player.carry.present_visual(item_id, visual, from, player.hand_rig.bag_socket, FEEL.bag_end_scale,
			func() -> void: player.play_cue(&"bag_catch"))
	else:
		site.add_child(visual)
		visual.global_transform = from
		var t := FeelMotion.tween(visual)
		t.tween_property(visual, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(visual.queue_free)
		manager.feel_puff(drop_pose.origin, reduced)
if freed:
	player.play_cue(&"animal_freed", {"site_id": str(site_id)})
```

In `try_click`, on the failure branches, add `player.play_cue(&"rejected", {"reason": ...})`.

Change `RescueSite.release_animal()` to `release_animal(reduced := false)`, and `RescueKnife` passes the setting. It celebrates, then starts the route without hiding the label at once:

1. Call `refresh()`. It sets "FREED" in green.
2. `animator.exhale()` if the Animator exists. It already produces bubbles.
3. `FeelRing.spawn(self, animal.global_position + Vector3.UP * 0.05, 0.3, 1.4, 0.6, FEEL.wave_color_reef, 0.08)`.
4. Unless reduced, pop the label: `status_label.scale = Vector3.ONE * 0.4`, then tween to 1.25 (0.12 s) and 1.0 (0.12 s).
5. Hold it for `FEEL.freed_label_seconds`, fade `modulate:a` to 0 over 0.4 s, then `hide()` it and restore `modulate.a = 1`.
6. Call `_start_route(false)`.

`_start_route(hide_label := true)` hides the label only when `hide_label` is true. `configure()` of an already-released site keeps calling `_start_route()`, so loads never replay the celebration.

### 5. Metal detector

In `MetalDetector._physics_process`:

- When not active, keep the existing hides.
- When active:
  - Call `player.hand_rig.set_tool_activity(&"detector", 0.3 if nearest_find == null else 0.3 + 0.7 * strength)`.
  - Advance `_ping_elapsed += delta`.
  - With a signal, when `_ping_elapsed >= lerpf(FEEL.detector_ping_far_seconds, FEEL.detector_ping_near_seconds, strength)`, reset it and call `_ping(strength)`.
- Replace the `marker.scale = … sin(...)` line with `marker.scale = Vector3.ONE`. The rings now carry the rhythm.

```gdscript
func _ping(strength: float) -> void:
	FeelRing.spawn(self, marker.global_position + Vector3.UP * 0.01, 0.2, FEEL.detector_ring_radius, 0.5, FEEL.detector_color, 0.05)
	player.hand_rig.flash_tool(FEEL.detector_color, 0.12)
	strength_bar.modulate = Color(1.35, 1.25, 1.0)
	FeelMotion.tween(strength_bar).tween_property(strength_bar, "modulate", Color.WHITE, 0.15)
	player.play_cue(&"detector_ping", {"strength": strength})
```

- Rings are positional feedback and stay under reduced motion; the tool flash does not.
- `try_click`: on success, `player.play_cue(&"reveal")`; on failure, `player.play_cue(&"rejected", {"reason": result.message})`.

Rewrite `BuriedFind._animate_lift(item_id)`:

1. After the existing `await get_tree().physics_frame`, compute `at = record.dig_surface_position`, `valuable = definition.kind == ItemDefinition.Kind.VALUABLE` and `reduced`.
2. Always:
   - `manager.dust.burst(at + Vector3.UP * 0.02, Vector3.UP, 7 if reduced else 14, 1.4, 0.6, Vector2(0.03, 0.06), 0.6, FEEL.sand_color)`
   - `manager.feel_sparkles(at + Vector3.UP * 0.15, 3 if reduced else 6, FEEL.sparkle_colors[1] if valuable else Color(0, 0, 0, 0))`
   - `FeelRing.spawn(self, at + Vector3.UP * 0.02, 0.9, 0.1, 0.25, FEEL.detector_color, 0.05)` (a collapsing ring)
3. If the view is valid and motion is not reduced:
   - Set `visual_root.position.y = -0.3`.
   - `FeelMotion.tween(view)`: to `FEEL.reveal_pop_height` in 0.22 s (`QUAD`/`OUT`), then to 0 in 0.16 s (`BOUNCE`/`OUT`).
   - For valuables, add a parallel tween of `visual_root.rotation:y` 0 → `TAU` over 0.38 s, then set it back to exactly 0.

### 6. Sand cleaner

- **Preview ring:** replace the `TorusMesh` and `StandardMaterial3D` preview with a `PlaneMesh` of size (2, 2) carrying a `ShaderMaterial` with `feel_ring.gdshader`:
  - `ring_color = FEEL.sand_ring_color`
  - `dashes = FEEL.sand_ring_dashes`
  - `thickness = 0.04 / radius()` in UV units

  Keep `preview.scale = Vector3.ONE * radius()`. Its x and z give the diameter from the size-2 plane; y is irrelevant for a plane.
- **In `_physics_process`, while active:**
  - Advance `dash_phase = fmod(time * 0.15, 1.0)` unless reduced.
  - Every 0.1 s, count `CleanupTargetQuery.nearby_waste(session, player, point + Vector3.UP * 0.15, radius())`. This count is a presentation hint only, with no visibility rays.
  - Set `intensity` to 1.0 when the count is above 0, otherwise 0.55.
  - Call `player.hand_rig.set_tool_activity(&"sand_cleaner", 0.4 if the target is valid else 0.0)`.
  - Skip position and scale updates while `Time.get_ticks_msec() < _contract_until`.
- **`try_click`:**
  - On success, call `player.play_cue(&"sift", {"count": changed.size()})` and puff sand: `manager.dust.burst(point + Vector3.UP * 0.03, Vector3.UP, 8 if reduced else 16, 1.0, 0.8, Vector2(0.04, 0.08), 0.6, FEEL.sand_color)`.
  - Unless reduced, contract the ring: set `_contract_until = now + 300` ms, tween `preview.scale` to `radius() * 0.2` and `intensity` to 0 over 0.3 s, then restore both.
  - Change the collect call inside the loop to `player.carry.present_collected(view.item_id, &"sand_cleaner", float(changed.size() - 1) * FEEL.sand_cleaner_stagger)`, placed after `changed.append(...)`.
  - On each failure branch, call `player.play_cue(&"rejected", {"reason": message})` and tint the ring amber (`FEEL.hover_blocked_color`) for 0.2 s.

### 7. Vacuum

In `configure()`:

```gdscript
motes = ParticlePool.create(ParticlePool.Kind.DUST, 48)
motes.drag = 0.0
motes.rise = 0.0
motes.grow = -0.6
motes.tint = Color(FEEL.dust_color, 0.8)
add_child(motes)
_mote_rng.seed = 1  # cosmetic stream, never gameplay
```

In `_physics_process`, when active, pressed and not blocked, call `player.hand_rig.set_tool_activity(&"vacuum", 1.0)` and `_emit_motes(delta)`:

```gdscript
func _emit_motes(delta: float) -> void:
	var reduced := FeelMotion.reduced(player.settings_store)
	_mote_budget += delta * FEEL.vacuum_mote_rate * (0.5 if reduced else 1.0)
	var nozzle := player.hand_rig.tool_tip().global_position
	var basis := player.camera.global_basis
	while _mote_budget >= 1.0:
		_mote_budget -= 1.0
		var direction := (-basis.z + basis.x * _mote_rng.randf_range(-0.35, 0.35) + basis.y * _mote_rng.randf_range(-0.2, 0.2)).normalized()
		var start := player.camera.global_position + direction * _mote_rng.randf_range(1.5, range_meters())
		var to_nozzle := nozzle - start
		motes.emit(start, to_nozzle.normalized() * FEEL.vacuum_mote_speed, _mote_rng.randf_range(0.02, 0.035), to_nozzle.length() / FEEL.vacuum_mote_speed)
```

- In `try_collect_next`, change the collect call to `player.carry.present_collected(view.item_id, &"vacuum")`, followed by `player.play_cue(&"vacuum_tick")`.
- In `_attempt_tick`, on capacity, call `player.play_cue(&"vacuum_full", {"reason": "Bag full"})`.
- The collection interval (`interval_seconds()`) and eligibility checks are unchanged. Throughput is gameplay.

### 8. Scanner

In `ScannerService.pulse()`, after `pulse_succeeded.emit()`:

```gdscript
FeelRing.spawn(player.get_parent(), player.global_position + Vector3.UP * 0.05, 0.5, FEEL.scanner_ring_radius, FEEL.scanner_ring_seconds, FEEL.scanner_color, 0.35)
player.play_cue(&"scanner_pulse")
_pop_markers = true
```

- At the end of `_refresh()`, if `_pop_markers` and motion is not reduced, each visible marker (a `PanelContainer`) gets `pivot_offset = size * 0.5`, `scale = Vector2.ONE * 0.6`, then a `FeelMotion.tween(marker)` to 1.08 and 1.0 with a delay of `index * 0.03` s.
- Then clear `_pop_markers`.
- `validate_scanner.gd` checks marker reuse and caps; this adds no nodes.

## Reduced motion

- **Clips:** 50% (J03).
- **Continuous motion:** no tool jitter, sweep or rock; no tool flash.
- **Kept:** detector rings, sand ring (static dashes), scanner ring and the FREED label, all without the pop.
- **Particles:** vacuum motes and all sparkles and puffs at half count.
- **Reveal:** no pop-up or spin.
- **Stains:** fade only.

## Validation

1. Re-run:
   - `validate_tool_filters.gd`: vacuum and sand eligibility, throughput and upgrades must be unchanged
   - `validate_buried.gd`
   - `validate_rescue.gd`
   - `validate_dirt.gd`
   - `validate_scanner.gd`
   - `validate_purchases.gd`
2. In `scenes/main.tscn`, stage ownership for all tools with a probe (state this in the handoff), or use a late save. Record one 1080p clip per tool:
   - **Cloth:** clean a two-stain chair.
   - **Knife:** cut both attachments on a shallows turtle, once with a free bag and once with a full bag (drop path).
   - **Detector:** walk from 4 m to 0.5 m from a buried find, then reveal it; repeat with a valuable.
   - **Sand cleaner:** aim over an empty patch, then over a litter patch, and click.
   - **Vacuum:** hold for 5 s in a pile, then fill the bag to capacity.
   - **Scanner:** pulse with a filter selected.
3. Check each at FOV 70: the hand and tool motion never cover the aim point, and the continuous motions stop when the tool is inactive or hands are full.
4. **Profile:** vacuum held in the densest pile. Record p95 and draws against the J00 baseline; motes must stay at or under 48 and the node count must stay flat.

## Done when

- Each row of the outcome table is visible in the real game.
- Tool throughput, eligibility and ownership are unchanged, and the checks pass.
- Reduced motion is observed.
- Clips are in J-feel.
