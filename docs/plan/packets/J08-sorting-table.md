# J08 — The sorting table as the tidy heart of the game

Dependencies: J00. It is independent of J01–J07 and can run in parallel with J06 and J07. Read first: [plan](../12-game-feel.md) §4, §6 tier 0 and §8. Also [P12](P12-table.md), and `scripts/stations/sorting_station.gd` plus `scripts/ui/sorting_view.gd`.

**Outcome.** Sorting feels like physically tidying a table:

- **Unload:** the bag's contents rain onto their cells in a quick staggered cascade.
- **Cursor:** the focus cursor is a set of corner brackets that glides between cells and pinches when you select.
- **Hover:** the hovered or focused item lifts and grows slightly.
- **Drag:** a dragged item lifts off the table, follows the mouse in 3D and tilts with motion. Bin buttons swell when you drag over them.
- **Sort:** a sorted item arcs into its bin, the bin bumps, a sparkle puffs from the opening and the bin's fill level rises in 3D and on its button. A ✓ (correct) or ? (wrong) glyph stamps onto the bin button; the shape carries the meaning, not only the colour.
- **Return:** returning an item from a bin arcs it back to its cell.
- **Seal:** the fill drops and the sealed bag bounces onto the output rack.
- **Physical throws:** throwing litter into a bin from the world "swishes".
- **Sell:** selling a valuable sparkles and floats `+$N`.

**Own files:**

| File | Change |
|---|---|
| `scripts/stations/sorting_station.gd` | Presentation only. Domain validation and commits stay byte-for-byte except for capturing `source_cell` before mutation. |
| `scripts/ui/sorting_view.gd` | Cursor, hover, drag, stamps, button fill |
| `scripts/ui/feel_icon.gd` | New. J09 reuses it. |

The table camera is orthographic-like (`table_camera.size` zoom), and the hands are hidden at the table, so no viewmodel work is needed here.

## Steps

### 1. `FeelIcon` (shared glyph control)

Create `scripts/ui/feel_icon.gd`, a `Control` with `@export var kind := Kind.CHECK`, `@export var color := Color.WHITE` and `enum Kind { CHECK, QUESTION, STAR, COIN, ARROW, INFO }`. It draws the glyph inside its rect with antialiased primitives, so nothing depends on font coverage:

| Kind | Drawing |
|---|---|
| CHECK | Polyline (0.18, 0.55) → (0.42, 0.78) → (0.84, 0.28) of the size, width `size.y * 0.14`, round |
| QUESTION | `draw_string` with `"?"` in the default theme font, centred. ASCII is safe. |
| STAR | Four-point star polygon |
| COIN | Filled circle in the colour, inner ring 70% darker, with a small highlight arc |
| ARROW | Chevron polygon pointing +X; rotate the control to aim |
| INFO | Ring plus an "i" drawn as a dot and a bar |

Add `mouse_filter = MOUSE_FILTER_IGNORE`. Call `queue_redraw()` from `set_kind` and `set_color` setters.

### 2. Station presentation helpers (`SortingStation`)

Add these fields: `const FEEL := preload(...)`, `var sparkles: ParticlePool`, `var _hover_cell := -1`, `var _drag_proxy: Node3D`, `var _drag_cell := -1`, `var _drag_velocity := Vector3.ZERO` and `var _bin_fills: Array[MeshInstance3D] = []`.

In `configure()`:

- Create `sparkles` (SPARKLE, 48, `process_always`) as a child.
- For each bin area call `_build_bin_fill(area, index)` after `_build_bin_walls`, then `_update_bin_fills(false)`.

Add the helpers:

