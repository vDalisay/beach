# P11 — Cloth and dirty surfaces

Dependencies: P09, P10. Requirements: R11, R18. Read: residue/furniture accounting in requirements and content.

**Outcome:** dirty furniture must be cleaned before organized placement; loose residue remains accountable waste.

**Own files:** `scripts/tools/cloth_tool.gd`, `scripts/items/dirt_visual.gd`, `scenes/items/dirt_patch.tscn`, cloth definition, `dirt` checks.

**Steps**

1. Place 1–3 authored dirt patch anchors on eligible chairs/loungers. Dirty count comes from the manifest, never a random `_ready()` call. Follow furniture transforms while it is carried/thrown.
2. Render supplied stain art on a small surface patch; until available use the approved coloured cube marker. Use mesh/Sprite3D treatment compatible with the selected renderer, not unsupported projected Decal nodes.
3. Cloth LMB cleans one targeted patch with a brief wipe/fade and updates its remaining dirt state. On the last patch, mark the same prop clean and allow placement. Do not create new waste IDs for furniture dirt.
4. A standalone residue objective is a different definition: cloth collects that existing ID into bagged residue if capacity permits. It remains unfinished until truck collection. A full bag leaves the residue visible and unchanged.
5. Expose “E: carry” for dirty furniture so it can be moved out of the way, while primary says Needs cloth or Clean. A dirty chair thrown into storage fails the same cleanliness validation as click placement.
6. Give cloth a shop-owned definition; tests may grant it directly, but normal gameplay must purchase it through P15.

**Acceptance:** `dirt` verifies one dirty chair remains a single required prop; partly cleaned furniture stays ineligible; thrown/picked/reloaded dirt persists; residue uses one stable ID and respects bag capacity. Dirty patches never appear on every instance because of a shared material mutation.

**Handoff:** dirt anchor convention, target/action precedence, no-bag-space behavior and visual evidence. Missing stain/cloth art stays in the asset request register.
