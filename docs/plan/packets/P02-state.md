# P02 — Definitions, item ownership and run state

Dependencies: P00. Requirements: R06–R28, R30. Read: [contracts](../02-architecture.md), especially states, entry points and invariants.

**Outcome:** one authoritative in-memory model shared by every gameplay feature, without networking or disk persistence yet.

**Own files:** `scripts/data/{item_definition,tool_definition,upgrade_definition,beach_definition}.gd`, `scripts/core/{run_state,item_record,run_session,item_store,action_result}.gd`, minimal fixtures in `tests/run_checks.gd`.

**Steps**

1. Implement the documented fields/enums as typed Resources or RefCounted records as appropriate. Use stable string IDs and typed arrays/dictionaries supported by 4.6. Definitions stay immutable; scene instances never mutate the shared `.tres`.
2. Build RunSession around one RunState and a player record keyed `local`. Add revision tracking and explicit signals; expose references to the services through exports/constructor setup.
3. Implement a small validated transfer helper inside ItemStore used by concrete methods, not a universal command framework. A transaction validates owner, source state, destination capacity and definition first, then applies all updates synchronously. Establish RunSession's finalization boundary: source changes, derived progress/rewards when P20 exists, one revision increment, then public signals/save requests. Defer signal-triggered follow-up actions until publication ends.
4. Add invariant validation for unique ownership, synchronized lists, nonnegative wallet, valid references, correct hand costs and unchanged required denominator. Return explicit reasons for capacity, wrong state, missing ID, blocked target and invalid category.
5. Define plain-data snapshot conversion hooks with string enum names and finite numeric values. Implement only representation/round-trip in memory here; disk generations, migrations and save UI belong to P24.
6. Create a tiny fixture with mixed waste, two small props, one large dirty chair, optional valuable and an attached item. No art is needed for these checks.

**Acceptance:** `ownership` rejects collecting the same ID twice; rejects invalid source and destination without partial mutation; preserves independence between two RunStates using the same definitions; snapshot data retains stable IDs and order. A signal listener sees a finalized revision, and its follow-up action cannot run inside the publishing commit. Direct scene deletion must not alter counts.

**Do not add:** network RPCs, interfaces for hypothetical storage backends, a database, encryption or event sourcing.

**Handoff:** exact class names/public method signatures, invariant checker usage, snapshot representation and fixture output. Later packets must extend these types rather than fork them.
