class_name Coastline
extends RefCounted


static func shore_z(x: float) -> float:
	var playable_x := clampf(x, -80.0, 80.0) * 4.0
	var cove := (playable_x - 70.0) / 120.0
	var flank := maxf(absf(x) - 80.0, 0.0)
	return maxf(0.0, 30.0 + 0.00027 * playable_x * playable_x + 6.0 * exp(-cove * cove) - flank * flank * 0.0014)


static func inland_z(x: float) -> float:
	var flank := maxf(absf(x) - 80.0, 0.0)
	var taper_width := maxf(6.0, 18.0 - maxf(absf(x) - 180.0, 0.0) * 0.03)
	return minf(-36.0 + flank * 0.9, shore_z(x) - taper_width)


static func shore_slope(x: float) -> float:
	return (shore_z(x + 0.25) - shore_z(x - 0.25)) / 0.5


## Height of the flat dry sand before relief.
const DRY_SAND := 0.012


static func surface_y(x: float, z: float) -> float:
	# The five-row sand/collision cross-section, with natural relief on the dry beach.
	var distance := z - shore_z(x)
	if distance <= -2.0:
		return DRY_SAND + BeachRelief.height(x, z)
	if distance <= 28.0:
		return lerpf(0.012, -2.5, (distance + 2.0) / 30.0)
	if distance <= 55.0:
		return lerpf(-2.5, -3.2, (distance - 28.0) / 27.0)
	return -3.2
