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
| C04 | Reference-led beach composition, structural reef and finished destinations | C00 | F08; P05/P10/P25 |
| C05 | Complete catalog and natural, reachable clutter distribution | C01, C04 | F06/F08; P06/P07/P26 |
| C06 | Cohesive sunny shore, surface water and underwater treatment | C04 | F09; P18/P25 |
| C07 | Authored reef and visible local restoration | C04, C05, C06; required assets for final fidelity | F07/F09; P19/P20/P21/P25 |
| C08 | Final asset integration, interaction feel and pacing | C03, C05, C06, C07 | F09/F10/F12; P01/P04/P22/P26/P27 |
| C09 | Full player completion and exported release evidence | C08 | F10/F11; P28/P29 |

Recommended execution is C00 → C01 → C02 → C03 → C04 → C05 → C06 → C07 → C08 → C09. Asset identification/supply can progress while input repairs happen, but final reef acceptance depends on actual assets. This ordering does not require delegation. If work is later split, explicitly allocate shared files first: C01–C03 touch player/session input and inventory; C04–C07 share world scenes and anchors. Never edit those shared scenes concurrently without allocating ownership.

Profile representative views during C04–C08. C09 is the final hardware gate, not the first performance measurement after adding art.

C04 establishes the coast **and structural reef geometry before C05 fits clutter to it**. C07 adds habitat dressing and restoration to that geometry. Any later change to terrain, collision, destinations or dense vegetation reopens the affected C05 access checks; packet numbering does not make earlier evidence valid after its inputs change.

## C00 — Establish an honest current baseline

**Deliverable:** one current status and asset register, with a declared engine/content/save baseline. Historical handoffs remain available but are clearly historical.

Work:

1. Record the current checkout, entry point, exact engine and export-template versions, renderer, content/generator versions and latest accepted evidence. The review used Godot 4.6.3; R01 and the original export instructions still name 4.6.1. Preserve the existing installation during this work. Reconcile the discrepancy explicitly before export, using prior user authorization if recorded; do not silently rewrite a locked requirement or call an engine mismatch accepted.
2. Refresh asset counts from `data/asset_manifest.json`. For each runtime role, identify its actual scene, source, status and replacement consumer. Use exact supplied asset / explicit substitute / provisional project art / missing. “No cube” is not proof of the requested asset or content family.
3. Split grouped requests where different consumers need different scenes: coral versus seaweed/seagrass, vacuum versus sand cleaner, flippers versus tank, and individual missing litter forms. Verify that supplying a requested replacement would actually reach the runtime node; a path in a register is insufficient.
4. Preserve existing saves before content changes. Visual replacements should keep existing wrapper paths where possible. Pure art edits must not gratuitously change item IDs, rules or generation.
5. Define the next content update policy before C04/C05 change anchors, definitions or generation. Default for this development pass: an explicit new content version for changed manifests, retained old saves with their compatible build recorded, and a readable incompatible-version message where migration is unsupported. Never silently regenerate or delete a player's existing run. Do not build a general migration framework. For C03's small schema additions, supply deterministic defaults for older snapshots where safe and keep existing validation.
6. Establish a reproducible implementation baseline before C01. The documentation commit alone is not that baseline: `scripts/`, `scenes/`, `data/`, `shaders/`, `tools/`, existing checks/handoffs and the active `project.godot` were largely untracked at review time. Preserve the working tree, then version the project-owned implementation, staging manifest/tool, import boundaries, runtime configuration and applicable handoffs on the existing repository. Inspect an explicit file list before committing; exclude licensed source/staged art, caches, saves and exports. Do not blanket-add the working tree or change repository visibility. Record the baseline commit and how an authorized checkout supplies its local licensed source.
7. Include reconciled requirement documents in the same handoff: R02 and P05 use the confirmed approximately 160 m beach, and the balance table includes cloth → knife → detector → tank, with vacuum/sand cleaner gated behind tank. These changes existed only locally at review time. C00 must check the committed versions, not infer consistency from files on the author's machine. Engine reconciliation remains the separate step above.
8. From a separate checkout of the baseline commit, supply the licensed source at the documented path, regenerate staged art with the existing tool, import and launch `scenes/main.tscn`, and run the existing small boot/asset/state check. Record the exact commands, source prerequisites and observed result in `docs/handoffs/C00.md`. Generated wrapper scenes and project-owned presentation assets must either be tracked without embedded vendor content or reproduced by the staging tool. A checkout that depends on a missing local wrapper does not pass. Retain a compatible build/commit for pre-update saves before advancing content versions.

