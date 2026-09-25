class_name SortingStation
extends Node3D

signal contents_changed
signal feedback_requested(message: String)

const CELL_COLUMNS := 20
const CELL_ROWS := 12
const CELL_COUNT := CELL_COLUMNS * CELL_ROWS
const BIN_CAPACITY := 50
const RACK_CAPACITY := 8
const CATEGORIES: Array[StringName] = [&"pmd", &"organic", &"general", &"glass"]
const CATEGORY_NAMES := ["PMD", "Organic", "General", "Glass"]
const PROXY_COLORS := [Color("4aa9e9"), Color("78a84c"), Color("777b82"), Color("78d4c5")]
const BAG_SCENE := preload("res://scenes/items/disposal_bag.tscn")

@export var station_id: StringName = &"sorting:S1"
@onready var tabletop: StaticBody3D = %Tabletop
@onready var table_camera: Camera3D = %TableCamera
@onready var proxy_root: Node3D = %ItemProxies
@onready var tray_items: Node3D = %TrayItems
@onready var bin_areas: Node3D = %BinAreas

var session: RunSession
var player: BeachPlayer
var view: SortingView
var active := false
var _saved_camera_current := false
var _saved_hand_visible := true
var _roof: Node3D
var _proxies: Dictionary = {}
var _bag_views: Dictionary = {}


func configure(run_session: RunSession, player_body: BeachPlayer, sorting_view: SortingView) -> void:
	session = run_session
	player = player_body
	view = sorting_view
	tabletop.set_meta(&"target_id", station_id)
	tabletop.set_meta(&"display_name", "Sorting table")
	tabletop.set_meta(&"interaction_actions", PackedStringArray(["interact"]))
	_ensure_records()
	if not player.interactor.interact_requested.is_connected(_on_interact_requested):
		player.interactor.interact_requested.connect(_on_interact_requested)
	if not session.bags_changed.is_connected(_on_bags_changed):
		session.bags_changed.connect(_on_bags_changed)
	for index in range(CATEGORIES.size()):
		var area := bin_areas.get_child(index) as Area3D
		_build_bin_walls(area)
		area.body_entered.connect(_on_bin_body_entered.bind(CATEGORIES[index], area))
	_refresh_proxies()
	_refresh_valuable_views()
	for bag_key in session.state.bag_records:
		_refresh_bag_view(StringName(str(bag_key)))


func table_record() -> Dictionary:
	return session.state.table_records[station_id] as Dictionary


func bin_id(category: StringName) -> StringName:
	return StringName("%s:%s" % [station_id, category])


func bin_record(category: StringName) -> Dictionary:
	return session.state.bin_records[bin_id(category)] as Dictionary


func rack_id() -> StringName:
	return StringName("%s:rack" % station_id)


func rack_record() -> Dictionary:
	return session.state.container_records[rack_id()] as Dictionary


func rack_slot_transform(index: int) -> Transform3D:
	var local := Vector3(3.1, 0.65 if index < 4 else 1.35, -1.65 + float(index % 4) * 1.05)
	return Transform3D(Basis.IDENTITY, to_global(local))


func bag_view_for(bag_id: StringName) -> DisposalBag:
	return _bag_views.get(bag_id) as DisposalBag


func cell_id(index: int) -> StringName:
	return StringName("cell:%03d" % index)


func item_at(index: int) -> StringName:
	return StringName(str((table_record().cells as Dictionary).get(cell_id(index), "")))


func first_free_cell() -> StringName:
	var cells := table_record().cells as Dictionary
	for index in range(CELL_COUNT):
		var candidate := cell_id(index)
		if not cells.has(candidate):
			return candidate
	return StringName()


func free_cell_count() -> int:
	return CELL_COUNT - (table_record().cells as Dictionary).size()


