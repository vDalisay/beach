extends RefCounted
## Backdrop city behind the beachfront row: a street grid of low-poly buildings generated at
## runtime (one MultiMesh per building class), paved and lawn block slabs, and tree positions
## for the backdrop's foliage batches. Scenery only: no collision, items or gameplay.

const BLOCK_SHADER := preload("res://shaders/city_block.gdshader")
const COLUMNS := [-114.0, -76.0, -38.0, 0.0, 38.0, 76.0, 114.0]
const ROWS := [-122.0, -156.0, -190.0, -224.0]
const BLOCK := Vector2(30.0, 26.0)
const STREET := 8.0
const FLOOR := 3.0
const SLAB := 0.15
# The beachfront landmark tower (city_backdrop.gd) keeps its block as a plaza.
const LANDMARK := Vector2(-46.0, -115.0)
const DOWNTOWN := Vector2(-40.0, -160.0)
# [width, depth, floors, style]; styles: 0 shops, 1 apartments, 2 glass tower, 3 stepped hotel,
# 4 house with a tiled gable roof (coastal villas, placed by city_backdrop.gd).
const CLASSES := [
	[12.0, 10.0, 3, 0], [13.0, 10.0, 5, 1], [12.0, 11.0, 8, 1],
	[11.0, 11.0, 12, 2], [10.0, 10.0, 18, 2], [14.0, 11.0, 8, 3],
	[9.0, 7.5, 2, 4],
]
const HOUSE := 6
const PAINTS := [
	Color("f4e7cf"), Color("f2c9a4"), Color("e9a88f"), Color("c5e3cf"),
	Color("bfd8ef"), Color("e8d7ad"), Color("f6f3ec"), Color("dccdea"),
]
const PAINTED := Color(1.0, 1.0, 1.0, 1.0)
const GLASS := Color(0.2, 0.36, 0.48, 0.0)
const TOWER_GLASS := Color(0.3, 0.5, 0.64, 0.0)
const TRIM := Color(0.86, 0.85, 0.82, 0.5)
const ROOF := Color(0.58, 0.58, 0.56, 0.5)
const PLANT := Color(0.8, 0.8, 0.78, 0.5)
const AWNING := Color(0.8, 0.27, 0.22, 0.5)
const POOL := Color(0.3, 0.72, 0.86, 0.5)
const TILES := Color(0.78, 0.4, 0.28, 0.5)
const PAVEMENT := Color(0.8, 0.77, 0.72)
const LAWN := Color(0.44, 0.65, 0.32)
const ASPHALT := Color(0.34, 0.34, 0.36)


## 1 inside the street grid, easing to 0 over `falloff` metres outside it.
static func mask(x: float, z: float, falloff := 12.0) -> float:
	var half := Vector2(COLUMNS[-1] + BLOCK.x * 0.5 + STREET * 0.5, (ROWS[0] - ROWS[-1] + BLOCK.y + STREET) * 0.5)
	var center_z := (float(ROWS[0]) + float(ROWS[-1])) * 0.5
	var outside := Vector2(maxf(absf(x) - half.x, 0.0), maxf(absf(z - center_z) - half.y, 0.0)).length()
	return 1.0 - smoothstep(0.0, falloff, outside)


