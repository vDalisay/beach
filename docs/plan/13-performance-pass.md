# Performance pass

Written 25 September 2026 against `e3883f4` (content `beach-content-8`, Godot 4.6.1 Compatibility, Jolt). This pass belongs to **FIN-08** (effect and crowded-view cost) and prepares **FIN-10** (GTX 980-class target). It changes how the game renders, streams and saves. It does not change gameplay, content, collision or the save format. Final target-hardware acceptance stays open in FIN-10.

**Status: implemented.** Twelve optimizations are in. Two more were measured and not adopted (section 3). Results are in section 4. [Raw baseline](../handoffs/images/PERF-performance-pass/baseline_profile.txt) and [final profiles](../handoffs/images/PERF-performance-pass/profile.txt).

## 1. Baseline: where the frame went

Measured with the new probe `tests/profile_views.gd` (real `main.tscn` run, seed `first-shore`, 1920×1080, vsync off) on the development machine: Ryzen 5 5600, RTX 3070, driver 595.79. `render CPU` and `GPU` are native viewport timings. Draw calls include the shadow passes.

| View | Frame median / p95 (ms) | GPU (ms) | Render CPU (ms) | Draw calls | Triangles |
|---|---:|---:|---:|---:|---:|
| Spawn, looking along the beach | 7.84 / 8.70 | 4.92 | 5.66 | 4,890 | 801 k |
| Dense lounge (C04 view) | 7.20 / 7.85 | 4.00 | 4.65 | 3,807 | 801 k |
| Along-shore | 6.86 / 7.54 | 3.66 | 4.74 | 4,040 | 746 k |
| Aerial | 7.51 / 8.17 | 4.19 | 4.78 | 3,734 | 549 k |
| Restored reef, underwater (script time 1.95 ms) | 6.28 / 8.17 | 2.21 | 1.80 | 1,194 | 401 k |

The development machine is **CPU-bound on draw-call submission**. A GTX 980 has roughly a third of the RTX 3070's shading throughput, so on the target the same scene would be **GPU-bound at about 12–15 ms**. Both costs needed to come down.

Removing one group or effect at a time from the spawn view gives this breakdown:

| Removed | Draw calls | GPU (ms) | Frame (ms) |
|---|---:|---:|---:|
| Sun shadows | −3,146 | −3.21 | −2.78 |
| Loose-item views and their shadows | −2,023 | −2.31 | −1.82 |
| Three hut interior lights (omni shadows) | −191 | −1.21 | −0.96 |
| Distant litter batches (386 k triangles in the lounge view) | −120 | −0.7 to −1.3 | −0.4 to −1.2 |
| Backdrop city | −167 | −0.86 | −0.64 |
| MSAA 4× | 0 | −0.3 to −0.8 | −0.3 to −0.6 |
| SSAO / glow | 0 | −0.1 / −0.3 | small |

Hitches mattered as much as averages:

- **Walking stalls.** A 7 m/s sprint along the beach had p99 24–28 ms, a maximum of 40 ms and 107–253 frames over 16.7 ms. Two causes: `ItemViewManager._refresh_stream` scanned all 5,421 stream candidates every 0.4 s, costing **9.5 ms**. Every streamed view also re-parsed its visual `.tscn`, costing **2.0 ms**, because nothing kept the `PackedScene` loaded. Freeing a view cost another 0.24 ms.
- **Autosave freezes.** One autosave blocked the main thread for **2.7 s, rising to 6.9 s** once both A/B generations existed. Each validation regenerated the 5,700-item manifest (1.08 s) and parsed a 6.6 MB save. Autosave runs every 60 s and on every wallet change.
- **Shader compilation.** With a cold shader cache (first run, fresh install), the first draw of an uncompiled variant froze a sprint for **974 ms**.
- **VRAM.** The Synty textures were imported lossless and without mipmaps: **1,326 MB** of RGBA8 at 2048–4096 px, out of 1,606 MB reported video memory.

## 2. Optimizations