func try_unload(player_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_unload.bind(player_id))
	if not session.state.players.has(player_id):
		return ActionResult.rejected(ActionResult.Reason.INVALID_OWNER, "Missing player")
	var player_record := session.state.players[player_id] as Dictionary
	var waste := player_record.trash_bag as Array[StringName]
	var valuables := player_record.valuable_bag as Array[StringName]
	var order := player_record.bag_order as Array[StringName]
	if waste.is_empty() and valuables.is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Bag is empty")
	if waste.size() > free_cell_count():
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Need %d free table cells; %d available" % [waste.size(), free_cell_count()])
	for item_id in waste:
		if not _is_bag_item(item_id, player_id, ItemDefinition.Kind.WASTE):
			return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Bag disagrees with waste %s" % item_id)
	for item_id in valuables:
		if not _is_bag_item(item_id, player_id, ItemDefinition.Kind.VALUABLE):
			return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Bag disagrees with valuable %s" % item_id)
	if order.size() != waste.size() + valuables.size():
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Bag order disagrees with contents")
	var seen := {}
	for item_id in order:
		if seen.has(item_id) or (item_id not in waste and item_id not in valuables):
			return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Bag order contains an invalid item")
		seen[item_id] = true
	var cells := table_record().cells as Dictionary
	var tray := table_record().tray as Array
	var changed := PackedStringArray()
	for item_id in order:
		var record := session.state.items[item_id] as ItemRecord
		if item_id in waste:
			var cell := first_free_cell()
			cells[cell] = item_id
			record.location = ItemRecord.Location.TABLE
			record.slot_id = cell
		else:
			tray.append(item_id)
			record.location = ItemRecord.Location.VALUABLE_TRAY
			record.slot_id = &""
		record.holder_id = &""
		record.container_id = station_id
		changed.append(str(item_id))
	player_record.trash_bag = [] as Array[StringName]
	player_record.valuable_bag = [] as Array[StringName]
	player_record.bag_order = [] as Array[StringName]
	session.finalize_action(changed)
	_contents_committed()
	return ActionResult.accepted(changed, {"waste": waste.size(), "valuables": valuables.size()})


func try_sell_valuable(player_id: StringName, item_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_sell_valuable.bind(player_id, item_id))
	if not session.state.players.has(player_id) or not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Unknown player or valuable")
	var record := session.state.items[item_id] as ItemRecord
	var tray := table_record().tray as Array
	var definition := session.definitions.get(record.definition_id) as ItemDefinition
	if record.location != ItemRecord.Location.VALUABLE_TRAY or record.container_id != station_id or item_id not in tray:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Valuable is not on this tray")
	if definition == null or definition.kind != ItemDefinition.Kind.VALUABLE or record.required or definition.base_sale_value <= 0:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Item cannot be sold")
	var amount := definition.base_sale_value
	var player_record := session.state.players[player_id] as Dictionary
	var receipt := {
		"sale_id": "sale:%06d" % (session.state.valuable_sales.size() + 1),
		"item_id": str(item_id),
		"definition_id": str(record.definition_id),
		"player_id": str(player_id),
		"station_id": str(station_id),
		"amount": amount,
	}
	tray.erase(item_id)
	record.location = ItemRecord.Location.SOLD
	record.container_id = &""
	player_record.money = int(player_record.money) + amount
	session.state.valuable_sales.append(receipt)
	session.finalize_action(PackedStringArray([str(item_id)]), PackedStringArray(), PackedStringArray([str(player_id)]))
	_contents_committed()
	return ActionResult.accepted(PackedStringArray([str(item_id)]), receipt)


func try_sort(item_id: StringName, category: StringName, physical_area: Area3D = null) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_sort.bind(item_id, category, physical_area))
	if category not in CATEGORIES:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Unknown bin")
	if not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing item")
	var record := session.state.items[item_id] as ItemRecord
	var definition := session.definitions.get(record.definition_id) as ItemDefinition
	if definition == null or definition.kind != ItemDefinition.Kind.WASTE:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Only waste enters sorting bins")
	var source_bin := StringName()
	if record.location == ItemRecord.Location.TABLE:
		if record.container_id != station_id or (table_record().cells as Dictionary).get(record.slot_id) != item_id:
			return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Table cell disagrees with item")
	elif record.location == ItemRecord.Location.BIN:
		source_bin = record.container_id
		if not session.state.bin_records.has(source_bin) or item_id not in (session.state.bin_records[source_bin] as Dictionary).items:
			return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Bin disagrees with item")
		if not str(source_bin).begins_with("%s:" % station_id):
			return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Item belongs to another station")
	elif record.location == ItemRecord.Location.WORLD:
		if physical_area == null or physical_area != bin_areas.get_child(CATEGORIES.find(category)):
			return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Waste has not entered this bin opening")
		var world_view := session.item_view_manager.view_for(item_id) if session.item_view_manager != null else null
		if world_view == null or not physical_area.overlaps_body(world_view):
			return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Waste has not entered this bin opening")
		if world_view.linear_velocity.y >= -0.1 or world_view.global_position.y < physical_area.global_position.y - 0.02:
			return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Waste must enter through the open top")
	else:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Item is not on this table or in its bin")
	var destination := bin_record(category)
	if source_bin == bin_id(category):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Already in that bin")
	if (destination.items as Array).size() >= BIN_CAPACITY:
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "%s bin is full" % CATEGORY_NAMES[CATEGORIES.find(category)])
	if record.location == ItemRecord.Location.TABLE:
		(table_record().cells as Dictionary).erase(record.slot_id)
	elif record.location == ItemRecord.Location.BIN:
		(session.state.bin_records[source_bin] as Dictionary).items.erase(item_id)
	(destination.items as Array).append(item_id)
	record.location = ItemRecord.Location.BIN
	record.holder_id = &""
	record.slot_id = &""
	record.container_id = bin_id(category)
	var correct := definition.waste_category == CATEGORIES.find(category)
	var changed := PackedStringArray([str(item_id)])
	var bag_ids := PackedStringArray()
	if (destination.items as Array).size() == BIN_CAPACITY:
		var sealed := _seal_bin(category)
		if not sealed.is_empty():
			for sealed_item in sealed.item_ids:
				if str(sealed_item) not in changed:
					changed.append(str(sealed_item))
			bag_ids.append(str(sealed.bag_id))
	session.finalize_action(changed, PackedStringArray(), PackedStringArray(), bag_ids)
	_contents_committed()
	return ActionResult.accepted(changed, {"correct": correct, "category": str(category), "sealed_bag_id": bag_ids[0] if not bag_ids.is_empty() else ""})


