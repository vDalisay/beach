# Initial content and balance specification

All numbers here except the approved 20-item starter bag, 10/60/unlimited air and roughly 5,700-object target are **tuning defaults**. They provide concrete values for implementation, not researched claims about other games' pacing. Tune through completed-item fractions and actual playtests; there are no development-time estimates.

## Required-object accounting

| Kind | Count | Completion |
|---|---:|---|
| PMD waste | 2,700 | Truck collection, regardless of sorting accuracy |
| Organic waste | 900 | Truck collection |
| General waste | 1,200 | Truck collection |
| Glass waste | 600 | Truck collection |
| Reusable props | 300 | Clean and in a compatible predefined slot |
| **Required total** | **5,700** | All required conditions met |
| Optional buried valuables | 40 | Extra sales/results statistic, no completion dependency |

Within the 5,400 waste IDs include 300 buried metal waste (200 PMD packaging + 100 general scrap), 24 attached rescue pieces (12 rescues × 2 pieces), and 120 detached seagull-residue patches. These are subsets, not additional objects. Within the reusable props include 60 dirty chairs/loungers with 1–3 authored stain patches each. Definition variants, patches, reward fish, bags and tools never inflate the objective count.

Default spatial proportions: roughly 60% singles/light clusters, 25% dense bin/food-area piles, 15% water/restoration points. These are art distribution guides; the immutable zone/category quotas are exact. Each section's authored quotas must reconcile both tables; produce the initial machine-readable matrix and complete logical item catalog in P06, then tune and finalize them in P26. Validate row and column sums at both stages. Do not choose waste category randomly without preserving totals.

| Category | Examples / explicit rules |
|---|---|
| PMD | Drink cans, plastic drink bottles/cups, plastic wrapping, six-pack plastic rings, empty drink cartons. Bottle material is defined per item, never inferred from colour. |
| Organic | Loose fries, hamburger food, fallen ice cream/cone, fruit/food scraps. Composite decorative meshes use a single authored gameplay category, displayed by the inspection label. |
| General | Nets, towels discarded as waste, dirty paper towels, bundled scrap, sealed oil containers, detached seagull residue. No hazardous-waste simulation or fifth hidden bin. |
| Glass | Glass bottles/jars. Different definition IDs from plastic bottles, even if temporary cubes look similar. |
| Reusable | Chairs, loungers, portable parasols/tents, buckets, spades, balls, coolers, boards, portable inflatables/lifebuoys, small boats and speakers. Clean towels can be a separate reusable definition only if deliberately included in the prop quota. |
| Valuables | Keys, jewellery/coins or compatible supplied objects; detected, collected, sorted into valuables tray, sold once. No gambling/randomized post-discovery reward. |

The art pack contains unrelated city/weapons/adult-themed props. Select only content needed for the approved beach and rescue tool; do not populate unrelated item families simply because they exist.

## Reusable family and storage budget

These default family allocations reconcile the 300 props with each zone's quota. They describe origin/objective credit, not a requirement to use storage in the origin zone. Colour/style variants share one family.

| Family | Arrival | Sports | Lounges | Sandplay | Pier | Shallows | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| Beach chairs | 8 | 6 | 44 | 0 | 12 | 0 | 70 |
| Loungers | 4 | 0 | 36 | 0 | 10 | 0 | 50 |
| Parasols | 4 | 2 | 12 | 2 | 0 | 0 | 20 |
| Coolers | 2 | 4 | 4 | 6 | 0 | 0 | 16 |
| Beach balls | 4 | 6 | 0 | 14 | 0 | 0 | 24 |
| Volleyballs | 0 | 12 | 0 | 0 | 0 | 0 | 12 |
| Buckets | 2 | 0 | 0 | 28 | 0 | 0 | 30 |
| Spades | 2 | 0 | 0 | 22 | 0 | 0 | 24 |
| Surfboards | 0 | 2 | 0 | 0 | 4 | 10 | 16 |
| Portable inflatables | 2 | 0 | 2 | 8 | 0 | 0 | 12 |
| Lifebuoys | 0 | 0 | 0 | 0 | 2 | 6 | 8 |
| Speakers | 2 | 4 | 0 | 0 | 0 | 0 | 6 |
| Portable tents | 0 | 2 | 2 | 0 | 0 | 0 | 4 |
| Small rowboats | 0 | 0 | 0 | 0 | 0 | 4 | 4 |
| Paddles | 0 | 2 | 0 | 0 | 2 | 0 | 4 |
| **Total** | **30** | **40** | **100** | **80** | **30** | **20** | **300** |

