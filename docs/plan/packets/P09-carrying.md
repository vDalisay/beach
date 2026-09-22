# P09 — Bag inventory, hands and LIFO throws

Dependencies: P02, P08. Requirements: R06–R08, R20. Read: ownership transitions and D08–D11.

**Outcome:** one-click collection into a 20-item bag, physical prop carrying and correct throws without duplication.

**Own files:** `scripts/player/carry.gd`, extend `ItemStore`, `HandRig`, and item view methods; implement `carry_lifo` checks.

**Steps**

1. `try_collect` validates target tool eligibility, range/occlusion, state and bag capacity. Append ID to ordered bag; mark definition/material discovered. Commit first, then animate a temporary view to the bag socket and hide it.
2. Primary with the stick uses only a fresh press, not held input or repeated key echoes. Pickup travel never holds an item outside the authoritative ownership model.
3. `try_hold` accepts reusable props and later disposal bag refs. Enforce two hand units, a large prop costing two. First pickup of a reusable prop also records its discovery for scanner filtering. Preserve pickup ordering separately from selected-hand placement. Stow tool/bag visually while holding anything; never move their owned records out of the player's equipment.
4. Add selected-held-item cycling for placement. RMB ignores selection and throws the latest currently held object; otherwise it throws the last bag ID. If both are empty, change nothing. A blocked spawn capsule/ray rejects the throw rather than teleporting it through a wall.
5. Spawn the view at a collision-clear position and apply an impulse along camera forward. Preserve the object's ID/properties. Re-pickup and throws may repeat indefinitely without money/progress changes.
6. Reject tool switching while hands are occupied with a clear place/throw prompt; no invisible storage of furniture. Keep a method for P18 to release all carried refs in one faint transaction.

**Acceptance:** `carry_lifo` covers A/B/C order, a full bag, optional valuable capacity, two small objects, a large object's two-hand requirement, held-selection versus throw order and input while a pickup tween is running. Cancelling presentation leaves exactly one owner.

**Handoff:** animated view lifecycle, selected/ordered hand fields, full-bag feedback and shared release-all method. Counts remain unchanged for bag pickup until collection.
