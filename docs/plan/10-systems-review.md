# Systems implementation review — 24 September 2026

This is a review snapshot. All remaining actions below are now consolidated into [the finishing phase](11-finishing-phase.md), including the revised look-and-feel plan. Track live completion in its FIN-01–FIN-10 checklist; keep this document as the finding/evidence record.

Reviewed gameplay checkout `68a123a` against the confirmed requirements, P00–P29 specifications, completion plan and C00–C09 handoffs. Engine: `4.6.1.stable.mono.official.14d19694e`, Compatibility; content `beach-content-8`, beach version 8, generator `manifest-1`, save schema 1. This review changes documentation and retains one bounded diagnostic; it does not repair gameplay.

**Conclusion:** the required systems have implementations and substantial integrated evidence. The game still has two reproduced control defects and incomplete player/device/release acceptance. There is no evidence here that inventory, sorting, progression, rescue, restoration or persistence needs rebuilding. Do not describe passing accelerated completion as proof that all systems are accepted through normal play.

**User direction carried into finishing:** finish all nonvisual systems first, with visuals as a separate part of the same finishing phase. Collision, objective access, readable action prompts, controller operation and observable restoration triggers remain functional requirements. Provisional art can support functional acceptance; it cannot establish visual acceptance. The [finishing phase](11-finishing-phase.md) owns execution and closure; [C-packet specifications](07-completion-plan.md) retain detailed contracts.

## What has changed since the previous review

- C01/C02 repaired post-reveal/detached pickup, contextual carrying, controller table focus and table pause/save access. C03/C03a added mixed waste/valuable bag order, three checkpoints, local result metadata, remapped native-button priority and correct checkpoint continuation. F01–F05 and F14/F15 should not remain described as unimplemented work.
- C04/C05 repaired the reproduced reef obstruction, hut entrances, rack aisle collision, selected-bag deposit and aim-ray interference. Occupied-state evidence now includes all 300 target rays, no reported collider/non-shade mesh intersections and one movement approach in each of 15 destination families. That is stronger than the previous checkpoint, but is not every occupied approach or every seed.
- C05 implemented the six missing logical waste forms: straw, wrap, carton, fries, hamburger and oil container. The catalog has 40 definitions; required counts remain 5,400 waste + 300 props, with 40 optional valuables. Its later rendered two-bag route includes normal pickup, four carried deposits and an $80 collection. Earlier service-shortcut opening notes are superseded by that bounded route; human pacing remains open.
- C07 implemented section fish, permanent local colour/plant rewards, lounge and both reef turtle routes, and partial-restoration reload/population checks. Restoration is not waiting for a new wildlife system. Species models and habitat composition are visual work; normal-play restoration and access at a dirty/restored boundary still need acceptance.
- C08 fixed large-prop swimming speed, global Pause conflicts, offscreen settings/shop focus and repeat actions across physics ticks. The last repair introduced the edge case below. Final device and remapping coverage remains open.
- C09 produced an interim 4.6.1/content-8 package with packed boot, saves, 100 seeds and accelerated completion evidence. Subsequent gameplay/world edits supersede that binary. Neither that candidate nor the old 4.6.3/content-5 package is the current reviewed build.

Evidence: [C03a](../handoffs/C03a.md), [C04](../handoffs/C04.md), [C05](../handoffs/C05.md), [C07](../handoffs/C07.md), [C08](../handoffs/C08.md), [C09](../handoffs/C09.md). These are historical results unless explicitly rerun below.

## Reproduced gaps

### F16 — The one-shot latch can discard the next distinct press

**P2 · R06/R08/R29 · owner: C03b, then C08 device acceptance.**

`InputReader.just_pressed()` stores an action in `_one_shot_held`. Only `sample()` removes it, and only if the action is currently up. If release and the next press both arrive between physics samples, the next sample sees the button held and retains the old latch. Godot reports a new action edge, but the reader suppresses it. This affects the shared one-shot path, including pickup, throwing, interaction and tool switching.

Reproduction used the actual `scenes/main.tscn` player/InputReader with the player's automatic physics sampling disabled so the edge sequence could be controlled. Inject left-button press → sample; release and press again before the next sample → sample. Observed `first=true`, `engine_second=true`, `reader_second=false`. A release given its own sample restores the next press (`sampled_release_control=true`). This is an injected timing regression, not a claim that every ordinary click fails. State invariants remained clean.

Future repair: retain one action per press across multiple physics ticks while acknowledging real release/new-press edges independently of whether a physics sample happened during release. Preserve continuous vacuum, modal suppression and remapped button/trigger operation. Check the shared input boundary; do not add per-tool workarounds or an input framework.

Sources: [input reader](../../scripts/player/input_reader.gd), [player dispatch](../../scripts/player/player.gd). [Diagnostic](review-evidence/systems-review.gd), [recorded output](review-evidence/systems-review.txt).

### F17 — Required service prompts still hardcode the keyboard E key

