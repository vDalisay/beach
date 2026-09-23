extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "payment-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "full playable beach starts: " + main.error_label.text)
	if session == null:
		quit(1)
		return
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	var player := session.get_node("Player") as BeachPlayer
	var call_point := session.get_node("Beach/ServicePoints/S1/CollectionCallPoint") as CollectionCallPoint
	player.global_position = call_point.global_position + Vector3(0, 0, 2.0)
	player.camera.look_at(call_point.global_position + Vector3.UP * 1.1)
	await physics_frame
	check(StringName(str(player.interactor.update_target().get("id", ""))) == &"collection:S1", "Synty collection phone is an E target")
	var empty_revision := session.state.revision
	player.interactor.request_interact()
	check(main.error_label.text == "Nothing to collect" and session.state.revision == empty_revision, "empty E call changes nothing")

	var correct: Array[StringName] = []
	var incorrect: Array[StringName] = []
	var sections: Dictionary = {}
	var keys: Array[String] = []
	for key in session.state.items:
		keys.append(str(key))
	keys.sort()
	for key in keys:
		var record := session.state.items[StringName(key)] as ItemRecord
		var definition := session.definitions[record.definition_id] as ItemDefinition
		if record.location != ItemRecord.Location.WORLD or definition.kind != ItemDefinition.Kind.WASTE:
			continue
		if definition.waste_category == ItemDefinition.WasteCategory.PMD and correct.size() < 30:
			correct.append(record.item_id)
			sections[record.home_section_id] = true
		elif definition.waste_category != ItemDefinition.WasteCategory.PMD and incorrect.size() < 20:
			incorrect.append(record.item_id)
			sections[record.home_section_id] = true
		elif correct.size() == 30 and incorrect.size() == 20 and sections.size() == 1 and not sections.has(record.home_section_id):
			if definition.waste_category == ItemDefinition.WasteCategory.PMD:
				correct[29] = record.item_id
			else:
				incorrect[19] = record.item_id
			sections[record.home_section_id] = true
		if correct.size() == 30 and incorrect.size() == 20 and sections.size() > 1:
			break
	check(correct.size() == 30 and incorrect.size() == 20 and sections.size() > 1, "50 real waste IDs span several home sections")
	var item_ids := correct + incorrect
	var changed := PackedStringArray()
	for item_id in item_ids:
		var record := session.state.items[item_id] as ItemRecord
		var cell := station.first_free_cell()
		(station.table_record().cells as Dictionary)[cell] = item_id
		record.location = ItemRecord.Location.TABLE
		record.container_id = station.station_id
		record.slot_id = cell
		changed.append(str(item_id))
	session.finalize_action(changed)
	station._contents_committed()
	check(session.progress_service.completed_waste == 0, "table ownership does not advance required waste completion")
	for item_id in item_ids:
		check(station.try_sort(item_id, &"pmd").ok, "real station sorts existing waste into declared PMD")
	check(session.progress_service.completed_waste == 0, "sorted and sealed bags do not advance required waste completion")
	var bag_id := &"bag:000001"
	check(session.state.bag_records.has(bag_id) and int((session.state.bag_records[bag_id] as Dictionary).correct_count) == 30, "50th item auto-seals with 30 correct")
	var before_deposit := session.state.revision
	check(session.item_store.try_hold_bag(&"local", bag_id).ok and container.try_deposit_bag(&"local", bag_id).ok, "rack bag travels through hands into a matching physical container")
	check(session.state.revision > before_deposit and int((session.state.players[&"local"] as Dictionary).money) == 0, "deposit itself does not pay")
	check(session.progress_service.completed_waste == 0, "container deposit still leaves required waste incomplete")
	var publication := {"snapshot": {}, "save_revision": -1}
	session.items_changed.connect(func(_ids: PackedStringArray) -> void:
		if (publication.snapshot as Dictionary).is_empty():
			publication.snapshot = session.state.to_snapshot()
	)
	session.save_requested.connect(func(revision: int) -> void: publication.save_revision = revision)
	main.clear_error()
	player.global_position = call_point.global_position + Vector3(0, 0, 2.0)
	player.camera.look_at(call_point.global_position + Vector3.UP * 1.1)
	await physics_frame
	player.interactor.update_target()
	player.interactor.request_interact()
	var receipt := session.state.collection_receipts[0] if not session.state.collection_receipts.is_empty() else {}
	check(receipt.get("item_count", -1) == 50 and receipt.get("correct_count", -1) == 30 and receipt.get("base_pay", -1) == 50 and receipt.get("bonus_pay", -1) == 30 and receipt.get("total_pay", -1) == 80, "collection pays exactly 50 + 30 = $80")
	check(int((session.state.players[&"local"] as Dictionary).money) == 80 and container.contents().is_empty(), "one collection credits wallet and empties container")
	check(main.collection_receipt.visible and main.collection_receipt.details_label.text.contains("$80"), "receipt is shown in playable UI")
	if "--capture" in OS.get_cmdline_user_args():
		main.clear_error()
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://docs/handoffs/images/P14-collection.png")
		check(root.get_texture().get_image().save_png(path) == OK, "collection screenshot saved")
		print("P14_CAPTURE " + path)
	var first_signal_snapshot := publication.snapshot as Dictionary
	check(first_signal_snapshot.get("collection_receipts", []).size() == 1 and int((first_signal_snapshot.get("players", [{}]) as Array)[0].money) == 80 and int(publication.save_revision) == session.state.revision, "first public signal and save request observe complete payment")
	var collected := 0
	for item_id in item_ids:
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.COLLECTED and record.container_id == &"collection:000001":
			collected += 1
	check(collected == 50 and (receipt.get("home_sections", {}) as Dictionary).size() > 1, "all 50 items complete without losing section provenance, even if sorted wrong")
	check(session.progress_service.completed_waste == 50 and session.progress_service.completed_props == 0, "only truck collection advances 50 waste across their home sections")
	check(session.state.validate_invariants(session.definitions).is_empty(), "collected bag, receipt and terminal item ownership remain valid")
	var loaded := RunState.from_snapshot(session.state.to_snapshot())
	check(loaded.validate_invariants(session.definitions).is_empty() and loaded.collection_receipts.size() == 1, "receipt and terminal items round-trip through snapshot")
	var repeat_revision := session.state.revision
	player.interactor.update_target()
	player.interactor.request_interact()
	check(main.error_label.text == "Nothing to collect" and session.state.revision == repeat_revision and int((session.state.players[&"local"] as Dictionary).money) == 80, "repeat E call cannot pay twice")
	print("P14_PAYMENT count=%d correct=%d base=%d bonus=%d total=%d collected=%d sections=%d failures=%d" % [receipt.get("item_count", -1), receipt.get("correct_count", -1), receipt.get("base_pay", -1), receipt.get("bonus_pay", -1), receipt.get("total_pay", -1), collected, sections.size(), failures])
	main.free()
	quit(failures)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P14 FAIL: " + message)
