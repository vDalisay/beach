# Implementation review at the C04 checkpoint — 23 September 2026

Historical checkpoint. F13–F15 have subsequent repair evidence; use the [24 September systems review](10-systems-review.md) and [updated completion plan](07-completion-plan.md) for current gaps, dependencies and the separate visual track.

## Outcome

Keep the existing implementation. C00 established the reproducible 4.6.1 baseline; C01's contextual pickup repairs and C03's mixed-bag order work in the checked flows. C02/C03 need a small follow-up for remapped table confirmation and the checkpoint selected after loading. C04 is still an implementation checkpoint, with a newly reproduced objective-access blocker as well as its recorded visual gaps. The game is not ready for release.

The [completion plan](07-completion-plan.md) now inserts **C03a**, then resumes **C04** with objective clearance as its first gate. C05–C09 retain their existing scope, with stronger geometry, input and release evidence requirements. No systems rewrite, new feature set or additional test framework is justified.

## Scope and baseline

- Reviewed checkout: `3c6b431`, following C01 `ef823e1`, C02 `3429a5e`, C03 `601cee3`. No tracked changes existed at review start; the pre-existing untracked historical images/video were preserved.
- Engine exercised: `4.6.1.stable.mono.official.14d19694e`; runtime uses GDScript and Compatibility. Content is **beach-content-6**, beach version **6**, generator **manifest-1**, save schema **1**.
- Content remains 34 definitions, 5,400 required waste + 300 required props + 40 optional valuables, eight zones and 18 sections. Assets remain 86 staged roles / 244 files and 27 registered open roles.
- Compared requirements, remaining packets, handoffs, changes since the reproducible baseline, input → transfer → sorting/payment → save/result paths, reef generation/collision, restoration wiring and the committed C04 captures against the three supplied references.
- This task changes the review, plan, status pointers and reproduction evidence. It does not apply gameplay fixes or produce another export. Earlier [F01–F12](06-implementation-review.md) findings are historical; the reconciliation below replaces their status, not their evidence.

## Findings

### F13 — P1: new reef colliders enclose required litter

**Owner: C04 clearance repair, retained by C05/C07.** [Reef structure construction](../../scripts/world/reef_dressing.gd), lines 45–64, creates 18 solid boxes independently of the [generator](../../scripts/world/manifest_generator.gd). The generator clears the dry walking route but has no reef-structure exclusion. This is a completion risk introduced by the C04 geometry, not merely unfinished habitat art.

In the actual main scene with seed `full-run-integration`, physics point queries found **23 WORLD item origins inside ReefRock colliders**. Example `item:reef_east:coral:00070`, an ordinary can at `(30.6, -2.8, 147.6)`, is inside `ReefRock16`. After creating its real streamed view and waiting 120 physics frames, it remained at that position with `freeze=true`; pickup-mask rays from above and four horizontal approaches all failed to reach its collider. The frozen item cannot rely on physics to push it clear. The 23 overlaps are origin intersections, not a claim that all 23 have individually received a full pickup audit.

The existing traversal still passes both swim channels. The accelerated full run also passes because setup transfers most litter by ID without pickup rays. Neither demonstrates access to litter inside rocks.

**Required adjustment:** resolve the overlap before accepting C04. Reuse conservative authored structural bounds in deterministic generation, or move the offending structure/anchors together; preserve all IDs/counts and apply the content-version/save policy if the manifest changes. Do not solve it by disabling occlusion, deleting objectives, auto-collecting them or letting tools work through terrain. Demonstrate normal collection of the previously trapped target and nearby large/attached targets, then retain the clearance check while C05 refits content and C07 dresses it.

### F14 — P2: a supported confirm remap still loses to table shortcuts

**Owner: new C03a; R29.** [SortingView input handling](../../scripts/ui/sorting_view.gd), lines 179–196, processes inspect/bin shortcuts before native Control activation without checking which control owns focus. [SettingsStore](../../scripts/ui/settings_store.gd) considers `ui_*` and `table_*` different conflict contexts, even though both can receive this event at the station.

