# P04 — First-person player and hand presentation

Dependencies: P02, P03. Requirements: R05, R07. Read: [movement defaults](../04-content-and-balance.md).

**Outcome:** comfortable first-person walking, jumping, sprinting and crouching with a reusable hand rig.

**Own files:** `scenes/player/player.tscn`, `scripts/player/{player,movement,hand_rig}.gd`, `tests/scenes/movement_lab.tscn`.

**Steps**

1. Compose CharacterBody3D with exported InputReader/Movement/HandRig references. Player root wires components and passes intents. Movement owns velocity/gravity/move_and_slide and floor handling.
2. Use baseline 3.5 m/s with sprint/crouch multipliers. Crouching changes capsule/eye height only when safe; check ceiling before standing. Normalize diagonal movement. Keep sprint independent of land stamina.
3. Implement yaw and clamped pitch, mouse capture/pause release, FOV settings and no compulsory head bob/camera shake. Default jump and floor snap must traverse beach stairs without auto-climbing walls.
4. Add left/right hand anchors and distinct sockets for permanent bag, active handheld tool, two small props and a two-handed large prop. Visual state is driven by Carry later; this packet provides pose/visibility methods, not a second inventory.
5. Use verified Synty hands if available or labelled skin-coloured cubes. Resolve near-plane clipping by reasonable viewmodel scale/clipping setup; do not change world pickup range to fix a visual issue.
6. Expose swimming mode/movement inputs for P18 through explicit methods, without implementing an unused general state-machine framework.

**Acceptance:** movement lab verifies walls, ramps, pier-height stairs, low ceiling, diagonal speed, jump landing and crouch refusal under obstruction. Controller-only traversal and pause/resume work. Hands stay in the intended side of the frame at supported FOVs.

**Handoff:** capsule dimensions, jump values, hand socket transforms, movement-mode entry points, screenshots and known geometry constraints for P05.
