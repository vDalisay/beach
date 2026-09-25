class_name BeachLayoutBaker
extends RefCounted
## Reads the authored beach scene into the layout data the terrain and the litter generator use:
##   pads      footprints the sand relief levels ("zero" to the base sand, "terrace" to the relief
##             at their centre) so gameplay places and multi-legged scenery stand flat;
##   obstacles footprints loose litter keeps clear of (trunks, lookouts, poles, slots, the shop);
##   sources   scenery that makes mess around it (the court, sandcastles, lounge rows, shades).
## Only x/z footprints are read, so the relief lifting scenery at load does not change the result.
## tools/bake_beach_layout.gd writes it to data/world/beach_layout.tres; a check rebuilds it from
## the scene and compares, so a moved hut or palm cannot leave stale data behind.

const LAYOUT_PATH := "res://data/world/beach_layout.tres"
## Authored corridors that runtime scenery uses and the scene does not show.
const EXTRA_PADS := [
	# The restored lounges turtle crawls from the loungers straight into the bay.
	{"id": "route:lounges_turtle", "shape": "rect", "min": [-4.0, 17.0], "max": [-1.0, 35.0], "falloff": 3.0, "mode": "zero"},
]


static func collect(beach: Node3D) -> Dictionary:
	var pads: Array = []
	var obstacles: Array = []
	var sources: Array = []
	for service in beach.get_node("ServicePoints").get_children():
		if not service is Node3D:
			continue
		var rect := _visual_rect(service as Node3D).grow(1.0)
		if service.is_in_group("service_points"):
			pads.append(_rect_pad("service:%s" % service.name, rect, 4.0, "zero"))
		else:
			pads.append(_rect_pad("shop:%s" % service.name, rect, 4.0, "zero"))
			obstacles.append(_rect_entry("shop:%s" % service.name, _visual_rect(service as Node3D).grow(0.4)))
	var approach := beach.get_node("PierBlockout/Approach") as Node3D
	var ramp := _collision_rect(approach)
	pads.append(_rect_pad("pier:approach", Rect2(ramp.position.x - 1.0, ramp.position.y - 5.0, ramp.size.x + 2.0, ramp.size.y + 6.0), 4.0, "zero"))
	obstacles.append(_rect_entry("pier:approach", ramp.grow(0.4)))
	for child in beach.get_node("ActivityAreas").get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D
		var name := str(node.name)
		var id := "activity:%s" % name
		var at := Vector2(node.global_position.x, node.global_position.z)
		if name.begins_with("Lifeguard"):
			var body := _collision_rect(node)
			pads.append(_circle_pad(id, at, body.size.length() * 0.5 + 0.6, 3.0, "zero"))
			obstacles.append(_rect_entry(id, body.grow(0.3)))
			sources.append(_source(id, "lookout", at, 3.5))
		elif name.ends_with("Shade"):
			pads.append(_circle_pad(id, at, 5.0, 3.0, "zero"))
			for pole in node.get_children():
				if str(pole.name).begins_with("Pole"):
					obstacles.append(_rect_entry("%s/%s" % [id, pole.name], _visual_rect(pole as Node3D).grow(0.25)))
			sources.append(_source(id, "shade", at, 4.0))
		elif name == "VolleyballNet":
			pads.append(_circle_pad(id, at, 7.0, 4.0, "zero"))
			obstacles.append(_rect_entry(id, _visual_rect(node).grow(0.3)))
			sources.append(_source(id, "court", at, 8.0))
		elif name.begins_with("Sandcastle"):
			obstacles.append(_rect_entry(id, _visual_rect(node).grow(0.2)))
			sources.append(_source(id, "castle", at, 3.5))
		elif name.begins_with("BoardParking"):
			pads.append(_circle_pad(id, at, 2.2, 2.0, "terrace"))
			obstacles.append(_rect_entry(id, _visual_rect(node).grow(0.3)))
			sources.append(_source(id, "board", at, 3.0))
		elif name.contains("CafeSet"):
			pads.append(_circle_pad(id, at, 2.8, 5.5, "terrace"))
			obstacles.append(_rect_entry(id, _collision_rect(node).grow(0.3)))
			sources.append(_source(id, "cafe", at, 3.5))
	for palm in beach.get_node("Foliage").get_children():
		if palm is Node3D:
			var at := Vector2((palm as Node3D).global_position.x, (palm as Node3D).global_position.z)
			obstacles.append(_rect_entry("palm:%s" % palm.name, Rect2(at - Vector2(0.55, 0.55), Vector2(1.1, 1.1))))
	for node in beach.get_node("Zones").find_children("*", "PlacementSlot", true, false):
		var slot := node as PlacementSlot
		var id := "slot:%s" % slot.pool_id
		var first := (slot.global_transform * slot.local_slot_transform(0)).origin
		var last := (slot.global_transform * slot.local_slot_transform(slot.capacity - 1)).origin
		if slot.layout == PlacementSlot.Layout.SHELF:
			var shelf := Rect2(Vector2(minf(first.x, last.x), minf(first.z, last.z)), Vector2.ZERO).expand(Vector2(maxf(first.x, last.x), maxf(first.z, last.z)))
			obstacles.append(_rect_entry(id, shelf.grow(slot.spacing * 0.5 + 0.3)))
			continue
		for index in slot.capacity:
			var at := (slot.global_transform * slot.local_slot_transform(index)).origin
			obstacles.append(_rect_entry("%s:%d" % [id, index], Rect2(Vector2(at.x, at.z) - Vector2(0.5, 0.5), Vector2(1.0, 1.0))))
		if "beach_chair" in slot.accepted_families or "lounger" in slot.accepted_families:
			var centre := (first + last) * 0.5
			sources.append(_source(id, "lounge", Vector2(centre.x, centre.z), 2.6))
	for node in beach.get_tree().get_nodes_in_group("recovery_anchors"):
		if beach.is_ancestor_of(node):
			var at := (node as Node3D).global_position
			pads.append(_circle_pad("recovery:%s" % node.name, Vector2(at.x, at.z), 2.2, 3.0, "zero"))
			# Recovered items and fainted players land here: no litter on the spot itself.
			obstacles.append(_rect_entry("recovery:%s" % node.name, Rect2(Vector2(at.x, at.z) - Vector2(1.3, 1.3), Vector2(2.6, 2.6))))
	var spawn := (beach.get_node("PlayerSpawn") as Node3D).global_position
	pads.append(_circle_pad("spawn", Vector2(spawn.x, spawn.z), 2.5, 3.0, "zero"))
	obstacles.append(_rect_entry("spawn", Rect2(Vector2(spawn.x, spawn.z) - Vector2(1.3, 1.3), Vector2(2.6, 2.6))))
	for pad in EXTRA_PADS:
		pads.append((pad as Dictionary).duplicate(true))
	var by_id := func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id)
	pads.sort_custom(by_id)
	obstacles.sort_custom(by_id)
	sources.sort_custom(by_id)
	return {"pads": pads, "obstacles": obstacles, "sources": sources}


