# Implementation and reference review — 23 September 2026

Historical review before C00–C04 implementation. See the [C04 checkpoint review](08-checkpoint-review.md) for current status, seven fresh passing checks and findings F13–F15. The findings below preserve their original evidence; repaired F01–F05 must not be read as unchanged current blockers.

## Conclusion

The project has most of the planned systems and a substantial playable beach. It is **not functionally complete or visually aligned with the references yet**. The remaining work is not another implementation of the whole game: preserve the existing state, sorting, payment, placement, save and streaming services, repair the input paths that do not reach them, then finish the authored environment and content.

Two failures in required input flows were reproduced during this review: revealed/detached waste cannot be collected in the intended tool mode, and the controller cannot activate essential sorting-table buttons. A staged occupied-hands case bypasses the first failure through an unintended fallback; it does not satisfy the planned pickup behavior. Existing checks pass because several invoke service methods or button signals directly. A successful accelerated 5,700-object completion therefore does not establish that a player can finish normally.

The largest visual gaps are the overall beach composition, the appearance of the completed prop destinations, the water/lighting treatment and the sparse reef. Adding more city façade details alone will not close these gaps. The [new completion plan](07-completion-plan.md) orders the remaining work around these findings.

## Scope, authority and evidence

This reviews the working tree, including its substantial untracked implementation, rather than only the last Git commit. The task changed documentation and review evidence; it did not fix gameplay, change tuning, replace art or create a new release build. Existing user changes were retained.

The original [requirements](01-requirements.md), [architecture](02-architecture.md), [world direction](03-world-and-assets.md), [balance](04-content-and-balance.md), [verification rules](05-verification.md), packet specifications and handoffs were compared with the active scene, catalog and relevant runtime call paths. The latest request is to review and plan. Old packet instructions to implement/export are historical specifications, not authorization to execute a new implementation in this task.

Exact copies of the three newly attached images are saved as [beach](review-evidence/reference-01-beach.png), [aerial](review-evidence/reference-02-aerial.png) and [reef](review-evidence/reference-03-reef.png). Their visual content is reference evidence. People, vehicles and branding pictured in them are not instructions to add visitors, vehicle gameplay or a logo to the game.

Preserved scope: one approximately 160 m beach, first person, 5,700 required objects, 40 optional valuables, sunny weather, decorative non-enterable city, no human visitors, and optional jetski deferred. The user-confirmed compact scale is already implemented; reducing the beach to 40 m would be a new change, not unfinished work.

Evidence labels used below:

- **Implemented:** source and scene wiring exist; relevant checks/handoffs support the described behavior. This is not blanket release acceptance.
- **Partial:** some required behavior, content, presentation or player-facing access remains missing.
- **Blocked:** a reproduced failure prevents a required player flow.
- **Unverified:** implementation exists, but the required human/device/build evidence does not.
- **Deferred:** intentionally outside the required release.

## Verified current inventory

| Area | Current implementation |
|---|---|
| Engine used for this review | Godot `4.6.3.stable.official.7d41c59c4`, GDScript, Compatibility/OpenGL. The original plan still names 4.6.1. |
| Entry point | `scenes/main.tscn` and `scripts/main.gd`; title, new run, load/continue, settings and runtime assembly. |
| Logical content | 34 definitions: 18 waste, 15 props, one valuable. 5,740 records: 5,400 required waste + 300 required props + 40 optional valuables. |
| World | Eight zones, 18 sections, three working service points, one physical shop/rack, compact shore, pier head, offshore lighthouse, inland backdrop and two reef areas. |
| Special content | 300 buried waste, 24 attachments at 12 rescues, 120 residue items, 60 dirty props. All are subsets of the required totals. |
| Purchases | 19 resource-defined offers, $5,300 total; cloth → knife → detector → tank access chain costs $490. |
| Assets | Manifest contains 86 staged roles and 17 unresolved grouped requests. Latest staging handoff records a 244-file dependency closure. |
| Persistence | Native JSON snapshots, A/B generations, checksum/identity/content validation, autosave and a manual slot for each independent run. |
| Rendering scale | Native distant MultiMesh litter plus nearby physical views. Small batched bodies promote within 12 m and demote beyond 24 m; fallback views use 45/70 m. |
| Working tree | Gameplay, scenes, data and handoffs are present locally but predominantly untracked. This review is not evidence of a reproducible committed checkout. Licensed staged art remains intentionally ignored. |