Small shelves serve buckets, spades, beach balls, volleyballs and speakers: 96 objects. Default authoring is 20 interchangeable sections of six slots, shared among these five families. When a previously empty section would be claimed, validate that remaining unplaced items can still fit: for each family subtract free space in its existing claimed sections, divide remaining demand by six with ceiling, and sum; this must fit remaining unclaimed sections. Reject an unsafe new claim with “Use an existing [family] section with room.” This preserves flexible rearrangement without a general-purpose packing solver. Picking up an item is always allowed.

Other families use clear floor racks, rows, upright board positions or moorings with at least their listed counts. These destinations can accept compatible visual variants. Sandcastles and fixed sports-net posts are authored scenery; buckets/spades/balls are the sortable equipment. P05 may increase storage capacity during authoring, but may not remove the feasibility check from shared shelves merely because a normal placement order fits.

## Payment and progression

Base waste price = $1; correctly sorted = $2. For N collected items of which C are correct: `payment = N + C`. Balance baseline is $1.50 per waste item (50% correct); it is not a third payout multiplier. Minimum complete-run waste earnings $5,400; baseline $8,100; perfectly sorted $10,800. Incorrect sorting always permits progress and never produces debt.

Each logical prop-family group gives $15 the first time it completes; treat this and optional valuables as bonus money, never mandatory progression funding. Valuables sell for $10 each initially ($400 total). Group IDs and reward receipts are fixed in content, not generated by how many shelves players split a family across.

| Purchase | Price | Exact initial effect / prerequisite |
|---|---:|---|
| Cloth | 30 | Clean one aimed stain patch per click; shop, no prerequisite |
| Rescue knife | 60 | Remove one aimed attachment per click; shop |
| Bag 40 | 60 | 40 units; shop, replaces 20 capacity |
| Flippers | 80 | Passive swim speed 2.5→4.0 m/s; shop |
| Walking I | 80 | Walk 3.5→4.2 m/s; booklet |
| Detector | 180 | Reveal buried metal/valuables within detection radius; shop |
| Oxygen tank | 220 | 60 seconds air; shop |
| Bag 80 | 180 | 80 units; requires Bag 40 |
| Scanner | 150 | Known definition/material filter and pulse; booklet |
| Sand cleaner | 250 | Up to 6 eligible exposed sand items per click, 1.0 m radius; shop |
| Reach I | 120 | Interaction reach 2.5→3.25 m; booklet |
| Vacuum | 450 | Up to 8 eligible small items/sec while held, 3 m range, 25° cone; shop |
| Walking II | 220 | Walk 4.2→4.9 m/s; requires Walking I |
| Bag 140 | 360 | 140 units; requires Bag 80 |
| Reach II | 260 | Reach 3.25→4.0 m; requires Reach I |
| Unlimited breathing | 700 | Passive unlimited air; requires tank |
| Bag 200 | 650 | 200 units; requires Bag 140 |
| Sand cleaner II | 450 | Up to 12 eligible exposed items, radius 1.5 m; requires sand cleaner |
| Vacuum II | 800 | Up to 16 eligible items/sec, 4 m range; requires vacuum |

Default total for all listed purchases is $5,300; mandatory access tools cloth + knife + detector + tank cost $490, or $1,190 including unlimited breathing. Ordinary exposed starter-accessible dry waste must fund the $490 route even if every item is mis-sorted; enforce at least 1,000 such waste IDs across accessible dry sections. Flippers make travel easier but are not a prerequisite to surface or return to land. Optional valuables and group bonuses are not required for this proof.

The 1,000-item floor proves one affordable route, not freedom from spending dead ends. For example, vacuum + sand cleaner + scanner + Walking I + Bag 40 cost $990 and can exhaust that guaranteed income before the cloth is bought. P26 must also validate every reachable affordable purchase set against remaining base-only income accessible with its owned equipment. After collecting all currently reachable waste, each unfinished state must still have a sequence of affordable access purchases that unlocks the remaining objectives. Include air-limited routes and free rack re-equipping, and exclude bonuses/valuables. If this fails, adjust the existing tuning defaults (prices, optional-upgrade prerequisites or accessible content quotas) and repeat the proof; do not add respawning waste, mandatory correct sorting or an undisclosed bailout. Total end-of-run earnings alone cannot establish this invariant.

