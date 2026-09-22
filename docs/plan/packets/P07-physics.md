# P07 — Physical items, piles and safe recovery

Dependencies: P01, P02, P06. Requirements: R08, R09, R20. Read: [physics contract](../02-architecture.md).

**Outcome:** manifest items appear as physical, recoverable objects while their identity stays in RunState.

**Own files:** `scenes/items/world_item.tscn`, `scripts/items/{world_item,item_view_manager}.gd`, `scripts/world/recovery_bounds.gd`, `tests/scenes/physics_lab.tscn`.

**Steps**

1. Create reusable RigidBody3D wrappers with shared mesh/material resources and simple definition-driven collision profiles. Keep a separate visual root for pulses. Initially place bodies at manifest poses, zero velocities and put supported piles to sleep.
2. Configure documented layers/masks. Tiny litter does not become a stair under the player; large furniture remains solid. Use convex/primitive shapes for moving bodies; collision-only imported meshes must not render.
3. Expose activate/freeze/sleep/restore methods for pickup, placement, throws and saves. ItemViewManager synchronizes WORLD transforms, velocities and sleep state at a physics boundary before snapshots/view demotion, and retains resting poses when bodies sleep. Apply the same path to P13 disposal bags. Use impulses for thrown active objects and enable continuous collision detection for small fast objects where testing shows tunnelling.
4. Maintain item-ID-to-view mapping. View deletion/visibility never changes objective state. Disable idle scripts rather than polling thousands of objects each frame. Do not instantiate meshes for BAG/BIN/SEALED terminal contents unless a station needs a presentation proxy.
5. Add bounds/fall recovery using authored anchors. Preserve item ID, dirt, discovery and home section; do not pay or mark complete. Avoid returning an object into another object's collision volume.
6. Measure the full 5,700-item layout and largest pile immediately. Record frame/physics/draw/memory observations; flag required P28 batching if native sleeping bodies/shared resources are insufficient.

**Acceptance:** physics lab throws can, ball and chair, collides two items, wakes/sleeps a pile and recovers an out-of-bounds object. `physics_recovery` asserts stable ID/count/money. Capture an in-memory snapshot after a throw has advanced and after it comes to rest; restoring it uses the captured pose/velocity, not the launch pose. Starting pile does not explosively separate or bury inaccessible required items.

**Handoff:** collision profiles, earliest full-scale measurements, body/view lifecycle and known rendering costs. No physics determinism claim.