**P2 · R17/R29/D21 · owner: C03b, then C08 remapping acceptance.**

The equipment counter, tool rack, collection hotline and waste containers set `interaction_reason` to an `E:` instruction. `PlayerInteractor` copies that reason; `TargetLabel` gives any nonempty reason priority over its binding-aware action text. Switching device or rebinding refreshes the label but leaves the same hardcoded instruction.

In the main scene, controller Interact resolved to `X`, while the real container target label read `PMD container | E: deposit or retrieve sealed bag`. The other three service roles use the same source path. These are instructions for mandatory gameplay, so this belongs to systems completion even while visual styling is deferred. C02's detector/table prompt repairs did not cover these service roles.

Future repair: retain meaningful service verbs and derive the displayed interaction binding from SettingsStore at display time. Check keyboard remap, controller remap and device switching for counter, rack, all container categories and hotline; preserve reason text for actual rejection conditions.

Sources: [equipment shop](../../scripts/stations/equipment_shop.gd), [containers](../../scripts/stations/waste_container.gd), [hotline](../../scripts/stations/collection_call_point.gd), [target label](../../scripts/ui/target_label.gd). Same diagnostic/output as F16.

## Systems reconciliation and remaining acceptance

“Implemented” below means source and integrated evidence exist; it does not certify every acceptance case. Missing human/device evidence is distinguished from missing code.

| Original scope | Current evidence | Remaining nonvisual work / owner |
|---|---|---|
| P00–P02: project, asset loading, state authority | Boot/staging closure, 5,740 records, stable IDs/owners and synchronous finalization exist; fresh baseline check passes. | Preserve authority and reproducible staging; no replacement architecture. C09 verifies the final packaged closure. Final asset fidelity is separate. |
| P03–P04: input, settings, movement | Native bindings, settings, first-person movement, carry/swim modifier and menu focus exist. | F16/F17 in C03b; C08 physical controller, remap/context transitions, disconnect/reconnect and functional readability. |
| P05–P07: world, generation, physics | Eight zones, 18 sections, three stations, deterministic quotas, streaming, throws and recovery exist. C04 has representative occupied-family access; C05 has bounded reef clearance. | C04/C05 record current playable reach, pickup/throw/slot access and air routes in initial, occupied and partially restored states. A clear item origin or target ray alone is not a walk/swim route. |
| P08–P11: targeting, carrying, placement, cleaning | Normal contextual pickup, shared mixed-bag order, two small/one large carry, reversible slots/claims and cloth cleaning exist. | C03b input repair; C04 normal manipulation at destination families, dirty-prop rejection, shared-shelf allocation and recovery after reload. Keep ownership/claim checks. |
| P12–P14: table, bags, containers, collection | Fresh sorting check passes 20/200/240 cells, wrong/correct sorting, controller and mouse actions, physical catches and tray. Two-bag opening evidence reaches payment. | C08 physical device loop including correction, partial seal, full rack/retry, selected second bag, deposit/retrieval and explicit collection. Payments must remain once-only; no new sorting/payment system needed. |
| P15–P16: purchases and cleanup tools | All 19 offers, two-slot rack, passive gear, sand cleaner and vacuum implemented. Fresh base-only economy check passes 3,960 purchase sets. | C05/C08 earn/purchase/equip/use through the physical shop and booklet in early/mid/late play; numeric affordability does not prove physical access or pacing. |
| P17–P19: buried finds, valuables, swimming, rescue | Detector/reveal, valuable tray sale, 10/60/unlimited air, faint drops/markers, 12 rescue sites/24 attachments and harmless freed animals exist. | C05/C08 connected detect→recover→sort/sell and rescue→loose attachment→collection routes, plus mixed carried-state faint→save/reload→normal recovery. Include full-bag cut and starter-air shore-to-site return. |
| P20–P21: completion/restoration | Home-section credit, permanent flags, once-only group reward/result receipt, local fish and three turtle routes exist; fresh accelerated 5,700 finish and two reloads pass. | C07 normal final-local-task collection/placement and dirty-neighbor access, rescue permanence and prop re-pick without nature/reward reset. Final species art is separate. |
| P22–P23: UI, guidance, scanner | HUD, booklet, shop, results, discovery filters and near/far remaining-item guidance exist. | C08 useful controller/keyboard prompts, all menus, late-run filter selection and last-item search across world/station/container states; no debug teleport or direct collection for those acceptance actions. |
| P24: persistence | Autosave, three manual checkpoints, independent runs, partial table, A/B recovery and failure retention exist; fresh save check passes. | C03b must preserve these flows; C09 repeat final packaged save/physics/recovery and incompatible-version handling. No migration subsystem requested. |
| P25: final art | Partial; deliberately outside this systems review. | Separate visual track. Any later geometry/collision/visibility edit reopens the affected system route, not every prior check. |
| P26–P27: content, balance, accessibility | Catalog gap closed; quota/economy and bounded opening routes pass; several accessibility fixes landed. | C05 human-paced opening, dense patch, tideline and underwater routes; C08 mid/late pacing, physical controller and readable 720p/1080p/4K/wide layouts/settings. |
| P28–P29: performance/export/release | Native batching and development profiles exist; interim export is stale. | C09 current export, normal full completion, target GTX 980-class/8 GB, cold startup/save spikes, long-session memory and clean-machine acceptance remain unverified. |
| P30 and R30/R31 deferred features | Optional jetski, multiplayer, online leaderboards and sound are intentionally absent. Local result metadata exists. | No required-release gap; do not add them during systems closure. |

