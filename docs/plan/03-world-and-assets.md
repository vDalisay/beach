# World layout, visual direction and asset audit

## Source evidence

The six supplied images are preserved in [references](references/01-beachfront.png): [beachfront](references/01-beachfront.png), [aerial layout](references/02-beach-layout.png), [small props](references/03-small-props.png), [furniture](references/04-furniture.png), [foliage](references/05-foliage.png), [reef](references/06-reef.png). These are visual references, not instructions embedded in a document. Images 1–2 control beachfront composition; image 6 controls the compact reef's colour and life.

[asset-scene-index.json](asset-scene-index.json) records all 1,790 converted scene filenames found locally. “Found” below means a named file exists, not that the mesh/materials/assembly have been rendered successfully. Do not confuse separate pieces such as bucket handles, wheels, sails and collision meshes with complete ready-to-use props.

Verified source root: `Assets/Synty/POLYGON_Palm_City/meshes/tscn_separate/`. The same package also has source FBX. Source conversion statistics report 1,240 FBX copied, 1,790 mesh scenes and 309 generated materials; the 2,480 FBX files in the tree include source/copied duplication. No complete demo environment scene was found outside the separate mesh scene folder.

## Full beach composition

Current blockout: approximately 160 m along a curved coastline, one quarter of the previous 640 m beach length, with the original Synty prop scale retained. The authored end-to-end walking route is about 148 m. The earlier three-minute target is superseded; the user explicitly confirmed that this 160 m layout is the desired quarter-size beach, not a request to cut it to 40 m. Keep sightlines broken by palms/towers, not arbitrary walls, and preserve all 5,700 required cleanup IDs unless a later balance decision changes that objective.

```text
BACK: minimal skyline silhouettes → promenade/low resort boundary (not enterable)

South arrival — Sports beach — Lounger terraces — Sand-play coves — Pier/lighthouse
      S1               palms + lifeguard towers              S2          S3
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ curved shoreline ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
               shallow-water play / surfboard parking / dock moorings
                          West coral beds      East coral beds
SEA: bounded playable reef; distant sailboats are scenery
```

This diagram is a composition guide; P05 records final measured coordinates. Three service points S1/S2/S3 each have a sorting table, four category bins, output rack and four large containers. A collection call at any point collects every deposited eligible bag across the beach. Station storage itself remains local. One physical equipment shop is next to S2, with a free equipment rack. Start at S1, with a visible route to the shop and starter litter nearby. Service spacing prevents long empty return walks while preserving the full coastline.

| Zone ID | Required waste | Required props | Main content and restoration |
|---|---:|---:|---|
| `arrival` | 650 | 30 | Access sand, parasols, starter service area; dune vegetation and shore birds if available |
| `sports` | 750 | 40 | Volleyball, portable speakers, balls, coolers; beach plants and wildlife routes |
| `lounges` | 950 | 100 | Chair/lounger rows, parasols and beach shelters; clean sand and turtle walk into sea |
| `sandplay` | 650 | 80 | Buckets, spades, sandcastles, storage hut; brighter coastal growth and shore life |
| `pier` | 800 | 30 | Pier approaches, mooring props, surfboard parking; clearer water and fish under dock |
| `shallows` | 600 | 20 | Floating litter, inflatables, rescue sites; returning fish and freed turtles |
| `reef_west` | 500 | 0 | Compact coral beds, buried/sunken debris and rescues; richer coral colour and fish schools |
| `reef_east` | 500 | 0 | Second limited reef patch with distinct rocks/plants; turtles, starfish and fish schools |
| **Total** | **5,400** | **300** | **5,700 required objects** |

Subdivide each zone into 2–4 clearly visible sections, except arrival's small starter section can be one. Exact section budgets must sum to the table. Default first arrival section has 80 exposed waste and 10 clean props, so the first restoration is achievable without expensive equipment. Reef beds each restore after their own task set, not only after all 1,000 reef items. A zone's larger wildlife event requires its sections complete. Each required ID belongs to exactly one section.

## Art direction and authoring rules

- Match warm pale sand, clear cyan shallows, saturated parasols/boards, readable low-poly shapes and long open shoreline from the references. Use fixed sun/sky; avoid heavy bloom that washes out white outlines. Restoration changes local cleanliness and life, not the fixed time of day.
- Keep rear city thin: a few silhouettes, a road/promenade suggestion and resort boundary. No city interiors, vehicles driving in the city, pedestrians, businesses or navigation system.
- Lifeguard houses, sorting hut and equipment shop are usable beach structures. Put only needed shelves/counters inside. Ensure door/camera/carry clearance for two-handed chairs.
- Named portable families must be pickable: chairs, loungers, parasols, coolers, balls, buckets/spades, portable speakers, boards, portable inflatables, lifebuoys, small rowboats and movable beach tents. Fixed volleyball net posts and buildings can remain structural; loose balls/net equipment are separate interactive props. Document static/pickup roles in the catalog.
- Surfboard slots plant boards upright in sand near the dock, front facing a common direction. Small boats use shallow mooring slots. Distant sailboats and larger yachts establish the setting without being required cleanup props. A non-rideable jetski can be parked scenery in the required release.
- Every reachable shelf has visible boundaries between claimable sections and enough headroom. No inaccessible upper shelf or overly narrow door can be necessary to finish. Any compatible shelf section across the beach is allowed; home-section completion credit travels with the prop.
- Handcrafted litter fields mix scattered singles, clusters near seating/food spots and several dense piles near bins. Piles remain made of collectable units. Avoid meaningless uniform noise over all sand.
- Beach trash includes floating/sunken variants and animal entanglements. Place early underwater items shallow enough to collect and surface within starter air. Deeper required work remains reachable after affordable oxygen gear.
- Underwater region is limited, with open swim lanes, distinctive coral beds and rocks. Wildlife uses simple authored looping routes. No combat, predator simulation, breeding or full ecosystem model.

