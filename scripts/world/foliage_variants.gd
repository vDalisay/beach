class_name FoliageVariants
extends RefCounted
## Deterministic palm variety for scenery placements. Presentation only: palms carry no
## collision, objectives or saved state, so swapping a variant never affects gameplay.

const PALMS: Array[PackedScene] = [
	preload("res://art/synty/wrappers/foliage_palm_03.tscn"),
	preload("res://art/synty/wrappers/foliage_palm.tscn"),
	preload("res://art/synty/wrappers/foliage_palm_05.tscn"),
	preload("res://art/synty/wrappers/foliage_palm_03.tscn"),
	preload("res://art/synty/wrappers/foliage_palm_02.tscn"),
	preload("res://art/synty/wrappers/foliage_palm_04.tscn"),
]
# Keeps each variant near the fan palm's height at the same placement scale.
const HEIGHT_SCALES: Array[float] = [0.84, 1.0, 0.8, 0.9, 0.9, 0.92]
const UNDERSTOREY: Array[PackedScene] = [
	preload("res://art/synty/wrappers/foliage_palm_small_01.tscn"),
	preload("res://art/synty/wrappers/foliage_bush_01.tscn"),
	preload("res://art/synty/wrappers/foliage_palm_small_03.tscn"),
	preload("res://art/synty/wrappers/foliage_bush_02.tscn"),
]


static func palm(index: int) -> PackedScene:
	return PALMS[posmod(index, PALMS.size())]


static func palm_scale(index: int) -> float:
	return HEIGHT_SCALES[posmod(index, HEIGHT_SCALES.size())]


static func instance_palm(index: int, size := 1.0) -> Node3D:
	var node := palm(index).instantiate() as Node3D
	node.scale = Vector3.ONE * size * palm_scale(index)
	return node


static func understorey(index: int) -> PackedScene:
	return UNDERSTOREY[posmod(index, UNDERSTOREY.size())]
