extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := (load("res://tests/scenes/placement_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	var settings := SettingsStore.new()
	settings.settings_path = "user://p20-completion.cfg"
	lab.add_child(settings)
	var definitions := ManifestGenerator.new().load_catalog()
	var state := RunState.new()
	state.run_id = "completion-fixture"
	state.seed_text = "completion-fixture"
	state.initial_manifest_hash = "fixture-manifest"
	state.add_player()
	var waste := ItemRecord.new()
	waste.item_id = &"waste:collected"
	waste.definition_id = &"waste_can"
	waste.home_section_id = &"home:lounge"
	waste.home_zone_id = &"lounge"
	waste.location = ItemRecord.Location.COLLECTED
	waste.container_id = &"collection:fixture"
	state.add_item(waste)
	var chair := ItemRecord.new()
	chair.item_id = &"chair:last"
	chair.definition_id = &"prop_beach_chair"
	chair.home_section_id = &"home:lounge"
	chair.home_zone_id = &"lounge"
	chair.last_world_transform = Transform3D(Basis.IDENTITY, Vector3(-0.8, 0.05, 3))
	chair.dirty_patches_remaining = [&"seat"]
	state.add_item(chair)
	var session := RunSession.new()
	session.initialize(state, definitions)
	lab.add_child(session)
	var manager := ItemViewManager.new()
	session.add_child(manager)
	session.item_view_manager = manager
	manager.configure(session, definitions, {&"recovery:lab": Vector3(0, 0.05, 4)})
	manager.build_views()
	var player := lab.get_node("%Player") as BeachPlayer
	player.configure(settings, session)
	var placement := PlacementService.new()
	session.add_child(placement)
	placement.configure(session, lab, player)
	var canvas := CanvasLayer.new()
	lab.add_child(canvas)
	var results := (load("res://scenes/ui/results_view.tscn") as PackedScene).instantiate() as ResultsView
	canvas.add_child(results)
	session.run_completed.connect(func(receipt: Dictionary) -> void: results.show_receipt(receipt, player, session))
	await physics_frame
	check(session.progress_service.completed_waste == 1 and session.progress_service.completed_props == 0 and state.completion_receipt.is_empty(), "only truck-collected waste is initially complete; dirty chair is not")
	check(session.item_store.try_hold(&"local", chair.item_id).ok, "last Synty chair is held from the playable placement lab")
	var slot := &"row:lab:chairs:000"
	player.global_position = placement.slot_transform(slot).origin + Vector3(0, 0, 1.8)
	check(not placement.try_place(&"local", slot).ok and session.progress_service.completed_props == 0, "dirty chair cannot count through placement")
	chair.dirty_patches_remaining.clear()
	session.finalize_action(PackedStringArray([str(chair.item_id)]))
	check(session.progress_service.completed_props == 0 and state.completion_receipt.is_empty(), "cleaning alone does not finish reusable prop")
	var first_signal := {"snapshot": {}, "revision": -1}
	session.progress_changed.connect(func(_waste: int, _props: int, _total: int) -> void:
		if (first_signal.snapshot as Dictionary).is_empty() and chair.location == ItemRecord.Location.SLOTTED:
			first_signal.snapshot = state.to_snapshot()
			first_signal.revision = state.revision
	)
	var before := state.revision
	check(placement.try_place(&"local", slot).ok, "final clean chair snaps into its real slot")
	var group := state.group_states[&"home:lounge/beach_chair"] as Dictionary
	var section := state.section_states[&"home:lounge"] as Dictionary
	var zone := state.zone_states[&"lounge"] as Dictionary
	var receipt := state.completion_receipt.duplicate(true)
	check(state.revision == before + 1 and int(first_signal.revision) == state.revision, "final placement produces exactly one revision before its first public signal")
	check(bool(group.complete) and bool(group.reward_claimed) and int(group.completion_transitions) == 1 and int((state.players[&"local"] as Dictionary).money) == 15, "group completion and first $15 reward commit atomically")
	check(bool(section.complete) and bool(section.restored_once) and bool(zone.restored_once), "home section and zone restore in final placement commit")
	check(int(receipt.get("required_total", 0)) == 2 and int(receipt.get("collected_waste", 0)) == 1 and int(receipt.get("slotted_props", 0)) == 1 and int(receipt.get("money", 0)) == 15, "immutable finish receipt contains exact counts and group money")
	var seen := first_signal.snapshot as Dictionary
	check(not (seen.get("completion_receipt", {}) as Dictionary).is_empty() and bool((seen.group_states[&"home:lounge/beach_chair"] as Dictionary).reward_claimed) and bool((seen.section_states[&"home:lounge"] as Dictionary).restored_once), "first public snapshot already includes reward, restoration and result")
	check(results.visible and session.results_open and paused, "results screen pauses gameplay after first finish")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P20-results.png")
	results.continue_roaming()
	check(not paused and not results.visible and not session.results_open, "Continue resumes roaming without clearing receipt")
	check(placement.try_remove(&"local", slot).ok, "chair can be removed after results")
	check(not bool(group.complete) and not bool(section.complete) and bool(section.restored_once) and bool(zone.restored_once) and state.completion_receipt == receipt, "current progress reverses but habitat and finish receipt persist")
	check(placement.try_place(&"local", slot).ok and int((state.players[&"local"] as Dictionary).money) == 15 and int(group.completion_transitions) == 2 and state.completion_receipt == receipt, "re-completion replays group transition without second payment or receipt")
	check(state.validate_invariants(definitions).is_empty() and RunState.from_snapshot(state.to_snapshot()).validate_invariants(definitions).is_empty(), "live and saved result state preserve ownership")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.settings_path))
	lab.free()
	await _full_beach_restoration()
	await _deep_reef_restoration()
	print("P20_COMPLETION waste=1 props=1 reward=15 transitions=2 restored=1 receipt=1 failures=%d" % failures)
	quit(failures)


