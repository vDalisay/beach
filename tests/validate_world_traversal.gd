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
		player.global_position = service + Vector3(0, 0.05, 5)
		player.velocity = Vector3.ZERO
		player.look_at(Vector3(service.x, player.global_position.y, service.z), Vector3.UP)
		_send_stick(-1.0)
		await _physics_frames(80)
		_send_stick(0.0)
		var local := player.global_position - service
		if absf(local.x) < 1.2 and local.z < 2.7 and local.z > -2.6:
			hut_entries += 1
	check(hut_entries == 3, "controller enters all three service huts through the carry-width doors")
	var beach := main.run_root.get_node("Beach") as Node3D
	for rock_name in ["ReefRock01", "ReefRock13"]:
		var rock := beach.get_node("Terrain/ReefDressing/%s" % rock_name) as StaticBody3D
		var origin := rock.global_position
		var hit := beach.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(origin.x, 0, origin.z), Vector3(origin.x, -5, origin.z)))
		check(hit.get("collider") == rock, "%s has a solid elevated reef surface" % rock_name)
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

	print("P05_TRAVERSAL waypoints=%d distance=%.1fm huts=%d reefs=%d reef_items=%d reef_overlaps=%d pier_carry=%d failures=%d" % [route.size(), traversed, hut_entries, int(west_reached) + int(east_reached), reef_checked, reef_overlaps + physics_overlaps, int(carried_onto_pier and carried_off_pier), failures])
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
