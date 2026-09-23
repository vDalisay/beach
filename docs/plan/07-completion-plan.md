# Completion and visual alignment plan — 23 September 2026

## Purpose and starting point

Finish the existing game, rather than restart P00–P29. The [implementation review](06-implementation-review.md) is the evidence baseline and defines findings F01–F12. This document is a new work plan; none of its implementation or acceptance steps is claimed complete by writing it.

The original [requirements](01-requirements.md) remain the product authority. The new screenshots guide composition, materials and habitat density. They do not authorize human visitors, a third-person camera, drivable boats, multiplayer, sound, a larger city or a second beach. Keep the approximately 160 m beach, 5,700 required IDs, 40 optional valuables, eight zones, 18 sections, three service points and existing upgrade progression. Jetski remains deferred P30.

Preserve the working foundation: RunSession/ItemStore authority, stable ownership, physical placement and shelf claims, table/bin/bag records, once-only payment and rewards, permanent restoration, deterministic generation, save recovery and native distant-item batching. Repair their player-facing access and author the world around them. Do not replace them with a new interaction framework, entity framework, menu framework or asset pipeline.

## Work order and dependencies

The C numbers identify follow-up packets, not replacements for the original requirement IDs. Each packet below includes its bounded scope, likely file ownership and acceptance evidence. Keep implementation handoffs in `docs/handoffs/Cxx.md`; there is no need for another set of empty packet files or new test scenes.

| Packet | Outcome | Depends on | Findings / original packets |
|---|---|---|---|
| C00 | Current baseline, asset status and compatibility decisions | — | F09/F11/F12; P00/P01/P24/P29 |
| C01 | Normal controls can collect and carry every eligible target | C00 | F01/F03; P08/P09/P16/P17/P19 |
| C02 | Complete table/controller/pause flow | C01 | F02/F04 and prompt part of F12; P03/P12/P13/P22/P24/P27 |
| C03 | Ordered mixed bag, complete local save/result contracts | C02 | F05/F12; P09/P17/P20/P24 |
| C04 | Reference-led beach composition and finished destinations | C00 | F08; P05/P10/P25 |
| C05 | Complete catalog and natural, reachable clutter distribution | C01, C04 | F06/F08; P06/P07/P26 |
| C06 | Cohesive sunny shore, surface water and underwater treatment | C04 | F09; P18/P25 |
| C07 | Authored reef and visible local restoration | C04, C05, C06; required assets for final fidelity | F07/F09; P19/P20/P21/P25 |
| C08 | Final asset integration, interaction feel and pacing | C03, C05, C06, C07 | F09/F10/F12; P01/P04/P22/P26/P27 |
| C09 | Full player completion and exported release evidence | C08 | F10/F11; P28/P29 |

Recommended execution is C00 → C01 → C02 → C03 → C04 → C05 → C06 → C07 → C08 → C09. Asset identification/supply can progress while input repairs happen, but final reef acceptance depends on actual assets. This ordering does not require delegation. If work is later split, explicitly allocate shared files first: C01–C03 touch player/session input and inventory; C04–C07 share world scenes and anchors. Never edit those shared scenes concurrently without allocating ownership.

Profile representative views during C04–C08. C09 is the final hardware gate, not the first performance measurement after adding art.

## C00 — Establish an honest current baseline

**Deliverable:** one current status and asset register, with a declared engine/content/save baseline. Historical handoffs remain available but are clearly historical.

Work:

