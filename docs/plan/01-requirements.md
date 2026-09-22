# Confirmed requirements and implementation defaults

The user's latest answer takes precedence: **full release only, no demo**. This document is the product authority for the work packets. Requirements use observable WHEN/IF/THEN statements where practical. Defaults fill gaps without reopening the completed question rounds.

**General validation rule:** keep written tests to a minimum and prioritize validated working systems in playable scenes with real game state. Simple checks remain appropriate for important invariants and difficult edge cases; do not set up a testing framework or extensive test arrangements. This applies to every packet; [verification](05-verification.md) defines how to record sufficient evidence without requiring a separate automated test for every acceptance case.

## Locked requirements

| ID | Required behavior |
|---|---|
| R01 | Use the supplied Godot 4.6.1 installation and GDScript. Ship singleplayer on Windows; target 60 fps, 8 GB RAM, GTX 980-class graphics. Preserve a viable later Linux port. |
| R02 | Build one handcrafted, fixed-sunny, LA-style private resort beach with about a three-minute baseline end-to-end walk, roughly 5,700 items and no human visitors. The seed changes clutter, buried finds and entanglements, not the beach layout. |
| R03 | Use supplied Synty Palm City art. Recreate the composition and feel of reference images 1–2: curved shoreline, pier, lighthouse, palms, minimal rear skyline/promenade, lifeguard towers, beach activity areas. The city is background and not enterable. |
| R04 | WHEN a required asset is unavailable THEN retain the feature with a coloured cube and record the asset the user needs to provide. Do not invent an external asset purchase or substitute pack. |
| R05 | Provide first-person WASD/mouse and controller movement, jumping, sprinting, crouching, visible hands/tools and a left-hand trash bag. No third-person mode. |
| R06 | WHEN LMB is pressed once with the poking stick on eligible trash THEN collect one item directly into the bag. Holding LMB does not repeat pokes; no stick stack. Initial bag capacity is 20. |
| R07 | Bag equipment is permanent and separate from two handheld tool slots. Reusable objects stow tools/bag visually; carry two small props, one per hand, or one large prop using both hands. |
| R08 | WHEN RMB is pressed in tool mode THEN throw the last collected bag item. WHEN carrying props THEN throw the most recently picked up held prop. Objects have physical collisions and throws. |
| R09 | WHEN aiming at a valid nearby slot THEN show an object-shaped placement ghost. WHEN LMB confirms THEN move the prop into place, orient it to the slot front, and pulse its visual scale. Valid physical throws into storage/bin targets also count. |
| R10 | Placement uses predefined compatible slots. A shelf section is claimed by the first object's type and becomes unassigned when emptied. Players may use any compatible section, and freely rearrange/drop objects outside destinations. |
| R11 | IF furniture is dirty THEN it must be cleaned with a purchasable cloth before sorted placement can complete. Only some furniture starts dirty. Furniture dirt does not add a second required object. |
| R12 | WHEN using the sorting table THEN the bag contents appear on a physical table and the camera changes to a bird's-eye view. Support drag-to-bin and select-bin-then-click, including controller operation. |
| R13 | Provide PMD, organic, general and glass sorting. PMD includes plastic/metal packaging and drink cartons. Nets and similar miscellaneous waste use general. Incorrect categories are allowed and reduce payment; they do not prevent completion. |
| R14 | Pay a base amount per item, doubled when correctly sorted. Assess correctness from the final category at sealing/collection, allowing correction before sealing. Balance purchases around an average 1.5× base payment. |
| R15 | Seal category bags automatically at a capacity threshold or manually on request, including partial bags. Players physically carry them to matching large containers. Call collection explicitly; a short event is sufficient. |
| R16 | WHEN collection completes THEN pay for its items and count those trash items complete. Collecting, table sorting, or container deposit alone does not complete a trash item. |
| R17 | Money buys skills in the booklet and physical tools from a shop. Two handheld tools can be equipped at once. Tools have unrestricted use: no batteries, consumables, durability or fuel. |
| R18 | Provide sand cleaning, vacuum, detector, flippers and oxygen upgrades. Detector finds include both ordinary buried waste and valuables. Poking remains click-only; vacuum may collect continuously. |
| R19 | Allow free diving. Initial underwater air lasts 10 seconds; a purchased oxygen tank gives 60 seconds; a later upgrade gives unlimited breathing. At zero air, fade briefly and respawn at the nearest authored safe beach point. |
| R20 | Fainting drops bagged trash, held reusable props and carried sealed waste bags at the faint location. Purchased equipment stays with the player. Mark the dropped pile for recovery. |
| R21 | Animals cannot be injured and rescues cannot fail. Use a knife to remove attached litter through simple point-and-click actions. Freed animals stay in the area. Removed attachments are loose trash objectives, not extra animal objectives. |
| R22 | WHEN every local task is complete, including truck collection of local litter, correct placement/cleaning and rescues, THEN restore that habitat. More fish, vibrant coral, clearer water/sand and turtle routes provide visible rewards. No human visitors return. |
| R23 | Restoration is permanent within the run. Re-picking a sorted prop may make a group/current progress incomplete, but cannot undo restored nature. Group celebration may replay; monetary group rewards may happen only once. |
| R24 | Top-left HUD: combined required-object progress, then reusable-prop and loose-trash breakdowns, then money. Recompute after relevant state changes. Show bag/oxygen context elsewhere without obscuring these counts. |
| R25 | WHEN all required trash is collected and all required props are clean and correctly placed THEN show results. Allow continued walking afterward. No trash respawns in that run. |
| R26 | Seeded generation must reproduce item types, locations, buried finds and rescue attachments within the same game/content version. No promise of identical physics trajectories or cross-version generation. |
| R27 | Support autosave, manual saves, multiple saves, save-and-quit during sorting, and separate beach runs. Money and upgrades belong to the run, not a global profile. |
| R28 | Scanner filters unlock after collecting a matching type/material once: e.g. bottles or plastics. It helps locate remaining matching items. |
| R29 | Use native Godot InputMap and UI facilities for controller support and rebinding. Entire gameplay and menu flow must be usable with a controller. No sounds required. |
| R30 | Preserve a straightforward path to eight-player shared-world co-op with join-in-progress. Future default is personal inventory/equipment/money/upgrades, with configurable sharing. Do not build multiplayer for this release. |
| R31 | Online leaderboards are later work, recording player count, elapsed time and amount of trash. Rideable jetski is optional even for the final game; other vehicles are scenery/reusable content where appropriate. |
| R32 | Produce detailed Markdown work packets, file/scene ownership, contracts, dependencies, acceptance checks and handoff evidence. No time-management material. |

