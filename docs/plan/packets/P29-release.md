# P29 — Full-run integration and Windows release build

Dependencies: P24, P26, P27, P28. Requirements: R01–R29; R30/R31 only their agreed preparation/deferment.

**Outcome:** a verified full-game Windows build with honest release evidence and remaining-art status.

**Own files:** `export_presets.cfg`, necessary runtime catalog/export inclusion resources, `docs/release-checks.md`, `docs/handoffs/P29.md`. Build outputs remain ignored.

**Steps**

1. Run the existing small written checks and the generator validator over 100 seeds with no script/import failures. Review scene-based evidence for the validation scenarios; do not create a separate automated suite to mirror the checklist. Verify each dependency packet has a handoff and no unresolved completion or data-loss issue.
2. Perform the state-sequence matrix and at least one full human-paced 5,700-object run without debug completion. Document last-item recoverability, habitat events, controller sorting, economy, all required tools and post-results roaming.
3. Validate fresh install/new run, multiple saves, same-seed independent runs, save-and-quit at table, corrupted latest autosave recovery and no-save-success-on-disk-failure. Preserve existing save files while testing updates.
4. Create Windows x86_64 export using matching 4.6.1 templates and GDScript-only runtime. Include dynamic catalog dependencies explicitly; path strings alone may not establish export references. Exclude vendor archives/conversion project, caches, tools, tests and plan reference images.
5. Run the exported build separately from editor, on a machine without Godot/.NET SDK where available. Verify all scene/material paths, save paths, controller detection and startup work. Keep all runtime paths platform-independent.
6. Compare P25/P27 visual evidence and P28 performance report against the release gate. Remaining cube models must be listed as user-supplied-art gaps; functional completeness and final visual readiness are separate statuses.
7. Produce final handoff with build path/version, seed/version used, actual checks, missing assets and any genuine unverified hardware claim. No publishing or storefront integration is part of this packet.

**Acceptance:** all required functional/save/integration criteria pass; target hardware and art readiness are reported accurately. Optional jetski, online leaderboards, multiplayer and sound are not release blockers.

**Do not add:** a demo branch/build, live leaderboard stub, online login, human visitors or a marketing/release schedule.

**Handoff:** Windows build path/version, completed verification matrix, full-run result receipt, target-hardware evidence, unresolved art register and explicit functional/visual readiness status.