## Whether the saved layout data still matches the scene; returns the first difference or "".
static func compare(beach: Node3D, layout: Resource) -> String:
	if layout == null:
		return "missing %s" % LAYOUT_PATH
	var fresh := collect(beach)
	for key in ["pads", "obstacles", "sources"]:
		var saved := layout.get_meta(StringName(key), []) as Array
		var built := fresh[key] as Array
		if saved.size() != built.size():
			return "%s: %d saved, %d in the scene" % [key, saved.size(), built.size()]
		for index in built.size():
			if var_to_str(_millimetres(saved[index])) != var_to_str(_millimetres(built[index])):
				return "%s: %s differs" % [key, (built[index] as Dictionary).id]
	return ""


static func _rect_pad(id: String, rect: Rect2, falloff: float, mode: String) -> Dictionary:
	var entry := _rect_entry(id, rect)
	entry["shape"] = "rect"
	entry["falloff"] = falloff
	entry["mode"] = mode
	return entry


static func _circle_pad(id: String, centre: Vector2, radius: float, falloff: float, mode: String) -> Dictionary:
	return {"id": id, "shape": "circle", "center": [_cm(centre.x), _cm(centre.y)], "radius": _cm(radius), "falloff": falloff, "mode": mode}


static func _rect_entry(id: String, rect: Rect2) -> Dictionary:
	return {"id": id, "min": [_cm(rect.position.x), _cm(rect.position.y)], "max": [_cm(rect.end.x), _cm(rect.end.y)]}


static func _source(id: String, kind: String, centre: Vector2, radius: float) -> Dictionary:
	return {"id": id, "kind": kind, "center": [_cm(centre.x), _cm(centre.y)], "radius": radius}


static func _cm(value: float) -> float:
	return snappedf(value, 0.01)


## Top-down footprint of everything drawn under `node`.
static func _visual_rect(node: Node3D) -> Rect2:
	var rect := Rect2()
	var first := true
	var visuals: Array = node.find_children("*", "GeometryInstance3D", true, false)
	if node is GeometryInstance3D:
		visuals.append(node)
	for visual_value in visuals:
		var visual := visual_value as GeometryInstance3D
		if visual is Label3D or not visual.visible:
			continue
		var box := visual.global_transform * visual.get_aabb()
		var flat := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		rect = flat if first else rect.merge(flat)
		first = false
	if first:
		return Rect2(Vector2(node.global_position.x, node.global_position.z), Vector2.ZERO)
	return rect


## Top-down footprint of the collision shapes under `node`.
static func _collision_rect(node: Node3D) -> Rect2:
	var rect := Rect2()
	var first := true
	for shape_value in node.find_children("*", "CollisionShape3D", true, false):
		var shape := shape_value as CollisionShape3D
		if shape.shape == null:
			continue
		var box := shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
		var flat := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		rect = flat if first else rect.merge(flat)
		first = false
	if first:
		return _visual_rect(node)
	return rect


## Metre values as whole millimetres, so a saved and a rebuilt entry compare without float noise.
static func _millimetres(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return roundi(float(value) * 1000.0)
		TYPE_ARRAY:
			var result: Array = []
			for child in value:
				result.append(_millimetres(child))
			return result
		TYPE_DICTIONARY:
			var result := {}
			for key in value:
				result[key] = _millimetres(value[key])
			return result
	return value
