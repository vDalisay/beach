# P27 — Interaction polish and accessibility pass

Dependencies: P08, P10, P12, P21, P22, P24, P26. Requirements: R05, R09, R23, R29.

**Outcome:** the full game's interactions feel responsive and consistent across input devices and display sizes.

**Own files:** targeted changes to existing interaction/hand/UI/shader scripts, shared effect timing resources only where already justified, accessibility settings. Avoid another feedback manager duplicating existing presentation owners.

**Steps**

1. Tune poke response, pickup arc, hand positioning, throw impulse, valid slot ghost, placement travel and 1→1.08→1 pulse. Apply scale only to visual roots, never collision shapes or saved transforms.
2. Add a clear shader sweep on completed logical groups/shelf rows. Repeat animation on re-completion while P20 retains one-time reward. Ensure unrelated instances sharing a material do not flash.
3. Coordinate group/restoration/receipt notifications so the screen remains readable; batch rapid count feedback. No sound work. Nature-return events should be visible from sensible nearby viewpoints without forcing camera movement.
4. Complete controller-only launch-to-results workflows, including correction of an item inside a bin, manual sealing, selecting either held prop, changing scanner filter and recovering a fainted pile. Fix focus loss, double input and mixed mouse/controller transitions at their shared source.
5. Verify remapped prompts, disconnect/reconnect, sensitivity, FOV, invert Y, UI scale, sprint/crouch toggles and reduced motion. Reduced motion removes big pulses/sweeps but preserves placement travel or clear positional feedback.
6. Check bright sand, water, hut shadows, thin/transparent targets and multiple moving objects. Highlight may not reveal through walls except explicitly marked scanner hints. Names must remain legible beside the object.

**Acceptance:** capture a short silent gameplay sequence showing pickup, throw, correct snap, group sweep and restoration. Complete documented controller and resolution checklist. Re-run targeted ownership/slot/table tests after any changes to input or effect sequencing.

**Handoff:** final feel values, supported settings, tested devices/resolutions and concrete outstanding issues. Do not call feedback finished merely because a tween exists.