- `_reduced() -> bool`: `FeelMotion.reduced(player.settings_store)`.
- `_cell_position(index) -> Vector3`: the existing proxy position formula, `Vector3((index % CELL_COLUMNS - 9.5) * 0.22, 0.855, (index / CELL_COLUMNS - 5.5) * 0.22)`. Use it inside `_refresh_proxies` too.
- `_build_bin_fill(area, index)`:
  - A `MeshInstance3D` named `BinFill` with a `BoxMesh` of size (0.72, 1.0, 0.46).
  - An unshaded-off `StandardMaterial3D` with `albedo_color = PROXY_COLORS[index].darkened(0.15)` and roughness 0.9.
  - Parent it to the area, and append it to `_bin_fills`.
  - The walls span Y −0.75…0.05 in area space, so the fill grows up from −0.74. Tune it against the Synty bin mesh.
- `_update_bin_fills(animate)`: for each category, `h = 0.62 * count / BIN_CAPACITY`. The target is `scale.y = max(h, 0.001)` and `position.y = -0.74 + h * 0.5`, and the fill is visible when `h > 0`. When animating and not reduced, tween both over 0.2 s (`TRANS_BACK`/`EASE_OUT`); otherwise set them directly.
- `_bump(node: Node3D)`:
  1. Store `rest` in meta `&"rest_scale"` the first time.
  2. Set `node.scale = rest * FEEL.bin_bump`.
  3. Run `FeelMotion.replace(node, &"bump", FeelMotion.tween(node))` to `rest` over 0.18 s (`TRANS_BACK`/`EASE_OUT`).

  Use this for each area's `SyntyBin` child and for the `RackLabel` (`Label3D`). It returns to the authored scale, which is not necessarily ONE.
- `_fly_proxy(proxy, target_global: Vector3, seconds, shrink_to, on_arrival: Callable)` calls `FeelMotion.travel(proxy, proxy_root, Transform3D(proxy.transform.basis, proxy_root.to_local(target_global)), seconds, {"arc": 0.0 if _reduced() else 0.25, "shrink_to": shrink_to, "shrink_from": 0.5}, on_arrival)`.

### 3. Hook the committed actions

Keep all validation and state changes as they are. Add presentation after commit:

- **`try_unload`:**
  - Change `_contents_committed()` to return the `Array[Node3D]` of proxies created by `_refresh_proxies()`.
  - Unless reduced, cascade them:
    - `count = created.size()`
    - `step = min(FEEL.unload_stagger, FEEL.unload_cascade_max / max(count, 1))`
    - For each proxy `i`:
      1. Store `rest = proxy.position` and hide the proxy.
      2. Set its position to `rest + Vector3(0, FEEL.unload_drop_height, 0)` and its scale to 0.6.
      3. `tween_interval(i * step)`, then `tween_callback(proxy.show)`.
      4. Position → `rest` (`FEEL.unload_fall_seconds`, `QUAD`/`IN`) in parallel with scale → ONE.
      5. Then scale (1.1, 0.85, 1.1) → ONE over 0.1 s.
  - After the loop, `player.play_cue(&"unload")`.
- **`try_sort`:**
  - Place the capture after every rejection check, including the bin-full check, and immediately before the first mutation (`if record.location == ItemRecord.Location.TABLE: (table_record().cells as Dictionary).erase(record.slot_id)`). Capture `var source_cell := record.slot_id if record.location == ItemRecord.Location.TABLE else StringName()`.
  - At the same point: if `source_cell` is set and `_proxies.has(source_cell)`, take `var flying := _proxies[source_cell]` and `_proxies.erase(source_cell)`. `_refresh_proxies()` then will not free it. A rejected sort never reaches this point, so it never detaches a proxy.
  - After `_contents_committed()`:
    - Call `_fly_proxy(flying, bin_area.global_position + Vector3.UP * 0.35, FEEL.sort_travel_seconds, 0.4, <on_arrival>)`, where on arrival: free the proxy, `_bump(bin SyntyBin)`, burst 6 sparkles at the opening and call `_update_bin_fills(true)`.
    - If there is no flying proxy (a world throw or a bin-to-bin move), bump and sparkle at once.
    - If an auto-seal happened (the receipt has a `sealed_bag_id`), `_update_bin_fills(true)` after the arrival shows the fill dropping. The rack bag is handled below.
  - Then `player.play_cue(&"sort", {"correct": correct})`.
