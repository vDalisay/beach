# Verification and release evidence

These are behaviors to validate during implementation, not results from this planning task. **Working systems demonstrated in playable scenes with real game state take priority over the number or breadth of written tests.** Keep written checks to the minimum that provides useful confidence, following the [project rule](../../AGENTS.md).

**Current execution policy — 24 September 2026:** [the finishing phase](11-finishing-phase.md) is the single remaining-work checklist, including the revised look-and-feel plan. Systems acceptance proceeds with provisional art; final visual fidelity is a separate status within that phase. Collision/reachability, functional prompts, controller focus, target visibility and restoration-state behavior still require gameplay evidence. Later visual changes reopen only the affected routes/save compatibility/performance/package checks. The [latest review](10-systems-review.md) records actual evidence and distinguishes source inspection, injected input, accelerated completion and human/device acceptance.

Use the running game or a shared development scene with the actual RunSession, components and gameplay flow. Record the starting state, actions and observed result in the handoff. A simple reproducible scene validation is sufficient when it demonstrates the behavior; a headless pass alone cannot establish that a feature works in play.

Named cases and lab filenames below and in packets identify behaviors and possible evidence locations, not a requirement for one automated test or separate scene per case. Combine related checks in an existing scene or short script and reuse the result across packets. Keep small written validations for important ownership/payment/save invariants, deterministic generation, concrete regressions and edge cases that are difficult to reproduce in play. Do not build frameworks, mocks, fixture factories, test discovery, coverage targets or extensive suites. Do not add a written test merely to satisfy a packet template.

## Commands and entry points

The following files are created by the named packets. Until then, do not report these commands as executed successfully.

```powershell
$beachGodot = 'C:\Users\Home\Downloads\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe'
& $beachGodot --version
& $beachGodot --headless --path 'C:\Users\Home\Documents\beach' --editor --import
& $beachGodot --headless --path 'C:\Users\Home\Documents\beach' --script res://tests/run_checks.gd
& $beachGodot --path 'C:\Users\Home\Documents\beach' res://tests/scenes/interaction_lab.tscn -- --graphics=low
& $beachGodot --path 'C:\Users\Home\Documents\beach' --script res://tests/validate_physics.gd -- --graphics=low
& $beachGodot --headless --path 'C:\Users\Home\Documents\beach' --export-release 'Windows Desktop' 'builds/windows/Beach.exe'
```

Graphics preset for test runs: windowed checks, scenes and play sessions run on Low (`-- --graphics=low`) unless the change affects rendering. Headless runs draw nothing, so they need no preset. The option applies to that launch only and never changes the saved settings. See `AGENTS.md` for when to use High, Ultra and Low instead.

Where written checks are justified, keep `tests/run_checks.gd` as a short SceneTree script with direct checks, a tiny `check(condition, message)` helper and a nonzero exit on failure. No case registry, discovery system or custom test command interface is required. Do not depend on `assert()` alone for release-mode execution. Use temporary `user://test_runs/` saves, never a real player save. Construct only the small amount of state needed by a check; prefer existing playable scenes for integrated behavior and add a development scene only when the game cannot conveniently expose the state needed.

## Validation scenarios and owners

