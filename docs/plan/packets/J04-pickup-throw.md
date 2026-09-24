# J04 — Pickup, bag catch, prop lift and throw

Dependencies: J03. Read first: [plan](../12-game-feel.md) §4 rules 1–5 and 7, §6 tier 0, §7 and §8. Also [architecture](../02-architecture.md): *"A pickup/placement travel animation is not a third owner… If the visual is interrupted… render the committed destination."*

**Outcome:**

- **Stick collect:** the item hops (a "yoink"), snaps to the stick tip, then flicks along an arc into the bag mouth, spinning and shrinking late. The bag squashes and the left arm dips on arrival. A puff of dust (or bubbles underwater) and a few sparkles mark where the item was.
- **Vacuum and sand cleaner:** vacuum items stretch into the nozzle. Sand-cleaner items stagger into the bag in a quick stream.
- **Prop pickup:** the prop lifts with a wiggle and arcs into the hands, shrinking to its in-hand scale so it never pops.
- **Slot removal and bag handling:** props lift off their slot and travel to the hand instead of teleporting. Disposal bags taken from a rack, the ground or a container travel to the hand too.
- **Throw:** the right arm (or bag arm) tosses. Small items tumble forward, and thrown items puff and squash when they land.
- **Cues:** every success sends a cue and every failure sends `rejected`.

**Own files:**

| File | Change |
|---|---|
| `scripts/items/world_item.gd` | `travel_to`, impact |
| `scripts/items/item_view_manager.gd` | Pools, puffs, impacts |
| `scripts/player/carry.gd` | Presentation paths, cues |
| `scripts/player/interactor.gd` | `request_primary` cues |
| `scripts/items/placement_service.gd` | `try_remove` presentation only |
| `scripts/stations/waste_container.gd` | Take-bag presentation only |

## Steps

### 1. `WorldItem.travel_to` with options

Keep the signature compatible and add a trailing `options` dictionary. Collision is off for the whole trip, and the record is already in its destination.

```gdscript
signal impacted(item_id: StringName, position: Vector3, speed: float)

var _impact_armed_until := 0
var _last_speed := 0.0


## Presentation travel of this already-committed view into `socket`.
## options: reduced, delay, yoink_seconds, yoink_height, yoink_scale, wiggle_degrees, arc, via,
## via_fraction, spin_turns, spin_axis, shrink_from, end_scale, end_local, stretch, ease.
func travel_to(socket: Node3D, duration: float, shrink: bool, finished: Callable, options: Dictionary = {}) -> void:
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	set_dirt_interactive(false)
	set_highlighted(false)
	FeelMotion.replace(visual_root, &"hover", null)
	visual_root.transform = Transform3D.IDENTITY
	reparent(socket, true)
	var reduced := bool(options.get("reduced", false))
	_presentation_tween = FeelMotion.tween(self)
	var delay := float(options.get("delay", 0.0))
	if delay > 0.0:
		_presentation_tween.tween_interval(delay)
	var yoink := 0.0 if reduced else float(options.get("yoink_seconds", 0.0))
	if yoink > 0.0:
		_presentation_tween.tween_property(visual_root, "position:y", float(options.get("yoink_height", FEEL.yoink_height)), yoink).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_presentation_tween.parallel().tween_property(visual_root, "scale", Vector3.ONE * float(options.get("yoink_scale", FEEL.yoink_scale)), yoink).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var wiggle := deg_to_rad(float(options.get("wiggle_degrees", 0.0)))
		if wiggle > 0.0:
			_presentation_tween.parallel().tween_method(func(t: float) -> void: visual_root.rotation.z = sin(t * TAU) * wiggle, 0.0, 1.0, yoink)
	var travel := options.duplicate()
	travel["visual"] = visual_root
	travel["shrink_to"] = float(options.get("end_scale", FEEL.bag_end_scale if shrink else 1.0))
	if reduced:
		for key in ["arc", "via", "spin_turns", "drop"]:
			travel.erase(key)
	FeelMotion.travel(self, socket, options.get("end_local", Transform3D.IDENTITY), duration, travel, finished, _presentation_tween)
```

`cancel_travel()` is unchanged: it kills the tween and frees the view. The callers already treat cancellation as "render the committed destination".

Add impact support to the same script:

```gdscript
func arm_impact(seconds := 3.0) -> void:
	_impact_armed_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	if not body_entered.is_connected(_on_feel_contact):
		body_entered.connect(_on_feel_contact)


func play_impact(reduced: bool) -> void:
	if not reduced:
		FeelMotion.squash_land(visual_root, FEEL.impact_squash, Vector3(0.98, 1.04, 0.98), FEEL.impact_seconds)


func _on_feel_contact(_body: Node) -> void:
	if Time.get_ticks_msec() > _impact_armed_until:
		return
	_impact_armed_until = 0
	if _last_speed >= FEEL.impact_min_speed:
		impacted.emit(item_id, global_position, _last_speed)
```

