# Beach terrain and litter pass — sand relief, grounded items, readable mess

Planned 25 September 2026 on branch `claude/beach-terrain-pass` from `main` at `768070b`. **Status:** B00–B06 implemented; evidence, departures and open issues are in [B-beach](../handoffs/B-beach.md).

The user asked for three things:

1. The beach is flat. A natural beach has some elevation here and there.
2. Many items hover above the sand instead of lying on it.
3. The litter layout should read like the tidy-up games they named: Tidy Farm, Too Many Toys and Supermarket Chaos.

This plan covers all three. It is written for implementers who have not read the code: every packet names its files, what it keeps for existing callers and checks, and how to show it working in the game.

## 0. Authority and boundaries

- **Locked content stays locked.** 5,700 required objects (5,400 waste, 300 props) plus 40 optional valuables; every per-section, per-category, per-family, buried (300), rescue (24), residue (120) and dirty-prop (60) count stays exact (`section_quotas.tres`, [content and balance](04-content-and-balance.md)).
- **Seeded generation stays deterministic.** The same seed and content version must give the same manifest in separate processes ([02-architecture](02-architecture.md) §manifest). The layout is authored data plus seeded clutter. The seed must not move the terrain or scenery (R02).
- **Content version.** Changing positions changes every manifest, so this pass bumps `beach-content-8` to `beach-content-9`. Saves made before the bump are rejected with the existing incompatibility message and are never migrated ([C00](../handoffs/C00.md)). Record `768070b` as the build to keep for content-8 saves. The generator label stays `manifest-1`, as in C04 and C05.
- **Frozen start.** Items still start asleep at their authored pose; nothing is settled by physics at run start ([P07](../handoffs/P07.md)). "Resting on the sand" is authored by the generator, not simulated.
- **Walkability.** The player's floor limit is 46° (`movement.gd`). Terrain in the playable area stays around 18° at its steepest (never above 20°), so walking, carrying and throwing feel the same as today.
- **Gameplay places stay level.** Service points, the equipment shop, the pier approach, lookouts, shade sails, café sets, the volleyball court, the player spawn and the recovery anchors keep flat ground. Their collision, interaction reach and capture volumes do not move.
- **Unchanged:** ownership, payments, completion, restoration and save format. Items in water keep the existing float/sink rules: floating items on the water plane, sinking items on the seabed.
- **Performance** stays within the [performance pass](13-performance-pass.md) budgets: the new terrain mesh is built once; the densest view is re-measured.
- **Tests:** follow the [project rule](../../AGENTS.md). Prove behaviour in the running game with before/after captures. Update only the pinned hashes and the few checks whose numbers this pass changes on purpose, and add one small check for the new terrain/layout invariants.

## 1. What exists today

Measured on `768070b` with seed `first-shore` at 1920×1080 High. Before images: `docs/handoffs/images/B-beach/*_before.png`.

| Area | Today (source) | Problem |
|---|---|---|
| Sand shape | `Coastline.surface_y` returns 0.012 m for every point more than 2 m inland of the waterline. `ShoreDressing` builds the sand from 5 rows per 2.5 m column; the whole dry beach is one flat strip per column (`shore_dressing.gd`). | A flat, featureless table. The only relief is decorative dune meshes outside the play area. |
| Item height | Each pack has one authored y. Sand packs use 0.150 m on sand at 0.012 m, so every land item's base floats **13.8 cm** above the sand. The collision box and mesh both start at the item origin, and items start frozen, so nothing ever drops (`spawn_anchors.tres`, `world_item.gd`). | Every bottle, jar, towel and chair visibly hovers, with its shadow detached. |
| Other heights | Pile layers add 60–240 mm more. Pier-deck litter is 0.25 m *inside* the deck. Reef litter hovers 0.2–0.4 m over the seabed; some shallows litter sits 1 m under the seabed. Recovered items land at 0.05 m, dug-up finds at +0.035 m. | Floating, sunk and buried-in-deck items everywhere. |
| Poses | Yaw only, in 22.5° steps. The rolled towel's mesh is centred on its origin, so it would sit half-buried if lowered. | Upright bottles and jars stand to attention like shop stock. |
| Layout | Each section is a 16×48 grid at 0.7 m. Waste fills 41–88 % of the cells, ordered by `randf() + 0.9·gauss` around two random centres, with ±150 mm jitter (`manifest_generator.gd`). The grids stop at z = 26.9 m, 6–28 m short of the water. | From above it reads as even noise with faint bands. No litter tells a story: nothing at the tideline, nothing blown against the dunes, no picnic mess. The foreshore is bare. |

