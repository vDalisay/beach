class_name BeachRelief
extends RefCounted
## Natural shape of the dry beach: dunes along the promenade, scattered mounds and a berm above the
## waterline, flattened under the places gameplay needs level (service points, the shop, the pier
## approach, lookouts, shades, the court, the spawn and the recovery anchors).
##
## `height(x, z)` is metres to add to the flat dry sand. `Coastline.surface_y` adds it, so the sand
## mesh, its collision, the manifest generator and everything that asks for the ground agree. It
## uses only integer hashing and polynomials, so the same point gives the same height on every
## machine; generated item heights depend on it. The level footprints come from
## `data/world/beach_layout.tres`, written by `tools/bake_beach_layout.gd` from the beach scene.

const VERSION := "relief-1"
const LAYOUT_PATH := "res://data/world/beach_layout.tres"
## The sand meets the promenade top (0.35 m) just below it.
const PROMENADE_SAND := 0.32
## Relief ends this far from the waterline, so wet sand, water and seabed keep their profile.
const SHORE_FADE := Vector2(-2.0, -4.5)
const BERM_OFFSET := -7.0
const BERM_HALF_WIDTH := 2.6
const BERM_HEIGHT := 0.24
const MOUND_HEIGHT := 0.5
const SWELL := 0.12
## Dune crest distance from the promenade edge and its spread, crest height base, noise and
## outside-boundary gain, the walkable face gradient and its outside gain, and the back length.
const DUNE_SHAPE := [11.0, 4.0, 0.7, 0.9, 0.3, 1.4, 0.19, 0.3, 9.5]
## Steepest mean gradient where a level pad blends back into the relief, and the longest blend.
const PAD_EDGE_GRADIENT := 0.12
const MAX_PAD_BLEND := 10.0
const BUCKET := 8.0

## The layout baker turns relief off while it reads authored scenery; nothing else should.
static var enabled := true
# Each pad: [kind (0 rect, 1 circle), a, b, c, d, falloff, level]. Rect: min x, min z, max x, max z.
# Circle: centre x, centre z, radius, unused.
static var _pads: Array[PackedFloat32Array] = []
static var _buckets: Dictionary = {}
static var _loaded := false


## Metres of relief at (x, z) on the dry beach; 0 in the wet band, the water and behind the sand.
static func height(x: float, z: float) -> float:
	return height_at(column(x), x, z)


## Relief at (x, z) given `column(x)`: loops down one column reuse its terms.
static func height_at(terms: PackedFloat64Array, x: float, z: float) -> float:
	if not enabled:
		return 0.0
	_ensure_loaded()
	var raw := raw_at(terms, x, z)
	if raw == 0.0 and not _has_pads_near(x, z):
		return 0.0
	return maxf(_apply_pads(raw, x, z), -0.04)


## Relief before level pads: what the sand would do without any authored feature on it.
static func raw_height(x: float, z: float) -> float:
	return raw_at(column(x), x, z)


## The terms of the relief that depend only on x: waterline, inland edge, dune crest distance and
## height, dune toe, distance fade and berm strength.
static func column(x: float) -> PackedFloat64Array:
	var ax := absf(x)
	var outer := _smooth(80.0, 112.0, ax)
	# Back dunes: from the promenade up to a crest that wanders along the beach, then down.
	var crest_at: float = DUNE_SHAPE[0] + (_noise_x(x, 23.0, 1) - 0.5) * DUNE_SHAPE[1]
	var crest_height: float = DUNE_SHAPE[2] + _noise_x(x, 17.0, 2) * DUNE_SHAPE[3] + _noise_x(x, 7.0, 3) * DUNE_SHAPE[4] + outer * DUNE_SHAPE[5]
	# Keep the promenade side of the dune walkable (about 16° at its steepest) in the play area.
	crest_height = minf(crest_height, PROMENADE_SAND + (crest_at - 4.0) * (DUNE_SHAPE[6] + outer * DUNE_SHAPE[7]))
	var toe: float = crest_at + DUNE_SHAPE[8] + outer * 6.0
	var far := 1.0 - _smooth(170.0, 200.0, ax)
	var berm_gain := 0.35 + 0.65 * _noise_x(x, 12.0, 7)
	return PackedFloat64Array([Coastline.shore_z(x), Coastline.inland_z(x), crest_at, crest_height, toe, far, berm_gain])


