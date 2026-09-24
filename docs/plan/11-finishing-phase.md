# Finishing phase — single remaining-work checklist

Consolidated 24 September 2026 from the [systems review](10-systems-review.md), [C-packet specifications](07-completion-plan.md), the revised [look-and-feel specification](09-reference-look-plan.md), [asset register](../asset_requests.md) and [release requirements](05-verification.md). Reviewed gameplay baseline: `68a123a`, Godot 4.6.1 Compatibility, `beach-content-8`, beach version 8, `manifest-1`, save schema 1.

**This is the active execution list for finishing the game.** The major gameplay systems already exist. FIN-01's control repairs and FIN-06/07's rendering implementation are complete. Remaining work is integrated play/device evidence, world and asset finishing, final interaction/visual acceptance, and release verification. Completed P/C work is not a second backlog. The V packets below are included here; their exact shader/resource instructions stay in the look-and-feel specification.

Work through FIN-01–FIN-10 in order by default: systems first, visuals as their own bounded part of the same phase, then final acceptance. Asset supply can be resolved early. If a missing device or asset blocks a check, record the exact dependency and continue independent work; do not mark that step complete. Changing gameplay geometry or content later reopens the affected earlier checks, not the entire implementation plan.

## Master checklist

- [x] **FIN-01 — Repair distinct input presses and service prompts.** F16/F17 closure and bounded main-scene evidence: [C03b](../handoffs/C03b.md). Physical controller acceptance remains FIN-04.
- [ ] **FIN-02 — Close physical access, storage and content compatibility.** Current bounded recheck: [C04](../handoffs/C04.md) and [C05](../handoffs/C05.md). A normal-input shore-to-reef pickup and return now passes on starter air. Connected walking approaches to every occupied slot and player-paced access remain open; gameplay geometry/content identity did not change in this pass.
- [ ] **FIN-03 — Prove the connected cleanup, progression, recovery and restoration loop.** Current bounded recheck: [C05](../handoffs/C05.md) and [C07](../handoffs/C07.md). A normal connected, player-paced route through every listed flow remains open.
- [ ] **FIN-04 — Finish controls, accessibility and pacing.** Current injected-input/UI recheck: [C08](../handoffs/C08.md), including measured walk and held/toggle sprint in a playable movement scene. Physical-controller, display/TV and human pacing evidence remain open.
- [ ] **FIN-05 — Finish composition, habitats and outstanding asset roles.** Continuous mainland/backdrop geometry and grouped existing habitat are implemented: [C04](../handoffs/C04.md#continuous-mainland-and-existing-habitat-composition--24-september-2026), [C07](../handoffs/C07.md#grounded-habitat-composition--24-september-2026), [paired captures](../handoffs/images/FIN05-composition-final/capture-log.txt). All 28 roles in the [asset register](../asset_requests.md) now have integrated models: project low-poly models plus Synty-derived first-person arms ([look and model pass](12-look-and-model-pass.md)). The user reviewed the models (32 pass, six reworked). A follow-up replaced the aerial mainland plain with a city grid, lawns and hills, and added restoration coral gardens to the reef ([section 7](12-look-and-model-pass.md#7-model-review-and-open-item-follow-up--24-september-2026)). User acceptance of the reworked models, the city and reef look, and final composition acceptance remain open. Gameplay collision, content identity and objective positions are unchanged by these passes.
- [x] **FIN-06 — Implement look-and-feel V00–V03.** Matched baseline/final pairs, corrected material normals, tuned light/shadows, wet sand and depth-aware water; native camera orbit/tilt, shore movement and pier/rescue intersection evidence in [C06](../handoffs/C06.md#fin-06fin-07-rendering-implementation--24-september-2026). Final asset/composition acceptance remains FIN-05/08.
- [x] **FIN-07 — Implement look-and-feel V04–V06.** Connected cloud/haze/contact treatment, actual receiver caustics, camera-owned underwater fade and native glow/32³ grade; effect A/B captures, measured costs, HUD surface crossing and submerged save/load in [C06](../handoffs/C06.md#fin-06fin-07-rendering-implementation--24-september-2026).
- [ ] **FIN-08 — Accept the final look and interaction presentation.** Rendering evidence and affected gameplay rechecks are recorded in [C06](../handoffs/C06.md#fin-06fin-07-rendering-implementation--24-september-2026). Blocked on FIN-05's final assets/composition. FOV 70–110 hand framing is now corrected ([C08](../handoffs/C08.md#view-model-fov-correction--24-september-2026)); final grips, ultrawide framing and physical-device/display acceptance remain open. The current paired views, 720p HUD recording and development-GPU profile are bounded evidence, not final visual signoff.
- [ ] **FIN-09 — Freeze a current Windows candidate and finish a normal full run.** Package, deterministic content, saves and 5,700-object completion.
- [ ] **FIN-10 — Pass target-hardware, extended-session and clean-machine gates.** Final evidence and release signoff.

All boxes started open at consolidation; later checked boxes require completion evidence beside them. Record a blocked dependency beside each open checkbox. Supporting C/V handoffs retain implementation detail; there is only one set of active completion boxes.

## FIN-01 — Controls repair

**Scope:** [F16/F17](10-systems-review.md#reproduced-gaps), previously C03b. Repair the shared boundaries rather than adding exceptions to individual tools.

- Rearm one-shot actions on a real release/new press even when both events arrive between physics samples. Preserve one action per held press across multiple ticks, click-only stick use, continuous vacuum, controller trigger/remap support and suppression of held actions when returning from menus.
- Replace hardcoded `E:` instructions at the equipment counter, tool rack, containers and collection hotline with the current device/binding and the correct service verb. Preserve real rejection reasons.
- In the main scene, reproduce and close both failures using the actual player and service targets. Exercise distinct pickup/throw/interact/tool-switch presses, held stick/vacuum, and table/booklet/pause return. Check keyboard/controller remaps and device switching while aiming.

**Own files:** `scripts/player/input_reader.gd`, interactor/target label and station prompt producers; existing input/interaction checks only for the small regressions. Keep detail in `docs/handoffs/C03b.md`.

**Done when:** both recorded reproductions stop failing; each distinct press acts once, held input does not repeat unintended actions, and all service instructions match the active binding without changing ownership/payment/save behavior. Physical-device coverage may share FIN-04 evidence.

## FIN-02 — Access, storage and compatibility

**Scope:** remaining functional C04/C05 gates. Preserve the already repaired F13 trap, hut/rack/shop routes, 300 occupied-target/overlap checks and 15-family representative approaches. These passes do not prove every occupied approach or every generated pickup route.

- In initial, fully occupied and partially restored states, walk/carry through the three huts, output racks, containers, shop, pier and shore exits. Manipulate real props through pickup, ghost placement, physical throw capture, removal and reload in all destination families and difficult/shared-shelf approaches. Confirm all occupied destinations have usable approaches; inspect any not covered by existing evidence. Preserve dirty-prop rejection and safe shared-shelf allocations.
- Check dense piles, tidelines, buried dig surfaces, attachment sites and both reef areas with actual item bounds, pickup rays and player/swim routes. Include current rear shelves, restoration foliage and faint recovery positions. Start the starter-air route at shore, collect at the site and return/surface; the previously staged short dive is insufficient alone.
- Retain exactly 5,400 waste + 300 props and 40 optional valuables, the existing buried/attachment/residue/dirty subsets, and all 40 catalog definitions. The six formerly missing waste types are already implemented. Final natural clutter dressing belongs to FIN-05, but no known objective may remain physically inaccessible.
- Record the terrain/slot/anchor revision used. Preserve old saves and a compatible build before any manifest/slot change; version changed generation explicitly and retain the readable incompatible-save message. Keep pure art replacements at stable wrapper paths. At the next generation-affecting reef edit, include the shared exclusion parameters in the existing content identity or deliberately version the change; do not weaken regenerated-manifest validation. See the [compatibility boundary](10-systems-review.md#compatibility-boundary-for-the-separate-visual-track).

**Own files:** existing world/zone scenes, slots/anchors, generator/validator and placement/recovery components if a demonstrated failure requires repair. Evidence belongs in C04/C05 handoffs.

**Done when:** current physical access and occupied manipulation are demonstrated, compatible storage remains feasible, no known objective is unreachable, and the accepted layout/content has an explicit save-compatibility decision. Record seeds and the limits of sampled generation; final 100-seed validation belongs to FIN-09.

## FIN-03 — Connected systems closure

**Scope:** remaining C05/C07 functional integration, preserving the implemented inventory, table, purchases, tools, swimming, rescues, scanner, restoration and persistence. Reuse one connected run or a small set of existing saved states; disclose any staged setup.

- Complete two starter-bag cycles through normal collection, wrong-bin correction, partial/automatic sealing, rack pickup, matching deposit and explicit truck call. Exercise full-table/full-bin/full-rack rejection and retry after making space, selected second-bag deposit and pre-collection retrieval. Receipt, wallet and home-section progress must agree; repeat calls pay nothing.
- Earn, buy and equip via the physical shop/rack and booklet. Use every handheld tool and passive gear, switch the two-slot loadout and freely re-equip owned tools. Include the cloth/knife/detector/tank access route, sand cleaner/vacuum eligibility and full-bag rejection. Keep optional-first purchases solvable at base-only waste income; valuables and group rewards cannot be mandatory funding.
- Detect/reveal buried waste and valuables, collect/throw/recover them, unload and sell valuables once. Cut an attachment with a full bag, recover its loose waste, and carry it through collection. Confirm hidden finds/intact attachments/residue cannot bypass their required tool, and animals cannot be harmed or re-entangled.
- Faint with mixed bagged waste/valuables, one small held prop and one sealed bag; save/reload and recover the same IDs through normal controls. Preserve wallet/equipment, marker membership, 10/60/unlimited air and one-second surface refill. Repeat faint/recovery without duplication; keep the already implemented large-prop swim/shore-exit behavior.
- Complete a section's final local task through actual placement or truck collection. Observe its local reward while its neighbor remains dirty, collect across that boundary, then complete the zone. Verify local fish and lounge/reef turtle routes, released-animal persistence and no duplicate populations after reload. Re-pick/re-slot a prop: current progress may change, nature and prior payment do not reset.
- Use the scanner's discovered filters for remaining world, table/bin and container work. Save-and-quit during sorting, resume the selected checkpoint, use distinct checkpoints and same-seed independent runs, and preserve the original result receipt after finish/rearrangement/reload. Keep the existing difficult ownership/payment/save checks alongside play evidence.

**Own files:** existing core, station, tool, swim, wildlife and UI components only where play exposes a failure. Reuse C05/C07/C08 handoffs and the verification state sequences.

**Done when:** the connected routes work through normal gameplay with correct ownership, payments, home credit, recovery, permanent restoration and save continuation. Staged near-finish evidence is acceptable for bounded behavior here; it does not replace FIN-09's normal full run.

## FIN-04 — Devices, accessibility and pacing

**Scope:** functional C08 and remaining C05 pacing. Default bindings or synthetic input alone cannot close this step.

- Use a physical controller from launch through new run, movement/diving, all menus/tools, shop/rack, booklet, complete sorting/transport/collection, scanner selection, checkpoints and result continuation, without mouse assistance. Include remapped confirm/back/interact, rapid distinct presses, focus return, device switch and controller disconnect/reconnect. Repeat mouse click/drag sorting and keyboard remaps.
- Check sensitivity, invert-Y, sprint/crouch toggles, deadzone, reduced motion, FOV 70–110 and UI scale 100–150%. HUD/table/shop/booklet/scanner/pause/results/settings must remain usable at 720p, 1080p, 4K and wide aspect ratio, including large-scale scroll/focus and TV viewing distance. Functional labels/category cues cannot depend on colour alone.
- Play human-paced early/middle/nearly complete states. Record first earnings, station trips, tool discovery/usefulness, sorting/capacity delays, upgrade purchases, and last-item search. Tune existing resources only for observed problems, preserving locked capacities/air/counts. Rerun the existing economy proof if prices, earnings, prerequisites or equipment-dependent access change.

**Own files:** existing input/settings/UI and tuning resources. Keep evidence in C08 and C05 handoffs; no telemetry framework or new menu system.

**Done when:** both device flows and accessibility settings are demonstrated, observed progression remains solvable, and recorded usability/pacing blockers are fixed. Missing physical controller/display evidence stays open. Final visual changes reopen affected readability checks in FIN-08.

## FIN-05 — World composition, habitats and asset completion

**Scope:** remaining visual C04/C05/C07/C08 work. This is part of the finishing phase, separate from system implementation. Use the existing [reference rubric](07-completion-plan.md#reference-rubric-and-visual-acceptance); the revised look specification owns lighting/shader values when older colour suggestions differ.

- Finish the continuous bay/outer land/backdrop edges, pier/café/lighthouse proportions and restrained skyline; compose readable foreground/middle-distance activity pockets and usable occupied seating/storage groups. Retain 160 m, first-person routes, three services and sufficient actual destination slots; decoration cannot conceal an unusable destination.
- Finish natural singles, food/bin patches, sports litter, tidelines and submerged work sites without changing exact quotas. Preserve the working catalog and starter route. Inspect initial/restored scenes at player height as well as the paired elevated view.
- Finish reef floor/rock relief, sandy lanes, layered near/middle/rear habitat and varied-height coral/plants. Degraded and restored states share the underlying habitat. Preserve local rewards, shore plants/life, fish/turtle routes and dirty-neighbor access; do not add a wildlife simulation.
- Resolve every open runtime role below from the asset register: supply and integrate the final asset, or record an explicit user-accepted substitute. A model path alone does not close a role; inspect its actual world/table/hand/rescue/restoration consumer. Missing art remains a blocked visual item with the exact needed asset named.

| Asset roles to resolve | Required integration |
|---|---|
| A01–A03 turtles/fish/starfish; A04C/A04P coral and seaweed/seagrass | Actual rescue, ambient, section and zone consumers, including procedural visuals that need scene hooks |
| A05 shore birds | Bounded nonblocking returning shore-life presentation when supplied; currently no runtime consumer |
| A06 stick; A07V/A07S cleaners; A08 detector; A10 cloth | Equipment scenes and actual hand/tool presentation |
| A09F/A09T flippers and tank | Worn/gear presentation where applicable; gameplay ownership already exists |
| A11R/A11N rings and net | Attachment and loose-waste presentations retaining original IDs |
| A12S/A12W/A12C straw/wrap/carton; A13F/A13H food; A14 oil container | Replace the six logical definitions' placeholders in their actual consumers |
| A15R/A15D residue and furniture stains | Residue scene and procedural stain consumer |
| A16L/A16B/A16T/A16S lookout/rowboat/tent/shelf; A17 hands | Final scene/wrapper integration and storage/hand contracts |

**Own files:** existing beach/zone/dressing/restoration scenes/scripts, asset manifest/staging and replacement/tool/hand scenes. Preserve source licensing and reproducible staging; no unrequested external asset purchase. Keep detail in C04/C05/C07/C08 handoffs and the asset register.

**Done when:** composition/habitat rubric rows pass, all open asset roles have an integrated final or explicitly accepted disposition, and every affected route from FIN-02/03 remains valid. The future rendering passes cannot substitute for missing geometry or assets. Freeze gameplay geometry before final look comparisons where possible.

## FIN-06 — Look-and-feel foundation, sand and water

**Scope:** implement V00–V03 exactly against the revised [look-and-feel specification](09-reference-look-plan.md), compiling and rendering each change. Its numeric values are starting values, not evidence of a finished image.

| Included packet | Remaining deliverable | Close with |
|---|---|---|
| V00 | Record the current dirty/restored baseline and settings; make the existing capture viewport copy gameplay MSAA and camera clip values | Matched 1080p pair, HUD view and baseline profile; same camera/seed/settings and controlled animation phase for effect comparisons |
| V01 | Correct polygon/foliage normal handling in attributed project shaders; redirect known staged shader references; extract light/sky resources and apply the specified sun/fill/shadow/MSAA setup | Fixed-object camera orbit, shaded chair/can/building/pier, palm underside and hut/table; normal fixes work for full views and distant batches |
| V02 | Share the existing coast profile/slope and shore attributes; compute actual sand normals and connect dry/wet sand ShaderMaterial, including the dry-dune variant | Continuous curved wet strip and stable world texture scale from eye height and above, with unchanged gameplay collision/profile |
| V03 | Subdivide the single water surface; separate bed-depth palette from view thickness; correct data normals/specular, opacity, shore/contact foam and underside | Stationary-patch tilt, moving surf, glints, clear shallow pickups, glass/floating prop/pier/rescue intersections and underwater surface |

**Own files:** the exact file table in the look specification: project shader variants and staging/manifest, environment/sky resources, beach scene, coastline/shore/water scripts, sand/water shaders/materials, project settings, and the existing capture method only for render-setting parity. Record V00–V03 in C06's handoff.

**Done when:** all four packet pass conditions are demonstrated in Godot 4.6.1 Compatibility with readable gameplay, reproducible staging, no shader/import errors and the intended unchanged water/oxygen/geometry contracts. Do not treat the specification's pseudocode as an already compiled implementation.

## FIN-07 — Atmosphere, underwater treatment and grade

**Scope:** V04–V06, after FIN-06. Keep the look specification's tuning order and single surface/receiver design.

| Included packet | Remaining deliverable | Close with |
|---|---|---|
| V04 | Controlled cloud top/underside shader and shape, native horizon haze/contact AO, normally shaded backdrop support materials | Coast pan, mountain/lighthouse separation and AO on/off; no chair/hand/waterline halos or haze masking unfinished geometry |
| V05 | Stage the supplied caustic data reproducibly; connect one shared caustics include to the actual sand/reef receivers; match underwater environment and a per-camera visual transition | Caustics on submerged sand/upper rocks only; surface crossings, HUD-visible reef pickup/rescue, submerged save/load; oxygen/hysteresis/physics remain immediate and unchanged |
| V06 | Native restrained glow and offline generated 32³ LUT with identity option; assign the retained grade to surface/underwater environments | Raw, glow-only, grade-only and combined views at matching cameras; retain material/category/outline/HUD readability and detail |

**Own files:** specified cloud/caustics/reef shaders/materials, backdrop/reef scripts, underwater environment and SwimService presentation, existing staging queue/manifest, grade tool/resource and environment assignment. Record V04–V06 in C06's handoff.

**Done when:** shader/resource connections actually affect the rendered scene, each packet's A/B and playable conditions pass, and effect costs are measured rather than inferred. Preserve the source package and fixed gameplay water state; no renderer switch, refraction system or new post-processing framework is required.

## FIN-08 — Final visual and interaction acceptance

**Scope:** V07 plus final C08 presentation and affected checks from FIN-02–04. Dependencies: final composition/assets and V00–V06.

- Inspect the complete reference rubric using matched dirty/restored aerial, along-shore, seating, pier and underwater views plus an ordinary HUD-visible walk/swim recording. Use the look specification's capture parity and animation-phase rules. Record retained values/resources, not just screenshots or proposed defaults.
- Fit all tool grips, left-hand bag, two small props, one large prop and two disposal bags at FOV extremes while moving, crouching and swimming. Finish hover/target/travel/ghost/pulse/group-sweep readability, reset scales correctly, and honour reduced motion. Do not obscure targets or category information.
- Revisit shadowed cans, shallow pickups, glass/foam intersections, all huts/tables, dirty/restored reef boundaries, rescue sites and submerged save/reload with the final materials/models. Recheck affected controller/keyboard focus and HUD/category readability at the FIN-04 display settings. Later visual changes must not reintroduce access, input, payment or persistence failures.
- Record effect-by-effect and crowded/restored-view cost. If needed, follow the look plan's reduction order: SSAO off, MSAA 4×→2×, glow off, then shorter/lower-resolution shadows. Preserve normal fixes, shaped light, water depth/foam and wet-sand identity. Final target-device certification remains FIN-10; development-GPU results do not close it.

**Own files:** existing hand/tool/UI presentation and the visual resources just implemented; C06/C08 handoffs, asset register and performance record.

**Done when:** V07's visual conditions and final presentation pass, each asset's actual disposition is clear, affected functional routes still pass, and measured costs/remaining hardware evidence are recorded. No broad repeat of unaffected system checks is required.

## FIN-09 — Current candidate, full completion and save integrity

**Scope:** final content and current Windows candidate; existing historical binaries are insufficient. Use the accepted final resources from FIN-08.

- Freeze and record commit, engine/templates, content/generator/save versions and seed. Export a versioned Windows x86_64 candidate with matching Godot 4.6.1 templates. Inspect packed runtime/catalog/staged references; exclude vendor source archives, nested conversion project, docs/review captures, tests and tools. Keep the external checks outside the pack.
- Run the existing ownership/payment/completion/save checks and accelerated full run against this candidate where applicable. Run the existing 100-seed validation once on settled content, including repeated, generated-empty, Unicode, maximum-length and rejected invalid seeds. No new runner, discovery system or seed framework.
- Finish at least one human-paced 5,700-object run through normal controls, without debug collection or staged completion. Resume across real saves/sessions as needed. Record earning/purchases, every special-content flow, final-item scanner search, final collection/placement, results, continued roaming and post-finish save/reload. Prefer controller for the full run so FIN-04 evidence overlaps; otherwise supplement it with the full physical-controller feature/menu route on this candidate.
- Validate final packaged autosave/manual checkpoints, independent runs, sorting save-and-quit, live item/bag physics poses, mixed-bag order, faint recovery and immutable result metadata. With isolated data, check corrupt-latest A/B fallback, both-generations failure, failed write retaining the prior generation and preventing false save/quit success, plus incompatible content handling. Preserve real player saves.

**Own files:** existing export preset and checks only if a demonstrated problem needs repair; C09 handoff, release record and final-run receipt/evidence.

**Done when:** the current candidate contains the intended resources, deterministic/state/save checks pass, a normal full finish and controller route are demonstrated, and no known completion/ownership/payment/save defect remains. If repairs change relevant final content or behavior, update the candidate and rerun affected evidence; keep the exact build association explicit.

## FIN-10 — Performance, clean machine and signoff

**Scope:** certify the FIN-09 candidate; this is the final required release step, not a new feature phase.

- Profile the exported build at 1920×1080 defaults on GTX 980-class graphics and 8 GB system RAM. Record CPU, GPU/VRAM, driver, OS and build. Target 60 fps, p95 ≤18 ms, no recurring >50 ms gameplay stalls; aim ≤3 GB process resident and ≤3 GB dedicated GPU memory.
- Measure full cold startup, dense piles, long coast views, 200-item table, maximum vacuum, restored occupied reef/world, full-bag faint/recovery, saves/loads and nearly complete scanner use. Repeat after extended pickup/throw/save activity; record process/GPU memory and body/node/material counts alongside frame times. Repair measured stalls/leaks using the existing batching/limits before considering larger changes.
- On a fresh Windows profile/machine without the editor or .NET SDK, demonstrate startup, actual play/controller detection, first save, load and quit. A development-machine headless boot alone does not close clean-machine acceptance.
- Update this checklist, C09 handoff, release/performance records, exact build path/hashes and final asset dispositions. All evidence must identify the candidate it covers. Missing hardware, human/device evidence or required assets remains explicitly open; it cannot be converted to a pass by wording.

**Done when:** the accepted candidate passes the target/extended-session/clean-machine gates and FIN-01–FIN-09 are closed with evidence. Performance changes that alter visuals or gameplay reopen only the relevant earlier acceptance before final signoff.

## Coverage and completion rules

| Prior open work | Finishing owner |
|---|---|
| C03b; new F16/F17 | FIN-01 |
| C04 physical access/storage; C05 reachable content; compatibility risk | FIN-02, with affected rechecks in FIN-05/08/09 |
| C05 tools/progression/recovery; C07 functional restoration | FIN-03 |
| C05 pacing; C08 controls/accessibility | FIN-04 |
| C04 composition, C05 natural clutter, C07 habitat/species, C08 missing art | FIN-05 |
| Revised look plan V00, V01, V02, V03 | FIN-06 |
| Revised look plan V04, V05, V06 | FIN-07 |
| Revised look plan V07; C08 final hands/feedback/readability | FIN-08; final target-device portion in FIN-10 |
| C09 normal finish, final content/export/save integrity | FIN-09 |
| C09 target hardware, extended-session/fresh-machine evidence and release record | FIN-10 |

**When all ten boxes are closed, the agreed full-release scope is done.** There is no additional required implementation phase hidden in P00–P29, C00–C09 or V00–V07. Those documents provide contracts, technical detail and historical evidence. Optional jetski, multiplayer, online leaderboards, sound, visitors, additional beaches and storefront publishing are outside this finishing phase.

Keep the existing verified foundation: stable owners/IDs, once-only payment/rewards, three checkpoints, implemented catalog/offers, permanent restoration and native streaming. A newly observed defect in this scope goes into its owning FIN step with a reproduction and exit condition. Do not expand scope with speculative features. Do not automatically restart the old packets or all testing after a local change.

Follow [AGENTS.md](../../AGENTS.md) and [verification guidance](05-verification.md): demonstrate working systems in the real game/existing scenes; written checks stay minimal and protect meaningful invariants or difficult regressions. Use the existing C handoffs and one C06 record for V work, linking them here rather than creating duplicate handoff sets. Each evidence entry records build/content/engine, seed/setup, device/bindings, actions, observed counts/results and unresolved limits. Passing automated or accelerated checks never impersonates human/device/target-hardware evidence.
