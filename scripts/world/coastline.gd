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
