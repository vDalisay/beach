# J13 — Controller vibration (optional)

Dependencies: J04, for the cues. It needs J09's world-cue emissions to cover sets and restoration. Read first: [plan](../12-game-feel.md) §5.3 and §7, and D21 (accessibility settings). **This packet is optional.** It is the only J packet that adds a setting. Skip it entirely if the user does not want vibration; nothing else depends on it.

**Outcome:**

- With a controller as the active input, short, low-intensity vibrations underline the same cues the eye already gets: picks, places, rejections, sets, restorations and the finale.
- A "Controller vibration" toggle (default on) turns it off.
- Vibration never plays for keyboard or mouse input, while paused, or in menus.

**Own files:**

| File | Change |
|---|---|
| `scripts/ui/settings_store.gd` | New setting key; last device |
| `scenes/ui/settings_menu.tscn`, `scripts/ui/settings_menu.gd` | One toggle |
| `scripts/player/player.gd` | `_rumble` inside `play_cue` |

## Steps

1. **Setting.** In `SettingsStore.DEFAULT_VALUES`, add `&"controller_vibration": true`. The existing `set_value` `_:` branch stores it as a bool, and load/save iterate `DEFAULT_VALUES`, so persistence needs no other change.
2. **Last joypad device.** Add `var last_joypad_device := -1`. In `note_input(event)`, when the event is a `InputEventJoypadButton` press or a `InputEventJoypadMotion` over the deadzone, set `last_joypad_device = event.device`.
3. **Settings menu.**
   - Add a `CheckButton` named `ControllerVibration` (unique name) directly after `ReducedMotion` in `settings_menu.tscn`, with the text "Controller vibration".
   - In `settings_menu.gd`, mirror `reduced_motion`:
     - an `@onready` reference
     - `toggled.connect(_on_toggle_changed.bind(&"controller_vibration"))`
     - `button_pressed` set from the store in the refresh function
     - inclusion in the controls array used for focus navigation (near line 200)
4. **Rumble in `BeachPlayer.play_cue`.** After emitting `cue_played`, call `_rumble(cue, info)`:

```gdscript
func _rumble(cue: StringName, info: Dictionary) -> void:
	if settings_store == null or not bool(settings_store.get_value(&"controller_vibration")):
		return
	if settings_store.prompt_device != SettingsStore.PromptDevice.CONTROLLER or settings_store.last_joypad_device < 0:
		return
	if get_tree().paused and cue != &"run_complete":
		return
	var pattern: Vector3 = FEEL.rumble.get(cue, Vector3.ZERO)
	if cue == &"detector_ping":
		var strength := float(info.get("strength", 0.0))
		pattern = Vector3(0.05 + 0.10 * strength, 0.0, 0.03)
	if pattern == Vector3.ZERO:
		return
	Input.start_joy_vibration(settings_store.last_joypad_device, pattern.x, pattern.y, pattern.z)
```

A new call replaces any running vibration, so rapid vacuum ticks never stack. `run_complete` fires as results open; allow it once and let it end on its own.

5. **Stop on pause and on disabled input.** In `set_paused(true)` and in `set_input_enabled(false)`, call `Input.stop_joy_vibration(settings_store.last_joypad_device)` when the device is 0 or higher. Also stop on `controller_disconnected`.

## Tuning notes

- The J00 table is intentionally mild. Weak motor is used for "soft" feedback and strong only for rejections and big moments.
- Keep every pattern at or under 0.6 s and at or under 0.4 magnitude, except that `run_complete` may reach 0.6 s.
- Test on at least one physical controller. Record the model, because motors differ widely.
- If no physical controller is available, record this packet as blocked on hardware, as FIN-04 does. Injected input cannot verify vibration.

## Validation

1. Re-run `validate_ui.gd` (settings screen, focus, disconnect) and `run_checks.gd` (settings round-trip).
2. With a physical controller:
   - play a short route: collect, full-bag reject, place, set complete, vacuum, detector approach, truck collection, section restore
   - confirm the toggle stops all vibration
   - confirm keyboard or mouse input produces none
   - confirm pause stops a running pattern
   - confirm a disconnect mid-pattern leaves no stuck motor
3. Record the device and observations in J-feel.

## Done when

- The toggle works and persists.
- Vibration follows the cue table only for controller input.
- Nothing vibrates while paused or in menus.
- A physical-device run is recorded, or the packet is explicitly blocked on hardware.