Sources: [main](../../scripts/main.gd), [generator](../../scripts/world/manifest_generator.gd), [world definition](../../data/world/beach_01.tres), [quota resource](../../data/world/section_quotas.tres), [asset manifest](../../data/asset_manifest.json), [view manager](../../scripts/items/item_view_manager.gd), [distant visuals](../../scripts/items/distant_item_visuals.gd).

## Findings ordered by player impact

### F01 — Required revealed finds and detached rescue litter fail the intended pickup flow

**Priority: P1 · Reproduced · R18/R20/R21/R25; P17/P19/P29.**

The detector changes a buried record to WORLD, but its immutable definition still requires `detector`. Likewise a cut attachment dropped into WORLD still requires `knife`. The stick is rejected by both targeting and `ItemStore.try_collect`. With the required tool equipped, `BeachPlayer._physics_process` routes primary input exclusively to `MetalDetector.try_click` or `RescueKnife.try_click`. Those methods handle BURIED/ATTACHED targets, not loose WORLD pickup.

The review placed existing manifest records into their post-reveal/post-detachment WORLD states and aimed through the real collider/ray path. For buried metal, rescue ring and keys, the stick reported “Needs Detector/Knife”; the matching tool showed a collect action but the click left the record WORLD. This is a controlled reproduction of the post-transition input failure, not a claim that the review manually dug every item or cut every attachment.

Consequences: intended stick pickup fails for the 300 mandatory buried waste. Rescue litter cannot be recovered in ordinary tool mode after a full-bag cut, throw or faint. Optional keys have the same problem after revelation. State is retained.

A follow-up deliberately staged a held bucket while the detector remained the selected tool, then injected the same pickup click. Collection succeeded: `is_active()` becomes false when hands are occupied, so primary input falls through to the general interactor while its eligibility check still sees the detector. This is a confirmed accidental bypass, not proof that every possible input sequence is blocked. The required tool-mode flow remains broken, and pickup should not depend on carrying an unrelated prop. [Follow-up evidence](review-evidence/input-probe-occupied-hands.txt).

**Root fix:** distinguish access actions from collection of an already loose item. Resolve the eligible target before applying a tool-wide primary override; enforce the same state-sensitive rule in targeting, ItemStore and area-tool filters. Preserve cloth-only residue and knife-only attached targets. Do not change all definitions to “no tool” and thereby bypass hidden/attached access rules.

Evidence: [player routing](../../scripts/player/player.gd), `_physics_process` line 41; [interactor](../../scripts/player/interactor.gd), `_result_for_collider`; [ItemStore](../../scripts/core/item_store.gd), `try_collect` line 15; [revelation](../../scripts/items/buried_find.gd), `try_reveal` line 50; [knife](../../scripts/tools/rescue_knife.gd), `try_cut` line 47; [input log](review-evidence/input-probe.txt). `tests/validate_buried.gd` and `tests/validate_rescue.gd` collect these records by calling ItemStore directly, explaining the coverage gap.

### F02 — Controller confirmation cannot activate Unload or Seal

**Priority: P1 · Reproduced · R12/R15/R29; P12/P13/P27.**

`SortingView._input` consumes D-pad events as table-cell movement and A as `table_select`. Its A branch special-cases only the valuables controls; other focused buttons still invoke `_select_focused`. Native button activation never receives the consumed input. `open()` also does not establish a controller route between the cell grid and the surrounding controls.

With a real waste item in the bag and **Unload explicitly focused**, a synthetic controller A press left bag count 1/table count 0 and displayed “Empty cell”. After staging one item in the PMD bin and explicitly focusing **Seal**, A left the bin at 1 and created zero bags. Even granting focus does not solve activation, so this is more than an unverified physical controller model.