**Ownership:** `docs/plan/README.md`, reconciled requirements/world/balance/P05 documents, current status in `docs/release-checks.md`, `docs/asset_requests.md`, `data/asset_manifest.json`, the explicit project-owned baseline file list and existing staging/import configuration; version constants and `scripts/core/save_service.gd` only if a concrete compatibility adjustment is required. Keep asset staging in the existing tools.

**Acceptance:** a reviewer can identify the active engine/content baseline, what genuinely renders, which art is still missing, and how an old save is treated without reconstructing every handoff. A separate checkout of the recorded commit launches the actual game after documented local asset staging; the committed authority documents agree with the completion plan. Missing source art or implementation files leave C00 open and must be named. Check a copy of an existing save before/after an in-place art swap and a deliberately incompatible content version. Record results; no new general-purpose migration tests. This planning revision does not itself claim C00 or the implementation baseline complete.

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

**Deliverable:** an inviting, navigable completed beach with the reference's spatial relationships, using the present scale and supplied assets, plus the structural reef surfaces to which C05 will fit objectives. Establish this before tuning thousands of clutter positions.

### Authored direction

| Area | Concrete change | Gameplay constraint |
|---|---|---|
| Coast and landform | Shape a continuous shallow bay with a readable curve, tapered ends and background landforms masking exposed rectangular edges. Retain a recognizable wet-sand/shallow/deep-water progression. | Keep the 160 m playable length, valid shore exits, authored recovery points and all section footprints reachable. Do not merely crop a debug camera to hide broken edges. |
| Pier and lighthouse | Compose a strong pier line, a legible café/head and a lighthouse on its own landform with water separation. Tune proportions and silhouette together from beach level and elevated review views. | Preserve pier traversal/collision, service access and recovery. Distant lighthouse scenery need not become a new playable island. |
| Palms and skyline | Cluster palms around activity areas and frame sightlines. Vary height/spacing; keep the city lower in visual priority, with a promenade edge and a few distinct background silhouettes. | City stays non-enterable. Avoid an expensive new building system or dense palm collisions across carry paths. |
| Sports and sandplay | Compose court, lookout, boards, shade, sandcastles and small-prop storage as recognizable activity pockets with open walking lanes. | Preserve sorting-family claims, pickup visibility and two-handed routes. Decoration must not be confused with a required pickup. |
| Lounges and pier seating | Replace tight parallel storage rows with small chair/lounger/umbrella/cabana arrangements and deliberate gaps. Make completion look like a resort being restored. | Move the actual compatible destination slots, not only duplicate decorative furniture around them. Keep all 300 props placeable. |
| Service and storage | Integrate hut, shop, containers and racks with paths/props while retaining a distinct visible service identity. | Three stations and shop stay easy to find; large carried props and sealed bags fit through entrances without visual/physics snags. |
| Structural reef | Establish both reef areas' large rock groups, sandy channels, floor heights and collision now. Reserve plant beds and animal routes around those channels. | C05 must receive the actual surfaces/exclusions used by the final habitat. Missing final rock art may use explicitly provisional structural blockout with conservative bounds; replacement cannot silently enlarge those bounds. |

Preserve 96 small objects across the five shared-shelf families and the current 20 six-slot interchangeable sections unless a documented capacity change improves the design. Keep the feasibility check. Other destinations retain at least the required family capacities, and arbitrary compatible placement must remain possible. Preserve immutable home-section credit even when destinations move.

