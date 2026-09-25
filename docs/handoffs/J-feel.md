# J-feel handoff — hover, hands, placement, tools and completion

Evidence record for the [game-feel plan](../plan/12-game-feel.md), packets J00–J14. One section per packet, newest entries at the top of each section. Follow [AGENTS.md](../../AGENTS.md): record what was shown working in the real game or an existing lab. A tween existing in code is not evidence.

**Status: in progress.** The plan was written 24 September 2026 on `claude/game-feel-juice-plan` from `main` at `b190cea`. On 25 September 2026 the branch was rebased onto `main` at `e3883f4` before implementation, because `main` had replaced the hand rig (per-socket FOV `View` nodes and IK-driven Synty arms), the tool scenes and `restoration_section.gd`. Packets that touch those files follow the plan's intent on the current code; each entry states where the code departs from a packet listing and why.

| Packet | Status | Evidence |
|---|---|---|
| J00 Foundations and baseline | Done | [J00](#j00--foundations-and-baseline) |
| J01 Hover | Done | [J01](#j01--hover) |
| J02 Reticle and label | Done | [J02](#j02--reticle-and-label) |
| J03 Viewmodel | Done | [J03](#j03--viewmodel) |
| J04 Pickup and throw | Done | [J04](#j04--pickup-and-throw) |
| J05 Placement | Done | [J05](#j05--placement) |
| J06 Tools | Done | [J06](#j06--tools) |
| J07 Completion shine | Done | [J07](#j07--completion-shine) |
| J08 Sorting table | Done | [J08](#j08--sorting-table) |
| J09 HUD | Done | [J09](#j09--hud) |
| J10 Collection and money | Done | [J10](#j10--collection-and-money) |
| J11 Restoration | Done | [J11](#j11--restoration) |
| J12 Finale | Done | [J12](#j12--finale) |
| J13 Rumble (optional) | Done in code; physical pad blocked on hardware | [J13](#j13--rumble-optional) |
| J14 Acceptance | Open | — |

## Entry template

Copy this for each packet entry:

- **Build:** commit, Godot 4.6.1 Mono Compatibility, `beach-content-8`, save schema 1
- **Scene / seed:** e.g. `scenes/main.tscn`, `first-shore`, or the lab name
- **Device / display:** GPU, resolution, FOV, UI scale, input device
- **Setup:** normal play, or staged, and exactly what was staged
- **Actions:**
- **Observed:** include stills and clips under `images/J-feel/`
- **Reduced motion:** observed behaviour
- **Checks run:** script and exit code, using isolated profiles
- **Profile:** only where the packet asks for one; compare with the baseline
- **Retained tuning:** `FeelTuning` fields changed from the defaults, and why
- **Open issues:**

Device for every entry unless stated: Windows 11, Ryzen 5 5600, RTX 3070 (driver 595.79), Godot 4.6.1 Mono, Compatibility renderer, 1920×1080 window, FOV 85, UI scale 100%, keyboard and mouse. Probes were temporary SceneTree scripts driving the real `scenes/main.tscn` or the existing labs; they were not committed.

## Baseline (J00)

Recorded on `cd20478` (plan commit rebased onto `e3883f4`) before any J code.

**Profile** — `tests/validate_physics.gd -- --profile --c04-dense`, 600 frames, two runs, both exit 0:

| Run | Median | Mean | p95 | Max draws | Nodes | Awake bodies | Physics mean |
|---|---|---|---|---|---|---|---|
| 1 | 7.24 ms | 8.90 ms | 18.43 ms | 3,659 | 9,577 | 0 | 1.06 ms |
| 2 | 7.27 ms | 8.97 ms | 18.58 ms | 3,659 | 9,577 | 0 | 1.05 ms |

Views 608, batch items 5,027, Godot static/video memory 176.4 / 1,610.0 MB.

**Stills** — `scenes/main.tscn`, seed `feedback-sequence`, 1920×1080, FOV 85, staged like `tests/record_feedback.gd` (nine starter props committed to slots, the last chair held and placed). These are the "before" images for J14:

| Beat | Still |
|---|---|
| Stick at rest and HUD | ![](images/J-feel/before-stick-rest.png) |
| Hover on a can | ![](images/J-feel/before-hover-can.png) |
| Hover on a glass bottle | ![](images/J-feel/before-hover-glass.png) |
| Holding a chair | ![](images/J-feel/before-hold-chair.png) |
| Ghost over a chair slot | ![](images/J-feel/before-ghost-chair.png) |
| Group sweep, 0.3 s after it began | ![](images/J-feel/before-group-sweep.png) |
| After placement | ![](images/J-feel/before-after-place.png) |

Observed before any change: the can hover is a thin white hull; the placed chair gets no outline while targeted ("Pick up" label only); the old mint group band is already off the chair 0.3 s after it starts; the ghost is a flat green translucent chair.

## J00 — Foundations and baseline

- **Build:** `cd20478` + J00 working tree, Godot 4.6.1 Mono Compatibility, `beach-content-8`, save schema 1.
- **Scene / seed:** `scenes/main.tscn`, `first-shore`.
- **Setup:** normal start; a probe spawned one of each effect 2.2 m ahead of the player.
- **Actions:** spawned a 24-star SPARKLE burst, a 16-puff DUST burst, a `FeelRing` (0.2 → 1.2 m, 1.2 s) and a `FeelFloater` ("Clean!"); paused the tree 6 frames later; waited 0.35 s and 1.8 s under pause; unpaused; freed the test pools; called `player.play_cue(&"poke")`.
- **Observed:** stars face the camera and twinkle, dust puffs are soft and fade, the ring expands and fades, the floater rises and fades ([running](images/J-feel/j00-effects-running.png), [paused 0.35 s later](images/J-feel/j00-effects-paused.png)). Under pause the ring kept expanding, the floater kept rising, particles kept aging, and the ring and floater freed themselves. Node count: 8,632 at start, 8,635 with the two test pools, 8,635 after every effect freed, 8,632 after the pools were freed. `cue_played` emitted `poke`. No shader compile errors or warnings in the log.
- **Reduced motion:** nothing visible is enabled by J00; `FeelFloater.spawn(..., reduced)` fades in place.
- **Checks run:** `tests/run_checks.gd` (headless) exit 0 — boot, asset closure, ownership, input bindings, manifest. `tests/validate_wildlife.gd` (rendered) exit 0 — `P21_WILDLIFE ... failures=0`; BUBBLE and SAND bodies are byte-for-byte unchanged.
- **Departures from the packet:** `FeelMotion.travel` arcs along world up expressed in the travel space instead of the space's local +Y, so a hand socket on a pitched camera still lifts items upward in the world; it also keeps the last known `via` position if the tip node is freed mid-flight. Sparkle and ring shaders add `fog_disabled` per plan §4 rule 10. Pool bounds grow by the largest live quad instead of a fixed 0.1 m so large dust puffs are not culled early.
- **Retained tuning:** none (J00 defaults).
- **Open issues:** none.

## J01 — Hover

- **Build:** J00 commit + J01 working tree, Godot 4.6.1 Mono Compatibility, `beach-content-8`.
- **Scene / seed:** `scenes/main.tscn`, `first-shore`; `tests/scenes/interaction_lab.tscn` for timing and occlusion.
- **Setup:** normal start. Staged only where noted: one bucket committed to a free shelf slot for the slotted case; `bag_capacity` set to 0 for the full-bag case and restored; player and camera teleported to each target.
- **Actions:** hovered a can at 0.6, 1.2 and 1.8 m horizontal distance; the same can with a full bag; a glass bottle; a dirty chair's stain without the cloth; the staged slotted bucket; the S1 sorting table, hotline phone (hovered and not), PMD container and shop counter; shallow-water litter from below the surface. In the lab, sampled the visual root every frame for 450 ms after hover-in and after hover-out, with reduced motion off and on, and forced an outline on a can hidden behind the lab wall.
- **Observed:** [hover styles](images/J-feel/j01-hover-styles.png) — crisp white outline on a dark backing at the same screen width at every distance; the full-bag can switches to the amber dashed outline with no rim; the glass bottle and the stain outline cleanly. [Other targets](images/J-feel/j01-hover-targets.png) — the slotted bucket gets the white outline; stations get only the soft rim (the hotline is visibly brighter hovered than not); underwater litter reads against the seabed. Lab timing: the can pops to 1.066, settles at 1.06 and hops 15 mm in the first 0.1 s; the chair lifts to 1.02 with no hop; after hover-out both visual roots are exactly `ONE`, zero position and zero rotation. A forced outline behind the wall produced no outline pixels on screen. No shader errors on first hover.
- **Reduced motion:** outline at rest width immediately, no lift, hop or wiggle (peak scale 1.000, peak hop 0.000 m), rim breathing off; the blocked dashes remain.
- **Checks run:** `validate_interaction.gd` exit 0 (including the new blocked-style assertion), `validate_dirt.gd` exit 0, `validate_placement.gd` exit 0, `validate_carry.gd` exit 0. `validate_interaction.gd -- --capture` fails its later "held primary input emits one fresh action edge" check; the same failure reproduces on the J00 code, because saving the PNG stalls a frame before the input-edge sequence, so it is pre-existing and unrelated to hover.
- **Written check added:** `validate_interaction.gd` asserts that the full-bag glass is highlighted with a different overlay material from its actionable hover (the plan's optional "blocked never looks actionable" invariant).
- **Departures from the packet:**
  - `hover_outline.gdshader` uses `abs(PROJECTION_MATRIX[1][1])`. The Compatibility renderer flips Y in the projection for its render targets, so the packet's formula produced a negative width and shrank the hull inside the object (no visible outline, dark bands at creases). `VIEWPORT_SIZE` works in `vertex()`; the `viewport_px` fallback was not needed.
  - Rim-only ("see-through") is chosen per mesh from its material (`_is_transparent`), not from the `glass` tag. The glass bottle and jar use the opaque shared Synty atlas, so a hull cannot show through them and they now get the clearer outline.
  - `HoverHighlight` does not descend into nested physics objects, so a dirty chair's outline follows the chair while each stain keeps its own highlight.
  - A hovered stain grows its visual mesh and overlays, not its `Area3D`, so the target collider never scales (plan §4 rule 2).
- **Retained tuning:** none.
- **Open issues:** the disposal-bag-on-rack case is shown with J08, where sealed bags exist. FOV 70/110 hover stills are part of the J14 audit.

## J02 — Reticle and label

- **Build:** J01 commit + J02 working tree.
- **Scene / seed:** `scenes/main.tscn`, `first-shore`.
- **Setup:** normal start. Staged: `bag_capacity` 0 for the full-bag case; one clean bucket held through `try_hold` for the placement cases; the vacuum added to owned and equipped tools and the primary action pressed with `Input.action_press` for the spin (staged ownership).
- **Actions:** looked at open sky; aimed at a can and sent an accepted `poke` cue; filled the bag and clicked the can (a real `request_primary`); held the bucket over the nearest compatible shelf slot and over a chair-row slot; ran the vacuum; opened pause, the booklet and the S1 table and returned; resized to 1280×720 at 100% and 1920×1080 at 150% UI scale.
- **Observed:** [reticle and label sheet](images/J-feel/j02-reticle-label.png) — top row: idle dot, action ring on the can, amber dashes for the full bag, mint corner brackets over the valid slot, dashes over the incompatible slot. Rows 2–4 are frame strips: the ring contracts and springs back after the accepted cue; the dashed ring shakes and flashes after the rejected click; the vacuum ring spins. Bottom: the label takes an amber border for "Bag full" and "This slot does not accept bucket", and keeps the white border for "Place [Left Mouse Button]"; its text is unchanged. The blocked click sent `rejected`. The reticle hid under pause, in the booklet and at the table and came back after each. Its centre matched the viewport centre exactly at both sizes and scales.
- **Reduced motion:** the reticle snaps between states with no pop or shake; the amber flash, dashes and brackets remain; the label appears in place without rise, scale or follow smoothing and still switches border style.
- **Checks run:** `validate_interaction.gd` exit 0, `validate_c01_input.gd` exit 0, `validate_ui.gd` exit 0 (label text contracts and HUD unchanged).
- **Departures from the packet:** the reticle processes while paused (`PROCESS_MODE_ALWAYS`) so it can hide itself under pause, results and settings. Placement brackets run 45% of the half edge from each corner; the listed 45% of the full edge nearly closed the square. `PlayerInteractor.request_primary` now sends `whiff` and `rejected` (J04 step 6), so a real blocked click could be shown here.
- **Retained tuning:** none.
- **Open issues:** the success pop in the real collect flow appears once J04 adds the `poke` cue.

## J03 — Viewmodel

- **Build:** J02 commit + J03 working tree.
- **Scene / seed:** `tests/scenes/movement_lab.tscn` for gaits; `scenes/main.tscn`, `first-shore` for clips, tool switch, bag fill, held props, a chair and swimming.
- **Setup:** real player input through `Input.action_press` for walking, sprinting, crouching and jumping. Staged: the cloth added to owned and equipped tools for the switch; 20 real litter items collected through `try_collect` for the fill; two buckets and then a chair taken through `try_hold`; the player placed in the C08 shallows for swimming.
- **How it fits the current rig:** `main` now keeps gameplay sockets fixed and carries its view-model FOV correction on a `View` node under each socket, with IK-driven Synty arms. J03 therefore composes its motion into those same view nodes instead of re-parenting sockets under `Sway/LeftArm/RightArm`: `ViewmodelAnimator` computes the sway (bob, breathing, look lag, landing, swim float), a clip transform per arm about the packet's elbow pivots and the tool's working motion; `HandRig.apply_motion` applies `correction × sway × arm clip` to each View, the fallback hand anchors and the IK arm targets (`FirstPersonArms.set_motion` adds the clip after its goal smoothing, so palms stay on the tools during fast clips). Clips are sampled by the animator with `Tween.interpolate_value`, not SceneTree tweens, so a cue raised during physics moves the hands in the next rendered frame. Sockets, `socket_transform`, throws and placement sources are unchanged.
- **Observed — gaits (movement lab, sway translation in camera space):**

  | Gait | Mean speed | Horizontal p-p | Vertical p-p | Horizontal sway |
  |---|---|---|---|---|
  | Walk | 3.39 m/s | 24 mm | 13 mm | 1.0 Hz |
  | Sprint | 4.83 m/s | 31 mm | 20 mm | 1.25 Hz |
  | Crouch walk | 1.72 m/s | 12 mm | 10 mm | 0.5 Hz |
  | Idle | 0 | 0 | 8 mm (breathing) | — |
  | Carrying a chair (main scene) | 2.66 m/s | 25 mm | 15 mm | heavier bob |
  | Swimming, idle (main scene) | 0 | 14 mm | 24 mm | slow float |

  A jump dips the hands 54 mm on landing, about 1.08 s after take-off.
- **Observed — clips and states:** [clip sheet](images/J-feel/j03-clips.png) — each row is rest, then three moments of poke, reach (both arms), place, toss, wipe, slash, dig, sift, recoil, choke, reject (left arm), the cloth rising after a switch from the stick, the bag catch squash, the full-bag wobble and a reduced-motion poke. [Rest, held props and bag](images/J-feel/j03-rest-held-bag.png) — top: the rest view at FOV 70, 85 and 110 keeps main's framing; middle: with two buckets, the selected one lifts and gets the soft rim, and cycling moves it; bottom: the bag at 0, 10 and 20 items. Right after each switch the tool `View` held exactly one child while the old tool fell away under the rig. Across every clip frame, the closest tool tip, socket or palm stayed 220 px from the screen centre at 1080p (the two-arm reach), so nothing crosses the aim point.
- **Tool tips:** [measured working ends](images/J-feel/j03-tool-tips.png) (magenta) on main's new tool models; retained in `feel_tuning.tres` (table below).
- **Reduced motion:** sway, landing and breathing stay exactly at identity in every gait and at idle; clips play at 50% with no overshoot; bag fill still follows the fill level; no bag squash or roll; the tool swap has no drop animation.
- **Checks run:** `validate_movement.gd`, `validate_carry.gd`, `validate_purchases.gd`, `validate_release_pack.gd`, `validate_dirt.gd`, `validate_tool_filters.gd`, all exit 0.
- **Departures from the packet:** motion is composed into the View nodes and IK targets as above rather than a `Sway/LeftArm/RightArm` node tree; clips are sampled procedurally; the look sway lags the view (turning right swings the hands left) where the packet's signs would lead it; the detector sweep fades out with its activity instead of persisting at 60%; the held-prop soft rim no longer restarts the hovered target's outline-width pop.
- **Retained tuning:** `tool_tips` for all six tools (below).
- **Open issues:** the plan's 10-second video clips are replaced by frame sheets and numeric traces, following the earlier C07/FIN handoffs; a single recording is part of J14.

## J04 — Pickup and throw

- **Build:** J03 commit + J04 working tree.
- **Scene / seed:** `scenes/main.tscn`, `first-shore`.
- **Setup:** real `request_primary` and `request_throw` routes for the collect, chair pickup and throws; the bucket placed and removed through `try_place`/`try_remove`; a six-item PMD bag staged onto the S1 table, sorted and sealed through the station to get a rack bag; the spam case commits 15 items with `try_collect` in one frame.
- **Observed:** [traced paths](images/J-feel/j04-paths.png) (yellow = the item's screen path, magenta = the stick tip), each drawn over a mid-flight frame:
  - Stick collect (top left): the can pops to 1.15 for 60 ms, slides to where the stick shaft meets the sand, then flicks up into the bag mouth, spinning and shrinking only in the last half; a dust puff and glints mark where it lay. Trace: y stays 0.15–0.18 m to the stab point, then rises to 0.78 m while scaling 1.15 → 0.82 → out.
  - Chair (top right): lifts with a wiggle for 70 ms, arcs up into both hands and arrives at 0.40, the in-hand scale, so it never pops; the carry speed (0.8) applies on the click, not on arrival.
  - Throw (bottom left): the can leaves the hand and flies forward; on landing it hit at 2.31 m/s, squashed to 0.85 height, puffed four dust quads and returned exactly to `ONE`.
  - Slot removal (bottom right): the bucket copy lifts 6 cm off its slot, then travels into the hand, shrinking to 0.35; the reticle already shows the brackets over the freed slot.
  - Rack and container: a sealed bag lifted off the S1 rack and out of the PMD container each travelled into the hand (probe frames, not kept).
  - Underwater collect: bubbles instead of dust where the item lay.
  - Spam: 15 commits in one frame kept at most 12 flights, and after 1.2 s none were left in the air.
  - Save during a flight, then load: the can was in the bag, with no stray view and no invariant errors.
  - Faint (release all + cancel presentations) inside a prop pickup flight: exactly one world view afterwards.
- **Reduced motion:** a collected item's view is freed at once (puff at half count, bag fill still updates); prop pickups travel straight over the same duration with no lift or wiggle; landings puff at half count with no squash.
- **Checks run:** `validate_carry.gd`, `validate_interaction.gd`, `validate_placement.gd`, `validate_physics.gd`, `validate_save_physics.gd`, `validate_tool_filters.gd`, `validate_sealing.gd`, plus `validate_movement.gd`, `validate_purchases.gd` and `validate_dirt.gd` after the hand-rig change, all exit 0.
- **Fixes found while validating:**
  - Carried throws did not launch. The throw commit stores the launch velocity and `restore_from_record` applies it while the body is still frozen, which Jolt discards, so thrown items dropped at the player's feet (identical with the tumble off). The thrown view now re-applies the recorded velocity once active. This is the only gameplay-visible change in J04; it makes the view match the committed record.
  - `HandRig._clear_socket` also freed the socket's direct children, which is where in-flight presentations live, so a hand refresh during a pickup (a second pickup, a slot removal) destroyed the flying view and could leave its id stuck as "presenting". It now clears only the visuals under the socket's View.
  - `validate_carry.gd` requires the large-prop carry speed within 0.3 s of the click; it was applied only when the flight landed. `_hold_target` now refreshes the hands (skipping the flying view) right after the commit, so the speed applies at once.
- **Departures from the packet:** the stick waypoint is the point where the shaft meets the ground when main's longer stick has its spike below the sand (looking down), so items never dive underground; `WorldItem.travel_to` takes the packet's options dictionary in place of main's `end_offset`, and landing points use main's `view_offset`/bag View so items meet the visible hand at any FOV; the vacuum travels into the tool socket with the nozzle as its end point rather than parenting to the nozzle marker, which carries the view-model scale; `try_place` now ends any pickup still flying for that prop.
- **Profile:** the 10-second vacuum profile is recorded with J06, which adds the vacuum motes.
- **Retained tuning:** none.
- **Open issues:** none.

## J05 — Placement

- **Build:** J04 commit + J05 working tree.
- **Scene / seed:** `tests/scenes/placement_lab.tscn` for the ghost sweep; `scenes/main.tscn`, `feedback-sequence`, for placements.
- **Setup:**
  - Lab: the P10 fixture with two buckets, one held; the player stands at (−4.25, 0, 1.6) while the aim sweeps from x = −2.3 to −6.3 across shelf A (slots at −2.8 and −3.6), the gap and shelf B (−4.9 and −5.7), then turns to the sky.
  - Main: each prop is taken off the sand with `try_hold`, with dirt cleared for staging. The player is moved in front of the first free slot of its kind and aims at it, and clicks through the real `request_primary` route. The ball is thrown with `PlayerCarry._on_throw_requested` from 1.3 m at an empty arrival shelf slot; the removal uses `try_remove`.
  - Traces and clips run at `--fixed-fps 60`, so tween timing is exact. The main probe suppresses autosave; see Open issues.
- **Observed:** [ghost sheet](images/J-feel/j05-ghost-glide.png), [ghost clip](images/J-feel/j05-ghost-glide.mp4), [placement sheet](images/J-feel/j05-placement.png) and [placement clip](images/J-feel/j05-placement.mp4) (Godot movie maker, scaled to 1280×720):
  - Ghost: a mint hologram of the actual prop, with a bright rim and slow rising scan lines. It materializes over 0.1 s (appear 0 → 1 in six frames, scale 0.92 → 1). It glides to the adjacent slot in 0.08 s (x −2.80 → −3.20 → −3.44 → −3.56 → −3.60), fades in 0.06 s when the aim crosses the gap (appear 1 → 0.72 → 0.44 → 0.17 → freed) and materializes again on shelf B. The shelf behind it stays visible. A soft contact shadow sits under it on shelves and on sand.
  - Placement: the prop leaves the hand at its in-hand scale (0.35, or 0.4 for the chair) and reaches 1.0 on the way. Travel took 0.267 s for the chair, 0.25 s for each bucket and 0.283 s for the surfboard (0.2 s + 0.04 s per metre, capped at 0.3 s). Paths rise 0.10–0.12 m above the straight line, then drop straight onto the slot. On landing the prop squashes to 0.92 height, rebounds to 1.057 and rests at exactly `ONE`, with one ring, 6 sparkles and 5 dust quads.
  - Neighbours: the second bucket, landing 0.8 m away, rocked the first by 0.67° (2° × (1 − 0.8/1.2)). Taking a bucket off rocked its neighbour by 0.40° (strength 0.6). Both returned to rotation 0.
  - Capture: the thrown ball entered the slot 0.05 s after release and travelled in for 0.167 s along a half-height arc (0.18 s tuned). It landed with 12 sparkles and the wider, shine-coloured ring.
  - Cleanup: counting nodes under the service and every `GhostRoot` gave 2 before and 3 after in both scenes. The extra node is the hidden blob, which is reused.
- **Reduced motion:** the ghost appears at rest with no breath and still scan lines. It snaps between slots (4 new ghosts, 0 glides) and clears without a fade. Travel keeps its duration and still grows to full size, but goes straight (0.000 m above the line). Landing has no squash, ring, dust or wobble, and 3 sparkles (half).
- **Checks run:** `validate_placement.gd` exit 0; `validate_placement.gd -- --capture` exit 0 (its generated captures were deleted); `validate_completion.gd` exit 0; `validate_full_run.gd` exit 0 (47.3 s). The 35-frame scale contract holds: travel ≤ 0.3 s + landing 0.22 s.
- **Departures from the packet:**
  - The landing ring starts at 0.6 × and grows to the prop's footprint half-diagonal + 0.3 m (+ 0.45 m for a capture) whenever that is larger than the packet's 0.15 → 0.55 m (0.8 m) ring. Otherwise a chair or cooler hides its own ring. Small props keep the packet's sizes.
  - The blob, ring, dust and sparkles sit on the ground found by a short ray at the slot, because sand rises above some slot origins and buried them. Shelf slots keep their authored top, since shelf modules have no collision.
  - The blob gradient keeps a broad core (0.7 alpha at half radius). A plain linear falloff at `ghost_blob_alpha` 0.28 was invisible on bright sand. The blob is skipped on moorings, where it would sit on water. It stays on upright racks, where its footprint is the board's edge.
  - Aiming at the same slot with a different held prop selected now rebuilds the ghost. The old early return kept showing the previous prop.
  - Ghost meshes do not cast shadows, and landing dust is skipped on moorings.
- **Retained tuning:** none.
- **Open issues:** two pre-existing costs, not changed here and flagged as separate tasks:
  - A group-completion reward triggers an autosave through `wallet_changed`. One `save_slot` on the full beach (5,740 items) took 2.4–6.5 s on the main thread. Any placement travel in flight then finishes in a single step after the stall.
  - Aiming at an empty, unclaimed shared shelf costs about 30 ms per physics frame, because `_shared_claim_is_safe` scans every item record on each preview. The frame rate drops while lining up such a shelf. Godot's catch-up delta (at most 0.133 s per frame) then shortens the visible travel: real-time traces of the first shelf placement and the capture finished in 30–60 ms. The fixed-FPS traces above show the intended timing.

## J06 — Tools

- **Build:** J05 commit + J06 working tree.
- **Scene / seed:** `scenes/main.tscn`, `first-shore`.
- **Setup:** ownership is staged by the probe: the tool is added to `owned_tools`, put in slot 1 with the stick in slot 2, the tool visual is refreshed and the change is published like `try_equip`. The scanner is learned through the real booklet purchase after collecting a plastic bottle. Actions use the real entry points: `request_primary` for the cloth and stick, and `try_click` for the knife, detector and sand cleaner (the routes `player.gd` uses). The vacuum trigger is held with `Input.action_press`. The bag is filled with `try_collect` for the full-bag cases. Traces and clips run at `--fixed-fps 60`; the vacuum profile runs in real time. The probe suppresses autosave (see J05).
- **Observed:** [tools sheet](images/J-feel/j06-tools.png) and [tools clip](images/J-feel/j06-tools.mp4) (1080p, recorded with short holds before each action). Sections: cloth 0:00, knife 0:05, detector 0:12, sand cleaner 0:24, vacuum 0:28, scanner 0:37, stick 0:40. For the clip only, the vacuum bag is staged ten items short of capacity so the hold ends in the choke.
  - Stick: at rest the spike tip sits at the same screen point (59 %, 89 %) at FOV 70 and 110, because main's per-socket View correction holds the tool in screen space, so no retune was needed. It stabs and collects at both FOVs and crouched from knee height. Clicking empty air sends `whiff` (a 60 % poke, with no reticle pop). With a full bag, clicking a can sends `rejected` ("Bag full"): the reject clip plays and the bag wobbles.
  - Cloth: on a two-stain lounger, each stain smears sideways to 1.35 × 0.60 while fading out over 0.22 s, with 2 glints. The cues are `clean`, then `clean_done` on the last stain; J07 adds the gleam.
  - Knife: shallows turtle `rescue:11`, at the water line. The first cut, with bag room, flies the cut litter into the bag (caught 0.31 s later) with 6 white snip glints. With the bag full, the second cut drops the litter: the attached model pops away and a puff marks the drop point. The turtle is freed: "FREED" pops 0.4 → 1.25 → 1.0, the turtle breathes out bubbles and a reef-coloured ring spreads 0.3 → 1.4 m. The label holds for 1.6 s, then fades and hides while the turtle sets off. Cutting at the submerged reef site `rescue:08` adds 6 bubbles.
  - Detector: approaching the most isolated find (5.4 m from its neighbour) from 4 m to 0.5 m, strength rose 0.22 → 0.83 and the ping interval shrank from 0.76 s to 0.65, 0.54, 0.45 and 0.38 s. Each ping spreads a yellow ring from the signal, flashes the coil and brightens the meter; the surface marker no longer throbs. On reveal: 14 sand quads, 6 glints and a collapsing ring. The find rises from −0.25 m to 0.06 m in 0.22 s and bounces to rest by 0.38 s. The valuable (lost keys) also spins one full turn, ends at exactly 0 and shows gold glints.
  - Sand cleaner: the preview is a rotating 24-dash ring. It shows intensity 0.55 over empty sand and 1.0 over litter (a presentation hint counted every 0.1 s). On a sift it collected 6 items (the cap) with a 16-quad sand puff. The ring contracted 1.0 → 0.2 while fading over 0.3 s, then came back. The items streamed into the bag 35 ms apart (six catches between 0.30 and 0.50 s).
  - Vacuum: held for 5 s in the densest pile, it collected 13 items at the unchanged 0.125 s interval before the pile ran out. Motes flowed into the nozzle, peaking at 13 live (cap 48), with a recoil per item and the hum jitter. Moving on to more litter filled the bag to 20/20: `vacuum_full` fired, the choke clip played and suction stopped until release.
  - Scanner: with the plastic filter (871 matches), the pulse's sonar ring spreads from the player to 30 m over 0.9 s. The visible marker pops 0.6 → 1.12 → 1.0.
- **Reduced motion:** stains fade only (scale stays 1, one glint). FREED shows without the pop; the ring and bubbles stay. Detector pings keep their rings but lose the tool flash, and the reveal keeps its burst at half count (7 quads, 3 glints) with no pop or spin. The sand ring keeps still dashes and does not contract, and the sift puff is 8 quads. Vacuum motes run at half rate (peak 7). Scanner markers appear without the pop. Clips play at 50 % and the tool jitter, sweep and rock are off (J03).
- **Checks run:** `validate_tool_filters.gd`, `validate_buried.gd`, `validate_rescue.gd`, `validate_dirt.gd`, `validate_scanner.gd` and `validate_purchases.gd`, all exit 0.
- **Profile:** vacuum held in the densest pile (real time, two runs), each compared with 300 idle frames at the same spot after the views finished streaming. Idle: median 7.46 / 7.52 ms, p95 8.30 / 8.43 ms. Held: median 7.83 / 7.85 ms, p95 8.91 / 8.89 ms. Draws rose from 5,092 to 5,161 (motes, flights and bag catches). The node count went from 10,439 before to 10,348 while held (collected views freed); motes add no nodes. The J00 baseline is the dense physics lab (p95 18.4 ms), so the same-spot comparison is the one that counts.
- **Departures from the packet:**
  - The reveal pop runs on the visual root's hover channel and holds hover lifts for 0.4 s (`WorldItem.hold_hover`). Otherwise the hover that starts on the freshly revealed item, in the same frame, would cut the pop short.
  - FREED eases up with QUAD to peak at exactly 1.25; `TRANS_BACK` overshot to 1.33.
  - Scanner markers pop on the pulse's first refresh: `_pop_markers` is set before `_refresh(result)`, where the packet set it after `pulse_succeeded`.
  - The sand cleaner's other failure branches (not aimed at sand, bag full) also send the reject cue and tint the ring amber. The detector's "no signal" click also sends the reject cue.
  - Cloth glints halve under reduced motion, like every other sparkle.
- **Retained tuning:** none.
- **Open issues:** none.

## J07 — Completion shine

- **Build:** J06 commit + J07 working tree.
- **Scene / seed:** `tests/scenes/placement_lab.tscn` (P10 fixture: red and blue buckets, and a beach ball as the unrelated neighbour); `scenes/main.tscn`, `feedback-sequence`, for a chair row; `scenes/main.tscn`, `first-shore`, for a two-stain lounger.
- **Setup:**
  - Lab: the ball goes on shelf B. The red bucket goes on shelf A and the blue one completes the set; then red is taken off and put back for the replay.
  - Main, chair row: the `arrival:dunes/beach_chair` group has one chair committed to `row:arrival:chairs:04` directly (staging). The last chair is held and placed through `try_place`, seen from the front; it is then removed and placed again, seen from the side.
  - Main, lounger: the cloth is staged as in J06 and both stains are wiped through `request_primary`.
  - All runs at `--fixed-fps 60`.
- **Observed:** [shine sheet](images/J-feel/j07-shine.png) and [shine clip](images/J-feel/j07-shine.mp4) (lab 0:00, chair row 0:04, lounger 0:09):
  - Set, first completion: "+$15" rises from the set in the money colour and the reward is paid once (money 15 → 30). The warm-white band with its turquoise fringe crosses the set left to right on screen: the left bucket lights at 0.18 s and the right one at 0.55 s. Sparkles pop above each prop as the band reaches it. The overlay lasts 48 frames (0.8 s) and clears.
  - Replay: "Tidy!" in warm white, with no payment (30 → 30) and the same band.
  - The unrelated ball on the next shelf never carried the band in either sweep, since the overlay goes only on the set's own meshes.
  - Chair row: from the front, "+$15" and the band run from the left chair to the right one. From the side, the replay's band still reads left to right across the visible chair, because the direction is camera-relative (screen right tilted 20° up), and the notice reads "restored again".
  - Clean gleam: wiping the lounger's last stain gives "Clean!", eight extra glints (10 in all with the wipe's two) and a 0.6 s band (35 frames) across the lounger. The lounger stays `WORLD`, so completion is unaffected.
  - Readability: the band reads on bright sand and on the lab's pale floor. Its core crosses the environment's glow threshold (0.95, intensity 0.12) and picks up a slight bloom, with no halo on neighbours. No placement slot sits in hut shade in this build: the storage shelves are outdoors.
- **Reduced motion:** no band on sets or on the cleaned lounger, and no sparkle line. "+$15", "Tidy!" and "Clean!" appear in place and fade, and the gleam keeps half its sparkles.
- **Checks run:** `validate_placement.gd` (the band only on the completed group, the ball not sharing it, cleared within 0.9 s, none under reduced motion), `validate_completion.gd` and `validate_dirt.gd`, all exit 0.
- **Departures from the packet:** none in code. `P27-group-sweep.png` is not tracked on this branch, so the new look is recorded here rather than by replacing it. `shaders/group_sweep.gdshader` and its `.uid` are deleted; nothing references them.
- **Retained tuning:** none.
- **Open issues:** none.

## J08 — Sorting table

- **Build:** J07 commit + J08 working tree.
- **Scene / seed:** `scenes/main.tscn`, `first-shore`, station S1.
- **Setup:**
  - Twenty waste items (five per category) are collected with `try_collect`. One buried valuable is staged into the bag the way `validate_sorting.gd` does it.
  - Table actions go through the real view: `_unload`, mouse events into `_input` (hover and drags), focus actions, the bin list and Return, and the tray and Sell.
  - The probe zooms the table camera to 3.5 and pans to the first rows, so they sit clear of the guidance banner.
  - The manual seal and the 50th sort use the same station calls the table's buttons make (`try_seal`, `try_sort`), with the player on the floor facing the rack, because the overhead table camera shows the rack only as a board. The other 49 glass items are committed straight into the bin (staged).
  - The world throw uses `ItemViewManager.throw_item` from 0.65 m above the PMD opening, as `validate_sorting.gd` does.
  - The 200-item profile stages bag capacity 240. Traces run at `--fixed-fps 60` and the profile in real time.
- **Observed:** [table sheet](images/J-feel/j08-table.png) and [table clip](images/J-feel/j08-table.mp4):
  - Unload: the 20 proxies drop in 12 ms apart from 0.45 m, starting at 0.6 scale. All are visible by 0.27 s and settled with their squash by 0.57 s.
  - Hover: the item under the pointer lifts 0.031 m and grows to 1.12; the one it left returns to 0 and 1.0.
  - Focus: the bracket cursor closes on the next cell over 20 → 12.1 → 7.4 → 4.5 → 2.7 → 1.6 px in successive frames, breathes ±1.5 px and pinches on select.
  - Drag: the proxy lifts 0.12 m, follows the pointer and tilts with its motion (−3.9°, −10.2° mid-drag). The bin under the pointer swells toward 1.06; it was at 1.03 at release, still rising.
  - Sort: on release the proxy arcs into the bin while shrinking to 0.4. The Synty bin bumps and returns to its authored (1.5, 0.74, 1.0) scale, six glints puff from the opening and the 3D fill and button bar rise. A check stamps on the correct bin (`FeelIcon.CHECK`) and a question mark on the wrong one, then fades after 0.8 s; the hint text still says it in words.
  - Return: the new table proxy arcs from the bin back to its cell, growing from 0.4, and settles with a squash.
  - Seal: the bin's fill drops, the sealed bag drops 0.5 m onto its rack shelf and bounces, and the rack label bumps. At the staged 50th glass item the fill emptied and a second bag landed.
  - Sell: eight gold glints and "+$10" rise from the tray.
  - World throw: a can dropped through the PMD opening was sorted, with a ring at the opening, the bin bump and glints.
  - At 1280×720 and 150 % UI scale, the stamps sit inside their buttons' top-right corners and the cursor stays on the table.
  - J01 follow-up: a sealed bag on the rack takes the hover outline and the "GLASS disposal bag · 1 sealed items · 1 hand" label ([still](images/J-feel/j08-rack-hover.png)).
- **Reduced motion:** unload proxies appear at once (all settled on the first frame), hover only scales, the cursor snaps and drag keeps its lift but has no tilt. The swell is instant; fills, bars and stamps update without motion; there is no bin bump or rack bounce, and glints are halved. The world-throw ring stays.
- **Checks run:** `validate_sorting.gd`, `validate_sealing.gd`, `validate_payment.gd` and `validate_ui.gd`, all exit 0. Their state assertions are unchanged.
- **Profile:** 200-item unload in real time, two runs. The cascade settled at 0.90 s both times. Frames during it: median 6.0 ms, p95 6.1 ms, max 15.0 / 15.1 ms. The unload call itself took about 535 ms both times, and 539 ms with reduced motion (no cascade), so that cost is the existing proxy build (200 scene instantiations), not this packet.
- **Departures from the packet:**
  - The cascade step is `min(unload_stagger, (unload_cascade_max − fall − squash) / count)`, so the last proxy also finishes by 0.9 s. With the packet's formula the starts spread over 0.9 s and a 200-item unload settles at about 1.2 s.
  - The view also calls `drag_to` from `_process` while dragging, so the lifted proxy keeps easing to the pointer and its tilt settles between mouse events.
  - Hover skips a proxy that is still falling in the cascade; `begin_drag` and a sort end any cascade or hover tween on that proxy.
  - Fills shrink with QUAD rather than BACK, which would overshoot below zero height.
  - The rack drop moves the bag's `SyntyBag`, `BagMesh` and `BagLabel` together from their authored heights.
  - The bag rigid body and record are untouched.
- **Retained tuning:** none.
- **Open issues:**
  - Pre-existing: at 1280×720 and 150 % UI scale, the HUD progress panel overlaps the left bin buttons at the table (noted for J09).
  - Pausing mid-drag uses `_cancel_drag`, which now returns the proxy home with a pause-safe tween. Resume behaviour was not replayed in this entry; J14 covers pause and save flows.

## J09 — HUD

- **Build:** J08 commit + J09 working tree.
- **Scene / seed:** `scenes/main.tscn`, `restoration-fixture`, at 1920×1080 and at 1280×720 with 150 % UI scale.
- **Setup:**
  - Five real pickups (`try_collect`), then the bag filled to 20, and one more collect through the real click (`request_primary`).
  - The starter section is restored as `validate_completion.gd` does it: props committed straight to slots, so their sets complete on publish; 80 waste items sorted and sealed through S1; bags deposited; then the truck collects for real.
  - A save and reload of the same run.
  - Traces and clip run at `--fixed-fps 60`, with autosave suppressed.
- **Observed:** [HUD sheet](images/J-feel/j09-hud.png) and [HUD clip](images/J-feel/j09-hud.mp4):
  - Bag: the bar fills mint and bumps on each pickup (scale 1.07 mid-bump), turns amber at 16/20 and red at 20/20. A "Bag full" click shakes the bag panel (x 64 → 68 → 61 → 65 → 64) and flashes the bar.
  - Sets: two sets completing show the check glyph notice "2 prop sets complete · +$30". The money line (coin glyph, gold) rolls from $0, reaching $24 by 0.12 s, bumps, and "+$30" floats up clear of the final value. The completion bar fills and shines.
  - Collection: the truck pays $120. Money rolls $30 → 48 → 86 → 111 → 126 → … → 149 → $150 (expo ease, 0.7 s). The restoration notice "Arrival · Start restored" gets the star glyph, a gold border, a bump and a shine. It shares the screen with the collection receipt without overlapping.
  - Notices slide down 10 px and fade in; the last one fades out before hiding. Tips carry the info glyph.
  - Reload: the progress text and money label match the pre-save values on the first frame, with no roll from 0.
- **Reduced motion:** bars and numbers take their values at once, with no bumps, shakes, slides, shines or floaters. The bag panel stays at x 64 on a full-bag click. The money line flashes once on gain. The colour states and glyphs remain.
- **Checks run:** `validate_ui.gd` (exact label prefixes), `validate_completion.gd` (the 720p lane checks: notice clear of the receipt and progress panel), `validate_payment.gd`, `validate_scanner.gd`, `validate_c01_input.gd` and `validate_sorting.gd`, all exit 0.
- **Fixes found while validating:** the autowrapped `GuidanceLabel` inside its new icon row measured its minimum size at a sliver of width, so the notice panel grew to 550 × 294. That hid the scanner's only marker, and `validate_scanner` reported `markers=0` where it had 1. A 480 px minimum width puts the panel back at 550 × 74, and the check reports `markers=1` again.
- **Departures from the packet:**
  - The "+$N" floater starts past the width the money text will have once the roll ends, not at the current right edge, because the growing number ran into it.
  - Notices use the panel's theme style for tiers 0–1 and a duplicated style with a 2 px gold border for tier 2.
- **Retained tuning:** none.
- **Open issues:** both pre-existing; the packet keeps these panels' anchors and offsets unchanged, so they go to the J14 display audit:
  - At 1280×720 with 150 % UI scale, the notice panel (y 268–379 px) reaches the screen centre and covers the reticle and target label.
  - At plain 1280×720, its right edge (x 915) overlaps the scanner summary (x 870–1262) by 45 px while both are up.

## J10 — Collection and money

- **Build:** J09 commit + J10 working tree.
- **Scene / seed:** `scenes/main.tscn`, `first-shore`, station S1, at 1280×720 and at 1280×720 with 150 % UI scale.
- **Setup:**
  - Ten waste items (five PMD, five glass) are collected with `try_collect`, then unloaded, sorted and sealed through S1's station calls. Both bags are held and deposited with `try_deposit_bag`, one per container.
  - The call goes through the hotline's interact handler, as a click does, and is then repeated with nothing left to collect.
  - First-time set: the three props of `sports:snack_edge/surfboard` are committed straight to slots (staged, as `validate_completion.gd` does), then published with `finalize_action`.
  - Pause and quit mid-flight (staged): $40 is added to the wallet and carried by four coins, the way a receipt's total is. Then the game pauses for 1 s, or quits to the menu and starts a new run.
  - A layout probe shows a toast with a rejection in the same frame, a notice and a display-only receipt at 100 %, 150 % and back to 100 % UI scale in one run.
  - Traces and clip run at `--fixed-fps 60`, with autosave suppressed.
- **Observed:** [collection sheet](images/J-feel/j10-collection.png) and [collection clip](images/J-feel/j10-collection.mp4):
  - Deposit: the fill springs 0.029 → 0.085 → 0.107 → 0.109 toward its 0.1 height (the BACK ease overshoots) while the container rocks (1.2°, 0.5°, −1.2°, 0.6° in 3-frame samples) and dust puffs from the opening.
  - Call: the phone rocks (−2.0° and −2.7° in the 0.1 s trace, still by 0.3 s) and a gold ring spreads at its base. Both fills dip and sink (0.11 → 0.10 → 0.06 → 0 by 0.42 s) with glints and dust; the containers shake and their labels pop.
  - Receipt: it slides in from the right as the title stamps. The details type out (visible ratio 0.18 → 0.44 → 0.66 → 0.84 → 1.0 by 0.7 s) while the gold total waits at +$0. The total then counts +$6 → +$16 → +$19 → +$20 by 1.0 s and pops.
  - Coins: three coins leave the total at 1.3 s and arc to the money line. The line held at $0 steps to $7 as the first lands and reaches $20 by 2.02 s, bumping on each arrival, and "+$20" floats. State money was $20 from the commit; `details_label.text` was final at once.
  - Empty call: the "Nothing to collect" toast, one short phone shake at half angle, no ring.
  - First-time set: three coins fly from the "Surfboard set complete · +$15" notice. The money line holds at $20, then steps to $30 and $35 by 0.8 s.
  - Pause mid-flight: the coins keep flying under the pause menu; at the end of the 1 s pause the line reads $75, the wallet.
  - Quit mid-flight: 0 coins after quitting and 0 in the next run, which opens at $0.
  - Screen checks: coin paths stay on screen (bounding box x 90–1032, y 80–227 of 1280×720; at 150 %, x 68–627, y 68–215 of 853×480). The receipt never overlapped the notice lane in any frame of the call or the set.
  - Feedback toast: a 440 × 48 strip centred above the bag panel (y 532–580 of 720; at 150 %, y 292–340 of 480), clear of the bag panel at both scales. See the first fix below.
- **Reduced motion:** the receipt appears in place with the full text and final total, and the money line shows $20 on the first sample and flashes once. No coins fly. A deposit sets the fill (0.100) with no wobble, the call empties the fills at once, and the phone does not move; only its label pops. Particle counts halve.
- **Checks run:** `validate_payment.gd`, `validate_sealing.gd`, `validate_completion.gd` (the 720p lanes with the taller receipt), `validate_ui.gd`, `validate_scanner.gd` and `validate_save_physics.gd` (the error panel on a failed load), all exit 0. The only error lines are the two exit-time GL texture-leak messages that the J06–J09 runs of the same checks also print.
- **Fixes found while validating:**
  - Pre-existing: the feedback toast (`ErrorPanel`, which gameplay feedback reuses) named the bottom-wide preset but left `anchor_top` at 0. It ran from 120 px above the top of the screen to 32 px above the bottom: a dark sheet over most of the view with the message in the middle. It is now bottom-centred and 440 px wide, with its bottom edge 140 px above the screen bottom. That clears the bag panel, the detector meter and the oxygen meter at 100 % and 150 %. The literal intent, a strip 240 px in from each side at the bottom, would have covered the right end of the bag panel.
  - J09 follow-up: the notice and toast slides, and the new receipt slide, stored an absolute position the first time they ran and returned to it. After a mid-run UI-scale change, the receipt would have slid back to x 830 on a screen 853 px wide. Slides and shakes now move the control's offsets relative to its scene layout (`FeelMotion.nudge_x` and `nudge_y`), so they follow resizes. The layout probe finds the toast, notice and receipt inside the screen at 100 % → 150 % → 100 %.
  - J09 follow-up: a rejection's shake that starts in the same frame as the toast's 6 px rise captured the risen position and restored it, leaving the toast 6 px low. The shake now moves only the horizontal offsets. After a toast plus rejection, the probe reads the toast's offsets back equal to its layout.
  - J09 follow-up: pruning expired "+$N" floaters erased freed labels from a typed array, which is an engine error each time. It was in the J09 probe logs too. They are now pruned by index, and the J10 runs log no errors.
- **Departures from the packet:**
  - `CoinFlyer.fly` does not clear earlier flights, so a receipt's coins and a set's coins may overlap. `clear()` cancels every flight through an epoch counter, without running their callbacks.
  - Held money stacks. `_hold_money(amount)` adds to `_money_pending`, and each landing releases only its own amount (`_shown.money = wallet − pending`), so a set reward during a receipt's flight does not release the receipt's hold early. A 5.2 s timer that also runs while paused releases whatever is still held.
  - Each coin adds `amount / n` to the displayed money rather than setting `base + amount × (i + 1) / n`, so it composes with the stacked holds.
  - The plain money reaction (roll, bump, floater) waits until the end of the frame. A receipt or set reward committed in the same `finalize_action` then holds the money first, and the coins carry the gain.
  - Slides use layout offsets instead of the J09 base-position meta pattern (see the fixes).
  - The hotline's ring is money gold; the packet leaves its colour open.
- **Retained tuning:** none.
- **Open issues:**
  - The results-screen safety (`coin_flyer.clear()` and a release when results open) lands with J12, as the packet says.
  - At 150 % UI scale, the toast's right end (x 646 of 853) passes under the sorting table's side panel (from x 563). Short messages stay clear; a long one would be partly hidden. This goes to the J14 display audit.

## J11 — Restoration

- **Build:** J10 commit + J11 working tree.
- **Scene / seed:** `scenes/main.tscn`: `restoration-fixture` (arrival) and `wildlife-fixture` (reef, shallows, batch). Also 1280×720 with 150 % UI scale.
- **Setup:**
  - Arrival: `arrival:start` is staged the way `validate_completion.gd` stages it. Its ten props are committed to slots, and its 80 waste items are sorted and sealed through S1 and deposited. The truck is then called through the hotline's interact handler. The staging's own set notices are cleared before the call, so the banner is not queued behind them.
  - Near: the player stands 7.8 m from the section centre, facing it.
  - Far: the player stands 40 m out on the line through the S1 hotline, facing the section and then turning away. The hotline itself is only 14 m from the section.
  - Reef, shallows and batch (staged): each section's props are committed to slots and its other required items collected in one commit, as `validate_wildlife.gd` does. The player is held still underwater for the reef views.
  - Save: the arrival restore, saved 0.3 s after the call and reloaded.
  - Traces and clip run at `--fixed-fps 60`; the profile runs in real time. Autosave is suppressed.
- **Observed:** [restoration sheet](images/J-feel/j11-restoration.png) and [restoration clip](images/J-feel/j11-restoration.mp4):
  - Near: a cream wall rises at the section centre and sweeps outward for 1.8 s, a bright line where it cuts the sand, with glints along its front (up to 57). It passes the player at about 0.7 s. The palm, 5.2 m out, pops from 0.01 at 0.6 s (0.51 → 0.82 → 0.88 overshoot) and settles at its authored 0.8. The banner reads "Arrival · Start restored"; there is no pointer or beacon.
  - Far: the wall and a beacon column rise; the column reads above the rooftops. The pointer's arrow hangs over the spot, pointing down, with "40 m", and pulses between 1.0 and 1.15. Turned away, the arrow moves to the left edge (80, 367) pointing left. It hides 4 s after the restore. The banner reads "Arrival · Start restored · 40 m ahead".
  - Reef, from underwater: a turquoise wall spreads over the seabed. The coral garden warms piece by piece as its front passes (0.8 m at 0.1 s, 12.5 m at 1.5 s, 26.7 m at 3.2 s); nearby coral is coloured while the far coral is still grey. The front clears at 4.1 s, once it has passed the garden's farthest piece.
  - Zone: `reef_west:coral` completes the zone. The section wall and the 22 m zone wall run together (two waves, up to 117 glints), the zone fish start as before, and "Reef West nature returns" follows the section banner. Seen from the surface, the submerged walls are dimmed (see the departures).
  - Shallows, from the shore: the wall crosses the water surface as a pale ring, and the coral pops in behind it.
  - Batch: four shore sections complete in one commit. One "4 areas restored" banner shows; the Sports zone banner follows with "29 m ahead". Waves peak at 4 and glints at 192, the two caps.
  - Save and reload: the restored dressing is visible at its authored scale. There are no waves, glints, bloom tweens, banner or pointer.
  - Existing checks: the first child of the restored root is still `FoliagePalm`. A replayed restoration signal adds no nodes, and the zone keeps three children.
- **Reduced motion:** no wall, glints, pop-in or beacon. The dressing and colours appear at once (the palm reads 0.80 on the first sample). The banner keeps its distance and direction, and the pointer still shows, at scale 1.00 with no pulse.
- **Checks run:** `validate_completion.gd`, `validate_wildlife.gd`, `validate_save.gd`, `validate_scanner.gd` and `validate_ui.gd`, all exit 0. The error lines are the two exit-time texture-leak messages seen in earlier runs and the save check's intended write failure to a blocked directory.
- **Profile:** the arrival restore by a real truck call, standing in the section and looking east along the crowded beach, 1280×720, real time, three runs.

  | Window | Median | p95 | Max | Max draws | Nodes |
  |---|---|---|---|---|---|
  | 2 s before the call | 7.69–7.78 ms | 8.32–8.44 ms | 18.0–18.5 ms | 4,959 | 8,539 |
  | 2 s after (wave, receipt, coins) | 8.26–8.29 ms | 9.04–9.22 ms | 20.2–20.8 ms | 5,329 | 8,541–8,546 |
  | the next 3 s | 7.81–7.85 ms | 8.65–8.74 ms | 18.1–19.3 ms | 5,030 | back to 8,539 |

  The burst adds 0.6–0.9 ms to p95 (budget 1.5 ms), and it includes J10's collection effects. The lasting 71 extra draws are the restored dressing itself. The wave's own node frees at 1.9 s. The node count is back to baseline 3.2 s after the call; the last node to go is J10's "+$120" floater, which rises for 0.9 s after the tenth coin lands. For reference, the J00 dense-view baseline is p95 18.4 ms.
- **Departures from the packet:**
  - Reef coral gardens were added on `main` after the plan was written. They are MultiMesh batches, so a per-child delay would warm a whole garden at once. `reef_garden.gdshader` gains a wave front (`wave_origin`, `wave_front`, `wave_feather` 4 m, `grow_with_wave`): each coral piece warms, and each regrowth piece grows, as the front passes it at the pop-in pace. The default front reaches everything, so the garden looks as before whenever no wave is running.
  - Recolour delays follow the front past the 12 m wall. Reef sections have coral and seagrass up to 35 m from their centre, which finish warming about 5 s after the restore.
  - `validate_wildlife.gd` now waits 3.0 s, not 1.3 s, before sampling the restored reef colours. The check is not in the plan's §11.2 list, and this packet's own delay step puts its seagrass bed, 11 m from the centre, at about 2.5 s. The assertions are unchanged.
  - Wave-light tweaks:
    - A fully submerged wall is dimmed to half while the camera is above the water, blended over ±0.1 m at the surface. This is the packet's conditional step; from the surface the reef rings had glowed as if they floated on the water.
    - The beacon uses a gentler height fade (`fade_power` 0.7 instead of the wall's 2.2). With the wall's fade, the part of the column visible above rooftops from 40 m was barely visible.
  - Scheduling:
    - Beacons are spawned at the end of the frame, so in a batch the walls take the shared four slots before any beacon does.
    - The zone handler skips its effects when the zone root was already visible, as the section handler does; the zone populations still start as before.
    - The glints along the front ride a tween bound to the particle pool, not scene timers, so quitting mid-wave leaves nothing scheduled.
  - Placement:
    - Reef glints sit at `Coastline.surface_y + 0.2`, as shore glints do. The seabed uses the same height function, and a sloped seabed puts the anchors' mean height above or below it.
  - Banners:
    - Section and zone banners flush together at the end of the frame, sections first, which keeps their old order.
- **Retained tuning:** none. New script constants: `RestorationWave.ABOVE_WATER_DIM` 0.5, `RestorationWave.BEACON_FADE_POWER` 0.7 and `RestorationSection.GARDEN_WAVE_FEATHER` 4.0.
- **Open issues:**
  - At 1280×720 with 150 % UI scale, the pointer's in-view arrow at the screen centre (427, 223) sits over the notice panel. This is the J09 notice-over-reticle overlap and goes to the J14 display audit. The edge arrow (80, 244) is clear.

## J12 — Finale

- **Build:** J11 commit + J12 working tree.
- **Scene / seed:** `scenes/main.tscn`, `full-run-integration`, at 1920×1080, then 1280×720 with 150 % UI scale.
- **Setup (accelerated):**
  - Staging:
    - 299 props are committed to free slots with their views, as `validate_full_run.gd` does.
    - All 5,400 required waste items are collected in one commit, as `validate_wildlife.gd` does.
    - The staging's own effects get 6 s to settle, then the notice lane is cleared.
  - Final actions (real):
    - Chair: the last `arrival:start` beach chair is held and placed with `try_place` from 1.8 m, as `validate_full_run.gd` does.
    - Truck: `arrival:start`'s 80 waste items are sorted and sealed through S1 and deposited, then the hotline is called.
  - Skip checks: a save made just before the final action is reloaded twice.
  - Traces and clip run at `--fixed-fps 60`.
- **Observed:** [finale sheet](images/J-feel/j12-finale.png) and [finale clip](images/J-feel/j12-finale.mp4):
  - Final chair: results, pause and `results_open` are set synchronously, as the checks require.
    - **The beat, 0–1.1 s:** the HUD tucks away. The chair's landing, the set shine and the arrival wave keep playing under the pause, while physics and wildlife stay frozen.
    - **1.1 s:** the frame is taken, with the hands hidden first. The flash rises to 0.54 and clears over 0.41 s while the shade fades in.
    - **The reveal:**
      - The panel scales 0.94 → 1.0, overshooting to 1.01, and is in by 1.5 s.
      - "COAST RESTORED" stamps from 1.6× and −5.7° down to 1.0 and level.
      - Confetti bursts at 1.67 s: 80 pieces in the four palette colours.
      - The postcard, showing the settled chairs and the wave front, settles from 0.8 at −4° to 1.0 at −2°, overshooting to 1.02 at −1.8°.
      - The stats count up: 1,671 → 4,434 → 5,305 → … → 5,700 by 2.5 s.
      - Continue fades in by 2.6 s. The intro ends at 2.7 s, and Continue pulses between 1.0 and 1.03 at 1 Hz.
  - Continue: the HUD's visibility (progress, context, error, pointer, scanner, detector, oxygen) matches its state before the finale, and the reticle and hands come back.
  - Save right after Continue, then reload: the results show at once, paused, with no intro (shade 0.88, panel 1.0). The receipt matches the pre-save receipt, compared as `validate_full_run.gd` compares it. There is no postcard, because it is not saved.
  - Skips, from reloads of the pre-final save:
    - A mouse click at 1.5 s, and the controller A button at 1.5 s, each jump straight to the final layout (final texts, panel 1.0) and keep the captured postcard.
    - A second click on Continue, or a second A press, continues.
  - Final truck call: the results open before the receipt would, so the receipt stays hidden, no coins fly and nothing is held back. The wallet reads the true $795 after Continue.
  - At 1280×720 with 150 % UI scale, the card shrinks to 171×96 so the panel fits on screen. The skips and the reload also work there.
- **Reduced motion:**
  - No flash (peak 0), confetti, stamp or pulse.
  - The panel and the card fade in, and the card rests at −2°.
  - The stats show their final numbers from the start, and the 1.1 s beat is kept.
- **Checks run:** all exit 0.
  - `validate_completion.gd`: its only error lines are the two exit-time texture-leak messages.
  - `validate_full_run.gd`: 43.5 s, with no error lines.
  - `validate_ui.gd` and `validate_payment.gd`.
- **Fixes found while validating:**
  - A final truck call publishes `run_completed` inside the commit, before the collection service emits `receipt_created`. The receipt and its $120 hold therefore arrived after the finale had cleared them, leaving the receipt visible under the results. The receipt now yields to the finale.
  - Godot containers reset their children's scale and rotation whenever they sort, so the count-up's text changes undid the stamp and the card's tilt. The title and the card now sit in plain holder controls, and the panel scales in through its `CenterContainer`.
  - Confetti still falling after Continue reappeared when a reload reopened the results at once. The confetti node now hides when the presentation ends.
- **Departures from the packet:**
  - Scene:
    - `Title` sits in `TitleHolder` and `Postcard` in `PostcardHolder` (the stack's first child), and `Center` carries the panel's scale-in. This works around the container resets described above.
    - The confetti's hard-stop colour ramp is built from `FEEL.confetti_colors` in `_ready`. Its position and emission width follow the view's size at each burst.
    - The panel's minimum size is unchanged; it grows with the card.
  - The card's image height fits the room the panel's other rows leave on screen, from 96 to 216 px. A fixed 384×216 card would push the panel off a 1280×720 screen at 150 %.
  - The capture happens first, and the reveal starts only after the image is taken, so the flash's first frame never lands in the postcard.
  - The first-person hands are hidden for the capture and stay hidden until Continue, so the card shows the beach rather than the arms.
  - The tucked-away HUD also includes the scanner overlay, detector meter and oxygen meter, which would otherwise appear in the card.
  - Money: `_settle_money()` clears coins and floaters, drops every hold and shows the true wallet at once. It is the stacked-hold equivalent of the packet's `_release_money(0)`.
  - While the results are up:
    - Notices, tips, set-reward coins, money floaters and the restoration pointer are suppressed. The same commit queues or defers them, so they would otherwise appear over the finale or in the card.
    - The notice panel is hidden along with its queue, so Continue does not bring back a stale banner.
  - A run reset from the results (quitting to the menu) drops the saved HUD states instead of restoring them.
  - Following the packet, `validate_completion.gd -- --capture` now waits 3.5 s before taking `P20-results.png`, so the still shows the final layout. P20 stills are generated, not tracked.
- **Retained tuning:** none.
- **Open issues:**
  - A reloaded finished run shows the HUD dimly under the shade, as before J12, because nothing tucks it away when there is no intro.
  - The accelerated staging collects waste directly, so these receipts read "Sorted correctly 0" (38 in the truck run).

## J13 — Rumble (optional)

- **Build:** J12 commit + J13 working tree.
- **Scene / seed:** `scenes/main.tscn`, `first-shore`.
- **Device:** no controller was connected during the session (`Input.get_connected_joypads()` was empty).
- **Setup:** a probe with injected input. It reads each request back from the engine's requested-vibration state (`Input.get_joy_vibration_strength` and `get_joy_vibration_duration`), which shows what was asked of the pad, not what a motor did.
- **Observed (logic):**
  - The setting defaults on.
  - With keyboard and mouse as the active input, a cue requests no vibration.
  - A pad press makes the controller the active input and pad 0 the target.
  - Patterns:
    - `place` requests weak 0.20, strong 0.12 for 0.08 s, from the J00 table.
    - A detector ping at strength 0.5 requests weak 0.10 for 0.03 s.
    - A cue with no pattern (`sort`) requests nothing.
  - The toggle turns it all off, and the setting survives a save and reload of the settings file.
  - Pausing stops a running pattern and blocks new ones. Only the finale's `run_complete` still plays (weak 0.30, strong 0.10).
  - Switching input off (the results and menus do this) stops a running pattern. So does a controller disconnect mid-pattern.
  - The settings menu shows "Controller vibration" right after "Reduced motion" in its focus chain.
- **Physical validation: blocked on hardware.** The packet's route (collect, full-bag reject, place, set complete, vacuum, detector approach, truck collection, section restore), the feel of each pattern, and motors actually stopping on pause, toggle and disconnect all need a physical pad, with its model recorded. As with FIN-04, injected input cannot verify vibration.
- **Reduced motion:** independent. Vibration follows its own toggle.
- **Checks run:** `validate_ui.gd`, `run_checks.gd` (settings round-trip; boot, asset closure, ownership, input bindings and manifest all PASS) and `validate_completion.gd`, all exit 0.
- **Departures from the packet:**
  - The finale's `run_complete` cue now plays just after the results open, not just before as J09 wired it. Opening the results switches input off, which stops vibration (step 5), so the finale's pattern would otherwise be cut off at once. `_rumble` allows that one cue under the pause, as the packet intends.
  - The controller-disconnect stop uses the player's existing connection to `controller_disconnected`.
- **Retained tuning:** none; the J00 rumble table is used as is.
- **Open issues:** physical-controller validation, as above.

## Retained tuning

Keep a running table: field, J00 default, retained value, reason.

| Field | J00 default | Retained | Reason |
|---|---|---|---|
| `tool_tips[&"stick"]` | (0, −0.32, −0.34) | (0.13, −0.61, −0.88) | Measured spike end of main's `tool_poking_stick.glb` in the tool View (J03) |
| `tool_tips[&"cloth"]` | (0, −0.02, −0.06) | (−0.10, 0.03, −0.05) | Leading edge of `tool_cloth.glb` |
| `tool_tips[&"knife"]` | (0, 0.02, −0.12) | (−0.05, 0.14, 0) | Blade tip of the rescue knife as held |
| `tool_tips[&"detector"]` | (0, −0.20, −0.62) | (0.09, −0.37, −0.82) | Coil of `tool_metal_detector.glb` |
| `tool_tips[&"sand_cleaner"]` | (0, −0.10, −0.20) | (−0.04, −0.54, −0.95) | Scoop of `tool_sand_cleaner.glb` |
| `tool_tips[&"vacuum"]` | (0, −0.02, −0.46) | (0.08, −0.26, −0.66) | Nozzle of `tool_vacuum.glb` |
