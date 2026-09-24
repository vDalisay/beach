# J09 — HUD that rewards: count rolls, bars, money and notices

Dependencies: J02 (main.gd sequence), plus J08's `FeelIcon`. If J08 is not merged yet, create `scripts/ui/feel_icon.gd` here exactly as specified in [J08 step 1](J08-sorting-table.md#1-feelicon-shared-glyph-control). Read first: [plan](../12-game-feel.md) §4 rule 9, §6, §8 and §11.2 (`validate_ui.gd`, `validate_completion.gd` lanes). Also R24 (top-left HUD order).

**Outcome.** The HUD makes progress and reward felt without clutter:

- **Progress:** numbers roll to their new values. A thin completion bar fills and shines when progress increases.
- **Money:** money gets its own gold line with a coin glyph. It counts up, bumps, and floats `+$N`.
- **Bag:** a small bag bar fills, turns amber near capacity and red-ish when full, bumps on each item, and shakes on a "Bag full" rejection.
- **Notices:** notices slide and fade in with a tier glyph: info for tips, check for sets, star for restoration. Restoration notices get a gold border and a shine.
- **Feedback toast:** the gameplay feedback panel eases in and shakes on rejections.
- **World cues:** `main.gd` emits the world cues (`set_complete`, `section_restored`, `zone_restored`, `run_complete`) through `player.play_cue` for J13 rumble.

**Own files:**

| File | Change |
|---|---|
| `scenes/main.tscn` | Three HUD panels |
| `scripts/main.gd` | HUD functions only |
| `shaders/ui_shine.gdshader` | New |
| `scripts/ui/feel_icon.gd` | New, if J08 has not created it |

Text contracts stay intact:

- `progress_label.text` keeps its first four lines exactly. The money line moves to the new `MoneyLabel`, still inside the top-left panel after the breakdowns, so R24's order holds.
- `context_label.text` is unchanged.
- `guidance_label.text` is unchanged.
- `error_label.text` semantics are unchanged.

## Steps

### 1. Restructure the three panels (`scenes/main.tscn`)

Do this in the editor, keeping every existing unique name. The resulting subtrees:

```text
UI/ProgressPanel (PanelContainer, unchanged anchors/offsets)
  ProgressStack (VBoxContainer, separation 4)
    ProgressLabel (%ProgressLabel, unchanged; text now 4 lines)
    CompletionBar (%CompletionBar, ProgressBar, custom_minimum_size (0, 8), show_percentage = false)
    MoneyRow (HBoxContainer, separation 6)
      MoneyIcon (FeelIcon, kind COIN, color FEEL.money_color, custom_minimum_size (18, 18))
      MoneyLabel (%MoneyLabel, Label, font size 19, font colour FEEL.money_color, text "$0")
UI/ContextPanel (unchanged anchors/offsets)
  ContextStack (VBoxContainer, separation 4)
    ContextLabel (%ContextLabel, unchanged)
    BagBar (%BagBar, ProgressBar, custom_minimum_size (0, 6), show_percentage = false)
UI/GuidancePanel (unchanged anchors/offsets)
  GuidanceRow (HBoxContainer, separation 10)
    NoticeIcon (%NoticeIcon, FeelIcon, custom_minimum_size (22, 22), size_flags_vertical = center)
    GuidanceLabel (%GuidanceLabel, unchanged; size_flags_horizontal = expand_fill)
```

- Give `CompletionBar` and `BagBar` `StyleBoxFlat` background and fill styles: background `Color(0, 0, 0, 0.35)`, corner radius 3; fill `FEEL.bag_color_normal` for both at first.
- Put a `ShaderMaterial` with `ui_shine.gdshader` on `CompletionBar`.
- Add `@onready` references in `main.gd` for `completion_bar`, `money_label`, `bag_bar` and `notice_icon`.

`shaders/ui_shine.gdshader`:

```glsl
shader_type canvas_item;

// Diagonal highlight band for HUD bars and banners. `progress` sweeps -0.3 -> 1.3.
uniform float progress = -1.0;
uniform float width = 0.18;
uniform float strength = 0.6;
uniform vec2 rect_size = vec2(100.0, 10.0);

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float diagonal = (local_position.x + local_position.y * 0.35) / max(rect_size.x, 1.0);
	float band = 1.0 - smoothstep(0.0, width, abs(diagonal - progress));
	COLOR = vec4(base.rgb + vec3(band * strength) * base.a, base.a);
}
```