### Layout defaults and first representative areas

Use this annotated layout as the starting design. Coordinates are metres in the existing world convention: X runs along the 160 m beach, +Z points toward the sea, Y is height. Ranges and proportions below are authoring defaults, not new locked requirements. Retain the eight zone IDs, 18 section IDs and native Synty prop scale. Record final coordinates and any justified deviations in C04; never shrink props or change quotas to fit the drawing.

```text
                         INLAND / -Z
   Thin skyline behind palms; non-enterable promenade (around Z -40)
   Arrival       Sports          Lounges          Sandplay       Pier
   X -80..-55    -55..-30        -30..5            5..35          35..80
   S1 (-69,-8)                   S2 + shop (6,-8)                 S3 (59,-5)
   -------- connected carrying route around Z 7; 3 m clear target --------
   small activity pockets / seating groups / gaps / lifeguard landmarks
   \                 curved bay, centre recedes inland                /
    \_________________ continuous wet sand _________________________/
      cyan shallows       West reef       East reef       pier -> café
      open shore exits    X -10..24       X 26..64         lighthouse island
                          Z 85..140      Z 100..155        beside outer pier
                          SEA / +Z
```

| Element | Starting placement / proportion | Acceptance from player and elevated views |
|---|---|---|
| Bay | Keep X within approximately -80..80; begin with shore Z 30–36 near the middle and 45–55 near the ends. Taper sand into background landforms at both ends. | The shore visibly bends in the wide view; no rectangular sand/backdrop cut is visible from the playable shore route. The city reads inland, not as a slab floating in open sea. |
| Pier and lighthouse | Start the pier near X 58..64 at its shore connection; target about 35–45 m of deck beyond that connection and a café/head about 12–18 m wide. Start the island near X 72, Z 100, then fit its landform to the actual tower base. | Pier connects shore to a readable destination without dominating the bay. A visible band of water separates lighthouse landform and mainland from the along-shore camera. No water gap is required between the tower and a deliberately connected pier landing. |
| Activity pockets | Sports: court, lookout and boards; lounges: small shaded seating groups; sandplay: sandcastles and small-prop storage. Frame pockets with uneven groups of 3–5 palms; retain open passages. | At eye height each pocket has an identifiable purpose and a nearby usable destination. Neither continuous furniture rows nor additional skyline detail substitutes for that purpose. |
| Reef structure | In each reef area start with three irregular rock groups: foreground framing, middle-distance habitat and a rear ridge. Use roughly 1–2.5 m relief above the local bed and 2–3 m clear sandy channels; retain reachable surface exits. | Swimmer views contain overlapping large forms and a visible route between them. The bed is not an uninterrupted flat plane. Actual player/large-prop bounds and pickup visibility take precedence over nominal channel width. |

