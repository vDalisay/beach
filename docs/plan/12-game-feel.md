# Game feel — hover, hands, placement, tools and completion

Planned 24 September 2026 on branch `claude/game-feel-juice-plan`, created from `main` at `b190cea`. **Status:** J00–J14 implemented; evidence, retained tuning and open issues are in [J-feel](../handoffs/J-feel.md). J13's physical-controller check is blocked on hardware, and FIN-08 stays open.

This plan makes the existing cleanup loop feel good to play:

- Hovering clearly shows what is actionable.
- Picking up litter snaps it into the bag.
- Placing a prop glides it in and settles it.
- Every tool has hand motion.
- Finishing something (a stain, a set, a section, the whole coast) produces escalating "done" feedback, as in other tidy-up games.

It is written for implementers who have not read the code. Every packet names the files, functions, nodes, starting values and existing checks it touches.

## 0. Authority and boundaries

- **Presentation only.** Do not change ownership, location transitions, payments, rewards, completion latches, restoration flags, saves, capacities, reach, bindings, content or generation. The [architecture](02-architecture.md) rule is absolute: *validate → commit → publish, then animate a temporary view*. An animation never delays, gates, reorders or repeats a commit.
- **Locked requirements stay locked.**
  - No sound: R29 and the [release checklist](05-verification.md#release-checklist).
  - No compulsory head bob or camera shake: [P04](packets/P04-player.md).
  - Nature events must not force camera movement: [P27](packets/P27-feel-accessibility.md).
  - Reduced motion and colour-independent cues: D21.
  - Scales apply to visual roots only, never to collision or saved transforms: [P27](packets/P27-feel-accessibility.md).
  - 60 fps on GTX 980-class hardware: R01.
- **Scope change, recorded.** At the user's request on 24 September 2026, this plan replaces the "tune existing hover/travel/ghost/pulse/sweep only" limit in [C08 step 3](07-completion-plan.md#c08--integrate-final-assets-and-tune-the-actual-experience) and P27's narrow scope. It keeps their intent:
  - No new feedback manager that duplicates presentation owners. Each existing owner animates its own objects.
  - Only the current target is outlined.
  - A blocked target is never styled like an actionable one.
  - No sound and no camera cinematics.
- **Relation to finishing.** [FIN-08](11-finishing-phase.md#fin-08--final-visual-and-interaction-acceptance) accepts the final interaction presentation, and this plan specifies what to build for that step. It closes no FIN box. J packets do not wait for FIN-05's supplied art. After art swaps, re-tune the tool tips, grips and outlines (J14).

**How to use this plan.** Read §1–§11 once, then implement the packets in the order given in §10. Each packet file is self-contained for its own steps. Record evidence per packet in [J-feel](../handoffs/J-feel.md), following [AGENTS.md](../../AGENTS.md): show the behavior working in the real game or an existing lab scene, and keep written checks to the minimum.

## 1. What exists today

| Area | Current behavior (source) | Feel gap |
|---|---|---|
| Hover | White inverted hull with a fixed 0.012 m world width, pushed along each mesh's own normals (`shaders/hover_outline.gdshader`, `WorldItem._build_outline_overlays`). Appears on any `WorldItem` or stain target (`PlayerInteractor._set_target`). | Cracks at Synty hard edges. The fixed world width looks heavy up close and vanishes at reach distance. No hover-in motion. Blocked targets ("Bag full", "Needs Knife") look actionable. Slotted props, rack and world disposal bags, and stations get no highlight. A hull behind a transparent glass material can show through it; verify this on the glass bottle and jar in J01. |
| Aim | No reticle. The target label pops on and off (`scripts/ui/target_label.gd`). | Hard to aim at tiny litter. No same-frame acknowledgement of a click or a rejection. |
| Collect | `WorldItem.travel_to` makes a straight 0.22 s `TRANS_QUAD` move into the bag socket, shrinking linearly from the first frame (`PlayerCarry.present_collected`). Under reduced motion the view simply vanishes. | No anticipation, no path shape, no bag reaction, no puff where the item was. Vacuum and sand cleaner reuse the same motion. |
| Prop pickup | Straight 0.24 s travel to a hand socket. Picking a prop off a slot pops it into the hands with no travel (`PlacementService.try_remove`). | No lift or catch. Removing from a slot is jarring. |
| Throw | Launch velocity only (`PlayerCarry._on_throw_requested`). | No arm motion and no landing feedback. |
| Placement | Flat green translucent ghost that pops between slots (`placement_ghost.gdshader`, `_show_ghost`). Straight 0.25 s travel. Uniform linear 1→1.08→1 pulse, duplicated in `WorldItem.pulse` and `_pulse_slotted_view`. | The ghost is lifeless. The prop does not arc or set down. There is no landing weight and no contact. |
| Tools | Static in `ToolSocket`, swapped instantly (`ProgressionService.refresh_tool_visual`). Detector ring scales with `sin`. Sand cleaner uses a plain torus. Knife attachments vanish (`RescueSite.remove_attachment`). | No poke, wipe, slash, sweep, sift or suction. No equip motion. Cut litter disappears without going anywhere. |
| Viewmodel | Hands are fixed to the camera (`HandRig` is five sockets). | No weight: no bob, sway, breath or landing. The bag never reacts. |
| Completion | Group sweep is a mint band along world X for 0.7 s (`_show_group_sweep`, `group_sweep.gdshader`). Restoration is an instant `show()` plus a 1.2 s albedo tween (`RestorationSection._on_section_restored`). Results appear and pause instantly (`ResultsView.show_receipt`). | No escalation. A restored reef pops in. Far-away restorations go unnoticed. The finale is a plain panel. |
| HUD | Text labels whose numbers jump. Notices show and hide instantly. Gameplay feedback reuses the error panel (`main.gd`). | Changes are easy to miss. Money and progress give no reward. |
| Sorting table | Proxies are freed and rebuilt on every refresh (`SortingStation._refresh_proxies`). Focus is a white square (`SortingView._draw`). Drag shows a text label. Bins do not react. | The main "tidy" activity has no motion at all. |
| Particles | CPU `ParticlePool` MultiMesh with `BUBBLE` and `SAND` kinds, used only by wildlife. | No sparkle or dust kinds. |

## 2. Feel pillars

1. **Acknowledge in the same frame.** Every accepted press gets visible motion within one rendered frame: the reticle pops, the arm moves, the item hops. Every rejected press gets a distinct "no" that never looks like success.
2. **Commit first, perform second.** The world state is already final when the animation starts. Animations only move temporary views and visual roots.
3. **Anticipation → action → follow-through**, at small amplitudes. A 6 cm hop before a 0.25 s flight reads better than a 0.4 s flight.
4. **Escalate by significance.** A stain, a set, a section and the coast each get a bigger version of the same language (§6), never a louder version of a smaller one.
5. **One vocabulary.**
   - White-gold gleam and sparkles mean *done*.
   - Mint hologram means *this will go here*.
   - Amber dashes mean *blocked*.
   - Turquoise bloom means *nature returns*.
   - Gold coins mean *money*.
6. **Calm coastal tone.** No camera shake, camera kicks, hit-stop, time scaling, strobing or cartoon elastic on big objects. Motion is springy but brief.
7. **Readability first.** Never cover the aim point, the target label or category information. Overlays over text stay under 0.6 alpha. The effects must work on bright sand, in a dark hut and underwater.
8. **Motion is optional.** Reduced motion removes secondary motion but keeps positional feedback (§8).
9. **Everything is capped and self-cleaning.** Pools, rings, floaters, coins and tweens have hard limits, and every temporary node frees itself.

## 3. Borrowed vocabulary

These are the patterns the packets implement, with the games they come from, so reviewers can compare the result to familiar references:

| Pattern | Seen in | Used here |
|---|---|---|
| Part-complete shimmer: a bright band sweeps an object and it sparkles | PowerWash Simulator | Clean-done gleam (J07), set sweep (J07) |
| Snap into place, set down, small squash | Unpacking, Townscaper | Place arc, drop and settle (J05) |
| Hover lift and jiggle, solved-state glint | A Little to the Left | Hover lift and hop (J01), set shine (J07) |
| Items stab and flick into a bag | Litter-picking sims | Stick-tip waypoint (J04) |
| Radial "life returns" wave | Cozy restoration games | Restoration bloom (J11) |
| Postcard or photo of the finished space | Unpacking | Postcard finale (J12) |
| Coins fly to the wallet, counters roll | Most management games | Coins and count-ups (J10, J09) |

## 4. Hard rules for every J packet

1. **Never touch domain state in presentation code.** No writes to `RunState`, records, player dictionaries, bags or claims, and no calls to `finalize_action`. Read state only.
2. **Never scale or move collision.** Scale and offset `VisualRoot`, temporary presentation nodes or viewmodel pivots only. Every scale animation ends exactly at `Vector3.ONE` / `Vector2.ONE` through a final `tween_property` to that value.
3. **Never save presentation.** Loading a save shows the terminal state instantly: restored sections are already bloomed and slots are already filled. Presentation starts only from live signals, never from `configure()` or load paths.
4. **Always reach the terminal state.** Create presentation tweens with `FeelMotion.tween(node)`, which sets `Tween.TWEEN_PAUSE_PROCESS`, so travel, pulses, sweeps and waves finish while results or the pause menu pause the tree. Feel particle pools and effect nodes use `PROCESS_MODE_ALWAYS`.
5. **One tween per channel.** Before starting a tween on a property, kill the previous one on that channel: `FeelMotion.replace(node, channel, tween)`. Never stack scale pops.
6. **Per-instance materials for per-object effects.** Use `material_overlay` with a material created per effect, or overlay meshes that only the hovered object owns. Never animate a shared `.tres` or mesh material that other copies use. The one exception is the hover materials: only one target is hovered at a time, so they may be shared (J01).
7. **No gameplay RNG.** Cosmetic variation uses `FeelMotion.cosmetic_random(id, salt)` (a hash) or a pool's own `RandomNumberGenerator`. Never call `randf()` in code that also runs gameplay.
8. **Honor reduced motion** using §8. Read it through `FeelMotion.reduced(settings_store)`.
9. **Respect the text and timing contracts that existing checks read** (§11.2). Where a packet must change a timing, it says which check to update and how.
10. **Compatibility-renderer shaders only.**
    - No `hint_screen_texture` or `DEPTH_TEXTURE` sampling, no decals, no `instance uniform`, no GPU particle attractors or collision.
    - Use `unshaded`, `blend_add` or `blend_mix`, `depth_draw_never`, `shadows_disabled` and `fog_disabled` for overlays.
    - Every new shader must be seen rendering in the running game with no errors in the log. Shaders compile on first draw, so a headless import proves nothing.
11. **Do not edit generated vendor wrappers** under `art/synty/`, because staging regenerates them. Add helper markers and overlays in code at runtime.
12. **Keep the existing API names** that checks or other owners use:
    - `WorldItem.set_highlighted`, `is_highlighted`, `outline_overlay_count`, `travel_to`, `cancel_travel`
    - `HandRig` socket exports and `socket_transform`
    - `PlacementService` ghost node name `GhostRoot`
    - `TargetLabel.text_label`
    - `ResultsView.show_receipt` and `continue_roaming`
    - `CollectionReceipt.details_label`
13. **Cap everything** (§9). Hitting a cap drops effects, never gameplay.

## 5. Shared contracts

J00 creates all of these. Later packets only use and extend them. Full code is in [J00](packets/J00-feel-foundations.md).

### 5.1 `FeelTuning` resource

`scripts/data/feel_tuning.gd` (`class_name FeelTuning`) defines every presentation constant, grouped by packet. `data/feel/feel_tuning.tres` is its single instance. Scripts load it with `const FEEL := preload("res://data/feel/feel_tuning.tres")`.

- The resource is immutable at runtime, like other definition resources.
- Tune it in the inspector: remote-inspector edits while the game runs update live because the resource is shared.
- Only presentation reads it. A value in it must never change gameplay.
- Record retained changes in the handoff.

### 5.2 `FeelMotion` helpers

`scripts/feel/feel_motion.gd` holds static, stateless helpers:

| Group | Helpers |
|---|---|
| Tweens | `tween` (pause-safe), `replace` (one channel per property) |
| Scale | `pop`, `squash_land` |
| Paths | `bezier2`, `bezier3`, `travel` (arc path for any `Node3D`) |
| Easing and timing | `ease_in_out_cubic`, `travel_seconds` |
| Springs and randomness | `spring`, `spring3`, `cosmetic_random` |
| UI | `bump_control`, `shake_offset`, `count_seconds` |
| Settings | `reduced` |

It holds no state and no scene references.

### 5.3 Player cues

`BeachPlayer.play_cue(cue: StringName, info := {})` is the one entry point for "the player just did or tried something". It forwards to `HandRig.play_cue` for the viewmodel and emits `BeachPlayer.cue_played(cue, info)`, which `main.gd` routes to the reticle, target label, HUD and rumble.

- Services that already hold a `player` reference call it at their success or failure point: `player.play_cue(&"place")`. This follows the existing style of `player.carry.present_collected(...)`.
- World and session events that are not player actions (`set_complete`, `section_restored`, and so on) are emitted by `main.gd` through the same method so rumble and the HUD treat them uniformly.
- It is not an event bus. It carries no state, and each listener only animates what it owns.

Cue names are fixed (`BeachPlayer.CUES`):

| Group | Cues |
|---|---|
| Stick and bag | `whiff`, `poke`, `bag_catch` |
| Rejection | `rejected` |
| Hands and props | `hold`, `hold_bag`, `throw`, `place`, `deposit` |
| Cloth and knife | `clean`, `clean_done`, `cut`, `animal_freed` |
| Detector and sand cleaner | `detector_ping`, `reveal`, `sift` |
| Vacuum and equip | `vacuum_tick`, `vacuum_full`, `equip` |
| Scanner | `scanner_pulse` |
| Stations and money | `collect_call`, `sort`, `seal`, `unload`, `sell` |
| Completion | `set_complete`, `section_restored`, `zone_restored`, `run_complete` |

`info` carries only presentation hints:

| Key | Meaning |
|---|---|
| `reason` | Rejection text |
| `arm` | `&"left"`, `&"right"` or `&"both"` |
| `strength` | 0–1 |
| `count` | Number of items affected |
| `large` | `true` for a two-hand prop |
| `underwater` | `true` when the effect is below the surface |

### 5.4 `HoverHighlight`

`scripts/feel/hover_highlight.gd` provides `set_active(root, active, style, reduced)` and `overlay_count(root)`.

- It builds overlay meshes lazily under any visual root, using an outline-only copy of each mesh with smoothed normals.
- There are three styles:

| Style | Look | Used for |
|---|---|---|
| `ACTION` | White two-tone outline, soft rim glow, hover-in pop | Actionable targets |
| `BLOCKED` | Amber dashed outline, no rim | Targets the current input cannot act on |
| `SOFT` | Rim glow only | Stations and large service objects |

- See-through meshes (glass) get a rim instead of a hull.
- `WorldItem`, slotted prop views, disposal bags, dirt stains and stations all use it.

### 5.5 Particle kinds and pool owners

`ParticlePool` (`scripts/wildlife/particle_pool.gd`) gains two kinds:

- `SPARKLE`: a camera-facing four-point star, additive, twinkling.
- `DUST`: a camera-facing soft round puff that drags, rises and grows.

Both are billboarded on the CPU, so there is no shader billboard uncertainty in Compatibility. The existing `BUBBLE` and `SAND` kinds keep exact current behavior.

There is no central effects manager. Each presentation owner owns its own small pools, following the precedent that each fish school owns its bubble pool:

| Owner | Pools (capacity) | Used for |
|---|---|---|
| `ItemViewManager` | SPARKLE 96, DUST 64, BUBBLE 64 | Pickup puffs, throw impacts, reveals, snips, clean gleams |
| `PlacementService` | SPARKLE 128, DUST 32 | Landing contact, capture, set shine |
| `RestorationSection` | SPARKLE 192 | Restoration wave front and sparkle field |
| `SortingStation` (each) | SPARKLE 48 | Sort and seal |
| `VacuumTool` | DUST 48 (motes: no drag, no rise, shrink) | Suction motes |

Idle pools draw nothing and do not process.

### 5.6 Effect nodes and shaders

| Asset | Kind | Purpose |
|---|---|---|
| `shaders/hover_outline.gdshader` (rewrite) | Spatial, inverted hull, constant pixel width | Hover outline and backing, including the dashed blocked style |
| `shaders/hover_rim.gdshader` | Spatial additive rim | Hover rim and see-through targets |
| `shaders/placement_ghost.gdshader` (rewrite) | Spatial alpha hologram | Placement ghost |
| `shaders/feel_shine.gdshader` | Spatial additive `material_overlay` band | "Done" gleam on props and sets (replaces `group_sweep.gdshader`) |
| `shaders/feel_sparkle.gdshader`, `shaders/feel_dust.gdshader` | Particle quads | `SPARKLE` and `DUST` pools |
| `shaders/feel_ring.gdshader` + `scripts/feel/feel_ring.gd` | Flat additive ring on a plane, self-freeing | Scanner sonar, detector ping, landing ring, sand-cleaner area |
| `shaders/feel_wave.gdshader` + `scripts/feel/restoration_wave.gd` | Open cylinder "light wall" that expands, self-freeing | Restoration bloom and far beacon; works on uneven sand and seabed |
| `scripts/feel/feel_floater.gd` | Billboard `Label3D` that rises and fades, self-freeing | "✓ +$15", "Clean!", "FREED" |
| `shaders/ui_shine.gdshader` | `canvas_item` diagonal highlight | HUD bar, banner and receipt shine |
| `scripts/ui/feel_icon.gd` | `Control` that draws its glyph | Check, star, coin, arrow, question and info glyphs, without depending on font coverage |

### 5.7 Palette and glyphs (starting values, sRGB)

| Meaning | Color | Colour-independent partner |
|---|---|---|
| Actionable hover | White `#FFFFFF` over dark backing `#0B1A1F` | Solid outline, ring reticle |
| Blocked | Amber `#E8B45A` | Dashed outline, dashed reticle ring, reason text |
| Will-go-here | Mint `#7FF5C8` | Hologram shape of the actual prop, bracket reticle |
| Done gleam | Core `#FFF8E6`, fringe `#8FF3E0`; sparkles `#FFF6D8` / `#FFD86A` / `#A6F5EE` | Moving band, check glyph |
| Nature returns | Shore `#FFF1C9`, reef `#7FF0E0` | Expanding wall, star glyph, banner text |
| Money | Gold `#FFD85A` | Coin glyph, "$" text |
| Correct / wrong sort | Existing category colors | ✓ glyph / ? glyph |
| Full | `#E2725B` | "FULL" text, shake |

Check each color against the retained glow threshold (0.95) and grade LUT from [C06](../handoffs/C06.md). Additive effects may bloom slightly, but no effect may rely on bloom to be readable.

## 6. Completion tiers

| Tier | Moment | World | HUD | Owner |
|---|---|---|---|---|
| 0 Micro | Collect, pick up, place, sort, deposit | Hop, arc and settle; small puff or sparkles (≤6); reticle pop | Counter bump; bag fill | J04, J05, J08 |
| 1 Object done | Last stain cleaned; attachment cut; animal freed; buried find revealed | Gleam over the object (0.6 s); 8 sparkles; floater "Clean!", "FREED" or a find glint | None or a toast | J06, J07 |
| 2 Set done | A logical group completes, including replay | Diagonal shine across the whole group (0.8 s); sparkle line; floater "✓", "✓ +$15" on first completion | Notice with check glyph; coins to wallet on first completion | J07, J09, J10 |
| 2 Payment | Truck collection; valuable sale | Containers empty with a lift-off puff; phone rings | Receipt slides, types and counts; coins fly; money rolls | J10 |
| 3 Section restored | `section_restored` | Bloom wave (12 m, 1.8 s); staged pop-in of restored dressing; sparkle field; beacon when far | Banner with star glyph, distance and direction; off-screen pointer | J11 |
| 4 Zone restored | `zone_restored` | Larger wave (22 m); wildlife intro (existing) | Larger banner | J11 |
| 5 Coast restored | `run_completed` | The world finishes its effects under pause, then a camera-flash postcard | Results stamp, confetti, row count-ups | J12 |

## 7. Cue → effect matrix

Numbers are the J packet that owns each effect. "—" means nothing.

| Cue / event | Emitted from | Viewmodel (J03/J06) | Reticle and label (J02) | World | HUD (J09/J10) | Rumble (J13) |
|---|---|---|---|---|---|---|
| `whiff` | `PlayerInteractor.request_primary` with an empty target | Active tool's clip at 60% | — | — | — | — |
| `poke` | `PlayerCarry._collect_target` ok | Right-arm poke | Pop | Yoink, then stick-tip arc to bag; puff (J04) | Bag counter bump | Tick |
| `bag_catch` | Travel finished (J04) | Bag squash, left-arm dip | — | — | — | Tiny |
| `rejected` | Any failed action (§7.1) | Head-shake clip; bag wobble if "Bag full" | Shake plus amber flash | — | Toast shake; bag bar flash when full | Strong tick |
| `hold` / `hold_bag` | `_hold_target`, `_hold_bag_target`, `try_remove`, container take | Reach (both arms) | Pop | Lift and wiggle, then arc to hand (J04) | — | Light |
| `throw` | `_on_throw_requested` ok | Toss or fling | — | Tumble; landing puff and squash (J04) | — | Light |
| `place` | `PlacementService.try_place` ok | Place push | Pop | Arc, drop, land squash, contact ring, neighbor wobble (J05) | — | Medium on land |
| `deposit` | `WasteContainer` deposit or capture ok | Place push | Pop | Container fill bump plus puff (J10) | — | Medium |
| `clean` / `clean_done` | `ClothTool.try_clean` ok | Wipe | Pop / big pop | Stain smear plus sparkles; when done, gleam plus floater (J06/J07) | — | Light / medium |
| `cut` / `animal_freed` | `RescueKnife.try_cut` ok | Slash | Pop | Snip sparkles or bubbles; attachment travels to bag or drops; when freed, label pop plus bubbles (J06) | — | Light / medium |
| `detector_ping` | `MetalDetector` ping timer | Coil flash | — | Ground ring (J06) | Meter flash | Tiny when near |
| `reveal` | `MetalDetector.try_click` ok | Dig | Pop | Sand burst, pop-up, glint (J06) | — | Medium |
| `sift` | `SandCleaner.try_click` ok | Sift | Pop | Sand puff, ring contract, staggered arcs (J06) | — | Medium |
| `vacuum_tick` / `vacuum_full` | `VacuumTool` | Recoil / choke; continuous hum jitter | — / shake | Item stretches into nozzle; motes (J06) | Bag bump / flash | Tiny / strong |
| `equip` | `ProgressionService.try_switch_tool` / `try_equip` ok. The drop and rise run inside `HandRig.set_tool_scene` whenever the tool scene changes. | Old tool drops, new tool rises | — | — | — | Light |
| `scanner_pulse` | `ScannerService.pulse` ok | — | Pop | Sonar ring from the player (J06) | Markers pop in | Light |
| `unload`, `sort`, `seal`, `sell` | `SortingView` actions ok | (Hands hidden at table) | — | Cascade, arc into bin, bin bump, bag drop on rack (J08) | Bin fill bar, ✓/? stamp | Light, medium on seal |
| `collect_call` | `CollectionCallPoint` ok | — | Pop | Phone rings; containers lift off (J10) | Receipt, coins, money roll | Medium |
| `set_complete` | `session.group_completed` (via `main.gd`) | — | — | Shine, sparkles, floater (J07) | Notice; coins on first time | Medium |
| `section_restored` / `zone_restored` | Session signals (via `main.gd`) | — | — | Wave, bloom, beacon (J11) | Banner plus pointer (J11) | Pattern |
| `run_complete` | `session.run_completed` | — | Hidden | Effects finish under pause (J12) | Postcard results (J12) | Long soft |

### 7.1 Rejection call sites

Add `player.play_cue(&"rejected", {"reason": message})` next to each existing failure message:

- `PlayerCarry._collect_target`, `_hold_target`, `_hold_bag_target` and `_on_throw_requested`, on failure
- `PlayerInteractor.request_primary`, on the blocked branch
- `PlacementService._on_primary_requested`, on failure
- `ClothTool._on_primary_requested`, on failure
- `SandCleaner.try_click`, on each failure
- `VacuumTool._attempt_tick`, on capacity (use `vacuum_full` instead)
- `MetalDetector.try_click`, on failure
- `RescueKnife.try_click`, on failure
- `WasteContainer._on_interact_requested` and `_on_body_entered`, on failure
- `CollectionCallPoint._on_interact_requested`, on failure

Do not classify feedback text in `main.gd`, because success and failure messages share one signal.

## 8. Reduced motion

`reduced_motion` removes secondary motion only. The setting already exists and is persisted. Read it at effect start; a change mid-effect may finish that effect.

| Effect | Normal | Reduced |
|---|---|---|
| Hover | Outline pops in; item lifts and hops; rim breathes | Outline appears at rest width; no lift, hop or breathing |
| Reticle and label | Springs, pop, shake | Instant state changes; blocked shown by dashes and color only |
| Viewmodel | Bob, sway, breath, landing dip, clips at 100% | No bob, sway, breath or landing dip; clips at 50% with no overshoot; equip swaps with a short 40% rise |
| Collect | Yoink, arc, spin, shrink; bag squash | Existing behavior: the view is removed at once. The HUD bag bump still plays. |
| Prop pickup and remove | Lift, wiggle, arc | Straight travel at the same duration; no lift or wiggle |
| Throw impact | Puff plus squash | Puff at half count; no squash |
| Placement | Arc, drop, squash, ring, wobble | Straight travel kept (P27: keep placement travel); no squash, ring or wobble |
| Ghost | Appear, glide, breathing, scan bands | Appears at rest; snaps between slots; no breathing; bands static |
| Group sweep and clean gleam | Shine plus sparkles | No shine overlay (the existing check asserts this); floater fades in place |
| Tools | Continuous jitter and sweep; motes; rings | No jitter or sweep; motes halved; rings kept (they are positional); no ring contraction |
| Sorting table | Cascade, arcs, bumps, drag tilt | Instant proxies; the cursor snaps; stamps fade |
| HUD | Count roll, bumps, slides, coins | Numbers set at once; no bumps or slides; no coins, but the money line flashes once |
| Restoration | Wave, pop-in, sparkle field, beacon | Instant reveal (existing), banner, static pointer; no wave, pop-in, sparkles or beacon |
| Finale | Beat, flash, postcard, stamp, confetti, count-ups | No flash or confetti; postcard fades in; rows appear together with final numbers |
| Particles generally | Listed counts | Half counts; no particle leaves a 1.5 m radius |

## 9. Performance budget

The development RTX 3070 already shows p95 of 10.9–17.2 ms in the crowded view ([performance](../performance.md)), and the GTX 980 target is unverified. Effects must be cheap and bounded:

| Effect | Extra draws while active | Cap |
|---|---|---|
| Hover (ACTION) | 3 passes × surfaces of one object | 1 object |
| Ghost plus blob | 1 pass × surfaces, plus 1 | 1 ghost |
| Each active particle pool | 1 | Pool capacity (§5.5); CPU writes only live instances |
| Shine overlay | Surfaces of the group (usually ≤ 30) | 2 concurrent sweeps; more wait |
| Rings and waves | 1 each | 4 concurrent; extras are skipped |
| Floaters | 1 each | 3 concurrent; the oldest is freed |
| UI coins | ≤ 10 controls | 10 in flight |
| Confetti | 1 `CPUParticles2D` | Finale only |

Measure with the existing profile route, `tests/validate_physics.gd -- --profile --c04-dense`, before J00 and after J05, J11 and J14. Targets on the development GPU:

- p95 regresses by no more than 0.5 ms at rest.
- An effect burst (group shine plus wave plus vacuum) adds no more than 1.5 ms p95.
- Maximum draws rise by no more than 40.
- Node count returns to baseline within 3 s after any effect (`Performance.OBJECT_NODE_COUNT`).

If a budget fails, reduce in this order: pool capacities, sparkle counts, wave sparkles, beacon off, then hover rim off. Keep the outline and ghost. Target-hardware certification stays in FIN-10.

## 10. Packets, order and file ownership

| Packet | Outcome | Depends on |
|---|---|---|
| [J00](packets/J00-feel-foundations.md) | Tuning resource, motion helpers, particle kinds, rings, floaters, player cues, baseline evidence | — |
| [J01](packets/J01-hover.md) | Crack-free constant-width outline, rim, blocked style, hover lift; slotted, bag and station highlights | J00 |
| [J02](packets/J02-reticle-label.md) | Reactive reticle; animated, following, state-styled target label | J01 |
| [J03](packets/J03-viewmodel.md) | Arm pivots, bob, sway, breath, landing, swim, clip player, equip animation, bag fill and squash, held-prop selection | J00, J01 |
| [J04](packets/J04-pickup-throw.md) | Yoink, arc, stick-tip and nozzle paths, bag catch, puffs, prop pickup and slot removal travel, throw arm, tumble and impact | J03 |
| [J05](packets/J05-placement.md) | Hologram ghost with glide and blob; arc and drop travel; squash landing; contact ring; neighbor wobble; capture magnet | J04 |
| [J06](packets/J06-tools.md) | Per-tool clips, continuous motions and world effects for stick, cloth, knife, detector, sand cleaner, vacuum and scanner | J04 |
| [J07](packets/J07-completion-shine.md) | Shine shader replacing group sweep; set sparkles and floater; clean-done gleam | J05 |
| [J08](packets/J08-sorting-table.md) | Table cascade, cursor, hover lift, 3D drag, arcs into bins, bin fill, stamps, seal drop | J00 |
| [J09](packets/J09-hud.md) | HUD layout for bars and money, count roll, bumps, notice motion, glyphs, feedback toast | J02 |
| [J10](packets/J10-collection-money.md) | Phone ring, container lift-off and deposit bump, receipt motion, coin flights | J09 |
| [J11](packets/J11-restoration.md) | Bloom wave, staged reveal, sparkle field, beacon, banner, off-screen pointer, batching | J07, J09 |
| [J12](packets/J12-finale.md) | Pause-safe finish, postcard capture, results sequence, confetti, skip and continue | J11 |
| [J13](packets/J13-rumble.md) | Optional controller vibration setting and cue mapping | J04 |
| [J14](packets/J14-acceptance.md) | Feel recording, reduced-motion and FOV/resolution audit, performance, art-swap re-tune, handoff | All |

**Shared-file sequence.** Several packets edit the same scripts. Implement them in the numeric order below, one agent at a time per file:

| File | Packets, in order |
|---|---|
| `scripts/items/world_item.gd` | J01 → J04 → J06 → J07 |
| `scripts/items/placement_service.gd` | J01 → J04 → J05 → J07 |
| `scripts/player/carry.gd` | J03 → J04 → J06 |
| `scripts/player/hand_rig.gd`, `scenes/player/player.tscn` | J03 → J06 |
| `scripts/player/player.gd` | J00 → J03 → J13 |
| `scripts/player/interactor.gd` | J01 → J04 |
| `scripts/items/item_view_manager.gd` | J04 → J06 |
| `scripts/tools/scanner.gd` | J06 → J11 |
| `scripts/main.gd`, `scenes/main.tscn` | J02 → J09 → J10 → J11 → J12 |
| `scripts/world/restoration_section.gd` | J11 only |
| `scripts/stations/sorting_station.gd`, `scripts/ui/sorting_view.gd` | J08 only |

Parallel-safe pairs once J00–J03 are done:

- J06 ∥ J08
- J07 ∥ J08
- J09 ∥ J05 (they share no files)

## 11. Verification and evidence

### 11.1 Validation style

Follow [AGENTS.md](../../AGENTS.md) and [verification](05-verification.md):

1. Show each behavior in the real game (`scenes/main.tscn`, seeds `first-shore`, `feedback-sequence`, `restoration-fixture`) or an existing lab.
   - `tests/scenes/interaction_lab.tscn` for hover, reticle, collect and throw
   - `tests/scenes/placement_lab.tscn` for ghost, place, sets and clean
   - `tests/scenes/movement_lab.tscn` for viewmodel locomotion
2. Drive the scene with a temporary probe script or the godot-mcp `game_*` tools. Remove probes afterward and do not commit them.
3. Record setup, actions and observed result, with at least one still per packet, in [J-feel](../handoffs/J-feel.md).
4. Add a written check only for a real invariant (J01, J05 and J12 each name one small optional check). Never add one for a tween existing.
5. After each packet, re-run the existing checks that packet lists, using isolated user profiles as earlier handoffs did.

```powershell
$beachGodot = 'C:\Users\Home\Downloads\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe'
# Rendering-sensitive checks: run without --headless; add -- --capture where the script supports it.
& $beachGodot --path . --script res://tests/validate_placement.gd
& $beachGodot --headless --path . --script res://tests/run_checks.gd
```

### 11.2 Contracts that existing checks read (do not break)

| Check | Contract | Where it bites |
|---|---|---|
| `validate_interaction.gd` | After aiming: `glass.is_highlighted()` and `outline_overlay_count() > 0`; the knife-reason net is still `is_highlighted()`; the label text contains the name and `Collect [RT]` / `[X]` | J01 BLOCKED counts as highlighted; J02 keeps the label text |
| `validate_placement.gd` | `GhostRoot.visible` synchronously after `preview_slot`; the sweep overlay is present on the group only, cleared within 0.9 s, and absent under reduced motion; `VisualRoot.scale == ONE` 35 physics frames (~0.58 s) after `try_place` | J05 keeps place travel plus landing at or under 0.5 s (or updates the frame wait); J07 keeps `group_sweep_seconds` at or under 0.8 |
| `validate_full_run.gd` | `GhostRoot` visible on preview; `results_open` and tree `paused` synchronously after the final place; results visible after reload | J05, J12 |
| `validate_completion.gd` | `results.visible and results_open and paused` synchronously after the final place; guidance, receipt and progress panels do not overlap at 720p | J12 intro keeps `visible = true` immediately; J09 layout |
| `validate_ui.gd` | `progress_label.text` begins with `Completed 0 / 5,700\nRemaining 5,700\nProps 0 / 300\nTrash collected 0 / 5,400`; `context_label` contains `Bag 0 / 20`, `Bag 1 / 20` and `Poking stick`; guidance visible; `error_panel` hidden after reconnect | J09: first render is instant; the final text keeps this format |
| `validate_payment.gd` | Immediately after the hotline call: `collection_receipt.visible` and `details_label.text.contains("$80")`; `error_label.text == "Nothing to collect"` | J10 uses `visible_ratio` typewriter reveal and keeps `details_label.text` final |
| `validate_purchases.gd`, `validate_release_pack.gd` | `tool_socket.get_child_count() == 1` and `get_child(0).has_node("Visual/Shaft")` | J03: the dropping tool leaves `ToolSocket` at once, and the tip marker lives under the tool instance |
| `validate_movement.gd` | `socket_transform(&"left_prop").origin.x < 0`, right `> 0` | J03 returns rig-space transforms |
| `validate_carry.gd` | `bag_placeholder.visible` false while carrying and true after release | J03 keeps `visible` synchronous |
| `validate_dirt.gd` | Calls `hand_rig.set_tool_scene(scene)` with one argument | J03 keeps `tool_id` optional |
| `validate_c01_input.gd` | Service label text contains `[<interact binding>]` and never `E:` | J02 |

### 11.3 Per-packet evidence template

For each packet, record in J-feel:

- Build identity (commit, Godot 4.6.1 Compatibility, content 8)
- Scene and seed
- Device, resolution and FOV
- Actions taken
- Observed result, including stills and short clips where the packet asks
- Reduced-motion observation
- Checks run, with exit codes
- Profile delta, where the packet asks for one
- Retained tuning changes
- Open issues

A tween existing in the code is not evidence that the effect works.

## 12. Out of scope

- Sound, music or audio hooks. R29 and the release checklist exclude them. The cue list in §5.3 is the natural attach point if a future, separately approved audio pass ever exists; do not add players or buses now.
- Camera shake, FOV kicks, head bob, forced camera motion, cutscenes, slow motion and hit-stop.
- New gameplay: combo scores, streak multipliers, rewards for effects, timers.
- Replacing final art (FIN-05) or re-doing the rendering look (FIN-06/07).
- New settings beyond the optional J13 vibration toggle. Reduced motion covers motion sensitivity.
