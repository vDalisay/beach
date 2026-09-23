class_name Coastline
extends RefCounted


static func shore_z(x: float) -> float:
	x *= 4.0
	var cove := (x - 70.0) / 120.0
	return 30.0 + 0.00027 * x * x + 6.0 * exp(-cove * cove)
