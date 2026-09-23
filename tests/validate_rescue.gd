extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var generator := ManifestGenerator.new()
	var first := generator.generate("rescue-fixture")
	var second := generator.generate("rescue-fixture")
	check(first.ok and second.ok and first.manifest_hash == second.manifest_hash, "same seed fixes all rescue site and attachment choices")
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "rescue-fixture"
	var session := main.start_run() as RunSession
	check(session != null and session.state.required_total == 5700, "rescue beach starts with unchanged required denominator")
	if session == null:
		quit(1)
		return
	var state := session.state
	var player := session.get_node("Player") as BeachPlayer
	var player_record := state.players[&"local"] as Dictionary
	var knife := session.rescue_knife
	var shop := session.progression.shop
	check(state.rescue_states.size() == 12 and knife.sites.size() == 12, "24 original required attachments form 12 paired rescue sites")
	var ids: Array[String] = []
	for site_key in state.rescue_states:
		ids.append(str(site_key))
	ids.sort()
	for site_text in ids:
		var roster := (state.rescue_states[StringName(site_text)] as Dictionary).attachment_ids as Array
		check(roster.size() == 2 and (state.items[StringName(str(roster[0]))] as ItemRecord).home_section_id == (state.items[StringName(str(roster[1]))] as ItemRecord).home_section_id, "site %s pairs one home section" % site_text)
		var site := knife.sites[StringName(site_text)] as RescueSite
		var floor_ray := PhysicsRayQueryParameters3D.create(site.global_position + Vector3.UP * 2.0, site.global_position + Vector3.DOWN * 10.0, 1)
		var floor_hit := player.get_world_3d().direct_space_state.intersect_ray(floor_ray)
		check(session.swim_service.water.contains_horizontal(site.global_position) and _above_floor(player, site.global_position), "site %s is in swimmable water above the world floor; pos=%s floor=%s collider=%s" % [site_text, site.global_position, floor_hit.get("position", Vector3.ZERO), floor_hit.get("collider", null)])
	var first_site_id := StringName(ids[0])
	var first_site := knife.sites[first_site_id] as RescueSite
	var first_roster := (state.rescue_states[first_site_id] as Dictionary).attachment_ids as Array
	var first_item_id := StringName(str(first_roster[0]))
	check(await _aim(player, first_site.attachment_area(first_item_id)), "first animal attachment is physically aimable")
	check(not knife.try_cut(first_item_id).ok and (state.items[first_item_id] as ItemRecord).location == ItemRecord.Location.ATTACHED, "unowned knife cannot alter an animal")
	player_record.money = 570
	player.global_position = shop.counter.global_position + Vector3(0, 0, 2)
	check(session.progression.try_purchase(&"local", &"cloth", UpgradeDefinition.Source.SHOP).ok and session.progression.try_purchase(&"local", &"knife", UpgradeDefinition.Source.SHOP).ok and session.progression.try_purchase(&"local", &"detector", UpgradeDefinition.Source.SHOP).ok and session.progression.try_purchase(&"local", &"oxygen_tank", UpgradeDefinition.Source.SHOP).ok and session.progression.try_purchase(&"local", &"flippers", UpgradeDefinition.Source.SHOP).ok, "physical shop sells the $570 access and swim package")
	player.global_position = shop.rack.global_position + Vector3(0, 0, 2)
	check(session.progression.try_equip(&"local", &"knife", 1).ok and knife.is_active() and session.progression.max_air_seconds(&"local") == 60.0 and is_equal_approx(player.movement.swim_speed, 4.0), "knife equips at physical rack with affordable swim gear active")
	var first_area := first_site.attachment_area(first_item_id)
	player.global_position = first_area.global_position + Vector3(0, 0, 8)
	player.camera.look_at(first_area.global_position)
	check(not knife.try_cut(first_item_id).ok and (state.items[first_item_id] as ItemRecord).location == ItemRecord.Location.ATTACHED, "out-of-range click leaves attachment unchanged")
	check(await _aim(player, first_area), "first attachment can be reacquired after moving close")
	var wall := StaticBody3D.new()
	wall.collision_layer = 8
	wall.collision_mask = 0
	wall.position = player.camera.global_position.lerp(first_area.global_position, 0.55)
	player.get_parent().add_child(wall)
	var collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(0.8, 0.8, 0.8)
	collision.shape = wall_shape
	wall.add_child(collision)
	await physics_frame
	check(not knife.try_cut(first_item_id).ok and (state.items[first_item_id] as ItemRecord).location == ItemRecord.Location.ATTACHED, "solid wall blocks cutting without mutation")
	wall.queue_free()
	await physics_frame
	check(await _aim(player, first_area), "attachment remains reachable after wall removal")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P19-rescue-before.png")
	var first_cut := knife.try_cut(first_item_id)
	check(first_cut.ok and str(first_cut.receipt.destination) == "bag" and not bool(first_cut.receipt.animal_freed) and (state.items[first_item_id] as ItemRecord).location == ItemRecord.Location.BAG, "first cut bags same waste ID but does not release animal")
	check(StringName("definition:%s" % (state.items[first_item_id] as ItemRecord).definition_id) in (player_record.discoveries as Array[StringName]), "bagged knife attachment unlocks its scanner type")
	player_record.bag_capacity = 1
	var second_item_id := StringName(str(first_roster[1]))
	check(await _aim(player, first_site.attachment_area(second_item_id)), "remaining attachment is aimable")
	var second_cut := knife.try_cut(second_item_id)
	check(second_cut.ok and str(second_cut.receipt.destination) == "world" and bool(second_cut.receipt.animal_freed) and (state.items[second_item_id] as ItemRecord).location == ItemRecord.Location.WORLD, "full bag still cuts final attachment and drops waste nearby")
	check(StringName("definition:%s" % (state.items[second_item_id] as ItemRecord).definition_id) not in (player_record.discoveries as Array[StringName]), "full-bag dropped attachment remains undiscovered")
	check(bool((state.rescue_states[first_site_id] as Dictionary).released) and first_site._route_tween != null and first_site._route_tween.is_running(), "animal release latches and starts authored local route once")
	check(not knife.try_cut(second_item_id).ok and (state.items[second_item_id] as ItemRecord).location == ItemRecord.Location.WORLD, "repeated knife click cannot duplicate detached litter")
	await physics_frame
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P19-rescue-after.png")
	var cut_count := 2
	for site_text in ids:
		if site_text == str(first_site_id):
			continue
		var site_id := StringName(site_text)
		var site := knife.sites[site_id] as RescueSite
		var roster := (state.rescue_states[site_id] as Dictionary).attachment_ids as Array
		for item_text in roster:
			var item_id := StringName(str(item_text))
			if await _aim(player, site.attachment_area(item_id)):
				var result := knife.try_cut(item_id)
				check(result.ok, "site %s cuts attachment %s in water" % [site_id, item_id])
				if result.ok:
					cut_count += 1
			else:
				check(false, "site %s attachment %s remains aimable and accessible" % [site_id, item_id])
		check(bool((state.rescue_states[site_id] as Dictionary).released), "site %s freed its animal" % site_id)
	check(cut_count == 24, "all 24 seeded attachments can be cut with available swim equipment")
	var detached := 0
	for item_value in state.items.values():
		var record := item_value as ItemRecord
		if not record.attachment_id.is_empty():
			check(record.location != ItemRecord.Location.ATTACHED and record.required and record.rescuer_id == &"local", "attachment %s is original required waste with a rescuer" % record.item_id)
			detached += 1
	check(detached == 24 and state.required_total == 5700, "rescues add no animal objective or extra litter")
	check(state.validate_invariants(session.definitions).is_empty(), "all released sites and waste ownership remain valid")
	var restored := RunState.from_snapshot(state.to_snapshot())
	check(restored.rescue_states.size() == 12 and restored.validate_invariants(session.definitions).is_empty(), "snapshot latches 12 freed animals without re-entanglement")
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	var category_index := (session.definitions[(state.items[first_item_id] as ItemRecord).definition_id] as ItemDefinition).waste_category
	var category := SortingStation.CATEGORIES[category_index] as StringName
	player_record.bag_capacity = 2
	check(session.progression.try_switch_tool(&"local").ok and await _click_world_item(player, session, second_item_id), "full-bag cut can be collected through aimed stick input after making room")
	check(station.try_unload(&"local").ok and (state.items[first_item_id] as ItemRecord).location == ItemRecord.Location.TABLE, "rescued ring unloads at the real sorting table")
	var later_detached_id := StringName(str(((state.rescue_states[StringName(ids[1])] as Dictionary).attachment_ids as Array)[0]))
	check(session.item_store.try_collect(&"local", later_detached_id).ok and StringName("definition:%s" % (state.items[later_detached_id] as ItemRecord).definition_id) in (player_record.discoveries as Array[StringName]), "stick collection of later dropped attachment unlocks its scanner type")
	check(session.item_store.try_throw(&"local", (state.items[later_detached_id] as ItemRecord).last_world_transform, Vector3.ZERO).ok, "collected attachment can be returned to world without duplicate ownership")
	check(station.try_sort(first_item_id, category).ok, "rescued ring sorts under its original category")
	var seal := station.try_seal(category)
	check(seal.ok, "rescued ring seals as ordinary waste")
	if seal.ok:
		var bag_id := StringName(str(seal.receipt.bag_id))
		check(session.item_store.try_hold_bag(&"local", bag_id).ok, "rescued ring bag can be carried from the rack")
		var container := session.waste_containers[StringName("container:S1:%s" % category)] as WasteContainer
		check(container.try_deposit_bag(&"local", bag_id).ok, "rescued ring bag deposits into its matching container")
		check(session.collection_service.try_collect_containers(&"local").ok and (state.items[first_item_id] as ItemRecord).location == ItemRecord.Location.COLLECTED, "truck collects the same rescued waste ID without crediting an animal objective")
	check(state.required_total == 5700 and state.validate_invariants(session.definitions).is_empty(), "rescued-waste collection preserves required total and ownership")
	print("P19_RESCUE sites=%d attachments=%d bag=%d world=%d required=%d failures=%d" % [state.rescue_states.size(), detached, (player_record.trash_bag as Array).size(), cut_count - (player_record.trash_bag as Array).size(), state.required_total, failures])
	quit(0 if failures == 0 else 1)