## 2. What the named games do (reference principles)

Tidy Farm, Too Many Toys and Supermarket Chaos share a small set of layout rules. This pass adopts them.

1. **Mess has a cause.** Litter gathers where people were: picnic blankets, around a court, under parasols, beside a sandcastle, at the tideline, blown against a wall or dune. The player can read the scene and predict where the rest is.
2. **Hotspots and gaps.** Dense clusters of 10–40 items with clean ground between them. The eye reads "areas to clear", and clearing a hotspot feels like a unit of progress.
3. **A few heaps.** Some items touch or overlap in small heaps. Heaps are the satisfying targets for vacuum and grab-many tools.
4. **Contact with the ground.** Everything lies on the floor, most things on their side, at varied angles. Nothing floats; nothing stands on a perfect grid.
5. **Type follows place.** Food wrappers at the picnic, bottles and nets at the tideline, paper and cups against the dunes, cans around the court.
6. **The ground has shape.** Gentle dips and rises make the scene read in depth and give "over that dune" discovery.

## 3. Packets

### B00 — Baseline captures (done)

`builds/ui_pass/probes/beach_views.gd` (local probe) starts a real run and captures the aerial, eye-level zone views, the shore, the pier approach, two top-down views and two low grazing views. The before set is saved to the handoff folder.

### B01 — Sand relief

**New:** `scripts/world/beach_relief.gd` (`BeachRelief`, static), `data/world/beach_layout.tres`, `tools/bake_beach_layout.gd`.

- `BeachRelief.height(x, z)` returns metres to add to the flat sand. It uses only integer-hash value noise and polynomials (no `sin`/`exp`), so it is exactly reproducible. The layers:
  - **Back dunes.** A ridge from the promenade (0.32 m, where the sand meets the promenade top) to a crest 9–13 m in front of it (0.7–1.9 m, varying along the beach and capped so the face stays walkable), falling to the beach level 9.5 m later. Bigger outside the play boundary.
  - **Hummocks and swells.** Scattered mounds up to about 0.75 m toward the dunes and 0.5 m toward the sea, and a very low swell (±6 cm) across the open beach.
  - **Berm.** A 0.24 m crest about 7 m above the waterline, with gaps along the shore. This is where the tideline litter lies.
  - **Level pads.** Each pad from the layout data flattens the relief inside its footprint ("zero" pads to the base sand, "terrace" pads such as the café sets to the relief at their centre) and blends back over 3–5.5 m, or further where the relief stands high, so a pad's edge is never steeper than a dune face.
  - The relief fades to 0 at 2 m from the waterline, so the wet sand, the water, swimming and the seabed are unchanged.
- `Coastline.surface_y` adds the relief on the dry side. Every existing caller (restoration gardens, wildlife, water depth, capture tools) follows automatically. `BeachRelief.land_normal(x, z)` returns the slope normal.
- **Reading the shape.** Synty `SM_Env_Grass_Clump_01` (staged as `foliage_grass_clump`) grows in patches on the dunes, thicker toward the crests, as one shadowless batch that stops 2 m above the dune toe so it never hides litter. The sand shader pales dry crests slightly and draws a faint, broken wrack band of darker sand along the old high-tide line.
- `ShoreDressing` builds the sand from 1 m columns with 72 dry rows (2.5 m columns beyond ±130 m). It keeps the node names `CurvedSandSurface` and `CurvedSandCollision/Collision` and the same five-row water profile. Collision is still the render mesh.
- **Grounding scenery.** Palms, sandcastles, board racks, placement pools (chair rows, shelves), spawn anchors and restoration visuals are raised by the relief under their origin at load. This happens before the scenery batcher bakes, so batched palms follow too. Level-pad features need no change.
- **Layout data.** `tools/bake_beach_layout.gd` reads the beach scene and writes `data/world/beach_layout.tres`:
  - `pads`: level footprints for the features listed in §0.
  - `obstacles`: footprints litter must avoid (palm trunks, lookouts, sandcastles, net, shade poles, board racks, the shop, placement slots and shelves).
  - `sources`: scenery that makes mess (court, sandcastles, lounge rows, shade sails, lookouts, board racks).
  A small check rebuilds the same data from the scene and fails if the saved file is stale.