static func build(parent: Node3D) -> Dictionary:
	var palms: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var paved: Array[Transform3D] = []
	var lawns: Array[Transform3D] = []
	var placed: Array = []
	for klass in CLASSES.size():
		placed.append([])
	for column in COLUMNS.size():
		for row in ROWS.size():
			var center := Vector2(COLUMNS[column], ROWS[row])
			var index := column * ROWS.size() + row
			var landmark := absf(center.x - LANDMARK.x) < BLOCK.x * 0.5 and absf(center.y - LANDMARK.y) < BLOCK.y * 0.5
			var slab := Transform3D(Basis.from_scale(Vector3(BLOCK.x, SLAB, BLOCK.y)), Vector3(center.x, SLAB * 0.5, center.y))
			if landmark or index % 5 == 2:
				lawns.append(slab)
				_plant_park(center, index, landmark, palms, bushes)
				continue
			paved.append(slab)
			# Four lots per block; towers cluster in a downtown around the landmark tower, and
			# the rest of the grid stays low and mid-rise.
			var downtown := 1.0 - clampf(center.distance_to(DOWNTOWN) / 105.0, 0.0, 1.0)
			for lot in 4:
				var lot_key := index * 4 + lot
				var offset := Vector2((float(lot % 2) - 0.5) * BLOCK.x * 0.5, (float(lot / 2) - 0.5) * BLOCK.y * 0.5)
				if unit_hash(lot_key + 101) < 0.12:
					# An open lot: a small planted plaza.
					for bush in 3:
						bushes.append(Transform3D(Basis(Vector3.UP, unit_hash(lot_key * 3 + bush) * TAU).scaled(Vector3.ONE * 1.4), Vector3(center.x + offset.x + (unit_hash(lot_key + bush * 7) - 0.5) * 8.0, SLAB, center.y + offset.y + (unit_hash(lot_key + bush * 11) - 0.5) * 6.0)))
					continue
				var klass := clampi(int(unit_hash(lot_key) * 2.1 + downtown * 3.3), 0, 4)
				if unit_hash(lot_key + 57) > 0.9:
					klass = 5
				var jitter := Vector2(unit_hash(lot_key + 13) - 0.5, unit_hash(lot_key + 17) - 0.5) * 1.2
				var yaw := PI if unit_hash(lot_key + 23) > 0.5 else 0.0
				var origin := Vector3(center.x + offset.x + jitter.x, SLAB, center.y + offset.y + jitter.y)
				var paint := PAINTS[int(unit_hash(lot_key + 31) * PAINTS.size()) % PAINTS.size()] as Color
				(placed[klass] as Array).append([Transform3D(Basis(Vector3.UP, yaw), origin), paint])
	# Palm avenues on the two central streets and along the street behind the beachfront row.
	for side in [-1.0, 1.0]:
		var avenue := float(side) * (BLOCK.x + STREET) * 0.5
		for kerb in [-1.0, 1.0]:
			var z := float(ROWS[0]) + BLOCK.y * 0.5 + 2.0
			while z > float(ROWS[-1]) - BLOCK.y * 0.5:
				palms.append(_tree(Vector3(avenue + float(kerb) * 3.2, SLAB, z), 0.62, palms.size()))
				z -= 13.0
	var cross := float(ROWS[0]) + (BLOCK.y + STREET) * 0.5
	var x := float(COLUMNS[0]) - BLOCK.x * 0.5
	while x < float(COLUMNS[-1]) + BLOCK.x * 0.5:
		if absf(absf(x) - (BLOCK.x + STREET) * 0.5) > 6.0:
			palms.append(_tree(Vector3(x, SLAB, cross + 2.8), 0.58, palms.size()))
		x += 14.0
	# A loose ring of palms softens the grid's outer edge against the lawns.
	var ring := Rect2(float(COLUMNS[0]) - BLOCK.x * 0.5 - STREET, float(ROWS[-1]) - BLOCK.y * 0.5 - STREET, float(COLUMNS[-1] - COLUMNS[0]) + BLOCK.x + STREET * 2.0, float(ROWS[0] - ROWS[-1]) + BLOCK.y + STREET * 2.0)
	var step := 0
	var along := 0.0
	var perimeter := (ring.size.x + ring.size.y) * 2.0
	while along < perimeter:
		var spot := _ring_point(ring, along)
		if spot.y > ring.end.y - 1.0 and absf(spot.x) < float(COLUMNS[-1]):
			along += 19.0
			continue
		palms.append(_tree(Vector3(spot.x, 0.0, spot.y), 0.55 + unit_hash(step + 700) * 0.2, step + 700))
		step += 1
		along += 17.0 + unit_hash(step + 900) * 6.0
	_add_slabs(parent, "CityStreets", [Transform3D(Basis.from_scale(Vector3(COLUMNS[-1] - COLUMNS[0] + BLOCK.x + STREET, 0.04, ROWS[0] - ROWS[-1] + BLOCK.y + STREET)), Vector3(0.0, 0.0, (ROWS[0] + ROWS[-1]) * 0.5))], ASPHALT)
	_add_slabs(parent, "CityPavedBlocks", paved, PAVEMENT)
	_add_slabs(parent, "CityParks", lawns, LAWN)
	for klass in CLASSES.size():
		add_buildings(parent, "CityBuildings%d" % klass, klass, placed[klass] as Array)
	return {"palms": palms, "bushes": bushes}


