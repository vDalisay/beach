# Asset register — C00, 23 September 2026

**Model pass, 24 September 2026:** every one of the 28 roles now has an integrated model, replacing the earlier supply-later decision for this pass. Twenty-seven are project-owned low-poly models built reproducibly by `tools/blender/build_models.py` (Blender 4.4) into `art/models/`. The first-person hands (A17) come from the licensed Synty Palm City character rig through `tools/blender/build_fp_arms.py` into the Git-ignored `art/synty/hands/`, with the project hand as the fallback. None of these roles is user-accepted final art yet; the user can still replace any of them at the same wrapper or model path. Details and evidence: [look and model pass](plan/12-look-and-model-pass.md#6-results--24-september-2026).

**Model review, 24 September 2026:** the user reviewed all 38 project models on a numbered [review sheet](handoffs/images/FIN05-models-play/model-sheet.png). 32 pass. Six were reworked:
- A11R: closed six-pack rings
- A10: a folded bath cloth
- A01: a connected turtle
- A04C: one connected sea fan
- A16L: the lookout ramp climbing into the hut
- A16B: fitted rowboat benches, with the oars as their own model on top

See the [before/after](handoffs/images/FIN05-open-items/model-fixes.png), the [refreshed sheet](handoffs/images/FIN05-open-items/model-sheet.png) and [plan 12, section 7](plan/12-look-and-model-pass.md#7-model-review-and-open-item-follow-up--24-september-2026). The user has not yet accepted the reworked six.

`data/asset_manifest.json` stages **95 Synty wrapper roles / 278 source and dependency files** (closure in [C00](handoffs/C00.md)) from the locally licensed Palm City conversion. The wrapper scene and every source component are named there. `tools/stage_assets.gd` regenerates `art/synty/`; `tests/run_checks.gd` verifies the closure and loads every wrapper. Generated/vendor files stay out of Git.

FIN-06/07 rendering update, 24 September 2026: the added dependency is the supplied `caustic_height.png`, explicitly listed in `extra_resources` and used on sand and reef rocks. Staging redirects the supplied polygon/foliage materials to attributed project shader variants and enables mipmaps for the sampled sand/water/foliage textures. This adds no asset role and does not resolve any final-art substitution below. See [C06](handoffs/C06.md#fin-06fin-07-rendering-implementation--24-september-2026).

The manifest's 28 `missing_assets` rows name each open role, its current status, the actual runtime consumer, and a replacement path. **A path is not a connection:** where the consumer is a script, passive tool, or `none`, adding a model at `replacement_path` alone will not display it. C07/C08 must wire and inspect those roles. A direct scene replacement must preserve the gameplay node contract and scale. The gallery shows these requests as placeholders; it does not prove that cubes appear in gameplay.

| Roles | What renders now | Runtime connection |
|---|---|---|
| A01 turtle | Project model, one connected shell, neck and head with animated flippers (`art/models/turtle.glb`) | `scenes/wildlife/turtle.tscn`, used by rescue sites and the lounge/reef routes; attachments drape over the shell |
| A02 fish, A03 starfish | Three reef fish species and two sea-star colours | `fish_school.gd` (one species per school, six fish, tail sway) and `starfish.gd` |
| A04C coral, A04P seaweed/seagrass | Branching, tube, fan (one connected sea fan) and brain coral; kelp and seagrass tufts | `restoration_section.gd` keeps the cluster/bed names and bleached-to-restored material tween, and batches the same meshes in the restoration coral gardens |
| A05 shore bird | Standing and flying gulls | New consumer: restored shore zones gain three standing gulls and a circling pair (no collision or saved state) |
| A06 stick, A07V vacuum, A07S sand cleaner, A08 detector, A10 cloth | Project tool models; the cloth is a folded terry washcloth | Stick wrapper `art/replacements/tools/poking_stick.tscn` via `progression.gd`; the other scenes are replaced in place |
| A09F flippers, A09T tank | Project gear models | `scene_path` on the passive tool definitions; shown resting on the equipment rack counter once owned |
| A11R rings, A11N net | Six closed six-pack rings in one web, and a tangled net with floats | Existing rescue wrappers replaced in place; attachments drape over the turtle |
| A12S straw, A12W wrap/bag, A12C carton, A13F fries, A13H hamburger, A14 oil container | Project litter models | Existing waste wrappers replaced in place (single mesh, so distant MultiMesh batching applies) |
| A15R residue, A15D furniture stain | Gull-dropping splat; grime smear | `residue_stain.tscn` replaced in place; `dirt_visual.gd` loads the stain mesh |
| A16L lookout, A16B rowboat, A16T tent, A16S shelf | LA-style lifeguard tower with a porch rail all round and a railed ramp that climbs from the sand to the deck door; wooden rowboat with separate oars (`rowboat_oars.glb`) on its benches; striped pop-up tent; storage shelf modules | Lookout scene keeps its collision; the rowboat wrapper stages `Hull` and `Oars` project components at its unchanged path; tent wrapper replaced in place; every SHELF pool builds visual-only modules |
| A17 hands | Synty `SM_Chr_Surfer_Male_01` arms with native two-bone IK and finger curls | `hand_rig.gd` creates `FirstPersonArms` when staged; the project hand remains as fallback |

The 87 staged roles include exact pack meshes and explicit substitutes. Exact named cleanup, marine, food and equipment art is **not** present in this licensed source. Some substitutions are suitable for gameplay but remain open for final fidelity. The current save/generator identity is independent of pure visual swaps; preserve wrapper paths where possible and retest runtime consumers after each swap.