**Root fix:** give native controls their own focus context and consume table navigation only while the table grid/bin inspection owns focus. Provide a visible route among Unload, cells, bins, Seal, valuables and Exit. Reuse native Control focus, not a second menu framework.

Evidence: [sorting input](../../scripts/ui/sorting_view.gd), `_input` line 102 and `_select_focused` line 323; [overlay](../../scenes/ui/sorting_overlay.tscn); [input log](review-evidence/input-probe.txt). Existing sorting/sealing checks emit `Button.pressed` directly for these actions, bypassing the failure.

### F03 — Four equipped tools prevent contextual prop and sealed-bag pickup

**Priority: P2 · Reproduced for props; same dispatch applies to bags · R07 and the tool target matrix; P09/P16/P17/P19.**

A clean bucket is correctly targeted with the action `hold`. Clicking holds it with the stick or cloth, but fails with sand cleaner, vacuum, detector or knife equipped. Those tools intercept primary input before the general interactor. `hold_bag` uses that same general path, so the dispatch also prevents starting bag transport with those tools active. With two such tools equipped, the ordinary workaround is a trip back to the rack to change loadout merely to pick up a clean prop or disposal bag; occupied-hand fallbacks do not make this intended behavior.

Repair this with F01's shared input-precedence change: compatible clean prop/bag pickup takes precedence over tool fallback. Dirty furniture still requires explicit carry or aimed cloth cleaning; holding a prop must stow equipment as it already does.

Evidence: [player routing](../../scripts/player/player.gd), lines 55–64; [carry](../../scripts/player/carry.gd), `_on_primary_requested`; [input log](review-evidence/input-probe.txt).

### F04 — Sorting has no pause/save-and-quit entry through the normal pause control

**Priority: P2 · Reproduced · R27; P22/P24.**

Entering the table disables player input. `BeachPlayer._input` therefore ignores Pause, while `SortingView._input` has no pause branch. Controller Start left sorting active with no pause menu. The player can exit sorting and then save, and the backend preserves table contents, but the promised save-and-quit-during-sorting flow is not exposed directly. The save check calls the main save handler directly.

Route Pause from table context to the existing pause menu, cancel only transient drag presentation, and retain the logical table/bin/tray state. Resume must restore the appropriate camera/focus and prevent a close-button press from becoming a world action.

Evidence: [station enter/exit](../../scripts/stations/sorting_station.gd), line 298; [player pause handler](../../scripts/player/player.gd), line 80; [sorting input](../../scripts/ui/sorting_view.gd); [save check](../../tests/validate_save.gd).

### F05 — Shared bag throwing is not chronological when valuables are present

**Priority: P2 · Reproduced · R08/D16; P09/P17/P24.**

Waste and valuables share capacity, but use separate arrays. `try_throw` and `peek_throw_item` always choose waste before valuables. Collecting a can and then keys throws the can, contradicting “last collected bag item”. This also needs a saved ordering rule; changing only the peek function would leave the authoritative throw inconsistent.

Keep one collection order or a small persisted ordering field, used by collection, knife-to-bag, preview, throw, unload and faint handling. Preserve valuable protection and the shared capacity limit.

Evidence: [ItemStore](../../scripts/core/item_store.gd), `try_throw` line 163 and `peek_throw_item` line 245; [player record](../../scripts/core/run_state.gd); [input log](review-evidence/input-probe.txt).

### F06 — The catalog does not implement every requested litter family

**Priority: P2 · Source-confirmed · R04; P01/P06/P26.**

The 34-definition catalog is internally count-correct, but it contains no distinct straw, plastic wrap/bag, drink-carton, fries, hamburger or sealed oil-container definitions. Several are listed only as asset requests. Having no cube-backed item definitions does not mean these features were retained: some requested forms never entered the logical catalog at all. Hotdogs/panini/banana food provide variety but do not establish the named missing types.

Reconcile the catalog against the requested families. Add missing required types with registered placeholders where necessary, replacing allocations within the existing category quotas. Do not increase 5,700 or introduce hazardous-waste mechanics. The exact distribution is tuning; omission of a named family should be explicitly recorded rather than hidden behind a total-count pass.

