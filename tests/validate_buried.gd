extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var generator := ManifestGenerator.new()
	var first := generator.generate("buried-fixture")
	var second := generator.generate("buried-fixture")
	check(first.ok and second.ok and first.manifest_hash == second.manifest_hash, "same seed has stable complete manifest")
	var buried_rows: Array = []
	for row in first.rows:
		if str(row.location) == "BURIED":
			buried_rows.append(row)
	check(buried_rows.size() == 340 and first.rows.size() == 5740, "300 required waste and 40 optional valuables use fixed buried rows")
	for row in buried_rows:
		check(row.reveal_position_mm == (second.rows as Array)[(first.rows as Array).find(row)].reveal_position_mm, "surface pose stable for %s" % row.id)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "buried-fixture"
	var session := main.start_run() as RunSession
	check(session != null and session.state.required_total == 5700, "playable beach retains 5700 required item denominator")
	if session == null:
		quit(1)
		return
	var player := session.get_node("Player") as BeachPlayer
	var state := session.state
	var player_record := state.players[&"local"] as Dictionary
	var progression := session.progression
	var detector := session.metal_detector
	var finds := session.get_node("BuriedFinds") as BuriedFind
	check(finds.missing_surfaces.is_empty() and finds.blocked_reveals.is_empty(), "all 340 buried anchors have a tagged dig surface and clear reveal pose (missing=%s blocked=%s)" % [finds.missing_surfaces, finds.blocked_reveals])
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	var hidden := _first_buried(state, session.definitions, ItemDefinition.Kind.WASTE)
	check(hidden != null and session.item_view_manager.view_for(hidden.item_id) == null and not session.item_store.try_collect(&"local", hidden.item_id).ok, "hidden find has no world view and cannot be bagged")
	check(not finds.try_reveal(&"local", hidden.item_id).ok, "unowned detector cannot reveal")
	player_record.money = 270
	player.global_position = progression.shop.counter.global_position + Vector3(0, 0, 2)
	check(progression.try_purchase(&"local", &"cloth", UpgradeDefinition.Source.SHOP).ok and progression.try_purchase(&"local", &"knife", UpgradeDefinition.Source.SHOP).ok and progression.try_purchase(&"local", &"detector", UpgradeDefinition.Source.SHOP).ok and int(player_record.money) == 0, "physical shop sells the $270 access chain through detector")
	player.global_position = progression.shop.rack.global_position + Vector3(0, 0, 2)
	check(progression.try_equip(&"local", &"detector", 1).ok and detector.is_active(), "physical rack equips detector")
	var waste := await _reveal_first(state, player, finds, session.definitions, ItemDefinition.Kind.WASTE)
	check(waste != null, "reachable buried waste surface reveals original ID")
	if waste != null:
		await physics_frame
		check(session.item_view_manager.view_for(waste.item_id) != null and not finds.try_reveal(&"local", waste.item_id).ok, "one reveal spawns Synty world item and cannot repeat")
		check(session.item_store.try_collect(&"local", waste.item_id).ok, "revealed waste follows normal bag flow")
		check(station.try_unload(&"local").ok, "required waste reaches normal sorting table")
	var valuable := await _reveal_first(state, player, finds, session.definitions, ItemDefinition.Kind.VALUABLE)
	check(valuable != null, "reachable valuable surface reveals fixed keys")
	if valuable != null:
		await physics_frame
		if "--capture" in OS.get_cmdline_user_args():
			await _capture("P17-buried-keys.png")
		var value := (session.definitions[valuable.definition_id] as ItemDefinition).base_sale_value
		check(session.item_store.try_collect(&"local", valuable.item_id).ok and valuable.item_id in state.optional_finds, "collected find records optional discovery")
		var throw_pose := Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP * 1.0)
		check(session.item_store.try_throw(&"local", throw_pose, Vector3.ZERO).ok and valuable.location == ItemRecord.Location.WORLD and (session.definitions[valuable.definition_id] as ItemDefinition).base_sale_value == value, "thrown valuable keeps same ID and value")
		valuable.last_world_transform.origin = Vector3(400, -20, 400)
		check(session.item_view_manager.recovery_bounds.recover_item(valuable.item_id) and valuable.location == ItemRecord.Location.WORLD, "world-bound recovery preserves valuable")
		check(session.item_store.try_collect(&"local", valuable.item_id).ok, "recovered valuable can be collected again")
		check(station.try_unload(&"local").ok and valuable.item_id in (station.table_record().tray as Array) and station.tray_items.get_child_count() == 1, "real sorting station unloads Synty keys to physical side-table tray")
		station.enter()
		main.sorting_view._on_tray_item_selected(0)
		check(main.sorting_view.sell_button.focus_mode != Control.FOCUS_NONE and not main.sorting_view.sell_button.disabled, "tray offers focusable Sell action")
		if "--capture" in OS.get_cmdline_user_args():
			await _capture("P17-valuables-tray.png")
		main.sorting_view.sell_button.pressed.emit()
		check(valuable.location == ItemRecord.Location.SOLD and int(player_record.money) == value and state.valuable_sales.size() == 1, "sale atomically marks SOLD and credits authored value")
		station.exit()
		check(not station.try_sell_valuable(&"local", valuable.item_id).ok and int(player_record.money) == value, "repeat sale cannot pay again")
	var bagged_valuable := await _reveal_first(state, player, finds, session.definitions, ItemDefinition.Kind.VALUABLE)
	check(bagged_valuable != null and session.item_store.try_collect(&"local", bagged_valuable.item_id).ok, "second valuable remains bagged for save fixture")
	var world_revealed := await _detector_click_first(state, player, detector, finds, session.definitions)
	check(world_revealed != null and world_revealed.location == ItemRecord.Location.WORLD and not world_revealed.buried, "active detector click reveals a find through the player tool flow")
	var roundtrip := RunState.from_snapshot(state.to_snapshot())
	check(roundtrip.required_total == 5700 and roundtrip.valuable_sales.size() == 1 and roundtrip.validate_invariants(session.definitions).is_empty(), "snapshot preserves hidden, revealed, bagged and sold state without ownership errors")
	check(state.validate_invariants(session.definitions).is_empty(), "live ownership, wallet and denominator remain valid")
	print("P17_BURIED waste=%s valuable=%s sold=%d required=%d failures=%d" % [waste.item_id if waste != null else "none", valuable.item_id if valuable != null else "none", state.valuable_sales.size(), state.required_total, failures])
	quit(0 if failures == 0 else 1)


