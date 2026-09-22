# P06 — Seeded starting manifest

Dependencies: P02, P05. Requirements: R02, R26. Read: [determinism contract](../02-architecture.md), [quotas](../04-content-and-balance.md).

**Outcome:** a reproducible full 5,700-object run definition, including dirt, buried finds and rescues, independent of scene spawn order.

**Own files:** `scripts/world/{manifest_generator,manifest_validator}.gd`, `data/world/spawn_anchors.tres`, generation cases in `tests/run_checks.gd`.

**Steps**

1. Implement bounded seed normalization and SHA-256-derived streams exactly as specified. Sort definition and anchor IDs explicitly. Put generator/content version into the manifest and digest.
2. Allocate per-zone, per-section and per-category quotas before placing items. Select anchor poses from valid family pools; give each record an immutable home section and stable ordinal ID.
3. Assign subsets: 300 buried ordinary waste, 24 rescue attachments, 120 standalone residue, 60 dirty props and 40 optional valuables. Make these explicit subsets of existing quotas except valuables. Ensure starter section requires no locked tool.
4. Create stable layer patterns for piles and choose them using the pile stream. Starting transforms use authored supported poses; do not run physics to decide manifest output. Generation must fail visibly with a useful anchor/capacity error rather than emit fewer required items.
5. Validate destination capacity, tool access, valid water depths and object clearances against authored metadata. Use offline geometry checks to establish valid anchors; final runtime generation does not rely on nondeterministic physics settling.
6. Store canonical manifest/hash and instantiate records, not meshes, through RunSession. P07 handles views. Keep cosmetic wildlife randomness separate.

**Acceptance:** `manifest` compares separate-process canonical outputs for the same seed, and different seeds preserve all quotas while changing valid poses. `manifest_constraints` tests missing anchors, impossible shelves, duplicate IDs and a seed with Unicode. Run at least ten fixed seeds now; P29 expands to 100.

**Handoff:** golden manifest/hash for a named fixture version, stream derivation, exact quota matrix and diagnostics. Never advertise deterministic physics or cross-version layouts.
