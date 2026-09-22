# P17 — Detector, buried waste and valuables

Dependencies: P06, P09, P15. Requirements: R18, R26. Read: optional-find accounting and detector defaults.

**Outcome:** deterministic buried objects reward exploration without becoming an economic or completion trap.

**Own files:** `scripts/tools/metal_detector.gd`, `scripts/items/buried_find.gd`, valuable definitions, valuables tray/sale methods in SortingStation, `buried` checks.

**Steps**

1. Render buried records as hidden but logically present at their predetermined anchors. Do not roll the item type/value when the player detects or reloads it.
2. Give each buried anchor a reachable dig-surface point and collision-clear reveal pose. Detector provides distance/pulse intensity to nearest eligible target within 4 m. LMB within 1.5 m of the visible surface point reveals that same item ID with a brief sand-lift animation; do not raycast to the hidden mesh and reject the covering sand itself. Intervening rocks/walls still block digging. No extra shovel purchase. Scanner must not locate hidden finds before this revelation.
3. Ordinary revealed waste follows the normal bag→table→category→sealed→collection route and remains part of 5,400. Optional valuables use bag capacity but not waste sorting categories or the required denominator.
4. Unloaded valuables appear identified on the labelled tray; expose Sell at station by focusable button/E context. One atomic sale marks SOLD and credits authored fixed value. Do not permit valuable disposal into waste bins or pay again after view/receipt repetition.
5. Update discovery on successful collection and record optional finds/sales for results. Throwing a valuable before selling returns it to the world with the same ID/value. World-bound recovery preserves it.
6. Verify required buried waste is reachable with affordable equipment and within the authored beach domain. Optional valuable locations cannot be the only way to fund a required tool.

**Acceptance:** `buried` proves same-seed location/type/value stability, hidden targeting refusal, one reveal, one sale and invariant 5,700 denominator. A find below solid sand reveals from its valid surface point; a wall between player and that point rejects it unchanged. Save round-trip fixture data includes a hidden find, revealed find, bagged valuable and sold valuable for P24.

**Handoff:** detector feedback/controls, reveal rules, tray/sale schema and catalogue of both waste and valuable definitions. No random rewards on click.
