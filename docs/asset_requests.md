# Asset register — C00, 23 September 2026

**Supply decision, 24 September 2026:** the user will supply the 28 final-art roles below. Retain their existing visuals until the supplied models can be integrated and reviewed. The current FIN-05 continuation covers coast/backdrop geometry and habitat composition with existing assets; it does not create or accept replacement art.

`data/asset_manifest.json` stages **87 Synty wrapper roles / 246 source and dependency files** from the locally licensed Palm City conversion. The wrapper scene and every source component are named there. `tools/stage_assets.gd` regenerates `art/synty/`; `tests/run_checks.gd` verifies the closure and loads every wrapper. Generated/vendor files stay out of Git.

FIN-06/07 rendering update, 24 September 2026: the added dependency is the supplied `caustic_height.png`, explicitly listed in `extra_resources` and used on sand and reef rocks. Staging redirects the supplied polygon/foliage materials to attributed project shader variants and enables mipmaps for the sampled sand/water/foliage textures. This adds no asset role and does not resolve any final-art substitution below. See [C06](handoffs/C06.md#fin-06fin-07-rendering-implementation--24-september-2026).

The manifest's 28 `missing_assets` rows name each open role, its current status, the actual runtime consumer, and a replacement path. **A path is not a connection:** where the consumer is a script, passive tool, or `none`, adding a model at `replacement_path` alone will not display it. C07/C08 must wire and inspect those roles. A direct scene replacement must preserve the gameplay node contract and scale. The gallery shows these requests as placeholders; it does not prove that cubes appear in gameplay.

| Roles | What renders now | Runtime connection / remaining work |
|---|---|---|
| A01 turtle | Project-owned low-poly scene | `scenes/wildlife/turtle.tscn` is loaded by restoration; direct visual replacement is possible. |
| A02 fish, A03 starfish | Project-owned procedural meshes | `fish_school.gd` and `starfish.gd` construct their visuals; supplied models need integration there. |
| A04C coral, A04P seaweed/seagrass | Subdued coral present before cleanup, brightened on restoration; narrow seagrass ribbons beside reef rocks | `restoration_section.gd` builds both as provisional project art. Distinct supplied seaweed/coral models still need to be connected and checked in the playable reef. |
| A05 shore bird | None | No runtime consumer yet; C07 adds one if art is supplied. |
| A06 stick | Scaled Synty sign pole, an explicit substitute | `progression.gd` loads the generated wrapper; a new model needs a scene-path edit. |
| A07V vacuum, A07S sand cleaner, A08 detector, A10 cloth | Project-owned primitive visual scenes | Each `data/tools/*.tres` points to its named `scenes/tools/*.tscn`; those scenes can be replaced in place. |
| A09F flippers, A09T tank | Passive gameplay only; no worn models | The tool resources have no visual scene contract; C08 must add presentation when models exist. |
| A11R rings, A11N net | Project-owned rescue silhouettes | Each item definition points to its matching `art/replacements/waste/*.tscn`; direct replacement is possible. |
| A12S straw, A12W wrap/bag, A12C carton, A13F fries, A13H hamburger, A14 oil container | Distinct item definitions and labelled, coloured project placeholders | C05 wires each definition to its matching runtime scene under `art/replacements/waste/`. The named final models remain missing; replacing a scene at that path reaches world, table and placement presentation. |
| A15R residue, A15D furniture stain | Flat project-owned residue/stain | Residue item points to `residue_stain.tscn`; `dirt_visual.gd` constructs furniture stains and needs a scene hook. |
| A16L lookout, A16B rowboat, A16T tent, A16S shelf | Synty dock/flag lookout, RIB hull, scaled Synty shelter, project-owned storage | Lookout scene and tent visual can be replaced in place. Rowboat definition points to the Synty wrapper; shelf geometry is in the beach scene. |
| A17 hands | Project-owned low-poly scene | `scenes/player/player.tscn` instances `art/first_person_hand.tscn`; direct visual replacement is possible. |

The 87 staged roles include exact pack meshes and explicit substitutes. Exact named cleanup, marine, food and equipment art is **not** present in this licensed source. Some substitutions are suitable for gameplay but remain open for final fidelity. The current save/generator identity is independent of pure visual swaps; preserve wrapper paths where possible and retest runtime consumers after each swap.
