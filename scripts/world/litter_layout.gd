class_name LitterLayout
extends RefCounted
## Where loose litter and reusable props lie on the dry sand and the pier deck, the way tidy-up
## games dress a mess: it gathers where it has a cause (a picnic, the court, the lounge rows, the
## sandcastles, the tideline, the foot of the dunes), with clean sand between the hotspots, and the
## kind of rubbish follows the place.
##
## Each section owns a territory (spawn_anchors.tres `territories`). Its candidate points are a
## jittered 0.42 m lattice clear of service exclusions and scenery obstacles (beach_layout.tres).
## Every candidate weighs its distance to the mess sources; each waste category then draws its
## exact quota by weighted sampling without replacement, and the dominant source biases which item
## type is placed. Props gather in a few seeded groups toward the front of the beach and lean toward
## related scenery. All randomness comes from the section's seeded streams; everything the seed does
## not change (candidates, tideline, dunes, scenery sources) is computed once per content hash.

const VERSION := "litter-1"
const SPACING_MM := 420
const JITTER_MM := 130
const CATEGORY_KEYS := [&"pmd", &"organic", &"general", &"glass"]
## Seed-independent mess around each candidate, in this order.
const STATIC_KINDS := ["tideline", "drift", "court", "castle", "shade", "lookout", "board"]
const DYNAMIC_KINDS := ["picnic", "lounge"]
## Peak weight of each kind; "base" is the light scatter everywhere, "lounge_quiet" a lounge row
## that was left tidy.
const STRENGTH := {
	"base": 0.12, "tideline": 9.0, "drift": 5.0, "court": 6.0, "castle": 6.0, "shade": 3.5,
	"lookout": 2.5, "board": 3.0, "picnic": 11.0, "lounge": 5.5, "lounge_quiet": 1.0,
}
## Share of each kind that goes to PMD, organic, general and glass.
const AFFINITY := {
	"base": [1.0, 1.0, 1.0, 1.0],
	"tideline": [1.2, 0.15, 1.0, 1.7],
	"drift": [1.2, 0.3, 1.6, 0.2],
	"court": [1.6, 0.6, 0.5, 1.1],
	"castle": [1.0, 1.5, 0.6, 0.3],
	"shade": [1.0, 1.3, 0.8, 0.6],
	"lookout": [1.0, 0.8, 0.8, 0.6],
	"board": [1.2, 0.5, 1.0, 1.0],
	"picnic": [1.0, 1.7, 0.8, 0.6],
	"lounge": [1.1, 0.9, 1.3, 0.9],
}
## Item types a place favours (multiplies spawn_weight); unlisted types keep their weight.
const DEFINITION_BIAS := {
	"tideline": {"waste_plastic_bottle": 3.0, "waste_glass_bottle": 3.0, "waste_bundled_scrap": 3.0, "waste_can": 1.5, "waste_crushed_can": 1.5, "waste_drink_carton": 1.5, "waste_plastic_wrap": 2.0, "waste_sealed_oil_container": 2.0, "waste_fruit_scrap": 1.5, "waste_paper": 0.2, "waste_towel": 0.4, "waste_food_scrap": 0.5},
	"drift": {"waste_paper": 3.0, "waste_plastic_wrap": 3.0, "waste_drink_cup": 2.0, "waste_straw": 2.5, "waste_drink_carton": 1.5, "waste_towel": 0.3, "waste_bundled_scrap": 0.2},
	"court": {"waste_can": 2.0, "waste_crushed_can": 2.0, "waste_drink_cup": 2.0, "waste_plastic_bottle": 2.0, "waste_glass_bottle": 1.5},
	"castle": {"waste_ice_cream": 3.0, "waste_fries": 2.0, "waste_drink_cup": 2.0, "waste_straw": 2.0, "waste_drink_carton": 2.0},
	"picnic": {"waste_hamburger": 2.0, "waste_panini": 2.0, "waste_fries": 2.0, "waste_food_scrap": 1.5, "waste_fruit_scrap": 1.5, "waste_ice_cream": 1.5, "waste_drink_cup": 1.5, "waste_can": 1.3, "waste_drink_carton": 1.5, "waste_plastic_wrap": 1.5, "waste_towel": 0.9},
	"lounge": {"waste_towel": 1.6, "waste_can": 1.3, "waste_plastic_bottle": 1.5, "waste_glass_bottle": 1.5, "waste_ice_cream": 1.3, "waste_paper": 1.3},
}
## The tideline follows the berm: its centre and half-width in metres from the waterline.
const TIDELINE := [-6.2, 2.2]
## Wind-blown litter collects just in front of the dune toe: offset and half-width in metres.
const DRIFT := [0.8, 2.4]
const PICNICS := [2, 3]
const PICNIC_RADIUS := [1.6, 3.0]
const MESSY_LOUNGE_SHARE := 0.45
## Candidate indices fit in these low bits of a sort key.
const INDEX_BITS := 16
## Clearance radius per collision profile (SMALL, LARGE, FLAT, FLOATING), mm, and the fraction of
## two radii neighbours must keep apart.
const WASTE_CLEARANCE_MM := [140, 550, 280, 160]
const PROP_CLEARANCE_MM := [380, 950, 450, 380]
const CLEARANCE_SHARE := 0.85
## Props: groups per section, their radius, where they may lie, and the free lane large props keep
## from the walking routes.
const PROP_GROUPS := [2, 4]
const PROP_GROUP_RADIUS := [4.0, 6.5]
const PROP_FRONT_Z_MM := 5000
const PROP_SHORE_MARGIN_MM := 6000
const ROUTE_CLEARANCE_MM := 1900
const PROP_FAMILY_KINDS := {
	"volleyball": ["court", 3.0], "beach_ball": ["court", 1.5], "bucket": ["castle", 4.0], "spade": ["castle", 4.0],
	"surfboard": ["board", 4.0], "paddle": ["board", 4.0], "beach_chair": ["lounge", 2.0], "lounger": ["lounge", 2.0],
	"parasol": ["lounge", 2.0],
}