- **`try_unsort`:** after commit, the created proxy (the one returned for the new cell) starts at the bin's global position plus 0.35 up, at scale 0.4. It travels to `_cell_position(index)` with `shrink_to = 1.0`, then gets a small squash. Call `_update_bin_fills(true)`.
- **`try_seal`:** after commit, call `_update_bin_fills(true)` and `_bump(bin)`, then `player.play_cue(&"seal")`.
- **`_on_bags_changed`:** pass `animate := true` into `_refresh_bag_view(bag_id, animate)`. `configure()` passes false.
  - In `_refresh_bag_view`, when a new view is created for a bag with `location == "RACK"` and `animate` is true and not reduced: find its `SyntyBag` child, set `position.y = FEEL.rack_drop_height`, and tween it to 0 over 0.35 s (`TRANS_BOUNCE`/`EASE_OUT`).
  - The bag's rigid body and collision stay where the record says.
  - Then call `_bump($OutputRack/RackLabel)`.
- **`try_sell_valuable`:** after commit:
  - Burst 8 gold sparkles (`FEEL.sparkle_colors[1]`) at `tray_items.global_position + Vector3.UP * 0.1`.
  - `FeelFloater.spawn(self, tray_items.global_position + Vector3.UP * 0.35, "+$%d" % amount, FEEL.money_color, _reduced())`.
  - `player.play_cue(&"sell")`.
- **`_on_bin_body_entered`** (world throw), on success: `FeelRing.spawn(self, area.global_position + Vector3.UP * 0.05, 0.2, 0.55, 0.3, FEEL.shine_core_color, 0.04)`, then `_bump(bin)`, 8 sparkles and `_update_bin_fills(true)`.
- **Hover API**, used by the view:
  - `set_hover_cell(index)`: if the index changes, tween the previous proxy (if valid) back to its cell position and scale ONE over 0.08 s. Tween the new one to `_cell_position(index) + Vector3(0, FEEL.proxy_hover_lift, 0)` and scale `FEEL.proxy_hover_scale` over 0.1 s (`TRANS_BACK`). When reduced, only apply the scale (no lift).
- **Drag API**, used by the view:
  - `begin_drag(index) -> bool`: stores `_drag_proxy = _proxies.get(cell_id(index))`.
  - `drag_to(screen_point: Vector2, delta: float)`:
    1. Intersect `table_camera.project_ray_origin/normal(screen_point)` with the plane at Y = `to_global(Vector3(0, 0.855 + FEEL.drag_height, 0)).y`.
    2. Lerp the proxy's global position there with factor `1 - exp(-30·delta)`.
    3. Set its rotation from the velocity, with `tilt = deg_to_rad(FEEL.drag_tilt_degrees)`: `rotation.z = -clampf(v.x * 0.05, -tilt, tilt)` and `rotation.x = clampf(v.z * 0.05, -tilt, tilt)`. No tilt when reduced.
  - `end_drag(return_home := true)`: when returning, tween the position to the cell, the rotation to ZERO and the scale to ONE over 0.16 s (`TRANS_BACK`), then clear the drag fields. A successful sort uses the flying path above, which picks the proxy up wherever the drag left it.

### 4. View: cursor, hover, drag, stamps and fills (`SortingView`)

- **Cursor.**
  - Add `var _cursor := Vector2.ZERO` and `var _pinch := 0.0`.
  - In `_process`, set `_cursor = _cursor.lerp(_cell_screen(focused_cell), 1.0 - exp(-FEEL.cursor_follow_hz * delta))`, snapping when reduced, and decay `_pinch` toward 0.
  - In `_draw()`, replace the white square with four L-brackets of half-size `radius * (1.0 - 0.2 * _pinch)` around `_cursor`: white, 2 px, with a 1-px dark backing and a ±1.5 px breathing (skipped when reduced).
  - Set `_pinch = 1.0` in `_select_focused()` and on mouse release.