func try_unsort(item_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_unsort.bind(item_id))
	if not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing item")
	var record := session.state.items[item_id] as ItemRecord
	if record.location != ItemRecord.Location.BIN or not session.state.bin_records.has(record.container_id):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Item is not in a bin")
	if not str(record.container_id).begins_with("%s:" % station_id):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Item belongs to another station")
	var source := session.state.bin_records[record.container_id] as Dictionary
	if item_id not in source.items:
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Bin disagrees with item")
	var cell := first_free_cell()
	if cell.is_empty():
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Table is full; move directly to another bin")
	(source.items as Array).erase(item_id)
	(table_record().cells as Dictionary)[cell] = item_id
	record.location = ItemRecord.Location.TABLE
	record.container_id = station_id
	record.slot_id = cell
	var changed := PackedStringArray([str(item_id)])
	session.finalize_action(changed)
	_contents_committed()
	return ActionResult.accepted(changed, {"cell_id": str(cell)})


func try_seal(category: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_seal.bind(category))
	if category not in CATEGORIES:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Unknown bin")
	if (bin_record(category).items as Array).is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Cannot seal an empty bin")
	if _first_free_rack_slot() < 0:
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Output rack is full")
	var sealed := _seal_bin(category)
	var changed := PackedStringArray()
	for item_id in sealed.item_ids:
		changed.append(str(item_id))
	session.finalize_action(changed, PackedStringArray(), PackedStringArray(), PackedStringArray([str(sealed.bag_id)]))
	_contents_committed()
	return ActionResult.accepted(changed, {"bag_id": str(sealed.bag_id), "count": changed.size(), "correct_count": sealed.correct_count})


func seal_waiting_full_bin() -> Dictionary:
	if _first_free_rack_slot() < 0:
		return {}
	for category in CATEGORIES:
		if (bin_record(category).items as Array).size() == BIN_CAPACITY:
			var sealed := _seal_bin(category)
			return sealed
	return {}


func enter() -> void:
	if active or player == null or view == null:
		return
	active = true
	player.set_input_enabled(false)
	player.input_reader.set_context(InputReader.Context.TABLE)
	_saved_hand_visible = player.hand_rig.visible
	player.hand_rig.hide()
	_saved_camera_current = player.camera.current
	table_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_roof = get_parent().get_node_or_null("Hut/Roof") as Node3D
	if _roof != null:
		_roof.hide()
	view.open(self)


func exit() -> void:
	if not active:
		return
	view.close()
	if _roof != null:
		_roof.show()
	table_camera.current = false
	player.camera.current = _saved_camera_current
	player.hand_rig.visible = _saved_hand_visible
	player.input_reader.set_context(InputReader.Context.WORLD)
	player.set_input_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	active = false


func _ensure_records() -> void:
	if not session.state.table_records.has(station_id):
		session.state.table_records[station_id] = {"cells": {}, "tray": []}
	for category in CATEGORIES:
		var key := bin_id(category)
		if not session.state.bin_records.has(key):
			session.state.bin_records[key] = {"items": [], "capacity": BIN_CAPACITY, "category": category}
	if not session.state.container_records.has(rack_id()):
		session.state.container_records[rack_id()] = {"kind": "output_rack", "slots": {}, "capacity": RACK_CAPACITY}


func _first_free_rack_slot() -> int:
	var slots := rack_record().slots as Dictionary
	for index in range(RACK_CAPACITY):
		if not slots.has(index):
			return index
	return -1


