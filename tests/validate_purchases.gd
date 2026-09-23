extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "purchases-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "full playable beach starts")
	if session == null:
		quit(1)
		return
	var progression := session.progression
	var shop := progression.shop
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	var player := session.get_node("Player") as BeachPlayer
	var record := session.state.players[&"local"] as Dictionary
	check(player.hand_rig.tool_socket.get_child_count() == 1 and player.hand_rig.tool_socket.get_child(0).has_node("Visual/Shaft"), "starter stick displays its staged Synty shaft in the hand")
	var total_prices := 0
	for definition in progression.offers.values():
		total_prices += (definition as ToolDefinition).shop_price if definition is ToolDefinition else (definition as UpgradeDefinition).price
	check(progression.offers.size() == 19 and total_prices == 5300, "19 exact resource offers total $5,300")
	check(int(record.money) == 0 and int(record.bag_capacity) == 20 and record.equipped_handheld_ids == [&"stick"], "$0 run starts with stick and 20-unit bag")
	check(not progression.try_purchase(&"local", &"cloth", UpgradeDefinition.Source.SHOP).ok, "shop purchase requires physical proximity")

	player.global_position = shop.counter.global_position + Vector3(0, 0, 2.0)
	player.camera.look_at(shop.counter.global_position + Vector3.UP * 0.65)
	await physics_frame
	check(StringName(str(player.interactor.update_target().get("id", ""))) == &"shop:counter", "Synty shop counter is an E target")
	player.interactor.request_interact()
	check(main.progression_view.visible and paused and not player.input_enabled and root.gui_get_focus_owner() is Button, "shop pauses play and focuses a controller button")
	var first_buy := (main.progression_view.list.get_child(0) as HBoxContainer).get_child(1) as Button
	first_buy.pressed.emit()
	check(main.progression_view.result_label.text == "Need $30 more" and int(record.money) == 0, "insufficient funds gives an explicit result without mutation")
	main.progression_view.close()
	check(not paused and player.input_enabled, "closing shop resumes world input")

	var candidates: Array[StringName] = []
	for item_key in session.state.items:
		var item := session.state.items[item_key] as ItemRecord
		var definition := session.definitions[item.definition_id] as ItemDefinition
		if item.location == ItemRecord.Location.WORLD and definition.kind == ItemDefinition.Kind.WASTE and definition.waste_category == ItemDefinition.WasteCategory.PMD and definition.required_tool.is_empty():
			candidates.append(item.item_id)
			if candidates.size() == 20:
				break
	check(candidates.size() == 20, "real manifest supplies 20 starter-collectible PMD items")
	for item_id in candidates:
		check(session.item_store.try_collect(&"local", item_id).ok, "existing item-store collects starter waste")
	check((record.trash_bag as Array).size() == 20 and station.try_unload(&"local").ok, "full starter bag unloads into the real S1 table")
	for item_id in candidates:
		check(station.try_sort(item_id, &"pmd").ok, "table sorting preserves each existing item")
	check(station.try_seal(&"pmd").ok, "player can manually seal a partial 20-item bag")
	var bag_id := &"bag:000001"
	check(session.state.bag_records.has(bag_id), "manual sealing retains one category bag")
	check(session.item_store.try_hold_bag(&"local", bag_id).ok and container.try_deposit_bag(&"local", bag_id).ok, "sealed bag is carried and deposited")
	var paid := session.collection_service.try_collect_containers(&"local")
	check(paid.ok and int(paid.receipt.total_pay) == 40 and int(record.money) == 40, "normal collection funds first cloth with $40")

	player.global_position = shop.counter.global_position + Vector3(0, 0, 2.0)
	player.camera.look_at(shop.counter.global_position + Vector3.UP * 0.65)
	await physics_frame
	player.interactor.update_target()
	player.interactor.request_interact()
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P15-shop.png")
	first_buy = (main.progression_view.list.get_child(0) as HBoxContainer).get_child(1) as Button
	first_buy.pressed.emit()
	check(int(record.money) == 10 and &"cloth" in (record.owned_tools as Array[StringName]) and main.progression_view.result_label.text.contains("purchased"), "visible shop Buy spends exactly $30 and permanently owns cloth")
	var duplicate := progression.try_purchase(&"local", &"cloth", UpgradeDefinition.Source.SHOP)
	check(not duplicate.ok and duplicate.message == "Already owned" and int(record.money) == 10, "duplicate click cannot spend again")
	check(shop.owned_tools_root.get_child_count() > 0, "purchased cloth appears at labelled physical rack")
	main.progression_view.close()
	if "--capture" in OS.get_cmdline_user_args():
		player.global_position = shop.global_position + Vector3(1.65, 0, 3.5)
		player.camera.look_at(shop.global_position + Vector3(1.65, 1.0, 0))
		await _capture("P15-shop-world.png")
	player.global_position = shop.rack.global_position + Vector3(0, 0, 2.0)
	player.camera.look_at(shop.rack.global_position + Vector3.UP * 0.55)
	await physics_frame
	check(StringName(str(player.interactor.update_target().get("id", ""))) == &"shop:rack", "Synty tool rack is a separate E target")
	player.interactor.request_interact()
	check(main.progression_view.visible and main.progression_view.mode == ProgressionView.Mode.RACK, "physical rack opens equipment screen")
	var cloth_row := main.progression_view.list.get_child(1) as HBoxContainer
	(cloth_row.get_child(2) as Button).pressed.emit()
	check((record.equipped_handheld_ids as Array[StringName]) == [&"stick", &"cloth"] and int(record.active_slot) == 1 and player.hand_rig.tool_socket.get_child_count() > 0, "cloth equips into empty second slot and is shown in hand")
	main.progression_view.close()
	check(progression.try_switch_tool(&"local").ok and int(record.active_slot) == 0 and progression.try_switch_tool(&"local").ok and int(record.active_slot) == 1, "world switch alternates two equipped tools")

	var cleaned := false
	for item_key in session.state.items:
		var item := session.state.items[item_key] as ItemRecord
		if item.location != ItemRecord.Location.WORLD or item.dirty_patches_remaining.is_empty():
			continue
		var view := session.item_view_manager.view_for(item.item_id)
		var patch := _find_patch(view, item.dirty_patches_remaining[0])
		if patch == null:
			continue
		player.global_position = view.global_position + Vector3(0, 0, 1.1)
		player.camera.look_at(patch.global_position)
		await physics_frame
		var target := player.interactor.update_target()
		if StringName(str(target.get("id", ""))) != item.item_id or not (target.get("actions", PackedStringArray()) as PackedStringArray).has("clean"):
			continue
		var before := item.dirty_patches_remaining.size()
		player.interactor.request_primary()
		cleaned = item.dirty_patches_remaining.size() == before - 1
		break
	check(cleaned, "paid-for, physically equipped cloth cleans one aimed chair stain in the full beach")

	player.global_position = shop.counter.global_position + Vector3(0, 0, 2.0)
	check(not progression.try_purchase(&"local", &"bag_80", UpgradeDefinition.Source.SHOP).ok, "Bag 80 dependency blocks purchase before Bag 40")
	check(not progression.try_purchase(&"local", &"knife", UpgradeDefinition.Source.SHOP).ok, "$10 cannot buy the $60 rescue knife")
	record.money = 1500
	check(progression.try_purchase(&"local", &"bag_40", UpgradeDefinition.Source.SHOP).ok and int(record.bag_capacity) == 40, "Bag 40 replaces capacity without clearing existing contents")
	check(progression.try_purchase(&"local", &"bag_80", UpgradeDefinition.Source.SHOP).ok and int(record.bag_capacity) == 80, "Bag 80 requires and supersedes Bag 40")
	check(progression.try_purchase(&"local", &"walking_1", UpgradeDefinition.Source.BOOKLET).ok and progression.try_purchase(&"local", &"walking_2", UpgradeDefinition.Source.BOOKLET).ok and is_equal_approx(player.movement.walk_speed, 4.9), "booklet walking levels replace speed values")
	check(progression.try_purchase(&"local", &"reach_1", UpgradeDefinition.Source.BOOKLET).ok and progression.try_purchase(&"local", &"reach_2", UpgradeDefinition.Source.BOOKLET).ok and is_equal_approx(player.interactor.reach, 4.0), "booklet reach levels replace interaction distance")
	main.progression_view.open_booklet()
	check(main.progression_view.visible and paused and main.progression_view.title_label.text.contains("BOOKLET") and root.gui_get_focus_owner() is Button, "Tab/View booklet pauses and retains controller focus")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P15-booklet.png")
	main.progression_view.close()
	record.money = 1500
	player.global_position = shop.counter.global_position + Vector3(0, 0, 2.0)
	check(progression.try_purchase(&"local", &"knife", UpgradeDefinition.Source.SHOP).ok and progression.try_purchase(&"local", &"detector", UpgradeDefinition.Source.SHOP).ok and progression.try_purchase(&"local", &"oxygen_tank", UpgradeDefinition.Source.SHOP).ok, "required access purchases follow the owned cloth")
	check(progression.try_purchase(&"local", &"sand_cleaner", UpgradeDefinition.Source.SHOP).ok and progression.try_purchase(&"local", &"vacuum", UpgradeDefinition.Source.SHOP).ok and int(record.money) == 340, "implemented $250/$450 efficiency tools unlock after access gear")
	player.global_position = shop.rack.global_position + Vector3(0, 0, 2.0)
	check(progression.try_equip(&"local", &"knife", 0).ok and (record.equipped_handheld_ids as Array[StringName]) == [&"knife", &"cloth"], "full two-slot loadout explicitly replaces a slot; cloth stays owned")
	check(not progression.try_equip(&"local", &"cloth", 0).ok and (record.equipped_handheld_ids as Array[StringName]) == [&"knife", &"cloth"], "duplicate slot equip fails without losing tools")
	var saved := RunState.from_snapshot(session.state.to_snapshot())
	check(saved.validate_invariants(session.definitions).is_empty(), "purchase set, payment and world ownership round-trip")
	session.state = saved
	var restored := saved.players[&"local"] as Dictionary
	restored.bag_capacity = 1
	player.movement.walk_speed = 99.0
	player.interactor.reach = 1.0
	progression.recompute_stats(&"local")
	check(int(restored.bag_capacity) == 80 and is_equal_approx(player.movement.walk_speed, 4.9) and is_equal_approx(player.interactor.reach, 4.0), "saved levels recompute base-plus-level stats without stacking")
	print("P15_PURCHASE earned=40 cloth=30 bag=80 walk=4.9 reach=4.0 clean=%s offers=%d failures=%d" % [cleaned, progression.offers.size(), failures])
	main.free()
	quit(failures)


func _find_patch(node: Node, patch_id: StringName) -> DirtVisual:
	if node is DirtVisual and (node as DirtVisual).patch_id == patch_id:
		return node as DirtVisual
	if node == null:
		return null
	for child in node.get_children():
		var found := _find_patch(child, patch_id)
		if found != null:
			return found
	return null


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "shop/booklet screenshot saved")
	print("P15_CAPTURE " + path)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P15 FAIL: " + message)
