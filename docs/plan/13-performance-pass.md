# Performance pass

Written 25 September 2026 against `e3883f4` (content `beach-content-8`, Godot 4.6.1 Compatibility, Jolt). This pass belongs to **FIN-08** (effect and crowded-view cost) and prepares **FIN-10** (GTX 980-class target). It changes how the game renders, streams and saves. It does not change gameplay, content, collision or the save format. Final target-hardware acceptance stays open in FIN-10.

## 1. Baseline: where the frame goes

Measured with the new probe `tests/profile_views.gd` (real `main.tscn` run, seed `first-shore`, 1920×1080, vsync off) on the development machine: Ryzen 5 5600, RTX 3070, driver 595.79. `render CPU` and `GPU` are native viewport timings. Draw calls include the shadow passes.

| View | Frame median / p95 (ms) | GPU (ms) | Render CPU (ms) | Draw calls | Triangles |
|---|---:|---:|---:|---:|---:|
| Spawn, looking along the beach | 7.84 / 8.70 | 4.92 | 5.66 | 4,890 | 801 k |
| Dense lounge (C04 view) | 7.20 / 7.85 | 4.00 | 4.65 | 3,807 | 801 k |
| Along-shore | 6.86 / 7.54 | 3.66 | 4.74 | 4,040 | 746 k |
| Aerial | 7.51 / 8.17 | 4.19 | 4.78 | 3,734 | 549 k |
| Restored reef, underwater (script time 1.95 ms) | 6.28 / 8.17 | 2.21 | 1.80 | 1,194 | 401 k |

The development machine is **CPU-bound on draw-call submission**. A GTX 980 has roughly a third of the RTX 3070's shading throughput, so on the target the same scene would be **GPU-bound at about 12–15 ms**. Both costs need to come down.

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

Hitches matter as much as averages:

- **Walking stalls.** A 7 m/s sprint along the beach had p99 24–28 ms, a maximum of 40 ms and 107–253 frames over 16.7 ms. Two causes: `ItemViewManager._refresh_stream` scans all 5,421 stream candidates every 0.4 s, costing **9.5 ms**. Every streamed view also re-parses its visual `.tscn`, costing **2.0 ms**, because nothing keeps the `PackedScene` loaded. Freeing a view costs another 0.24 ms.
- **Autosave freezes.** One autosave blocks the main thread for **2.7 s, rising to 6.9 s** once both A/B generations exist. Each validation regenerates the 5,700-item manifest (1.08 s) and parses a 6.6 MB save. Autosave runs every 60 s and on every wallet change.
- **VRAM.** The Synty textures are imported lossless and without mipmaps: **1,326 MB** of RGBA8 at 2048–4096 px, out of 1,606 MB reported video memory.

## 2. Optimizations

Each item is implemented and measured again with the same probe. Checks follow the [project rule](../../AGENTS.md): playable evidence first, and a written check only for an invariant.