1. Record the current checkout, entry point, exact engine and export-template versions, renderer, content/generator versions and latest accepted evidence. The review used Godot 4.6.3; R01 and the original export instructions still name 4.6.1. Preserve the existing installation during this work. Reconcile the discrepancy explicitly before export, using prior user authorization if recorded; do not silently rewrite a locked requirement or call an engine mismatch accepted.
2. Refresh asset counts from `data/asset_manifest.json`. For each runtime role, identify its actual scene, source, status and replacement consumer. Use exact supplied asset / explicit substitute / provisional project art / missing. “No cube” is not proof of the requested asset or content family.
3. Split grouped requests where different consumers need different scenes: coral versus seaweed/seagrass, vacuum versus sand cleaner, flippers versus tank, and individual missing litter forms. Verify that supplying a requested replacement would actually reach the runtime node; a path in a register is insufficient.
4. Preserve existing saves before content changes. Visual replacements should keep existing wrapper paths where possible. Pure art edits must not gratuitously change item IDs, rules or generation.
5. Define the next content update policy before C04/C05 change anchors, definitions or generation. Default for this development pass: an explicit new content version for changed manifests, retained old saves with their compatible build recorded, and a readable incompatible-version message where migration is unsupported. Never silently regenerate or delete a player's existing run. Do not build a general migration framework. For C03's small schema additions, supply deterministic defaults for older snapshots where safe and keep existing validation.
6. Record how to reproduce the implementation from the current largely untracked working tree and locally supplied licensed art. Do not commit licensed assets, publish the repository or alter user changes as part of this planning task.

**Ownership:** `docs/plan/README.md`, current status in `docs/release-checks.md`, `docs/asset_requests.md`, `data/asset_manifest.json`; version constants and `scripts/core/save_service.gd` only if a concrete compatibility adjustment is required. Keep asset staging in the existing tools.

**Acceptance:** a reviewer can identify the active engine/content baseline, what genuinely renders, which art is still missing, and how an old save is treated without reconstructing every handoff. Check a copy of an existing save before/after an in-place art swap and a deliberately incompatible content version. Record results; no new general-purpose migration tests.

## C01 — Repair target eligibility and primary-action routing

**Deliverable:** the prompt, player input and authoritative transfer agree for each target state. This closes the completion blocker before further art polish.

Work:

1. Trace all callers of ItemStore collection, interactor eligibility and cleanup-target filtering before editing. Implement the existing tool matrix using item state: BURIED requires detection/reveal, ATTACHED requires knife, exposed ordinary/revealed/detached waste becomes eligible for stick pickup; standalone residue remains cloth-only. Valuables remain excluded from bulk tools.
2. Resolve aimed contextual actions before tool fallback. A clean reusable prop or disposal bag must enter hands with any equipped tool. Preserve aimed cloth cleaning and the explicit alternate carry path for dirty furniture; do not clean and carry on one click.
3. Make detector/knife prompts describe their current valid action. Revealing should not claim that another detector click collects if the intended next action is stick pickup. One mouse/controller press must not trigger two transfers.
4. Preserve click-only poking, continuous vacuum, bag/hand capacity, occlusion, buried visibility, rescue permanence and same-ID recovery. Check both empty and occupied hands: a tool becoming inactive while carrying a prop must not accidentally bypass eligibility or be required to collect a revealed find. Apply the rule once at the appropriate shared boundaries, not as unrelated exceptions for each item definition.

**Ownership:** `scripts/player/player.gd`, `interactor.gd`, `carry.gd`; `scripts/core/item_store.gd`; `scripts/tools/cleanup_target_query.gd`, `metal_detector.gd`, `rescue_knife.gd`, and their callers as needed. Item definitions should retain their access/category semantics.

**Playable evidence:** in `scenes/main.tscn`, purchase/equip or stage ownership of the real tools, then perform the actions through normal controls. Reveal a buried can, scrap and valuable; switch to stick and collect each. Cut an attachment with a full bag, make room, collect it, throw it, recover it, then repeat recovery after an underwater faint/save/load. Pick up a clean prop and a sealed bag with each of the six active tools. Confirm hidden finds, intact attachments and cloth residue cannot be swept up by other tools. Carry the recovered waste through table, sealing, container and collection and observe credit to its original section.

**Small regression:** extend an existing buried/rescue/interaction validation at the player-input boundary for the failing post-transition path, with a normal stick pickup as a positive control. Reuse the review probe's setup if useful, but report failure with a nonzero exit in an actual validation. Do not create a script per tool or replace play evidence with direct `try_collect` calls.

**Exit condition:** F01/F03 no longer reproduce; displayed actions are executable; ownership and capacity checks still pass. A staged near-complete run can finish by actually detecting, collecting, sorting and collecting the final special waste, with no direct service shortcut for those final actions.

## C02 — Finish table input, focus and pause/save access

