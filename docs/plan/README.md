# Beach — full-release implementation plan

Current status — 23 September 2026: most gameplay systems are implemented, but normal-input completion and controller sorting have reproduced blockers. Visual alignment and release evidence remain incomplete. Start with the [implementation and screenshot review](06-implementation-review.md), then follow the [completion plan C00–C09](07-completion-plan.md).

The P00–P30 index below is the original implementation specification, not a current completion checklist. The starting-point and planning-validation sections record the historical 22 September planning pass. Use the review's packet reconciliation for current status; the confirmed requirements remain authoritative. This review added documentation and evidence, not gameplay fixes.

This plan incorporates both clarification rounds and the final instruction: **build only the full-release version; there is no demo deliverable**. Internal test scenes are verification tools, not a separate product. There are no schedules, estimates, or staffing assumptions.

Read [requirements](01-requirements.md), [contracts and architecture](02-architecture.md), [world and asset audit](03-world-and-assets.md), [content and balance](04-content-and-balance.md), and [verification](05-verification.md) before implementing the relevant packets. User decisions are binding. Values explicitly marked **default** are proposed implementation/tuning decisions, not additional user approvals.

## Outcome

A first-person, singleplayer beach cleanup game in Godot 4.6.1 and GDScript: pick up litter, sort it at a physical table, carry sorted bags to containers, call collection, earn money, buy better equipment, organize reusable props, rescue animals, and restore local habitats. One handcrafted LA-inspired resort beach contains a default 5,700 required objects. The starting mess, buried finds, and rescue attachments are reproducible from a seed within the same content/game version.

Priority order: satisfying cleanup → organizing props → visual fidelity → environmental restoration → optional vehicles. Restoration is essential despite that priority order. Target Windows, 60 fps on an 8 GB RAM / GTX 980-class system. Do not introduce Windows-only runtime dependencies that prevent a later Linux port.

## Verified starting point — 22 September 2026

- Workspace: `C:/Users/Home/Documents/beach`.
- Existing tracked project: `project.godot`, an empty `node_3d.tscn`, icon and Git configuration. No gameplay scripts or main scene were found. Working tree was clean before this plan.
- Engine verified with `--version`: `4.6.1.stable.mono.official.14d19694e`.
- Console executable: `C:/Users/Home/Downloads/Godot_v4.6.1-stable_mono_win64/Godot_v4.6.1-stable_mono_win64_console.exe`.
- Current renderer: GL Compatibility; physics: Jolt. A `d3d12` RenderingDevice setting exists but Compatibility itself uses OpenGL. Keep Compatibility initially and validate its visual result; do not silently switch renderers.
- `Assets/Synty` is present and Git-ignored. It contains a separate converted Godot project, 1,790 generated mesh scenes, 309 materials, source FBX files, textures, shaders, and a Unity package. This is **not** a verified assembled beachfront scene.
- Sample converted scenes reference `res://POLYGON_Palm_City/...`; materials reference `res://shaders/...`. Those locations belong to the nested conversion project, not the Beach root. Packet P01 stages and rewrites a selected dependency closure before gameplay uses the assets.
- Conversion log reports one missing material. No rendered visual QA of these assets was performed during planning. Marine wildlife and tools require the gap audit in [world and assets](03-world-and-assets.md).

## Implementation order and packet index

Each packet is a bounded handoff. Complete its prerequisites first. Packet numbers provide a convenient default order; **Dependencies** are authoritative. Multiple contributors must not concurrently edit the same scene or script without explicitly allocating ownership. No agent delegation is required by this plan.

