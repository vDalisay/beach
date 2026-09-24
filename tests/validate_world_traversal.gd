extends SceneTree

const REEF_DRESSING := preload("res://scripts/world/reef_dressing.gd")

var failures := 0
var player: BeachPlayer


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	await process_frame
	main.settings_store.reset_all()
	main.start_run()
	await _physics_frames(5)
	player = main.run_root.get_node("Player") as BeachPlayer
	var definition := load("res://data/world/beach_01.tres") as BeachDefinition
	var route := definition.starting_state.get("walk_route", []) as Array

	Engine.time_scale = 8.0
	var traversed := 0.0
	for index in range(1, route.size()):
		var target := route[index] as Vector3
		var reached := false
		for frame in 480:
			var before := player.global_position
			var flat_target := Vector3(target.x, player.global_position.y, target.z)
			player.look_at(flat_target, Vector3.UP)
			_send_stick(-1.0)
			await physics_frame
			traversed += Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length()
			if player.global_position.y < -1.0:
				break
			if Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length() < 1.2:
				reached = true
				break
		check(reached, "controller route reaches waypoint %d" % index)
		if not reached:
			break
	_send_stick(0.0)
	Engine.time_scale = 1.0
	check(player.global_position.y >= -1.0, "coastline traversal stays on authored terrain")

	var hut_entries := 0
	for service_value in definition.starting_state.get("service_points", {}).values():
		var service := service_value as Vector3
		player.global_position = service + Vector3(0, 0.05, 10)
		player.velocity = Vector3.ZERO
		player.look_at(Vector3(service.x, player.global_position.y, service.z), Vector3.UP)
		_send_stick(-1.0)
		await _physics_frames(180)
		_send_stick(0.0)
		var local := player.global_position - service
		if absf(local.x) < 1.2 and local.z < 2.7 and local.z > -2.6:
			hut_entries += 1
	check(hut_entries == 3, "controller enters all three service huts through the carry-width doors")
	for service_id in ["S1", "S2", "S3"]:
		var exclusion := main.run_root.get_node("Beach/SpawnExclusions/%s" % service_id) as Area3D
		check((exclusion.collision_layer & PlayerInteractor.TARGET_MASK) == 0, "%s spawn exclusion cannot hide an interactable" % service_id)
	for category in ["organic", "glass"]:
		var container := (main.run_root as RunSession).waste_containers[StringName("container:S1:%s" % category)] as WasteContainer
		player.global_position = container.global_position + Vector3(0, 0.05, 1.7)
		player.velocity = Vector3.ZERO
		player.camera.look_at(container.global_position + Vector3.UP * 1.2)
		await physics_frame
		check(str(player.interactor.update_target().get("id", "")) == str(container.container_id), "S1 %s back-row container is aimable from the beach" % category)
	var shop := main.run_root.get_node("Beach/ServicePoints/EquipmentShop/ShopStations") as EquipmentShop
	player.global_position = Vector3(10.5, 0.05, 3.0)
	player.velocity = Vector3.ZERO
	var shop_front := Vector3(10.5, 0, -2.0)
	player.look_at(Vector3(shop_front.x, player.global_position.y, shop_front.z), Vector3.UP)
	_send_stick(-1.0)
	for frame in 150:
		await physics_frame
		if Vector2(player.global_position.x - shop_front.x, player.global_position.z - shop_front.z).length() < 0.4:
			break
	_send_stick(0.0)
	player.camera.look_at(shop.counter.global_position)
	await physics_frame
	var shop_target := player.interactor.update_target()
	var shop_reached := str(shop_target.get("id", "")) == "shop:counter" and shop.player_near_counter()
	check(shop_reached, "normal movement from the beach reaches the S2 equipment shop counter")
	if shop_reached:
		var press_shop := InputEventKey.new()
		press_shop.physical_keycode = KEY_E
		press_shop.pressed = true
		Input.parse_input_event(press_shop)
		await _physics_frames(2)
		var release_shop := press_shop.duplicate() as InputEventKey
		release_shop.pressed = false
		Input.parse_input_event(release_shop)
		await physics_frame
		check(main.progression_view.visible, "normal interact input opens the shop")
		main.progression_view.close()
	var beach := main.run_root.get_node("Beach") as Node3D
	for rock_name in ["ReefRock01", "ReefRock13"]:
		var rock := beach.get_node("Terrain/ReefDressing/%s" % rock_name) as StaticBody3D
		var origin := rock.global_position
		var hit := beach.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(origin.x, 0, origin.z), Vector3(origin.x, -5, origin.z)))
		check(hit.get("collider") == rock, "%s has a solid elevated reef surface" % rock_name)
	check(await _cross_surface(main.run_root as RunSession), "normal movement enters and leaves the water with air recovery")
	var west_reached := await _swim_lane(Vector3(2.5, -2.1, 101), Vector3(2.5, -2.1, 119))
	var east_reached := await _swim_lane(Vector3(40, -2.1, 118), Vector3(40, -2.1, 137))
	check(west_reached and east_reached, "player swims through both structural reef channels")
	var session := main.run_root as RunSession
	var reef_checked := 0
	var reef_overlaps := 0
	var physics_overlaps := 0
	var pickup_can: ItemRecord
	var pickup_distance := INF
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if not str(item.home_section_id).begins_with("reef_"):
			continue
		if item.location not in [ItemRecord.Location.WORLD, ItemRecord.Location.BURIED, ItemRecord.Location.ATTACHED]:
			continue
		var position := item.dig_surface_position if item.buried else item.last_world_transform.origin
		var point_mm := [roundi(position.x * 1000.0), roundi(position.y * 1000.0), roundi(position.z * 1000.0)]
		if REEF_DRESSING.blocks_point(point_mm):
			reef_overlaps += 1
		if item.location == ItemRecord.Location.WORLD:
			var query := PhysicsPointQueryParameters3D.new()
			query.position = position
			query.collision_mask = 1
			for hit in player.get_world_3d().direct_space_state.intersect_point(query):
				if str(hit.collider.name).begins_with("ReefRock"):
					physics_overlaps += 1
		reef_checked += 1
		if item.location == ItemRecord.Location.WORLD and item.definition_id == &"waste_can":
			var distance := position.distance_to(Vector3(30.6, -2.8, 147.6))
			if distance < pickup_distance:
				pickup_distance = distance
				pickup_can = item
	check(reef_checked >= 1000 and reef_overlaps == 0 and physics_overlaps == 0, "all reef world, buried-reveal and attachment origins clear structural rock bounds and real colliders")
	check(pickup_can != null, "reef has a real can near the formerly trapped target")
	if pickup_can != null:
		player.set_physics_process(false)
		session.swim_service.set_physics_process(false)
		player.global_position = pickup_can.last_world_transform.origin + Vector3(0, 0, 1.4)
		await _physics_frames(120)
		var aimed := {}
		for offset in [Vector3(0, 0, 1.4), Vector3(1.4, 0, 0), Vector3(0, 0, -1.4), Vector3(-1.4, 0, 0)]:
			player.global_position = pickup_can.last_world_transform.origin + offset
			player.camera.look_at(pickup_can.last_world_transform.origin)
			await _physics_frames(2)
			aimed = player.interactor.update_target()
			if str(aimed.get("id", "")) == str(pickup_can.item_id):
				break
		check(str(aimed.get("id", "")) == str(pickup_can.item_id), "normal pickup ray reaches a reef can near the former rock overlap")
		if str(aimed.get("id", "")) == str(pickup_can.item_id):
			player.set_physics_process(true)
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			Input.parse_input_event(press)
			await _physics_frames(3)
			var release := press.duplicate() as InputEventMouseButton
			release.pressed = false
			Input.parse_input_event(release)
			await physics_frame
			check(pickup_can.location == ItemRecord.Location.BAG, "normal primary input collects reef can into the original bag")
		player.set_physics_process(true)
		session.swim_service.set_physics_process(true)
	var new_families := [&"waste_straw", &"waste_plastic_wrap", &"waste_drink_carton", &"waste_fries", &"waste_hamburger", &"waste_sealed_oil_container"]
	var collected_new: Array[StringName] = []
	for definition_id in new_families:
		var collected_id := await _collect_catalog_item(session, definition_id)
		check(not collected_id.is_empty(), "normal primary input collects %s from the playable beach" % definition_id)
		if not collected_id.is_empty():
			collected_new.append(collected_id)
	if collected_new.size() == new_families.size():
		var sorting := session.sorting_stations[&"sorting:S1"] as SortingStation
		check(sorting.try_unload(&"local").ok, "new litter and the reef can unload to the real sorting table")
		for item_id in collected_new:
			var item := session.state.items[item_id] as ItemRecord
			var category: StringName = [&"pmd", &"organic", &"general", &"glass"][(session.definitions[item.definition_id] as ItemDefinition).waste_category]
			var sorted := sorting.try_sort(item_id, category)
			check(sorted.ok and bool(sorted.receipt.get("correct", false)), "%s sorts into %s" % [item.definition_id, category])
		if pickup_can != null and pickup_can.location == ItemRecord.Location.TABLE:
			check(sorting.try_sort(pickup_can.item_id, &"pmd").ok, "reef can joins the PMD bin")
		for category in [&"pmd", &"organic", &"general"]:
			var sealed := sorting.try_seal(category)
			check(sealed.ok, "S1 seals the %s sample bin" % category)
			if sealed.ok:
				var bag_id := StringName(str(sealed.receipt.bag_id))
				var container := session.waste_containers[StringName("container:S1:%s" % category)] as WasteContainer
				if category == &"pmd":
					check(await _carry_s1_bag(sorting, container, bag_id), "S1 rack bag is carried through the hut and deposited with normal input")
				else:
					check(session.item_store.try_hold_bag(&"local", bag_id).ok and container.try_deposit_bag(&"local", bag_id).ok, "%s bag enters its real container" % category)
		var call_point := session.get_node("Beach/ServicePoints/S1/CollectionCallPoint") as CollectionCallPoint
		check(await _walk_to(sorting.global_position + Vector3(3.7, 0, 6.7), 200), "player reaches S1 collection hotline")
		player.camera.look_at(call_point.global_position + Vector3.UP)
		await _physics_frames(3)
		check(str(player.interactor.update_target().get("id", "")) == "collection:S1", "collection hotline has a normal interaction target")
		await _press_interact()
		var receipts := session.state.collection_receipts
		var receipt := receipts[0] as Dictionary if receipts.size() == 1 else {}
		check(receipts.size() == 1 and session.progress_service.completed_waste >= 7 and int((session.state.players[&"local"] as Dictionary).money) == int(receipt.get("total_pay", -1)) and int(receipt.get("total_pay", -1)) == int(receipt.get("item_count", 0)) + int(receipt.get("correct_count", 0)), "normal hotline input credits waste and pays the recorded base plus sorting bonus")
	check(session.state.validate_invariants(session.definitions).is_empty(), "catalog collection and payment preserve ownership")
	var chair_id := StringName()
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.definition_id == &"prop_beach_chair" and item.location == ItemRecord.Location.WORLD:
			chair_id = item.item_id
			player.global_position = item.last_world_transform.origin + Vector3(0, 0.5, 1.5)
			break
	check(not chair_id.is_empty() and session.item_store.try_hold(&"local", chair_id).ok, "player picks up a real large prop before pier travel")
	player.global_position = Vector3(62.5, 1.5, 34)
	player.velocity = Vector3.ZERO
	var carried_onto_pier := await _walk_lane(Vector3(62.5, 1.5, 62))
	var carried_off_pier := await _walk_lane(Vector3(62.5, 1.5, 31))
	check(carried_onto_pier and carried_off_pier and (session.state.items[chair_id] as ItemRecord).location == ItemRecord.Location.HELD, "player carries a real chair onto and off the pier")

	print("P05_TRAVERSAL waypoints=%d distance=%.1fm huts=%d shop=%d reefs=%d reef_items=%d reef_overlaps=%d catalog=%d/6 pier_carry=%d failures=%d" % [route.size(), traversed, hut_entries, int(shop_reached), int(west_reached) + int(east_reached), reef_checked, reef_overlaps + physics_overlaps, collected_new.size(), int(carried_onto_pier and carried_off_pier), failures])
	quit(failures)