**Deliverable:** mouse and controller can perform the entire station loop, including partial sealing and saving while sorting.

Work:

1. Use native Godot Control focus for Unload, bin controls, Seal, valuables and Exit. Establish a visible route from controls to the item grid and back. Consume D-pad/A as table navigation only when that context owns focus; focused buttons must receive their ordinary activation.
2. Keep mouse drag, select-bin-then-click and controller item selection on the same sorting service. Switching input device must preserve logical selection without double-sorting or losing a drag.
3. Route Pause/Start from sorting into the existing pause menu. Cancel only transient drag visuals. Freeze the singleplayer timer/oxygen through the existing pause mechanism. Resume restores the table camera/focus. Save and quit serializes all table/bin/tray contents; on load, preserve the original contract of returning to world view at the station with that state intact.
4. Derive detector/table/help prompts from the existing remapping/device-label mechanism. Replace raw item IDs with display names in ordinary inspection text. Keep IDs in diagnostics where useful.
5. Prevent close/resume/confirm from leaking into world pickup, throwing or a second menu action. Handle disconnect/reconnect through the existing pause path.

**Ownership:** `scripts/ui/sorting_view.gd`, `scenes/ui/sorting_overlay.tscn`, `scripts/stations/sorting_station.gd`, existing player input, pause/settings and `scripts/main.gd`. Reuse the existing menus; do not build a UI router or second focus system.

**Playable evidence:** controller-only from table entry: unload mixed waste/valuable → choose wrong bin → inspect and return/correct → seal a partial bin → sell a valuable → exit → carry/deposit/call collection. Then pause during a populated table, resume, save and quit, load and finish sorting. Repeat with remapped confirm/back and with mouse dragging. Record focus and state after each modal transition. Physical controller testing is required for final acceptance; synthetic input is useful for reproducing the specific interception regression.

**Small regression:** adapt the existing sorting/sealing check so its essential Unload/Seal actions use InputEventJoypadButton rather than emitting `pressed`. Reuse the same scenario to check that Pause opens during sorting; do not build a controller test harness.

**Exit condition:** F02/F04 and hardcoded prompts are resolved. The full table loop works without mouse assistance, including the eight-position output rack/full-bin retry path, with no lost or duplicate IDs.

## C03 — Complete inventory order and local save/result contracts

**Deliverable:** a mixed bag throws in collection order, saved checkpoints are clear, and the result receipt contains the promised local metadata.

Work:

1. Give bagged waste and valuables a single authoritative chronological order, either by reusing one existing list or a small persisted order field. Apply it to pickup, knife-to-bag, preview, throw, unload and faint/drop. Do not fix only the visual preview. Preserve shared capacity and the protected valuables tray/sale behavior.
2. Define older-save ordering honestly: old snapshots cannot reveal the true interleaving if it was never stored. Use a deterministic fallback for those snapshots and record the limitation; preserve exact order for all newly saved runs.
3. Add a minimal native manual-checkpoint picker. Proposed default: three named manual slots within each run, alongside autosave, showing timestamp and progress; Save and quit writes the selected slot. This completes the multiple-save UX without a file browser or save-management subsystem. Existing independent run selection remains.
4. Complete the local receipt with participant ID/count (one current participant), ruleset/relevant gameplay settings and faint count. Record metadata from authoritative state at the same immutable completion boundary. Defaults for old snapshots must not fabricate historical faint counts; use an explicit unavailable value if necessary. No leaderboard/network work.
5. Keep saved generation/content checks, A/B fallback, atomic finalization and failure UI intact. Do not weaken validation to load incompatible content.

**Ownership:** `scripts/core/run_state.gd`, `item_store.gd`, `progress_service.gd`, `save_service.gd`; inventory callers in sorting/swim; existing save/load/pause UI and `scripts/main.gd`.

**Acceptance:** collect waste → keys → waste and throw in reverse order, including after reload. Unload and faint leave no stale ordering entries. Two checkpoints in one run restore distinct states while another run stays independent. A failed save retains the previous valid generation and does not quit. Finish once, save/reload, rearrange a prop: original result metadata/payment remains unchanged. Extend the existing carry/save validations only for the new order/schema invariant.

## C04 — Compose the finished beach first

