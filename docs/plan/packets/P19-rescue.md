# P19 — Safe animal rescues

Dependencies: P06, P09, P15, P18. Requirements: R21, R22. Read: attachment accounting and asset gaps.

**Outcome:** knife removal frees animals while keeping attached litter in the cleanup loop.

**Own files:** `scenes/wildlife/rescue_site.tscn`, `scripts/wildlife/rescue_site.gd`, `scripts/tools/rescue_knife.gd`, attachment definitions, `rescue` checks. Use cubes if animal/net models remain unavailable.

**Steps**

1. Instantiate 12 authored/seed-selected rescue sites with two required attachment IDs each, using the manifest's stable site/attachment choices. Animals themselves do not add objectives.
2. Position attachments visibly around animal anchors; avoid gore or injury depiction. Knife primary validates attachment, proximity, visibility and ownership, then detaches precisely that waste ID. No hit/damage/combat component exists.
3. Transfer removed litter into the bag if space exists; otherwise drop it nearby with visible feedback. Full bag cannot make a cut fail or erase the waste. Preserve home section and discovery semantics when the item is later collected.
4. After final attachment removal, latch rescue success and release the animal onto an authored local route. Returning to the site, reloading or re-picking the removed litter must not re-entangle it.
5. The home section still requires truck collection of all attachment IDs before restoration. Individual freedom occurs immediately; regional fish/coral reward is separate.
6. Missing knife animal art must not remove the interaction: use the registered placeholders and keep the same stable site/attachment IDs for replacement later.

**Acceptance:** `rescue` tests first/final cut, non-knife attempt, occluded/out-of-range attempt, full bag drop, repeated click and one-time animal release. Swim to each rescue location with available oxygen upgrades; no rescue is inside inaccessible rock or under the world.

**Handoff:** site/attachment IDs, animal route trigger, art needed and evidence that 24 attachments are already in the waste total rather than added at runtime.
