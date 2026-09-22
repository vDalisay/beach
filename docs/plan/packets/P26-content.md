# P26 — Complete content population and economy validation

Dependencies: P06, P15, P16, P17, P19, P23, P25. Requirements: R02, R17, R18, R25, R26. Read: world/category budgets and purchase table.

**Outcome:** one complete authored beach with all required families, exact quotas and a finishable economy.

**Own files:** final `data/items/*.tres`, `data/world/beach_01.tres`, section/category quota resource, full upgrade/tool resources and anchor packs; `content_totals` / `economy_reachability` checks.

**Steps**

1. Build a section×category matrix whose row sums match section/zone budgets and columns match 2,700 PMD, 900 organic, 1,200 general, 600 glass. Separately allocate 300 props. Keep optional 40 valuables outside both totals.
2. Add all requested litter families, assigning explicit material/category/tool tags even for cubes. Mark bundled nets/oil containers, standalone residue, buried waste and animal attachments. Validate the 300/24/120 waste subsets and 60 dirty props without double-counting.
3. Populate varied anchor patterns: scattered litter, grouped food waste, dense bin piles, floating trash, seabed/rescue areas and buried finds. Avoid hiding rare required types inside opaque meshes. Leave sightlines, walk lanes, stations and slot entry paths clear.
4. Populate portable props and compatible destinations, with enough interchangeable shelf capacity under every legal claim arrangement. Test all buckets first, mixed colours and deliberately inefficient shelf choices. Full count cannot depend on optional riding.
5. Validate $0-start progression using base-only trash payment and no valuables/groups. At least 1,000 exposed starter-accessible waste IDs fund all required tool purchases. Reconcile upgrade price totals programmatically and record any tuned changes.
6. Play the full loop at early/mid/late completion fractions. Tune efficiency and travel burden using observed behavior, not a claim of matching unmeasured reference-game timing. Maintain click-only stick and physical bag carrying.
7. Rebuild content version/hash and golden fixtures only when deliberate content changes require it; document why. Do not change seed algorithm casually to hide bad anchors.

**Acceptance:** both content checks pass; ten-seed build checks find no missing family/slot and no unfinishable required work. Demonstrate first restoration with starting tools and deeper reef completion with purchased gear. Scan known filters near the final few objects.

**Handoff:** exact machine-readable quota matrix, total price proof, playtest observations, final required/optional catalogue and golden manifest version.
