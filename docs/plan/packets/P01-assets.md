# P01 — Stage supplied assets and register gaps

Dependencies: P00. Requirements: R03, R04. Read: [asset audit](../03-world-and-assets.md).

**Outcome:** selected Palm City assets load correctly from the Beach project, and every missing role has a labelled cube and a request record.

**Own files:** `tools/stage_assets.gd`, `data/asset_manifest.json`, `art/synty/` (generated/local), `art/placeholders/missing_asset.tscn`, `scripts/items/missing_asset.gd`, `tests/scenes/asset_gallery.tscn`, `docs/asset_requests.md`. Extend root shader globals and `.gitignore` only as necessary.

**Steps**

1. Build the manifest from exact audited filenames, mapping logical asset ID to source scene and optional assembly pieces. Start with can, chair, bucket+handle, palm, beach shop, knife+blade, glass object and water test.
2. Parse resource reference declarations, collect transitive dependencies, copy into the staged hierarchy and rewrite recognized root prefixes. Preserve source originals and binary mesh arrays. Reject paths escaping the source/staging roots. Repeated staging must be idempotent.
3. Resolve or regenerate copied UID metadata where required; do not copy nested `.godot` or FBX import caches. Register needed shader globals from inspected source materials. Verify P00's `.gdignore` keeps the nested conversion project out of root imports while FileAccess staging still reads it.
4. Inspect gallery at known metre markers. Normalize through wrapper-node transforms: pivot at a useful pickup/ground point and a consistent front direction. Assemble missing pieces; exclude collision-only visual meshes. Dynamic shapes must be primitive/convex, not concave city collision meshes.
5. Expand selected candidates from the role table. Audit missing-material report against chosen dependencies. For every unresolved role, create a logical cube placeholder and record ID, colour, approximate dimensions, intended interaction, search performed, and requested replacement.
6. Stage hands from source FBX only if the rig is suitable; otherwise use the approved cubes. No substitute pack downloads.

**Acceptance:** `asset_closure` resolves every staged reference from root and detects a deliberately broken reference; second staging leaves identical hashes. Gallery shows correct textures, scale, palms/alpha, separate-object material independence and no missing shaders. Record unresolved art honestly.

**Handoff:** gallery screenshots, generated manifest, unresolved roles and reproducible staging command. No claim that a ready-made beach scene was imported.
