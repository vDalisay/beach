# P13 — Sealed disposal bags and large containers

Dependencies: P07, P09, P12. Requirements: R15. Read: bag record/location contract.

**Outcome:** category contents become physical, transportable bags with exact retained item identities.

**Own files:** `scenes/items/disposal_bag.tscn`, `scripts/items/disposal_bag.gd`, `scenes/stations/waste_container.tscn`, `scripts/stations/waste_container.gd`; extend SortingStation, Carry and RunState; `sealing` checks.

**Steps**

1. Give each category bin capacity 50 and output rack eight slots. On threshold, try to seal into a rack slot. If none is available, preserve the full bin and block more deposits until an output position becomes free.
2. Manual Seal button/E-context action works for any nonempty bin. Create monotonic run-local bag ID and move each contained waste record to SEALED in one transaction. Record declared category and correctness from original definitions; no rounding or mystery bonus.
3. Render an output bag with category label/icon/colour and correct versus total count. Bags cost one hand unit; preserve their contents while carried, thrown or left on the ground. They are not new required cleanup items.
4. Implement matching container deposit by interaction and physical throw capture. A container accepts the bag's declared category even if some internal items were wrong. Wrong-category container rejects it without changing its location/contents.
5. Containers retain bag IDs with unlimited logical capacity and a bounded visual fill representation. Permit picking a deposited bag back up before collection. No thousands of mesh bags inside a container.
6. Keep SEALED item records independent of bag view lifecycle. Bag contents cannot be reopened/corrected after sealing. Show that rule before manual sealing so a player understands the consequence.

**Acceptance:** `sealing` checks 50-item auto seal, 1-item manual seal, empty refusal, full rack, two held bags, mismatched/matching physical catch and re-pickup. All source items still exist once and only once. No payment occurs here.

**Handoff:** rack/bin/container state and bag view lifecycle, sealing interaction, full-output feedback, and test receipt sample for P14/P24.