static func raw_at(terms: PackedFloat64Array, x: float, z: float) -> float:
	var d := z - terms[0]
	if d >= SHORE_FADE.x:
		return 0.0
	var from_back := z - terms[1]
	var far := terms[5]
	if from_back < -0.5 or far <= 0.0:
		return 0.0
	var crest_at := terms[2]
	var crest_height := terms[3]
	var toe := terms[4]
	var dunes := 0.0
	if from_back <= 4.0:
		dunes = PROMENADE_SAND
	elif from_back < crest_at:
		dunes = lerpf(PROMENADE_SAND, crest_height, _smooth(4.0, crest_at, from_back))
	else:
		dunes = crest_height * (1.0 - _smooth(crest_at, toe, from_back))
	# The open beach: scattered mounds and a very low swell, below the dunes.
	var open := _smooth(crest_at + 4.0, toe + 2.0, from_back)
	var rest := 0.0
	if open > 0.0:
		var field := _noise(x + 311.0, z, 10.0, 4) * 0.85 + _noise(x, z + 97.0, 5.0, 5) * 0.15
		# Mounds are taller toward the dunes and lower toward the sea.
		var mounds := MOUND_HEIGHT * (1.5 - 0.5 * _smooth(18.0, 40.0, from_back)) * _smooth(0.47, 0.95, field)
		var swell := (_noise(x, z, 21.0, 6) - 0.5) * SWELL
		rest = open * (mounds + swell)
	# The berm: a low ridge above the waterline, broken into lengths along the shore.
	var berm := 0.0
	var across := (d - BERM_OFFSET) / BERM_HALF_WIDTH
	if absf(across) < 1.0:
		var bump := 1.0 - across * across
		berm = BERM_HEIGHT * bump * bump * terms[6]
	var fade := _smooth(SHORE_FADE.x, SHORE_FADE.y, d)
	return (dunes + rest + berm) * fade * far


