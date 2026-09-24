# J02 — Reactive reticle and living target label

Dependencies: J01. Read first: [plan](../12-game-feel.md) §2 pillar 1, §7, §8 and §11.2 (`validate_interaction.gd`, `validate_c01_input.gd`). Also [P22](P22-ui.md) step 2: notifications never cover the crosshair.

**Outcome:**

- A small reticle at the screen centre tells the player what a click will do before they click:
  - a dot when nothing is targeted
  - a ring for actionable targets
  - a dashed amber ring for blocked targets
  - corner brackets for a valid placement
  - a spinning dashed ring while the vacuum runs
- It pops on success and shakes on rejection within the same frame.
- The target label fades and rises in when the target changes, follows its target smoothly, takes an amber border when blocked, and shakes on a rejected click.
- The label text is unchanged, because checks read it.

**Own files:**

| File | Change |
|---|---|
| `scripts/ui/reticle.gd`, `scenes/ui/reticle.tscn` | New |
| `scenes/main.tscn` | Add the `Reticle` instance under `UI`, directly before `TargetLabel` |
| `scripts/main.gd` | Configure and clear the reticle |
| `scripts/ui/target_label.gd` | Motion and style only |

## Steps

### 1. Share the actionability rule

Use J01's public `PlayerInteractor.style_for(result: Dictionary) -> int`. The reticle and the label use the same rule, so the outline, the reticle and the label always agree. If J01 shipped the helper as private, rename it now.

### 2. Reticle scene and script

`scenes/ui/reticle.tscn` is a full-rect `Control` named `Reticle`, with `mouse_filter = 2` (ignore) and script `scripts/ui/reticle.gd`:

```gdscript
class_name Reticle
extends Control
## Centre reticle. Presentation only: it reads targets and cues, never input or state.

enum Mode { IDLE, ACTION, BLOCKED, PLACE }

const FEEL := preload("res://data/feel/feel_tuning.tres")
const SUCCESS_CUES: Array[StringName] = [
	&"poke", &"hold", &"hold_bag", &"place", &"deposit", &"clean", &"cut",
	&"reveal", &"sift", &"scanner_pulse", &"collect_call",
]

var player: BeachPlayer
var mode := Mode.IDLE
var _radius := 2.5
var _radius_velocity := 0.0
var _pop := 0.0
var _pop_velocity := 0.0
var _shake_elapsed := 99.0
var _flash := 0.0
var _spin := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	set_process(false)


func configure(beach_player: BeachPlayer) -> void:
	player = beach_player
	if not player.interactor.target_changed.is_connected(_on_target_changed):
		player.interactor.target_changed.connect(_on_target_changed)
	if not player.cue_played.is_connected(_on_cue):
		player.cue_played.connect(_on_cue)
	mode = Mode.IDLE
	_radius = FEEL.reticle_dot_px
	set_process(true)


func clear() -> void:
	player = null
	hide()
	set_process(false)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		hide()
		return
	var active := player.input_enabled and not get_tree().paused and player.camera.current \
		and player.input_reader.context == InputReader.Context.WORLD
	visible = active
	if not active:
		return
	var reduced := FeelMotion.reduced(player.settings_store)
	var target := _mode_radius()
	if reduced:
		_radius = target
		_radius_velocity = 0.0
		_pop = 0.0
	else:
		var r := FeelMotion.spring(_radius, _radius_velocity, target, FEEL.reticle_spring_hz, delta)
		_radius = r.x
		_radius_velocity = r.y
		var p := FeelMotion.spring(_pop, _pop_velocity, 0.0, FEEL.reticle_spring_hz * 1.4, delta)
		_pop = p.x
		_pop_velocity = p.y
	_shake_elapsed += delta
	_flash = move_toward(_flash, 0.0, delta * 4.0)
	_spin += delta * (4.0 if _vacuum_running() else 0.0)
	queue_redraw()
```

Complete the script:

- `_mode_radius()` returns:

| Mode | Radius |
|---|---|
| IDLE | `FEEL.reticle_dot_px` |
| ACTION or BLOCKED | `FEEL.reticle_ring_px` |
| PLACE | `FEEL.reticle_place_px` |

- `_vacuum_running()`:
  ```gdscript
  var session := player.interactor.session
  return session != null and session.vacuum_tool != null and session.vacuum_tool.is_active() and player.input_reader.pressed(&"primary")
  ```
- `_on_target_changed(result)`:
  - Empty result: IDLE.
  - `actions.has("place")`: PLACE.
  - `kind == "slot"` without place: BLOCKED.
  - Otherwise `player.interactor.style_for(result)`: BLOCKED gives BLOCKED, ACTION or SOFT gives ACTION, anything else gives IDLE.
- `_on_cue(cue, info)`:
  - `&"rejected"` or `&"vacuum_full"`: set `_shake_elapsed = 0.0` and `_flash = 1.0`, even under reduced motion. `_draw` skips the shake offset when reduced.
  - A success cue, when not reduced: set `_pop = -3.0` and `_pop_velocity = FEEL.reticle_pop_px * 26.0`. The spring contracts, overshoots outward, then settles.
  - `&"clean_done"`: use twice the velocity.
- `_draw()`:
  - Centre: `size * 0.5` plus `Vector2(FeelMotion.shake_offset(_shake_elapsed, FEEL.reticle_shake_seconds, FEEL.reticle_shake_px), 0)`, with no offset when reduced.
  - Tint: white mixed toward `FEEL.hover_blocked_color` by `_flash`.
  - Draw a dark backing (`FEEL.hover_backing_color`, alpha 0.7, width + 2 px) under every shape. Use antialiased `draw_arc`, `draw_circle` and `draw_polyline`.