static func _plant_park(center: Vector2, index: int, landmark: bool, palms: Array[Transform3D], bushes: Array[Transform3D]) -> void:
	for tree in 7:
		var spot := center + Vector2(unit_hash(index * 19 + tree) - 0.5, unit_hash(index * 23 + tree) - 0.5) * (BLOCK - Vector2(7.0, 7.0))
		if landmark and spot.distance_to(LANDMARK) < 8.0:
			continue
		palms.append(_tree(Vector3(spot.x, SLAB, spot.y), 0.5 + unit_hash(index * 29 + tree) * 0.25, index * 7 + tree))
	for bush in 12:
		var spot := center + Vector2(unit_hash(index * 31 + bush) - 0.5, unit_hash(index * 37 + bush) - 0.5) * (BLOCK - Vector2(3.0, 3.0))
		if landmark and spot.distance_to(LANDMARK) < 7.0:
			continue
		bushes.append(Transform3D(Basis(Vector3.UP, unit_hash(index * 41 + bush) * TAU).scaled(Vector3.ONE * (1.2 + unit_hash(index * 43 + bush) * 0.9)), Vector3(spot.x, SLAB, spot.y)))


static func _ring_point(ring: Rect2, along: float) -> Vector2:
	if along < ring.size.x:
		return Vector2(ring.position.x + along, ring.position.y)
	along -= ring.size.x
	if along < ring.size.y:
		return Vector2(ring.end.x, ring.position.y + along)
	along -= ring.size.y
	if along < ring.size.x:
		return Vector2(ring.end.x - along, ring.end.y)
	return Vector2(ring.position.x, ring.end.y - (along - ring.size.x))


static func _tree(at: Vector3, size: float, turn: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(turn) * 1.37).scaled(Vector3.ONE * size), at)


static func unit_hash(value: int) -> float:
	return fposmod(sin(float(value) * 12.9898 + 78.233) * 43758.5453, 1.0)


static func _add_slabs(parent: Node3D, label: String, transforms: Array, color: Color) -> void:
	if transforms.is_empty():
		return
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = BoxMesh.new()
	instances.instance_count = transforms.size()
	for index in transforms.size():
		instances.set_instance_transform(index, transforms[index] as Transform3D)
	var finish := StandardMaterial3D.new()
	finish.albedo_color = color
	finish.roughness = 0.95
	var visual := MultiMeshInstance3D.new()
	visual.name = label
	visual.multimesh = instances
	visual.material_override = finish
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)


## Entries are [Transform3D, paint Color]; one MultiMesh per call.
static func add_buildings(parent: Node3D, label: String, klass: int, entries: Array) -> void:
	if entries.is_empty():
		return
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	# Vertex colour is multiplied by the instance colour in the Compatibility renderer.
	instances.use_colors = true
	instances.mesh = building_mesh(CLASSES[klass] as Array)
	instances.instance_count = entries.size()
	for index in entries.size():
		var entry := entries[index] as Array
		instances.set_instance_transform(index, entry[0] as Transform3D)
		instances.set_instance_color(index, Color.WHITE)
		instances.set_instance_custom_data(index, (entry[1] as Color).srgb_to_linear())
	var finish := ShaderMaterial.new()
	finish.shader = BLOCK_SHADER
	var visual := MultiMeshInstance3D.new()
	visual.name = label
	visual.multimesh = instances
	visual.material_override = finish
	# Distant scenery, like the rest of the backdrop: no shadow pass.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)


