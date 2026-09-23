extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/review_20260923"
	main.seed_input.text = "review-20260923"
	var session := main.start_run() as RunSession
	var player := session.get_node("Player") as BeachPlayer
	player.set_physics_process(false)
	session.swim_service.set_physics_process(false)
	session.vacuum_tool.set_physics_process(false)
	session.metal_detector.set_physics_process(false)
	var record := session.state.players[&"local"] as Dictionary
	var bucket: ItemRecord
	var buried: ItemRecord
	var rescued: ItemRecord
	var waste: ItemRecord
	var valuable: ItemRecord
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.definition_id == &"prop_bucket" and bucket == null: bucket = item
		if item.definition_id == &"waste_buried_metal" and buried == null: buried = item
		if item.definition_id == &"waste_rescue_ring" and rescued == null: rescued = item
		if item.definition_id == &"waste_can" and item.location == ItemRecord.Location.WORLD and waste == null: waste = item
		if item.definition_id == &"valuable_keys" and valuable == null: valuable = item
	for tool in [&"stick", &"cloth", &"sand_cleaner", &"vacuum", &"detector", &"knife"]:
		await pose(session, player, bucket)
		equip(record, tool)
		var target := player.interactor.update_target()
		await click(player)
		print("REVIEW_PROP tool=%s correct_target=%s actions=%s held=%s" % [tool, str(target.get("id", "")) == str(bucket.item_id), target.get("actions", []), bucket.location == ItemRecord.Location.HELD])
		if bucket.location == ItemRecord.Location.HELD:
			session.item_store.try_throw(&"local", Transform3D(Basis.IDENTITY, Vector3(-74, 10, 4.6)), Vector3.ZERO)
			player.carry.cancel_all_presentations()
	for item in [buried, rescued, valuable]:
		await pose(session, player, item)
		item.buried = false
		item.revealed = true
		for tool in [&"stick", (session.definitions[item.definition_id] as ItemDefinition).required_tool]:
			equip(record, tool)
			var target := player.interactor.update_target()
			await click(player)
			print("REVIEW_PICKUP definition=%s tool=%s correct_target=%s actions=%s reason=%s location=%s" % [item.definition_id, tool, str(target.get("id", "")) == str(item.item_id), target.get("actions", []), target.get("reason", ""), ItemRecord.LOCATION_NAMES[item.location]])
	# Both inventories share bag capacity, but throw chooses waste first.
	equip(record, &"stick")
	var a := session.item_store.try_collect(&"local", waste.item_id)
	equip(record, &"detector")
	var b := session.item_store.try_collect(&"local", valuable.item_id)
	print("REVIEW_LIFO collect_waste=%s collect_valuable=%s expected=%s actual=%s" % [a.ok, b.ok, valuable.item_id, session.item_store.peek_throw_item(&"local")])
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	station.enter()
	var view := main.sorting_view
	view.unload_button.grab_focus()
	await joy(JOY_BUTTON_A)
	print("REVIEW_TABLE focused_unload=%s bag_after_A=%d table_cells=%d hint=%s" % [view.unload_button.has_focus(), record.trash_bag.size(), station.table_record().cells.size(), view.hint.text])
	station.try_unload(&"local")
	station.try_sort(waste.item_id, &"pmd")
	view.seal_button.grab_focus()
	await joy(JOY_BUTTON_A)
	print("REVIEW_TABLE focused_seal=%s bin_after_A=%d bags=%d hint=%s" % [view.seal_button.has_focus(), station.bin_record(&"pmd").items.size(), session.state.bag_records.size(), view.hint.text])
	await joy(JOY_BUTTON_START)
	print("REVIEW_TABLE start_opens_pause=%s sorting_active=%s" % [main.pause_menu.visible, station.active])
	main.free()
	quit()

func pose(session: RunSession, player: BeachPlayer, item: ItemRecord) -> void:
	item.location = ItemRecord.Location.WORLD
	item.last_world_transform = Transform3D(Basis.IDENTITY, Vector3(-74, 10, 4.6))
	item.holder_id = &""
	session.item_view_manager.restore_world_view(item.item_id)
	for prior in session.item_view_manager.views.values():
		if prior is WorldItem and prior.item_id != item.item_id and prior.global_position.y > 8:
			prior.global_position.x += 8
	var view := session.item_view_manager.view_for(item.item_id)
	view.freeze = true
	view.global_transform = item.last_world_transform
	player.global_position = Vector3(-74, 9.9, 6)
	player.velocity = Vector3.ZERO
	player.camera.look_at(view.global_position + Vector3.UP * 0.1)
	await physics_frame
	await physics_frame

func equip(record: Dictionary, tool: StringName) -> void:
	if tool not in record.owned_tools: record.owned_tools.append(tool)
	record.equipped_handheld_ids = [tool] as Array[StringName]
	record.active_slot = 0

func click(player: BeachPlayer) -> void:
	player.set_physics_process(true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in range(5): await physics_frame
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in range(5): await physics_frame
	await process_frame
	player.set_physics_process(false)

func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