First complete one approximately 8 × 8 m lounge arrangement with real destination slots and one approximately 12 × 16 m west-reef pocket with structural geometry. Capture both against the [reference rubric](#reference-rubric-and-visual-acceptance) before repeating the layout elsewhere. C04 accepts their composition, scale and access; C06/C07 finish lighting, plants and animals on those same pockets before repeating the treatment. Provisional art cannot pass final model fidelity. Record a pass/fail reason for every applicable rubric row; unresolved failures remain in the owning packet.

### Build seating groups with existing placement pools

`PlacementSlot.local_slot_transform()` currently creates a row/grid. Moving a 54-chair pool does not turn it into seating groups. Replace large dedicated pools with smaller positioned/rotated `PlacementSlot` nodes in the existing zone scenes. Reuse native transforms and the existing placement service; do not add a layout generator, per-item transform framework or decorative duplicate chairs.

Default capacity allocation below preserves the current surplus above the 70 chairs / 50 loungers / 20 parasols required. These are **destination capacities**, not changes to home-zone quotas; a compatible prop can still be placed in any zone.

| Zone | Chair slots (2 per pool) | Lounger slots (2 per pool) | Parasol slots (1 per pool) |
|---|---:|---:|---:|
| Arrival | 8 | 4 | 4 |
| Sports | 8 | 0 | 4 |
| Lounges | 44 | 40 | 14 |
| Sandplay | 0 | 0 | 2 |
| Pier | 12 | 10 | 0 |
| **Capacity** | **72** | **54** | **24** |

Example within the representative lounge pocket: one chair-pair pool centred at local `(0,0,-2)`, spacing 1.4 m; one lounger-pair pool at `(0,0,2)`, spacing 1.8 m; one parasol pool at `(2.8,0,0)`. Rotate each pool so actual prop fronts face the water or the intended conversation group. Adjust distances from rendered mesh/collision bounds, retaining at least a 2 m clear approach and the 3 m main carrying route. Alternate these groups with lounger-only and shaded-chair groups rather than repeating one tile across the beach.

Assign unique descriptive pool IDs, for example `row:lounges:chairs:01`; derived slot IDs remain `pool_id:000`, `pool_id:001`. Preserve IDs for unchanged pools. Splitting/reassigning pools changes save locations: include the layout change in C00's content-version policy and keep the compatible prior build; never accept old slot records against missing/new pools. Update `beach_01.tres` capacity declarations if final capacities change, and leave the 20 shared six-slot shelves and their feasibility checks intact.

Populate all 300 required props through the existing accelerated setup, then inspect each destination family for intersecting occupied meshes, covered targets and blocked walkways. Also exercise normal pickup, ghost placement, throw capture, removal and reload in the representative group. Spare slot counts alone do not prove usable capacity. Update old coordinate/mesh-count assertions only where the authored layout intentionally changed; retain traversal, collision, ownership and capacity checks.

**Ownership:** `scenes/world/beach.tscn`, `scenes/world/zones/*.tscn`, existing lookout/café/shelter scenes; `scripts/world/coastline.gd`, `shore_dressing.gd`, `pier_visuals.gd`, `city_backdrop.gd`, structural `reef_dressing.gd`; world/slot/anchor resources where movement requires it. Keep one authoritative shoreline shared by visible sand/water and gameplay placement. Reuse `tests/validate_pier_art.gd` for the [capture procedure](#repeatable-capture-procedure), with only the small changes needed for reproducible visual evidence.

**Evidence:** reuse the main scene and existing traversal validation. Follow the capture procedure for the three review cameras, an along-shore player view and the representative lounge/reef pockets, plus hut/pier navigation. For new before/after comparisons use the same seed, FOV, light, resolution and camera transforms. Record the accelerated setup for restored visual review separately from human completion. Walk/carry across the whole route, enter all huts, carry a large prop onto/off the pier and place representative items in every destination type.

**Exit condition:** the composition rows of the reference rubric pass in the representative areas and the complete layout; no exposed world edges dominate normal playable views; coast, pier and lighthouse read as one composition; completed seating resembles usable groups; travel and sufficient compatible storage still work. Both reef areas have their structural surfaces, collision and exclusions ready for C05. Record the final layout/pool allocation and a quick worst-view profile before proceeding. Keep an elevated shot for authoring only, not a new game camera.

## C05 — Finish the catalog and author the mess

**Deliverable:** every named required litter family exists logically, and the same quotas produce believable, reachable cleanup areas.

Work:

1. Add the missing straw, plastic wrap/bag, empty drink carton, fries, hamburger and sealed oil-container definitions. Reuse the existing definition resource and category rules: packaging/cartons PMD, loose food organic, sealed oil container general. Distinguish variants only where gameplay/art needs them. Keep missing visuals as explicit labelled coloured placeholders with asset requests; do not omit the logical type or quietly reuse an unrelated can as final art.
2. Redistribute existing family counts to include these definitions. Keep PMD 2,700 / organic 900 / general 1,200 / glass 600, plus 300 props and 40 optional valuables. Preserve 300 buried, 24 attached, 120 residue and 60 dirty as subsets, not additions. Reconcile section/zone/category totals and seed determinism under the declared content version.
3. Author anchors/masks for sparse singles, food/bin piles, sports litter, tidelines and submerged work sites. Use the original roughly 60/25/15 distribution as an art guide, not a demand for a new procedural placement framework. Break visible bands and grids while retaining collision-clear pickup poses and deterministic allocation.
4. Place starter content near the first station so the opening action-to-payment loop is legible. Keep the first small restoration section possible with starter tools. Maintain base-only affordability and existing required-access prerequisites; no tuning should make optional valuables or correct sorting necessary for access.
5. Fit buried dig surfaces, attachment sites and dense piles to C04's finished coast and structural reef terrain/collision. Check line of sight, loose-item clearance, air-limited routes and recovery positions, including exclusions reserved for restoration plants. Keep required litter out of inaccessible rocks, under permanent props, inside foliage or behind the nonplayable backdrop. Record which terrain/layout revision these checks cover so later C07/C08 changes can reopen the affected checks.

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
6. Use the rubric's colour/lighting defaults on the C04 beach and reef pockets first. Record the actual environment/material values and matched captures before applying them across the world. Tune material response and shadow separation together; increasing brightness or saturating a flat water plane is not sufficient acceptance.

**Ownership:** `shaders/beach_water.gdshader`, `scripts/world/water_surface.gd`, `scenes/world/underwater_environment.tres`, main beach environment, existing materials and cloud placement. Do not switch renderer or introduce a second water system without measured evidence that the current approach cannot meet the target.

**Acceptance:** fixed-camera captures show warmer dimensional shore forms, a coherent shore/deep-water transition and blue underwater depth. Play pickup/scanning at bright sand, shaded hut, shoreline and submerged reef; names/outlines, air and category information remain readable at 720p/1080p. Check low/high FOV and surface crossings. Profile the most expensive water view before accepting shader changes.

## C07 — Build a reef worth restoring

**Deliverable:** layered habitat geometry with clear cleanup lanes and local, permanent rewards that match the plan.

Work:

1. Dress the rock groups/ridges, sandy channels and depths established in C04. Use supplied compatible geometry where available; record unavailable rock forms rather than pretending a flat recoloured sand pile is finished reef art. Keep C04's collision/exclusion bounds when replacing provisional geometry. Large shapes should frame foreground, middle distance and background from a swimmer's view; finish the representative west-reef pocket against the rubric before repeating the treatment in both reef areas.
2. Integrate coral, seaweed/seagrass and starfish at varied heights/densities. A04 needs separate identifiable plant/coral forms, not one generic replacement scene. Leave task silhouettes and swim/pickup routes clear. Degraded before-state and vibrant restored state should share the authored habitat, not be an empty plane followed by scattered cylinders.
3. Use the existing section/zone restoration latches. Completing a coral section should produce local colour/clarity changes and one or two bounded fish schools; completing the whole zone enables its additional turtle routes. Do not delay every visible fish reward until the entire reef zone is done.
4. Reconcile the land turtle route with the current balance specification. Default: enable the beach-to-water route in lounges as specified, placing the route to avoid chairs and service paths. Record any deliberate change to this tuning default rather than leaving contradictory documents.
5. Integrate A01 turtle, A02 reef fish, A03 starfish and A04 coral/plants into rescue/restoration/ambient consumers. Preserve release after the last cut, harmless animals, persistent freed state and original attachment IDs. Do not add damage, hunger, breeding, flocking simulation or wildlife objectives.
6. Add bounded shore life/plants for completed beach sections using available approved assets. A05 shore birds remain a visible asset dependency if unavailable; bird absence must not be relabelled complete because residue exists. Maintain population caps and no duplicate wildlife on reload.
7. Refit affected C05 anchors whenever geometry, collision or dense foliage changes. Recheck real pickup rays, buried reveal surfaces, rescue attachments, faint-drop recovery and surface routes in initial and restored states. Finish a section while its neighbor still contains required waste, then collect that remaining waste through the normal controls: returning plants/animals must not hide or block it. If depths/routes change accessible income, rerun the existing economy proof and the relevant equipment/air route even when prices are unchanged. Quota/100-seed validation does not perform these physical-access checks.

**Ownership:** `scripts/world/reef_dressing.gd`, `restoration_section.gd`, `data/world/restoration_recipes.tres`, existing reef/zone scenes and `scripts/wildlife/*`; wrapper/replacement art through the existing manifest.

**Acceptance:** at a coral bed, collect and remove the final local waste via the station and observe a local reward before the rest of the zone finishes. Complete the zone and observe its additional route. Rescue an animal before restoration, reload, then finish restoration: no re-entanglement or duplicated animal. Remove a sorted prop afterward: progress may decrease but restored nature remains. Capture same-seed before/after underwater views and a short swimmer-level route showing rocks, tall plants, schools and turtles at multiple depths. Pass the reef rubric and refreshed access checks, including the restored/unrestored boundary. The final model check remains open if A01–A04 are still provisional; do not block C01–C06 while waiting for them.

## C08 — Integrate final assets and tune the actual experience

**Deliverable:** complete art-role accounting, coherent hands/tools/feedback and observed early/mid/late gameplay pacing.

Work:

1. Close or explicitly retain the remaining grouped art requests: A06–A10 tools/swim gear, A11 attachments, A12–A14 missing litter, A15 stains, A16 service/portable-prop roles, A17 hands, plus any wildlife still open. Verify source provenance, scale, orientation, materials, collision/target size and runtime references. Split grouped roles as C00 requires. Keep provisional models labelled as such; screenshots cannot supply usable 3D models.
2. Fit grip/socket transforms for all tools, left-hand bag, two small props, one large prop and two disposal bags. Check FOV 70–110, movement, crouch, underwater and transitions so meshes do not obscure targets or clip across the camera. Reuse hand-rig/tween/animation facilities already present.
3. Tune existing hover, travel, ghost, pulse and group-sweep feedback. Reduce motion when requested, restore visual scales exactly and avoid cues on targets the input cannot act on. Do not add sound or new cinematic systems.
4. Exercise remapping, sensitivity/invert-Y, toggle movement, UI scale, category icons/text, controller focus and disconnect. Review HUD/table/shop/booklet/scanner/results at 720p, 1080p, 4K and a wide aspect ratio; evaluate normal TV viewing distance with a physical controller where available. Rendered screenshots establish layout, not human readability by themselves.
5. Play early, middle and nearly complete states. Record collection/rejection behavior, trips to stations, sorting corrections, full-table/rack delays, tool discovery, upgrade purchases and last-item search. Tune existing resource values or anchor placements only in response to observed problems. Preserve the 20-item starter bag, 10/60/unlimited air, 5,700 target and base-only access guarantee.

**Ownership:** existing asset manifest/wrappers, `scripts/player/hand_rig.gd`, hand/tool scenes, `scripts/ui/*`, relevant resource tuning. Do not add telemetry infrastructure: brief handoff notes and the game's existing counters are sufficient.

**Acceptance:** a clean controller run of the complete feature loop and a mouse run of drag/click sorting; clear readable feedback and comfortable target visibility. Record actual pacing observations and changes, then rerun economy if prices/prerequisites/earnings or equipment-dependent content accessibility changed. Recheck affected pickup, placement, collision and dive routes after mesh/anchor changes. Separate “logic works with provisional art” from “final reference fidelity accepted.”

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

### Reference rubric and visual acceptance

The saved [image 1 — beach](review-evidence/reference-01-beach.png), [image 2 — aerial](review-evidence/reference-02-aerial.png) and [image 3 — reef](review-evidence/reference-03-reef.png) are the exact supplied references. Apply the responsibilities below rather than copying every object pictured. Human visitors, vehicle play, branding, blur and chromatic fringes are not acceptance requirements.

| Reference / owner | Pass criteria | Failure that must remain open |
|---|---|---|
| Image 1: beach-level composition / C04 | Along-shore player view contains foreground beach props/palm framing, a recognizable middle-distance activity pocket, and pier/lighthouse or another major destination beyond it. An open walking lane connects the scene. | Empty sand fills the lower half with all activity compressed into a distant horizontal band; more city detail does not repair it. |
| Image 2: bay and skyline / C04 | Elevated view shows a continuous curved bay, pier connected to shore and café/head, distinct lighthouse landform, clusters of activity separated by passages, and a narrow inland city/promenade layer. | Exposed rectangular world backing, giant uniform shallow-water strip, pier dwarfing activity areas, or repetitive furniture/palm rows. |
| Images 1–2: completed destinations / C04 | Actual sorted props form usable seating, shade, board/mooring and sandplay groups. Fully populated destinations retain approaches and access to each occupied slot. | Decorative duplicates conceal unchanged storage rows, props interpenetrate when filled, or restoration blocks a destination. |
| Images 1–2: warm shore and dimensional light / C06 | Pale warm sand, cream sunlit faces, readable cooler shadows, green palms and saturated prop accents remain distinct. Starting palette guides: sand `#E8CF91`, foam `#F4F5E8`, shallows `#53C5CE`, offshore `#238DB6`. These are appearance guides, not identical albedo/shader assignments. Retain one angled sunny key light, visible contact shadows and enough ambient fill to read shaded props. | Clipped white clouds/sand, neon cyan shade, black unreadable hut interiors, or colour changes without shape/shadow separation. Do not require a bloom effect. |
| Images 1–2: water / C06 | Thin foam follows land/pier contact; visible seabed in the shallows transitions continuously to deeper blue with smaller distant facets. | Straight bounded colour strips, a visible ocean seam, opaque foam hiding litter, or breathing behavior changing with cosmetic waves. |
| Image 3: habitat structure / C04 then C07 | Swimmer view shows near rock framing, middle-distance coral/plant groups at low/medium/tall heights, a sandy channel and a rear ridge softened by depth. Use roughly 0.2–0.5 m ground cover, 0.6–1.2 m coral and 1.5–2.5 m taller plants as initial scale ranges, adjusted to supplied assets. | Flat exposed bed, equal-height cylinders, a regular planting grid, or one generic mesh representing every coral/plant role. |
| Image 3: blue depth and restoration / C06–C07 | Near litter and outlines remain readable; distant geometry progressively loses contrast into blue water. Restored coral adds pink/lilac/green accents, local schools occupy more than one depth and turtle routes cross open habitat. Degraded state retains the same underlying rock/plant structure. | Green flat horizon with distant boats/buildings clearly visible underwater; empty before-state followed by spawned cylinders; all animal rewards deferred until whole-zone completion. |

Record each row as pass, fail or blocked with capture filenames and the observed reason. An unavailable model is blocked final art, not a visual pass. A renderer limitation needs a documented compatible alternative and another capture. Save the actual light/material/fog settings used; hex guides and object presence alone are not evidence. The final first-person route must keep these qualities between the fixed cameras, with HUD and hands visible.

### Repeatable capture procedure

**Existing tooling, not new acceptance evidence:** `tests/validate_pier_art.gd` already supports `--capture` / `--goal`, uses seed `restoration-fixture`, and writes under `docs/handoffs/images/`. `tests/validate_full_run.gd` uses `full-run-integration` and isolated saves under `user://test_runs/full_run`; its last saved checkpoint has the final chair held (5,699), although its final live state is 5,700. Do not use those two outputs as a matched before/after pair or assume the last checkpoint is fully placed. The previous review's SubViewport captures document their settings but do not provide a reusable capture entry point.

Before accepting C04, extend the existing pier capture script only enough to produce the paired review set. Keep the current validation entry point and flags working. Required small additions: a `--review-pair` option with `--review-output` for the packet's output directory; one fixed seed `full-run-integration` for both states; a 1920×1080 SubViewport/FOV 85; and the shared camera table below. Reuse the accelerated completion procedure from the existing full-run check for the restored state, preserving its invariant/payment checks; extract only the needed existing setup if sharing is necessary. Do not copy another completion engine or build a capture framework. In the live restored state, ensure all 300 props are placed, all 5,400 waste collected, restoration applied and invariants clean before capture. Continue roaming through the existing results flow so the tree is unpaused before waiting for streaming/physics frames. Use only isolated test saves. Label this accelerated visual setup throughout.

| Capture name | Position → target (world metres) | Purpose |
|---|---|---|
| `aerial` | `(-15,65,135) → (0,0,0)` | Original wide baseline and complete bay composition. |
| `sports-eye` | `(-45,2.1,32) → (-43.75,1.7,12)` | Original inland-facing activity baseline. This does not replace the along-shore view. |
| `reef` | `(2.5,-1.25,101) → (2.5,-2.25,107.5)` | Original swimmer-level habitat baseline. |
| `along-shore` | Start `(-65,2.1,45) → (60,6,72)` | Water/land relationship, activity framing, pier and lighthouse at player height. Ground the final camera on reachable shore at normal eye height. |
| `lounge-pocket` | Approximately 6 m from C04's representative group centre, at normal player eye height, facing toward water | Actual occupied seating and its approach; record final numeric position/target before capturing the pair. |

If a redesigned landform makes a camera obstructed/submerged or outside the intended pocket, record that fact and choose one new transform for **both** states. Retain the historical images and distinguish the new framing from a camera-matched comparison with the historical build. Never move only the restored-state camera to make it look better. For every pair keep seed/content, transforms, FOV, sun, resolution and culling settings identical; only objective/restoration state changes. Record one fixed underwater environment per state if restoration intentionally changes it.

Place the real player/streaming origin at each view, disable movement and automatic swim updates only while fixed captures run, and apply the appropriate above/underwater environment. Hide UI/hands for composition captures only. Wait at least 180 physics frames and a rendered frame; confirm nearby item views are populated before saving. Distant culling remains enabled. Write `<view>-initial.png` and `<view>-restored.png` plus `capture-log.txt` to `docs/handoffs/images/C04/` (later packets use their own Cxx directory). Log build/content/engine, seed, camera/settings, state counts and zero/nonzero invariant errors. Failed setup, missing captures or invariant errors return a nonzero exit. Retain a HUD-visible walk/swim recording separately using normal controls.

PowerShell command contract from the project root, **to be implemented and exercised by C04**; `--review-pair` is not available merely because this plan names it. Use the executable agreed in C00; this example points to the review's existing installation without resolving R01 on its own:

```powershell
$beachGodot = 'C:/Users/Home/Downloads/Godot_v4.6.3-stable_win64/Godot_v4.6.3-stable_win64_console.exe'
& $beachGodot --headless --path . --script res://tests/run_checks.gd
& $beachGodot --path . --script res://tests/validate_pier_art.gd -- --review-pair --review-output=res://docs/handoffs/images/C04
```

Run captures with rendering enabled. Record each command's exit code. Before that addition, the existing `-- --capture --goal` flags can regenerate their historical views but cannot satisfy paired acceptance. C04 handoff must replace this pending status with the actual working command, exact output paths and inspected results; no separate test scene, golden-image test suite or pixel-diff threshold is required.

## What can be called complete

| Claim | Required evidence |
|---|---|
| Core implementation repaired | C01–C03 input flows work and authoritative state/payment/save checks remain sound. |
| Beach and reef visually aligned | C04–C08 pass matched rendered/first-person review in new and restored states; required final assets are actually integrated or remaining limitations are explicitly accepted. |
| Full release ready | C09 gates pass on the agreed build; no completion/save blockers or unverified target-hardware claim is concealed. |

The immediate next implementation packet is **C00, then C01**. The highest-value visual packet is **C04**; the reef's critical art dependency is **A01–A04**. There is no reason to rebuild the systems that already preserve ownership, payment and progress correctly.