## A faceted low-poly building: window bays per floor, parapet, rooftop plant and details.
static func building_mesh(spec: Array) -> ArrayMesh:
	var width := float(spec[0])
	var depth := float(spec[1])
	var floors := int(spec[2])
	var style := int(spec[3])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := TOWER_GLASS if style == 2 else GLASS
	var top := float(floors) * FLOOR
	if style == 3:
		# Stepped hotel: a wide podium with a terrace pool and a narrower upper block.
		var podium := 3
		_facades(st, Vector3(-width * 0.5, 0.0, -depth * 0.5), Vector3(width * 0.5, podium * FLOOR, depth * 0.5), podium, glass, 0)
		_top(st, Vector3(-width * 0.5, podium * FLOOR, -depth * 0.5), Vector3(width * 0.5, podium * FLOOR, depth * 0.5), TRIM)
		_top(st, Vector3(width * 0.12, podium * FLOOR + 0.05, -depth * 0.3), Vector3(width * 0.42, podium * FLOOR + 0.05, depth * 0.3), POOL)
		_facades(st, Vector3(-width * 0.4, podium * FLOOR, -depth * 0.36), Vector3(width * 0.06, top, depth * 0.36), floors - podium, glass, 1)
		_roof(st, Vector3(-width * 0.4, top, -depth * 0.36), Vector3(width * 0.06, top, depth * 0.36))
	elif style == 4:
		_facades(st, Vector3(-width * 0.5, 0.0, -depth * 0.5), Vector3(width * 0.5, top, depth * 0.5), floors, glass, 1)
		_gable_roof(st, Vector3(-width * 0.5, top, -depth * 0.5), Vector3(width * 0.5, top, depth * 0.5))
	else:
		_facades(st, Vector3(-width * 0.5, 0.0, -depth * 0.5), Vector3(width * 0.5, top, depth * 0.5), floors, glass, style)
		_roof(st, Vector3(-width * 0.5, top, -depth * 0.5), Vector3(width * 0.5, top, depth * 0.5))
		if style == 2:
			# Tower crown.
			_box(st, Vector3(-width * 0.3, top, -depth * 0.3), Vector3(width * 0.3, top + 3.2, depth * 0.3), PAINTED)
	return st.commit()


static func _facades(st: SurfaceTool, low: Vector3, high: Vector3, floors: int, glass: Color, style: int) -> void:
	var size := high - low
	# [start corner, direction along the face (viewer's right), length, outward normal]
	var sides := [
		[Vector3(low.x, 0.0, high.z), Vector3.RIGHT, size.x, Vector3.BACK],
		[Vector3(high.x, 0.0, low.z), Vector3.LEFT, size.x, Vector3.FORWARD],
		[Vector3(high.x, 0.0, high.z), Vector3.FORWARD, size.z, Vector3.RIGHT],
		[Vector3(low.x, 0.0, low.z), Vector3.BACK, size.z, Vector3.LEFT],
	]
	var window_share := 0.8 if style == 2 else 0.55
	for side in sides:
		var start := side[0] as Vector3
		var along := side[1] as Vector3
		var length := float(side[2])
		var normal := side[3] as Vector3
		var bays := maxi(1, roundi(length / 3.0))
		var bay := length / float(bays)
		# One painted wall per side; window panes sit just in front of it.
		_face(st, start, along, normal, 0.0, length, low.y, high.y, PAINTED)
		var pane := start + normal * 0.03
		for floor_index in floors:
			var y0 := low.y + float(floor_index) * FLOOR
			if floor_index == 0 and style == 0:
				# Shopfront: one glass band under a red awning.
				_face(st, pane, along, normal, 0.0, length, y0 + 0.35, y0 + 2.5, glass)
				var out := start + normal * 1.0
				_box(st, (start + Vector3(0, y0 + 2.55, 0)).min(out + along * length + Vector3(0, y0 + 2.75, 0)), (start + Vector3(0, y0 + 2.55, 0)).max(out + along * length + Vector3(0, y0 + 2.75, 0)), AWNING)
				continue
			for bay_index in bays:
				var pier := bay * (1.0 - window_share) * 0.5
				var s0 := float(bay_index) * bay
				_face(st, pane, along, normal, s0 + pier, s0 + bay - pier, y0 + 0.9, y0 + 2.4, glass)


