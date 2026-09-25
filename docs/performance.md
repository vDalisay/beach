# Performance measurements — P28

## Performance pass — 25 September 2026

The [performance pass](plan/13-performance-pass.md) adds a Graphics settings tab with Low/Medium/High/Ultra presets. It also adds sun-shadow and hut-light budgets, pooled grid-streamed item views, a visual-scene cache, VRAM-compressed mipmapped textures, shader warm-up, static scenery instancing, wildlife animation LOD and background autosaves. The new probe `tests/profile_views.gd` measured it on the same Ryzen 5 5600 / RTX 3070 / driver 595.79 at 1920×1080, Godot 4.6.1 Compatibility, seed `first-shore`, vsync off. The probe runs the real `main.tscn` over eight fixed views plus a 7 m/s sprint; `--restored`, `--graphics=<preset>` and `--breakdown` are optional. [Baseline](handoffs/images/PERF-performance-pass/baseline_profile.txt) and [final](handoffs/images/PERF-performance-pass/profile.txt) outputs are recorded.

| Default High preset | Before | After |
|---|---:|---:|
| Spawn frame median / GPU / draw calls | 7.84 ms / 4.92 ms / 4,890 | 6.81 ms / 3.27 ms / 2,967 |
| Dense lounge frame median / GPU / draw calls | 7.20 ms / 4.00 ms / 3,807 | 6.01 ms / 3.06 ms / 2,498 |
| Aerial frame median / GPU / draw calls | 7.51 ms / 4.19 ms / 3,734 | 5.63 ms / 2.37 ms / 1,746 |
| Sprint p99 / max / frames over 16.7 ms | 23.9 / 40.3 ms / 107 | 9.6 / 22.3 ms / 2 |
| Restored sprint p99 / max / frames over 16.7 ms | 27.6 / 36.1 ms / 253 | 8.1 / 11.5 ms / 0 |
| Autosave main-thread block | 2.7–6.9 s | about 70 ms |
| Cold-shader-cache worst frame while sprinting | 974 ms | 25 ms |
| Run start / item-view build | 4.2 s / 2,938 ms | 1.8 s / 300 ms |
| Godot video / static memory | 1,606 / 172 MB | 432 / 206 MB |

Spawn-view GPU by preset: Ultra 3.74 ms, High 3.27, Medium 1.79, Low 1.35. For scale, a GTX 980 has about a third of this GPU's shading throughput, so Medium or Low is the expected starting point there. Distant-litter LOD and backdrop MultiMesh chunking were measured and not adopted (plan section 3). Frame p95 varies by about ±2 ms between runs on this shared machine. Target-hardware, exported-build and long-session gates remain open.

## FIN-05 open-item follow-up — 24 September 2026

