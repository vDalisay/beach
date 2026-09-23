extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/p24"
	main.seed_input.text = "save-physics"
	var session := main.start_run() as RunSession
	var run_id := session.state.run_id
	var player := session.get_node("Player") as BeachPlayer
	var bottle: ItemRecord
	var chair: ItemRecord
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.location == ItemRecord.Location.WORLD and item.definition_id == &"waste_plastic_bottle" and bottle == null:
			bottle = item
		if item.location == ItemRecord.Location.WORLD and item.definition_id == &"prop_beach_chair" and chair == null:
			chair = item
	check(bottle != null and chair != null, "Synty bottle and chair fixture exists")
	check(session.item_store.try_collect(&"local", bottle.item_id).ok, "bottle collected")
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	check(station.try_unload(&"local").ok and station.try_sort(bottle.item_id, &"pmd").ok, "bottle sorted")
	var sealed := station.try_seal(&"pmd")
	check(sealed.ok, "bag sealed")
	var bag_id := StringName(str(sealed.receipt.get("bag_id", "")))
	check(session.item_store.try_hold_bag(&"local", bag_id).ok, "bag held")
	var launch := Transform3D(Basis.IDENTITY, player.global_position + Vector3(0, 2, -2))
	check(session.item_store.try_throw(&"local", launch, Vector3(0, 1.5, -2)).ok, "bag thrown")
	print("P24_PHYSICS bag thrown")
	check(session.item_store.try_hold(&"local", chair.item_id).ok, "chair held")
	check(session.item_store.try_throw(&"local", launch.translated(Vector3.RIGHT), Vector3(1, 2, -1)).ok, "chair thrown")
	session.item_view_manager.restore_world_view(chair.item_id)
	print("P24_PHYSICS chair thrown")
	await physics_frame
	await physics_frame
	var bag_view := station.bag_view_for(bag_id)
	var chair_view := session.item_view_manager.view_for(chair.item_id)
	check(bag_view != null and chair_view != null, "moving objects have physical views")
	check(bool(main.save_service.save_slot(&"manual").ok), "moving bodies saved")
	var flight := main.save_service.load_slot(&"beach_01", run_id, &"manual")
	check(bool(flight.ok), "moving-body save validates")
	if bool(flight.ok):
		var flight_state := flight.state as RunState
		check(ItemRecord._array_to_transform((flight_state.bag_records[bag_id] as Dictionary).world_transform as Array).origin.distance_to(bag_view.global_position) < 0.01, "bag captured at current pose")
		check((flight_state.items[chair.item_id] as ItemRecord).last_world_transform.origin.distance_to(chair_view.global_position) < 0.01, "chair captured at current pose")
	var opened := main.load_run(run_id, &"manual")
	check(bool(opened.ok), "moving bodies reload")
	session = main.run_root as RunSession
	station = session.sorting_stations[&"sorting:S1"] as SortingStation
	bag_view = station.bag_view_for(bag_id)
	chair_view = session.item_view_manager.view_for(chair.item_id)
	check(bag_view != null and chair_view != null and session.state.validate_invariants(session.definitions).is_empty(), "reloaded bodies and ownership are valid")
	bag_view.freeze = true
	bag_view.sleeping = true
	chair_view.freeze_view()
	check(bool(main.save_service.save_slot(&"manual").ok), "settled bodies saved")
	var settled := main.save_service.load_slot(&"beach_01", run_id, &"manual")
	if bool(settled.ok):
		var settled_state := settled.state as RunState
		check(bool((settled_state.bag_records[bag_id] as Dictionary).sleeping) and (settled_state.items[chair.item_id] as ItemRecord).sleeping, "settled sleep state roundtrips")
	else:
		check(false, "settled save validates")
	player = session.get_node("Player") as BeachPlayer
	check(session.item_store.try_hold_bag(&"local", bag_id).ok, "world bag recovered")
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	check(container.try_deposit_bag(&"local", bag_id).ok and session.collection_service.try_collect_containers(&"local").ok, "truck collects sealed bag and pays")
	await physics_frame
	await process_frame
	var autosave := main.save_service.load_slot(&"beach_01", run_id, &"autosave")
	check(bool(autosave.ok) and (autosave.state as RunState).collection_receipts.size() == 1 and (autosave.state as RunState).items[bottle.item_id].location == ItemRecord.Location.COLLECTED, "collection autosave includes receipt and terminal item")
	var can: ItemRecord
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.location == ItemRecord.Location.WORLD and item.definition_id == &"waste_can":
			can = item
			break
	check(can != null and session.item_store.try_collect(&"local", can.item_id).ok, "can carried into faint")
	var swim := session.swim_service
	swim.set_physics_process(false)
	player.global_position = Vector3(0, -2, 80)
	swim.step_environment(0.05)
	(session.state.players[&"local"] as Dictionary).air_remaining = 0.0
	check((await swim.try_faint()).ok and session.state.recovery_piles.size() == 1, "faint commits a recoverable pile")
	check(bool(main.save_service.save_slot(&"manual").ok), "post-faint run saved")
	var faint_save := main.save_service.load_slot(&"beach_01", run_id, &"manual")
	check(bool(faint_save.ok) and (faint_save.state as RunState).recovery_piles.size() == 1, "faint pile survives disk roundtrip")
	opened = main.load_run(run_id, &"manual")
	session = main.run_root as RunSession
	check(bool(opened.ok) and session.state.recovery_piles.size() == 1 and session.swim_service._markers.size() == 1, "faint recovery marker rebuilds in loaded beach")
	check(session.item_store.try_collect(&"local", can.item_id).ok and session.state.recovery_piles.is_empty() and session.swim_service._markers.is_empty(), "recovering dropped item retires marker")
	check(bool(main.save_service.save_slot(&"broken").ok) and bool(main.save_service.save_slot(&"broken").ok), "separate damaged-load slot prepared")
	var broken_folder := main.save_service.save_root.path_join("beach_01").path_join(run_id).path_join("broken")
	for generation_name in ["A.json", "B.json"]:
		var broken := FileAccess.open(broken_folder.path_join(generation_name), FileAccess.WRITE)
		if broken != null:
			broken.store_string("broken")
			broken.close()
	var live_root := main.run_root
	check(not bool(main.load_run(run_id, &"broken").ok) and main.run_root == live_root and main.error_panel.visible, "failed load preserves live run and shows error")
	main.free()
	print("P24_SAVE_PHYSICS flight=1 settled=1 collection=1 faint=1 failures=%d" % failures)
	quit(failures)


func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("P24 FAIL: " + label)
