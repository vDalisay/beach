# J14 — Feel acceptance, audits and art-swap re-tune

Dependencies: J00–J12 (J13 if implemented). Read first: [plan](../12-game-feel.md) §8, §9 and §11, [verification](../05-verification.md) "Manual gameplay and controller gate", and [FIN-08](../11-finishing-phase.md#fin-08--final-visual-and-interaction-acceptance).

**Outcome:** a single honest evidence set showing that the game-feel plan works in the real game on this build:

- one short silent recording of the full vocabulary
- audits for reduced motion, FOV and display, lighting conditions and devices
- a performance comparison against the J00 baseline
- the retained tuning values and a re-tune list for when final art arrives

This packet adds no features. Fix only what the audits expose, each in its owning packet's files.

**Own files:**

| File | Change |
|---|---|
| `tests/record_feedback.gd` | Update waits and camera beats only |
| `docs/handoffs/J-feel.md` | Final record |
| `data/feel/feel_tuning.tres` | Retained values |

## Steps

### 1. Feel recording

1. Update `tests/record_feedback.gd` so its existing staged sequence (seed `feedback-sequence`) shows the new vocabulary, in this order:
   - hover a can, then a blocked target
   - stick collect into the bag
   - hold and throw a chair (impact)
   - pick up and place a chair (ghost glide, arc and drop, settle)
   - set shine with `+$15`
   - clean a stain to `Clean!` (stage the cloth)
   - sort at S1 (cascade, arc into a bin, stamp, seal and rack drop)
   - deposit and collect (phone, lift-off, receipt, coins)
   - the section restoration wave
   - the finale (after accelerated completion, labelled as such)
2. Adjust only waits, aim poses and staging calls. Keep the script's `failures=0` ownership assertions.
3. Record with Godot Movie Maker at 1920×1080 and 30 fps to `docs/handoffs/images/J-feel.avi`. Take stills of each beat into `docs/handoffs/images/J-feel/`.
4. The J00 baseline stills are the "before" images. Put a before/after table in the handoff.

### 2. Reduced-motion audit

Walk every row of [plan §8](../12-game-feel.md#8-reduced-motion) with `reduced_motion` on, in the main scene. Mark each row pass or fail in a table in J-feel, and fix failures in their owning packet's files. Also confirm that no reduced-motion path changes gameplay timing or ownership: run `validate_placement.gd`, `validate_carry.gd` and `validate_completion.gd` with reduced motion set in their settings files, if they support it, or via a probe.

### 3. FOV, display and conditions audit

| Condition | Check |
|---|---|
| FOV 70 and 110 | Walk, sprint, crouch, swim; every clip; holding two props or one large prop. Nothing crosses the aim point; C08's fit still holds. |
| 1280×720, 1920×1080, 3840×2160 (offscreen via `tests/capture_4k_ui.gd`), wide window; UI scale 100% and 150% | Reticle, label, HUD bars, money, coins, notices, pointer, receipt and results fit, stay readable and never overlap the aim point or each other |
| Bright sand noon, hut shade, underwater, surface crossing | Hover styles (action, blocked, glass), ghost, sparkles and waves are readable and not washed out by glow or grade |
| Controller-only and mouse-only | Every cue fires once per action. There is no double pop from mixed input, and the vacuum spin reticle follows held input. |

### 4. Performance

1. Re-run the J00 profile (`validate_physics.gd -- --profile --c04-dense`) on the same machine and compare.
2. Run a burst sequence in a temporary probe (do not commit it) in the crowded arrival view:
   1. Hold the vacuum for 5 s.
   2. Complete a set (shine).
   3. Restore a section (wave).
   4. Collect with coins.
3. Record p95 and max draws during the burst, and the node count before, 3 s after and 10 s after.
4. Hold the budgets from [plan §9](../12-game-feel.md#9-performance-budget). If a budget fails, apply the listed reduction order and record the retained values.

Target-hardware certification remains FIN-10. This is development-GPU evidence only; state that plainly.

### 5. Art-swap re-tune list

List what must be re-tuned when FIN-05's supplied art arrives, so it is not forgotten:

| Asset role | What to re-tune |
|---|---|
| A06 stick | `FEEL.tool_tips[&"stick"]`, `stick_tip_fraction`, grip in `refresh_tool_visual`, outline on the new mesh |
| A07V vacuum, A07S sand cleaner | `tool_tips`, `vacuum_stretch`, jitter amplitude, `flash_tool` look |
| A08 detector | Tip, sweep degrees, coil flash |
| A10 cloth | Wipe clip amplitude |
| A17 hands | Arm pivots and clip amplitudes at FOV 70/110; optional finger curl if the rig has bones |
| A12–A16 litter and props | Outline continuity (welded normals), glass rim-only list, hover lift amounts, ghost look |
| A01–A04 wildlife and coral | Bloom exclusions for animal anchors, coral recolour schedule |

### 6. Handoff

Finish `docs/handoffs/J-feel.md`:

- build identity
- per-packet status (done, open or blocked)
- the retained `FeelTuning` diff from the J00 defaults, with the reason for each change
- the audits
- performance
- the recording and stills
- the re-tune list
- open issues

Do not mark FIN-08 closed. Add a one-line evidence link beside FIN-08 in `11-finishing-phase.md` pointing to the J-feel handoff. FIN-08's own "Done when" still governs.

## Done when

- The recording and every audit table exist with pass or fail marks and fixes.
- Performance is compared with the baseline within budget, or the recorded reductions are applied.
- Every existing check named in the J packets has been re-run on the final J build.
- The handoff is complete and honest about accelerated staging, development-GPU limits and missing hardware.
