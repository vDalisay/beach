class_name BeachGround
extends RefCounted
## The surface a resting item lies on: the sand or seabed (`Coastline.surface_y`), the visible pier
## planks, or the water plane for floating items. The manifest generator authors every item's height
## from this, and the pier numbers match `pier_visuals.gd` (plank modules at 1.25 m with a
## 0.1875 m thick top, the approach ramp rising 5 % from z 13 m).

const WATER_Y := 0.08
const PLANK_TOP := 1.4375
const PLANK_THICKNESS := 0.1875
## Deck, head and approach footprints in metres: min x, min z, max x, max z.
const DECK := [57.5, 37.0, 67.5, 67.0]
const HEAD := [53.5, 67.0, 71.5, 89.5]
const APPROACH := [57.5, 13.0, 67.5, 37.0]
## Items on the deck keep clear of the railings.
const DECK_INNER := [58.4, 66.6]


## Height of the pier's walking surface at (x, z), or NAN when the point is not on the pier.
static func pier_top(x: float, z: float) -> float:
	if _inside(DECK, x, z) or _inside(HEAD, x, z):
		return PLANK_TOP
	if _inside(APPROACH, x, z):
		return -0.08 + 0.05 * (z - 13.0) + PLANK_THICKNESS
	return NAN


static func _inside(rect: Array, x: float, z: float) -> bool:
	return x >= float(rect[0]) and x <= float(rect[2]) and z >= float(rect[1]) and z <= float(rect[3])