- **Show it working:** aerial and eye-level captures with visible dunes and mounds; walk the 148 m route and every hut entrance; carry and throw on a slope; the lounges turtle route and the reef are unchanged.

### B02 — Items rest on the ground

**Files:** `manifest_generator.gd`, `item_definition.gd` + `data/items/*.tres`, new `scripts/items/item_rest_pose.gd`, `world_item.gd`, `distant_item_visuals.gd`, `recovery_bounds.gd`, `buried_find.gd`.

- **Rest height.** The generator sets every row's y from the ground under it:
  - sand: `Coastline.surface_y`, including the relief;
  - pier: the visible plank top (approach ramp, deck and head);
  - water packs: floating items on the water plane (0.08 m), sinking items on the seabed;
  - reef: the seabed.
  Buried rows lie their depth below that ground, and their dig spot is on it. Pile members stand on the ground plus a small layer offset. Rescue attachments sit 0.25 m above the seabed.
- **Slope and tumble.** When the run state is created, each loose item's pose leans to the ground normal, plus a small per-item wobble (±7°, from its ID hash). Large items lean to the slope without wobble. Items on the water plane stay level. The pose is saved as today.
- **Lying on their side.** `ItemDefinition.lying_chance` (new, authored) is the share of an item type that lies on its side: bottles 80–85 %, cans, cups and cartons about 50 %, jars 55 %, the ice cream and loose paddles always. `ItemRestPose.visual_transform(definition, item_id)` turns the model 90° inside its body and lifts it so its lowest point just touches the ground, sunk by up to 1.5 cm. The choice comes from the item ID, so near views, distant batches and reloads always agree. The same lift fixes the centred rolled towel. The physics box does not change, so pickup, hover and throws behave as before.
- **Other rest heights.** Recovered items and dug-up finds rest on the sand under them instead of 3.5–5 cm above it.
- **Show it working:** low grazing captures before/after (shadows touch the items); a thrown bottle lands and stays on its side; a woken item does not jump or sink; the deck, a reef site and a shallows rescue.

### B03 — Litter layout that tells a story

**Files:** `manifest_generator.gd`, `data/world/spawn_anchors.tres` (sand territories, heap patterns), `data/world/beach_layout.tres`.

- **Territories.** Each dry-sand section owns its strip along the beach from the dune foot (z −19 m) to 3.2 m above the waterline. The empty strip between the sandplay hut and the pier approach (x 24–37 m) is shared out between those two sections, and arrival:start reaches the west boundary. Service exclusions, obstacles and pads with gameplay stay clear. The pier deck owns the plank area inside the railings, clear of benches.
- **Candidates.** Jittered 0.42 m points over each territory. Each chosen item keeps a clearance from its neighbours based on its model footprint, so nothing interpenetrates except inside heaps.
- **Mess sources.** Each candidate weighs its distance to:

  | Source | Where | Mostly |
  |---|---|---|
  | Tideline | berm crest, with gaps | bottles, jars, cans, nets, bundled scrap |
  | Dune drift | foot of the back dunes | paper, wrap, cups, straws |
  | Picnic spots | 2–3 per section, placed by seed | food, cups, cans, cartons |
  | Court | around the volleyball net | cans, cups, bottles |
  | Lounge rows | a seeded share of chair and lounger rows | towels, cans, bottles, food |
  | Sandcastles | around each castle | ice cream, fries, cups, straws |
  | Shade, lookout, board rack | around each | mixed |
  | Base | everywhere | light scatter |

  Each category (PMD, organic, general, glass) draws its quota by weighted sampling without replacement over the candidates. The dominant source then biases which item type is chosen. The contrast between the source peaks and the base weight gives hotspots with clean ground between them.
- **Heaps.** The 25 % pile share stays. Piles start at a chosen member in a hotspot, and the patterns become tight, low heaps (4–6 items, at most one raised layer of 5–8 cm). `validate_physics`'s "largest pile ≤ 6" still holds.
- **Props.** Reusable props (chairs, parasols, balls) gather in 2–4 seeded "abandoned" groups per section toward the front of the beach. They lean toward related places: volleyballs near the court, buckets and spades near sandcastles, boards near the racks. Large props keep 1.9 m apart and clear of the walk route, as the validator requires.
- **Unchanged:** water, shallows and reef packs keep their grids, apart from the corrected heights. Buried, residue, rescue and valuable selection keep their rules, and the dirty-prop pass skips the starter section so its props start clean, as [03](03-world-and-assets.md) specifies.
- **Show it working:** top-down captures of each zone before and after; eye-level views where a hotspot, a clean gap and the tideline are visible; the densest-view frame time.