Do not introduce an auto-poke or hold-to-poke upgrade. Extra bag capacity, reach, walking, sand cleaner and vacuum create efficiency. All prices/values live in Resources; never hardcode prices in button scripts. Upgrade values recompute from purchased levels to prevent repeated application after loads. No reselling purchased equipment is needed.

## Tool target matrix

| Target | Stick | Cloth | Knife | Sand cleaner | Vacuum | Detector |
|---|---|---|---|---|---|---|
| Exposed small loose waste | One click | — | — | Sand-only eligible cluster | Continuous eligible cone | — |
| Large bundled waste | One click | — | — | — | — | — |
| Standalone residue patch | — | One click, same ID to bag | — | — | — | — |
| Dirty furniture patch | — | One patch per click | — | — | — | — |
| Animal attachment | — | — | One click, bag if space else drop | — | — | — |
| Hidden buried metal/find | — | — | — | — | — | Reveal at closest valid ping |
| Revealed buried waste/find | One click | — | — | Waste if eligible | Waste if eligible | — |
| Reusable prop | Contextual hand pickup | Contextual hand pickup when clean | Contextual hand pickup | Contextual hand pickup | Contextual hand pickup | Contextual hand pickup |

Tool precedence: an aimed dirty furniture patch requires cloth; it must not start carrying on the same click. Reusable clean props can be picked up with any active tool and stow the tool; dirty furniture can be carried by an explicit alternate pickup prompt, then dropped for cleaning, but cannot snap until clean. This avoids making a dirty chair an immovable blocker.

Sand cleaner processes up to available bag capacity, ordered by distance then ID, skipping ineligible/occluded targets. Vacuum uses the same collection API one item at a time and stops at full capacity. Neither gathers attachments, valuables, furniture, hidden items or residue. Knife has no damage action. Detector starts with 4 m radius; proximity meter highlights one nearest buried target, LMB reveals it when within 1.5 m of its authored dig-surface point and that point is visible. The covering sand is expected: test visibility to the surface, not to the hidden mesh below terrain. Buildings, rocks and intervening terrain still block digging. Reveal into a collision-clear authored surface pose. A free “lift from sand” presentation needs no separate purchasable shovel. Revealing never directly pays money.

## Movement, water and restoration defaults

- Baseline walk 3.5 m/s, sprint ×1.45, crouch ×0.5, swim 2.5 m/s. No land stamina. Two-handed props reduce movement to 80% but never prevent jump or exit from water. Tune jump/capsule for the authored pier steps and hut doors.
- Oxygen follows confirmed 10 s → 60 s → unlimited; UI still indicates immersion with unlimited gear. Faint fade 0.5 s out/0.5 s in, full air on safe respawn. Carried objects are released at validated nearby underwater positions around the faint point, not erased or returned to shore.
- No current can carry required litter outside the playable boundary. Cosmetic waves do not move stable authored spawn anchors. Buoyant items settle near a gameplay water plane; dense glass/scrap sinks to accessible seabed.
- A restored coral section changes local coral material/tint over approximately 2 s and adds one or two fish schools. Completing its whole zone enables additional turtle paths. Individual rescues release their animal immediately without waiting for the truck.
- A restored beach section removes residual decorative dirt and brings back local plants/shore life. Zone `lounges` enables an authored turtle walk to the water. Wildlife never blocks sorting slots or pickup rays.
- Do not hide required litter under restoration foliage. Wildlife population caps and cosmetic route loops are content parameters; they never add objectives.

## Tuning acceptance

The first small restoration section must be finishable with starting tools, and the player can purchase a useful upgrade after one or two starter-bag collection cycles at the baseline payment. Mid-run tools should visibly increase items collected per action. All required access purchases remain affordable at base-only payouts. With these defaults all listed upgrades are affordable by completion even at minimum waste payout; correct sorting and bonuses make them affordable earlier. Optional upgrades never become completion prerequisites.

Measure pickup rejection rate, sorting errors, travel proportion, repeated full-table blocks, discovery of required tool uses, and last-item search difficulty. Record observed behavior and change specific tuning values. Do not claim to have matched other games' pacing without playtesting.
