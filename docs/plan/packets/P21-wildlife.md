# P21 — Returning wildlife and vibrant reef

Dependencies: P01, P18, P20. Requirements: R21, R22. Read: reef reference and section recipes.

**Outcome:** each completed local habitat visibly gains life, including turtle walks into the ocean and more vibrant coral/fish.

**Own files:** `scenes/wildlife/{fish_school,turtle,starfish}.tscn`, `scripts/wildlife/{fish_school,path_animal}.gd`, section wildlife routes/visual roots and material parameter resources.

**Steps**

1. Use supplied models or the registered coloured cubes; never fake a resolved asset request. Fish schools use a small number of shared-mesh instances following authored paths with local offsets. Avoid full flocking simulation or thousands of individual physics bodies.
2. Author separate ambient, rescued and restoration-unlocked populations. Rescue routes start immediately; regional populations require the appropriate restored flag. Stable spawn keys prevent duplicate schools or turtles on signal replay/load.
3. Animate reef colour/vibrancy and local plants/water clarity only for completed section roots. Use per-section uniforms/materials; unrelated regions must not brighten because of shared global material edits.
4. Trigger at least one clear turtle beach-to-water route when the designated beach zone finishes. After entering water, keep that animal within the area's bounded loop. Restored animals never vanish permanently after the one-off flourish.
5. Keep wildlife nonblocking for player/item collision and interaction rays. Small effects may be culled at distance; logical restoration stays saved. Reduced motion shortens presentation without suppressing the final environmental reward.
6. On load, apply restored terminal appearance directly and instantiate only missing population keys. Do not replay a long camera lock or force a cutscene.

**Acceptance:** repeated restoration signals and scene reloads maintain bounded population counts. Before/after captures from identical camera positions clearly show coral and fish changes. Turtles complete the walk/swim route without getting stuck and remain visible in the area. Confirm no human visitors spawn.

**Handoff:** route IDs, population caps, per-section appearance controls, screenshots and unresolved animal/plant assets. P28 profiles the fully restored scene.