static var _prepared: Dictionary = {}

var _layout: Resource
var _exclusion: Callable
var _obstacle_buckets: Dictionary = {}
var _tables: Dictionary = {}
var _ids: Array = []


## `exclusion` tells whether a mm position lies in a fixed gameplay exclusion (service points,
## lookouts); `layout` is beach_layout.tres.
func _init(layout: Resource, exclusion: Callable) -> void:
	_layout = layout
	_exclusion = exclusion
	for obstacle in layout.get_meta(&"obstacles", []) as Array:
		var rect := Rect2i(Vector2i(roundi(float(obstacle.min[0]) * 1000.0), roundi(float(obstacle.min[1]) * 1000.0)), Vector2i.ZERO)
		rect = rect.expand(Vector2i(roundi(float(obstacle.max[0]) * 1000.0), roundi(float(obstacle.max[1]) * 1000.0)))
		for bx in range(floori(rect.position.x / 4000.0), floori(rect.end.x / 4000.0) + 1):
			for bz in range(floori(rect.position.y / 4000.0), floori(rect.end.y / 4000.0) + 1):
				var key := Vector2i(bx, bz)
				if not _obstacle_buckets.has(key):
					_obstacle_buckets[key] = []
				(_obstacle_buckets[key] as Array).append(rect)


## Everything that decides the layout besides the seed, for the manifest content hash.
static func identity(layout: Resource) -> Array:
	return [
		VERSION, SPACING_MM, JITTER_MM, STATIC_KINDS, DYNAMIC_KINDS, STRENGTH, AFFINITY, DEFINITION_BIAS,
		TIDELINE, DRIFT, PICNICS, PICNIC_RADIUS, MESSY_LOUNGE_SHARE, WASTE_CLEARANCE_MM, PROP_CLEARANCE_MM,
		CLEARANCE_SHARE, PROP_GROUPS, PROP_GROUP_RADIUS, PROP_FRONT_Z_MM, PROP_SHORE_MARGIN_MM,
		ROUTE_CLEARANCE_MM, PROP_FAMILY_KINDS,
		layout.get_meta(&"pads", []), layout.get_meta(&"obstacles", []), layout.get_meta(&"sources", []),
	]