## Ground normal of the sand from its height, for items lying on slopes.
static func land_normal(x: float, z: float) -> Vector3:
	var step := 0.25
	var dx := Coastline.surface_y(x + step, z) - Coastline.surface_y(x - step, z)
	var dz := Coastline.surface_y(x, z + step) - Coastline.surface_y(x, z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()


## Everything that decides the relief, for the manifest content hash.
static func identity() -> Dictionary:
	_ensure_loaded()
	var pads: Array = []
	for pad in _pads:
		var values: Array = []
		for value in pad:
			values.append(roundi(value * 1000.0))
		pads.append(values)
	return {
		"version": VERSION,
		"constants": [PROMENADE_SAND, SHORE_FADE.x, SHORE_FADE.y, BERM_OFFSET, BERM_HALF_WIDTH, BERM_HEIGHT, MOUND_HEIGHT, SWELL, DUNE_SHAPE, PAD_EDGE_GRADIENT, MAX_PAD_BLEND],
		"pads": pads,
	}


## Reloads the level footprints (after the layout data is re-baked in the same process).
static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_pads.clear()
	_buckets.clear()
	if not ResourceLoader.exists(LAYOUT_PATH):
		return
	var layout := load(LAYOUT_PATH) as Resource
	if layout == null:
		return
	for pad_value in layout.get_meta(&"pads", []) as Array:
		var pad := pad_value as Dictionary
		var values := PackedFloat32Array()
		if str(pad.shape) == "rect":
			values = PackedFloat32Array([0.0, pad.min[0], pad.min[1], pad.max[0], pad.max[1], pad.falloff, 0.0])
		else:
			values = PackedFloat32Array([1.0, pad.center[0], pad.center[1], pad.radius, 0.0, pad.falloff, 0.0])
		_pads.append(values)
	# Terrace pads keep the height of the relief at their centre; the others level to the base sand.
	for index in _pads.size():
		var pad := _pads[index]
		var source := layout.get_meta(&"pads")[index] as Dictionary
		if str(source.get("mode", "zero")) == "terrace":
			var centre := Vector2((pad[1] + pad[3]) * 0.5, (pad[2] + pad[4]) * 0.5) if pad[0] == 0.0 else Vector2(pad[1], pad[2])
			pad[6] = raw_height(centre.x, centre.y)
			_pads[index] = pad
	# A pad blends back over a fixed distance, lengthened where the relief near it stands well above
	# or below its level, so its edge stays about as gentle as a dune face everywhere around it.
	for index in _pads.size():
		var pad := _pads[index]
		var lo := Vector2(pad[1], pad[2]) - Vector2.ONE * (pad[3] if pad[0] == 1.0 else 0.0)
		var hi := Vector2(pad[3], pad[4]) if pad[0] == 0.0 else Vector2(pad[1], pad[2]) + Vector2.ONE * pad[3]
		var highest := 0.0
		var sx := lo.x - MAX_PAD_BLEND
		while sx <= hi.x + MAX_PAD_BLEND:
			var terms := column(sx)
			var sz := lo.y - MAX_PAD_BLEND
			while sz <= hi.y + MAX_PAD_BLEND:
				highest = maxf(highest, absf(raw_at(terms, sx, sz) - pad[6]))
				sz += 2.0
			sx += 2.0
		pad[5] = clampf(highest / PAD_EDGE_GRADIENT, pad[5], MAX_PAD_BLEND)
		_pads[index] = pad
	for index in _pads.size():
		var pad := _pads[index]
		var reach := pad[5] + MAX_PAD_BLEND + (0.0 if pad[0] == 0.0 else pad[3])
		var min_corner := Vector2(pad[1], pad[2]) if pad[0] == 0.0 else Vector2(pad[1], pad[2])
		var max_corner := Vector2(pad[3], pad[4]) if pad[0] == 0.0 else Vector2(pad[1], pad[2])
		for bx in range(floori((min_corner.x - reach) / BUCKET), floori((max_corner.x + reach) / BUCKET) + 1):
			for bz in range(floori((min_corner.y - reach) / BUCKET), floori((max_corner.y + reach) / BUCKET) + 1):
				var key := Vector2i(bx, bz)
				if not _buckets.has(key):
					_buckets[key] = PackedInt32Array()
				var list := _buckets[key] as PackedInt32Array
				list.append(index)
				_buckets[key] = list


static func _has_pads_near(x: float, z: float) -> bool:
	return _buckets.has(Vector2i(floori(x / BUCKET), floori(z / BUCKET)))


static func _apply_pads(raw: float, x: float, z: float) -> float:
	var key := Vector2i(floori(x / BUCKET), floori(z / BUCKET))
	if not _buckets.has(key):
		return raw
	var result := raw
	for index in _buckets[key] as PackedInt32Array:
		var pad := _pads[index]
		var distance := 0.0
		if pad[0] == 0.0:
			var dx := maxf(maxf(pad[1] - x, 0.0), x - pad[3])
			var dz := maxf(maxf(pad[2] - z, 0.0), z - pad[4])
			distance = sqrt(dx * dx + dz * dz)
		else:
			var offset := Vector2(x - pad[1], z - pad[2])
			distance = maxf(offset.length() - pad[3], 0.0)
		# Blend back over the pad's falloff, which _ensure_loaded lengthened where the relief around
		# the pad stands high, so the edge of a level place never gets steeper than a dune face.
		var falloff := pad[5]
		if distance >= falloff:
			continue
		var weight := 1.0 - _smooth(0.0, falloff, distance)
		result = lerpf(result, pad[6], weight)
	return result


## Smoothstep between edge0 and edge1 (edges may be in either order).
static func _smooth(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Value noise in [0, 1] from an integer lattice hash: identical on every platform.
static func _noise(x: float, z: float, scale: float, salt: int) -> float:
	var fx := x / scale
	var fz := z / scale
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	tx = tx * tx * (3.0 - 2.0 * tx)
	tz = tz * tz * (3.0 - 2.0 * tz)
	var a := _hash(ix, iz, salt)
	var b := _hash(ix + 1, iz, salt)
	var c := _hash(ix, iz + 1, salt)
	var d := _hash(ix + 1, iz + 1, salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func _hash(ix: int, iz: int, salt: int) -> float:
	var h := (ix * 374761393 + iz * 668265263 + salt * 1442695041) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


## Value noise in [0, 1] (same lattice hash as the relief), for other layout data that should
## follow the same shapes, such as gaps in the tideline.
static func noise(x: float, z: float, scale: float, salt: int) -> float:
	return _noise(x, z, scale, salt)


## Distance from the inland sand edge at which the back dunes meet the open beach.
static func dune_toe(x: float) -> float:
	var outer := _smooth(80.0, 112.0, absf(x))
	var crest_at: float = DUNE_SHAPE[0] + (_noise_x(x, 23.0, 1) - 0.5) * DUNE_SHAPE[1]
	return crest_at + DUNE_SHAPE[8] + outer * 6.0


## `_noise(x, 0, scale, salt)` with only the lattice row it reads: same values, half the hashing.
static func _noise_x(x: float, scale: float, salt: int) -> float:
	var fx := x / scale
	var ix := floori(fx)
	var tx := fx - float(ix)
	tx = tx * tx * (3.0 - 2.0 * tx)
	return lerpf(_hash(ix, 0, salt), _hash(ix + 1, 0, salt), tx)


## Ground normal from forward differences around a point whose height `here` is already known:
## two height lookups instead of four, for placing thousands of resting items.
static func normal_from(x: float, z: float, here: float) -> Vector3:
	var step := 0.3
	var dx := Coastline.surface_y(x + step, z) - here
	var dz := Coastline.surface_y(x, z + step) - here
	return Vector3(-dx, step, -dz).normalized()
