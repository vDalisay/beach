# P16 — Sand cleaner and vacuum

Dependencies: P09, P15. Requirements: R17, R18. Read: target matrix and throughput defaults.

**Outcome:** purchased tools visibly speed collection while respecting the same inventory, eligibility and visibility rules.

**Own files:** `scripts/tools/{sand_cleaner,vacuum_tool}.gd`, tool scenes/definitions and upgrades, `tool_filters` checks. Reuse ItemStore collection; do not create a tool-specific bag.

**Steps**

1. Sand cleaner uses a ground-targeted patch preview. On a fresh primary click, query eligible exposed sand litter within radius, sort by distance then stable ID, and collect up to tool count and free capacity. It cannot clean furniture or reveal buried items.
2. Vacuum works while primary is held, at a capped item-per-second rate, in the configured forward cone. Exclude through-wall targets and choose the closest eligible items. Stop immediately on release, full bag, menu, tool change or carried-prop mode.
3. Process collection through the normal validated method; animation can travel along a curved path into the nozzle, then disappear into bag ownership. Limit simultaneous trails/particles without reducing actual gameplay throughput.
4. Show clear full-bag/invalid-surface feedback. No batteries, fuel, consumables or maintenance. Animation interval is not an inventory cost.
5. Apply upgraded count/radius/rate from progression. Preserve the stick's one-click-only behavior. Scanning for candidates must use active nearby views/areas or a bounded registry query, not 5,700 per-item `_process` functions.

**Acceptance:** `tool_filters` compares exactly collected IDs for a known patch/cone with an occluding wall, attachment, valuable, dirty chair, hidden find and nearly full bag. Hold/release tests demonstrate vacuum repeat and no stick repeat. Visual travel cannot duplicate pickup if two candidates leave range during the animation.

**Handoff:** radii/rates, eligible tags, shared query/helper location, reduced-motion presentation and screenshots of both tool actions.
