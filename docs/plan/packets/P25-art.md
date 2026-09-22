# P25 — Final beachfront and underwater presentation

Dependencies: P01, P05, P18, P21. Requirements: R03, R04, R22. Read: saved visual references and asset register.

**Outcome:** a detailed, coherent beach matching the supplied style without changing gameplay IDs or reducing required mechanics.

**Own files:** world art/zone subscenes, `shaders/water.gdshader` only if needed beyond tested supplied shader, environment/lighting resources, staged art manifest additions, asset request status.

**Steps**

1. Replace approved blockout art with staged Synty pieces: curved sand edges, palms, parasols/chairs, lifeguard structures, pier and lighthouse, beach shops/shelters, sports area, board parking, boats and restrained skyline. Keep inaccessible city visually thin.
2. Assemble complete multi-piece props and use consistent scale, orientation and shared materials. Keep intended empty sorting spaces visible. Do not fill the beach with unrelated city assets to reach a detail target.
3. Establish fixed sunny lighting, warm sand, turquoise shallows and distinct reef silhouettes. Tune sun/shadow distance, ambient fill, MSAA and fog on the selected renderer; no day/night/weather system.
4. Validate supplied water shader on Compatibility. Correct staged/project-owned depth reconstruction if necessary; keep foam, mild waves and surface visibility readable. Avoid a compute or renderer-exclusive dependency for core swimming. Water surface appearance and stable gameplay surface must remain close enough that breath transitions feel correct.
5. Add underwater tint/fog and simple animated caustic treatment where supported; avoid obscuring litter/rescue targets. Ensure surface and underwater views do not double-tint, clip at near plane or hide floating glass.
6. Preserve approved cube placeholders for unresolved models and update the register. Project-owned shaders, native UI and authored terrain geometry are allowed; do not substitute third-party art for missing creatures/tools.
7. Capture all six named reference viewpoints before/after section restoration. Check UI/outline visibility in sunlight and through water. Record visual gaps separately from functional completion.

**Acceptance:** reference-view comparison, no missing materials/shader errors, correct multipart props, no enterable backdrop, readable reef and visible wildlife reward. Core scope remains intact wherever art is pending.

**Handoff:** screenshot set, renderer/settings, water limitations, asset request changes and added dependency closure. P28 profiles this fully dressed world.
