extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "scanner-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "full beach opens for scanner flow")
	if session == null:
		quit(1)
		return
	var scanner := session.scanner
	var player := session.get_node("Player") as BeachPlayer
	var record := session.state.players[&"local"] as Dictionary
	var plastic := _find_item(session, &"waste_plastic_bottle", ItemRecord.Location.WORLD)
	var can := _find_item(session, &"waste_can", ItemRecord.Location.WORLD)
	var hidden := _find_item(session, &"waste_buried_metal", ItemRecord.Location.BURIED)
	check(plastic != null and can != null and hidden != null, "authored beach has Synty plastic bottle, can and buried can")
	check(not scanner.pulse().ok, "unbought scanner cannot pulse")
	check(session.item_store.try_collect(&"local", plastic.item_id).ok, "first real Synty bottle pickup unlocks its type and plastic material")
	check(&"definition:waste_plastic_bottle" in scanner.available_filters() and &"material:plastic" in scanner.available_filters(), "discovery records expose only collected type and associated material")
	check(not scanner.try_select_filter(&"definition:prop_parasol").ok, "unknown type filter is rejected")
	record.money = 150
	check(session.progression.try_purchase(&"local", &"scanner", UpgradeDefinition.Source.BOOKLET).ok and int(record.money) == 0 and (record.equipped_handheld_ids as Array).size() == 1, "booklet skill costs $150 and consumes no handheld slot")
	main.progression_view.open_booklet()
	var tabs := main.progression_view.list.get_child(0) as HBoxContainer
	(tabs.get_child(1) as Button).pressed.emit()
	var filter_button: Button
	for row in main.progression_view.list.get_children():
		for child in row.get_children():
			if child is Button and child.has_meta(&"scanner_filter") and child.get_meta(&"scanner_filter") == &"material:plastic":
				filter_button = child as Button
	check(filter_button != null, "booklet shows a controller-focusable Plastic material filter")
	if filter_button != null:
		filter_button.pressed.emit()
	check(record.scanner_filter == &"material:plastic" and main.progression_view.result_label.text.contains("Plastic"), "booklet selects persistent filter")
	main.progression_view.close()
	var plastic_query := scanner.query_matches()
	check(plastic_query.ok and str(plastic.item_id) not in (plastic_query.ids as PackedStringArray) and (plastic_query.ids as PackedStringArray).size() > 0, "bagged bottle is excluded while other known-material items remain")
	var next_bottle := _find_item(session, &"waste_plastic_bottle", ItemRecord.Location.WORLD)
	var view := session.item_view_manager.view_for(next_bottle.item_id)
	player.global_position = view.global_position + Vector3(0, 0, 3.0)
	player.camera.look_at(view.global_position + Vector3.UP * 0.25)
	await physics_frame
	Input.action_press(&"scanner_pulse")
	await physics_frame
	await physics_frame
	Input.action_release(&"scanner_pulse")
	check(main.scanner_overlay.visible, "live player pulse action reaches the passive scanner")
	check(scanner.pulse().ok and main.scanner_overlay.visible and scanner.markers.size() <= ScannerService.MARKER_LIMIT, "scanner pulse shows capped nearby markers and global counts")
	var allocated := scanner.markers.size()
	for index in 3:
		scanner.pulse()
	check(scanner.markers.size() == allocated, "repeated pulses reuse the same marker nodes")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P23-scanner.png")
	check(session.item_store.try_collect(&"local", can.item_id).ok, "real can pickup unlocks Metal material")
	check(scanner.try_select_filter(&"material:metal").ok, "newly discovered material filter can be selected")
	var metal_query := scanner.query_matches()
	check(str(hidden.item_id) not in (metal_query.ids as PackedStringArray), "hidden buried can stays out of scanner results")
	hidden.location = ItemRecord.Location.WORLD
	hidden.buried = false
	hidden.revealed = true
	hidden.last_world_transform = hidden.reveal_transform
	session.finalize_action(PackedStringArray([str(hidden.item_id)]))
	metal_query = scanner.query_matches()
	check(str(hidden.item_id) in (metal_query.ids as PackedStringArray), "same original can ID becomes scannable after detector-style reveal state")
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	check(station.try_unload(&"local").ok, "picked items enter real S1 sorting table")
	check(scanner.try_select_filter(&"material:plastic").ok, "switching filters does not erase discoveries")
	plastic_query = scanner.query_matches()
	var owner_found := false
	for target in plastic_query.targets as Array[Dictionary]:
		if str(target.key) == "station:sorting:S1":
			owner_found = true
	check(str(plastic.item_id) in (plastic_query.ids as PackedStringArray) and owner_found, "sorted-but-uncollected bottle points to its owner station rather than a vanished world mesh")
	check(station.try_sort(plastic.item_id, &"pmd").ok, "bottle moves from table to correct bin")
	var sealed := station.try_seal(&"pmd")
	check(sealed.ok, "partial real bin seals into a disposal bag")
	var bag_id := StringName(str(sealed.receipt.get("bag_id", "")))
	plastic_query = scanner.query_matches()
	var rack_action := false
	for target in plastic_query.targets as Array[Dictionary]:
		if str(target.key) == "station:sorting:S1" and "carry sealed bag" in str(target.label):
			rack_action = true
	check(rack_action, "sealed item routes to its station rack with a carry action")
	check(session.item_store.try_hold_bag(&"local", bag_id).ok, "sealed bag can be carried")
	plastic_query = scanner.query_matches()
	check(int(plastic_query.carried_count) == 1 and str(plastic.item_id) in (plastic_query.ids as PackedStringArray), "held sealed bag gives a deposit hint without a marker at the player's feet")
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	check(container.try_deposit_bag(&"local", bag_id).ok, "sealed bag enters matching Synty container")
	plastic_query = scanner.query_matches()
	var container_action := false
	for target in plastic_query.targets as Array[Dictionary]:
		if str(target.key) == "container:container:S1:pmd" and "call truck" in str(target.label):
			container_action = true
	check(container_action, "deposited item guides the player to call truck collection")
	check(session.collection_service.try_collect_containers(&"local").ok and str(plastic.item_id) not in (scanner.query_matches().ids as PackedStringArray), "truck collection removes completed waste from the scan")
	var chair := _find_item(session, &"prop_beach_chair", ItemRecord.Location.WORLD)
	check(chair != null and session.item_store.try_hold(&"local", chair.item_id).ok, "real Synty chair pickup discovers its type")
	if not chair.dirty_patches_remaining.is_empty():
		chair.dirty_patches_remaining.clear()
		session.finalize_action(PackedStringArray([str(chair.item_id)]))
	var placement := session.placement_service
	var placed_slot := StringName()
	for slot_key in placement.slots:
		var slot := placement.slots[slot_key] as Dictionary
		var pool := session.state.container_records[StringName(str(slot.pool_id))] as Dictionary
		if &"beach_chair" not in (pool.accepted_families as Array) or not placement.occupant_for(StringName(slot_key)).is_empty():
			continue
		player.global_position = (slot.transform as Transform3D).origin + Vector3(0, 0, 1.0)
		if placement.try_place(&"local", StringName(slot_key)).ok:
			placed_slot = StringName(slot_key)
			break
	check(not placed_slot.is_empty(), "clean chair fits a real compatible beach slot")
	check(scanner.try_select_filter(&"definition:prop_beach_chair").ok and str(chair.item_id) not in (scanner.query_matches().ids as PackedStringArray), "clean slotted chair is excluded")
	check(placement.try_remove(&"local", placed_slot).ok and str(chair.item_id) not in (scanner.query_matches().ids as PackedStringArray), "held removed chair is not marked at the player's feet")
	var other_zone: ItemRecord
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.location == ItemRecord.Location.WORLD and item.home_zone_id != chair.home_zone_id:
			other_zone = item
			break
	var drop_pose := Transform3D(Basis.IDENTITY, other_zone.last_world_transform.origin + Vector3.UP * 5.0)
	check(session.item_store.try_throw(&"local", drop_pose, Vector3.ZERO).ok and str(chair.item_id) in (scanner.query_matches().ids as PackedStringArray), "dropped chair becomes scannable again in another zone")
	session.item_view_manager.restore_world_view(chair.item_id)
	await physics_frame
	var chair_position := Vector3.INF
	for target in (scanner.query_matches().targets as Array[Dictionary]):
		if str(target.key) == str(chair.item_id):
			chair_position = target.position as Vector3
	check(chair.home_zone_id != other_zone.home_zone_id and chair_position.distance_to(drop_pose.origin) < 2.0, "scanner follows current world pose, not the chair's original home zone")
	check(&"definition:prop_beach_chair" == StringName(str((RunState.from_snapshot(session.state.to_snapshot()).players[&"local"] as Dictionary).scanner_filter)), "selected filter and discoveries survive snapshot reconstruction")
	check(session.state.validate_invariants(session.definitions).is_empty(), "scanner queries and actual table transfer preserve ownership")
	main.free()
	var zero_checked := "--capture" not in OS.get_cmdline_user_args()
	if zero_checked:
		await _single_item_finish()
	for frame in 4:
		await process_frame
	print("P23_SCANNER purchase=1 filters=3 buried=1 owners=3 chair=1 zero=%d markers=%d failures=%d" % [int(zero_checked), allocated, failures])
	quit(failures)