Reproduced with real main-scene state: collect a can, enter S1, rebind `ui_accept` to controller **Y**, focus **Unload**, and inject Y through `Input.parse_input_event`. Rebinding reports no conflict; the can stays in the bag, inspection opens and focus moves to SortingOverlay. The existing X-remap check passes because it does not hit this shortcut. F02's default-A fix works, but remapped confirmation is not complete.

**Required adjustment:** let a focused native control own its confirm event before grid/global table shortcuts; reconcile overlapping active-context bindings where needed. Preserve the grid's own bindings and deliberate bin shortcuts. Use the same input route for Unload, Seal, Sell and Exit; include Y/inspect and a shoulder/bin conflict, plus return to the grid and pause/resume. Extend the existing sorting check with the failing case; do not add another controller harness.

### F15 — P2: loading Checkpoint 2 changes the next save destination to Checkpoint 1

**Owner: new C03a; R27.** [BeachMain](../../scripts/main.gd), lines 287–288 and 313–323, resets the native slot picker during run teardown, then never selects the manual slot being loaded. Both Save and Save and quit use that reset selection at lines 367–379.

Reproduced by writing Checkpoints 1 and 2, loading `manual_2`, opening pause and confirming Save through controller input. The picker selected `manual`; Checkpoint 1 advanced **sequence 1 → 2**, while Checkpoint 2 remained **sequence 1**. The player can manually change the picker, and A/B recovery still works, but the default Save after loading a checkpoint writes into a different checkpoint and can overwrite the state the player meant to retain.

**Required adjustment:** select the loaded manual checkpoint after opening the run, retain it across pause/settings, and use it for Save and Save and quit. Define the default for a new run/autosave load separately. Use the same Checkpoint 1–3 names, timestamp and progress in Load and pause so the destination is recognizable. Validate that saving loaded Checkpoint 2 changes only that slot; keep other-run isolation and failed-write retention.

## Current reconciliation

| Area | Current status and remaining owner |
|---|---|
| C00 / F11 baseline | Reproducible baseline accepted. The active C04 content is now version 6. Keep `601cee3` for C03-era content-5 saves and `3c6b431` for this checkpoint's content-6 saves. No new 4.6.1 export is certified. |
| C01 / F01, F03 | Checked routes repaired. Six-tool contextual pickup and the final revealed-item normal-input route pass again. Physical controller/human completion remains C09. |
| C02 / F02, F04 | Default focus, table pause, loaded sorting and tray sale pass again. F14 reopens remapped confirmation under C03a. |
| C03 / F05, F12 | Mixed inventory ordering, additive receipt fields and three isolated checkpoint slots are implemented. Current broad save/recovery check now passes in a fresh isolated profile; the earlier disk-space limitation is historical. F15 leaves checkpoint continuation UX open under C03a. |
| C04 / F08 | Representative lounge grouping and structural swim routes exist. Full composition, occupied destination audit, worst-view profile and F13 clearance remain open. |
| C05 / F06 | Catalog still lacks straw, wrap/bag, drink carton, fries, hamburger and sealed oil-container definitions. Natural distribution and final terrain/exclusion fitting remain open. Preserve totals and starter/base-income reachability. |
| C06 / F09 | Shore colour, lighting, foam continuity, cloud forms and underwater depth remain open. |
| C07 / F07, F09 | Section restoration latches exist, but coral remains procedural, tall plants are absent, new schools still wait for zone completion, and the land turtle route remains in sandplay rather than the planned lounges default. Existing C07 work correctly covers these gaps. |
| C08 / F09, F10, F12 | Final art integration, all-device flow, physical readability and observed pacing remain open. Supplying an asset is not enough unless its runtime consumer is wired. |
| C09 / F10, F11 | Human-paced full completion, physical controller acceptance, final-content 4.6.1 export/packed checks, clean-machine play and target-hardware/long-session profiling remain open. Historical 4.6.3 exports cannot satisfy them. |