func _seal_bin(category: StringName) -> Dictionary:
	var slot := _first_free_rack_slot()
	if slot < 0:
		return {}
	var contents := (bin_record(category).items as Array).duplicate()
	if contents.is_empty():
		return {}
	var bag_id := StringName("bag:%06d" % session.state.next_runtime_bag_serial)
	session.state.next_runtime_bag_serial += 1
	var correct_count := 0
	for item_value in contents:
		var item_id := StringName(str(item_value))
		var record := session.state.items[item_id] as ItemRecord
		var definition := session.definitions[record.definition_id] as ItemDefinition
		if definition.waste_category == CATEGORIES.find(category):
			correct_count += 1
		record.location = ItemRecord.Location.SEALED
		record.container_id = bag_id
		record.holder_id = &""
		record.slot_id = &""
	bin_record(category).items = []
	(rack_record().slots as Dictionary)[slot] = bag_id
	var bag := {
		"bag_id": bag_id,
		"category": category,
		"item_ids": contents,
		"correct_count": correct_count,
		"sealed": true,
		"location": "RACK",
		"station_id": station_id,
		"rack_slot": slot,
		"holder_id": &"",
		"container_id": &"",
		"world_transform": ItemRecord._transform_to_array(rack_slot_transform(slot)),
		"linear_velocity": ItemRecord._vector_to_array(Vector3.ZERO),
		"angular_velocity": ItemRecord._vector_to_array(Vector3.ZERO),
		"sleeping": true,
	}
	session.state.bag_records[bag_id] = bag
	return {"bag_id": bag_id, "item_ids": contents, "correct_count": correct_count}


func _is_bag_item(item_id: StringName, player_id: StringName, expected_kind: ItemDefinition.Kind) -> bool:
	if not session.state.items.has(item_id):
		return false
	var record := session.state.items[item_id] as ItemRecord
	var definition := session.definitions.get(record.definition_id) as ItemDefinition
	return record.location == ItemRecord.Location.BAG and record.holder_id == player_id and definition != null and definition.kind == expected_kind


func _contents_committed() -> void:
	_refresh_proxies()
	_refresh_valuable_views()
	($OutputRack/RackLabel as Label3D).text = "SEALED BAGS %d/8" % (rack_record().slots as Dictionary).size()
	contents_changed.emit()


func _refresh_proxies() -> void:
	var cells := table_record().cells as Dictionary
	for cell_key in _proxies.keys():
		var proxy := _proxies[cell_key] as Node3D
		if cells.get(cell_key) == proxy.get_meta(&"item_id"):
			continue
		proxy.free()
		_proxies.erase(cell_key)
	for index in range(CELL_COUNT):
		var cell := cell_id(index)
		var item_id := StringName(str(cells.get(cell, "")))
		if item_id.is_empty() or _proxies.has(cell):
			continue
		var record := session.state.items[item_id] as ItemRecord
		var definition := session.definitions[record.definition_id] as ItemDefinition
		var proxy := Node3D.new()
		proxy.position = Vector3((index % CELL_COLUMNS - 9.5) * 0.22, 0.855, (index / CELL_COLUMNS - 5.5) * 0.22)
		proxy.set_meta(&"item_id", item_id)
		proxy_root.add_child(proxy)
		var scene := definition.visual_scene()
		if scene != null and definition.visual_scene_path != "res://art/placeholders/missing_asset.tscn":
			var visual := scene.instantiate() as Node3D
			var source_root := visual.get_node_or_null("Visual") as Node3D
			var source: MeshInstance3D = null
			if source_root != null and source_root.get_child_count() > 0:
				source = source_root.get_child(0) as MeshInstance3D
			if source != null and source.mesh != null:
				var size := source.get_aabb().size
				var lay_flat := size.y > maxf(size.x, size.z) * 1.3
				if lay_flat:
					visual.rotation.x = PI * 0.5
				visual.scale = Vector3.ONE * (0.17 / maxf(maxf(size.x, size.y if lay_flat else size.z), 0.01))
			else:
				visual.scale = Vector3.ONE * (0.17 / maxf(WorldItem.profile_size(definition.collision_profile).x, WorldItem.profile_size(definition.collision_profile).z))
			proxy.add_child(visual)
		else:
			var box := BoxMesh.new()
			box.size = Vector3(0.15, 0.07, 0.15)
			var material := StandardMaterial3D.new()
			material.albedo_color = PROXY_COLORS[definition.waste_category]
			var mesh := MeshInstance3D.new()
			mesh.mesh = box
			mesh.material_override = material
			proxy.add_child(mesh)
		_proxies[cell] = proxy


