# J12 — Coast restored: postcard finale

Dependencies: J11, which in turn requires J00–J10. Read first: [plan](../12-game-feel.md) §3 (Unpacking-style photo), §4 rules 3 and 4, §6 tier 5, §8 and §11.2 (`validate_completion.gd` and `validate_full_run.gd` require `results_open`, a paused tree and a visible results view synchronously). Also R25 and D20: results latch on the first valid finish; the receipt is immutable; later roaming is allowed.

**Outcome.** Finishing the whole beach is a moment, not a popup:

1. The final action's effects (placement settle, set shine, restoration wave, sparkles) keep playing under the results pause for a one-second beat. The world's physics and wildlife stay frozen, so it reads like a held breath.
2. The HUD tucks away, a soft camera-flash whitens the screen, and that exact frame becomes a tilted postcard.
3. The results panel scales in. "COAST RESTORED" stamps down with a burst of confetti in the beach palette.
4. The postcard settles beside the stats, and each stat counts up in turn.
5. "Continue exploring" fades in and gently pulses.

Pressing confirm during the intro skips to the final layout; pressing it again continues. Loading an already-finished run shows the final layout at once, with no intro.

**Own files:**

| File | Change |
|---|---|
| `scripts/ui/results_view.gd` | Intro, capture, skip |
| `scenes/ui/results_view.tscn` | `Flash`, `Postcard`, `Confetti` nodes |
| `scripts/main.gd` | Pass `animate` and the HUD list; restore on continue; clear coins |

## Steps

### 1. Scene additions (`results_view.tscn`)

- **`Flash`**: a `ColorRect` (unique name), full-rect, white, `color.a = 0`, `mouse_filter = IGNORE`. Place it last so it draws above the panel.
- **`Postcard`**: a `PanelContainer` (unique name) inside `Center/Panel/Margin/Stack`, first child, `size_flags_horizontal = SHRINK_CENTER`.
  - Style: a white `StyleBoxFlat` border of 10 px and a slight shadow (`shadow_size` 8, `shadow_color` `Color(0, 0, 0, 0.35)`).
  - Child `PostcardImage` (`TextureRect`, unique name): `custom_minimum_size = FEEL.postcard_size` (384×216), `expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_ASPECT_COVERED`.
  - Hidden by default.
- **`Confetti`**: a `CPUParticles2D` (unique name) under the root, placed at the top centre, with `process_mode = ALWAYS`, `emitting = false`, `one_shot = true`, `amount = FEEL.confetti_amount`, `lifetime = 2.5` and `explosiveness = 0.85`.
  - Emission: `EMISSION_SHAPE_RECTANGLE` with `emission_rect_extents = (640, 8)`, `direction = (0, 1)`, `spread = 35`, `gravity = (0, 320)`, `initial_velocity` 120–260, `angular_velocity` −360–360, `scale_amount` 4–8.
  - Colour: `color_initial_ramp` is a `Gradient` with the four `FEEL.confetti_colors` as hard stops, so each particle picks one.
  - Keep it under the flash.
- Raise the panel's `custom_minimum_size` enough for the postcard. Verify at 720p and 150% UI scale that the panel still fits.

### 2. `ResultsView` behaviour

Keep everything synchronous that the checks read:

```gdscript
func show_receipt(receipt: Dictionary, player_body: BeachPlayer, run_session: RunSession, animate := true, hud: Array[CanvasItem] = []) -> void:
	if visible:
		return
	player = player_body
	session = run_session
	_previous_pause = get_tree().paused
	_final = _final_texts(receipt)          # title/summary/details exactly as today's strings
	session.results_open = true
	player.set_input_enabled(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	continue_button.grab_focus()
	if not animate:
		_apply_final_state()
		return
	_hide_hud(hud)
	_play_intro(receipt, FeelMotion.reduced(player.settings_store))
```