## Places one section. `waste_counts` maps category key to count, `families` lists prop families in
## the order their rows are created, `routes` are the walking routes large props keep clear of.
## Returns {"ok", "waste": [{category, definition, position_mm, orientation}], "props": [...]}.
func place_section(
	content_hash: String,
	section_id: StringName,
	territory: Dictionary,
	pack: Dictionary,
	waste_counts: Dictionary,
	families: Array,
	definitions: Dictionary,
	litter_rng: RandomNumberGenerator,
	props_rng: RandomNumberGenerator,
	routes: Array
) -> Dictionary:
	var prepared := _prepare(content_hash, section_id, territory)
	var xs := prepared.x as PackedInt32Array
	var zs := prepared.z as PackedInt32Array
	var count := xs.size()
	# Seeded jitter keeps the lattice from showing where the litter is dense.
	var px := PackedInt32Array()
	var pz := PackedInt32Array()
	px.resize(count)
	pz.resize(count)
	for index in count:
		px[index] = xs[index] + litter_rng.randi_range(-JITTER_MM, JITTER_MM)
		pz[index] = zs[index] + litter_rng.randi_range(-JITTER_MM, JITTER_MM)
	var dynamic := _dynamic_mess(prepared, px, pz, section_id, territory, litter_rng)
	var taken := {}
	var grid := {}
	var props := _place_props(prepared, px, pz, dynamic, families, definitions, props_rng, routes, taken, grid)
	if props.size() != families.size():
		return {"ok": false, "error": "Not enough clear sand for %d props in %s." % [families.size(), section_id]}
	var waste: Array = []
	for category_index in CATEGORY_KEYS.size():
		var category_key := CATEGORY_KEYS[category_index] as StringName
		var needed := int(waste_counts.get(category_key, 0))
		if needed == 0:
			continue
		var weights := PackedFloat32Array()
		weights.resize(count)
		# Per-kind factors for this category, hoisted out of the per-candidate loop.
		var factors := PackedFloat64Array()
		for kind in STATIC_KINDS:
			factors.append(float(STRENGTH[kind]) * float(AFFINITY[kind][category_index]))
		var picnic_factor := float(STRENGTH.picnic) * float(AFFINITY.picnic[category_index])
		var lounge_factor := float(AFFINITY.lounge[category_index])
		var statics := prepared.static as PackedFloat32Array
		var slots := STATIC_KINDS.size()
		var base := float(STRENGTH.base)
		for index in count:
			var total := base + dynamic[index * 2] * picnic_factor + dynamic[index * 2 + 1] * lounge_factor
			var offset := index * slots
			for slot in slots:
				total += statics[offset + slot] * factors[slot]
			weights[index] = total
		var order := _weighted_order(weights, litter_rng)
		var placed := 0
		for index in order:
			if placed == needed:
				break
			if taken.has(index):
				continue
			var kind := _dominant_kind(prepared, dynamic, index, category_index)
			var definition := _pick_definition(definitions, category_key, pack.tags, kind, litter_rng)
			var radius := int(WASTE_CLEARANCE_MM[definition.collision_profile])
			var at := Vector2i(px[index], pz[index])
			if definition.collision_profile == ItemDefinition.CollisionProfile.LARGE and _route_distance(at, routes) < ROUTE_CLEARANCE_MM:
				continue
			if not _clear(grid, at, radius):
				continue
			taken[index] = true
			_mark(grid, at, radius)
			waste.append({
				"category": category_key,
				"definition": definition,
				"position_mm": [at.x, 0, at.y],
				"orientation": litter_rng.randi_range(0, 15),
			})
			placed += 1
		if placed < needed:
			return {"ok": false, "error": "Not enough clear sand for %s waste in %s." % [category_key, section_id]}
	return {"ok": true, "waste": waste, "props": props}


