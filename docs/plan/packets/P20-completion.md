# P20 — Progress, restoration and finishing the run

Dependencies: P10, P11, P14, P17, P19. Requirements: R16, R22–R25. Read: progress invariants and R23/D20 carefully.

**Outcome:** trustworthy progress, permanent habitat improvements and a finish receipt that cannot be farmed.

**Own files:** `scripts/core/progress_service.gd`, `scripts/world/restoration_section.gd`, `data/world/restoration_recipes.tres`, result data in RunState, `completion` checks.

**Steps**

1. Compute waste completion only from required COLLECTED IDs; compute prop completion from required clean SLOTTED IDs. Combined total stays 5,700. Exclude valuables, disposal bags, tools, wildlife and furniture patch count.
2. Build home-section objective lookup once from the manifest. Finalize affected sections and logical home-family groups synchronously inside the initiating RunSession commit, before its revision increment, public signals or save request; do not run reward mutations from an `items_changed` listener. Credit props wherever their compatible physical destination is.
3. Queue group-completed notifications on false→true transitions for publication after finalization. Award its configured money only if `reward_claimed` is false and set the flag atomically with payment. Removal makes current group incomplete but does not clear the reward flag.
4. A section is eligible when all its waste is truck-collected and all props clean/slotted; its rescue attachments also require rescue release. Latch `restored_once` and dispatch the recipe. Zone-level larger rewards wait for all sections. Decorative restoration does not erase new objectives or add IDs.
5. If a prop later moves, update current progress but preserve restored flags and wildlife. Replays of restoration signals after load must merely set the final visual state.
6. At first global all-done condition, store immutable receipt with active-play seconds, seed/version/hash, counts, sorting accuracy, money/upgrade summary and optional statistics. Pause gameplay for results; Continue resumes roaming with the finish receipt intact.

**Acceptance:** `completion` proves pickup/table/container do not count trash, truck does, and a dirty chair counts once only after cleaning+placement. Test cross-section mixed collection, repeated group completion, prop removal after restoration, finish→roam→save fixture and no second reward/result receipt. Make the final prop placement also finish its group, section and run: capture from the first public signal and verify the snapshot includes group money/flag, restoration and immutable result receipt, with exactly one revision increment.

**Handoff:** exact counters/signals, section recipes, receipt schema and examples for P21/P22. Never recompute restored state solely from current completeness on load.
