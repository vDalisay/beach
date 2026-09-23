# Asset requests

Current audit status: the P01 sample was too narrow. The playable beach now stages 84 Synty wrappers (240-file selected closure), including the supplied `SM_Prop_Drink_Bottle_01` for glass litter, a tinted drink-bottle mesh for plastic litter, crushed cans, drink cups, ice cream, sandwiches, rolled discarded towels and glass jars, plus deck chairs, outdoor table, parasols, bins and containers, sandcastles, shade structures, boats, a windsurf board with sail, skyline, pier, lighthouse and a scaled Synty pole shaft for the starter poking stick. The later reference-image pass added Synty city, low-rise, villa and art-deco window façades with their separate glass meshes, roofs, sidewalk, mountain range, planter benches, boulevard curb trim, a cloud ring, modular service-hut walls/roofs and a furnished pier-head cafe with pack-made awnings, lamps, benches, umbrellas, outdoor tables, chairs and support poles. Thirty-one of 34 item definitions use Synty meshes or Synty-based compositions; the two rescue attachments and residue stain use project-owned shapes, not cubes. The source conversion's missing material is `Lit`; it affects `SM_Env_Drawbridge_Base_01`, the left/right counter doors, one ferris-wheel glass compartment, `SM_Prop_Street_Sign_02`, and `SM_Veh_Hot_Dog_Cart_01`. None is in the selected closure.

No item definition now points to the generic cube. The rowboat uses Synty's inflatable RIB hull as an explicit visual substitute, the portable tent uses the pack's scaled `SM_Prop_Shelter_02`, and fruit scrap uses the pack's banana-food prop. These are not claims that exact rowboat, collapsible tent or fruit-peel prefabs exist. `data/asset_manifest.json` remains the machine-readable source for open fidelity requests.

| ID | Requested replacement | Cube | Approximate size (m) | Intended use | Search result |
|---|---|---|---|---|---|
| A01 | Turtle with swimming and beach-walking poses | green | 1.4 × 0.45 × 1.0 | Restoration wildlife and entanglement rescue | No turtle-named scene found. |
| A02 | Small reef fish variants | blue | 0.45 × 0.25 × 0.18 | Underwater wildlife routes | No living fish scene found. |
| A03 | Starfish | orange | 0.35 × 0.08 × 0.35 | Reef restoration | No starfish scene found. |
| A04 | Coral, seaweed, and seagrass set | pink | 0.8 × 0.9 × 0.8 | Permanent reef restoration | No matching scenes found. |
| A05 | Shore bird/seagull | white | 0.45 × 0.5 × 0.25 | Shore wildlife | No matching scene found. |
| A06 | Poking stick | yellow | 0.08 × 1.2 × 0.08 | Starter handheld tool | The live hand now uses a scaled Synty `SM_Prop_Sign_Pole_01` shaft; no dedicated cleanup-stick model was found. |
| A07 | Vacuum and sand cleaner | purple | 0.65 × 0.9 × 0.45 | Purchased cleanup tools | No matching models found. |
| A08 | Detector | cyan | 0.35 × 1.1 × 0.25 | Buried-item detection | No matching model found. |
| A09 | Flippers and oxygen tank | orange | 0.65 × 0.8 × 0.35 | Swimming equipment | No matching equipment found. |
| A10 | Cleaning cloth | white | 0.35 × 0.04 × 0.35 | Furniture cleaning | No cloth found; a beach towel is not a suitable substitute. |
| A11 | Six-pack rings, tangled net, rescue variants | red | 0.6 × 0.12 × 0.6 | Knife-removable attachments | Project-owned ring/net silhouettes replace cubes for gameplay; faithful Synty rescue art remains open. Can-pack and sports-net meshes are not verified rescue art. |
| A12 | Straw, wrap/bag and cup forms | cyan | 0.3 × 0.25 × 0.3 | PMD waste variants | Synty bottle and drink-cup geometry is staged; straw and wrap/bag forms remain open. The cup is explicitly categorized as PMD despite its composite material. |
| A13 | Fries and hamburger | orange | 0.28 × 0.18 × 0.28 | Food waste | Synty hotdog, banana food, ice cream and panini are staged; no burger/fries scene found. |
| A14 | Oil container | dark grey | 0.35 × 0.55 × 0.25 | General waste | Burn barrel is not a valid substitute. |
| A15 | Seagull residue and dirt visuals | brown | 0.3 × 0.08 × 0.3 | Residue pickup and furniture stains | Project-owned flat stain replaces the cube; exact residue mesh and furniture variants remain open. |
| A16 | Lifeguard tower, rowboat, portable tent, storage shelf | blue | 1.2 × 1.2 × 1.2 | Beach service roles | Synty dock modules/flag form lookouts; RIB dinghy and scaled `SM_Prop_Shelter_02` replace rowboat/tent cubes. A collapsible tent and storage shelf remain unverified. |
| A17 | First-person hands and grips | skin | 0.22 × 0.12 × 0.45 | Visible hands/tools | The two plain capsule placeholders were replaced with project-owned low-poly palms, fingers, thumbs and forearms. Character FBX exists, but no suitable Synty first-person rig was verified; an exact rig remains open. |

A18 is resolved: the live sorting station uses Synty's outdoor table, trash bins and sealed trash bag; its large category containers use a scaled Synty bin mesh. Physics openings and collision shells remain project-owned so sorting and bag capture continue to work.

Replacement scenes should be placed at the `replacement_path` declared for each entry in `data/asset_manifest.json`; open roles keep their current functional presentation until a replacement is validated.