func _aim(player: BeachPlayer, area: Area3D) -> bool:
	if area == null:
		return false
	for offset in [Vector3(0, 0, 1.0), Vector3(0, 0, -1.0), Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0), Vector3(0.8, 0, 0.8), Vector3(-0.8, 0, 0.8)]:
		player.global_position = area.global_position + offset
		player.camera.look_at(area.global_position)
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, area.global_position, PlayerInteractor.TARGET_MASK, [player.get_rid()])
		query.collide_with_areas = true
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == area:
			player.interactor.update_target()
			return true
	return false


func _click_world_item(player: BeachPlayer, session: RunSession, item_id: StringName) -> bool:
	var view := session.item_view_manager.view_for(item_id)
	if view == null:
		return false
	var aimed := false
	for offset in [Vector3(0, 0, 1.0), Vector3(0, 0, -1.0), Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0)]:
		player.global_position = view.global_position + offset
		player.camera.look_at(view.global_position + Vector3.UP * 0.05)
		await physics_frame
		if str(player.interactor.update_target().get("id", "")) == str(item_id):
			aimed = true
			break
	if not aimed:
		return false
	var revision := session.state.revision
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	for _index in range(3):
		await physics_frame
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await physics_frame
	print("C01_RESCUE_INPUT target=%s tool=%s bag=%d location=%s revision=%d->%d" % [player.interactor.current_target.get("id", ""), session.progression.active_tool_id(&"local"), (session.state.players[&"local"].trash_bag as Array).size(), ItemRecord.LOCATION_NAMES[(session.state.items[item_id] as ItemRecord).location], revision, session.state.revision])
	return (session.state.items[item_id] as ItemRecord).location == ItemRecord.Location.BAG and session.state.revision == revision + 1


func _above_floor(player: BeachPlayer, position: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 2.0, position + Vector3.DOWN * 10.0, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and position.y > float((hit.position as Vector3).y) + 0.08


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "rescue screenshot saved")
	print("P19_CAPTURE " + path)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P19 FAIL: " + message)