func _walk_lane(target: Vector3) -> bool:
	player.look_at(target, Vector3.UP)
	_send_stick(-1.0)
	for frame in 600:
		await physics_frame
		if Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length() < 1.8:
			_send_stick(0.0)
			return true
	_send_stick(0.0)
	print("PIER_CARRY target=%s stopped=%s" % [target, player.global_position])
	for index in player.get_slide_collision_count():
		print("PIER_COLLIDER %s" % player.get_slide_collision(index).get_collider())
	return false


func _carry_s1_bag(station: SortingStation, container: WasteContainer, bag_id: StringName) -> bool:
	player.global_position = station.global_position + Vector3(0, 0.05, 7.5)
	player.velocity = Vector3.ZERO
	await _physics_frames(4)
	for point in [Vector3(0, 0, 2.3), Vector3(0.8, 0, 1.8), Vector3(2.95, 0, 1.8), Vector3(2.95, 0, -0.9)]:
		if not await _walk_to(station.global_position + point, 180):
			return false
	var view := station.bag_view_for(bag_id)
	if view == null:
		return false
	player.camera.look_at(view.global_position + Vector3.UP * 0.2)
	await _physics_frames(3)
	if str(player.interactor.update_target().get("id", "")) != str(bag_id):
		return false
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await _physics_frames(3)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await _physics_frames(2)
	if str((station.session.state.bag_records[bag_id] as Dictionary).location) != "HELD":
		return false
	for point in [Vector3(0, 0, 2.3), Vector3(0, 0, 4.2), Vector3(-1.7, 0, 5.2)]:
		if not await _walk_to(station.global_position + point, 180):
			return false
	player.camera.look_at(container.global_position + Vector3.UP * 1.2)
	await _physics_frames(3)
	if str(player.interactor.update_target().get("id", "")) != str(container.container_id):
		return false
	await _press_interact()
	return str((station.session.state.bag_records[bag_id] as Dictionary).location) == "CONTAINER"