Evidence: [item resources](../../data/items), [asset requests](../asset_requests.md), [P26 specification](packets/P26-content.md), [content specification](04-content-and-balance.md).

### F07 — Restoration logic is strong, but the environmental reward is incomplete

**Priority: P2 · Source and render evidence · R22/R23; P20/P21/P25.**

Permanent restoration flags, one-time group payment and immutable first-finish receipts are implemented. Their visual recipes remain limited: beach sections add a palm; pier sections add a buoy; reef sections reveal a regular cluster of procedural stems, a clarity patch and starfish. Extra fish schools are zone rewards rather than the planned local coral-section reward. The one beach-to-water turtle is assigned to sandplay, while the balance document names lounges. No supplied-art shore birds, seaweed or seagrass are integrated.

The primary coral form is five cylinders repeated into twelve clusters per applicable section. The underwater ridge set is twelve transformed Synty sand-pile/ridge forms with a flat material. These do not create the large rocks, branching coral, tall vegetation, layered fish and blue depth shown in reference 3.

Finish authored local before/after states and reconcile the turtle-zone default. Keep the existing state latches and bounded route populations. Asset completion and stronger environment authoring are needed; an ecosystem simulation is not.

Evidence: [restoration recipes](../../data/world/restoration_recipes.tres), [restoration implementation](../../scripts/world/restoration_section.gd), [reef dressing](../../scripts/world/reef_dressing.gd), [before](review-evidence/reef-current.png), [restored](review-evidence/reef-restored.png).

### F08 — Composition and finished destinations remain far from the references

**Priority: P2 · Visual finding · R02/R03; P05/P10/P25/P26.**

The compacted world retains a long pier projecting through a very broad shallow strip, a row of city blocks on an exposed rectangular backing plane, widely separated activity structures and large areas of flat sand. The reference aerial uses a beach that wraps around a bay, a pier that crosses the composition, a lighthouse on a legible separate landform, and alternating dense activity pockets and open passages.

The fully restored view matters: sorted chairs and parasols become tight straight storage rows, and the portable shelter grouping remains very simple. Tidying the level therefore does not yet produce the inviting small seating groups and activity compositions in the references. Slot count is correct; destination composition still needs design. New-run clutter also reveals regular allocation bands instead of strongly authored food, sports and shoreline contexts.

Use the existing assets to recompose the playable scene and compatible destinations. Do not treat an elevated debug camera as a proposed third-person mode. The screenshot comparison is about relationships and silhouettes, not exact coordinates or reproducing a promotional crowd.

Evidence: [current aerial](review-evidence/aerial-current.png), [restored aerial](review-evidence/aerial-restored.png), [current beach](review-evidence/beach-current.png), [restored beach](review-evidence/beach-restored.png), [shore geometry](../../scripts/world/shore_dressing.gd), [pier](../../scripts/world/pier_visuals.gd), [generation](../../scripts/world/manifest_generator.gd).

### F09 — Water, lighting and art availability are separate unfinished tasks

**Priority: P2 · Visual/source finding · R03/R04; P01/P21/P25/P27.**

The surface now has facets and foam, but the aerial reads as a pale, strongly bounded shallow strip against an almost uniform distant ocean. The shore transition and foam need integration at the ends and under the pier. Clouds are bright flat ring shapes; lighting gives palms, sand and buildings a harsher cyan/white contrast than the warm, layered reference. The underwater presentation is green/teal and opens onto distant above-water silhouettes, rather than enclosing the player in blue water and reef forms.

The reef's largest limit is also missing geometry. The asset manifest still requests turtles, reef fish, starfish, coral/sea plants, multiple tools/swim gear and first-person hands. Existing project-owned approximations preserve presentation but are not verified pack assets or final replacements. Palm City building/prop reuse can improve the shore now; it cannot supply verified marine species merely by changing tint or adding cylinders.

Record each role as exact staged asset, explicit substitute, provisional project art or unavailable. Split grouped requests that cannot map to a single runtime scene. Integrate user-supplied compatible assets when available; final reef fidelity remains open until then. No external purchase or pack substitution is assumed.

