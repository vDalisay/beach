# P15 — Shop, owned equipment and booklet skills

Dependencies: P03, P11, P14. Requirements: R17, R18. Read: [purchase table](../04-content-and-balance.md).

**Outcome:** the cleanup economy buys concrete efficiency and required-access upgrades without bypassing physical tool collection.

**Own files:** `scenes/stations/equipment_shop.tscn`, `scripts/stations/equipment_shop.gd`, `scripts/core/progression.gd`, `data/tools/*.tres`, `data/upgrades/*.tres`; basic native shop/booklet controls; `purchases` checks.

**Steps**

1. Populate Resources with the exact initial price/value/prerequisite table. Tools/bags/passive gear come from the physical shop; movement/reach/scanner skills are bought in the booklet. Unimplemented tools may be test-visible but cannot be advertised functional in a shipped build.
2. Shop purchase validates proximity, money, ownership and prerequisites. Payment and owned state change atomically. A purchased handheld tool appears at its labelled rack position; equipping into an empty slot or explicitly replacing one is free and physical.
3. Maintain max two handheld slots, permanent bag, passive flippers/tank and selected active tool. Unequipped owned tools stay owned. Duplicate purchase or failed equip cannot lose money or equipment.
4. Booklet on Tab/View displays current skills, exact next effect/cost and locked prerequisites. Purchase uses the same progression service, not button-local wallet arithmetic.
5. Recalculate derived stats from base plus saved levels each time; never repeatedly multiply speed/capacity after load. Bag upgrades retain all contents. Gear upgrades never remove already available capabilities.
6. Pause singleplayer during booklet/shop UI. Show an explicit result for insufficient funds/already owned and restore focus after buying. Mark all price constants as tunable Resources.

**Acceptance:** `purchases` tests insufficient funds, dependency order, duplicate click, full loadout replacement and recomputation from a saved purchase set. Follow one normal collect→pay→buy cloth→physically equip→clean chair loop. Controller can perform the whole purchase flow.

**Handoff:** populated definitions, stat calculations, shop rack behavior and confirmed $0-start progression. Optional purchases never become a requirement for collection calls.
