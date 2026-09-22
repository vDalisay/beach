# P23 — Discovery-based scanner

Dependencies: P06, P08, P15, P22. Requirements: R28, R29. Read: D22 and discovery rules.

**Outcome:** a purchased scanner helps locate known item types/materials without revealing hidden buried finds prematurely.

**Own files:** `scripts/tools/scanner.gd`, `scenes/ui/scanner_marker.tscn`, scanner/booklet filter controls, `discovery_scan` checks.

**Steps**

1. Unlock a definition filter on first successful collection and its associated material-tag filters (e.g. plastic). Family tags such as bottle may include plastic and glass variants; show that distinction clearly. Knife removal into a full bag only unlocks when subsequently collected.
2. Keep scanner as a booklet skill with a selected filter and F/right-stick pulse. It consumes no handheld slot and no battery. Prevent UI repeat spam from building unlimited marker nodes.
3. Query authoritative records, excluding completed waste/valuables (COLLECTED/SOLD), completed props (clean SLOTTED), still-hidden BURIED records and items already in the player's bag/hands. Removing a sorted prop makes it eligible again once dropped. For TABLE/BIN/SEALED/VALUABLE_TRAY items, guide to the owning station/bag/container with the remaining action instead of drawing hundreds of overlapping item markers; a held bag uses a carry/deposit hint, not a marker at the player's feet.
4. Show nearby world matches and a direction/count for distant matches globally. Unlike ordinary hover, scanner markers may deliberately indicate occluded known litter, with a distinct icon to avoid implying direct interaction range. They do not allow pickup through walls.
5. Keep unknown-type discovery possible through level authoring and section task status; scanner cannot be the only means of finding a type that has never been collected. Buried targets remain detector work until revealed.
6. Preserve filter/discoveries with run records for P24; new runs reset discoveries. Reuse existing target label/prompt styles.

**Acceptance:** `discovery_scan` tests newly unlocked material group, unknown definition refusal, hidden/revealed buried state, item carried to another zone, sorted-but-uncollected owner markers and zero remaining matches. A clean slotted prop produces no remaining marker; pick it up and drop it to restore its marker without clearing restoration. Last-known-item search works without out-of-bounds/offscreen confusion.

**Handoff:** filter definitions, scan query ordering, marker cap/refresh behavior, screenshots and exact saved fields.