static func _roof(st: SurfaceTool, low: Vector3, high: Vector3) -> void:
	_top(st, low, high, ROOF)
	var rim := 0.3
	var lift := Vector3(0.0, 0.8, 0.0)
	_box(st, low, Vector3(high.x, high.y, low.z + rim) + lift, TRIM)
	_box(st, Vector3(low.x, low.y, high.z - rim), high + lift, TRIM)
	_box(st, Vector3(low.x, low.y, low.z + rim), Vector3(low.x + rim, high.y, high.z - rim) + lift, TRIM)
	_box(st, Vector3(high.x - rim, low.y, low.z + rim), Vector3(high.x, high.y, high.z - rim) + lift, TRIM)
	var span := high - low
	_box(st, low + Vector3(span.x * 0.18, 0.0, span.z * 0.25), low + Vector3(span.x * 0.42, 1.3, span.z * 0.55), PLANT)
	_box(st, low + Vector3(span.x * 0.6, 0.0, span.z * 0.5), low + Vector3(span.x * 0.78, 0.9, span.z * 0.72), PLANT)


static func _gable_roof(st: SurfaceTool, low: Vector3, high: Vector3) -> void:
	# Ridge along X with small eaves; painted gable ends.
	var eave := 0.4
	var middle := (low.z + high.z) * 0.5
	var ridge := high.y + (high.z - low.z) * 0.38
	var rise := ridge - high.y
	var south := Vector3(0.0, high.z + eave - middle, rise).normalized()
	var north := Vector3(0.0, middle - low.z + eave, -rise).normalized()
	_quad(st, Vector3(low.x - eave, high.y, high.z + eave), Vector3(high.x + eave, high.y, high.z + eave), Vector3(high.x + eave, ridge, middle), Vector3(low.x - eave, ridge, middle), south, TILES)
	_quad(st, Vector3(high.x + eave, high.y, low.z - eave), Vector3(low.x - eave, high.y, low.z - eave), Vector3(low.x - eave, ridge, middle), Vector3(high.x + eave, ridge, middle), north, TILES)
	_triangle(st, Vector3(low.x, high.y, low.z), Vector3(low.x, ridge, middle), Vector3(low.x, high.y, high.z), Vector3.LEFT, PAINTED)
	_triangle(st, Vector3(high.x, high.y, high.z), Vector3(high.x, ridge, middle), Vector3(high.x, high.y, low.z), Vector3.RIGHT, PAINTED)


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	# Clockwise as seen from outside.
	var linear := Color(color.srgb_to_linear(), color.a)
	for corner in [a, b, c]:
		st.set_color(linear)
		st.set_normal(normal)
		st.add_vertex(corner)


static func _box(st: SurfaceTool, low: Vector3, high: Vector3, color: Color) -> void:
	var size := high - low
	_face(st, Vector3(low.x, 0.0, high.z), Vector3.RIGHT, Vector3.BACK, 0.0, size.x, low.y, high.y, color)
	_face(st, Vector3(high.x, 0.0, low.z), Vector3.LEFT, Vector3.FORWARD, 0.0, size.x, low.y, high.y, color)
	_face(st, Vector3(high.x, 0.0, high.z), Vector3.FORWARD, Vector3.RIGHT, 0.0, size.z, low.y, high.y, color)
	_face(st, Vector3(low.x, 0.0, low.z), Vector3.BACK, Vector3.LEFT, 0.0, size.z, low.y, high.y, color)
	_top(st, Vector3(low.x, high.y, low.z), high, color)


static func _face(st: SurfaceTool, start: Vector3, along: Vector3, normal: Vector3, s0: float, s1: float, y0: float, y1: float, color: Color) -> void:
	# Corners seen from outside: a bottom-left, b bottom-right, c top-right, d top-left.
	var a := start + along * s0 + Vector3(0.0, y0, 0.0)
	var b := start + along * s1 + Vector3(0.0, y0, 0.0)
	var c := start + along * s1 + Vector3(0.0, y1, 0.0)
	var d := start + along * s0 + Vector3(0.0, y1, 0.0)
	_quad(st, a, b, c, d, normal, color)


static func _top(st: SurfaceTool, low: Vector3, high: Vector3, color: Color) -> void:
	# Seen from above with -Z up the screen.
	_quad(st, Vector3(low.x, high.y, high.z), Vector3(high.x, high.y, high.z), Vector3(high.x, high.y, low.z), Vector3(low.x, high.y, low.z), Vector3.UP, color)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	# Clockwise front faces: (a, d, c) and (a, c, b).
	var linear := Color(color.srgb_to_linear(), color.a)
	for corner in [a, d, c, a, c, b]:
		st.set_color(linear)
		st.set_normal(normal)
		st.add_vertex(corner)
