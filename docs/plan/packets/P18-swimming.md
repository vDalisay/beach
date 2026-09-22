# P18 — Swimming, oxygen and faint recovery

Dependencies: P04, P07, P09, P13, P15. Requirements: R19, R20. Read: water and carry-release contracts.

**Outcome:** freely dive, upgrade breathing and recover all carried cleanup objects after running out of air.

**Own files:** `scripts/player/swim.gd`, `scripts/world/water_volume.gd`, `scenes/world/water_volume.tscn`, oxygen feedback and `faint` checks. Final water art belongs to P25.

**Steps**

1. Water volumes define a stable gameplay surface, bounds and seabed. Transition movement from wading to swimming; camera/head depth determines submersion with small hysteresis to prevent wave-edge flicker. Jump/crouch become swim up/down.
2. Track air at 10 seconds initially, 60 with tank, unlimited after upgrade. Refill after one second continuously above water. Pause/booklet freezes air. Display remaining air early enough to surface deliberately.
3. At zero air, guard against repeated faint requests. In one state change snapshot bag IDs and hand refs, empty carry locations, create validated drop poses around the faint point and retain tools, upgrades, wallet and discoveries. Dispose no content.
4. Loose items become WORLD; carried disposal bags retain SEALED contents and become WORLD bags. Reusable props retain dirt/home IDs. Items remain at the underwater faint area, with bounded drift and recovery markers. Store each pile's dropped item/bag refs in RunState; markers track its remaining WORLD members and disappear when none remain. Recovered refs leave the old pile before a later faint can put them in a new one.
5. Select nearest authored valid dry recovery anchor by spatial distance with stable tie-break. Fade out/in, reset player position/velocity and air, and request save. Fainting while already recovering does nothing.
6. Implement buoyant/sinking item profiles with simple native forces for nearby active objects. Visual wave crests do not dictate breath and deterministic starting poses. Prevent required objects moving beyond valid ocean boundaries.

**Acceptance:** `faint` uses mixed bag/prop/disposal-bag contents and verifies exact IDs/locations/equipment/money before and after. Run a playable recovery swim after each oxygen tier. Test camera near surface, crouching at shoreline, water under pier, pause at low air and repeated faint/load.

**Handoff:** surface/depth conventions, respawn selection, marker schema, breath settings and screenshot of an actual dropped recoverable pile.