## Candidate points and their seed-independent mess, cached per content hash and section.
func _prepare(content_hash: String, section_id: StringName, territory: Dictionary) -> Dictionary:
	var key := "%s|%s" % [content_hash, section_id]
	if _prepared.has(key):
		return _prepared[key] as Dictionary
	var xs := PackedInt32Array()
	var zs := PackedInt32Array()
	var weights := PackedFloat32Array()
	var shore_ds := PackedFloat32Array()
	var x_range := territory.x_mm as PackedInt32Array
	var sand := str(territory.ground) == "sand"
	var sources: Array = []
	for source in _layout.get_meta(&"sources", []) as Array:
		var kind := str(source.kind)
		# Only scenery whose reach overlaps this territory's strip of beach matters here.
		var reach := float(source.radius) * 1300.0
		var centre_mm := float(source.center[0]) * 1000.0
		if kind in STATIC_KINDS and centre_mm + reach >= float(x_range[0]) and centre_mm - reach <= float(x_range[1]):
			sources.append(source)
	var x := x_range[0] + SPACING_MM / 2
	while x < x_range[1]:
		var xm := float(x) / 1000.0
		var shore := Coastline.shore_z(xm)
		var z_max := roundi((shore * 1000.0) - float(territory.get("shore_margin_mm", 0))) if sand else int(territory.z_max_mm)
		var inland := Coastline.inland_z(xm)
		var toe := BeachRelief.dune_toe(xm)
		var tide_gap := _smooth(0.3, 0.65, BeachRelief.noise(xm, 0.0, 8.0, 21))
		var drift_gap := _smooth(0.25, 0.6, BeachRelief.noise(xm, 0.0, 6.0, 22))
		var z := int(territory.z_min_mm) + SPACING_MM / 2
		while z < z_max:
			var at := Vector2i(x, z)
			if not _exclusion.call([x, 0, z]) and not _in_obstacle(at):
				var zm := float(z) / 1000.0
				xs.append(x)
				zs.append(z)
				shore_ds.append(zm - shore)
				var values := PackedFloat32Array()
				values.resize(STATIC_KINDS.size())
				if sand:
					values[0] = _bump((zm - shore - float(TIDELINE[0])) / float(TIDELINE[1])) * tide_gap
					values[1] = _bump((zm - inland - toe - float(DRIFT[0])) / float(DRIFT[1])) * drift_gap
				for source in sources:
					var centre := Vector2(float(source.center[0]), float(source.center[1]))
					var radius := float(source.radius)
					var distance := centre.distance_to(Vector2(xm, zm))
					if distance > radius * 1.3:
						continue
					var slot := STATIC_KINDS.find(str(source.kind))
					var value := 0.0
					if str(source.kind) == "court":
						# Spectators and players leave their cans around the court, not on it.
						value = _bump((distance - radius * 0.72) / (radius * 0.4))
					else:
						value = 1.0 - _smooth(radius * 0.35, radius, distance)
					values[slot] = maxf(values[slot], value)
				weights.append_array(values)
			z += SPACING_MM
		x += SPACING_MM
	var result := {"x": xs, "z": zs, "static": weights, "shore_d": shore_ds, "sand": sand}
	_prepared[key] = result
	return result


