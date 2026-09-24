# J-feel handoff — hover, hands, placement, tools and completion

Evidence record for the [game-feel plan](../plan/12-game-feel.md), packets J00–J14. One section per packet, newest entries at the top of each section. Follow [AGENTS.md](../../AGENTS.md): record what was shown working in the real game or an existing lab. A tween existing in code is not evidence.

**Status: in progress.** The plan was written 24 September 2026 on `claude/game-feel-juice-plan` from `main` at `b190cea`. On 25 September 2026 the branch was rebased onto `main` at `e3883f4` before implementation, because `main` had replaced the hand rig (per-socket FOV `View` nodes and IK-driven Synty arms), the tool scenes and `restoration_section.gd`. Packets that touch those files follow the plan's intent on the current code; each entry states where the code departs from a packet listing and why.

| Packet | Status | Evidence |
|---|---|---|
| J00 Foundations and baseline | Done | [J00](#j00--foundations-and-baseline) |
| J01 Hover | Open | — |
| J02 Reticle and label | Open | — |
| J03 Viewmodel | Open | — |
| J04 Pickup and throw | Open | — |
| J05 Placement | Open | — |
| J06 Tools | Open | — |
| J07 Completion shine | Open | — |
| J08 Sorting table | Open | — |
| J09 HUD | Open | — |
| J10 Collection and money | Open | — |
| J11 Restoration | Open | — |
| J12 Finale | Open | — |
| J13 Rumble (optional) | Open | — |
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

## Retained tuning

Keep a running table: field, J00 default, retained value, reason.

| Field | J00 default | Retained | Reason |
|---|---|---|---|