func _walk_to(target: Vector3, max_frames: int) -> bool:
	for frame in max_frames:
		var flat := Vector3(target.x, player.global_position.y, target.z)
		player.look_at(flat, Vector3.UP)
		_send_stick(-1.0)
		await physics_frame
		if Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length() < 0.55:
			_send_stick(0.0)
			await physics_frame
			return true
	_send_stick(0.0)
	print("S1_WALK target=%s stopped=%s" % [target, player.global_position])
	return false


func _press_interact() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	await _physics_frames(3)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await _physics_frames(2)


func _collect_catalog_item(session: RunSession, definition_id: StringName) -> StringName:
	player.set_physics_process(false)
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.definition_id != definition_id or item.location != ItemRecord.Location.WORLD or item.home_zone_id not in [&"arrival", &"sports", &"lounges", &"sandplay", &"pier"]:
			continue
		var view := session.item_view_manager.view_for(item.item_id)
		if view == null:
			continue
		for offset in [Vector3(0, 0, 1.2), Vector3(1.2, 0, 0), Vector3(0, 0, -1.2), Vector3(-1.2, 0, 0)]:
			player.global_position = view.global_position + offset
			player.camera.look_at(view.global_position + Vector3.UP * 0.08)
			await physics_frame
			var aimed := player.interactor.update_target()
			if str(aimed.get("id", "")) != str(item.item_id) or not (aimed.get("actions", PackedStringArray()) as PackedStringArray).has("collect"):
				continue
			player.velocity = Vector3.ZERO
			player.set_physics_process(true)
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			Input.parse_input_event(press)
			await _physics_frames(3)
			press.pressed = false
			Input.parse_input_event(press)
			await physics_frame
			player.set_physics_process(false)
			if item.location == ItemRecord.Location.BAG:
				player.set_physics_process(true)
				return item.item_id
	player.set_physics_process(true)
	return StringName()


