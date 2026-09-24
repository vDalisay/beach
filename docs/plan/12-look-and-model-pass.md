# Look review and low-poly model pass

Written 24 September 2026 against gameplay `4006dda` (content `beach-content-8`, Godot 4.6.1 Compatibility). This pass belongs to **FIN-05** (asset roles and composition) and feeds **FIN-08** (final look acceptance). It does not close either box: final acceptance still needs human review, all FOV/display extremes and target hardware.

## 1. Review: implementation against the plan and the references

**Rendering implementation (FIN-06/07, V00–V06)** matches the look specification: attributed polygon/foliage shader repairs, extracted light/sky resources, shaded sand with shoreline attributes, the depth-aware single water surface, analytic clouds, caustics on real receivers, the per-camera underwater blend, and native glow plus a generated LUT. The retained values differ from the specification's starting values where renders required it, and C06 records why.

**Visual result against the reference rubric** ([07 rubric](07-completion-plan.md#reference-rubric-and-visual-acceptance)). Colours are medians sampled from the latest `FIN05-composition-final` captures.

| Rubric row | Observed | Verdict |
|---|---|---|
| Image 1 composition | Foreground chairs, parasol and palms frame the view. The lighthouse, pier and activity pocket are readable. | Pass (bounded) |
| Warm shore and light | Sand `#E4C897` against the `#E8CF91` guide. Warm key, cool shade and contact shadows are present. **Every palm is the one Synty fan palm (`Palm_01`)**. Its large brown dead-frond skirt makes crowns read brown or olive from below. **The clouds are stretched diagonal strips** from one ring mesh rather than layered cumulus. | Fail: palms and clouds |
| Water | Shallows `#9FE7DC` (lightness 0.76, hue 170°) against the `#53C5CE` guide. Offshore `#80CFD1` against the `#238DB6` guide. The water is pale mint, nearly uniform and dominated by grazing sky reflection; foam is sparse. | Fail: palette |
| Image 2 bay/skyline | The aerial shows a huge flat pale plain behind a single row of towers and evenly spaced identical palms. | Fail (FIN-05 composition) |
| Image 3 habitat | Sparse mounds, thin spike "coral" and flat ribbons. Placeholder cubes with floating labels sit on the seabed. | Fail: models |
| Image 3 blue depth | Underwater fog `#4095AA` (hue 191°) against the reference's blue `#227FC6`–`#5C8CC3` (hue 205–212°). Seabed `#A3AB8D` is olive against mauve/lilac. Rocks `#2E8792` are teal against lavender `#808DD4`. | Fail: palette |
| Props/litter | Six waste types render as labelled coloured cubes. Rescue, residue, stains, tools and hands use primitives. **The 20 shared storage-shelf pools have no shelf geometry**, so props sit at 0.8 m on nothing. | Fail: models |

## 2. Look changes (Part 1)

| Id | Change | Files | Close with |
|---|---|---|---|
| L1 | Water palette toward the guides. Keep the native sun glint but take control of grazing sky reflection so distant water reads azure rather than white-mint. Strengthen the broken surf line. | `shaders/beach_water.gdshader`, `shaders/beach_water.tres` | Along-shore/aerial medians move toward `#53C5CE`/`#238DB6`; shallow sand and pickups stay visible |
| L2 | Blue underwater: blue fog/ambient, lavender reef rock, lilac seabed tint below the surface | `underwater_environment.tres`, `seabed_caustics.tres`, `beach_sand.gdshader` | Reef capture fog hue in the 200–215° range; near litter stays readable |
| L3 | Palm variety: stage Synty coconut and small palms (`Palm_02`–`05`, small/sapling variants) and cycle them deterministically at existing placements | `data/asset_manifest.json`, palm placers | Green crowns and varied silhouettes at player height and from the aerial |
| L4 | Replace the cloud-ring strips with project low-poly cumulus clusters in a horizon band, using the existing analytic cloud shader | `city_backdrop.gd`, new cloud models | Sky reads as layered flat-bottomed clouds with open blue overhead |
| L5 | Break up the aerial plain with low-poly hills and bush groves using existing Synty foliage (bounded; no gameplay geometry) | `city_backdrop.gd` | Aerial no longer shows a bare flat backing |

The placement volume stays untouched: no collision, objective, slot or water-level changes.

## 3. Low-poly models (Part 2)

**Toolchain.** `tools/blender/build_models.py` (Blender 4.4, run headless) builds every model procedurally: faceted flat shading, per-face vertex colours from a Palm City-style palette and roughness 0.8. It exports one single-mesh `.glb` per model to `art/models/`. The source script is the editable master. A single mesh keeps each loose item eligible for `DistantItemVisuals` MultiMesh batching. The models are project-owned and contain no Synty data.

**Compatibility rule.** `ItemDefinition.visual_scene_path` is hashed into the content identity, so **no definition path changes**. Models replace the contents of the existing wrapper scenes. The rowboat's path is a generated Synty wrapper, so staging gains a project-component option for that wrapper rather than a definition edit.

| Role | Model | Consumer and wiring |
|---|---|---|
| A01 turtle | Faceted sea turtle, head −Z | `scenes/wildlife/turtle.tscn` (rescue sites and routes) |
| A02 fish | Three reef fish species | `fish_school.gd` keeps `Fish_NN` nodes and the head-first route contract |
| A03 starfish | Five-arm faceted star, two colours | `starfish.gd` |
| A04C coral | Branching, brain, fan and tube coral | `restoration_section.gd` coral clusters keep the degraded→restored material tween and names |
| A04P seaweed | Tall kelp frond and seagrass tuft | `restoration_section.gd` seagrass beds keep the tween and names |
| A05 shore bird | Standing and flying gull | New bounded consumer: gulls return to restored shore zones (no collision, no state) |
| A06 stick | Litter picker | `art/replacements/tools/poking_stick.tscn`, `progression.gd` |
| A07V/A07S/A08/A10 | Vacuum, sand sifter, detector, cloth | Existing `scenes/tools/*.tscn` replaced in place |
| A09F/A09T | Flippers, oxygen tank | `scene_path` on the passive tool definitions; shown on the equipment rack when owned |
| A11R/A11N | Six-pack rings, tangled net with floats | Existing rescue wrappers replaced in place |
| A12–A14 | Straw, plastic bag, carton, fries, burger, oil bottle | Existing waste wrappers replaced in place |
| A15R/A15D | Residue splat, furniture stain | `residue_stain.tscn`; `dirt_patch.tscn` mesh |
| A16L/B/T/S | Lifeguard tower, rowboat, beach tent, storage shelf | Lookout scene in place; rowboat wrapper via staging; tent wrapper in place; **new** shelf visuals under every SHELF-layout pool, clear of the capture volume |

## 4. First-person arms (Part 3)

`tools/blender/build_fp_arms.py` imports the licensed Synty `PalmCityCharacters.fbx`. It keeps one character's two arms, upper arm through fingers, skinned to the shared rig, and exports them without animation to the Git-ignored `art/synty/hands/`, the same licensing boundary as other staged Synty art. In Godot, `FirstPersonArms` drives both arms with a native `TwoBoneIK3D` (shoulder→elbow→hand, extended to the palm) aimed at the existing hand-rig sockets. Fingers curl per carry/tool state. A small character shader applies the Palm City skin mask, which the converted polygon shader ignores. If the arms have not been staged, the project hand remains the fallback.

## 5. Validation

Per [AGENTS.md](../../AGENTS.md): demonstrate the changes in the real main scene and keep written checks minimal.

- The existing paired review capture (`validate_pier_art.gd -- --review-pair`) for before/after views
- Existing native checks touched by the changes: boot/asset closure, wildlife, world traversal, pier art, rescue, dirt and placement
- Model inspection in the existing asset gallery scene
- HUD-visible first-person captures for tools, props, bag and arms

Content identity, quotas, slot IDs, collision and the save schema remain unchanged.

## 6. Results — 24 September 2026

All three parts are implemented and demonstrated in the real main scene. Handoff detail: [C06 look](../handoffs/C06.md#reference-look-review-and-palette-pass--24-september-2026), [C04 composition](../handoffs/C04.md#palm-variety-cumulus-sky-storage-shelves-and-modelled-structures--24-september-2026), [C07 wildlife/reef](../handoffs/C07.md#modelled-marine-life-reef-plants-and-shore-birds--24-september-2026), [C08 arms/tools](../handoffs/C08.md#synty-first-person-arms-and-modelled-tools--24-september-2026) and the [asset register](../asset_requests.md).

| Part | Delivered | Evidence |
|---|---|---|
| L1 water | Tinted grazing reflection replaces pale sky reflection; palette on the guides; thicker broken surf | Mid water `#9EE8DF` → `#50CCD4` (guide `#53C5CE`), aerial bay `#53948A` → `#218BA2` (guide `#238DB6`) |
| L2 underwater | Blue fog/ambient, lilac seabed, lavender rock, opaque underside | Fog 191° → 205° (`#217DC3`, reference `#227FC6`) |
| L3 palms | Five Synty palm forms plus understorey, deterministic at every placement | [Restored lounge pocket](../handoffs/images/FIN05-models/lounge-pocket-restored.png) |
| L4 clouds | 38 project cumulus instances in a horizon band plus a few framing clouds | [Restored along-shore](../handoffs/images/FIN05-models/along-shore-restored.png) |
| L5 backdrop | Understorey only; the broad plain remains | Open (FIN-05) |
| Models | 38 single-purpose models (80–1,472 tris; litter ≤ 316) for all 27 project roles plus clouds | [Galleries](../handoffs/images/FIN05-models-play/) |
| Arms | Synty surfer arms, native two-bone IK, per-grip finger curls, skin-mask shader, fallback hand | [First-person states](../handoffs/images/FIN05-models-play/fp-states.png) |

Checks run on the final tree (Godot 4.6.1, isolated profiles), all exit 0 with zero failures: `run_checks`, `validate_pier_art`, `validate_wildlife`, `validate_purchases`, `validate_dirt`, `validate_rescue`, `validate_placement`, `validate_carry`, `validate_sorting`, `validate_faint`, `validate_interaction`, `validate_movement`, `validate_ui`, `validate_save`, `validate_buried`, `validate_tool_filters`, `validate_scanner`, `validate_completion`, the rendered `validate_world_traversal -- --shore-reef`, and the paired full run [FIN05-models](../handoffs/images/FIN05-models/capture-log.txt) ([raw outputs](../handoffs/images/FIN05-models/validation-log.txt), including one completion assertion fixed by keeping the restoration palm's `FoliagePalm` node name). Updated check strings reflect three changed contracts: the cloud node (the Synty ring is replaced by the cumulus band), the lookout node path, and the stick shaft message. No test framework or scene was added. The local capture probes are archived as `.gd.txt` beside the [evidence](../handoffs/images/FIN05-models-play/); copy one into the ignored `builds/` folder to rerun it.

Content identity (`beach-content-8`), quotas, objective IDs, slot IDs, collision, water level and the save schema are unchanged.

Performance, same crowded 1080p profile on the development RTX 3070: median 7.90 → 6.94 ms, mean 9.24 → 7.87 ms, p95 16.53 → 16.67 ms (within earlier variance), maximum draws 4,690 → 3,640, video memory 1,429 → 1,608 MB. The single-mesh litter models now join the distant batches that the placeholder cubes could not use ([performance record](../performance.md#fin-05-look-and-model-pass--24-september-2026)). `tools/blender/build_models.py` is deterministic: a full rebuild reproduced all 38 `.glb` files byte-for-byte.

**Still open after section 6:** the aerial mainland plain, reef density against reference 3, user acceptance of the project models, FOV/display extremes and swimming arm motion, and physical-device play and target-hardware cost (FIN-04/08/10). Section 7 takes up the first four.

## 7. Model review and open-item follow-up — 24 September 2026

**Model review.** The user reviewed all 38 models on one numbered [review sheet](../handoffs/images/FIN05-models-play/model-sheet.png), which shows each model with its in-game material. 32 pass. Six are reworked in `tools/blender/build_models.py`:

- 9: fully closed six-pack rings
- 15: a folded bath cloth
- 18: a connected turtle without the loose shell ring
- 28: one connected sea fan
- 32: the lookout ramp leading up into the hut
- 33: rowboat thwarts inside the hull, with the oars as their own model on top

The user then asked for the remaining open items.

| Id | Change | Files | Close with |
|---|---|---|---|
| L5 | Replace the sand plain behind the beachfront with a level city grid, lawns and hills. The street grid has 28 blocks: paved lots with low-poly buildings generated at runtime (downtown towers around the existing glass tower, low and mid-rise elsewhere) and seven palm parks, plus palm avenues and an edge ring of palms. 25 small tiled-roof houses sit between the flank groves. Lawns start beyond an 8–22 m dune strip, and green hills rise right behind the city. | `scripts/world/city_blocks.gd` (new), `shaders/city_block.gdshader` (new), `city_backdrop.gd` | Aerial shows no bare plain; the eye-level frontage is unchanged; cost measured; no collision |
| R1 | Restoration coral gardens on and around every reef rock and background ridge, plus a patchy open-seabed fill that keeps 1.1 m clear of the run's litter. The gardens are bleached until their section is restored. A regrowth layer, hidden until restoration, then grows over the cleaned litter strip. Rock colour is about 15 % deeper. | `reef_dressing.gd`, `restoration_section.gd`, `shaders/reef_garden.gdshader` (new), `seabed_caustics.gdshader` | Restored views approach reference 3; litter stays readable before restoration; clearance, restoration and replay checks pass |
| A1 | View-model FOV. Poses are framed at the default 85°; at other settings the visible arms, tools, bag and props are scaled across the view by tan(FOV/2) / tan(42.5°). Gameplay sockets stay put, and travel and placement presentations start or end at the visible hand. | `hand_rig.gd`, `world_item.gd`, `carry.gd`, `placement_service.gd` | FOV 70/85/110 captures match; carry, placement, purchase, interaction, save and UI checks pass |
| B1 | Found while building R1: the Compatibility renderer multiplies vertex colour by the MultiMesh instance colour, which is black when instance colours are off. The 103 distant litter batches (988 items) that use the vertex-coloured models therefore drew black between 12 and 55 m. They now carry white instance colours. | `distant_item_visuals.gd` | Coloured distant litter; release, carry and placement checks pass |
| B2 | Found while reviewing the cloth: owned tools on the equipment rack stood 9 cm inside the counter mesh, hiding the flat cloth. Models now rest on the counter top using their measured bounds, and only tall tools are flipped onto their grips. | `equipment_shop.gd`, `equipment_shop.tscn` | Cloth visible on the rack; purchase and save checks pass |
| B3 | User follow-up: "the bridge to the light tower" had missing and misplaced railings. **Pier to the lighthouse:** the right-hand approach and deck rails sat one 2.5 m module toward the shore, sticking out onto the sand and stopping short of the pier head. The head's right rail started 2.5 m early and hung over the water past the deck corner. The two corners where the head widens had no rail, and the approach rails stepped up in a sawtooth and doubled over the deck rail. Every run now spans its deck edge. The approach rails are sheared to follow the 5 % slope, and four 2 m pieces close the head corners. The head's outer tile column is stretched to 3 m so the deck meets its rail and its unchanged 18 m collider. **Lookout ramp** (the user's earlier "bridge"): the porch rail now also runs along the back. The ramp is widened to the rail opening, and its handrail and a new mid rail meet the opening posts at porch-rail height. | `pier_visuals.gd`, `build_models.py` (`lifeguard_tower`), `validate_pier_art.gd` | Continuous rails in the pier and lookout captures; pier art, placement, release, movement and (headless) traversal checks pass |

Results:

| Part | Delivered | Evidence |
|---|---|---|
| L5 | Seven building classes (62–512 triangles each) in one MultiMesh per class. 75 city buildings, 25 houses, 135 palms and 107 bushes use the existing foliage batches. The mainland mesh is 3,381 vertices at 10 m resolution. Building shadows are off, as for the rest of the backdrop. | [Aerial before/after](../handoffs/images/FIN05-open-items/aerial-before-after.png), [high aerial](../handoffs/images/FIN05-open-items/aerial-high.png), [city from the boulevard](../handoffs/images/FIN05-open-items/city-eye.png), [blocks](../handoffs/images/FIN05-open-items/city-block.png), [villas](../handoffs/images/FIN05-open-items/villas.png), [along-shore](../handoffs/images/FIN05-open-items/along-shore.png) |
| R1 | 3,506 garden pieces across 24 MultiMeshes are always present. 862 regrowth pieces appear on restoration. The restoration tween drives the shader fade (and regrowth growth). The coral cluster, seagrass and plant-clearance contracts are unchanged. | [Reef before/after restoration](../handoffs/images/FIN05-open-items/reef-states.png) |
| A1 | Identical hand framing at FOV 70, 85 and 110; before, FOV 70 cropped oversized hands and FOV 110 stretched the arms thin. | [FOV before/after](../handoffs/images/FIN05-open-items/fov-arms.png) |
| Models | Six reworked: rings 612 → 680 triangles, cloth 112 → 212, turtle 248 → 386, fan 392 → 440, lookout 924 → 1,116 (with the B3 rails), rowboat 364 → 382 plus separate oars (168). The rowboat wrapper stages `Hull` + `Oars`. All other contracts are kept: single meshes, flipper joints, fan origin and colours, and the lookout collider. | [Before/after](../handoffs/images/FIN05-open-items/model-fixes.png), [refreshed sheet](../handoffs/images/FIN05-open-items/model-sheet.png), [in-game fixes](../handoffs/images/FIN05-open-items/fixes/) ([C04](../handoffs/C04.md#reviewed-structure-models--24-september-2026), [C07](../handoffs/C07.md#reviewed-marine-models--24-september-2026), [C08](../handoffs/C08.md#reviewed-cloth-and-equipment-rack--24-september-2026)) |
| Railings | 73 pier railing modules (4 new corner pieces) in the same three MultiMeshes; pier collision unchanged. The lookout goes from 1,032 to 1,116 triangles and keeps its collider. | [Railings before/after](../handoffs/images/FIN05-open-items/fixes/railings-before-after.png), [lookout ramp](../handoffs/images/FIN05-open-items/fixes/lookout-ramp.png) ([C04](../handoffs/C04.md#pier-and-lookout-railings--24-september-2026)) |

Cost on the development RTX 3070 at 1080p, measured by toggling the new geometry in place with vsync off:

- **Reef gardens:** 0.8–1.0 ms of GPU time in restored reef views, which stay at or under 4.4 ms median.
- **City:** 0.35–0.9 ms of GPU time in views that see it; the aerial costs the most.
- **Crowded shore profile:** two quiet runs gave median 7.15/7.27 ms (was 6.94), mean 8.54/8.40 ms (was 7.87), p95 17.24/16.40 ms (was 16.67, within earlier variance) and 3,659 draws (was 3,640).

See the [performance record](../performance.md#fin-05-open-item-follow-up--24-september-2026). The capture and cost probes are archived as `.gd.txt` in [FIN05-open-items](../handoffs/images/FIN05-open-items/).

Content identity (`beach-content-8`), quotas, objective IDs, slot IDs, collision, water level and the save schema are unchanged. All new geometry is visual-only.

**Validation.** On the tree before B3, all 19 headless checks exit 0 with no failures, and so does the rendered `validate_world_traversal.gd -- --shore-reef`. The 19 are `run_checks.gd` and the pier art, wildlife, purchase, dirt, rescue, placement, carry, sorting, faint, interaction, movement, UI, save, buried, tool filter, scanner, completion and release-pack checks. After B3, `run_checks.gd`, the pier art check (now 53 rail modules), and the placement, release-pack and movement checks were rerun and pass. The traversal passes headless with the same positions, air values and counts as the rendered pass before B3. The paired main-scene review passed ([capture log](../handoffs/images/FIN05-open-items/review/capture-log.txt)). Earlier review attempts stalled on the scripted lounge and sports approaches while other heavy processes were running. Unmodified copies passed when run alone, so the stalls came from timing, not content. The two rendered traversal reruns after B3 show the same symptom. Both were made while the desktop was in use, and each lost the scripted walk at a different step (a hut entrance and the shore water crossing, then one reef channel), with the player off the scripted line. The rendered traversal should be repeated on an idle machine. `validate_world.gd` also fails at `4006dda`, on stale `ChairTerraces` nodes that predate this pass, and is left for a separate fix.

**Still open:**
- user acceptance of the reworked models and B3 railings, the city and the reef look
- horizontal framing on ultrawide displays (the view-model correction follows vertical FOV) and swimming arm motion
- target-hardware cost of the gardens and city, and physical-device play (FIN-04/08/10)