## Named local candidates

All names below are exact entries in the scene index and relative to the verified source root. Packet P01 checks assembly, scale, orientation, material resolution and collision suitability before mapping a candidate to a logical asset ID.

| Role | Found candidates |
|---|---|
| Beach chairs/loungers | `SM_Prop_Beach_Chair_01.tscn`, `SM_Prop_Beach_Chair_02.tscn`, `SM_Prop_Deck_Chair_01.tscn`, `SM_Prop_Deck_Chair_02.tscn` |
| Parasols/shelters | `SM_Prop_Umbrella_01.tscn`, `SM_Prop_Umbrella_02.tscn`, `SM_Prop_Umbrella_03.tscn`, `SM_Prop_Shelter_01.tscn`, `SM_Prop_Shelter_02.tscn` |
| Small reusable props | `SM_Prop_Beach_Ball_01.tscn`, `SM_Prop_VolleyBall_01.tscn`, `SM_Prop_Bucket_01.tscn`, `SM_Prop_Bucket_01_Handle.tscn`, `SM_Prop_Spade_01.tscn` |
| Sand-play structures | `SM_Prop_Sandcastle_01.tscn`, `SM_Prop_Sandcastle_02.tscn`, `SM_Prop_Sandcastle_Flag_01.tscn` |
| Cooler | `SM_Prop_Drinks_Cooler_01.tscn`, `SM_Prop_Drinks_Cooler_02.tscn`, plus separate handles/lid/insert |
| Boards/water props | `SM_Prop_Surfboard_01.tscn`, `SM_Prop_Surfboard_02.tscn`, `SM_Prop_PaddleBoard_01.tscn`, `SM_Prop_Paddle_01.tscn`, `SM_Prop_Inflatable_01.tscn` through `SM_Prop_Inflatable_09.tscn` |
| Volleyball | `SM_Prop_VolleyBall_Net_01.tscn` |
| Beach buildings | `SM_Bld_Beach_Shop_01.tscn`, `SM_Bld_Beach_Shop_02.tscn`, `SM_Bld_Beach_Shop_03.tscn` |
| Lighthouse/pier | `SM_Bld_Lighthouse_01.tscn` with separate inserts/doors; `SM_Bld_Dock_Platform_01.tscn`, `SM_Bld_Dock_Pillar_01.tscn`, `SM_Bld_Dock_Stairs_01.tscn`, railings and corner pieces |
| Palms | `SM_Env_Tree_Palm_01_LOD0.tscn` and `_LOD1`, further palm and small palm variants |
| Cans/bottles | `SM_Prop_Drink_Can_01.tscn`, `SM_Prop_Drink_Can_Crushed_01.tscn`, `SM_Prop_Drink_Can_Pack_01.tscn`, `SM_Prop_Drink_Bottle_01.tscn`, `SM_Prop_Drink_Bottle_02.tscn` |
| Coffee/food | `SM_Prop_Drink_Coffee_01.tscn`, `SM_Prop_Drink_Coffee_02.tscn`, `SM_Prop_Food_Ice_Cream_01.tscn`, `SM_Prop_Food_Ice_Cream_02.tscn`, pizza/hotdog/taco/panini variants |
| General litter | `SM_Prop_Towel_01.tscn`, `SM_Prop_Towel_02.tscn`, `SM_Prop_Newspaper_01.tscn`, `SM_Prop_Toilet_Paper_01.tscn` through `_04`, `SM_Prop_Baggy_01.tscn` through `_05` (inspect branding before use) |
| Waste infrastructure | `SM_Prop_Trash_Bag_01.tscn`, `SM_Prop_Trash_Bag_Open_01.tscn`, `SM_Prop_Trash_Bin_01.tscn` through `_04`; table candidates `SM_Prop_Table_01.tscn`, `_02`, `_03` |
| Knife/valuables | `SM_Wep_Knife_01.tscn`, `SM_Wep_Knife_01_Blade_01.tscn`, `SM_Prop_Keys_01.tscn`; knife may need blade assembly |
| Water vehicles | `SM_Veh_Jetski_01.tscn` plus steering; `SM_Veh_Sailboat_01.tscn` plus sail/rudder, `SM_Veh_RIB_Boat_01.tscn`; `SM_Prop_WindSurf_Board_01.tscn` plus `SM_Prop_WindSurf_Sail_01_Alt.tscn` |