**Deliverable:** an inviting, navigable completed beach with the reference's spatial relationships, using the present scale and supplied assets. Establish this before tuning thousands of clutter positions.

### Authored direction

| Area | Concrete change | Gameplay constraint |
|---|---|---|
| Coast and landform | Shape a continuous shallow bay with a readable curve, tapered ends and background landforms masking exposed rectangular edges. Retain a recognizable wet-sand/shallow/deep-water progression. | Keep the 160 m playable length, valid shore exits, authored recovery points and all section footprints reachable. Do not merely crop a debug camera to hide broken edges. |
| Pier and lighthouse | Compose a strong pier line, a legible café/head and a lighthouse on its own landform with water separation. Tune proportions and silhouette together from beach level and elevated review views. | Preserve pier traversal/collision, service access and recovery. Distant lighthouse scenery need not become a new playable island. |
| Palms and skyline | Cluster palms around activity areas and frame sightlines. Vary height/spacing; keep the city lower in visual priority, with a promenade edge and a few distinct background silhouettes. | City stays non-enterable. Avoid an expensive new building system or dense palm collisions across carry paths. |
| Sports and sandplay | Compose court, lookout, boards, shade, sandcastles and small-prop storage as recognizable activity pockets with open walking lanes. | Preserve sorting-family claims, pickup visibility and two-handed routes. Decoration must not be confused with a required pickup. |
| Lounges and pier seating | Replace tight parallel storage rows with small chair/lounger/umbrella/cabana arrangements and deliberate gaps. Make completion look like a resort being restored. | Move the actual compatible destination slots, not only duplicate decorative furniture around them. Keep all 300 props placeable. |
| Service and storage | Integrate hut, shop, containers and racks with paths/props while retaining a distinct visible service identity. | Three stations and shop stay easy to find; large carried props and sealed bags fit through entrances without visual/physics snags. |

Preserve 96 small objects across the five shared-shelf families and the current 20 six-slot interchangeable sections unless a documented capacity change improves the design. Keep the feasibility check. Other destinations retain at least the required family capacities, and arbitrary compatible placement must remain possible. Preserve immutable home-section credit even when destinations move.

**Ownership:** `scenes/world/beach.tscn`, `scenes/world/zones/*.tscn`, existing lookout/café/shelter scenes; `scripts/world/coastline.gd`, `shore_dressing.gd`, `pier_visuals.gd`, `city_backdrop.gd`; world/slot/anchor resources where movement requires it. Keep one authoritative shoreline shared by visible sand/water and gameplay placement.

**Evidence:** reuse the main scene and existing traversal validation. Capture initial and restored states at the three review cameras, plus hut/pier navigation and one lounge view. For new before/after comparisons use the same seed, FOV, light, resolution and camera transforms. Record the accelerated setup for restored visual review separately from human completion. Walk/carry across the whole route, enter all huts, carry a large prop onto/off the pier and place representative items in every destination type.

**Exit condition:** no exposed world edges dominate normal playable views; coast, pier and lighthouse read as one composition; completed seating resembles usable groups; travel and sufficient compatible storage still work. Keep an elevated shot for authoring only, not a new game camera. Record a quick worst-view profile before proceeding.

## C05 — Finish the catalog and author the mess

**Deliverable:** every named required litter family exists logically, and the same quotas produce believable, reachable cleanup areas.

Work:

1. Add the missing straw, plastic wrap/bag, empty drink carton, fries, hamburger and sealed oil-container definitions. Reuse the existing definition resource and category rules: packaging/cartons PMD, loose food organic, sealed oil container general. Distinguish variants only where gameplay/art needs them. Keep missing visuals as explicit labelled coloured placeholders with asset requests; do not omit the logical type or quietly reuse an unrelated can as final art.
2. Redistribute existing family counts to include these definitions. Keep PMD 2,700 / organic 900 / general 1,200 / glass 600, plus 300 props and 40 optional valuables. Preserve 300 buried, 24 attached, 120 residue and 60 dirty as subsets, not additions. Reconcile section/zone/category totals and seed determinism under the declared content version.
3. Author anchors/masks for sparse singles, food/bin piles, sports litter, tidelines and submerged work sites. Use the original roughly 60/25/15 distribution as an art guide, not a demand for a new procedural placement framework. Break visible bands and grids while retaining collision-clear pickup poses and deterministic allocation.
4. Place starter content near the first station so the opening action-to-payment loop is legible. Keep the first small restoration section possible with starter tools. Maintain base-only affordability and existing required-access prerequisites; no tuning should make optional valuables or correct sorting necessary for access.
5. Fit buried dig surfaces, attachment sites and dense piles to the finished terrain. Check line of sight, loose-item clearance, air-limited routes and recovery positions. Keep required litter out of inaccessible rocks, under permanent props, inside foliage or behind the nonplayable backdrop.