## Visual review of the committed C04 evidence

The [lounge pocket](../handoffs/images/C04/lounge-pocket-restored.png) is materially better organized: actual paired destinations, shade and gaps replace the earlier storage rows. Keep this work. It does not close the full layout audit.

The [along-shore view](../handoffs/images/C04/along-shore-restored.png) still has a large empty sand/water foreground and a narrow activity band; the [aerial](../handoffs/images/C04/aerial-restored.png) exposes broad sparse flanks, a rectangular-looking inland backdrop and a pier that dominates the beach. These remain C04 composition work. C06 owns the harsh cyan/white water, segmented foam and very bright cloud forms. Adding skyline detail alone would not address the composition.

The [reef](../handoffs/images/C04/reef-initial.png) has some near/middle framing but repeated mound proxies, a flat floor, no tall vegetation and a distant above-water silhouette plainly visible through green water. It remains far from the [reef reference](review-evidence/reference-03-reef.png). C04 owns safe structure, C06 depth/readability and C07 habitat/restoration. Preserve this split so visual dressing does not repeatedly invalidate clutter access.

These are inspected, already committed rendered captures from the same gameplay checkpoint. This review did not recapture them or claim a new human walk/swim recording.

## Validation performed

All commands used the supplied 4.6.1 console executable from the project root. Each process used its own temporary `%APPDATA%` directory (`%TEMP%/beach-review-20260923-<case>`), so the old accumulated check runs and real player settings/saves were not used. Roughly 48 GB was free when checks began. No existing saves or historical captures were deleted.

| Command suffix after `--headless --path . --script res://` | Exit / result | What it establishes |
|---|---|---|
| `tests/run_checks.gd` | 0; boot, asset closure, ownership, bindings, manifest pass | Current native baseline. |
| `tests/validate_c01_input.gd` | 0; six tools, prop and sealed bag, zero failures | Injected primary input in the real scene with staged tools/targets. |
| `tests/validate_sorting.gd` | 0; 20 → 200 → 240 cells, zero failures | Existing default/X-remap, table pause, checkpoint, loaded sorting and tray routes; does not cover F14/F15. |
| `tests/validate_save.gd` | 0; initial/recovery/rack/pose/table/quit, zero failures | Broad save check now completes. The blocked-directory error is its intentional failed-write case. |
| `tests/validate_full_run.gd -- --final-special` | 0; 5,400 waste, 300 props, one result/receipt, two reloads | Accelerated full-run service invariants and a final revealed item through input. Most collection is staged, so this does not clear F13. |
| `tests/validate_world_traversal.gd` | 0; 13 waypoints, 147 m, three huts, two reefs, pier carry | Injected movement through selected routes; not an exhaustive pickup/reachability pass. |
| `tests/validate_content_economy.gd` | 0; three seeds, 3,960 reachable purchase sets | Existing numeric base-income solvability. Physical rock clearance is outside its model. |
| `docs/plan/review-evidence/checkpoint-review.gd` | **3**, one for each reproduced finding | Review reproduction with real state/colliders/input; [recorded output](review-evidence/checkpoint-review.txt). |

The [reproduction script](review-evidence/checkpoint-review.gd) is tied to this checkpoint/seed and deliberately exits nonzero while F13–F15 reproduce. Setup collects by service, focuses controls and loads slots directly; the failing Y/Save activations use injected controller events. Reef evidence uses real collider queries after streaming/physics reconciliation. It is not a new test framework or physical-controller evidence. When implementing the fixes, fold only the smallest useful regression into the existing sorting/save/world checks and keep this historical reproduction as evidence.

No target-hardware timing, physical controller session, human-paced 5,700-object completion or new exported-build acceptance was performed. The seven passing checks and three reproduced failures are compatible results: the passing checks do not cover the failing paths.

Plan validation passed: seven changed/new Markdown files, 165 local links including referenced anchors, balanced code fences, eleven completion-packet sections matching the dependency table, no missing dependencies or cycles, and `git diff --check`.
