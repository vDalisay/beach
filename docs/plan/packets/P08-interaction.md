# P08 — Targeting, outlines and contextual actions

Dependencies: P04, P07. Requirements: R06, R09, R29. Read: input/physics contracts and feel defaults.

**Outcome:** precise, readable targeting of litter, props and stations with one contextual action route.

**Own files:** `scripts/player/interactor.gd`, `scripts/ui/target_label.gd`, `scenes/ui/target_label.tscn`, `shaders/hover_outline.gdshader`, `tests/scenes/interaction_lab.tscn`.

**Steps**

1. Query from camera centre within current reach. Return a stable target ID, hit point and permitted actions. Include world occlusion, exclude held/viewmodel/player colliders and prefer the actual frontmost visible surface.
2. Add a modest near-ray tolerance for tiny litter only after ray miss, validating line of sight to the candidate. Do not pick items through a chair, wall, table or sand.
3. Highlight only the current eligible target with a white outline. Test an inverted hull on opaque closed meshes, all submeshes and thin objects; use a target-only alternative if hull artifacts fail visual acceptance. Keep effects per-instance so one can never highlights every can.
4. Position the name near the projected target with viewport clamping and legible backing. Show contextual reasons such as Bag full, Needs cloth or Wrong shelf; no technical node/definition names in the player UI.
5. Route primary/interact/throw intents according to active context. Initially expose signals/call sites for P09–P15, not local fake state changes. Do not trigger an action twice from both InputReader and `_input`.

**Acceptance:** run interaction lab with small glass, thin net, cube, multi-part chair and occluder. Verify target switches, one fresh primary edge, no through-wall action, no stale label on freed view, correct reach and controller aim. Add a runnable selection/occlusion check for frontmost eligible targets.

**Handoff:** target result format, action precedence, effect cleanup method, reach setting and bright-sand/underwater test needs for P27.
