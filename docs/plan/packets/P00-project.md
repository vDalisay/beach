# P00 — Root project and runnable foundation

Dependencies: none. Requirements: R01, R29, R32. Read: [starting point](../README.md), [architecture](../02-architecture.md).

**Outcome:** a cleanly booting GDScript project with a small native verification entry point. This is infrastructure for the full release, not a demo.

**Own files:** `project.godot`, `scenes/main.tscn`, `scripts/main.gd`, `tests/run_checks.gd`, `.gitignore`, a local `Assets/Synty/.gdignore`, `docs/handoffs/P00.md`. Preserve the original empty `node_3d.tscn` until no references exist; deleting it is optional.

**Steps**

1. Confirm executable/version and inspect current settings. Before root-editor import, exclude the nested conversion project using a documented local `Assets/Synty/.gdignore`; P01's FileAccess staging can still read those source files. Set `run/main_scene` to main. Keep GL Compatibility and Jolt initially. Remove stale .NET assembly configuration only after confirming no C# files exist; use GDScript exclusively.
2. Create main's boot/error/menu placeholder and explicit run-root creation/freeing route. No global inventory or autoload event bus. Main can show a basic native Label/Button until P22 supplies final screens.
3. Set resizable window defaults to 1920×1080 with scalable Controls. Leave detailed input actions to P03; reserve the root UI layer and loading/error presentation.
4. Add the test runner with case selection, accumulated failures and explicit nonzero exit. Its boot check instantiates/frees main without loading the entire vendor project.
5. Ignore build outputs and local generated assets, retaining the existing vendor ignore. Do not commit `.godot` or licensed archives. Record executable path as a local command example, never a runtime dependency.

**Acceptance:** root opens in the specified editor; main runs with no GDScript errors; headless boot case exits zero; a deliberately failed check exits nonzero. No C# build requirement is introduced.

**Do not add:** menu framework, scene-transition framework, plugin dependencies, multiplayer bootstrap or automated CI service configuration.

**Handoff:** record root settings, engine output and exact boot/test commands. Note vendor import work belongs to P01, rather than pretending assets already load.