Evidence: [asset manifest](../../data/asset_manifest.json), [asset register](../asset_requests.md), [water shader](../../shaders/beach_water.gdshader), [water mesh](../../scripts/world/water_surface.gd), [underwater environment](../../scenes/world/underwater_environment.tres).

### F10 — Release evidence remains incomplete, and passing checks currently overstate player access

**Priority: P1 for player completion; unverified for hardware · P26–P29.**

The new review reran accelerated full completion, economy and save checks successfully. Those protect important invariants and should remain. They do not replace a full run that collects through input, travels, cleans, detects, rescues and transports bags. F01–F04 demonstrate why that distinction changes the release conclusion.

The latest recorded 600-frame 1080p development sample is 7.65 ms p95 on an RTX 3070, with about 2.61 seconds spent building item views synchronously. That is useful progress, not an exported-executable GTX 980-class/8 GB performance pass. Full startup includes more than item-view construction. Long-session memory, save stalls, worst-case table/vacuum/faint/restored-reef loads, physical controller-only completion and a separate clean-machine playthrough remain open. These were not performed in this review.

There are already 31 top-level GDScript validation/capture files. Do not respond by building a new test framework or one script per plan row. Extend the existing meaningful flows at the actual input boundary, and record playable evidence.

Evidence: [performance record](../performance.md), [release record](../release-checks.md), [full-run check](../../tests/validate_full_run.gd), [project verification policy](../../AGENTS.md).

### F11 — Planning and handoff status has drifted from the current build

**Priority: P2 for reliable handoff.**

The original index still described an unimplemented project before this review added a current-status pointer. Several historical handoffs describe 640 m, older asset/catalog counts, old content hashes or a pre-MultiMesh implementation. Newer notes supersede them, but readers must reconstruct that history. Requirements/export instructions still specify 4.6.1 while current release notes and installed runtime use 4.6.3. `asset_requests.md` says 84 wrappers/240 files while the current manifest has 86 roles and the latest staging handoff says 244 files.

The existing maintenance-engine change is recorded, not silently reversed or newly approved here. Reconcile the active engine baseline, current evidence and exact asset statuses in one current register. Historical handoffs can stay historical. A packet with a script and handoff should not be marked accepted while its own player flow fails.

### F12 — Smaller product-contract gaps remain

**Priority: P2/P3 · Source-confirmed.**

- **Prompts:** detector still says `LMB: uncover`; bin-inspection feedback still says `LB/RB`, `A`, `B`. They do not follow remapped bindings. The sorting inspection label also exposes raw item IDs in ordinary player UI. Relevant files: [detector](../../scripts/tools/metal_detector.gd), [sorting view](../../scripts/ui/sorting_view.gd).
- **Save selection:** backend supports arbitrary slots, but both Save and Save and quit write `manual`. Players have independent runs and autosaves, but cannot choose several manual checkpoints within one run. Treat a simple manual-slot picker as a product completion proposal, not proof that all multi-save behavior is absent. Relevant file: [main](../../scripts/main.gd), lines 365–375.
- **Result metadata:** the receipt records seed, versions, time, totals, sorting, money and purchases. Planned participant IDs/count, ruleset/settings and faint count are absent. Add the small local record fields; do not implement online leaderboards. Relevant files: [progress](../../scripts/core/progress_service.gd), [state](../../scripts/core/run_state.gd), [swim](../../scripts/player/swim.gd).
- **Art/save coupling:** `compute_content_hash` includes display names and visual scene paths, and save loading requires a regenerated matching content/manifest hash. Replacing meshes in-place can preserve compatibility; changing a catalog visual path/name can invalidate saves and alter seed streams. The next art/content pass needs an explicit compatibility decision before changing those fields. This review found no save corruption in the checked paths.

## Packet-by-packet reconciliation