At the top of `_physics_process`, add `_last_speed = linear_velocity.length()`. The item scene already has `contact_monitor = true` and `max_contacts_reported = 4`, so `body_entered` fires. The handler is only armed for 3 s after a throw, which keeps the cost negligible.

### 2. `ItemViewManager` owns item puffs

In `configure()`, when `player != null`, create three pools with `process_always = true` and add them as children:

- `sparkles`: SPARKLE, 96
- `dust`: DUST, 64, with `tint = FEEL.dust_color`
- `bubbles`: BUBBLE, 64

Add the following:

```gdscript
func feel_puff(at: Vector3, reduced := false) -> void:
	if sparkles == null:
		return
	var amount := 0.5 if reduced else 1.0
	if at.y < WorldItem.WATER_LEVEL - 0.05:
		bubbles.burst(at, Vector3.UP, maxi(1, int(5 * amount)), 0.4, 0.15, Vector2(0.008, 0.02), 1.6)
		return
	dust.burst(at + Vector3.UP * 0.03, Vector3.UP, maxi(1, int(FEEL.pickup_dust * amount)), 0.6, 0.35, Vector2(0.04, 0.08), 0.5)
	feel_sparkles(at + Vector3.UP * 0.08, int(FEEL.pickup_sparkles * amount))


func feel_sparkles(at: Vector3, count: int, color := Color(0, 0, 0, 0)) -> void:
	if sparkles == null or count <= 0:
		return
	var chosen := color
	if chosen.a <= 0.0:
		chosen = FEEL.sparkle_colors[int(FeelMotion.cosmetic_random(at.snapped(Vector3.ONE * 0.1)) * FEEL.sparkle_colors.size()) % FEEL.sparkle_colors.size()]
	sparkles.burst(at, Vector3.UP, count, 0.5, 0.4, Vector2(0.05, 0.08), 0.45, chosen)
```

In `_spawn_view`:

- set `view.effects = self`
- connect `view.impacted` to `_on_item_impacted(item_id, position, speed)`

`_on_item_impacted`:

- Get `reduced` from `(player as BeachPlayer).settings_store`.
- Puff `clampi(int(speed * 2.0), 3, 10)` dust particles at the landing point, or bubbles underwater.
- Call `views[item_id].play_impact(reduced)` if the view still exists.

### 3. Collect presentation in `PlayerCarry`

Replace `present_collected(item_id)` with the version below. Every existing caller keeps working because the new parameters are optional.

```gdscript
func present_collected(item_id: StringName, source: StringName = &"stick", delay := 0.0) -> void:
	var manager := _view_manager()
	var view := manager.take_view_for_presentation(item_id) if manager != null else null
	if view == null:
		return
	var reduced := FeelMotion.reduced(player.settings_store)
	manager.feel_puff(view.global_position, reduced)
	_prune_presentations()
	if _presentation_views.size() >= 12 or reduced:
		view.queue_free()
		return
	_presentation_views[item_id] = view
	var distance := view.global_position.distance_to(hand_rig.bag_socket.global_position)
	var seconds := FeelMotion.travel_seconds(distance, FEEL.bag_travel_base, FEEL.bag_travel_per_meter, FEEL.bag_travel_max)
	var destination: Node3D = hand_rig.bag_socket
	var options := {
		"delay": delay, "end_local": Transform3D(Basis.IDENTITY, FEEL.bag_mouth),
		"spin_axis": FeelMotion.cosmetic_axis(item_id), "shrink_from": FEEL.bag_shrink_from,
	}
	var shrink := true
	match source:
		&"stick":
			options.merge({"yoink_seconds": FEEL.yoink_seconds, "via": hand_rig.tool_tip(),
				"via_fraction": FEEL.stick_tip_fraction, "arc": FEEL.bag_arc_height, "spin_turns": FEEL.bag_spin_turns}, true)
		&"vacuum":
			destination = hand_rig.tool_tip()
			seconds = FEEL.vacuum_travel_seconds
			shrink = false
			options.merge({"ease": &"in", "stretch": FEEL.vacuum_stretch, "shrink_from": 0.4, "end_local": Transform3D.IDENTITY}, true)
		_:
			options.merge({"yoink_seconds": FEEL.yoink_seconds * 0.7, "arc": FEEL.bag_arc_height, "spin_turns": FEEL.bag_spin_turns * 0.5}, true)
	view.travel_to(destination, seconds, shrink, func() -> void:
		_presentation_views.erase(item_id)
		if is_instance_valid(view):
			view.queue_free()
		if source == &"vacuum":
			hand_rig.bag_catch(0.35)
		else:
			player.play_cue(&"bag_catch", {"strength": 1.0})
	, options)


func _prune_presentations() -> void:
	for key in _presentation_views.keys():
		if not is_instance_valid(_presentation_views[key]):
			_presentation_views.erase(key)
```

