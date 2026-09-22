# P22 — HUD, booklet, menus and player guidance

Dependencies: P03, P15, P18, P20. Requirements: R24, R25, R27, R29. Read: locked HUD order and input contexts.

**Outcome:** complete, readable interfaces for the full game, with all actions reachable by controller.

**Own files:** `scenes/ui/{hud,booklet,main_menu,pause_menu,results}.tscn`, matching `scripts/ui/*.gd`, shared Theme resource. Reuse P03 settings and P15 purchase controls rather than duplicating them.

**Steps**

1. Top-left layout: `Completed 0 / 5,700` with remaining count, then `Props 0 / 300`, `Trash collected 0 / 5,400`, then money. This wording makes truck-based waste credit explicit. Bag `used/capacity` and pickup feedback live separately.
2. Show oxygen while swimming/submerged, current tool/loadout, selected held object and context prompts. Target names stay next to the object. Notifications never cover the crosshair or sorting targets.
3. Booklet includes skills, discoveries/scanner filter space, section task status and basic controls. Show stage-specific tasks such as “3 items awaiting collection” rather than falsely suggesting litter remains on the sand. Physical equipment purchases direct the player to the shop.
4. Build new run with seed entry, continue/load slots, settings, pause/save/save-and-quit and results/continue-roaming. P24 supplies real save operations later; until then do not show a fake successful save message.
5. Add brief context guidance for first pickup, full bag, sorting correction, sealing/carrying, calling collection, buying cloth, oxygen and first rescue. Save acknowledged guidance per run. No long tutorial level or separate demo.
6. Use Containers/anchors, visible focus boundaries, labels/icons alongside colours and current action bindings. Focus returns to the originating button when a modal closes. Use native Controls and Theme; no UI framework.

**Acceptance:** controller-only navigation of every screen; clear totals during each loop stage; 720p/1080p/4K and UI scale checks. First results screen reports the immutable finish receipt and does not prevent roaming afterward. UI strings never expose internal service/resource names.

**Handoff:** screen/control paths, focus map, screenshots, unfinished backend hookups explicitly assigned to P23/P24.
