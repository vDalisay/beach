# P30 — Optional arcade jetski

Dependencies: P18, P24, P29. Requirement: R31. **Optional: skip without reducing completion or release scope.**

**Outcome:** one simple surface-riding extra if explicitly chosen after required work is complete.

**Own files:** `scenes/vehicles/jetski.tscn`, `scripts/vehicles/jetski.gd`, optional definition/save fields and a small movement/dismount fixture.

**Steps**

1. Use the staged jetski body/steering pieces. Build a simple buoyant/arcade mover at the gameplay water plane with forward/reverse acceleration, steering and bounded speed. Do not use a wheeled VehicleBody setup for a boat or build a water-fluid simulation.
2. E mounts only with empty hands and safe proximity. Stow tool presentation, retain equipment/bag ownership, switch movement input context. E dismount finds a collision-clear nearby water/shore position; if none exists, refuse dismount with a prompt instead of trapping the player inside geometry.
3. Keep jetski within playable sea bounds. It cannot damage wildlife, destroy required litter, collect items automatically or carry containers. No fuel, repairs, races or quests.
4. Snapshot vehicle pose/occupancy. Loading or a recovery condition must produce either a valid occupied vehicle or a safe swimming/shore player with all inventory intact. Test controller prompts and exit to menus.
5. Park the non-rideable presentation at the dock when this packet is omitted. No required object, purchase or restoration depends on the vehicle feature.

**Acceptance:** surface movement, collision, boundary recovery, mount/dismount, controller support and save/load work without impacting P29's completion/save checks.

**Handoff:** actual inclusion decision, control values and edge-case evidence. Keep this optional scope separate from the required full game.