- `_cancel_presentation` must accept any `Node3D`, not only a `WorldItem`: call `cancel_travel()` when the value is a `WorldItem`, otherwise `queue_free()` it.
- `_collect_target`:
  - On success, call `player.play_cue(&"poke" if hand_rig.active_tool_id() == &"stick" else &"hold", {"item_id": str(item_id)})`.
  - Then call `present_collected(item_id, hand_rig.active_tool_id() if hand_rig.active_tool_id() == &"stick" else &"hand")`.
  - On failure, call `player.play_cue(&"rejected", {"reason": result.message})` next to the existing `feedback_requested`.

The tip waypoint is the stick's `FeelTip` from J03. Tune `FEEL.tool_tips[&"stick"]`: temporarily parent a 2 cm `SphereMesh` to the tip in a probe until it sits on the visible end of the pole, then remove the sphere. Tune `FEEL.bag_mouth` so items enter the top of the hand bag.

### 4. Prop pickup, slot removal and bag handling

`_hold_target` on success:

```gdscript
var large := definition.hand_cost == 2
player.play_cue(&"hold", {"large": large})
# ... existing take_view_for_presentation ...
var reduced := FeelMotion.reduced(player.settings_store)
_view_manager().feel_puff(view.global_position, reduced)
var destination := hand_rig.large_prop_socket if large else next_small_socket()
view.travel_to(destination, FEEL.prop_travel_seconds, false, func() -> void:
	_presentation_views.erase(item_id)
	if is_instance_valid(view):
		view.queue_free()
	refresh_hand_visuals()
	hand_rig.animator.play(&"catch", &"both" if large else (&"left" if destination == hand_rig.left_prop_socket else &"right"), 0.8)
, {
	"reduced": reduced, "yoink_seconds": FEEL.prop_yoink_seconds, "yoink_height": FEEL.prop_yoink_height,
	"yoink_scale": 1.05, "wiggle_degrees": FEEL.prop_wiggle_degrees, "arc": FEEL.prop_arc_height,
	"end_scale": 0.4 if large else 0.35, "shrink_from": 0.2,
})
```

`end_scale` matches `_scale_hand_visual`, so the arriving prop and the in-hand instance are the same size. Rename `_next_small_socket()` to the public `next_small_socket()` and update its callers.

Add a generic presenter for visuals that are not `WorldItem`s:

```gdscript
## Animates a temporary visual from `from_global` into `destination` (hand socket or bag socket).
## `on_arrival` runs after the visual is freed (J06 uses it for the bag catch of cut attachments).
func present_visual(item_id: StringName, visual: Node3D, from_global: Transform3D, destination: Node3D, end_scale: float, on_arrival := Callable()) -> void:
	_prune_presentations()
	var reduced := FeelMotion.reduced(player.settings_store)
	destination.add_child(visual)
	visual.global_transform = from_global
	_presentation_views[item_id] = visual
	var t := FeelMotion.tween(visual)
	if not reduced:
		var up_local := (destination.global_basis.inverse() * Vector3.UP).normalized()
		t.tween_property(visual, "position", visual.position + up_local * FEEL.remove_lift, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	FeelMotion.travel(visual, destination, Transform3D.IDENTITY, FEEL.prop_travel_seconds,
		{"arc": 0.0 if reduced else FEEL.prop_arc_height, "shrink_to": end_scale, "shrink_from": 0.2},
		func() -> void:
			_presentation_views.erase(item_id)
			if is_instance_valid(visual):
				visual.queue_free()
			if on_arrival.is_valid():
				on_arrival.call()
			else:
				refresh_hand_visuals()
		, t)
```

Callers:

- **`PlacementService.try_remove`:**
  1. Before `_remove_slotted_view(item_id)`, capture `var from := slotted_visual_root(item_id).global_transform` (fall back to `slot_transform(slot_id)`).
  2. After `finalize_action` and before `carry.refresh_hand_visuals()`, call `carry.present_visual(item_id, _create_visual(definition), from, carry.hand_rig.large_prop_socket if definition.hand_cost == 2 else carry.next_small_socket(), 0.4 if definition.hand_cost == 2 else 0.35)` and `player.play_cue(&"hold", {"large": definition.hand_cost == 2})`.

  `refresh_hand_visuals()` already skips ids that are in `_presentation_views`, so the hand does not show the prop until it arrives. Ownership is already `HELD`.
