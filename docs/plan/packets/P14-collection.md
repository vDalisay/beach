# P14 — Collection call and exact payouts

Dependencies: P02, P13. Requirements: R14–R16, R24. Read: payment formula and mutation invariants.

**Outcome:** an explicit station call permanently removes deposited waste, pays once and credits original sections.

**Own files:** `scripts/stations/collection_service.gd`, `scenes/ui/collection_receipt.tscn`, `scripts/ui/collection_receipt.gd`; extend RunState receipt data; `payment` checks.

**Steps**

1. Add a clearly labelled collection call point at each service station. E can call with any deposited bag amount; empty call displays Nothing to collect and changes nothing. Bags on ground/rack/in hands do not qualify.
2. Build a stable list of eligible bag IDs across all station containers. Validate every bag/content owner and category. Payment uses authoritative definition category and sealed final category, never a UI-supplied total.
3. In one synchronous collection commit, assign receipt ID, move all eligible waste to COLLECTED, mark bags consumed, remove their container ownership and credit `N + C` dollars. Reentrant/repeat calls have no eligible bag to pay twice.
4. Play a brief collection/removal event and display item count, correct count, base pay, bonus and total. The logical pickup/completion transaction is the collection moment; the receipt animation is presentation and can be skipped without changing results. No visible truck/worker AI is required.
5. Pass affected IDs/home sections through RunSession's finalization boundary; P20 updates totals/restoration and the first-finish receipt there before wallet/item signals are published. Request save only after this entire commit; P24 later makes it persistent. A snapshot requested by the first public signal already contains all consequences of collection.
6. Keep all errors non-destructive. If validation finds corruption, refuse the entire batch and report a developer diagnostic; do not partly consume bags.

**Acceptance:** `payment` proves 50 mixed items with 30 correct pays $80 and completes exactly 50; a second call pays zero. Mix items from several sections and confirm their provenance survives. Wrong sorting still completes all delivered items.

**Handoff:** receipt format, collection boundary, save signal and representative expected/actual calculations. Never decrement HUD trash on earlier pickup or sorting events.