## Compatibility boundary for the separate visual track

Keep wrapper paths, item definitions, IDs, slot IDs, anchors and gameplay collision stable for a pure visual swap. `compute_content_hash()` includes definition names/visual paths, while reef clearance reads `reef_dressing.gd` constants that are not themselves included in that hash. Therefore an edit in a presentation file is not automatically save-compatible. Save loading correctly compares the regenerated manifest and rejects a mismatch; never weaken that protection to hide a content change.

The review compared the current rear-shelf 1.4 scale against the preceding 1.0 exclusion behavior on 20 named seeds, including `manifest-fixture-v1` and `first-shore`. No manifest change was observed in that sample. **No new save-compatibility failure is claimed.** Future functional geometry/anchor changes still need a declared version decision and a preserved compatible build under C00/C09; a single pinned seed is insufficient to infer universal compatibility. Add generation-affecting reef parameters to the existing content identity when that boundary next changes, or explicitly version that change. This is bounded compatibility work, not a reason to rebuild generation or couple art acceptance to systems acceptance.

## Fresh validation and its limits

All runs used the specified 4.6.1 executable and separate process-only `%APPDATA%` paths under `%TEMP%/beach-systems-review-20260924-*`. Existing player saves/settings were not used. Existing validation scripts were reused without changes.

| Run | Observed result | Limit |
|---|---|---|
| `tests/run_checks.gd`, headless | Exit 0; boot, staged closure, ownership, bindings and manifest pass. | Broad baseline, not every input edge. |
| `tests/validate_sorting.gd`, headless | Exit 0; 20→200→240, atomic unload, wrong/correct, controller/mouse, physical catch, tray; zero failures. | Injected input and staged inventory, not physical-controller evidence. |
| `tests/validate_save.gd`, headless | Exit 0; initial/recovery/rack/pose/table/quit, zero failures. | Blocked-directory error is intentional failed-write evidence. |
| `tests/validate_full_run.gd`, headless | Exit 0; 5,400 waste + 300 props, one receipt/result, two reloads, post-finish replacement. | Accelerates most actions and placement; cannot certify all pickup routes or human pacing. |
| `tests/validate_content_economy.gd`, headless | Exit 0; 3 seeds, dry minimum 3,321, 3,960 reachable purchase sets, $490 access route, $5,300 offers; deliberate dead-end detected. | Numeric accessibility model, not actual diving/travel effort. |
| `tests/validate_world_traversal.gd`, rendered Compatibility/RTX 3070 | Exit 0; 13 waypoints/147 m, three huts, shop, two reefs, 1,010 reef origins with zero rock overlaps, six catalog pickups, pier carry, 2.00 m/s loaded swim; zero failures. | Scripted movement/aim with accelerated/staged portions; no physical-controller or exhaustive access claim. |
| `systems-review.gd -- --input-only`, headless | Nonzero; two gaps reproduced, zero state errors. | Controlled injected edge sequence and actual service-label path; no human timing/device claim. |
| `systems-review.gd`, generation comparison | 20 seeds unchanged under old/new rear exclusion scale. | Bounded sample; initial input setup was corrected to wait for physics delivery before the final input-only reproduction. |

Rendered traversal result is recorded in the accompanying [review evidence](review-evidence/systems-review.txt). No new performance certification, physical controller session, normal full human run or final export was performed for this documentation review.

## Next execution

1. **C03b:** repair F16/F17 at their shared boundaries and demonstrate them in the main scene.
2. **C04/C05 functional gates:** finish physical access, occupied destinations, dense/tideline/special-content routes, starter-air travel and observed opening pacing using current provisional art.
3. **C07 functional gate and C08:** demonstrate connected restoration/recovery, then the complete control/menu/tool loop and early/mid/late progression on real devices. Reuse the same run/evidence where possible.
4. **C09 systems gate:** current Windows candidate, normal 5,700-object finish, final save/package checks and honest hardware/long-session evidence. Unavailable human/hardware evidence stays explicitly open.
5. **Separate visual track:** finish C04 composition, C06 look, C07 habitat/species and C08 final asset/grip polish. Recheck only functional routes affected by those edits, then refresh the final package/performance gate.

Do not restart accepted C00–C03a work, re-add the six catalog definitions or defer functioning restoration/controllers/saving until art is final. The [completion plan](07-completion-plan.md) supplies ownership and exit criteria for each remaining step.