## Picnic spots and messy lounge rows chosen by the seed, per candidate: [picnic, lounge strength].
func _dynamic_mess(prepared: Dictionary, px: PackedInt32Array, pz: PackedInt32Array, section_id: StringName, territory: Dictionary, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count := px.size()
	var result := PackedFloat32Array()
	result.resize(count * DYNAMIC_KINDS.size())
	var shore_d := prepared.shore_d as PackedFloat32Array
	var picnic_candidates: Array[int] = []
	for index in count:
		if not bool(prepared.sand) or (pz[index] > -8000 and shore_d[index] < -10.0):
			picnic_candidates.append(index)
	var picnics: Array = []
	var picnic_count := rng.randi_range(int(PICNICS[0]), int(PICNICS[1])) if bool(prepared.sand) else 1
	for _picnic in picnic_count:
		if picnic_candidates.is_empty():
			break
		var index := picnic_candidates[rng.randi_range(0, picnic_candidates.size() - 1)]
		picnics.append([Vector2(float(px[index]), float(pz[index])) / 1000.0, rng.randf_range(float(PICNIC_RADIUS[0]), float(PICNIC_RADIUS[1]))])
	var lounges: Array = []
	var x_range := territory.x_mm as PackedInt32Array
	for source in _layout.get_meta(&"sources", []) as Array:
		if str(source.kind) != "lounge":
			continue
		var centre := Vector2(float(source.center[0]), float(source.center[1]))
		if centre.x * 1000.0 < float(x_range[0]) - 3000.0 or centre.x * 1000.0 > float(x_range[1]) + 3000.0:
			continue
		var messy := rng.randf() < MESSY_LOUNGE_SHARE
		lounges.append([centre, float(source.radius), float(STRENGTH.lounge if messy else STRENGTH.lounge_quiet)])
	for index in count:
		var at := Vector2(float(px[index]), float(pz[index])) / 1000.0
		var picnic := 0.0
		for spot in picnics:
			var distance := at.distance_to(spot[0] as Vector2)
			var radius := float(spot[1])
			if distance < radius * 1.25:
				picnic = maxf(picnic, 1.0 - _smooth(radius * 0.55, radius * 1.25, distance))
		var lounge := 0.0
		for row in lounges:
			var distance := at.distance_to(row[0] as Vector2)
			var radius := float(row[1])
			if distance < radius:
				lounge = maxf(lounge, (1.0 - _smooth(radius * 0.35, radius, distance)) * float(row[2]))
		result[index * 2] = picnic
		result[index * 2 + 1] = lounge
	return result


## The kind of place that contributes most to this candidate for this category, or "base".
func _dominant_kind(prepared: Dictionary, dynamic: PackedFloat32Array, index: int, category: int) -> String:
	var weights := prepared.static as PackedFloat32Array
	var best := "base"
	var best_value := float(STRENGTH.base)
	var offset := index * STATIC_KINDS.size()
	for slot in STATIC_KINDS.size():
		var kind := STATIC_KINDS[slot] as String
		var value := weights[offset + slot] * float(STRENGTH[kind]) * float(AFFINITY[kind][category])
		if value > best_value:
			best = kind
			best_value = value
	var picnic := dynamic[index * 2] * float(STRENGTH.picnic) * float(AFFINITY.picnic[category])
	if picnic > best_value:
		best = "picnic"
		best_value = picnic
	if dynamic[index * 2 + 1] * float(AFFINITY.lounge[category]) > best_value:
		best = "lounge"
	return best


func _place_props(
	prepared: Dictionary,
	px: PackedInt32Array,
	pz: PackedInt32Array,
	dynamic: PackedFloat32Array,
	families: Array,
	definitions: Dictionary,
	rng: RandomNumberGenerator,
	routes: Array,
	taken: Dictionary,
	grid: Dictionary
) -> Array:
	var count := px.size()
	var shore_d := prepared.shore_d as PackedFloat32Array
	var sand := bool(prepared.sand)
	var eligible := PackedByteArray()
	eligible.resize(count)
	var front: Array[int] = []
	for index in count:
		var ok := not sand or (pz[index] >= PROP_FRONT_Z_MM and shore_d[index] * 1000.0 <= -float(PROP_SHORE_MARGIN_MM))
		eligible[index] = 1 if ok else 0
		if ok:
			front.append(index)
	var groups: Array = []
	var group_count := rng.randi_range(int(PROP_GROUPS[0]), int(PROP_GROUPS[1]))
	for _group in group_count:
		if front.is_empty():
			break
		var index := front[rng.randi_range(0, front.size() - 1)]
		groups.append([Vector2(float(px[index]), float(pz[index])) / 1000.0, rng.randf_range(float(PROP_GROUP_RADIUS[0]), float(PROP_GROUP_RADIUS[1]))])
	# One weighted order per family: families in a section share their groups but lean differently.
	var orders := {}
	var cursors := {}
	var result: Array = []
	var weights_static := prepared.static as PackedFloat32Array
	for family_value in families:
		var family := str(family_value)
		if not orders.has(family):
			var weights := PackedFloat32Array()
			weights.resize(count)
			var lean: Array = PROP_FAMILY_KINDS.get(family, ["", 0.0])
			var lean_kind := str(lean[0])
			var lean_slot := STATIC_KINDS.find(lean_kind)
			var lean_strength := float(lean[1])
			var slots := STATIC_KINDS.size()
			for index in count:
				if eligible[index] == 0:
					weights[index] = 0.0
					continue
				var at := Vector2(float(px[index]), float(pz[index])) / 1000.0
				var weight := 0.15
				for group in groups:
					var distance := at.distance_to(group[0] as Vector2)
					var radius := float(group[1])
					if distance < radius:
						weight += 3.0 * (1.0 - _smooth(radius * 0.3, radius, distance))
				if lean_kind == "lounge":
					weight += dynamic[index * 2 + 1] * lean_strength
				elif lean_slot >= 0:
					weight += weights_static[index * slots + lean_slot] * lean_strength
				weights[index] = weight
			orders[family] = _weighted_order(weights, rng)
			cursors[family] = 0
		var definition := _prop_definition(definitions, StringName(family))
		var large := definition != null and definition.collision_profile == ItemDefinition.CollisionProfile.LARGE
		var radius := int(PROP_CLEARANCE_MM[definition.collision_profile]) if definition != null else 400
		var order := orders[family] as PackedInt32Array
		var cursor := int(cursors[family])
		var chosen := -1
		while cursor < order.size():
			var index := order[cursor]
			cursor += 1
			if eligible[index] == 0 or taken.has(index):
				continue
			var at := Vector2i(px[index], pz[index])
			if large and _route_distance(at, routes) < ROUTE_CLEARANCE_MM:
				continue
			if not _clear(grid, at, radius):
				continue
			chosen = index
			break
		cursors[family] = cursor
		if chosen < 0:
			break
		taken[chosen] = true
		var position := Vector2i(px[chosen], pz[chosen])
		_mark(grid, position, radius)
		result.append({"family": family, "position_mm": [position.x, 0, position.y], "orientation": rng.randi_range(0, 15)})
	return result


func _pick_definition(definitions: Dictionary, category_key: StringName, pack_tags: Variant, kind: String, rng: RandomNumberGenerator) -> ItemDefinition:
	var table := _definition_table(definitions, category_key, pack_tags, kind)
	var candidates := table[0] as Array
	var weights := table[1] as PackedInt32Array
	var roll := rng.randi_range(1, int(table[2]))
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0:
			return candidates[index] as ItemDefinition
	return candidates.back() as ItemDefinition


## Candidate types and weights for a category, pack and place, built once per generation.
func _definition_table(definitions: Dictionary, category_key: StringName, pack_tags: Variant, kind: String) -> Array:
	var key := "%s|%s|%s" % [category_key, ",".join(PackedStringArray(pack_tags)), kind]
	if _tables.has(key):
		return _tables[key] as Array
	var bias := DEFINITION_BIAS.get(kind, {}) as Dictionary
	var candidates: Array = []
	var weights := PackedInt32Array()
	var total := 0
	for definition_id in _sorted_ids(definitions):
		var definition := definitions[definition_id] as ItemDefinition
		if definition.kind != ItemDefinition.Kind.WASTE or not definition.required_tool.is_empty():
			continue
		if definition.waste_category != CATEGORY_KEYS.find(category_key):
			continue
		var tagged := false
		for tag in definition.eligible_spawn_tags:
			if tag in pack_tags:
				tagged = true
				break
		if not tagged:
			continue
		var weight := maxi(1, roundi(float(definition.spawn_weight) * float(bias.get(str(definition.definition_id), 1.0)) * 10.0))
		candidates.append(definition)
		weights.append(weight)
		total += weight
	var table := [candidates, weights, total]
	_tables[key] = table
	return table


func _prop_definition(definitions: Dictionary, family: StringName) -> ItemDefinition:
	for definition_id in _sorted_ids(definitions):
		var definition := definitions[definition_id] as ItemDefinition
		if definition.kind == ItemDefinition.Kind.PROP and definition.sorting_family == family:
			return definition
	return null


func _sorted_ids(definitions: Dictionary) -> Array:
	if _ids.is_empty():
		_ids = definitions.keys()
		_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	return _ids


## Indices by weighted sampling without replacement (Efraimidis–Spirakis keys), heaviest first.
## Keys are packed as integers (-key in micro-units, then the index) so the engine sorts them.
func _weighted_order(weights: PackedFloat32Array, rng: RandomNumberGenerator) -> PackedInt32Array:
	var keys := PackedInt64Array()
	keys.resize(weights.size())
	for index in weights.size():
		var weight := weights[index]
		var u := maxf(rng.randf(), 1e-9)
		var rank := (1 << 40) if weight <= 0.0 else mini(int(-log(u) / weight * 1000000.0), (1 << 40) - 1)
		keys[index] = (rank << INDEX_BITS) | index
	keys.sort()
	var order := PackedInt32Array()
	order.resize(keys.size())
	for index in keys.size():
		order[index] = int(keys[index] & ((1 << INDEX_BITS) - 1))
	return order


func _in_obstacle(at: Vector2i) -> bool:
	var key := Vector2i(floori(at.x / 4000.0), floori(at.y / 4000.0))
	if not _obstacle_buckets.has(key):
		return false
	for rect in _obstacle_buckets[key]:
		if (rect as Rect2i).has_point(at):
			return true
	return false


func _clear(grid: Dictionary, at: Vector2i, radius: int) -> bool:
	var reach := 2
	var cell := Vector2i(floori(at.x / 500.0), floori(at.y / 500.0))
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var key := cell + Vector2i(dx, dz)
			if not grid.has(key):
				continue
			for entry in grid[key]:
				var other := entry as Vector3i
				var needed := float(radius + other.z) * CLEARANCE_SHARE
				if Vector2(at - Vector2i(other.x, other.y)).length() < needed:
					return false
	return true


func _mark(grid: Dictionary, at: Vector2i, radius: int) -> void:
	var key := Vector2i(floori(at.x / 500.0), floori(at.y / 500.0))
	if not grid.has(key):
		grid[key] = []
	(grid[key] as Array).append(Vector3i(at.x, at.y, radius))


func _route_distance(at: Vector2i, routes: Array) -> float:
	var point := Vector2(at)
	var closest := INF
	for route in routes:
		for index in range((route as Array).size() - 1):
			var start := route[index] as Vector3
			var finish := route[index + 1] as Vector3
			var a := Vector2(start.x, start.z) * 1000.0
			var b := Vector2(finish.x, finish.z) * 1000.0
			var segment := b - a
			var fraction := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
			closest = minf(closest, point.distance_to(a + segment * fraction))
	return closest


static func _bump(t: float) -> float:
	if absf(t) >= 1.0:
		return 0.0
	var inner := 1.0 - t * t
	return inner * inner


static func _smooth(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