func _refresh_valuable_views() -> void:
	for child in tray_items.get_children():
		child.free()
	var tray := table_record().tray as Array
	for index in range(mini(tray.size(), 8)):
		var item_id := StringName(str(tray[index]))
		var record := session.state.items[item_id] as ItemRecord
		var definition := session.definitions[record.definition_id] as ItemDefinition
		var scene := definition.visual_scene()
		if scene == null:
			continue
		var visual := scene.instantiate() as Node3D
		visual.position = Vector3((index % 3 - 1) * 0.24, 0, (index / 3 - 1) * 0.22)
		tray_items.add_child(visual)


func _build_bin_walls(area: Area3D) -> void:
	var shell := StaticBody3D.new()
	shell.name = "OpenBinWalls"
	shell.collision_layer = 8
	shell.collision_mask = 0
	area.add_child(shell)
	var material := (area.get_node("Bin") as MeshInstance3D).material_override
	for part in [
		{"position": Vector3(-0.43, -0.35, 0), "size": Vector3(0.08, 0.8, 0.6)},
		{"position": Vector3(0.43, -0.35, 0), "size": Vector3(0.08, 0.8, 0.6)},
		{"position": Vector3(0, -0.35, -0.27), "size": Vector3(0.9, 0.8, 0.08)},
		{"position": Vector3(0, -0.35, 0.27), "size": Vector3(0.9, 0.8, 0.08)},
	]:
		var box := BoxMesh.new()
		box.size = part.size
		var visual := MeshInstance3D.new()
		visual.position = part.position
		visual.mesh = box
		visual.material_override = material
		visual.visible = false
		shell.add_child(visual)
		var shape := BoxShape3D.new()
		shape.size = part.size
		var collision := CollisionShape3D.new()
		collision.position = part.position
		collision.shape = shape
		shell.add_child(collision)


func _on_bags_changed(bag_ids: PackedStringArray) -> void:
	for bag_text in bag_ids:
		_refresh_bag_view(StringName(bag_text))
	($OutputRack/RackLabel as Label3D).text = "SEALED BAGS %d/8" % (rack_record().slots as Dictionary).size()


func _refresh_bag_view(bag_id: StringName) -> void:
	var bag := session.state.bag_records.get(bag_id, {}) as Dictionary
	if bag.is_empty() or StringName(str(bag.get("station_id", ""))) != station_id:
		return
	var location := str(bag.location)
	if location != "RACK" and location != "WORLD":
		if _bag_views.has(bag_id):
			(_bag_views[bag_id] as DisposalBag).queue_free()
			_bag_views.erase(bag_id)
		return
	var view := bag_view_for(bag_id)
	if view == null:
		view = BAG_SCENE.instantiate() as DisposalBag
		add_child(view)
		view.configure(bag, session.item_view_manager.recovery_bounds.is_outside)
		view.fell_out_of_bounds.connect(_on_bag_fell_out)
		_bag_views[bag_id] = view
	else:
		view.restore_from_record()


func _on_bag_fell_out(bag_id: StringName) -> void:
	var bag := session.state.bag_records.get(bag_id, {}) as Dictionary
	if bag.is_empty() or str(bag.location) != "WORLD":
		return
	var origin := global_position + Vector3(0, 0.05, 4.0)
	var found := false
	var candidate := origin
	for distance in [0.0, 1.0, 2.0, 3.0, 4.0]:
		for direction in [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			candidate = origin + direction * distance
			if _bag_recovery_clear(bag_id, candidate):
				found = true
				break
		if found:
			break
	bag.world_transform = ItemRecord._transform_to_array(Transform3D(Basis.IDENTITY, candidate if found else origin))
	bag.linear_velocity = ItemRecord._vector_to_array(Vector3.ZERO)
	bag.angular_velocity = ItemRecord._vector_to_array(Vector3.ZERO)
	bag.sleeping = true
	session.finalize_action(PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray([str(bag_id)]))


func _bag_recovery_clear(bag_id: StringName, position: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.46, 0.5, 0.32)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.25)
	query.collision_mask = 1 | 4 | 8
	var view := bag_view_for(bag_id)
	if view != null:
		query.exclude = [view.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _on_interact_requested(target: Dictionary) -> void:
	if StringName(str(target.get("id", ""))) == station_id:
		enter()


func _on_bin_body_entered(body: Node3D, category: StringName, area: Area3D) -> void:
	if body is not WorldItem or session == null:
		return
	var result := try_sort((body as WorldItem).item_id, category, area)
	if result.ok:
		feedback_requested.emit("Sorted into %s" % CATEGORY_NAMES[CATEGORIES.find(category)])
	else:
		feedback_requested.emit(result.message)
