# J-feel handoff — hover, hands, placement, tools and completion

Evidence record for the [game-feel plan](../plan/12-game-feel.md), packets J00–J14. One section per packet, newest entries at the top of each section. Follow [AGENTS.md](../../AGENTS.md): record what was shown working in the real game or an existing lab. A tween existing in code is not evidence.

**Status: not started.** The plan was written 24 September 2026 on `claude/game-feel-juice-plan` from `main` at `b190cea`.

| Packet | Status | Evidence |
|---|---|---|
| J00 Foundations and baseline | Open | — |
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

## Baseline (J00)

Record the pre-change profile and stills here before any J change.

## Retained tuning

Keep a running table: field, J00 default, retained value, reason.