| Packet | Assessment now | Implemented evidence and remaining work |
|---|---|---|
| P00 Project | Implemented | Main scene, runtime folders, import boundary and checks. Reconcile current engine baseline. |
| P01 Assets | Partial | Reproducible selected staging and missing-role manifest. Final exact models and accurate replacement wiring/status remain. |
| P02 State | Implemented foundation | Stable IDs, typed records, authoritative owners, synchronous finalization before signals. Preserve this. |
| P03 Input | Partial | InputMap, settings, remapping, device prompts/disconnect exist. Table context and remaining hardcoded prompts fail full coverage. |
| P04 Player | Implemented; device/feel unverified | Movement, jump/sprint/crouch/swim integration, hands and sockets. Physical controller and final grips remain. |
| P05 World | Implemented blockout; art partial | Eight zones, 18 sections, services/storage/recovery. Fresh rendered route reaches 13 waypoints, 147 m and three huts. Recomposition must preserve access. |
| P06 Generation | Implemented; catalog partial | Seed/version/hash, exact quotas, special subsets, starter section. Missing named families and more natural anchor patterns remain. |
| P07 Physics | Implemented | Throws, recovery, sleeping, streaming and live pose capture; save-physics rerun passes. Preserve near-target physics while dressing. |
| P08 Interaction | Partial | Ray target, label, outline, occlusion and action signals. Displayed collect/hold actions can disagree with actual tool dispatch. |
| P09 Carrying | Partial | Capacity, two small/one large prop, bag/hand presentation, throw physics. F03 and mixed waste/valuable LIFO remain. |
| P10 Placement | Implemented logic; art partial | Object ghost, compatible slots, claims/capacity, dirty rejection, physical capture, pulse/sweep. Finished destination layouts need art direction. |
| P11 Cleaning | Implemented | Aimed stain patches, cloth gate, same-ID residue and clean-before-slot logic. Exact cloth/dirt presentation remains provisional. |
| P12 Table | Blocked on controller | Physical table/proxies, overhead view, click/drag/correction, capacity and tray exist. Controller Unload/control focus is broken. |
| P13 Bags | Partial | Auto/manual sealing services, rack backpressure, bag records and category containers. Controller manual sealing and tool-mode carrying need repair. |
| P14 Collection | Implemented | Whole-beach container collection, exact once-only payment/completion and receipt. Accelerated full run exercises it successfully. |
| P15 Progression | Implemented | Physical shop/free rack, booklet, prices/prerequisites, recomputed upgrades. All 19 offers are implemented. |
| P16 Cleanup tools | Partial | Radius/cone/filter/capacity logic exists. Tool priority prevents contextual hold; final tool meshes remain open. |
| P17 Buried finds | Intended pickup flow blocked | Detection/reveal/optional tray sale exist. Revealed WORLD items fail ordinary tool-mode pickup; F01 records an accidental occupied-hands bypass. |
| P18 Swimming | Implemented; final flow unverified | 10/60/unlimited air, surface refill, faint drops/recovery markers and safe respawn. F01 breaks ordinary tool-mode recovery of some carried special waste. |
| P19 Rescue | Intended loose attachment recovery blocked | 12 sites/24 cuts, full-bag drop, permanent animal release. Dropped/thrown/fainted attachments fail ordinary tool-mode pickup. |
| P20 Completion | Implemented at service level | Required counts, one-time rewards, permanent restoration, immutable results and continued roaming. Required input flows fail upstream; no human completion was verified. |
| P21 Wildlife | Partial | Ambient/zone schools, rescue animals, turtle route, stable population keys, terminal load appearance. Local rewards/art/composition need completion. |
| P22 UI | Partial | HUD, menus, booklet/guidance, results, save/load. Table pause/focus, remapped prompts and checkpoint UX remain. |
| P23 Scanner | Implemented | Discovered type/material filters, global matching, near/far guidance, exclusion of hidden/complete items. Human final-item search still needs play evidence. |
| P24 Saving | Implemented backend; UI partial | A/B recovery, snapshot validation, physics/partial-table persistence, independent runs. Table save access, checkpoint selection and next-version compatibility remain. |
| P25 Art | Partial | Supplied shore/palms/buildings/pier/lighthouse/props, water and underwater treatment. Macro composition, lighting, destination layouts and reef fidelity remain substantial. |
| P26 Content/balance | Partial | Exact totals and base-only affordability proof pass. Missing logical families, full-run pacing and input-accessible completion remain. |
| P27 Feel/accessibility | Partial | Travel/pulse/sweep/reduced motion, layout captures and feedback clip. Concrete input failures plus physical controller/TV/contrast checks remain. |
| P28 Performance | Optimized; target unverified | Native batching/streaming is present. Exported target GPU/RAM, extended stress and full startup/save measurements remain. |
| P29 Release | Candidate only; blocked | Windows package and historical packed checks exist. New P1 findings invalidate a claim of functional release readiness. |
| P30 Jetski | Deferred as intended | No required-release gap. Do not implement it to make the screenshot look busy. |