### B04 — Content version, saves and checks

- Bump `CONTENT_VERSION` and the resource metadata to `beach-content-9` and the beach version to 9. The content hash covers the relief parameters and layout data.
- Update the pinned content and manifest hashes in `tests/run_checks.gd`. Update any check whose number changes on purpose, recording the old and new values in the handoff. Add one small written check:
  - relief slope ≤ 20° in the play area;
  - pads level;
  - every land row's y within 2 cm of the ground under it;
  - layout data matches the scene.
- Run the battery: run_checks, world, world_traversal, physics (windowed), pier_art (windowed), placement, buried, rescue, save, save_physics, full_run, release_seeds, content_economy, interaction, carry, tool_filters, wildlife and faint.
- Record the old content-8 keep commit in the README, the release checks and the handoff.

### B05 — Evidence

The [handoff](../handoffs/B-beach.md) records setup, actions and results. It includes before/after images for aerial, eye-level, low grazing and top-down views, the check list with results, frame times for the lounges densest view and the aerial at High, and remaining issues.

### B06 — Sand detail and the swash

Requested after B00–B05: make the sand read as real beach sand with shells in it, and give the edge of the sea waves that run up the sand and leave it wet.

- **Sand detail.** `tools/build_sand_detail.gd` writes three project textures to `art/textures/sand/` (deterministic, committed, lossless):
  - `sand_detail.png`: grain, wind-ripple height, dark and pale grit, and sparkle grains, tileable over 2 m;
  - `sand_normals.png`: ripple and grain slopes;
  - `shell_atlas.png`: sixteen shapes (scallops, cockles, mussels, whelks, a sand dollar, a starfish, pebbles, a shell shard and a seaweed scrap).
  The Synty packs have no shells or sand grain; `Sand_01` stays as the low-frequency base.
- **Sand shader.** `beach_sand.gdshader` adds, within the detail distance (32 m, scaled by the View distance setting):
  - two scales of grain and grit;
  - wind ripples in patches on dry open sand only;
  - a per-pixel grain normal;
  - faint grain glints;
  - shells and pebbles scattered from a hashed 0.7 m cell grid, about 1 in 10 cells, three times as many along the tideline and in the swash zone. They fade out before they shrink below a pixel.
  The city ground that reuses the material turns this off (`beach_detail`).
- **The swash.** `shaders/beach_swash.gdshaderinc` is shared by the sand and water shaders, so both stay in step:
  - every 8.5 s a breaking wave rolls in from 11 m out as a line of white water;
  - it runs up the sand as a thin glossy sheet with a lacy foam front (up to 3 m, varying per wave and along the shore in cusps), then drains back;
  - uncovered sand stays dark and shiny and dries over about 4 s;
  - a band that the waves keep reaching stays damp.
  Waves arrive at an angle, so the phase drifts along the beach. The water keeps its edge foam; its old oscillating foam band is replaced by the surf.
- **Graphics setting.** Graphics → *Beach detail (sand, shells, waves)*: Off, Low, Medium, High. It is part of the presets: Low → Low, Medium → Medium, High and Ultra → High.
  - Off: plain sand, a still wet strip at the waterline, and only edge foam on the water.
  - Low: the waves and wet sand, with one grain layer.
  - Medium: adds the second grain layer, ripples, grain relief, shells and lacy foam.
  - High: adds glints.
  `BeachDetail` sets it on the shared sand and water materials, so it applies live on the title screen and in a run. The shader branches are uniform, so each level skips the texture reads it does not use.
- **Boundaries.** Presentation only. Waves never reach litter, which starts 3.2 m above the waterline; the sand collision, the waterline, swimming and the water plane are unchanged.
- **Show it working:** paired captures with the previous shaders on the same layout; a top-down swash sequence over one wave; a recorded clip; frame times on High.

## 4. Out of scope

New item models, new scenery beyond the staged Synty dune grass and the project sand textures, 3D shell props, the reef bed shape (C04/C07 record it as flat), per-item physics colliders fitted to meshes, sound, and changes to quotas or the economy.