| Scenario | Owner | Behavior to demonstrate |
|---|---|---|
| `boot` | P00 | Boot scene loads, no script errors, application main scene assigned. |
| `asset_closure` | P01 | Every staged reference resolves from root, repeated staging changes no content, no nested cache or source archive in runtime closure. |
| `ownership` | P02 | Every fixture item is in exactly one record/list; duplicate/invalid transfers rejected without any mutation; public signals expose only finalized revisions and defer reentrant actions. |
| `input_bindings` | P03 | Required actions exist, nonempty keyboard/controller bindings, persisted remap round-trip and reset. |
| `manifest` | P06 | Same seed/version gives equal canonical manifest in separate fresh processes; different seed changes placement while maintaining 5,700 required / category / zone quotas. Golden stream bytes/hash cover Unicode and punctuation seeds. |
| `manifest_constraints` | P06 | All required destinations/capacities valid; no impossible single family shelf claim; no unreachable or overlapping pickup anchors; fixed dirty/buried/rescue counts. |
| `physics_recovery` | P07 | Out-of-bounds item returns with same ID and no completion/payment; throw/catch failure leaves item recoverable; snapshot after flight/settling captures current pose/velocity rather than launch pose. |
| `carry_lifo` | P09 | A then B then C collects to ordered bag; throws C then B. Full capacity rejects. Two small/one large hand cost respected. |
| `slots` | P10 | Bucket claim rejects ball; removing last bucket clears claim; colour variants share family; dirty prop rejected; physical catch and click give same committed state. |
| `dirt` | P11 | Dirty chair cannot complete until all patches cleaned; furniture count remains one; loose residue keeps its original waste ID and requires collection. |
| `table` | P12 | Full-table unload rejected intact; drag/click share sort logic; correct→wrong→correct is reflected in final contents; exiting mid-drag loses nothing. |
| `sealing` | P13 | 50 items auto-seal; manual 1-item seal works; zero fails; full output rack blocks safely and retries waiting full bins when space returns; mismatched category container rejects bag; out-of-bounds bag recovers with the same SEALED contents. |
| `payment` | P14 | 30 correct + 20 incorrect pays 80 and completes 50; repeat call pays zero; bag transport never pays. |
| `purchases` | P15 | Insufficient money and missing prerequisite rejected; already purchased level cannot charge twice; loadout max two; upgrades recompute identically after load. |
| `tool_filters` | P16 | Vacuum/sand cleaner respect range, occlusion, eligibility and bag free capacity; no hold-to-poke behavior. |
| `buried` | P17 | Seed preserves reveal locations/rewards; hidden objects cannot be collected/scanned; valid sand-surface dig succeeds while an intervening wall blocks it; optional valuable sold once, denominator unchanged. |
| `faint` | P18 | Exactly all carried object refs drop once; equipment/wallet unchanged; nearest valid shore selected; repeat event cannot clone objects or recovery-pile membership. |
| `rescue` | P19 | Full bag drops removed attachment; last cut releases animal; no damage path; restored area still waits for attachment collection. |
| `completion` | P20 | Pickup/sort/deposit do not count waste complete; truck does. Prop removal reverses current progress. Restoration/group payment/result receipt latch once inside the triggering action's revision, before any observer snapshots it. |
| `discovery_scan` | P23 | Only unlocked definition/tag filters available; matching IDs include new locations; collected/sold and clean SLOTTED props excluded; dropping a removed prop makes it eligible again; buried stays hidden until revealed. |
| `save_roundtrip` | P24 | Every state restores identical records before physics resumes, including moving/resting WORLD item/bag poses, recovery markers, ordered inventory, money, claims, rewards and manifest; sorting loads at the player pose in world view. |
| `save_recovery` | P24 | Truncated latest generation falls back; both corrupt preserve live run and files; failed write retains previous valid save; quit persists its own snapshot sequence even when movement has not changed the run revision. If background writes are added, overlapping requests preserve the latest snapshot. |
| `economy_reachability` | P26 | All reachable affordable purchase sets retain a route to required tools/air using remaining accessible base-only waste income; optional-first spending cannot strand completion. A deliberately trapped $990-spend fixture fails. |
| `content_totals` | P26 | Per-zone and per-category matrix sums exactly; dirty60/buried300/attachments24/residue120 are subsets; optional40 excluded. |

## State sequences that must be exercised together

1. Collect 20 mixed waste → reject item 21 → throw last two → collect again → unload → sort wrong → correct before sealing → manually seal → carry → throw into matching container → call collection → buy cloth → clean chair → slot it → remove/re-slot it. Counts and money must match a written expected receipt at every stage.
2. Fill table cells/bin/rack/hand positions in a development scene using real game state. Check each distinct capacity rule with no free space, then make one space and retry. No ID vanishes, duplicates or changes category just to fit; this does not require separate fixtures for every transfer permutation.
3. Collect a mix of surface/buried/rescue waste across multiple home sections into the same sealed bag. Truck collection credits each original section correctly.
4. Enter water with a mixed trash bag, one held prop and one disposal bag. Faint with 0 air. Reload the resulting save, recover each item, finish the relevant section. Recovery markers survive load, follow remaining WORLD members and disappear when emptied. Re-faint with recovered items; no duplicate membership, equipment loss or ghost hand reservations.
5. Collect the final local waste to trigger collection and habitat restoration. Separately place the final required prop to trigger its group reward, section restoration and first run completion in one action. Save before the action and from its first public signal, interrupt presentation, and load either snapshot. Each snapshot must be internally before or after the entire commit, including rewards/flags/receipt, with one revision increment and no partial payment.
6. Finish the game, continue roaming, remove a chair, save and reload, replace the chair. Original finish receipt persists, current progress changes and returns, wildlife remains, no second reward.
7. Start two runs from the same seed; complete tasks and buy gear in only one. Open the second run and confirm that it still starts fresh. Manual slots and autosave of the first run remain selectable.
8. Throw a loose item and a sealed bag; snapshot mid-flight, then again after settling. Reload each snapshot with simulation initially frozen and compare captured poses/velocities before continuing. Repeat from pause, and reject a corrupt load while keeping the current live run intact.