func _single_item_finish() -> void:
	var lab := (load("res://tests/scenes/placement_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	var settings := SettingsStore.new()
	settings.settings_path = "user://p23-scanner-check.cfg"
	lab.add_child(settings)
	var state := RunState.new()
	state.run_id = "scanner-single"
	state.seed_text = "scanner-single"
	var player_record := state.add_player()
	(player_record.upgrade_levels as Dictionary)[&"scanner"] = 1
	(player_record.discoveries as Array[StringName]).append(&"definition:waste_can")
	state.discoveries.append(&"definition:waste_can")
	var item := ItemRecord.new()
	item.item_id = &"single:can"
	item.definition_id = &"waste_can"
	item.home_section_id = &"lab"
	item.home_zone_id = &"lab"
	item.last_world_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 3))
	state.add_item(item)
	var definitions := ManifestGenerator.new().load_catalog()
	var session := RunSession.new()
	session.initialize(state, definitions)
	lab.add_child(session)
	var player := lab.get_node("%Player") as BeachPlayer
	player.configure(settings, session)
	var manager := ItemViewManager.new()
	session.add_child(manager)
	session.item_view_manager = manager
	manager.configure(session, definitions, {&"recovery:lab": Vector3(0, 0.05, 4)}, player)
	manager.build_views()
	var progression := ProgressionService.new()
	session.add_child(progression)
	progression.configure(session, player)
	var canvas := CanvasLayer.new()
	lab.add_child(canvas)
	var overlay := (load("res://scenes/ui/scanner_overlay.tscn") as PackedScene).instantiate() as Control
	canvas.add_child(overlay)
	var scanner := ScannerService.new()
	session.add_child(scanner)
	scanner.configure(session, player, overlay)
	check(scanner.try_select_filter(&"definition:waste_can").ok and str(item.item_id) in (scanner.query_matches().ids as PackedStringArray), "single known world item is scannable in the existing placement lab")
	item.location = ItemRecord.Location.COLLECTED
	item.container_id = &"collection:single"
	session.finalize_action(PackedStringArray([str(item.item_id)]))
	check((scanner.query_matches().ids as PackedStringArray).is_empty() and state.validate_invariants(definitions).is_empty(), "final truck-collected item yields zero remaining matches and a valid run")
	var settings_path := settings.settings_path
	lab.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _find_item(session: RunSession, definition_id: StringName, location: ItemRecord.Location) -> ItemRecord:
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.definition_id == definition_id and item.location == location:
			return item
	return null


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "scanner screenshot saved")
	print("P23_CAPTURE " + path)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P23 FAIL: " + message)