- Before any tween runs, `_final_texts(receipt)` returns today's exact `title_label`, `summary_label` and `details_label` strings. `_apply_final_state()` sets them, sets shade alpha to the authored value (store `_shade_alpha = shade.color.a` in `_ready`), sets panel alpha and scale to 1, shows the continue button, stops the confetti, and shows the postcard only when a texture exists.
- `_hide_hud(hud)`: store each node's `visible` in `_hud_states` and hide it.
- `_play_intro(receipt, reduced)`: set `_intro_running = true`, then build one `FeelMotion.tween(self)` sequence:
  1. **Initial state:**
     - shade alpha 0, panel `modulate.a` 0, flash alpha 0, continue `modulate.a` 0
     - postcard hidden
     - summary and details showing zero counts (unless reduced)
  2. **The beat:** `tween_interval(FEEL.finale_capture_seconds)`. World presentation keeps running because of plan §4 rule 4.
  3. **Capture:** `tween_callback(_capture_postcard)`. It is async: `await RenderingServer.frame_post_draw`, then take the image:
     ```gdscript
     var image := get_viewport().get_texture().get_image()
     var height := int(FEEL.postcard_size.y * 2.0)
     image.resize(int(float(height) * float(image.get_width()) / float(image.get_height())), height, Image.INTERPOLATE_BILINEAR)
     postcard_image.texture = ImageTexture.create_from_image(image)
     ```
     If the image is null or empty, leave the postcard hidden. The HUD is already hidden and the results UI is transparent, so the frame is the clean world view.
  4. **Flash** (skipped when reduced): `flash.color.a` → `FEEL.finale_flash_alpha` in 0.06 s, then → 0 in 0.35 s. In parallel, fade the shade to `_shade_alpha` over 0.4 s.
  5. **Panel:** `pivot_offset = size / 2`. Scale 0.94 → 1 (`TRANS_BACK`, 0.3 s) with alpha 0 → 1 (0.25 s). When reduced, alpha only.
  6. **Stamp:** set the title pivot to its centre, then scale 1.6 → 1.0 and `rotation` −0.1 → 0 over 0.22 s (`TRANS_BACK`/`EASE_OUT`). Callback: `confetti.restart()` unless reduced.
  7. **Postcard** (if it has a texture): show it with scale 0.8 → 1, `rotation_degrees` −4 → −2 (`TRANS_BACK`, 0.35 s).
  8. **Count-up** (skipped when reduced; set the final texts instead): a `tween_method` 0 → 1 over `FEEL.finale_count_seconds` (`TRANS_EXPO`/`EASE_OUT`) rebuilds the summary and details with numbers interpolated from 0. Waste, props and correct counts are integers; active time counts up in seconds. The last step writes `_final` exactly.
  9. **Continue:** `modulate.a` → 1 over 0.2 s. Callback: set `_intro_running = false` and start a looping pulse (scale 1.0 ↔ 1.03, 1 Hz) unless reduced.

Also add:

- **Skip.** Add `_input(event)`: if `_intro_running` and the event is `ui_accept`, or a left mouse press:
  - call `_finish_intro()`: kill the intro, write `_final`, apply the final state and keep any captured postcard
  - `get_viewport().set_input_as_handled()`

  The first confirm skips; the next one reaches the focused button.
- **`continue_roaming()`.** Keep the existing body. Add: kill the intro and pulse tweens, stop the confetti, restore `_hud_states` (each node back to its previous `visible`), and reset flash alpha to 0. `reset_view()` does the same cleanup.

### 3. `main.gd` wiring

- **Live completion.** In the `run_completed` handler, keep `_clear_notices()` and `collection_receipt.clear_receipt()`, and add `coin_flyer.clear()` and `_release_money(0)` (J10). Then call:
  ```gdscript
  results_view.show_receipt(receipt, player, session, true, [progress_panel, context_panel, guidance_panel, target_label, reticle, error_panel, restoration_pointer])
  ```
- **Loaded finished run** (`_open_run`): call `results_view.show_receipt(initial_state.completion_receipt, player, session, false)`. No intro and no capture.
- `results_view.continued` already exists. No extra HUD handling is needed: `continue_roaming` restores what it hid.

## Reduced motion

- No flash, no confetti, no stamp rotation or scale, no pulse.
- The panel fades in and the postcard fades in with no tilt animation (it rests at −2°).
- Rows appear with their final numbers.
- The one-second beat is kept, so the final placement or restoration is still seen before the panel.

## Validation

1. `validate_completion.gd` must pass unchanged: results visible, paused and `results_open` right after the final place; continue resumes. Use `-- --capture` to update `P20-results.png`; capture after the intro ends (about 3 s later) as the new still.
2. `validate_full_run.gd` must pass: results open and the tree paused at the final place; results visible after reload (no intro); continue. It is heavy, so run it once at the end.
3. In `scenes/main.tscn`, use the existing accelerated staging from `tests/validate_full_run.gd` or `tests/record_feedback.gd` (label it accelerated in the handoff) to finish the beach with a final chair placement. Record the whole finale at 1080p:
   - the postcard contains the settled chair, the shine and the wave front, with no HUD
   - skipping works with the controller A button and a mouse click
   - Continue restores the HUD exactly
4. Repeat with the final action being a truck collection: receipt and coins are cleared, and the wallet shows the true value.
5. Reduced-motion pass.
6. Save from the pause menu immediately after Continue, reload, and confirm the receipt is unchanged and the results show instantly.

## Done when

- The finale plays as described, and skip and continue are reliable with mouse and controller.
- Loads show no intro, and HUD states are restored.
- The completion and full-run checks pass.
- Reduced motion is observed.
- The clip is in J-feel.