func _full_beach_restoration() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "restoration-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "full beach opens for restoration flow")
	if session == null:
		main.free()
		return
	var section_id := &"arrival:start"
	var waste_ids: Array[StringName] = []
	var prop_ids: Array[StringName] = []
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if record.home_section_id != section_id or not record.required:
			continue
		var definition := session.definitions[record.definition_id] as ItemDefinition
		if definition.kind == ItemDefinition.Kind.WASTE:
			waste_ids.append(record.item_id)
		elif definition.kind == ItemDefinition.Kind.PROP:
			prop_ids.append(record.item_id)
	check(waste_ids.size() == 80 and prop_ids.size() == 10, "starter section has its authored 80 waste and 10 props")
	var placement := session.placement_service
	var changed := PackedStringArray()
	for item_id in prop_ids:
		var record := session.state.items[item_id] as ItemRecord
		var family := (session.definitions[record.definition_id] as ItemDefinition).sorting_family
		var chosen := StringName()
		for slot_key in placement.slots:
			var pool_id := StringName(str((placement.slots[slot_key] as Dictionary).pool_id))
			var pool := session.state.container_records[pool_id] as Dictionary
			var claim := StringName(str(pool.claim))
			if placement.occupant_for(slot_key).is_empty() and family in (pool.accepted_families as Array) and (claim.is_empty() or claim == family):
				chosen = slot_key
				break
		check(not chosen.is_empty(), "starter prop has a compatible authored slot")
		if chosen.is_empty():
			continue
		record.dirty_patches_remaining.clear()
		placement._commit_to_slot(item_id, chosen)
		changed.append(str(item_id))
	session.finalize_action(changed)
	var section := session.state.section_states[section_id] as Dictionary
	check(int(section.slotted_props) == 10 and not bool(section.restored_once), "clean placed props alone do not restore a littered section")
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	changed.clear()
	for item_id in waste_ids:
		var record := session.state.items[item_id] as ItemRecord
		var cell := station.first_free_cell()
		(station.table_record().cells as Dictionary)[cell] = item_id
		record.location = ItemRecord.Location.TABLE
		record.container_id = station.station_id
		record.slot_id = cell
		changed.append(str(item_id))
	session.finalize_action(changed)
	station._contents_committed()
	for item_id in waste_ids:
		check(station.try_sort(item_id, &"pmd").ok, "starter waste sorts through real station")
	check(station.try_seal(&"pmd").ok, "partial starter waste bin seals")
	check(int(section.collected_waste) == 0 and not bool(section.restored_once), "table, bins and container stage do not restore habitat")
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	var bag_ids: Array[StringName] = []
	for bag_key in session.state.bag_records:
		bag_ids.append(StringName(str(bag_key)))
	for bag_id in bag_ids:
		check(session.item_store.try_hold_bag(&"local", bag_id).ok and container.try_deposit_bag(&"local", bag_id).ok, "sealed starter bag reaches matching container")
	var before := session.state.revision
	check(session.collection_service.try_collect_containers(&"local").ok, "truck collects both starter bags")
	var nature := session.get_node("RestorationSection") as RestorationSection
	var section_node := nature.sections[section_id] as BeachSection
	check(session.state.revision == before + 1 and int(section.collected_waste) == 80 and bool(section.restored_once) and section_node.restoration_visual_root.visible, "truck collection restores starter habitat in its own revision")
	check(not bool((session.state.zone_states[&"arrival"] as Dictionary).restored_once), "larger arrival-zone reward waits for dunes too")
	check(section_node.restoration_visual_root.get_child_count() > 0 and (section_node.restoration_visual_root.get_child(0) as Node3D).name == "FoliagePalm", "restored shoreline reveals staged Synty palm, not square art")
	check(session.state.validate_invariants(session.definitions).is_empty(), "real collection/restoration fixture retains ownership and progress invariants")
	var original_size := root.size
	root.size = Vector2i(1280, 720)
	await process_frame
	var receipt_panel := main.collection_receipt.get_node("Panel") as Control
	check(main.collection_receipt.visible and main.guidance_panel.visible and main.guidance_label.text.contains("restored") and not main.guidance_panel.get_global_rect().intersects(receipt_panel.get_global_rect()) and not main.guidance_panel.get_global_rect().intersects(main.progress_panel.get_global_rect()), "720p collection, restoration notice and persistent progress occupy separate readable lanes")
	var player := session.get_node("Player") as BeachPlayer
	if "--capture" in OS.get_cmdline_user_args():
		var palm := section_node.restoration_visual_root.get_child(0) as Node3D
		player.global_position = palm.global_position + Vector3(-5, 0, 16)
		player.camera.look_at(palm.global_position + Vector3(0, 2, -3))
		await physics_frame
		await _capture("P27-hud-720.png")
	root.size = original_size
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P20-arrival-restored.png")
		var ui := main.get_node("UI") as CanvasLayer
		ui.hide()
		player.hand_rig.hide()
		await _capture("reference-arrival-restored.png")
		ui.show()
		player.hand_rig.show()
		await _capture_p25_views(player)
	main.free()