## Coverage of locked requirements

| Requirements | Review conclusion |
|---|---|
| R01 | GDScript/Windows/Compatibility supported; 4.6.3 versus 4.6.1 documents needs reconciliation; target performance unverified. |
| R02–R04 | Compact seeded cleanup world and supplied-art pipeline exist; reference composition, exact art and some catalog families remain partial. |
| R05–R11 | Core movement/carry/placement/cleaning exists; F01/F03/F05 affect interaction consistency and bag order; final hand/tool art remains partial. |
| R12–R16 | Sorting/sealing/payment services exist; controller table access is blocked; payment/completion invariants pass checked flows. |
| R17–R21 | Shop/tools/air/rescue systems exist; revealed/detached pickup is blocked; physical all-tool use is incomplete. |
| R22–R25 | Restoration/progress/results state exists; environmental reward is partial and normal full completion cannot currently be established. |
| R26 | Deterministic generation checks pass at the current version; new content must intentionally version the manifest. |
| R27 | Persistence works in checked paths; table pause/save UI and manual checkpoint selection need completion. |
| R28 | Scanner implemented; late-run usability remains unverified. |
| R29 | InputMap/controller settings exist; entire controller flow fails F02 and needs a real-device pass after repair. |
| R30–R31 | Stable IDs/services provide useful future preparation; no multiplayer or leaderboard should be built now. Local result metadata needs its small promised additions; jetski remains optional. |
| R32 | Detailed original packets/handoffs exist; this review and follow-up plan supply current reconciliation and missing-work ownership. |

## Visual comparison and priorities

| Reference quality | Current gap | Next concrete direction |
|---|---|---|
| Curved, continuous resort coast | Exposed planar ends/backing; a broad strip dominates the aerial | Author a convincing coast silhouette within the existing length; mask nonplayable edges with background landforms; compose bay, pier and island together. |
| Readable foreground/middle/background | Long empty foregrounds, repeated palms/blocks, scattered landmarks | Frame a few intentional beach-level views with palms and activity groups, keeping skyline behind them. |
| Organized leisure areas | Completed props become dense straight rows | Compose small usable chair/umbrella/cabana groups, board racks and sandplay storage while retaining every compatible slot. |
| Warm sand and dimensional sunlit forms | Flat large sand areas, harsh cyan shade/white highlights | Tune sun, ambient, material response and colour as a coherent pass in Compatibility. |
| Clear cyan water with depth and foam | Facets improved, but foam/shallows and distant ocean read as separate surfaces | Refine depth transition, facet scale, shoreline continuity, pier contact and underwater surface view. |
| Blue, layered, living reef | Repeated short stems on a flat green seabed, low habitat density | Authored rock groups, varied coral/sea plants and bounded animal routes at several depths; preserve open pickup/swim lanes. |
| Activity without cluttering the composition | Current objective density is high and visually banded | Keep 5,700 IDs; redistribute into meaningful authored singles, food clusters, bin piles and submerged work sites. Use wildlife and props to suggest life without visitors. |

The reference reef's blur/chromatic fringing and the beach's promotional bloom are not necessary gameplay targets. Match form, colour, depth and life while keeping small litter and outlines readable. Do not increase city scope or switch renderer as a substitute for composition work.

## Validation performed during this review

