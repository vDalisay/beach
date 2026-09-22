# P03 — Native input, remapping and settings

Dependencies: P00. Requirements: R05, R29. Read: [input contract](../02-architecture.md).

**Outcome:** all gameplay/UI intents have keyboard and gamepad actions, with saved remapping and usable focus behavior.

**Own files:** `scripts/player/input_reader.gd`, `scripts/ui/settings_store.gd`, `scripts/ui/settings_menu.gd`, `scenes/ui/settings_menu.tscn`, InputMap entries in `project.godot`.

**Steps**

1. Create every action in the input table, using physical keys for movement. Use Input.get_vector for movement/deadzones. InputReader exposes intents only and never moves bodies or transfers items.
2. Separate mouse-motion delta from right-stick angular velocity; the latter uses delta time. Settings cover sensitivity, deadzone, invert Y, FOV, UI scale, reduced motion and sprint/crouch toggles.
3. Capture button/key/axis events for remapping; ignore noise below deadzone and key echoes. Show context-aware conflicts and allow replacement/reset. Preserve accessible UI accept/cancel/reset routes.
4. Save overrides in ConfigFile and rebuild actions on startup. Do not serialize hardware-specific paths. Adapt visible prompts to the most recent meaningful device and current binding; stick drift cannot constantly switch prompt style.
5. Implement explicit modal focus/cursor capture transitions. Controller disconnect pauses the singleplayer world and reconnect retains focus. Settings Controls use focus neighbours and a visible outline, not colour alone.

**Acceptance:** `input_bindings` verifies required actions/default bindings and override round-trip. Manually remap primary, move and UI accept, restart, then reset all. Navigate and exit settings with controller only. Mouse sensitivity must not vary with frame rate and controller look must not be tied to raw mouse delta.

**Do not assume:** Godot's device mappings automatically supply the game's remapping screen, prompts, sorting cursor or focus graph.

**Handoff:** final action names, conflict policy, tested devices, settings file format and instructions for other UI packets to enter/exit contexts.
