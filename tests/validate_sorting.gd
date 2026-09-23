extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/c02"
	main.seed_input.text = "sorting-fixture"
	var run_root := main.start_run() as RunSession
	check(run_root != null, "full beach run starts")
	if run_root == null:
		quit(1)
		return
	var station := run_root.sorting_stations[&"sorting:S1"] as SortingStation
	var view := main.sorting_view
	var player := run_root.get_node("Player") as BeachPlayer
	check(run_root.sorting_stations.size() == 3 and station.free_cell_count() == 240, "three authored service stations each have 240 stable cells")
	var candidates: Array[StringName] = []
	var ids: Array[String] = []
	for item_key in run_root.state.items:
		ids.append(str(item_key))
	ids.sort()
	for item_text in ids:
		var record := run_root.state.items[StringName(item_text)] as ItemRecord
		var definition := run_root.definitions[record.definition_id] as ItemDefinition
		if record.location == ItemRecord.Location.WORLD and definition.kind == ItemDefinition.Kind.WASTE and definition.required_tool.is_empty():
			candidates.append(record.item_id)
			if candidates.size() == 244:
				break
	check(candidates.size() == 244, "live manifest has enough accessible waste for 200-item station exercise")
	var player_record := run_root.state.players[&"local"] as Dictionary
	player_record.bag_capacity = 200
	_collect(run_root, candidates.slice(0, 20))
	await _physics_frames(2)
	player.global_position = station.global_position + Vector3(0, 0, 2.2)
	player.camera.look_at(station.global_position + Vector3(0, 0.82, 0))
	await _physics_frames(2)
	var target := player.interactor.update_target()
	check(target.get("kind") == "station" and target.get("id") == station.station_id, "the physical tabletop is an E interaction target")
	player.interactor.request_interact()
	check(station.active and view.visible and not player.input_enabled and station.table_camera.current and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "E enters overhead table context, stows tools, freezes movement and releases pointer")
	var blocked_world_throw := (player_record.trash_bag as Array).size()
	player._physics_process(0.016)
	check((player_record.trash_bag as Array).size() == blocked_world_throw, "world actions cannot consume bag contents in table context")
	view.focused_cell = 0
	await _joy(JOY_BUTTON_DPAD_UP)
	check(view.unload_button.has_focus(), "grid top edge gives native focus to Unload")
	await _joy(JOY_BUTTON_A)
	check(station.free_cell_count() == 220 and (player_record.trash_bag as Array).is_empty() and station.item_at(0) == candidates[0] and station.item_at(19) == candidates[19], "whole bag unloads in stable order into cells 000–019")
	await _joy(JOY_BUTTON_START)
	check(paused and main.pause_menu.visible and station.active and station.table_camera.current, "Start opens pause over the populated table")
	var paused_time := run_root.state.elapsed_active_seconds
	await process_frame
	check(is_equal_approx(run_root.state.elapsed_active_seconds, paused_time), "the active run timer stops while sorting is paused")
	await _joy(JOY_BUTTON_A)
	check(not paused and station.active and station.table_camera.current and player.input_reader.context == InputReader.Context.TABLE and view.unload_button.has_focus(), "Resume returns to the table camera, input context and focused control")
	await _joy(JOY_BUTTON_START)
	main.pause_menu.settings_button.grab_focus()
	await _joy(JOY_BUTTON_A)
	check(main.settings_menu.visible and not player.input_enabled, "table pause opens Settings without enabling world input")
	main.settings_menu.close_menu()
	check(paused and main.pause_menu.visible and not player.input_enabled, "closing Settings returns to table pause with world input disabled")
	main._resume_run()
	check(not paused and player.input_reader.context == InputReader.Context.TABLE and not player.input_enabled, "resuming after Settings restores table controls")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P12-table-20.png")
	_collect(run_root, candidates.slice(20, 200))
	await _physics_frames(2)
	var remapped_confirm := InputEventJoypadButton.new()
	remapped_confirm.button_index = JOY_BUTTON_X
	remapped_confirm.pressed = true
	main.settings_store.rebind(&"ui_accept", remapped_confirm)
	var remapped_back := InputEventJoypadButton.new()
	remapped_back.button_index = JOY_BUTTON_BACK
	remapped_back.pressed = true
	main.settings_store.rebind(&"ui_cancel", remapped_back)
	check(view.exit_button.text.contains(main.settings_store.binding_text(&"ui_cancel")), "table exit prompt follows the remapped controller back binding")
	view.unload_button.grab_focus()
	await _joy(JOY_BUTTON_X)
	check(station.free_cell_count() == 40 and station.item_at(199) == candidates[199], "remapped controller confirm unloads into stable table cells")
	view.grab_focus()
	await _joy(JOY_BUTTON_BACK)
	check(not station.active and player.input_enabled, "remapped controller back exits table without a world action")
	station.enter()
	main.settings_store.reset_all()
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P12-table-200.png")
	_collect(run_root, candidates.slice(200, 241))
	var bag_before := (player_record.trash_bag as Array[StringName]).duplicate()
	var rejected := station.try_unload(&"local")
	check(not rejected.ok and rejected.reason == ActionResult.Reason.CAPACITY and (player_record.trash_bag as Array[StringName]) == bag_before and station.free_cell_count() == 40, "41-item unload into 40 cells rejects intact and states the free-space shortage")
	var first := candidates[0]
	var true_category := SortingStation.CATEGORIES[(run_root.definitions[(run_root.state.items[first] as ItemRecord).definition_id] as ItemDefinition).waste_category]
	var wrong_category := SortingStation.CATEGORIES[(SortingStation.CATEGORIES.find(true_category) + 1) % 4]
	var wrong := station.try_sort(first, wrong_category)
	check(wrong.ok and not bool(wrong.receipt.correct) and (run_root.state.items[first] as ItemRecord).location == ItemRecord.Location.BIN, "wrong bin accepts item and records final category feedback")
	var corrected := station.try_sort(first, true_category)
	check(corrected.ok and bool(corrected.receipt.correct) and (run_root.state.items[first] as ItemRecord).container_id == station.bin_id(true_category), "bin-to-bin correction uses same method without a free table cell")
	check(station.try_unsort(first).ok and (run_root.state.items[first] as ItemRecord).location == ItemRecord.Location.TABLE, "bin item can return to first free cell before sealing")
	var controller_item := station.item_at(1)
	view.focused_cell = 0
	view.grab_focus()
	view._input(_action(&"table_focus_right"))
	check(view.focused_cell == 1, "controller D-pad navigates stable table cells")
	view._input(_action(&"table_bin_2"))
	view._input(_action(&"table_select"))
	check((run_root.state.items[controller_item] as ItemRecord).location == ItemRecord.Location.BIN, "controller D-pad/bin/A path commits a focused table item")
	view._input(_action(&"table_inspect_bin"))
	view._input(_action(&"table_select"))
	view._input(_action(&"table_bin_next"))
	view._input(_action(&"table_select"))
	check((run_root.state.items[controller_item] as ItemRecord).container_id == station.bin_id(SortingStation.CATEGORIES[2]), "controller-only inspect, select and bin-cycle corrects an unsealed item")
	view._input(_action(&"table_inspect_bin"))
	var mouse_item := station.item_at(2)
	var from := view._cell_screen(2)
	var destination := view.bin_buttons[0].get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	view._input(down)
	var motion := InputEventMouseMotion.new()
	motion.position = destination
	view._input(motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = destination
	view._input(up)
	check((run_root.state.items[mouse_item] as ItemRecord).container_id == station.bin_id(&"pmd"), "mouse drag preview releases into a physical category bin")
	var cancelled_item := station.item_at(3)
	down.position = view._cell_screen(3)
	view._input(down)
	motion.position = Vector2(5, 350)
	view._input(motion)
	view._input(_action(&"ui_cancel"))
	check(station.active and (run_root.state.items[cancelled_item] as ItemRecord).location == ItemRecord.Location.TABLE, "first B cancels an uncommitted drag without leaving table mode")
	view._input(_action(&"ui_cancel"))
	check(not station.active and player.input_enabled and player.camera.current and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) and (run_root.state.items[cancelled_item] as ItemRecord).location == ItemRecord.Location.TABLE, "exit cancels transient drag but retains committed station contents")
	station.enter()
	check(station.item_at(3) == cancelled_item and view.visible and station.free_cell_count() == 42, "reenter restores table contents and overhead UI without replaying unload")
	station.exit()
	var physical_item := candidates[241]
	var bin_area := station.bin_areas.get_child(3) as Area3D
	var drop_pose := Transform3D(Basis.IDENTITY, bin_area.global_position + Vector3.UP * 0.65)
	check(run_root.item_view_manager.throw_item(physical_item, drop_pose, Vector3.DOWN * 4.0), "existing WORLD waste begins a real downward bin-opening throw")
	await _physics_frames(12)
	check((run_root.state.items[physical_item] as ItemRecord).location == ItemRecord.Location.BIN and (run_root.state.items[physical_item] as ItemRecord).container_id == station.bin_id(&"glass"), "physical opening catch uses the same sorting transfer")
	var side_item := candidates[243]
	var side_pose := Transform3D(Basis.IDENTITY, bin_area.global_position + Vector3(0.8, -0.3, 0))
	check(run_root.item_view_manager.throw_item(side_item, side_pose, Vector3.LEFT * 3.0), "existing WORLD waste approaches the bin from the side")
	await _physics_frames(12)
	check((run_root.state.items[side_item] as ItemRecord).location == ItemRecord.Location.WORLD, "physical bin walls and top-entry rule reject side capture")
	check(station.try_unload(&"local").ok and station.free_cell_count() == 1, "41 bag items can fill exactly 41 of the 42 remaining cells")
	_collect(run_root, [candidates[242]] as Array[StringName])
	check(station.try_unload(&"local").ok and station.free_cell_count() == 0, "all 240 table cells can hold stable item IDs")
	check(not station.try_unsort(controller_item).ok and (run_root.state.items[controller_item] as ItemRecord).location == ItemRecord.Location.BIN, "a full table rejects bin-to-cell correction intact")
	check(station.try_sort(controller_item, &"organic").ok and (run_root.state.items[controller_item] as ItemRecord).container_id == station.bin_id(&"organic"), "full table still allows direct bin-to-bin correction")
	var valuable_id := StringName()
	for item_text in ids:
		var value_record := run_root.state.items[StringName(item_text)] as ItemRecord
		if value_record.location == ItemRecord.Location.BURIED and (run_root.definitions[value_record.definition_id] as ItemDefinition).kind == ItemDefinition.Kind.VALUABLE:
			valuable_id = value_record.item_id
			break
	check(not valuable_id.is_empty(), "live manifest contains a stable optional valuable ID")
	var valuable_record := run_root.state.items[valuable_id] as ItemRecord
	valuable_record.location = ItemRecord.Location.BAG
	valuable_record.holder_id = &"local"
	(player_record.valuable_bag as Array[StringName]).append(valuable_id)
	run_root.finalize_action(PackedStringArray([str(valuable_id)]))
	check(station.try_unload(&"local").ok and valuable_id in (station.table_record().tray as Array) and (run_root.state.items[valuable_id] as ItemRecord).location == ItemRecord.Location.VALUABLE_TRAY, "full waste table still identifies an optional valuable into the labelled tray")
	var glass_bin := station.bin_record(&"glass")
	var to_sort: Array[StringName] = []
	for index in range(SortingStation.CELL_COUNT):
		var item_id := station.item_at(index)
		if not item_id.is_empty():
			to_sort.append(item_id)
		if to_sort.size() == SortingStation.BIN_CAPACITY:
			break
	for item_id in to_sort.slice(0, SortingStation.BIN_CAPACITY - (glass_bin.items as Array).size()):
		check(station.try_sort(item_id, &"glass").ok, "glass bin accepts an unsealed table item")
	var extra: StringName = to_sort.back()
	check((glass_bin.items as Array).is_empty() and (station.rack_record().slots as Dictionary).size() == 1, "P13 auto-seals the 50th item into the output rack")
	check(station.try_sort(extra, &"glass").ok and (glass_bin.items as Array).size() == 1, "the next item enters the newly empty bin without losing its ID")
	check(int(player_record.money) == 0 and run_root.state.required_total == 5700, "sorting and tray identification neither pay nor alter the required denominator")
	check(run_root.state.validate_invariants(run_root.definitions).is_empty(), "sorting table, bins, bag and item records preserve unique ownership")
	var run_id := run_root.state.run_id
	var table_count := SortingStation.CELL_COUNT - station.free_cell_count()
	var glass_count := (station.bin_record(&"glass").items as Array).size()
	station.enter()
	await _joy(JOY_BUTTON_START)
	check(paused and main.pause_menu.visible, "Pause remains available after a full table and tray are populated")
	main.pause_menu.save_quit_button.grab_focus()
	await _joy(JOY_BUTTON_A)
	check(not paused and not main.sorting_view.visible and main.menu_container.visible, "Save and quit from table returns to title without a world action")
	var loaded := main.load_run(run_id, &"manual")
	check(bool(loaded.ok), "table save loads from manual slot")
	if bool(loaded.ok):
		var resumed := main.run_root as RunSession
		var resumed_station := resumed.sorting_stations[&"sorting:S1"] as SortingStation
		check(not resumed_station.active and not main.sorting_view.visible and resumed_station.free_cell_count() == SortingStation.CELL_COUNT - table_count and (resumed_station.bin_record(&"glass").items as Array).size() == glass_count and valuable_id in (resumed_station.table_record().tray as Array) and resumed.state.validate_invariants(resumed.definitions).is_empty(), "load returns to world at station with table, bin and tray ownership intact")
		resumed_station.enter()
		view.tray_list.grab_focus()
		await _joy(JOY_BUTTON_DPAD_DOWN)
		check(view.selected_valuable == valuable_id, "controller selects the saved valuable in the native tray list")
		view.sell_button.grab_focus()
		await _joy(JOY_BUTTON_A)
		check((resumed.state.valuable_sales as Array).size() == 1 and (resumed_station.table_record().tray as Array).is_empty(), "focused Sell activates once and pays for the original valuable")
		view.bin_buttons[3].grab_focus()
		await _joy(JOY_BUTTON_A)
		var loaded_cell := -1
		for index in range(SortingStation.CELL_COUNT):
			if not resumed_station.item_at(index).is_empty():
				loaded_cell = index
				break
		check(loaded_cell >= 0, "saved table retains a sortable cell")
		if loaded_cell >= 0:
			var loaded_item := resumed_station.item_at(loaded_cell)
			view.focused_cell = loaded_cell
			view.grab_focus()
			await _joy(JOY_BUTTON_A)
			check(resumed_station.item_at(loaded_cell).is_empty() and (resumed.state.items[loaded_item] as ItemRecord).location == ItemRecord.Location.BIN, "controller sorts a restored cell without leaving its saved owner behind")
		view.seal_button.grab_focus()
		await _joy(JOY_BUTTON_A)
		check((resumed_station.bin_record(&"glass").items as Array).is_empty() and (resumed_station.rack_record().slots as Dictionary).size() == 2, "focused Seal creates a partial physical bag after reload")
		view.exit_button.grab_focus()
		await _joy(JOY_BUTTON_A)
		check(not resumed_station.active and (resumed.get_node("Player") as BeachPlayer).input_enabled and resumed.state.validate_invariants(resumed.definitions).is_empty(), "controller Exit returns to world without duplicating table ownership")
	print("P12_TABLE cells=20->200->240 unload=atomic sort=wrong/correct controller=sort/correct mouse=drag catch=physical bin=50->sealed tray=valuable failures=%d" % failures)
	main.free()
	quit(failures)


func _collect(session: RunSession, item_ids: Array[StringName]) -> void:
	for item_id in item_ids:
		check(session.item_store.try_collect(&"local", item_id).ok, "fixture collects existing item %s through ItemStore" % item_id)


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var released := event.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "table evidence capture saves: %s" % filename)
	print("P12_CAPTURE %s" % path)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P12 FAIL: %s" % message)