Engine: `C:/Users/Home/Downloads/Godot_v4.6.3-stable_win64/Godot_v4.6.3-stable_win64_console.exe`. Rendered checks reported NVIDIA RTX 3070, driver 595.79, Compatibility/OpenGL 3.3. These are development-machine results.

| Run | Observed result | Limit |
|---|---|---|
| `--headless --path . --script res://tests/run_checks.gd` | Exit 0: boot, asset closure, ownership, input bindings, manifest pass. | Does not prove every input context. |
| `tests/validate_full_run.gd` headless | Exit 0: 5,400 waste/300 props, receipt/results, two reloads and post-finish replacement pass. | Accelerated setup directly stages props/finds/attachments and table batches. |
| `tests/validate_content_economy.gd` headless | Exit 0: 3 seeds, 3,321 conservative dry waste, 3,960 reachable purchase sets, $490 access route, $5,300 total offers; intentional dead-end fixture detected. | Resource/affordability proof, not player pacing. |
| `tests/validate_save.gd` headless | Exit 0: initial/recovery/rack/pose/table/quit, zero failures. | Expected blocked-directory error exercises failure handling; UI entry is partly bypassed. |
| `tests/validate_save_physics.gd` headless | Exit 0: flight, settled, collection, faint, zero failures. | Does not prove later normal-input recovery of special litter. |
| `tests/validate_world_traversal.gd` rendered | Exit 0: 13 waypoints, 147 m, three huts, zero failures. | Automated movement, not physical-controller acceptance. |
| `tests/validate_pier_art.gd` rendered | Exit 0: lighthouse/pier/shore/backdrop checks and player pier traversal. | Checks presence/collision, not reference fidelity. |
| [Focused input probe](review-evidence/input-probe.gd), headless then rendered | F01–F04 reproduced using the active main scene, real components, existing IDs and injected mouse/controller input. Stick/cloth prop pickup are positive controls. F05's order mismatch was checked through direct collection and throw-preview service calls; source confirms the same ordering in the actual throw. | Gear/poses and post-reveal states are staged; this is not a human run. Probe prints observations and exits 0 even when a gap is observed. |
| Occupied-hands follow-up, rendered | A staged held bucket disables the detector's tool override; clicking then collects revealed metal with the detector selected. | Confirms an accidental alternate path, not the intended stick flow or a full human completion. |
| Fresh 1920×1080 captures | Actual run before and fully restored visual states captured, inspected and saved. Restored state reached 5,700 with zero invariant errors after loading the isolated accelerated full-run save and replacing its final held chair. | Artistic evidence from accelerated states; not a manually earned completion. |

The probe is a narrow review diagnostic under `docs` (excluded from game import/export), not a new testing framework. Run it with `--path . --script res://docs/plan/review-evidence/input-probe.gd`; use the rendered engine for comparable input observations. [Recorded output](review-evidence/input-probe.txt).

Capture setup: 1920×1080 SubViewport, FOV 85, UI/hands hidden, player movement and automatic swim updates disabled for fixed cameras; underwater environment explicitly applied only to the submerged view. Waited 180 physics frames at each viewpoint for normal item streaming. New run seed: `restoration-fixture`; restored save seed: `full-run-integration`. The different seeds prevent treating the pair as a same-seed distribution comparison, but static layout and terminal restoration are comparable. Distant-item culling remains active, so aerial litter counts are not evidence of total density.

| View | Camera position → target | Captures |
|---|---|---|
| Elevated layout | `(-15,65,135) → (0,0,0)` | [Current](review-evidence/aerial-current.png), [restored](review-evidence/aerial-restored.png) |
| Sports at eye level | `(-45,2.1,32) → (-43.75,1.7,12)` | [Current](review-evidence/beach-current.png), [restored](review-evidence/beach-restored.png) |
| West reef habitat | `(2.5,-1.25,101) → (2.5,-2.25,107.5)` | [Current](review-evidence/reef-current.png), [restored](review-evidence/reef-restored.png) |

[Capture log](review-evidence/capture-log.txt). No human-paced complete run, physical controller-only run, clean-machine install or target-hardware certification is claimed.
