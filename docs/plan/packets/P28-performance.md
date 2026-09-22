# P28 — Full-scale performance and memory

Dependencies: P07, P21, P24, P25, P26, P27. Requirements: R01. Read: performance matrix in [verification](../05-verification.md).

**Outcome:** measured performance on the requested hardware class, with only evidence-driven optimizations.

**Own files:** targeted runtime/world/rendering changes and `docs/performance.md`; an optional `scripts/items/resting_item_batches.gd` only if profiling requires it.

**Steps**

1. Compare P07 baseline to exported full content at default 1080p on the target GPU/RAM class. Record CPU/driver, frame-time distribution, resident/GPU memory, awake bodies, visible draws, shader/physics cost and save spikes. If hardware is unavailable, label that test unverified.
2. Fix measured easy costs first: accidental per-frame idle processing, duplicate material instances, overly long shadows, unbounded markers, source assets loaded unnecessarily, excess alpha layers and too many visible distant props.
3. If item draws/physics still dominate, batch distant resting small litter per spatial cell/mesh/material. Keep logical records independent. Promote cells within an interaction/physics safety radius back to ordinary objects, preserving IDs/transforms and avoiding double-rendering. Active/thrown/held/highlighted objects never remain in resting batches.
4. Ensure fast throws can activate destination cells before collision/capture. Demote only after sleep and outside nearby-interaction radius. If this complexity is not justified by profiling, retain native sleeping bodies.
5. Bound fish/particle/notification counts and retain culling by cell/section. Save snapshot construction must not stall frequently; if optimization is needed, copy a consistent plain-data snapshot on the main thread before any asynchronous file work.
6. Repeat stress routes listed in verification and extended throw/pickup/save/reload cycles. Check memory returns after switching runs and completed item views are freed.

**Acceptance:** measured target budget or explicit unresolved shortfall, plus passing ownership/capture/manifest/save cases after optimization. Renderer changes require revisiting water/stain/outline visual evidence, not only fps comparisons.

**Handoff:** before/after measurements, exact settings, changed constraints and any remaining hardware verification gap. Do not lower required item count to meet the budget.
