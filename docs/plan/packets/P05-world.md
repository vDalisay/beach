# P05 — Full handcrafted beach blockout and authoring data

Dependencies: P01, P02, P04. Requirements: R02, R03, R09, R10, R22. Read: [world composition](../03-world-and-assets.md).

**Outcome:** the complete traversable beach layout, with authored semantic markers ready for clutter and storage.

**Own files:** `scenes/world/beach.tscn`, zone subscenes under `scenes/world/zones/`, `data/world/beach_01.tres`, `scripts/world/{section,spawn_anchor,placement_slot,recovery_anchor}.gd` as small authoring components.

**Steps**

1. Build curved sand/shore/seabed with native authored geometry and Synty environment candidates. Use primitive blockout only for level geometry or approved missing cubes. Place the essential pier, lighthouse, minimal city backdrop, promenade boundary, lifeguard towers, courts, seating areas and huts.
2. Mark the eight stable zones and 2–4 sections per zone. Assign explicit IDs in the Inspector; validate duplicates. Add three service points, one shop at S2 and a spawn at S1. Create safe beach recovery anchors with dry collision-clear space.
3. Measure baseline end-to-end walking route around 180 seconds. Ensure all required paths, hut doors and pier stairs accommodate the player's large carry pose. Add clear non-enterable backdrop boundaries and recoverable ocean/underside bounds.
4. Author compatible storage pools with enough total slots for all 300 props. Logical home groups can use any compatible storage section across the beach. Uniform interchangeable shelf sections avoid unusable leftover capacity after players claim them.
5. Create spawn anchor packs tagged for sand, piles, water surface, seabed, buried finds and attachments. Explicit exclusion zones keep paths/stations/slots usable. Author at least one valid pose for each planned object clearance class.
6. Reserve reef swim lanes and wildlife/turtle paths. Mark restoration visual roots independently from objective markers. Starting scene contains the whole map; no locked demo boundary.

**Acceptance:** walk entire beach and enter required huts with controller; no falls through terrain or inaccessible recovery point. World validator checks unique IDs, section coverage, slot capacity and anchor categories. Record coordinates and measured route, not only a screenshot.

**Handoff:** zone map, authoring conventions, stable IDs, available slot pools and anchor/resource paths. P25 will dress this layout without silently moving gameplay IDs.
