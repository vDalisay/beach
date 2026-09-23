extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "sealing-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "full beach run starts")
	if session == null:
		quit(1)
		return
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	var player := session.get_node("Player") as BeachPlayer
	var player_record := session.state.players[&"local"] as Dictionary
	player_record.bag_capacity = 200
	var candidates: Array[StringName] = []
	var ids: Array[String] = []
	for item_key in session.state.items:
		ids.append(str(item_key))
	ids.sort()
	for item_text in ids:
		var record := session.state.items[StringName(item_text)] as ItemRecord
		var definition := session.definitions[record.definition_id] as ItemDefinition
		if record.location == ItemRecord.Location.WORLD and definition.kind == ItemDefinition.Kind.WASTE and definition.required_tool.is_empty():
			candidates.append(record.item_id)
			if candidates.size() == 504:
				break
	check(candidates.size() == 504, "live manifest supplies real waste IDs for rack saturation")
	check(session.item_store.try_collect(&"local", candidates[0]).ok and station.try_unload(&"local").ok, "first real waste item reaches the table through bag unload")
	check(not station.try_seal(&"organic").ok, "empty manual seal is rejected")
	check(station.try_sort(candidates[0], &"pmd").ok, "one table item enters a bin")
	station.enter()
	check(main.sorting_view.seal_button.visible and not main.sorting_view.seal_button.disabled, "visible Seal button enables for a nonempty bin")
	main.sorting_view.seal_button.pressed.emit()
	station.exit()
	var bag_one := &"bag:000001"
	check(session.state.bag_records.has(bag_one) and (session.state.bag_records[bag_one] as Dictionary).item_ids == [candidates[0]] and (session.state.items[candidates[0]] as ItemRecord).location == ItemRecord.Location.SEALED and station.bag_view_for(bag_one) != null, "one-item UI seal preserves original ID in a physical rack bag")
	check(session.item_store.try_collect(&"local", candidates[1]).ok and station.try_unload(&"local").ok and station.try_sort(candidates[1], &"glass").ok, "second existing item reaches glass bin")
	var second_seal := station.try_seal(&"glass")
	var bag_two := StringName(str(second_seal.receipt.get("bag_id", "")))
	check(second_seal.ok and station.bag_view_for(bag_two) != null, "second distinct category bag occupies another rack slot")
	check(session.item_store.try_hold_bag(&"local", bag_one).ok and session.item_store.try_hold_bag(&"local", bag_two).ok and (player_record.held_objects as Array).size() == 2, "two sealed bags each use one hand")
	player.carry.refresh_hand_visuals()
	check(_count_bag_visuals(player.hand_rig) == 2, "both held disposal bags have labelled hand visuals")
	player.global_position = station.global_position + Vector3(0, 0, 7.0)
	player.camera.look_at(player.global_position + Vector3(0, 1.65, 10))
	await _physics_frames(2)
	player.interactor.request_throw()
	await _physics_frames(2)
	check(str((session.state.bag_records[bag_two] as Dictionary).location) == "WORLD" and station.bag_view_for(bag_two) != null and (player_record.held_objects as Array).size() == 1, "world throw is LIFO and leaves the other sealed bag held")
	var world_view := station.bag_view_for(bag_two)
	world_view.global_position = Vector3(500, -20, 300)
	await _physics_frames(3)
	var recovered := session.state.bag_records[bag_two] as Dictionary
	check(str(recovered.location) == "WORLD" and not session.item_view_manager.recovery_bounds.is_outside((station.bag_view_for(bag_two) as DisposalBag).global_position) and recovered.item_ids == [candidates[1]], "out-of-bounds bag recovers with the same identity and sealed contents")
	check(session.item_store.try_hold_bag(&"local", bag_two).ok, "recovered bag can be picked up")
	var pmd_container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	var glass_container := session.waste_containers[&"container:S1:glass"] as WasteContainer
	var wrong := pmd_container.try_deposit_bag(&"local", bag_two)
	check(not wrong.ok and wrong.reason == ActionResult.Reason.INVALID_CATEGORY and str((session.state.bag_records[bag_two] as Dictionary).location) == "HELD", "mismatched container rejects without losing the carried bag")
	check(glass_container.try_deposit_bag(&"local", bag_two).ok and bag_two in glass_container.contents(), "matching container accepts a carried sealed bag")
	check(glass_container.try_take_last_bag(&"local").ok and str((session.state.bag_records[bag_two] as Dictionary).location) == "HELD", "uncollected container bag remains retrievable")
	check(pmd_container.try_deposit_bag(&"local", bag_one).ok, "first bag deposits to its matching category")
	var opening := glass_container.opening
	var drop_pose := Transform3D(Basis.IDENTITY, opening.global_position + Vector3.UP * 0.7)
	check(session.item_store.try_throw(&"local", drop_pose, Vector3.DOWN * 4.0).ok, "retrieved glass bag begins real downward container throw")
	await _physics_frames(12)
	check(str((session.state.bag_records[bag_two] as Dictionary).location) == "CONTAINER" and bag_two in glass_container.contents(), "physical opening deposits the same glass bag without payment")
	if "--capture" in OS.get_cmdline_user_args():
		main.clear_error()
		player.global_position = station.global_position + Vector3(0, 0, 11)
		player.camera.look_at(station.global_position + Vector3(0, 1.0, 5.2))
		await _capture("P13-containers.png")

	_stage_table(session, station, candidates.slice(2, 202))
	await _physics_frames(2)
	for category in SortingStation.CATEGORIES:
		_sort_first_cells(station, 50, category)
	check((station.rack_record().slots as Dictionary).size() == 4 and session.state.bag_records.size() == 6, "four threshold seals each create one new 50-item bag")
	var sample := session.state.bag_records[&"bag:000003"] as Dictionary
	print("P13_BAG_SAMPLE id=%s category=%s total=%d correct=%d location=%s" % [str(sample.bag_id), str(sample.category), (sample.item_ids as Array).size(), int(sample.correct_count), str(sample.location)])
	_stage_table(session, station, candidates.slice(202, 402))
	await _physics_frames(2)
	for category in SortingStation.CATEGORIES:
		_sort_first_cells(station, 50, category)
	check((station.rack_record().slots as Dictionary).size() == 8, "output rack holds exactly eight physical bags")
	if "--capture" in OS.get_cmdline_user_args():
		main.clear_error()
		player.global_position = station.global_position + Vector3(1.2, 0, 2.7)
		player.camera.look_at(station.global_position + Vector3(3.1, 1.1, -0.1))
		await _capture("P13-rack-full.png")
	_stage_table(session, station, candidates.slice(402, 504))
	await _physics_frames(2)
	_sort_first_cells(station, 50, &"pmd")
	_sort_first_cells(station, 50, &"organic")
	_sort_first_cells(station, 1, &"general")
	var overflow_item := station.item_at(101)
	var blocked := station.try_sort(overflow_item, &"pmd")
	check(not blocked.ok and blocked.reason == ActionResult.Reason.CAPACITY and (station.bin_record(&"pmd").items as Array).size() == 50 and (station.bin_record(&"organic").items as Array).size() == 50 and (session.state.items[overflow_item] as ItemRecord).location == ItemRecord.Location.TABLE, "full rack leaves full bins waiting and rejects item 51 unchanged")
	check(not station.try_seal(&"general").ok and (station.bin_record(&"general").items as Array).size() == 1, "full rack rejects partial manual seal intact")
	var rack_slots := station.rack_record().slots as Dictionary
	var first_rack_bag := StringName(str(rack_slots[0]))
	check(session.item_store.try_hold_bag(&"local", first_rack_bag).ok, "taking a rack bag frees one output position")
	check((station.bin_record(&"pmd").items as Array).is_empty() and (station.bin_record(&"organic").items as Array).size() == 50 and rack_slots.size() == 8, "first waiting full bin seals immediately in PMD-first order")
	var organic_item := StringName(str((station.bin_record(&"organic").items as Array).back()))
	check(station.try_unsort(organic_item).ok and (station.bin_record(&"organic").items as Array).size() == 49, "correcting a waiting full bin drops it below threshold")
	var second_rack_bag := StringName(str(rack_slots[1]))
	check(session.item_store.try_hold_bag(&"local", second_rack_bag).ok and rack_slots.size() == 7 and (station.bin_record(&"organic").items as Array).size() == 49, "next rack release does not seal a corrected 49-item bin")
	var partial := station.try_seal(&"organic")
	check(partial.ok and int(partial.receipt.count) == 49 and rack_slots.size() == 8, "explicit manual seal handles a partial nonempty bin")
	check(int(player_record.money) == 0 and (session.state.items[candidates[0]] as ItemRecord).location == ItemRecord.Location.SEALED and session.state.required_total == 5700, "transport and sorting neither pay nor complete waste")
	check(session.state.validate_invariants(session.definitions).is_empty(), "rack, hands, world bags, containers and sealed item owners remain unique")
	var loaded := RunState.from_snapshot(session.state.to_snapshot())
	check(loaded.validate_invariants(session.definitions).is_empty() and loaded.bag_records.size() == session.state.bag_records.size(), "snapshot round-trip preserves exact bag/item/rack ownership")
	print("P13_SEAL manual=1+49 auto=8 rack=8 waiting=ordered bags=held/world/container/recovered failures=%d" % failures)
	main.free()
	quit(failures)