Helper `_shine(control)`: set the material's `rect_size = control.size`, then run a `FeelMotion.tween(control)` `tween_method` over `progress` from −0.3 to 1.3 across `FEEL.bar_shine_seconds`. Skip it when reduced.

### 2. Count roll in `_update_progress(session)`

Replace the body with a displayed-value model. The first render of a session is instant.

```gdscript
var _shown := {}
var _shown_session: RunSession
var _progress_tween: Tween


func _update_progress(session: RunSession) -> void:
	var service := session.progress_service
	var waste_total := 0
	var props_total := 0
	for section_value in session.state.section_states.values():
		waste_total += int((section_value as Dictionary).required_waste)
		props_total += int((section_value as Dictionary).required_props)
	var target := {
		"complete": float(service.completed_waste + service.completed_props),
		"props": float(service.completed_props),
		"waste": float(service.completed_waste),
		"money": float(int((session.state.players[&"local"] as Dictionary).money)),
	}
	var totals := {"required": session.state.required_total, "props_total": props_total, "waste_total": waste_total}
	var first := _shown_session != session or _shown.is_empty()
	var start := target.duplicate() if first else _shown.duplicate()
	_shown_session = session
	var reduced := FeelMotion.reduced(settings_store)
	var largest := 0.0
	for key in target:
		largest = maxf(largest, absf(float(target[key]) - float(start[key])))
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_react_to_progress(start, target, first, reduced)
	if first or reduced or largest <= 1.0 or _money_held():
		_shown = target.duplicate()
		if _money_held():
			_shown["money"] = start["money"]
		_render_progress(totals)
		return
	_progress_tween = FeelMotion.tween(progress_panel)
	_progress_tween.tween_method(func(t: float) -> void:
		for key in target:
			if key == "money" and _money_held():
				continue
			_shown[key] = lerpf(float(start[key]), float(target[key]), t)
		_render_progress(totals)
	, 0.0, 1.0, FeelMotion.count_seconds(largest)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_progress_tween.tween_callback(func() -> void:
		var keep_money := float(_shown.get("money", target["money"]))
		_shown = target.duplicate()
		if _money_held():
			_shown["money"] = keep_money
		_render_progress(totals)
	)
```

- `_render_progress(totals)`:
  - Sets `progress_label.text` using exactly today's format without the trailing `\n$…` line: `"Completed %s / %s\nRemaining %s\nProps %s / %s\nTrash collected %s / %s"`, built from `roundi(_shown.*)` with `_comma`.
  - Sets `completion_bar.max_value = totals.required` and `completion_bar.value = _shown.complete`.
  - Sets `money_label.text = "$" + _comma(roundi(_shown.money))`.
- `_react_to_progress(start, target, first, reduced)`: on a non-first increase, when not reduced:
  - If `complete` rose: `_shine(completion_bar)` and `FeelMotion.bump_control(completion_bar, 1.04, 0.14)`.
  - If `money` rose and money is not held: `FeelMotion.bump_control(money_label, FEEL.bump_scale, FEEL.bump_seconds)` and `_float_money(delta)`.
  - When reduced and money rose, flash `money_label.modulate` to (1.3, 1.25, 1.0) and back once instead.
- `_float_money(amount)`:
  - A `Label` added under `UI`, text `"+$%d"`, gold with a dark outline (`outline_size` 6), placed at the money label's global rect right edge + 6 px.
  - Tween it up 24 px and to alpha 0 over `FEEL.money_float_seconds`, then free it. At most 3 at once.
- `_money_held()` returns `Time.get_ticks_msec() < _money_hold_until`. J10 sets `_money_hold_until` while coins are flying so each coin arrival can step the money display. Declare `var _money_hold_until := 0` here.

`validate_ui.gd` reads the label right after run start (a first render, so instant) and after one pickup (no completion change). Both stay exact.

### 3. Bag bar in `_update_context(session)`

Keep the label text code. Then:

- `ratio = bag_count / capacity`.
- Set `bag_bar.max_value = capacity`. Tween `value` to `bag_count` over 0.15 s, or set it directly when reduced.
- Choose the fill style: `bag_color_full` at ratio ≥ 1, `bag_color_warn` at ratio ≥ `FEEL.bag_warn_ratio`, otherwise `bag_color_normal`. Pre-make the three `StyleBoxFlat` in `_ready`.
- When `bag_count` rose compared with the last call and motion is not reduced, call `FeelMotion.bump_control(bag_bar, 1.08, 0.14)`.
- Track `_last_bag_count` per session and reset it in `clear_run()`.