| Id | Optimization | Technique | Expected effect |
|---|---|---|---|
| PERF-01 | **Graphics settings tab and quality presets** | New Graphics tab in the settings menu. Settings: Low/Medium/High/Ultra preset, MSAA, 3D render scale (bilinear), shadow quality, SSAO, glow, view distance, VSync and a frame-rate cap. All persist in `settings.cfg` and apply immediately. Ultra is the previous look; the default High keeps it with the budgets below. | Scales from the RTX 3070 down to the GTX 980 target and lower. |
| PERF-02 | **Sun-shadow caster budget** | Quality-scaled cascade count, atlas size and shadow distance: 100 m by default instead of 150 m. Per-object shadow distance culling for streamed items: small litter casts within 15 m, furniture within 45 m, toggled with hysteresis in the existing streaming pass. Text labels never cast shadows. | Measured −1,150 draws and −0.6 ms GPU at defaults. The Medium preset (2 splits) saves another −830 draws and −1.3 ms. |
| PERF-03 | **Light distance fade** | `Light3D.distance_fade_*` on the hut interior lights, so they and their cube-shadow passes switch off when far away. Low and Medium drop the omni shadows. | About −1 ms GPU and −1 ms CPU away from huts. |
| PERF-04 | **Visual-scene cache** | Keep each item's visual `PackedScene` referenced after its first load. Used by item views, the sorting table, placement, carried props and rescue sites. | Streamed spawn 2.0 ms → about 0.1 ms. Faster run start and 200-item table unloads. |
| PERF-05 | **Spatial hash grid and time-sliced streaming** | Bucket stream candidates in 16 m grid cells and scan only cells within the load radius. Amortised re-bucketing keeps moved items correct. Spawns run under a per-frame time budget instead of a fixed count. | Removes the 9.5 ms scan spike every 0.4 s and fills nearby views faster. |
| PERF-06 | **Item view object pooling** | Released `WorldItem` bodies go to a pool: processing disabled, which removes them from physics; hidden; renamed. They are reconfigured for the next record instead of calling `queue_free()` and `instantiate()`. Visual children are reused when the definition matches. | Removes free/instantiate churn while walking. Ownership and save state stay in `RunState`. |
| PERF-07 | **Texture compression and mipmaps** | Staging writes VRAM-compressed (S3TC/BPTC) imports with mipmaps for every 3D texture, and RGTC for normal maps. | About −1 GB VRAM, less texture bandwidth and no distance shimmer. |
| PERF-08 | **Distant litter LOD** | Distant litter batches draw a simplified mesh: meshoptimizer LODs generated once per definition and cached. Physical views within 12 m keep the full mesh. Falls back to the full mesh if no LOD is available. | Distant-batch triangles cut by about 60%, −0.4 to −0.8 ms GPU in dense views. |
| PERF-09 | **Static scenery instancing** | After the beach builds, merge repeated static meshes into MultiMesh batches per 32 m cell: palms, shelves, hut walls, cafe sets, pier furniture, shops. Batches key on mesh, materials and shadow mode. Scripted, physical and toggled subtrees are left alone. | Fewer draw calls in both the visible and the shadow passes. |
| PERF-10 | **Spatial chunking for frustum and distance culling** | Split world-spanning MultiMeshes (city blocks, foliage groves, sidewalks, curbs, dunes) into cell chunks so frustum culling works per chunk. Give small scenery visibility ranges that scale with View distance. | Off-screen and far chunks stop drawing, for less GPU vertex and fragment work. |
| PERF-11 | **Wildlife animation LOD** | Fish schools, turtles and bird flappers skip or reduce updates when off-screen (`VisibleOnScreenNotifier3D`) or far away. Distant ones update at a lower rate with accumulated delta. The 12 entangled rescue turtles stop animating out of view. | Restored-reef script time about 1.95 → 0.6 ms. |
| PERF-12 | **Autosave without freezes** | Memoise the deterministic manifest generation per seed. Remember the generations this session has already written or validated, keyed by size and modified time. Move autosave serialisation, write and full verification to a worker thread. The main thread only captures the snapshot. Manual saves keep their synchronous result using the same caches. | Autosave stall 2.7–6.9 s → about 0.1 s. Every validation and A/B rule is unchanged. |
| PERF-13 | **Per-frame CPU cleanups** | Reuse physics query objects in the interactor (a shape was allocated every tick). Cache bone indices in the first-person arms (30 `find_bone` string lookups and formats per frame). Drop contact monitoring that no item uses. Skip the Synty shader's per-fragment `inverse(MODEL_MATRIX)` unless triplanar mapping is on. | Lower steady CPU and GPU cost; fewer allocations. |

### Graphics presets (PERF-01/02/03)

| Setting | Low | Medium | High (default) | Ultra (previous look) |
|---|---|---|---|---|
| MSAA | Off | 2× | 4× | 4× |
| 3D render scale | 75% | 100% | 100% | 100% |
| Sun shadows | 2048, 2 splits, 50 m | 2048, 2 splits, 80 m | 4096, 4 splits, 100 m | 4096, 4 splits, 150 m |
| Small / large item shadow range | none / 20 m | 10 / 30 m | 15 / 45 m | 25 / 70 m |
| Hut light shadows | off | off | within 15 m | within 30 m |
| SSAO | off | off | on | on |
| Glow | off | on | on | on |
| View distance (small scenery and litter) | 70% | 85% | 100% | 120% |

VSync and the frame-rate cap sit outside the presets. Changing any preset value shows "Custom".

## 3. Verification

- Rerun `tests/profile_views.gd` for every view, the sprint walk and `--restored`, then compare with section 1. Record the results in [the performance record](../performance.md).
- Run the existing validation scripts. Streaming, pooling and batching must keep every `RunState` ownership invariant, including the collect/throw/save/restore routes in `validate_physics.gd`, `validate_save*.gd` and `validate_full_run.gd`.
- In the running game: sprint the beach, then check pickup, throw, placement, sorting, rescue and swimming. Check settings changes apply live and persist after a restart. Compare the default High preset with the Ultra captures for shadows, litter and palms.
- An exported GTX 980-class run remains FIN-10.
