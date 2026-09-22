# P24 — Persistent runs, autosave and recovery

Dependencies: P02, P06, P12, P14, P17, P18, P20, P22, P23. Requirements: R27, R30. Read: full save contract; all state owners' handoffs.

**Outcome:** every supported gameplay state survives save/load, with separate runs and recoverable failed writes.

**Own files:** `scripts/core/save_service.gd`, save slot UI backend, schema/migration helpers only as needed; `save_roundtrip` and `save_recovery` checks.

**Steps**

1. Serialize the entire logical run snapshot, including initial manifest, all item states/transforms/velocities/sleep states, ordered bags/hands, disposal-bag contents and WORLD poses, recovery-pile membership, table cells/bins, shelf claims, partial dirt, rescues, discoveries, equipment, purchases, wallet, group receipts, restored flags, player pose/velocity, air and completion receipt.
2. Validate IDs/allowed definitions, unique ownership, bounded counts/string lengths, finite transforms and known enum/schema values before allocating views. Never instantiate arbitrary save-supplied scripts/resources. Reject incompatible content with explanation; missing art uses registered placeholders, missing required definitions cannot silently disappear.
3. Implement alternating A/B generations with sequence/checksum and temporary-file write/flush/validation. Maintain the previous valid generation until new content is usable. Corrupt latest falls back with a notice; both invalid show a recoverable error and leave the files and live run untouched. Validate a candidate snapshot before replacing the active RunRoot. Start with synchronous writes; any later background optimization must serialize writes to each slot so overlapping requests cannot publish an older snapshot last.
4. Implement independent autosave/manual slots beneath validated beach/run IDs. Keep UI display names separate from paths. Enumerate only save root. New run with same seed gets a distinct run ID and fresh money/upgrades.
5. Snapshot only after RunSession finalization and a consistent P07 physics capture for WORLD items/bags and the player, including paused saves. Cancel a transient table drag to its source logical cell; finish view-only tweens at their committed destination on load. Save the player's world pose rather than the overhead camera. Load in world view with station contents intact and transient UI closed. Rebuild physical bodies frozen, apply recorded state, then resume simulation after owners/views are ready. Pause/faint transitions cannot leave duplicate hand ownership.
6. Autosave on interval and important transactions, coalescing simultaneous requests. Save-and-quit waits until its own snapshot sequence is persisted, even if an earlier save has the same run revision; failed writes provide retry/quit-without-saving choices and never claim success. On load construct state, validate it, then create views/UI/restoration appearance before accepting input.

**Acceptance:** round-trip a fixture containing every state, then compare normalized snapshots exactly before physics resumes. Save mid-flight and after settling for a loose item and sealed bag; both restore their captured poses/velocities, not launch poses. Truncate latest generation, corrupt both, simulate write failure, load while table sorting, load after faint and reload after collection/result receipt. Check recovery markers survive loading and retire as contents are recovered. Save, walk without an item transaction, then save-and-quit: the later pose/time must persist even though the run revision is unchanged. If background writes are added, repeat with overlapping requests. A failed load preserves the live run. Demonstrate two same-seed runs remain isolated. No test writes into player save slots.

**Handoff:** schema version, file layout, migration policy, test outputs and failure UI screenshots. Do not treat locally editable saves as anti-cheat.