### 4. Notices with motion and glyphs

In `_show_next_notice()`, after setting the text:

- Glyph by priority:

| Priority | Kind | Colour |
|---|---|---|
| ≥ 2 | STAR | `FEEL.money_color` |
| 1 | CHECK | `FEEL.ghost_color` |
| 0 | INFO | white |

- Panel border: gold for priority 2. Use a duplicate of the panel's style with `border_color` changed; restore the default for the others.
- Unless reduced:
  1. Capture the base position once, in meta `&"base_position"`.
  2. Set `modulate.a = 0` and `position.y = base.y - FEEL.notice_rise_px`.
  3. Tween both back over `FEEL.notice_in_seconds` (`TRANS_BACK`/`EASE_OUT`).
  4. For priority 2, also `FeelMotion.bump_control(guidance_panel, 1.05, 0.2)` and run a shine on the panel (give `GuidancePanel` a `ui_shine` material too).
- When the queue empties, fade `modulate.a` to 0 over `FEEL.notice_out_seconds` and then hide.
- `_clear_notices()` still hides immediately and resets `modulate.a = 1` and the base position.

`validate_completion.gd` checks `guidance_panel.visible` and its text while the restoration notice shows. Visibility is set synchronously; only alpha animates.

### 5. Feedback toast and rejection reactions

- **`_show_gameplay_feedback`:** after `error_panel.show()`, unless reduced, fade in from `modulate.a = 0` over 0.1 s and slide up 6 px, using the same base-position pattern. `clear_error()` still hides at once and resets alpha.
- **Cue reactions:** in `_open_run`, connect `player.cue_played` to `_on_player_cue(cue, info)`:
  - `&"rejected"` or `&"vacuum_full"`:
    - If `error_panel.visible`, call `_shake(error_panel)`.
    - If the reason contains "Bag full" or the cue is `vacuum_full`: `_shake(context_panel)` and flash `bag_bar.modulate` to (1.5, 1.2, 1.2) and back over 0.3 s.
- **`_shake(panel)`:**
  1. If there is no meta `&"shake_base"`, store `panel.position` in it.
  2. `FeelMotion.replace(panel, &"shake", FeelMotion.tween(panel))`, then `tween_method` over 0 → 0.2 s setting `position.x = base.x + FeelMotion.shake_offset(e, 0.2, 5.0)`.
  3. Finally restore `position = base` and remove the meta.

  Skip the shake when reduced; keep the colour flash.

### 6. Emit world cues

These are presentation hooks only. In the existing session signal handlers in `_open_run`:

- `group_completed`: `player.play_cue(&"set_complete", payload)`.
- `section_restored`: `player.play_cue(&"section_restored", {"section_id": str(section_id)})`.
- `zone_restored`: `player.play_cue(&"zone_restored", {"zone_id": str(zone_id)})`.
- `run_completed`: `player.play_cue(&"run_complete")`, before `results_view.show_receipt(...)`.

## Reduced motion

- Numbers are set instantly, with no bumps, slides, shakes, shines or floaters.
- The money line flashes once on gain.
- Bars change value without tweens.
- Colour states and glyphs remain.

## Validation

1. Re-run:
   - `validate_ui.gd`: exact label prefixes, bag and tool text, guidance visible, error panel hidden after reconnect
   - `validate_completion.gd`: 720p lanes do not overlap after the panel grows
   - `validate_payment.gd`
2. In `scenes/main.tscn` at 1280×720, 1920×1080 and 150% UI scale, record:
   - the HUD during five pickups (bag bar and bump)
   - a full-bag rejection (amber to red, shake)
   - a collection paying $80 (the J10 coins arrive later; here the money rolls)
   - a set completion (check notice, `+$15`)
   - a section restoration (star notice, gold border, shine)

   Confirm nothing overlaps the reticle, target label, receipt or scanner summary.
3. Reload a mid-run save: the HUD shows final numbers instantly, with no roll from 0.

## Done when

- The progress, money and bag changes are felt.
- Notices are tiered and animated.
- Rejections reach the HUD.
- Text contracts and layout lanes hold.
- Reduced motion is observed.
- Clips are in J-feel.