- **Hover.**
  - In `_input`, for `InputEventMouseMotion` when not dragging or panning, call `station.set_hover_cell(_cell_at(motion.position))`.
  - In `_move_focus`, call `station.set_hover_cell(focused_cell)`.
  - In `close()`, call `station.set_hover_cell(-1)` before clearing `station`.
- **Drag.**
  - When `dragging` first becomes true, call `station.begin_drag(pressed_cell)`.
  - On every later motion, call `station.drag_to(motion.position, get_process_delta_time())`.
  - Keep `drag_preview` as the caption, as today.
  - While dragging, swell the bin button under the cursor: set `pivot_offset = size / 2` and `scale = 1.06`, and return the others to 1.0.
  - In `_mouse_release`:
    - On a bin: call `_sort(...)`, then `station.end_drag(false)` if the sort succeeded, or `station.end_drag(true)` if it failed.
    - Elsewhere: call `station.end_drag(true)`.
  - `_cancel_drag()` calls `station.end_drag(true)`.
- **Button fill bars.**
  - In `_ready()`, add a child `ColorRect` named `Fill` to each bin button, anchored bottom-left, height 4 px, colour `SortingStation.PROXY_COLORS[i]` lightened 0.2, with `mouse_filter = IGNORE`.
  - In `_refresh()`, tween its `size.x` to `button.size.x * count / BIN_CAPACITY` over 0.2 s, or set it directly when reduced.
  - When a count increases compared with the last refresh, call `FeelMotion.bump_control(button, 1.06, 0.16)` unless reduced.
- **Stamps.**
  - In `_sort()`, on success, add a `FeelIcon` to the button's top-right corner (24×24):
    - correct: `CHECK` in `FEEL.ghost_color`
    - wrong: `QUESTION` in `FEEL.hover_blocked_color`
  - Unless reduced, pop it (scale 1.6 → 1.0, `TRANS_BACK`, 0.16 s).
  - Fade it after `FEEL.stamp_seconds` and free it. Keep at most one stamp per button, replacing the old one.
  - The existing `_say` text still reports correct or wrong for screen readers and clarity.

## Reduced motion

- Proxies appear and disappear instantly (the existing behaviour), and hover is scale-only.
- The cursor snaps and drag has no tilt.
- Fills and bars update without tweens, and there is no bin bump or rack bounce.
- Stamps and floaters fade only.
- Sparkles run at half count; the world-throw ring is kept.

## Validation

1. Re-run the existing checks:
   - `validate_sorting.gd`: controller and mouse table flow, wrong→correct correction, full table, remap conflicts
   - `validate_sealing.gd`: auto and manual seal, rack saturation
   - `validate_payment.gd`
   - `validate_ui.gd`

   None of their state assertions may change.
2. In `scenes/main.tscn` (seed `first-shore`), collect 20 mixed items, enter S1, then record:
   - unload (the cascade)
   - hovering across cells with the mouse
   - D-pad focus moving (the glide)
   - drag and drop into the correct bin, then into a wrong bin (the ? stamp)
   - inspect → return to table (the reverse arc)
   - a manual seal (the rack bounce)
   - a 50-item auto-seal (staged with a probe; say so)
   - selling a valuable
   - a world throw into a bin from outside the hut
3. At 720p and 150% UI scale, the cursor, stamps and fill bars stay inside their buttons and never cover the side panel or hint.
4. Pausing mid-drag and saving still loses nothing (existing D12 behaviour). Confirm the proxy returns home after resume.
5. **Profile:** a 200-item unload (bag 200; staged) cascade stays within budget and settles in at most 0.9 s.

## Done when

- Every table action has the listed motion and response in the real station.
- Drag works with mouse and focus with controller.
- The domain checks are unchanged and passing.
- Reduced motion is observed.
- Clips are in J-feel.