func _first_buried(state: RunState, definitions: Dictionary, kind: ItemDefinition.Kind) -> ItemRecord:
	for item_value in state.items.values():
		var record := item_value as ItemRecord
		if record.location == ItemRecord.Location.BURIED and (definitions[record.definition_id] as ItemDefinition).kind == kind:
			return record
	return null


func _reveal_first(state: RunState, player: BeachPlayer, finds: BuriedFind, definitions: Dictionary, kind: ItemDefinition.Kind) -> ItemRecord:
	for item_value in state.items.values():
		var record := item_value as ItemRecord
		if record.location != ItemRecord.Location.BURIED or (definitions[record.definition_id] as ItemDefinition).kind != kind or record.dig_surface_position.y < -0.1:
			continue
		var point := record.dig_surface_position
		player.global_position = point + Vector3(0, 0, 1.0)
		player.camera.look_at(point)
		await physics_frame
		var wall := StaticBody3D.new()
		wall.collision_layer = 8
		wall.collision_mask = 0
		wall.position = player.camera.global_position.lerp(point, 0.55)
		player.get_parent().add_child(wall)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.8, 1.0, 0.15)
		collision.shape = shape
		wall.add_child(collision)
		await physics_frame
		var blocked := finds.try_reveal(&"local", record.item_id)
		wall.queue_free()
		await physics_frame
		var clear := finds.try_reveal(&"local", record.item_id)
		if clear.ok:
			check(not blocked.ok and record.revealed, "solid wall blocks dig without mutating original find")
			return record
	return null


func _detector_click_first(state: RunState, player: BeachPlayer, detector: MetalDetector, finds: BuriedFind, definitions: Dictionary) -> ItemRecord:
	for item_value in state.items.values():
		var record := item_value as ItemRecord
		if record.location != ItemRecord.Location.BURIED or (definitions[record.definition_id] as ItemDefinition).kind != ItemDefinition.Kind.WASTE or record.dig_surface_position.y < -0.1:
			continue
		var point := record.dig_surface_position
		player.global_position = point + Vector3(0, 0, 0.9)
		player.camera.look_at(point)
		if finds.nearest(player.global_position, 4.0) != record:
			continue
		for _index in range(8):
			await physics_frame
		if detector.nearest_find == record and detector.try_click().ok:
			return record
	return null


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "buried screenshot saved")
	print("P17_CAPTURE " + path)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P17 FAIL: " + message)
