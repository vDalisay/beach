extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := (load("res://tests/scenes/physics_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	var generator := ManifestGenerator.new()
	var definitions := generator.load_catalog()
	var state := _fixture_state()
	var session := RunSession.new()
	session.initialize(state, definitions)
	lab.add_child(session)
	var manager := ItemViewManager.new()
	session.add_child(manager)
	session.item_view_manager = manager
	manager.configure(session, definitions, {&"recovery:lab": Vector3(0, 0.05, 8)})
	manager.build_views()
	await _physics_frames(3)
	check(manager.views.size() == state.items.size(), "fixture creates one view per WORLD record")
	check((manager.view_for(&"tiny:can").collision_layer & 8) == 0, "tiny litter does not block the player layer")
	check((manager.view_for(&"large:chair").collision_layer & 8) != 0, "large furniture exposes player-blocking collision")
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as BeachPlayer
	lab.add_child(player)
	player.set_input_enabled(false)
	player.global_position = Vector3(-8, 0, -2)
	await _physics_frames(2)
	var player_hit := player.move_and_collide(Vector3(4, 0, 0))
	check(player.global_position.x > -7.0 and player_hit != null and player_hit.get_collider() == manager.view_for(&"large:chair"), "player passes tiny litter but is blocked by large furniture")
	player.free()

	var can_start := manager.view_for(&"throw:can").global_position
	var ball_start := manager.view_for(&"throw:ball").global_position
	var chair_start := manager.view_for(&"throw:chair").global_position
	manager.throw_item(&"throw:can", Transform3D(Basis.IDENTITY, can_start), Vector3(2.8, 2.3, 0))
	manager.throw_item(&"throw:ball", Transform3D(Basis.IDENTITY, ball_start), Vector3(2.4, 2.0, 0))
	manager.throw_item(&"throw:chair", Transform3D(Basis.IDENTITY, chair_start), Vector3(8.0, 3.0, 0))
	manager.throw_item(&"impact:a", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Vector3(3.8, 0.2, 0))
	manager.activate_item(&"impact:b")
	await _physics_frames(24)
	check(manager.view_for(&"throw:can").global_position.distance_to(can_start) > 0.2, "can throw advances through physics")
	check(manager.view_for(&"throw:ball").global_position.distance_to(ball_start) > 0.2, "ball throw advances through physics")
	check(manager.view_for(&"throw:chair").global_position.distance_to(chair_start) > 0.2, "chair throw advances through physics")
	check(manager.view_for(&"impact:b").global_position.x > 1.55, "active items transfer motion on collision")

	await manager.synchronize_at_physics_boundary()
	var moving_record := state.items[&"throw:can"] as ItemRecord
	check(moving_record.last_world_transform.origin.distance_to(can_start) > 0.2 and moving_record.linear_velocity.length() > 0.01, "moving snapshot captures advanced pose and velocity")
	var moving_snapshot := JSON.parse_string(JSON.stringify(state.to_snapshot())) as Dictionary
	var restored_state := RunState.from_snapshot(moving_snapshot)
	var restored_session := RunSession.new()
	restored_session.initialize(restored_state, definitions)
	lab.add_child(restored_session)
	var restored_manager := ItemViewManager.new()
	restored_session.add_child(restored_manager)
	restored_manager.configure(restored_session, definitions, {&"recovery:lab": Vector3(0, 0.05, 8)})
	manager.queue_free()
	await process_frame
	restored_manager.build_views()
	await _physics_frames(2)
	var restored_can := restored_manager.view_for(&"throw:can")
	var captured_can := restored_state.items[&"throw:can"] as ItemRecord
	check(restored_can.global_position.distance_to(captured_can.last_world_transform.origin) < 0.15, "restored moving body starts at captured pose, not launch pose")

	for item_id in [&"pile:1", &"pile:2", &"pile:3", &"pile:4"]:
		restored_manager.activate_item(item_id).apply_throw(Vector3(0.08, 0.12, 0.03))
	await _physics_frames(360)
	var pile_sleeping := true
	for item_id in [&"pile:1", &"pile:2", &"pile:3", &"pile:4"]:
		var pile_view := restored_manager.view_for(item_id)
		pile_sleeping = pile_sleeping and pile_view.sleeping
	check(pile_sleeping, "supported pile wakes and returns to sleep")
	await restored_manager.synchronize_at_physics_boundary()
	var resting_snapshot := JSON.parse_string(JSON.stringify(restored_state.to_snapshot())) as Dictionary
	var resting_can := ItemRecord.from_snapshot((resting_snapshot.items as Array).filter(func(row: Dictionary) -> bool: return row.item_id == "throw:can")[0])
	check(resting_can.last_world_transform.origin.distance_to(can_start) > 0.2, "resting snapshot retains the final physics pose")

	var count_before := restored_state.items.size()
	var required_before := restored_state.required_total
	var money_before := int((restored_state.players[&"local"] as Dictionary).money)
	var recovery_view := restored_manager.view_for(&"recover:item")
	recovery_view.global_position = Vector3(0, -20, 0)
	recovery_view.activate()
	await _physics_frames(3)
	var recovered := restored_state.items[&"recover:item"] as ItemRecord
	check(restored_state.items.size() == count_before and restored_state.required_total == required_before, "recovery preserves stable ID and objective counts")
	check(int((restored_state.players[&"local"] as Dictionary).money) == money_before, "recovery never pays")
	check(recovered.location == ItemRecord.Location.WORLD and recovered.last_world_transform.origin.distance_to(Vector3(0, 0.05, 8)) < 7.0, "out-of-bounds item returns to a clear authored anchor")
	check(restored_state.validate_invariants(definitions).is_empty(), "physics and recovery preserve domain invariants")

	lab.free()
	await process_frame
	await _measure_full_scale()
	print("P07_PHYSICS_RECOVERY failures=%d" % failures)
	quit(failures)


func _measure_full_scale() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	await process_frame
	var session := main.start_run() as RunSession
	await _physics_frames(5)
	var manager := session.item_view_manager
	var player := session.get_node("Player") as BeachPlayer
	if "--c04-dense" in OS.get_cmdline_user_args():
		player.global_position = Vector3(-17, 2.1, 24)
		player.camera.look_at(Vector3(-17, 1.7, -18))
		await _physics_frames(90)
	elif "--c06-water" in OS.get_cmdline_user_args():
		player.set_physics_process(false)
		session.swim_service.set_physics_process(false)
		player.global_position = Vector3(0, 2.1, 45)
		player.camera.look_at(Vector3(0, 0, 180))
		await _physics_frames(90)
	var initial_world_count := 0
	for value in session.state.items.values():
		if (value as ItemRecord).location == ItemRecord.Location.WORLD:
			initial_world_count += 1
	var largest_pile := 0
	var pile_counts := {}
	for row_value in session.state.initial_manifest:
		var pile_id := str((row_value as Dictionary).pile_id)
		if not pile_id.is_empty():
			pile_counts[pile_id] = int(pile_counts.get(pile_id, 0)) + 1
	for pile_id in pile_counts:
		largest_pile = maxi(largest_pile, int(pile_counts[pile_id]))
	var memory_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)
	var frame_samples: Array[float] = []
	var physics_samples: Array[float] = []
	var max_draw_calls := 0
	var max_active_bodies := 0
	var previous_tick := Time.get_ticks_usec()
	var sample_frames := 600 if "--profile" in OS.get_cmdline_user_args() else 120
	for _index in sample_frames:
		await process_frame
		var current_tick := Time.get_ticks_usec()
		frame_samples.append(float(current_tick - previous_tick) / 1000.0)
		previous_tick = current_tick
		physics_samples.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		max_draw_calls = maxi(max_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		max_active_bodies = maxi(max_active_bodies, int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)))
	frame_samples.sort()
	physics_samples.sort()
	var frame_average := _average(frame_samples)
	var physics_average := _average(physics_samples)
	var frame_p95 := frame_samples[int(floor((frame_samples.size() - 1) * 0.95))]
	var video_mb := float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / (1024.0 * 1024.0)
	print("P07_SCALE frames=%d views=%d batches=%d batch_items=%d awake=%d meshes=%d largest_pile=%d build_ms=%.1f memory_mb=%.1f video_mb=%.1f nodes=%d frame_avg_ms=%.2f frame_p95_ms=%.2f physics_avg_ms=%.2f draw_calls_max=%d active_bodies_max=%d" % [sample_frames, manager.views.size(), manager.distant_visuals.batch_count(), manager.distant_visuals.instance_count(), manager.awake_count(), manager.visual_instance_count(), largest_pile, manager.build_time_ms, memory_mb, video_mb, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), frame_average, frame_p95, physics_average, max_draw_calls, max_active_bodies])
	print("P07_DEVICE os=%s cpu=%s gpu=%s" % [OS.get_name(), OS.get_processor_name(), RenderingServer.get_video_adapter_name()])
	if "--c04-dense" in OS.get_cmdline_user_args() or "--c06-water" in OS.get_cmdline_user_args():
		main.free()
		quit(failures)
		return
	var world_count := 0
	var missing_near := 0
	var distant_target: ItemRecord
	for value in session.state.items.values():
		var record := value as ItemRecord
		if record.location != ItemRecord.Location.WORLD:
			continue
		world_count += 1
		var distance := Vector2(record.last_world_transform.origin.x, record.last_world_transform.origin.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
		if distance < 30.0 and not manager.views.has(record.item_id):
			if not manager.distant_visuals.is_item_visible(record.item_id) or distance < 8.0:
				missing_near += 1
		if distance > 120.0 and not manager.views.has(record.item_id) and manager.distant_visuals.is_item_visible(record.item_id):
			distant_target = record
	check(world_count == initial_world_count and session.state.items.size() == 5740 and manager.views.size() < world_count and missing_near == 0, "all WORLD records persist while only nearby visible objects have views")
	var worst_walk_gap := 0
	for step in 6:
		player.global_position.x += 3.5
		await create_timer(1.0).timeout
		var walk_gap := 0
		for value in session.state.items.values():
			var record := value as ItemRecord
			if record.location == ItemRecord.Location.WORLD and not manager.views.has(record.item_id):
				var distance := Vector2(record.last_world_transform.origin.x, record.last_world_transform.origin.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
				if distance < 30.0 and (not manager.distant_visuals.is_item_visible(record.item_id) or distance < 8.0):
					walk_gap += 1
		worst_walk_gap = maxi(worst_walk_gap, walk_gap)
	print("P07_STREAM walk_missing_max=%d" % worst_walk_gap)
	check(worst_walk_gap == 0, "walking through the compact litter field keeps nearby physical views loaded")
	var pickup_id := StringName()
	for item_id in manager.views:
		var candidate := session.state.items[item_id] as ItemRecord
		var definition := session.definitions[candidate.definition_id] as ItemDefinition
		if manager.distant_visuals.has_item(item_id) and definition.kind == ItemDefinition.Kind.WASTE and definition.required_tool.is_empty():
			pickup_id = item_id
			break
	check(not pickup_id.is_empty(), "batched Synty waste is physically available near the player")
	if not pickup_id.is_empty():
		var pickup := session.item_store.try_collect(&"local", pickup_id)
		await _physics_frames(2)
		check(pickup.ok and (session.state.items[pickup_id] as ItemRecord).location == ItemRecord.Location.BAG and not manager.views.has(pickup_id) and not manager.distant_visuals.is_item_visible(pickup_id) and session.state.validate_invariants(session.definitions).is_empty(), "collecting a batched item removes both world presentations without losing ownership")
	check(manager.awake_count() == 0, "full layout starts asleep")
	check(largest_pile <= 6, "largest authored pile stays within a stable layer pattern")
	if "--capture" in OS.get_cmdline_user_args():
		var image := root.get_texture().get_image()
		var capture_path := ProjectSettings.globalize_path("res://docs/handoffs/images/P07-full-layout.png")
		check(image.save_png(capture_path) == OK, "full-layout evidence capture saves")
		print("P07_CAPTURE %s" % capture_path)
	check(distant_target != null, "a distant resting litter record can be streamed")
	if distant_target != null:
		var return_pose := player.global_transform
		var position := distant_target.last_world_transform.origin
		player.global_position = Vector3(position.x, 0.05, position.z)
		for _index in range(360):
			await process_frame
			if manager.views.has(distant_target.item_id):
				break
		check(manager.views.has(distant_target.item_id) and not manager.distant_visuals.is_item_visible(distant_target.item_id), "approaching a distant Synty instance promotes one physical view")
		player.global_transform = return_pose
		await create_timer(0.6).timeout
		check(not manager.views.has(distant_target.item_id) and manager.distant_visuals.is_item_visible(distant_target.item_id) and distant_target.location == ItemRecord.Location.WORLD and session.state.validate_invariants(session.definitions).is_empty(), "leaving a resting view restores its Synty batch instance without losing ID or save ownership")
	main.free()


func _fixture_state() -> RunState:
	var state := RunState.new()
	state.run_id = "physics-lab"
	state.add_player()
	_add_record(state, &"tiny:can", &"waste_can", Vector3(-7, 0.05, -2))
	_add_record(state, &"large:chair", &"prop_beach_chair", Vector3(-5, 0.05, -2))
	_add_record(state, &"throw:can", &"waste_can", Vector3(-6, 0.05, 0))
	_add_record(state, &"throw:ball", &"prop_beach_ball", Vector3(-4, 0.05, 0))
	_add_record(state, &"throw:chair", &"prop_beach_chair", Vector3(-2, 0.05, 0))
	_add_record(state, &"impact:a", &"waste_can", Vector3(0, 0.05, 0))
	_add_record(state, &"impact:b", &"waste_can", Vector3(1.5, 0.05, 0))
	_add_record(state, &"recover:item", &"waste_can", Vector3(5, 0.05, 0))
	_add_record(state, &"pile:1", &"waste_can", Vector3(-0.24, 0.05, 4))
	_add_record(state, &"pile:2", &"waste_can", Vector3(0.24, 0.05, 4))
	_add_record(state, &"pile:3", &"waste_can", Vector3(-0.12, 0.23, 4))
	_add_record(state, &"pile:4", &"waste_can", Vector3(0.12, 0.23, 4))
	return state


func _add_record(state: RunState, item_id: StringName, definition_id: StringName, position: Vector3) -> void:
	var record := ItemRecord.new()
	record.item_id = item_id
	record.definition_id = definition_id
	record.home_section_id = &"physics:lab"
	record.home_zone_id = &"physics"
	record.last_world_transform = Transform3D(Basis.IDENTITY, position)
	record.sleeping = true
	state.add_item(record)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P07 FAIL: %s" % message)