## Defaults adopted to remove remaining implementation ambiguity

| ID | Default and reason |
|---|---|
| D01 | Start all geographic areas open. Equipment, air duration and distance create progression; no invisible chapter gates. |
| D02 | Required manifest has exactly 5,700 IDs: 5,400 waste and 300 reusable props. Forty seeded valuables are optional and excluded from the completion denominator. This interprets “roughly 5,700 items” as required cleanup objects. |
| D03 | Required detached seagull residue on sand is a general-waste item. Cloth converts that same ID into bagged residue; it completes at collection. Furniture stains are properties of the furniture, not extra litter. Fixed shoreline/terrain is authored level geometry; it is not a pickup. |
| D04 | Use eight restoration zones with smaller authored objective sections such as a coral bed. Sections may restore independently after all their own objectives complete; whole-zone turtle/landscape rewards require all sections. A section is a place, not “all glass everywhere.” |
| D05 | Every objective has an immutable home section/zone. Carrying an item across the beach never moves its restoration credit. A prop may use any compatible physical slot across the beach; its completion still credits its original home section. |
| D06 | Prop type/family means logical sorting family, not colour variant. Red and blue sand buckets may share a bucket shelf; bucket and ball may not. Empty shelf sections release their claim. Sufficient compatible capacity must exist for every legal allocation. |
| D07 | Free placement is physical dropping/throwing. It does not count as sorted until captured by a compatible slot. Large structural buildings, pier, lighthouse, fixed shop/stations and distant yachts are static, while named portable beach props are interactive. |
| D08 | Passive purchased flippers and oxygen gear do not occupy handheld slots. Starting equipped handheld tool is the stick; second slot is empty. The bag appears in the left hand while using a tool, including the knife; it is hidden while hands carry props. |
| D09 | Changing the two equipped handheld tools happens at the physical shop rack. Switching between those two tools works anywhere. Purchased tools stay owned if unequipped; the shop can re-equip them for free. |
| D10 | Start with $0. First dry beach litter is reachable with the stick. Early payments fund cloth/knife and later required tools. No tool rental, stock shortage, payment penalties below base, consumable cost or missable purchase can block completion. |
| D11 | All ordinary waste consumes one bag unit, including bundled nets and sealed oil containers; their pickup visuals can shrink into the bag. Reusable large objects never enter it. Sealed disposal bags occupy one hand; two can be carried. |
| D12 | Table has 240 stable display cells; maximum player bag is 200. Unload transfers the whole bag only when enough cells are free. Otherwise keep it intact and request space. Camera zoom/pan and focus navigation keep small objects selectable. |
| D13 | Each category bin seals at 50 items; output rack has eight bag positions. A full rack leaves a full bin waiting to seal and rejects further deposits into that bin until room is made. Empty manual sealing is invalid. Large containers have unlimited logical capacity, shown by bounded representative visuals. |
| D14 | Sealed disposal bags cannot reopen in this release. Wrongly sorted contents remain payable at base rate. Containers accept bags by their declared category, not by inspecting whether contents were accurate. |
| D15 | Collection can be called at the station with E even for one partial bag. Empty calls change nothing. Collection briefly locks eligible bags, commits payment/completion once, then plays a short visual event. No truck-driving NPC AI. |
| D16 | Valuables occupy bag units but have no waste category. On table unload they are identified and travel to a labelled valuables tray; an explicit sell action at the station pays their fixed value once. No valuable can be destroyed, incorrectly sorted or required for mandatory purchases. |
| D17 | Freeing an attachment succeeds even with a full bag; it falls nearby as collectable waste instead of disappearing. Animal release is permanent; the area's restoration still waits for truck collection of that waste. |
| D18 | Oxygen refills to full upon sustained surfacing for one second. Breath state uses camera/head submersion with hysteresis. Faint recovery preserves uncollected items and their IDs; repeated fainting must not multiply piles. |
| D19 | Pause and booklet pause singleplayer simulation, oxygen and active-play timer. Sorting is active gameplay and advances the timer. Save/load, pause and results time are excluded; future online timing requires separate verified rules. |
| D20 | Completion and result receipt latch on first valid finish; post-results rearrangement updates current prop counts without restarting the finished run or paying rewards again. Initial completion results remain immutable. |
| D21 | English interface, readable labels and colour-independent category icons. Provide sensitivity, invert-Y, FOV, UI scale, reduced motion, sprint/crouch toggle options and input remapping. Controller disconnect pauses singleplayer. |
| D22 | The scanner is a booklet skill, not a handheld tool. It scans globally for a selected unlocked type/material; show nearby markers and a direction/count for far matches. Hidden buried items need detector revelation before scanner targeting. |
| D23 | Uncollected objects falling outside valid play bounds are returned to a nearby authored recovery point with the same ID. This is recovery, never trash respawning. Do not secretly collect or pay them. |

