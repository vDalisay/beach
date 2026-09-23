class_name Coastline
extends RefCounted


static func shore_z(x: float) -> float:
	var playable_x := clampf(x, -80.0, 80.0) * 4.0
	var cove := (playable_x - 70.0) / 120.0
	return 30.0 + 0.00027 * playable_x * playable_x + 6.0 * exp(-cove * cove) + maxf(absf(x) - 80.0, 0.0) * 0.22