| Id | Optimization | What was built | Measured effect |
|---|---|---|---|
| PERF-01 | **Graphics settings tab and quality presets** | New Graphics tab in the settings menu. Settings: Low/Medium/High/Ultra preset (Custom when mixed), MSAA, 3D render scale (bilinear), shadow quality, SSAO, glow, detail view distance (visibility ranges and mesh LOD threshold), VSync and a frame-rate cap. All persist in `settings.cfg` and apply live. LB/RB switch tabs; the controller focus chain is per tab. | Spawn-view GPU is 4.92 ms before; after, Ultra 3.74, High 3.27, Medium 1.79 and Low 1.35 ms. |
| PERF-02 | **Sun-shadow caster budget** | `RenderQuality` sets cascade count, atlas size, filter and shadow distance per quality (100 m on High instead of 150 m). Streamed items cast sun shadows only within a per-quality distance (High: litter 15 m, furniture 45 m), toggled with hysteresis during view upkeep. 3D text labels never cast shadows. | Included in the High results below: spawn draws 4,890 → 2,967. |
| PERF-03 | **Light distance fade** | Hut interior lights fade out beyond 40–48 m, and their cube shadows beyond 15 m (High) or 30 m (Ultra). Low and Medium drop the omni shadows. | About −1 ms GPU and −1 ms CPU when away from huts. |
| PERF-04 | **Visual-scene cache** | `ItemDefinition.visual_scene()` and `ToolDefinition.scene()` keep each `PackedScene` loaded. Used by item views, the sorting table, placement, carried props, rescue sites and tool switches. | Streamed spawn 2.35 → 0.09 ms. Item-view build at run start 2,938 → 300 ms; run start 4.2 → 1.8 s. |
| PERF-05 | **Spatial hash grid and time-sliced streaming** | Stream candidates are bucketed in 16 m cells, in two grids by load radius (12 m batched litter, 45 m other). A refresh every 0.25 s scans only nearby cells; an amortised slice re-buckets moved records. Spawns run under a 1.2 ms per-frame budget. Demotion and shadow checks visit 48 views per frame. | Refresh 9.5 → 0.8 ms; upkeep 0.1 ms per frame. |
| PERF-06 | **Item view object pooling** | Released `WorldItem` bodies go to a 96-view pool: processing disabled (removed from physics), hidden and detached from their record. They are reconfigured for the next record, keeping the visual when the model matches. The unused per-body contact monitoring was removed. | Release 0.24 → 0.01 ms; reuse 0.07 ms. |
| PERF-07 | **Texture compression and mipmaps** | Staging writes VRAM-compressed (S3TC/BPTC, RGTC for normal maps) imports with mipmaps for every 3D texture. `tools/stage_assets.gd -- --imports-only` reconfigures an existing staging. | Video memory 1,606 → 432 MB. Texture-bound views −0.2 to −0.45 ms GPU. Distant fronds no longer alias. |
| PERF-08 | **Shader warm-up** *(replaces the planned litter LOD)* | `ShaderWarmup` draws one proxy per mesh, material and instancing combination: every run node, every item and tool scene, labels, and the hover, ghost and sweep materials. They draw in an offscreen view sharing the beach's world, under sunlight, a shadowed hut-style light and an unshadowed one, then free themselves. | Cold-cache sprint maximum 974 → 25 ms. The one-time cost (0.8 s cold, 0.27 s warm) lands on the loading frame. |
| PERF-09 | **Static scenery instancing** | `SceneryBatcher` merges identical static meshes under the scenery roots, hut visuals and shelf pools into one MultiMesh per 16 m cell. Scripted, physical and `unbatched` subtrees (the hut roof the table hides) are left alone; replaced nodes stay hidden in the tree. | −500 draw calls (14–17%) in dense views; lounge GPU −0.3 ms. Frame time was within noise on the RTX 3070; weaker GL drivers pay more per call. |
| PERF-11 | **Wildlife animation LOD** | `PresentationLOD` pauses fish flocks, turtle poses, wing flaps and particle writes when off-screen or out of range. Distant animals update every second or fourth frame with the time they missed. Tangled rescue turtles skip their struggle off-screen. | Restored lounge script time 0.82 → 0.60 ms, pier 0.85 → 0.63 ms. The reef with schools up close is unchanged at 1.9 ms: a school step costs 0.1 ms. |
| PERF-12 | **Autosave without freezes** | Validation reuses one manifest (with canonical text and row index) per seed. Generation files this process already checked are skipped while size and time match, and listing summaries are cached. Autosaves capture on the main thread, then serialise, write and fully verify on a worker. Loads and listings wait for an in-flight write; the service finishes it before being freed. | Autosave main thread 2.7–6.9 s → 70 ms. Manual save 1.2 s. Pause-menu slot summaries 673 → 1 ms. |
| PERF-13 | **Per-frame CPU cleanups** | First-person arms cache finger bone indices and skip settled grips (were 30 name lookups and formats per frame). The interactor reuses its physics query objects (was allocating a capsule every tick). The Synty surface shader inverts the model matrix only for triplanar materials. Small labels stop drawing past 20–40 m. | Small steady CPU and GPU savings; fewer allocations. |

### Graphics presets