**Ownership:** `data/items/*.tres`, `data/world/section_quotas.tres`, `spawn_anchors.tres`, `beach_01.tres`, existing generator/validator, zone anchor nodes and asset manifest. Keep near-body/distant rendering contracts intact for new definitions.

**Acceptance:** catalog totals and same-seed generation pass the existing validator; economy remains solvable after every reachable purchase set. Play the opening two starter-bag cycles, one dense cleanup patch, a buried route and a rescue route. Capture the new-run composition at the C04 cameras and inspect individual pile/shore sites on foot. Final 100-seed validation belongs to C09 after content settles, rather than being rerun for every visual tweak.

## C06 — Unify lighting, shore water and the underwater view

**Deliverable:** a warm, readable low-poly beach above water and convincing blue depth below, within Compatibility rendering.

Work:

1. Tune sun direction/energy, ambient colour, sand, palms and building materials together. Preserve a sunny fixed time of day. Reduce blown whites and harsh cyan contrast; retain form and shadow separation without excessive bloom.
2. Reshape/reposition the existing cloud forms so they read as layered low-poly clouds rather than dominating white rings. Keep the sky subordinate to the landmarks and working area.
3. Make shallow-to-deep colour and facet scale continuous with C04's shoreline. Refine thin shoreline foam, terrain/pier contact and distant-water continuity. Remove conspicuous bounded strips/seams from playable viewpoints without hiding objectives under opaque foam.
4. Tune underwater fog/colour/visibility and the underside of the water surface so submerged views read as water volume instead of an unbounded flat green plane with above-water silhouettes. Use effects actually supported by the current renderer. The reef needs readable near objects and obscured distant background, not heavy blur or chromatic fringing copied from a promotional image.
5. Keep visual waves cosmetic relative to stable gameplay water level, oxygen hysteresis and buoyancy. Check surface crossing in both directions; a lighting edit must not change breathing rules.

**Ownership:** `shaders/beach_water.gdshader`, `scripts/world/water_surface.gd`, `scenes/world/underwater_environment.tres`, main beach environment, existing materials and cloud placement. Do not switch renderer or introduce a second water system without measured evidence that the current approach cannot meet the target.

**Acceptance:** fixed-camera captures show warmer dimensional shore forms, a coherent shore/deep-water transition and blue underwater depth. Play pickup/scanning at bright sand, shaded hut, shoreline and submerged reef; names/outlines, air and category information remain readable at 720p/1080p. Check low/high FOV and surface crossings. Profile the most expensive water view before accepting shader changes.

## C07 — Build a reef worth restoring

**Deliverable:** layered habitat geometry with clear cleanup lanes and local, permanent rewards that match the plan.

Work:

1. Author a small number of distinct rock groups/ridges, sandy channels and depth changes in both existing reef areas. Use supplied compatible geometry where available; record unavailable rock forms rather than pretending a flat recoloured sand pile is finished reef art. Large shapes should frame foreground, middle distance and background from a swimmer's view.
2. Integrate coral, seaweed/seagrass and starfish at varied heights/densities. A04 needs separate identifiable plant/coral forms, not one generic replacement scene. Leave task silhouettes and swim/pickup routes clear. Degraded before-state and vibrant restored state should share the authored habitat, not be an empty plane followed by scattered cylinders.
3. Use the existing section/zone restoration latches. Completing a coral section should produce local colour/clarity changes and one or two bounded fish schools; completing the whole zone enables its additional turtle routes. Do not delay every visible fish reward until the entire reef zone is done.
4. Reconcile the land turtle route with the current balance specification. Default: enable the beach-to-water route in lounges as specified, placing the route to avoid chairs and service paths. Record any deliberate change to this tuning default rather than leaving contradictory documents.
5. Integrate A01 turtle, A02 reef fish, A03 starfish and A04 coral/plants into rescue/restoration/ambient consumers. Preserve release after the last cut, harmless animals, persistent freed state and original attachment IDs. Do not add damage, hunger, breeding, flocking simulation or wildlife objectives.
6. Add bounded shore life/plants for completed beach sections using available approved assets. A05 shore birds remain a visible asset dependency if unavailable; bird absence must not be relabelled complete because residue exists. Maintain population caps and no duplicate wildlife on reload.

**Ownership:** `scripts/world/reef_dressing.gd`, `restoration_section.gd`, `data/world/restoration_recipes.tres`, existing reef/zone scenes and `scripts/wildlife/*`; wrapper/replacement art through the existing manifest.

**Acceptance:** at a coral bed, collect and remove the final local waste via the station and observe a local reward before the rest of the zone finishes. Complete the zone and observe its additional route. Rescue an animal before restoration, reload, then finish restoration: no re-entanglement or duplicated animal. Remove a sorted prop afterward: progress may decrease but restored nature remains. Capture same-seed before/after underwater views and a short swimmer-level route showing rocks, tall plants, schools and turtles at multiple depths. The final model check remains open if A01–A04 are still provisional; do not block C01–C06 while waiting for them.

## C08 — Integrate final assets and tune the actual experience

**Deliverable:** complete art-role accounting, coherent hands/tools/feedback and observed early/mid/late gameplay pacing.

Work:

1. Close or explicitly retain the remaining grouped art requests: A06–A10 tools/swim gear, A11 attachments, A12–A14 missing litter, A15 stains, A16 service/portable-prop roles, A17 hands, plus any wildlife still open. Verify source provenance, scale, orientation, materials, collision/target size and runtime references. Split grouped roles as C00 requires. Keep provisional models labelled as such; screenshots cannot supply usable 3D models.
2. Fit grip/socket transforms for all tools, left-hand bag, two small props, one large prop and two disposal bags. Check FOV 70–110, movement, crouch, underwater and transitions so meshes do not obscure targets or clip across the camera. Reuse hand-rig/tween/animation facilities already present.
3. Tune existing hover, travel, ghost, pulse and group-sweep feedback. Reduce motion when requested, restore visual scales exactly and avoid cues on targets the input cannot act on. Do not add sound or new cinematic systems.
4. Exercise remapping, sensitivity/invert-Y, toggle movement, UI scale, category icons/text, controller focus and disconnect. Review HUD/table/shop/booklet/scanner/results at 720p, 1080p, 4K and a wide aspect ratio; evaluate normal TV viewing distance with a physical controller where available. Rendered screenshots establish layout, not human readability by themselves.
5. Play early, middle and nearly complete states. Record collection/rejection behavior, trips to stations, sorting corrections, full-table/rack delays, tool discovery, upgrade purchases and last-item search. Tune existing resource values or anchor placements only in response to observed problems. Preserve the 20-item starter bag, 10/60/unlimited air, 5,700 target and base-only access guarantee.

**Ownership:** existing asset manifest/wrappers, `scripts/player/hand_rig.gd`, hand/tool scenes, `scripts/ui/*`, relevant resource tuning. Do not add telemetry infrastructure: brief handoff notes and the game's existing counters are sufficient.

**Acceptance:** a clean controller run of the complete feature loop and a mouse run of drag/click sorting; clear readable feedback and comfortable target visibility. Record actual pacing observations and changes, then rerun economy only if prices/prerequisites/earnings changed. Separate “logic works with provisional art” from “final reference fidelity accepted.”

## C09 — Prove completion, performance and release integrity

**Deliverable:** a versioned Windows candidate with evidence that a player can finish it and that its performance/export claims are accurate.

Work and gates:

1. Reuse the existing short checks for ownership, exact payment, completion, content/seed determinism and save integrity. Run the existing 100-seed validator once against settled content, including edge-case seed input. Run the accelerated full-run check for service invariants, but label it accelerated.
2. Complete at least one human-paced 5,700-object run through normal controls, without debug collection, staged completion or direct button signals. Record seed/build, progression, all special content, final-item search, final collection/placement, results, continued roaming and post-finish save/reload. Resume over multiple sessions is acceptable and demonstrates persistence.
3. Perform the physical controller-only acceptance route from launch through every menu/tool/station, save/load and result continuation, without mouse assistance. Prefer doing the full human run on controller so this evidence overlaps; otherwise supplement it with a representative controller route including a normally reached near-finish save. Record which evidence was actually obtained.
4. Profile the exported Windows release at 1920×1080 defaults on GTX 980-class graphics and an 8 GB RAM system. Record CPU, GPU/VRAM, driver, OS and build. Existing defaults: 60 fps goal, p95 ≤18 ms, no recurring >50 ms gameplay stalls, aim ≤3 GB process resident memory and ≤3 GB dedicated GPU memory. A stronger development GPU or headless pass does not certify these budgets.
5. Measure full cold startup, dense piles, long shore views, 200-item table, maximum vacuum, restored reef, full-bag faint/recovery, save/load and nearly complete scanner use. Repeat after extended pickup/throw/save activity; record body/node/material counts and memory, not just average fps. Optimize only measured bottlenecks using existing batching, visibility and population limits first.
6. Export with the agreed engine/template version. Test a fresh Windows profile/machine without editor or .NET dependencies. Confirm all runtime art/catalog references are packed and source packages, nested conversion projects, review images, tests and tools are excluded. Exercise first save, several checkpoints/runs, damaged newest generation and failed-write UI using isolated test data; retain genuine player saves.
7. Update current release/performance records and link the final build and actual handoff evidence. Preserve historical results but do not present them as the new build's certification. If hardware, human testing or exact art is unavailable, mark that gate unverified/blocked with the specific remaining action.

**Ownership:** existing validation scripts and export preset only where a demonstrated gap requires a small change; `docs/performance.md`, `docs/release-checks.md`, `docs/handoffs/C09.md`. No release automation framework, new test runner or speculative cross-platform rewrite.

**Exit condition:** no known completion, ownership, payment or save failures; human completion and controller flow demonstrated; final art status truthful; exported target-hardware and fresh-machine checks passed. Optional jetski is considered only after these gates and a separate decision to implement it.

## Evidence and handoff rule for all packets

Follow [AGENTS.md](../../AGENTS.md) and [verification guidance](05-verification.md): acceptance behaviors above are not instructions to create one test per row. Reuse the main game and existing development scenes. Keep a small written regression only for a real invariant or difficult edge case. Do not build mocks, fixtures, discovery infrastructure or a large suite.

Each handoff records: exact build/content/engine and seed; setup (including any staged ownership/state); device/bindings; actions performed through gameplay; observed result and counters; screenshots/logs where useful; commands actually executed; unresolved gaps. Explicitly distinguish source inspection, direct service checks, injected input, rendered captures and human play. Record whether target hardware and final assets were available.

For visual acceptance, use the review's three fixed views plus one short first-person walk/swim route. Compare both new-run and restored states, at matched camera/settings and the same seed where distribution is being assessed. Keep culling behavior in mind: a distant screenshot cannot verify 5,700 visible items. Screenshot alignment is achieved through composition, silhouette, colour, depth and restoration quality, not by copying visitors or hiding gameplay under post-processing.

## What can be called complete

| Claim | Required evidence |
|---|---|
| Core implementation repaired | C01–C03 input flows work and authoritative state/payment/save checks remain sound. |
| Beach and reef visually aligned | C04–C08 pass matched rendered/first-person review in new and restored states; required final assets are actually integrated or remaining limitations are explicitly accepted. |
| Full release ready | C09 gates pass on the agreed build; no completion/save blockers or unverified target-hardware claim is concealed. |

The immediate next implementation packet is **C00, then C01**. The highest-value visual packet is **C04**; the reef's critical art dependency is **A01–A04**. There is no reason to rebuild the systems that already preserve ownership, payment and progress correctly.