func _stage_table(session: RunSession, station: SortingStation, item_ids: Array[StringName]) -> void:
	var changed := PackedStringArray()
	for item_id in item_ids:
		var record := session.state.items[item_id] as ItemRecord
		check(record.location == ItemRecord.Location.WORLD, "fixture stages only existing WORLD waste")
		var cell := station.first_free_cell()
		(station.table_record().cells as Dictionary)[cell] = item_id
		record.location = ItemRecord.Location.TABLE
		record.container_id = station.station_id
		record.slot_id = cell
		changed.append(str(item_id))
	session.finalize_action(changed)
	station._contents_committed()


func _sort_first_cells(station: SortingStation, count: int, category: StringName) -> void:
	for _index in range(count):
		var item_id := StringName()
		for cell_index in range(SortingStation.CELL_COUNT):
			item_id = station.item_at(cell_index)
			if not item_id.is_empty():
				break
		check(not item_id.is_empty() and station.try_sort(item_id, category).ok, "actual station sorts staged item into %s" % category)


func _count_bag_visuals(node: Node) -> int:
	var count := 1 if node is DisposalBag else 0
	for child in node.get_children():
		count += _count_bag_visuals(child)
	return count


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "bag evidence capture saves: %s" % filename)
	print("P13_CAPTURE %s" % path)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P13 FAIL: %s" % message)