Defaults are deliberately explicit so agents do not make conflicting guesses. Adjust tuning in the designated resources after playtesting and record the change; do not replace R01–R32 with different behavior.

## End-to-end acceptance examples

- WHEN 20 waste items are in the starter bag AND the player clicks another THEN it stays in the world, the bag stays at 20, and a readable full-bag cue appears.
- WHEN an item is put in the wrong table bin AND moved to its correct bin before sealing THEN it earns double base payment when collected.
- WHEN a 50-item PMD bag contains 30 correct and 20 incorrect items THEN collection pays $80 at the default $1 base and completes exactly 50 waste IDs.
- WHEN a dirty chair is thrown into an empty chair slot THEN it remains unsorted and the UI requests cleaning; it cannot bypass the cloth requirement.
- WHEN the final local waste is bagged but not collected THEN that section does not restore. WHEN its collection finishes and all other local tasks are done THEN restoration begins once.
- WHEN a player subsequently removes a chair from that restored area THEN current prop progress falls by one, group animation becomes eligible again, but coral/wildlife and paid group rewards do not reset.
- WHEN a save is loaded while objects previously occupied the table, bins, hands and containers THEN every ID returns to exactly one of those locations, with money and oxygen state preserved.
- WHEN two new runs use the same seed and version THEN their starting manifests match exactly; their run save IDs, progress and money remain independent.