- **`_hold_bag_target`:** before `try_hold_bag`, store `var from := (target.collider as Node3D).global_transform`. On success, instance `DISPOSAL_BAG_SCENE`, `configure(record, Callable(), true)` it like `_style_hand_visual` does, and call `present_visual(bag_id, copy, from, next_small_socket(), 0.55)` and `player.play_cue(&"hold_bag")`.
- **`WasteContainer.try_take_last_bag`:** on success, do the same starting from `opening.global_transform`. The rack or world bag view is freed by its station on `bags_changed`, which is why the copy is built from the stored transform.

### 5. Throw

In `_on_throw_requested`, before calling `try_throw`, decide which arm throws. `held_objects` is ordered by pickup, and slot 0 is the left hand (`next_small_socket()`).

```gdscript
var held := _player_record()[&"held_objects"] as Array
var arm := &"left"
if not held.is_empty():
	var last_index := held.size() - 1
	var last_definition := _definition_for_item(StringName(str((held[last_index] as Dictionary).get("id", ""))))
	arm = &"both" if last_definition != null and last_definition.hand_cost == 2 else (&"right" if last_index == 1 else &"left")
```

- On success, call `player.play_cue(&"throw", {"arm": arm})`.
- For items, use the returned view: `var thrown := manager.restore_world_view(object_id)`.
- If `thrown != null`, call `thrown.arm_impact()`. If the definition's collision profile is `SMALL` and `FEEL.throw_spin > 0`, also set `thrown.angular_velocity = -camera.global_basis.x * FEEL.throw_spin` for a forward tumble.

The tumble changes only rotation, not the launch velocity or the ownership path. Physics trajectories are not a determinism promise ([R26](../01-requirements.md)). If tumbling rolls cans somewhere awkward in play, set `throw_spin` to 0 and record it.

On every failure branch ("Nothing to throw", "Not enough room to throw", `result.message`), call `player.play_cue(&"rejected", {"reason": ...})`.

### 6. Interactor cues

In `PlayerInteractor.request_primary()`:

- If `current_target.is_empty()`, call `(get_parent() as BeachPlayer).play_cue(&"whiff")` and return. J03 maps `whiff` to the active tool's short clip.
- In the blocked branch, next to `action_blocked.emit(reason)`, call `play_cue(&"rejected", {"reason": reason})`.

Do not change which signals fire. `validate_interaction.gd` counts `primary_requested` emissions.

## Reduced motion

- **Collect:** the view is freed at once (existing behavior). The puff is kept at half count and the bag fill updates.
- **Prop pickup, slot removal and bag take:** straight travel over the same duration, with no yoink, wiggle, lift or arc.
- **Throw:** no squash and half the dust.
- **Viewmodel clips:** play at 50% strength (J03).

## Validation

1. Re-run the existing checks:
   - `validate_carry.gd`: LIFO, hands, full bag, input during travel
   - `validate_interaction.gd`
   - `validate_physics.gd`: throw, settle, recovery
   - `validate_save_physics.gd`: poses after throws
   - `validate_tool_filters.gd`: vacuum and sand throughput unchanged
   - `validate_sealing.gd`: bag hold and throw
   - `validate_placement.gd`: remove and re-place
2. In `scenes/main.tscn` with seed `first-shore`:
   - Collect ten items by hand at normal pace, then spam-click a dense pile. Confirm no more than 12 travels and that nothing stays in the air.
   - Collect one item underwater (bubbles).
   - Pick up a chair and two buckets, then place one bucket on a shelf and take it off again.
   - Throw a can onto sand and a bucket onto the pier (dust and squash).
   - Take a sealed bag off the rack and out of a container.
   - Record a 1080p clip of each, with one pass at FOV 70 and one at FOV 110.
3. **Ownership spot check.** During a travel, open pause, save, then quit and load. The item must be in its committed location (bag, hand or slot) with no ghost view left in the world. Run `RunState.validate_invariants` in the probe.
4. **Interruption.** Pick up a prop, then faint within the travel window (the existing faint path calls `release_all_items` and `cancel_all_presentations`). Confirm exactly one view exists afterwards.
5. **Profile.** Hold the vacuum in the densest pile for 10 s and record p95 and node count before and after, to confirm no growth.

## Done when

- Every collect, pickup, remove, bag take and throw shows the specified motion and cue in the real game.
- The stick-tip path reads as stab-and-flick.
- The bag reacts to what lands in it.
- Rejections play the rejection cues.
- Nothing is left floating, ownership is intact after interruptions, and the checks pass.
- Clips are in J-feel.