func _deep_reef_restoration() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "reef-completion-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "full beach opens for reef restoration")
	if session == null:
		main.free()
		return
	var player := session.get_node("Player") as BeachPlayer
	var progression := session.progression
	var player_record := session.state.players[&"local"] as Dictionary
	player_record.money = 490 # Fund the gear gate; the separate economy check proves $0-start reachability.
	player.global_position = progression.shop.counter.global_position + Vector3(0, 0, 2)
	for purchase_id in [&"cloth", &"knife", &"detector", &"oxygen_tank"]:
		check(progression.try_purchase(&"local", purchase_id, UpgradeDefinition.Source.SHOP).ok, "reef access gear purchases in the real shop: %s" % purchase_id)
	check(int(player_record.money) == 0 and progression.max_air_seconds(&"local") == 60.0, "reef flow owns all access gear at exact $490 cost")
	var nature := session.get_node("RestorationSection") as RestorationSection
	var station := session.sorting_stations[&"sorting:S3"] as SortingStation
	var container := session.waste_containers[&"container:S3:pmd"] as WasteContainer
	for section_id in [&"reef_west:outer", &"reef_west:coral"]:
		var waste_ids: Array[StringName] = []
		for item_value in session.state.items.values():
			var record := item_value as ItemRecord
			if record.home_section_id == section_id and record.required and (session.definitions[record.definition_id] as ItemDefinition).kind == ItemDefinition.Kind.WASTE:
				waste_ids.append(record.item_id)
		waste_ids.sort()
		check(waste_ids.size() == 250, "reef section has exactly 250 authored waste IDs: %s" % section_id)
		# Accelerate pickup/transport only: P17/P19 exercise detector and knife targeting;
		# every ID still passes through the live S3 table, bin, bag, container and truck.
		for start in range(0, waste_ids.size(), 200):
			var changed := PackedStringArray()
			var end := mini(start + 200, waste_ids.size())
			for index in range(start, end):
				var item_id := waste_ids[index]
				var record := session.state.items[item_id] as ItemRecord
				if record.location == ItemRecord.Location.ATTACHED:
					var site_id := StringName(str(record.attachment_id).get_slice("/", 0))
					(session.rescue_knife.sites[site_id] as RescueSite).remove_attachment(item_id)
				var cell := station.first_free_cell()
				check(not cell.is_empty(), "S3 table has room for the next reef item")
				if cell.is_empty():
					continue
				(station.table_record().cells as Dictionary)[cell] = item_id
				record.location = ItemRecord.Location.TABLE
				record.container_id = station.station_id
				record.slot_id = cell
				record.buried = false
				record.revealed = true
				changed.append(str(item_id))
			for site_key in session.state.rescue_states:
				var rescue := session.state.rescue_states[site_key] as Dictionary
				if StringName(str(rescue.home_section_id)) == section_id:
					var attached := false
					for attachment_text in rescue.attachment_ids:
						if (session.state.items[StringName(str(attachment_text))] as ItemRecord).location == ItemRecord.Location.ATTACHED:
							attached = true
					rescue.released = not attached
					if not attached:
						(session.rescue_knife.sites[site_key] as RescueSite).release_animal()
			session.finalize_action(changed)
			station._contents_committed()
			for index in range(start, end):
				check(station.try_sort(waste_ids[index], &"pmd").ok, "reef waste sorts through S3: %s" % waste_ids[index])
		var bag_ids: Array[StringName] = []
		for bag_key in session.state.bag_records:
			var bag := session.state.bag_records[bag_key] as Dictionary
			if str(bag.location) == "RACK" and StringName(str(bag.station_id)) == station.station_id:
				bag_ids.append(StringName(str(bag_key)))
		check(bag_ids.size() == 5, "250 reef items seal into five 50-item Synty bags")
		for bag_id in bag_ids:
			check(session.item_store.try_hold_bag(&"local", bag_id).ok and container.try_deposit_bag(&"local", bag_id).ok, "reef bag reaches S3 container")
		var collected := session.collection_service.try_collect_containers(&"local")
		check(collected.ok and int(collected.receipt.item_count) == 250, "truck collects entire reef section")
		var section := session.state.section_states[section_id] as Dictionary
		var visual := (nature.sections[section_id] as BeachSection).restoration_visual_root
		check(int(section.collected_waste) == 250 and bool(section.restored_once) and visual.visible, "reef section restores after real truck collection: %s" % section_id)
	check(bool((session.state.zone_states[&"reef_west"] as Dictionary).restored_once) and (nature.zone_roots[&"reef_west"] as Node3D).visible and nature.populations.has(&"zone:reef_west:01"), "both restored reef sections reveal the zone fish reward")
	check(session.state.validate_invariants(session.definitions).is_empty(), "500 collected reef IDs preserve save and ownership invariants")
	if "--capture" in OS.get_cmdline_user_args():
		player_record.air_remaining = 60.0
		player.global_position = Vector3(47, -1.9, 113)
		player.camera.look_at(Vector3(50, -2.9, 105))
		await physics_frame
		await create_timer(3.1).timeout
		await _capture("P26-reef-restored.png")
		player.global_position = Vector3(8, -1.9, 114)
		player.camera.look_at(Vector3(10, -1.6, 108))
		await physics_frame
		await _capture("P26-reef-fish.png")
	print("P26_REEF waste=500 bags=10 sections=2 zone=reef_west fish=1 failures=%d" % failures)
	main.free()


func _capture_p25_views(player: BeachPlayer) -> void:
	var views := [
		[Vector3(-70, 2, 9), Vector3(10, 2, 9), "P25-01-beachfront-after.png"],
		[Vector3(-15, 65, 135), Vector3(0, 0, 0), "P25-02-beach-layout-after.png"],
		[Vector3(36, 2.1, 21), Vector3(48, 0.7, 12), "P25-03-small-props-after.png"],
		[Vector3(-17, 2.1, 24), Vector3(-17, 1.7, -18), "P25-04-furniture-after.png"],
		[Vector3(-55, 3.3, 20), Vector3(-45, 4, -5), "P25-05-foliage-after.png"],
		[Vector3(30, -1.9, 111), Vector3(30, -2.6, 102), "P25-06-reef-after.png"],
	]
	for view in views:
		player.global_position = view[0]
		player.camera.look_at(view[1])
		await physics_frame
		await _capture(view[2])


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "completion capture saved")
	print("P20_CAPTURE " + path)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P20 FAIL: " + message)