| Mode | Shape |
|---|---|
| IDLE | Filled dot at `FEEL.reticle_dot_px`, alpha `FEEL.reticle_idle_alpha` |
| ACTION | Full ring at `_radius + _pop`, width `FEEL.reticle_ring_width_px`, plus a 1.5 px centre dot |
| BLOCKED | Eight amber dashes around the ring (`draw_arc` from `TAU * i / 8` spanning `TAU / 16`). Dashes are the colour-independent signal. |
| PLACE | Four mint (`FEEL.ghost_color`) corner brackets at ±radius. Each is a 3-point polyline from 45% along one edge, to the corner, to 45% along the other edge. |
| Vacuum running | Replaces IDLE or ACTION: twelve short white dashes rotated by `_spin` |

Sizes are in the UI's logical pixels (1280×720 canvas-items stretch), so the existing UI-scale setting scales the reticle with the HUD.

### 3. Wire the reticle

In `scenes/main.tscn`, add `[node name="Reticle" parent="UI" instance=ExtResource(...reticle.tscn)]` immediately before the `TargetLabel` node, so the label draws above the reticle.

In `main.gd`:

- Add `@onready var reticle: Reticle = $UI/Reticle`.
- In `_open_run`, after `target_label.configure(...)`, call `reticle.configure(player)`.
- In `clear_run()`, call `reticle.clear()`.

The scanner already avoids the centre 140×100 rectangle (`ScannerService._marker_position_clear`). Keep the reticle inside it. Guidance and receipts use other lanes.

### 4. Target label motion and state

Edit `scripts/ui/target_label.gd`. Do not change `_refresh_text()` or `_action_text()`. `text_label.text` stays exactly as it is today.

1. Add these fields: `var player: BeachPlayer`, `var _shown_id := ""`, `var _position := Vector2.ZERO`, `var _rise := 0.0`, `var _shake_elapsed := 99.0`, `var _normal_style: StyleBox`, `var _blocked_style: StyleBoxFlat`.
2. In `_ready()`, set `_normal_style = panel.get_theme_stylebox(&"panel")` and `_blocked_style = (_normal_style as StyleBoxFlat).duplicate()` with `border_color = FEEL.hover_blocked_color`.
3. In `configure()`, set `player = interactor.get_parent() as BeachPlayer` and connect `player.cue_played` to `_on_cue`, guarded like the existing connections.
4. In `_on_target_changed(result)`, after `_refresh_text()`:
   - If `str(result.get("id", "")) != _shown_id`: store the id, set `_position` to the projected point (see step 5), and play the in-animation unless reduced:
     - `panel.pivot_offset = Vector2(0, panel.size.y)`
     - `panel.modulate.a = 0.0`
     - `panel.scale = Vector2(0.92, 0.92)`
     - `_rise = FEEL.label_rise_px`
     - one `FeelMotion.tween(panel)`: `modulate:a` → 1 and `scale` → `Vector2.ONE` over `FEEL.label_in_seconds` (`TRANS_BACK`/`EASE_OUT`), plus a parallel `tween_method` driving `_rise` → 0
   - Apply `_blocked_style` when `player.interactor.style_for(result) == HoverHighlight.Style.BLOCKED`, or when the target is a slot without `place`. Otherwise apply `_normal_style` (`panel.add_theme_stylebox_override(&"panel", ...)`).
5. In `_process(delta)`, compute the same `projected` point as today, then position the panel:

```gdscript
var reduced := FeelMotion.reduced(player.settings_store) if player != null else true
_position = projected if reduced else _position.lerp(projected, 1.0 - exp(-FEEL.label_follow_hz * delta))
_shake_elapsed += delta
var shake := 0.0 if reduced else FeelMotion.shake_offset(_shake_elapsed, FEEL.reticle_shake_seconds, FEEL.label_shake_px)
panel.position = Vector2(
	clampf(_position.x + shake, 12.0, viewport_size.x - panel_size.x - 12.0),
	clampf(_position.y - panel_size.y + _rise, 12.0, viewport_size.y - panel_size.y - 12.0))
```

6. `_on_cue(cue, _info)`: on `&"rejected"` while visible, set `_shake_elapsed = 0.0` and apply `_blocked_style` for 0.35 s using a pause-safe timer, then re-evaluate the style.
7. In `clear_target()`, also reset `_shown_id = ""`, `panel.scale = Vector2.ONE` and `panel.modulate.a = 1.0`. It must still hide synchronously: `validate_interaction.gd` checks that a freed target hides the label.

## Reduced motion

- The reticle changes state instantly, with no pop or shake. The amber flash is kept (colour change, no motion). Dashes and brackets remain.
- The label has no rise, scale, follow smoothing or shake. The style still changes.

## Validation

1. Re-run `validate_interaction.gd` and `validate_c01_input.gd`. Label text contracts must pass unchanged. Re-run `validate_ui.gd` for no HUD overlap.
2. In `scenes/main.tscn` (seed `first-shore`), walk the arrival area and record short clips (Movie Maker or screen capture) of:
   - dot → ring on a can, and a pop on collect
   - bag full → dashed ring and a label shake on click
   - holding a bucket → brackets over a valid shelf slot, and the dashed ring over an incompatible shelf
   - vacuum spinning ring (staged ownership via a probe is acceptable; state it in the handoff)
3. Check at 720p, 1080p and UI scale 150% that the reticle stays centred and crisp and never covers the target label or scanner markers.
4. Confirm the reticle hides in the sorting view, booklet, pause, results and settings, and reappears on return.

## Done when

- The reticle states and cues behave as described in the real game.
- The label animates, follows, styles and shakes, with its text unchanged.
- Checks pass.
- Reduced motion is observed.
- Clips and stills are in J-feel.
