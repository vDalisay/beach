# P10 — Shelf claims, snapping and reversible sorting groups

Dependencies: P05, P09. Requirements: R09, R10, R23. Read: group versus shelf distinction in architecture.

**Outcome:** any compatible destination accepts a clean prop with a ghost, travel animation and reversible occupancy.

**Own files:** `scripts/items/placement_service.gd`, `scenes/items/placement_slot.tscn`, `shaders/placement_ghost.gdshader`, slot/group tests. Extend P05 markers instead of adding a second slot type.

**Steps**

1. Define slot front transform, physical clearance, accepted prop families and shelf section ID. A first committed occupant claims that physical section's family; variants share a family. Preview is read-only.
2. `preview_slot` validates selected held prop, cleanliness, occupancy, range, family and clearance. Show ghost only on a valid nearby target. Mesh is reused with translucent presentation, auto-oriented to the slot front.
3. `try_place` repeats validation, changes ownership/occupancy/claim atomically, then animates the view to the slot. Pulse visual root 1→1.08→1. Stop/cancel a tween without leaving a phantom reservation.
4. Physical capture at a valid slot opening calls the same validation/commit function for a WORLD prop. Use a trigger/entry check that cannot pull objects through shelf walls. Invalid throws continue as ordinary physics, with no credit.
5. Picking up a slotted item releases occupancy immediately; removing last occupant clears its physical family claim. Current prop/group count decreases. P20 later owns reward/restoration latches.
6. Count logical home-section family completion independently of which compatible physical shelves hold its items. Cross-beach sorting is allowed. Validate uniform shelf pool capacity so player choices cannot make the remaining arrangement impossible.

**Acceptance:** `slots` covers first claim, mixed-family refusal, colour variants, empty reset, occupied slot, dirty chair, invalid/valid thrown capture and repeated re-pickup. Exactly one completion event per false→true transition; no payment in this service.

**Handoff:** slot/family IDs, capture geometry, group event payload and before/after screenshots for chairs, buckets and upright boards.