Do not reinterpret cooked crab/lobster food props as living wildlife. A picture of an object in a promotional sheet is not proof that this particular converted subset contains a complete model.

## Asset gaps and requests

Create logical definitions now with coloured cubes if the final candidate inspection does not resolve these. Each placeholder must have an asset ID, readable label, sensible physical size, source-search notes and replacement scene path. One reusable cube scene with exported colour/size/label is sufficient.

| Gap ID | Required content / placeholder | Audit status and next action |
|---|---|---|
| A01 | Turtle, swimming and beach-walking poses; green cube | No turtle-named scene found. User to provide compatible mesh/rig or simple poses. |
| A02 | Small reef fish, several colour variants; blue cubes | No living fish-named scene found. User to provide models; rig optional for path motion. |
| A03 | Starfish; orange cube | No matching scene name found. User to provide. |
| A04 | Coral variants, seaweed/seagrass; pink/teal cubes | No matching coral/seaweed scene names found. User to provide a small varied set. |
| A05 | Shore bird/seagull; white cube | No matching scene name found. Optional species presentation if unavailable; core fish/turtle restoration remains required with cubes. |
| A06 | Poking stick; yellow cube | No matching named tool found. User to provide. |
| A07 | Vacuum and sand cleaner; purple cubes | No matching named tools found. User to provide both. |
| A08 | Detector; cyan cube | No matching named tool found. User to provide. |
| A09 | Flippers and oxygen tank; orange/blue cubes | No matching named equipment found. User to provide. |
| A10 | Cloth; white cube | No cloth-named scene found. User to provide; do not silently use a full beach towel as a handheld cloth. |
| A11 | Six-pack rings, tangled fishing net and attached rescue variants; red/green cubes | Can-pack mesh and sports net exist, but not verified as the requested entanglement assets. Need correct separate litter models. |
| A12 | Loose straw, plastic wrapping/bag, plastic cup and plastic bottle; category-coloured cubes | Coffee/bottle/baggy candidates exist but material/type must be inspected; use cubes for specific missing forms. |
| A13 | Fries and hamburger; orange cubes | No matching burger/fries scene names found. Additional food models do not replace the requested types. |
| A14 | Oil container; dark cube | Burn-barrel candidate exists, not verified as an oil container. Need compatible sealed container. |
| A15 | Seagull residue and furniture dirt visual; brown/white cube markers | Use cube markers until user art arrives. Final stain-mask/shader treatment is project-owned rendering work, not replacement model art. |
| A16 | Lifeguard tower/house, lifebuoy, small rowboat, portable beach tent, speaker, shelf | No clear filename match for all these roles. Inspect beach shops, inflatables, shelters and remaining index; request each unresolved role explicitly. |
| A17 | First-person hands and tool grips | Character source FBX exists; separate generated mesh scenes do not prove reusable hand rigs/animations. Inspect source rig. If unsuitable, skin-coloured cubes preserve hand positions pending user art. |
| A18 | Large category container models and sorting-table fit | Bins/tables exist; verify scale and usable geometry. Cube container/table only if none can serve the role. |

## Staging and import decision

P01 creates a whitelist manifest of **selected** source scenes and their transitive materials/textures/shader dependencies. Copy that closure into `art/synty/`, rewrite only recognized `res://POLYGON_Palm_City/` and `res://shaders/` references to the staged root, preserve UID consistency, then resolve every dependency from the Beach root. Do not globally replace arbitrary text in mesh byte arrays.

Use Godot's existing converted scenes first; source FBX is a fallback when a candidate lacks necessary rig/assembly. Godot 4.6 has native [ufbx import](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), so do not require Blender or an external converter just to read a valid FBX.

Prevent the Beach editor from importing the nested conversion project and duplicated raw sources: P00 adds a documented local `.gdignore` at `Assets/Synty/` before the first root-editor import, and P01 verifies staging around it. Keep source package intact. Stage through FileAccess/offline tooling, which can read ignored files. Preserve `Assets/Synty`'s current Git-ignore rule; ignore generated licensed runtime copies as well and commit the manifest/tool so another authorized checkout can regenerate them. Do not commit the supplied Unity archive or `.godot` caches.

Inspect shader globals in the nested project before reusing its materials: wind direction/intensity, sky/light colours and water settings must exist where needed. The existing water shader is a candidate requiring renderer testing, not accepted final water. Validate one chair, can, palm, building, translucent object and water surface before bulk staging. The conversion log's missing material requires a concrete affected-asset report; its old “Import Success” only refers to the nested project.

## Visual acceptance evidence

P25 must capture the same named viewpoints before/after cleanup: arrival eye height facing the pier, a wide elevated shoreline view, chair row at player height, sorting hut interior, surface looking through shallows, and underwater reef before/after restoration. Compare layout, colour hierarchy, silhouettes, prop scale and water readability against saved references. Do not call the visual target complete from a clean console alone.