## Manual gameplay and controller gate

Use a controller from launch through new run, tutorial prompts, movement, diving, sorting by focus, manual partial sealing, physical carrying, collection, shop, booklet, scanner filter selection, save/load and result-screen continuation. No mouse assistance is allowed during this pass. Repeat mouse play for click/drag sorting. Test controller disconnect/reconnect, UI focus restoration and bindings changed away from defaults.

Check FOV range 70–110 (default 85), sensitivity, invert Y, sprint/crouch toggle, UI scale 100–150%, reduced motion, and clear labels/icons in all four waste categories. On the Graphics tab, check that each preset and each option applies live, persists after a restart and stays reachable by controller (LB/RB switch tabs). At 1280×720 and 1920×1080, HUD and sorting controls stay reachable and readable; at 4K, scaling does not leave microscopic text. Check modal closing cannot throw an item or poke through the menu.

Visual feedback must show white hover outline and a nearby item name; no through-wall hover. A valid placement ghost must match the chosen slot and front orientation. Placement travels rather than popping. Pulses change only visual scale and return exactly to baseline. Group sweeps replay safely; restoration never reverses. Test bright sand, dark hut, water surface, submerged camera and overlapping thin objects.

## Performance target and limits of evidence

Target test: exported Windows release, 1920×1080 default settings, GTX 980-class GPU with 8 GB total system RAM. CPU was not specified by the user; record the actual test CPU, driver, OS, game build and GPU VRAM. No claim of target compliance from a stronger developer machine or a headless run.

Default budget: approximately 16.7 ms per frame at 60 fps, 95th-percentile frame time ≤18 ms across the test route, and no recurring >50 ms gameplay stalls. Aim for ≤3 GB game process resident memory and ≤3 GB dedicated GPU memory to leave system headroom. These are initial engineering budgets, not guarantees from this plan. Profile CPU physics, draw calls, shader cost, loading and save spikes separately; adjust settings before redesigning systems.

Measure a 5,700-object cold start, densest trash mountain, chair row interaction, 200-item table unload, maximum vacuum throughput, view down the full coastline, restored reef population, full-bag underwater faint, save/load, and almost-complete scanner pass. `tests/profile_views.gd` (run with a window) covers the fixed views, a sprint and the graphics presets; see the [performance pass](13-performance-pass.md). Repeat representative route after extended pickup/throw/save activity to catch accumulating nodes/materials/markers. Report maximum awake rigid bodies, visible item draws and instantiated mesh/material counts alongside frame time and memory.

P07 records the early baseline. P28 may add per-cell batching or near-view promotion only if measurements identify the need. Any optimization reruns ownership, target selection, physical catch and save checks, so it cannot make far-away litter disappear logically. Missing target hardware is an explicit unverified release criterion, not an automatic pass.

## Release checklist

- P00–P29 acceptance evidence exists; P30 is optional and cannot block the required release.
- All required assets either render correctly or remain honestly listed as placeholders awaiting the user. Do not label remaining cube wildlife as final art quality.
- Required quotas and compatible storage verified with a simple loop over 100 seeds, including empty-input-generated seed, Unicode seed, max-length seed and repeated seed. Reuse the generator's validator; do not build a separate seed-testing system. Reject too-long/control-character input cleanly.
- At least one human-paced complete full run without debug collection proves pacing and recoverability. A fast fixture completion checks logic but cannot replace this.
- Export boots on a machine without the Godot editor or .NET SDK. Game uses GDScript; do not bundle a .NET runtime because the local editor happens to be Mono.
- Windows export template version matches 4.6.1. Exclude source package, conversion project, `.godot`, planning reference images, test fixtures and build tools; include every runtime catalog dependency explicitly.
- Test a fresh user profile, first save, multiple runs, damaged latest autosave and failed-write UI. Keep existing saves during build updates.
- No sounds, visitors, multiplayer lobby or fake online leaderboard has been added to fill perceived gaps. No Windows-specific runtime path is required.
- Final handoff states actual check results and remaining gaps, with build path and exact version. Do not mark “release-ready” while known completion/save failures remain.