| Packet | Outcome | Dependencies |
|---|---|---|
| [P00](packets/P00-project.md) | Root project, boot scene, small validation script | — |
| [P01](packets/P01-assets.md) | Reproducible asset staging and cube placeholders | P00 |
| [P02](packets/P02-state.md) | Definitions, run state, validated state changes | P00 |
| [P03](packets/P03-input.md) | Input actions, remapping, settings, UI focus | P00 |
| [P04](packets/P04-player.md) | First-person movement and hand presentation | P02, P03 |
| [P05](packets/P05-world.md) | Full beach blockout, zones, slots and anchors | P01, P02, P04 |
| [P06](packets/P06-generation.md) | Deterministic full-run manifest | P02, P05 |
| [P07](packets/P07-physics.md) | Physical items, piles and recovery boundaries | P01, P02, P06 |
| [P08](packets/P08-interaction.md) | Targeting, names, outlines and contextual actions | P04, P07 |
| [P09](packets/P09-carrying.md) | Bag, hands, pickup travel and LIFO throws | P02, P08 |
| [P10](packets/P10-placement.md) | Claimed shelves, snapping and reversible groups | P05, P09 |
| [P11](packets/P11-cleaning.md) | Cloth, furniture stains and loose residue | P09, P10 |
| [P12](packets/P12-table.md) | Bird's-eye table, dragging and selected-bin sorting | P03, P09 |
| [P13](packets/P13-bags.md) | Sealed bags, output rack and category containers | P07, P09, P12 |
| [P14](packets/P14-collection.md) | On-call collection and exact payment | P02, P13 |
| [P15](packets/P15-progression.md) | Physical shop and booklet skill purchases | P03, P11, P14 |
| [P16](packets/P16-cleanup-tools.md) | Sand cleaner and vacuum | P09, P15 |
| [P17](packets/P17-buried-finds.md) | Detector, buried waste and valuables | P06, P09, P15 |
| [P18](packets/P18-swimming.md) | Swimming, oxygen and recoverable faint drops | P04, P07, P09, P13, P15 |
| [P19](packets/P19-rescue.md) | Knife rescues with no animal damage | P06, P09, P15, P18 |
| [P20](packets/P20-completion.md) | Progress, permanent restoration and results | P10, P11, P14, P17, P19 |
| [P21](packets/P21-wildlife.md) | Returning fish, turtles and reef life | P01, P18, P20 |
| [P22](packets/P22-ui.md) | Complete HUD, menus, booklet and guidance | P03, P15, P18, P20 |
| [P23](packets/P23-scanner.md) | Discovered-type and material scanner | P06, P08, P15, P22 |
| [P24](packets/P24-saving.md) | Autosave, manual saves and run isolation | P02, P06, P12, P14, P17, P18, P20, P22, P23 |
| [P25](packets/P25-art.md) | Finished beachfront, water and underwater look | P01, P05, P18, P21 |
| [P26](packets/P26-content.md) | Final 5,700-object distribution and economy | P06, P15, P16, P17, P19, P23, P25 |
| [P27](packets/P27-feel-accessibility.md) | Final interaction feel and controller accessibility | P08, P10, P12, P21, P22, P24, P26 |
| [P28](packets/P28-performance.md) | Target-hardware performance and memory checks | P07, P21, P24, P25, P26, P27 |
| [P29](packets/P29-release.md) | Full completion audit and Windows export | P24, P26, P27, P28 |
| [P30](packets/P30-optional-jetski.md) | Optional arcade jetski | P18, P24, P29; explicitly optional |

P06 supplies the initial complete logical catalog and quota matrix used by P07's early 5,700-item performance measurement; P26 finalizes those same resources. P28 is final profiling, not the first opportunity to discover scale problems. P02 defines snapshot-friendly state and the action finalization boundary early; P24 implements disk persistence after all required states exist.

## Handoff rules for every packet

1. Read the linked contracts and prerequisite handoffs. Inspect existing implementations before adding another helper.
2. Implement only the named outcome, using typed GDScript, native Godot nodes/resources and existing project utilities. Do not install a gameplay framework, networking library, custom ECS, or test framework.
3. Keep domain changes out of presentation callbacks. One logical item has one stable ID and one owner/location. Never decrement remaining counts just because a mesh disappeared.
4. Missing art becomes a labelled coloured cube and an entry in the asset register. Preserve the feature. Do not fetch substitute art or quietly remove it.
5. Follow the [project validation rule](../../AGENTS.md): prioritize working systems demonstrated in playable scenes with real game state. Keep written tests minimal; add a small check only where it protects an important invariant or catches a regression that play validation would miss. No test is required merely because a packet or file changed, and no testing framework or extensive test setup should be built. Reuse scenes and existing checks; record the evidence.
6. Update `docs/handoffs/Pxx.md`: outcome, files changed, commands and results, manual evidence, known gaps, and contract changes. Mark a packet done only when its acceptance checks pass; distinguish blocked art from completed logic.
7. If implementation exposes a contradiction, resolve it against [requirements](01-requirements.md), document the concrete default used, and preserve all user-approved behavior. Do not change a locked rule to make a test pass.

## Full-release gate

P00–P29 deliver one release. The full loop must work with mouse/keyboard and controller, saves must preserve every meaningful state, all required objects must remain recoverable, and a normal run must reach completion without debug actions. The art audit must be honest about any remaining user-supplied assets; cube placeholders permit implementation and testing but do not establish final visual fidelity. Multiplayer, online leaderboards, sound, other beaches, and rideable vehicles are not required release work.

Use [verification](05-verification.md) for the evidence required before calling the game release-ready. This planning package is not evidence that those future checks have passed.

## Planning validation completed

The planning pass checked all local Markdown links, balanced code fences, all 31 packet structures, dependency existence and absence of cycles, index-to-packet dependency agreement, and every named asset candidate against the 1,790-file inventory. Arithmetic checks confirmed 5,400 waste + 300 props, all zone/family column sums, and the $5,300 default purchase total. Six supplied reference images were copied into this package. Only documentation/reference files were added; the gameplay project, source assets and runtime settings were not modified.

## Independent review — 22 September 2026

Reviewed all contracts and packets against the empty root project and rechecked the installed engine version. Revisions close gaps in action/reward/save ordering, live physics snapshots, sealed-bag recovery, recovery markers, full-rack retry, buried-target visibility and scanner completion filtering. P06 now explicitly owns the initial catalog/quota data needed before P26, and seed streams have an unambiguous encoding. Economy acceptance now checks optional-first spending dead ends as well as the cheapest required-tool route. These are implementation requirements and regression cases, not claims that gameplay or performance checks have passed.

Review validation passed: 37 Markdown files, 59 local links, all 31 packet structures and matching acyclic dependencies, zone/family/purchase arithmetic, 24 verification-case owners, 58 named asset candidates and all 1,790 indexed source files. `git diff --check` also passed. No gameplay or rendered-art tests were run for these documentation changes.
