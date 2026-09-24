extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "faint-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "playable full beach starts")
	if session == null:
		quit(1)
		return
	var player := session.get_node("Player") as BeachPlayer
	var record := session.state.players[&"local"] as Dictionary
	var swim := session.swim_service
	var underwater_fog_end := SwimService.UNDERWATER_ENVIRONMENT.fog_depth_end
	var water := swim.water
	var shop := session.progression.shop
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	check(is_equal_approx(water.surface_y, 0.08) and water.contains_horizontal(Vector3(0, 0, 50)) and not water.contains_horizontal(Vector3(0, 0, 10)), "authored water surface and horizontal bounds stay fixed")
	player.global_position = Vector3(0, -0.2, 35)
	swim.step_environment(0.05)
	check(not player.movement.is_swimming and not bool(record.immersed), "shore wading does not trigger swimming or air loss")
	player.movement.physics_step(Vector2.ZERO, false, false, true, 0.1)
	swim.step_environment(0.05)
	check(not player.movement.is_swimming and not bool(record.immersed), "crouching at the shoreline does not falsely submerge the camera")
	check(not water.contains_horizontal(Vector3(55, -2, 40)) and water.contains_horizontal(Vector3(55, -2, 50)), "water bounds follow the compact curved shore below the pier")
	var edge_poses: Array[Dictionary] = []
	var edge_center := water.clamp_inside(Vector3(79, -2, 212), 8.0)
	for _index in range(200):
		var pose := swim._find_drop_pose(edge_center, Vector3(0.22, 0.18, 0.22), edge_poses)
		if pose == Transform3D.IDENTITY:
			break
		edge_poses.append({"position": pose.origin, "radius": 0.11})
	check(edge_poses.size() == 200, "full 200-item bag has distinct safe drop poses even near water bounds")
	check(swim._find_drop_pose(edge_center, Vector3(1.15, 0.9, 0.8), edge_poses) != Transform3D.IDENTITY, "large carried prop still has a clear pose beside full-bag spill")
	player.global_position = Vector3(0, -2.0, 70)
	swim.step_environment(0.1)
	check(player.movement.is_swimming and bool(record.immersed) and float(record.air_remaining) < 10.0, "submerged player swims and consumes starter air")
	check(player.camera.environment != null and player.camera.environment != SwimService.UNDERWATER_ENVIRONMENT and player.camera.environment != SwimService.SURFACE_ENVIRONMENT and player.camera.environment.fog_depth_end > SwimService.UNDERWATER_ENVIRONMENT.fog_depth_end, "visual entry fades a private camera environment while air is already consumed")
	player.movement.physics_step(Vector2.ZERO, false, false, false, 0.1, true, false)
	check(player.velocity.y > 0.0, "jump input swims upward")
	for _index in range(3):
		player.movement.physics_step(Vector2.ZERO, false, false, false, 0.1, false, true)
	check(player.velocity.y < 0.0, "crouch input swims downward")
	var near_surface_feet := water.surface_y - player.head.position.y - 0.05
	player.global_position = Vector3(0, near_surface_feet, 70)
	swim.step_environment(0.05)
	check(bool(record.immersed), "head within hysteresis band remains submerged")
	player.global_position.y += 0.16
	swim.step_environment(0.05)
	check(not bool(record.immersed), "head above exit threshold resurfaces without flicker")
	check(player.camera.environment != null, "exit keeps the camera override until its short visual fade completes")
	swim.step_environment(0.6)
	check(player.camera.environment == null and is_equal_approx(SwimService.UNDERWATER_ENVIRONMENT.fog_depth_end, underwater_fog_end), "completed exit restores the world environment without mutating the shared underwater resource")
	player.global_position.y = near_surface_feet - 0.16
	swim.step_environment(0.05)
	player.global_position.y = near_surface_feet + 0.16
	swim.step_environment(0.6)
	check(float(record.air_remaining) < 10.0, "brief surfacing is not a refill")
	swim.step_environment(0.5)
	check(is_equal_approx(float(record.air_remaining), 10.0), "one continuous second above water refills starter air")
	player.global_position = Vector3(0, -2.0, 70)
	swim.step_environment(0.1)
	record.air_remaining = 0.4
	player.set_paused(true)
	await create_timer(0.25, true).timeout
	check(is_equal_approx(float(record.air_remaining), 0.4), "pause at low air freezes oxygen")
	player.set_paused(false)
	main.progression_view.open_booklet()
	await create_timer(0.2, true).timeout
	check(is_equal_approx(float(record.air_remaining), 0.4), "booklet modal also freezes oxygen")
	main.progression_view.close()
	swim.set_physics_process(false)
	var pmd_ids := _world_items(session, &"waste_can", 4)
	check(pmd_ids.size() == 4, "real generated beach has enough Synty cans for mixed faint setup")
	for index in range(2):
		check(session.item_store.try_collect(&"local", pmd_ids[index]).ok, "collects original can for sealed bag")
	check(station.try_unload(&"local").ok, "unloads two cans on real S1 table")
	for index in range(2):
		check(station.try_sort(pmd_ids[index], &"pmd").ok, "sorts original can into real PMD bin")
	check(station.try_seal(&"pmd").ok, "seals partial original-ID disposal bag")
	var bag_id := &"bag:000001"
	check(session.item_store.try_hold_bag(&"local", bag_id).ok, "holds sealed disposal bag in first hand")
	var bucket_id := _world_items(session, &"prop_bucket", 1)[0]
	check(session.item_store.try_hold(&"local", bucket_id).ok, "holds Synty bucket in second hand")
	for index in range(2, 4):
		check(session.item_store.try_collect(&"local", pmd_ids[index]).ok, "bags loose Synty can before faint")
	player.carry.refresh_hand_visuals()
	var before_money := 570
	record.money = before_money
	var before_tools := (record.equipped_handheld_ids as Array).duplicate()
	player.global_position = Vector3(0, -2.0, 80)
	swim.step_environment(0.05)
	record.air_remaining = 0.0
	var result := await swim.try_faint()
	check(result.ok and str(result.receipt.pile_id) == "recovery:000001" and str(result.receipt.anchor_id) == "recovery:shallows" and (result.receipt.item_ids as Array).size() == 3 and (result.receipt.bag_ids as Array).size() == 1, "one faint commits mixed drop and chooses nearest dry anchor")
	check((record.trash_bag as Array).is_empty() and (record.bag_order as Array).is_empty() and (record.held_objects as Array).is_empty() and int(record.money) == before_money and record.equipped_handheld_ids == before_tools and session.state.faint_count == 1, "faint empties carry and order but preserves tools and wallet")
	check((session.state.items[bucket_id] as ItemRecord).location == ItemRecord.Location.WORLD and (session.state.bag_records[bag_id] as Dictionary).location == "WORLD", "bucket and sealed bag remain recoverable world objects")
	for index in range(2):
		check((session.state.items[pmd_ids[index]] as ItemRecord).location == ItemRecord.Location.SEALED, "sealed bag contents stay sealed")
	check(session.state.recovery_piles.size() == 1 and swim._markers.size() == 1 and float(record.air_remaining) == 10.0 and not bool(record.immersed), "dry respawn restores starter air and marks underwater pile")
	check(not (await swim.try_faint()).ok, "repeat faint at restored air cannot drop twice")
	check(session.state.validate_invariants(session.definitions).is_empty(), "mixed faint preserves exact ownership and 5700 denominator")
	if "--capture" in OS.get_cmdline_user_args():
		player.global_position = Vector3(0, -1.2, 83)
		player.camera.look_at(Vector3(0, -3.0, 80))
		await _capture("P18-recovery-pile.png")
	player.global_position = shop.counter.global_position + Vector3(0, 0, 2)
	check(session.progression.try_purchase(&"local", &"cloth", UpgradeDefinition.Source.SHOP).ok and session.progression.try_purchase(&"local", &"knife", UpgradeDefinition.Source.SHOP).ok and session.progression.try_purchase(&"local", &"detector", UpgradeDefinition.Source.SHOP).ok and session.progression.try_purchase(&"local", &"oxygen_tank", UpgradeDefinition.Source.SHOP).ok and session.progression.try_purchase(&"local", &"flippers", UpgradeDefinition.Source.SHOP).ok, "physical shop sells the access chain and $80 flippers")
	check(is_equal_approx(player.movement.swim_speed, 4.0) and session.progression.max_air_seconds(&"local") == 60.0 and int(record.money) == 0, "purchased gear applies exact swim speed and 60-second tier")
	player.global_position = Vector3(0, 0.0, 20)
	swim.step_environment(1.01)
	check(float(record.air_remaining) == 60.0, "tank refills to 60 seconds after one dry second")
	check(session.item_store.try_collect(&"local", pmd_ids[2]).ok, "recovers an original can from first pile")
	check(pmd_ids[2] not in (session.state.recovery_piles[&"recovery:000001"] as Dictionary).item_ids, "recovered ID leaves old pile before later faint")
	player.global_position = Vector3(0, -2.0, 80)
	swim.step_environment(0.05)
	record.air_remaining = 0.01
	var automatic := {"receipt": {}}
	swim.faint_completed.connect(func(receipt: Dictionary) -> void: automatic.receipt = receipt, CONNECT_ONE_SHOT)
	swim.set_physics_process(true)
	await create_timer(0.08, true).timeout
	check(swim._recovering and not (await swim.try_faint()).ok, "faint request during fade is rejected without another drop")
	await create_timer(1.2, true).timeout
	swim.set_physics_process(false)
	check(str((automatic.receipt as Dictionary).get("pile_id", "")) == "recovery:000002" and session.state.recovery_piles.size() == 2 and float(record.air_remaining) == 60.0 and session.state.faint_count == 2, "automatic zero-air faint at 60-second tier creates new pile and restores tank air")
	check(session.state.validate_invariants(session.definitions).is_empty(), "no duplicate reference across recovery piles")
	record.money = 700
	player.global_position = shop.counter.global_position + Vector3(0, 0, 2)
	check(session.progression.try_purchase(&"local", &"unlimited_breathing", UpgradeDefinition.Source.SHOP).ok and not is_finite(session.progression.max_air_seconds(&"local")), "tank prerequisite unlocks $700 unlimited breathing")
	player.global_position = Vector3(0, -2.0, 80)
	swim.step_environment(100.0)
	check(float(record.air_remaining) == 60.0 and bool(record.immersed) and main.oxygen_meter.visible and swim._markers.size() == 2, "unlimited tier swims without finite air drain while recovery markers persist")
	var restored := RunState.from_snapshot(session.state.to_snapshot())
	check(restored.recovery_piles.size() == 2 and restored.next_recovery_serial == 3 and restored.validate_invariants(session.definitions).is_empty(), "save round-trip retains distinct piles, ownership and next serial")
	print("P18_FAINT drops=3+bag piles=%d air=10/60/infinite money=%d required=%d failures=%d" % [session.state.recovery_piles.size(), int(record.money), session.state.required_total, failures])
	quit(0 if failures == 0 else 1)


func _world_items(session: RunSession, definition_id: StringName, count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.location == ItemRecord.Location.WORLD and item.definition_id == definition_id:
			result.append(item.item_id)
			if result.size() == count:
				break
	return result


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "underwater faint screenshot saved")
	print("P18_CAPTURE " + path)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P18 FAIL: " + message)