func _swim_lane(start: Vector3, target: Vector3) -> bool:
	var record := ((player.get_parent() as RunSession).state.players[&"local"] as Dictionary)
	record.air_remaining = 10.0
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.look_at(target, Vector3.UP)
	_send_stick(-1.0)
	for frame in 500:
		await physics_frame
		if player.global_position.distance_to(target) < 2.0:
			_send_stick(0.0)
			return true
	_send_stick(0.0)
	print("REEF_LANE start=%s target=%s stopped=%s swimming=%s" % [start, target, player.global_position, player.movement.is_swimming])
	return false


func _cross_surface(session: RunSession) -> bool:
	var record := session.state.players[&"local"] as Dictionary
	var water := session.swim_service.water
	player.global_position = Vector3(0, 0.2, 26)
	player.velocity = Vector3.ZERO
	record.air_remaining = 10.0
	player.look_at(Vector3(0, player.global_position.y, 60), Vector3.UP)
	_send_stick(-1.0)
	var swimming := false
	for frame in 500:
		await physics_frame
		if player.movement.is_swimming and player.global_position.z > 45.0:
			swimming = true
			break
	_send_stick(0.0)
	var dive := InputEventJoypadButton.new()
	dive.button_index = JOY_BUTTON_B
	dive.pressed = true
	Input.parse_input_event(dive)
	var submerged := false
	for frame in 150:
		await physics_frame
		if bool(record.immersed) and float(record.air_remaining) < 10.0:
			submerged = true
			break
	dive.pressed = false
	Input.parse_input_event(dive)
	var deep_position := player.global_position
	var rise := InputEventJoypadButton.new()
	rise.button_index = JOY_BUTTON_A
	rise.pressed = true
	Input.parse_input_event(rise)
	var surfaced := false
	for frame in 180:
		await physics_frame
		if not bool(record.immersed):
			surfaced = true
			break
	rise.pressed = false
	Input.parse_input_event(rise)
	player.look_at(Vector3(0, player.global_position.y, 20), Vector3.UP)
	_send_stick(-1.0)
	var dry := false
	for frame in 720:
		await physics_frame
		if not water.contains_horizontal(player.global_position) and not bool(record.immersed) and not player.movement.is_swimming:
			dry = true
			break
	_send_stick(0.0)
	for frame in 75:
		await physics_frame
	print("SURFACE_CROSSING swimming=%s submerged=%s at=%s surfaced=%s dry=%s at=%s air=%.2f" % [swimming, submerged, deep_position, surfaced, dry, player.global_position, float(record.air_remaining)])
	return swimming and submerged and surfaced and dry and is_equal_approx(float(record.air_remaining), 10.0)


func _send_stick(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	Input.parse_input_event(event)


func _physics_frames(count: int) -> void:
	for frame in count:
		await physics_frame


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P05 TRAVERSAL FAIL: %s" % message)