| Setting | Low | Medium | High (default) | Ultra |
|---|---|---|---|---|
| MSAA | Off | 2× | 4× | 4× |
| 3D render scale | 75% | 100% | 100% | 100% |
| Sun shadows | 2048, 2 splits, 50 m | 2048, 2 splits, 80 m | 4096, 4 splits, 100 m | 4096, 4 splits, 150 m (previous) |
| Small / large item shadow range | none / 20 m | 10 / 30 m | 15 / 45 m | 25 / 70 m |
| Hut light shadows | off | off | within 15 m | within 30 m |
| SSAO | off | off | on | on |
| Glow | off | on | on | on |
| Detail view distance | 70% | 85% | 100% | 120% |
| Beach detail ([B06](15-beach-terrain-pass.md#b06--sand-detail-and-the-swash)) | Low: waves, one grain layer | Medium: + ripples, relief, shells | High: + glints | High |

VSync and the frame-rate cap sit outside the presets. Beach detail can also be set to Off (plain sand, a still wet strip, no waves on the sand). [High against Ultra](../handoffs/images/PERF-performance-pass/ultra_vs_high.jpg) differs only in the smallest distant shadows. [Low](../handoffs/images/PERF-performance-pass/high_vs_low.jpg) drops small-litter shadows, SSAO and glow and renders 3D at 75%. [The Graphics tab](../handoffs/images/PERF-performance-pass/graphics_tab.jpg).

## 3. Measured and not adopted

- **Distant litter LOD (original PERF-08).** The imported litter models already carry LODs, and the engine's automatic LOD thins their batches with distance: food-scrap batches draw 4 k triangles with it, against 63 k at full detail. Generated chains for the LOD-less meshes (cans, bottles, cups) cut 213–350 k triangles per view. GPU time was 0.15 ms *slower* in same-session A/B runs, so litter triangles are not the bottleneck here. Runtime `ImporterMesh.generate_lods()` does work in the 4.6.1 release template if it is needed later.
- **Spatial chunking of the backdrop MultiMeshes (original PERF-10).** The engine measures a MultiMesh's LOD distance against its whole bounding box, so the world-spanning palm and bush sets drew at a coarse LOD. Splitting them into 48–64 m cells brought nearby foliage back to full detail: city-view triangles rose 188 k → 266 k and draw calls 288 → 416. Frustum culling saved less than that, so the sets stay whole. The buildings (no LODs) gained nothing measurable either.

## 4. Results

Same probe, machine and seed. Draw calls, triangles and objects are medians. Frame p95 on this shared development machine varies by ±2 ms between runs; the GPU and median columns are stable.

| View | Frame median before → High | GPU before → High (ms) | Render CPU before → High (ms) | Draw calls before → High |
|---|---:|---:|---:|---:|
| Spawn | 7.84 → 6.81 | 4.92 → 3.27 | 5.66 → 4.72 | 4,890 → 2,967 |
| Dense lounge | 7.20 → 6.01 | 4.00 → 3.06 | 4.65 → 3.78 | 3,807 → 2,498 |
| Along-shore | 6.86 → 5.88 | 3.66 → 2.65 | 4.74 → 3.61 | 4,040 → 2,245 |
| Sea | 4.12 → 4.14 | 1.73 → 1.62 | 1.79 → 1.73 | 1,206 → 971 |
| Pier | 5.40 → 5.03 | 2.17 → 1.75 | 2.47 → 2.48 | 2,034 → 1,637 |
| City | 3.85 → 3.41 | 2.02 → 1.54 | 1.22 → 1.21 | 341 → 288 |
| Reef (underwater) | 4.34 → 4.26 | 1.82 → 1.74 | 1.52 → 1.56 | 1,040 → 954 |
| Aerial | 7.51 → 5.63 | 4.19 → 2.37 | 4.78 → 2.78 | 3,734 → 1,746 |

| Spawn view by preset | Frame median (ms) | GPU (ms) | Render CPU (ms) | Draw calls |
|---|---:|---:|---:|---:|
| Before (previous settings) | 7.84 | 4.92 | 5.66 | 4,890 |
| Ultra | 7.29 | 3.74 | 4.98 | 3,566 |
| High (default) | 6.81 | 3.27 | 4.72 | 2,967 |
| Medium | 5.12 | 1.79 | 3.48 | 2,107 |
| Low | 4.80 | 1.35 | 3.32 | 1,560 |

| Sprint along the beach, 7 m/s | p95 (ms) | p99 (ms) | Max (ms) | Frames over 16.7 ms |
|---|---:|---:|---:|---:|
| Before | 15.74 | 23.94 | 40.29 | 107 |
| High | 8.66 | 9.55 | 22.34 | 2 |
| Before, everything restored | 20.66 | 27.60 | 36.05 | 253 |
| High, everything restored | 6.85 | 8.09 | 11.50 | 0 |

With everything restored, High also brings the lounge from 10.01 to 6.59 ms (GPU 5.69 → 3.64) and the aerial from 10.12 to 5.44 ms (GPU 5.53 → 2.24). Run start is 4.2 → 1.8 s, video memory 1,606 → 432 MB. Godot static memory rises 172 → 206 MB for the scene, manifest and view caches.

## 5. Verification

- Every existing validation script passes. Headless: `run_checks` and the `validate_*` scripts, including the save, save-physics, sorting, completion, rescue, wildlife, placement, dirt, scanner, faint, payment, purchase, sealing, buried, content-economy, release-seed, release-pack, traversal and full-run checks. With a window: `validate_physics` and `validate_pier_art`. `validate_physics` needs a window, because the headless dummy renderer does not keep MultiMesh transforms.
- In the running game: presets were applied from the Graphics tab and checked on the sun, lights, environment and viewport, persisting to `settings.cfg`. Captures at each preset were compared against Ultra. Streaming was checked by sprinting the beach, the batched pickup and promotion flow was confirmed rendered, and autosave frame times were measured during play.
- Still open (FIN-10): exported-build and GTX 980-class / 8 GB measurements, and a long-session memory check. Reproduce with `tests/profile_views.gd` (add `--graphics=<preset>`, `--restored`, `--breakdown`).