This sample covers the city grid, reef gardens, view-model FOV and distant-litter colour fix from [plan 12, section 7](plan/12-look-and-model-pass.md#7-model-review-and-open-item-follow-up--24-september-2026). Machine and settings are unchanged: Ryzen 5 5600, RTX 3070, driver 595.79, 1920×1080, Godot 4.6.1 Compatibility.

| Crowded shore profile (`validate_physics.gd -- --profile --c04-dense`) | Previous | Two quiet runs |
|---|---:|---:|
| Median frame | 6.94 ms | 7.15 / 7.27 ms |
| Mean frame | 7.87 ms | 8.54 / 8.40 ms |
| p95 frame | 16.67 ms | 17.24 / 16.40 ms |
| Maximum draw calls | 3,640 | 3,659 |
| Godot video memory | 1,608.4 MB | about 1,610 MB |

A third run made while another heavy process was active gave 8.64 ms median and 19.89 ms p95 and is excluded; machine load moved the numbers more than the change did. The p95 stays within the earlier variance.

In-place cost, from GPU medians: the new geometry was toggled with vsync off, 60 warm-up and 300 measured frames per state, using native viewport timing. The probes are [reef_profile](handoffs/images/FIN05-open-items/reef_profile.gd.txt) and [city_profile](handoffs/images/FIN05-open-items/city_profile.gd.txt).

| Views | Without | With |
|---|---:|---:|
| Restored reef (3 views; 4,368 garden and regrowth pieces) | 1.17–1.29 ms | 2.01–2.28 ms |
| City from the boulevard | 1.73 ms | 2.08 ms |
| Along-shore | 3.56 ms | 4.08 ms |
| Aerial | 3.85 ms | 4.78 ms |

Frame and CPU columns in those probes vary with item streaming as the camera moves, so only GPU time is quoted. The distant-litter fix adds white instance colours only: 322 batches and 5,027 batched items, as before. Target-hardware, packaged and extended-session gates remain open.

## FIN-05 look and model pass — 24 September 2026

This sample covers the project models, palm variants, cumulus band, Synty arms and palette changes from the [look and model pass](plan/12-look-and-model-pass.md). It used the same crowded source-scene profile (`tests/validate_physics.gd -- --profile --c04-dense`, 1920×1080, 4× MSAA) on Ryzen 5 5600 / RTX 3070 / driver 595.79 and exited 0.

| Metric | Previous | This pass |
|---|---:|---:|
| Median frame | 7.90 ms | 6.94 ms |
| Mean frame | 9.24 ms | 7.87 ms |
| p95 frame | 16.53 ms | 16.67 ms |
| Maximum draw calls | 4,690 | 3,640 |
| Nodes | 13,246 | 9,468 |
| Full nearby item views | 1,209 | 608 |
| Distant batches | 217 | 322 |
| Batched distant items | 3,983 | 5,027 |
| Godot static / video memory | 184.3 / 1,428.6 MB | 172.1 / 1,608.4 MB |

The six former placeholder waste types were a box mesh plus a label, which `DistantItemVisuals` cannot batch. Their single-mesh models now join the distant MultiMeshes, which accounts for the lower view, node and draw counts. Video memory rose by about 180 MB with the extra palm/bush variants, cloud and model meshes and the arm atlas material. The p95 lies within the variance recorded below, so no p95 change is claimed. [Raw output](handoffs/images/FIN05-models/profile.txt). Target-hardware, packaged, restored worst-view and extended-session gates remain open.

## FIN-05 composition continuation — 24 September 2026

After the continuous mainland, 51 batched inland palms, one additional existing mountain instance and rearranged existing reef habitat, the same crowded source-scene profile ran in Godot 4.6.1 Compatibility at 1920×1080 with 4× MSAA on Ryzen 5 5600 / RTX 3070 / driver 595.79. Across 600 frames: median 7.90 ms, mean 9.24 ms, p95 16.53 ms, average physics monitor 1.37 ms, maximum draws 4,690, Godot static/video memory 184.3/1,428.6 MB, 13,246 nodes and zero awake bodies. The item-view build substep took 3,223.7 ms. [Raw output](handoffs/images/FIN05-composition-final/profile.txt), [change and gameplay evidence](handoffs/C04.md#continuous-mainland-and-existing-habitat-composition--24-september-2026).

The previous first all-effects FIN-06/07 sample had 4,686 draws / p95 17.23 ms and its later warmed sample had p95 10.88 ms. This variability prevents attributing a p95 gain to the scenery changes. The current run does not collect separate native GPU timing; memory values are engine monitors rather than process/board telemetry. Target-hardware, packaged, restored worst-view and extended-session gates remain open.

## FIN-06/07 rendering pass — 24 September 2026

Current source review: Godot 4.6.1 Mono Compatibility, content-8, seed `first-shore`, Windows / Ryzen 5 5600 / RTX 3070 / driver 595.79, 1920×1080. The existing crowded shore profile uses 4× MSAA, 4096 directional shadows and the retained lighting/water/environment resources from [C06](handoffs/C06.md#fin-06fin-07-rendering-implementation--24-september-2026). It runs 600 measured frames per setting after 90 warmup frames, disabling one effect at a time and restoring the original resources afterward. CPU/GPU render columns are native viewport timing medians; full-frame median/p95 are wall-clock samples. [Raw output](handoffs/images/FIN08-final/profile.txt).

| Same crowded view | Frame median / p95 (ms) | Render CPU / GPU median (ms) | Max draws | Godot video MB |
|---|---:|---:|---:|---:|
| Retained effects | 8.96 / 17.23 | 5.90 / 4.68 | 4,686 | 1,428.4 |
| SSAO off | 8.34 / 10.30 | 5.81 / 4.49 | 4,545 | 1,428.4 |
| Glow off | 8.04 / 10.19 | 5.65 / 4.18 | 4,545 | 1,428.4 |
| Grade off | 8.60 / 10.68 | 5.92 / 4.64 | 4,545 | 1,428.4 |
| Fog off | 8.25 / 10.26 | 5.86 / 4.47 | 4,545 | 1,428.4 |
| Caustics off | 8.45 / 10.68 | 5.79 / 4.53 | 4,545 | 1,428.4 |

With all settings restored, a further 600-frame sample measured median 8.66 ms, mean 9.10 ms and p95 10.88 ms, 4,545 maximum draws, 3.34 ms mean physics monitor, 183.5 MB Godot static memory and zero awake bodies. The initial sample still has more draws while streaming settles; its p95 difference is not an isolated SSAO/effect cost. These short samples give native effect-cost observations on the development GPU, not target-hardware certification or a guaranteed added-GPU-time budget.

The [pre-pass baseline](handoffs/images/FIN06-baseline/profile.txt), same dense view and 600-frame protocol before effects/MSAA changes, measured mean 8.01 ms / p95 14.34 ms, 4,967 maximum draws, 184.7 MB static and 1,350.1 MB video memory. It did not record native GPU timing or frame median, so no precise baseline GPU delta is claimed. Current static/video values are engine monitors, not process-resident/dedicated-board telemetry. The source tree was exercised directly; no new exported candidate was profiled.

FIN-08 still needs final assets/presentation and restored worst-view comparison; FIN-10 needs GTX 980-class / 8 GB, exported cold-start/stress/extended-session measurements and a clean machine. Keep the reduction order if measurements require it: SSAO, 4×→2× MSAA, glow, then shadow range/resolution. The prior measurements below remain historical.

## Earlier measurements

Current-status note, 24 September 2026: after the final S2 bin/phone position, the content-8 C04 dense lounge view had a workspace sample with Godot 4.6.1 Compatibility at 1920×1080 on Ryzen 5 5600 / RTX 3070. Across 600 rendered frames: 7.84 ms average / 13.94 ms p95 frame time, 1.41 ms average physics monitor, 4,938 maximum draw calls, 1,209 nearby views and 3,983 batched distant items. Initial nearby-view build took 2,932 ms; Godot reported 185.6 MB static and 1,356.3 MB video memory. The command was `tests/validate_physics.gd -- --profile --c04-dense` and exited 0. Two preceding same-view samples measured 7.96/14.18 and 7.94/14.30 ms average/p95, so small differences are not attributed to the bins. This is a crowded initial player-height view, not the restored occupied worst view. C09 still owns exported Godot 4.6.1 target-hardware and extended-session acceptance. The samples below are historical and do not prove that gate.

Status: development-machine optimization measured on 23 September 2026. A Windows candidate export now exists, but it has not been profiled; GTX 980-class / 8 GB system-RAM performance remains unverified.

Test: Godot 4.6.1 Mono, OpenGL 3.3 Compatibility renderer, Windows, AMD Ryzen 5 5600, NVIDIA GeForce RTX 3070, driver 595.79, 1920×1080, default settings, full 5,700-required-item `first-shore` run. `tests/validate_physics.gd` times the synchronous item-view build and 120 visible frames after scene start. Frame times are wall-clock samples, not GPU timestamps; the static/video memory values are Godot monitors, not process private bytes or dedicated-board telemetry. The later exported build was not profiled, and no GTX 980 compliance is inferred.

| Same-machine 1080p pass | All views, no distance cull | All views, 95 m small-item draw limit | 150 m nearby streaming + draw limit |
|---|---:|---:|---:|
| WORLD records | 5,376 | 5,376 | 5,376 |
| Instantiated views after startup | 5,376 | 5,376 | 1,551 |
| Instantiated meshes | 10,918 | 10,918 | 3,240 |
| Scene nodes | 41,341 | 41,341 | 14,626 |
| Synchronous view build | 19,039 ms | 20,137 ms | 6,144 ms |
| Frame mean / p95 | 11.36 / 15.31 ms | 6.96 / 11.60 ms | 6.79 / 12.22 ms |
| Maximum visible draw calls | 11,644 | 4,714 | 4,714 |
| Mean physics time | 3.98 ms | 0.92 ms | 2.53 ms |
| Godot static memory | 263.9 MB | 264.1 MB | 180.6 MB |
| Godot video-memory monitor | 954.8 MB | 954.8 MB | 954.8 MB |
| Awake rigid bodies at rest | 0 | 0 | 0 |

The first measured cost was 11,644 visible draws, so small resting item meshes now use Godot's native 95 m visibility range; the 1080p draw count fell to 4,714 without changing target/collision range. The separate 19–20 s full-view startup cost justified streaming ordinary resting small WORLD records. The initial 150 m radius creates nearby bodies; at most two new views are promoted per frame as the player approaches. Farther than 200 m, only frozen/asleep, non-highlighted small views demote after synchronizing their transform. Large props and active/thrown/highlighted bodies remain ordinary views. Every logical ID stays in `RunState`; thrown/revealed items can still obtain a physical view explicitly. Scanner global queries read a moving view when it already exists but do not instantiate thousands of distant items. There is no per-cell batch or new draw framework because the measured native cull/stream path addressed the observed costs.

Playable verification: the shared physics lab threw and settled active can/ball/chair bodies, tested a four-can pile and safe out-of-bounds recovery, then opened the full manifest. A distant sleeping litter ID appeared when the player moved to it, disappeared when the player returned, and remained WORLD in a valid ownership snapshot. Full-beach traversal covered 13 waypoints / 631.1 m. The separate real-scene checks passed buried reveal, all 24 rescue cuts, 500-item reef truck completion, physical save/restore of moving and settled items, scanner, slot capture, sorting and ten-seed manifest/ownership validation. No required count was reduced. The full world still has only zero awake bodies at rest.

Limits: the 120-frame sample is short and the three runs can vary with caching, scheduling and camera position; the physics-time change is not assigned to one optimization. The ~6.1 s synchronous nearby-view build is still noticeable and needs a cold-start usability pass. GPU monitor values did not fall with view streaming, so imported texture/resource retention needs separate inspection. Densest-mountain, 200-cell table, vacuum peak, coastline, restored reef, faint, late scanner and extended throw/save routes were checked for correctness in packet scenes, not timed as a 95th-percentile exported stress matrix. CPU driver/OS and memory behavior on the target hardware remain release gates, not passes.

Reference-image scene pass, same development RTX 3070 at 1920×1080: 1,551 nearby item views, 14,799 scene nodes, 4,837 maximum draw calls, 6,053 ms synchronous nearby-view build, 6.86 ms mean / 13.77 ms p95 over 120 visible frames, 182.4 MB Godot static memory and 1,186.7 MB Godot video-memory monitor. This is a separate short sample after adding Synty city façades, sidewalk, mountain and palms; it does not update the baseline table or establish target-hardware/export compliance.

After correcting the culled water mesh and warming sand/pavement, the same short 1080p scene sample measured 1,551 nearby views, 14,799 nodes, 4,837 maximum draw calls, 6,091 ms synchronous nearby-view build, 7.14 ms mean / 12.74 ms p95, 182.4 MB static memory and 1,186.7 MB video-memory monitor. The water is now visibly rendered, but this remains a development-GPU sample, not the GTX 980-class release gate.

After adding the Synty boulevard, planters, palms and lighthouse paint, the short scene sample measured 1,551 nearby views, 14,984 nodes, 4,964 maximum draw calls, 6,119 ms synchronous nearby-view build, 7.46 ms mean / 14.04 ms p95, 183.1 MB static memory and 1,336.3 MB video-memory monitor. The extra art remains under 16.67 ms p95 on this RTX 3070 sample; exported-build/target-hardware performance is still unverified.

After adding the Synty cloud ring and service-hut modules, two further 120-frame visible 1080p samples each had 1,551 nearby views, 15,059 nodes, 5,021 maximum draw calls, 183.3 MB static memory and 1,337.1 MB video-memory monitor. Startup nearby-view build was 6,434–6,636 ms. Frame p95 was 8.13 and 7.78 ms; the Godot physics-time monitor varied sharply (22.77 and 14.92 ms), so these brief samples are not evidence of stable physics timing. A longer exported-build run on target hardware remains open.

With 12 additional Synty palms at the beach activity edge, the same short visible-scene sample measured 1,551 nearby views, 15,095 nodes, 5,049 maximum draw calls, 6,241 ms nearby-view build, 6.63 ms frame mean / 7.54 ms p95, 1.03 ms physics mean, 183.4 MB static memory and 1,337.1 MB video-memory monitor. The earlier physics-monitor variability reinforces the need for a longer target-device run.

The continuous sand-to-seabed water pass, on the same development machine and 1080p sample, measured 1,551 nearby views, 15,095 nodes, 5,032 maximum draw calls, 6,333 ms nearby-view build, 7.66 ms mean / 14.36 ms p95, 20.96 ms physics monitor mean, 183.4 MB static memory and 1,337.1 MB video-memory monitor. The strong short-run monitor variance is not attributed to the visual mesh without a longer controlled profile. Rescue and route checks still pass; target-device exported performance remains open.

After widening and furnishing the Synty pier head, two more short development-machine 1080p samples each had 1,551 nearby item views, 15,287 nodes, 5,079 maximum draw calls, about 6,180 ms nearby-view build, 183.7 MB static memory and 1,337.3 MB video-memory monitor. Frame mean/p95 was 7.73/18.78 ms and 8.32/25.49 ms; physics mean was 0.81/0.98 ms. The p95 exceeds the 16.67 ms 60 fps budget in both short samples, and the discrepancy between runs suggests frame-time variability that needs profiling. No target-hardware or exported-build performance claim is made. The scene, full route and rescue checks pass despite this open performance gate.

The follow-on denser-frontage sample, on the same development machine at 1080p, recorded 1,551 nearby views, 15,315 nodes, 5,106 maximum draw calls, 6,271 ms nearby-view build, 184.4 MB static memory and 1,337.4 MB video-memory monitor. Frame mean/p95 was 8.13/17.45 ms with 0.70 ms mean physics monitor time. This remains just above 16.67 ms p95 in one short sample, not evidence that the target GPU is ready; the four additional modular blocks and eight Synty beach shops should be evaluated in a longer exported-build profile before release.

With Synty windows and awnings on all three service huts, the next short 1080p development-machine sample recorded 1,551 nearby views, 15,375 nodes, 5,304 maximum draw calls, 6,428 ms nearby-view build, 184.7 MB static memory and 1,337.4 MB video-memory monitor. Frame mean/p95 was 7.87/15.80 ms; the physics-time monitor reported a variable 14.51 ms mean despite zero awake bodies. One sample below the 16.67 ms p95 frame budget does not establish target-device or long-session compliance.

After nearest-first view promotion and four fixed Synty cafe sets, the short visible-scene 1080p RTX 3070 sample recorded 1,551 nearby views, 15,492 nodes, 5,373 maximum draw calls, 6,310 ms nearby-view build, 185.1 MB static memory and 1,337.4 MB video-memory monitor. Frame mean/p95 was 7.05/8.82 ms; the physics-time monitor again varied (22.62 ms mean with zero awake bodies). This short local sample checks for an obvious rendering regression, not target-device or sustained performance. A live lounge relocation loaded 343/343 nearby section views within 180 frames with nearest-first scheduling, versus 44/343 with ID ordering at the same two-view-per-frame budget.

The mixed Synty villa/deco façade pass and corrected per-surface material batching increased video-memory monitor use to 1,354.4 MB on the RTX 3070 development machine. Before dropping invisible rear-face modules, two short 1080p samples measured 17.42 and 20.36 ms p95; afterward, two samples measured 16.04 and 15.92 ms p95, with 1,551 nearby views, 15,496 nodes, 5,382 maximum draw calls and roughly 6.4 s synchronous view build. These brief samples are variable and do not prove the GTX 980-class, 8 GB RAM or exported-build gate.

After aligning the physical shoreline, one short 1080p sample on the same RTX 3070 measured 1,551 nearby views, 15,498 nodes, 5,382 maximum draw calls, 6,362 ms nearby-view build, 7.91 ms mean / 17.09 ms p95, 16.47 ms mean physics monitor time and zero awake bodies. The p95 exceeds 16.67 ms; this one sample cannot establish causation or target-device performance.

Compact-beach update: the quarter-length 160 m shoreline concentrates the unchanged 5,700 required items. With a 55 m view-loading radius, 80 m unload radius and 60 m small-item visual range, the full playable scene at 1080p on the same RTX 3070 held all 5,740 records, including 5,375 initially WORLD, while instantiating 2,042 nearby views / 4,215 meshes. The latest 120-frame sample measured 7,892 ms synchronous view build, 12.52 ms mean / 22.08 ms p95, and 11,963 maximum draw calls. Other short samples varied up to 28.25 ms p95. A trial 45 m visual range saved roughly 1,000 draw calls but did not reliably improve frame time and was reverted to avoid earlier visual pop-in. The near-view promotion/demotion and ownership check passed. The compact build is not yet a 60 fps or target-hardware performance pass; its synchronous startup remains a usability concern.

Second compact sample: loading ordinary small-item views within 45 m, unloading beyond 70 m, and rendering them to 35 m reduced initial views to 1,773 / 3,677 meshes, node count to 16,838 and maximum draw calls to 9,591. Two 120-frame 1080p RTX 3070 samples gave 6,890–6,904 ms synchronous builds and 22.63 / 19.76 ms p95, respectively; means were 10.34 / 10.26 ms. The lower draw count and build time are material improvements, but the varying p95 remains over 16.67 ms and no GTX 980-class result is inferred. The real scene's six-step, 21 m walking-stream check found no missing physical views within 30 m. Visual captures keep nearby trash dense while the far background is cleaner; long-session movement/pop-in and target hardware remain open.

Native batch follow-on: 4,859 initial WORLD records with a single Synty mesh now draw through 216 MultiMesh groups keyed by section and definition, while 574 physical views remain near the player or for large/multipart items in the tested seed. Physical promotion happens within 12 m and demotion beyond 24 m; unsupported visual scenes retain the earlier 45/70 m stream. Batched groups draw to 55 m and retain the supplied Synty mesh/material and record transform; no substitute cube is introduced. The real scene checked a 21 m walking stream with zero gaps within 8 m, distant batch-to-body-to-batch promotion, collection hiding both presentations, and invariant-preserving save ownership. Three 600-frame 1080p RTX 3070 samples measured 3,308–3,414 ms synchronous build, 8.22–8.71 ms frame mean, 10.04–10.52 ms p95, 5,489 maximum draw calls, 8,662 nodes and about 169.6 MB Godot static memory. One earlier 120-frame run still spiked to 24.09 ms p95; the longer samples do not establish sustained/exported or GTX 980-class performance. Video-memory monitor use stayed about 1,355 MB. Packed new-run and physical/save flows pass; cold-start usability and target hardware remain release gates.

Pack-mounted follow-on: two 600-frame visible 1080p runs loaded the current Windows PCK with the external P07 scene script on the same RTX 3070. The `ItemViewManager.build_views` timing was 472.4 and 474.9 ms (it excludes manifest generation, full boot and OS cold-start I/O); frame p95 was 10.08 and 9.23 ms, maximum draw calls 5,494, and zero near-view gaps appeared on the 21 m stream. The packed resources were precompiled, explaining why this measured substep is much shorter than the editor-workspace build; it is not a standalone executable or GTX 980-class measurement. Packed save/recovery and physics-save checks on this same PCK passed separately.

Dry-sand prop-spread workspace sample: after `beach-content-5` dispersed loose furniture across a wider dry-sand band, the same RTX 3070 at 1920×1080 held 5,740 records with 504 nearby physical views and 4,880 batched Synty small-item instances in the sampled seed. A rendered 600-frame run measured 2,932 ms for the synchronous item-view build, 7.86 ms frame mean / 10.17 ms p95, 5,075 maximum draw calls and zero near-view gaps on the 21 m streaming walk. This is workspace execution, not a cold standalone executable or GTX 980-class/8 GB test; the target-device gate remains open. Godot 4.6.1 emitted intermittent Jolt area-overlap warnings in some scene runs even though the gameplay checks reported no failures.

Godot 4.6.3 maintenance sample: the same 1080p RTX 3070 development-machine workspace flow, still with `beach-content-5`, held 5,740 records, 504 nearby physical views and 4,880 batched Synty instances. Its rendered 600-frame run measured 2,699 ms synchronous item-view build, 6.68 ms frame mean / 8.50 ms p95, 5,075 maximum draw calls and zero near-view gaps; no Jolt area-overlap warning appeared. The real traversal, rescue, completion, packed save/physics-save and 100 packed seeds also passed under 4.6.3 without that warning. These checks support using the maintenance engine fix, but do not establish sustained standalone-executable or GTX 980-class/8 GB performance.

Faceted-water sample, 23 September 2026: with the Synty water-normal color layer enabled, a rendered 600-frame 1920×1080 workspace flow on the same RTX 3070 held 5,740 records, 509 nearby physical views and 4,880 batched small items. It measured 2,791 ms synchronous view build, 7.58 ms frame mean / 10.78 ms p95, 5,419 maximum draw calls, 169.4 MB Godot static-memory monitor, 1,354.9 MB video-memory monitor and zero near-view gaps along the 21 m streaming walk. This differs from the earlier 8.50 ms p95 sample and cannot isolate shader cost from frame-time variability; the target GTX 980-class / 8 GB and standalone executable gates remain open.

Second Synty cloud-ring sample: with both cloud layers visible, the same 600-frame 1920×1080 workspace flow on the RTX 3070 held 5,740 records, 509 nearby physical views and 4,880 batched Synty small items. It measured 2,851 ms synchronous view build, 7.43 ms frame mean / 9.85 ms p95, 5,420 maximum draw calls, 169.4 MB Godot static-memory monitor, 1,354.9 MB video-memory monitor and zero near-view gaps. The difference from the prior sample cannot be attributed solely to the sky change; exported-build, long-session and GTX 980-class / 8 GB gates remain open.

Synty city-awning sample: with the extra batched storefront awnings, the same rendered 600-frame 1920×1080 workspace flow on the RTX 3070 held 5,740 records, 509 nearby physical views and 4,880 batched Synty small items. It measured 2,591 ms synchronous view build, 6.99 ms frame mean / 7.31 ms p95, 5,422 maximum draw calls, 169.5 MB Godot static-memory monitor, 1,354.9 MB video-memory monitor and zero near-view gaps. The faster frame sample should not be attributed to the awnings alone; target GPU/8 GB, standalone executable and long-session profiling remain open.

Synty promenade-tile sample: with 320 extra batched sidewalk modules dressing the formerly flat inland walking strip, the same rendered 600-frame 1920×1080 workspace flow on the RTX 3070 held 5,740 records, 509 nearby physical views and 4,880 batched Synty small items. It measured 2,590 ms synchronous view build, 7.29 ms frame mean / 7.63 ms p95, 5,423 maximum draw calls, 169.6 MB Godot static-memory monitor, 1,354.9 MB video-memory monitor and zero near-view gaps. The small difference from the awning sample is normal short-run variability, not a target-hardware result.

Synty roof-cap/balcony sample: with the extra staged roof cap and twelve balcony modules on the same full beach, the rendered 600-frame 1920×1080 workspace flow on the RTX 3070 held 5,740 records, 509 nearby physical views and 4,880 batched small items. It measured 2,608 ms synchronous view build, 7.15 ms frame mean / 7.65 ms p95, 5,427 maximum draw calls, 169.6 MB Godot static-memory monitor, 1,355.1 MB video-memory monitor and zero near-view gaps. Target GTX 980-class / 8 GB, exported-executable and long-session profiling remain open.
