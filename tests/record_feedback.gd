extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/p27_movie"
	main.seed_input.text = "feedback-sequence"
	var session := main.start_run() as RunSession
	if session == null:
		push_error("Feedback recording could not start the beach")
		quit(1)
		return
	var player := session.get_node("Player") as BeachPlayer
	var placement := session.placement_service
	var prop_ids: Array[StringName] = []
	var waste_ids: Array[StringName] = []
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.home_section_id != &"arrival:start" or not item.required:
			continue
		if (session.definitions[item.definition_id] as ItemDefinition).kind == ItemDefinition.Kind.PROP:
			prop_ids.append(item.item_id)
		else:
			waste_ids.append(item.item_id)
	prop_ids.sort()
	waste_ids.sort()
	if prop_ids.size() != 10 or waste_ids.size() != 80:
		push_error("Feedback recording starter-section counts changed")
		quit(1)
		return
	var last_prop := StringName()
	for item_id in prop_ids:
		if (session.state.items[item_id] as ItemRecord).definition_id == &"prop_beach_chair":
			last_prop = item_id
			break
	if last_prop.is_empty():
		last_prop = prop_ids[prop_ids.size() - 1]
	prop_ids.erase(last_prop)
	var staged := PackedStringArray()
	for item_id in prop_ids:
		var item := session.state.items[item_id] as ItemRecord
		var family := (session.definitions[item.definition_id] as ItemDefinition).sorting_family
		for slot_key in placement.slots:
			var pool_id := StringName(str((placement.slots[slot_key] as Dictionary).pool_id))
			var pool := session.state.container_records[pool_id] as Dictionary
			var claim := StringName(str(pool.claim))
			if placement.occupant_for(slot_key).is_empty() and family in (pool.accepted_families as Array) and (claim.is_empty() or claim == family):
				item.dirty_patches_remaining.clear()
				placement._commit_to_slot(item_id, slot_key)
				staged.append(str(item_id))
				break
	if staged.size() != 9:
		push_error("Feedback recording could not stage starter props")
		quit(1)
		return
	session.finalize_action(staged)
	main._clear_notices()
	var prop := session.state.items[last_prop] as ItemRecord
	prop.dirty_patches_remaining.clear()
	var slot_id := StringName()
	var family := (session.definitions[prop.definition_id] as ItemDefinition).sorting_family
	for slot_key in placement.slots:
		var pool_id := StringName(str((placement.slots[slot_key] as Dictionary).pool_id))
		var pool := session.state.container_records[pool_id] as Dictionary
		var claim := StringName(str(pool.claim))
		if placement.occupant_for(slot_key).is_empty() and family in (pool.accepted_families as Array) and (claim.is_empty() or claim == family):
			slot_id = slot_key
			break
	if slot_id.is_empty():
		push_error("Feedback recording has no final prop slot")
		quit(1)
		return
	var prop_position := prop.last_world_transform.origin
	player.global_position = prop_position + Vector3(0, 0, 1.6)
	player.camera.look_at(prop_position + Vector3.UP * 0.45)
	await create_timer(1.2).timeout
	var target := player.interactor.update_target()
	_check(StringName(str(target.get("id", ""))) == last_prop, "aim at the last Synty prop")
	player.carry._hold_target(target)
	_check(prop.location == ItemRecord.Location.HELD, "pick up the last Synty prop")
	await create_timer(0.8).timeout
	player.carry._on_throw_requested()
	_check(prop.location == ItemRecord.Location.WORLD, "throw the prop")
	await create_timer(1.1).timeout
	_check(session.item_store.try_hold(&"local", last_prop).ok, "pick the thrown prop back up")
	player.carry.refresh_hand_visuals()
	await create_timer(0.6).timeout
	var destination := placement.slot_transform(slot_id).origin
	player.global_position = destination + Vector3(0, 0, 2.3)
	player.camera.look_at(destination + Vector3.UP * 0.55)
	await create_timer(0.6).timeout
	_check(placement.try_place(&"local", slot_id).ok, "snap the last prop and show group sweep")
	await create_timer(1.3).timeout

	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	staged.clear()
	for item_id in waste_ids:
		var item := session.state.items[item_id] as ItemRecord
		var cell := station.first_free_cell()
		(station.table_record().cells as Dictionary)[cell] = item_id
		item.location = ItemRecord.Location.TABLE
		item.container_id = station.station_id
		item.slot_id = cell
		staged.append(str(item_id))
	session.finalize_action(staged)
	station._contents_committed()
	for item_id in waste_ids:
		_check(station.try_sort(item_id, &"pmd").ok, "sort starter waste")
	_check(station.try_seal(&"pmd").ok, "seal starter bags")
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	for bag_key in session.state.bag_records.keys():
		var bag_id := StringName(str(bag_key))
		_check(session.item_store.try_hold_bag(&"local", bag_id).ok and container.try_deposit_bag(&"local", bag_id).ok, "deposit starter bag")
	var nature := session.get_node("RestorationSection") as RestorationSection
	var section := nature.sections[&"arrival:start"] as BeachSection
	var palm := section.restoration_visual_root.get_child(0) as Node3D
	player.global_position = palm.global_position + Vector3(-5, 0, 16)
	player.camera.look_at(palm.global_position + Vector3(0, 2, -3))
	await create_timer(0.8).timeout
	_check(session.collection_service.try_collect_containers(&"local").ok, "truck collection restores the starter shore")
	await create_timer(2.5).timeout
	_check(bool((session.state.section_states[&"arrival:start"] as Dictionary).restored_once), "starter shore restored")
	_check(session.state.validate_invariants(session.definitions).is_empty(), "recording preserves item ownership")
	print("P27_FEEDBACK pickup=1 throw=1 snap=1 sweep=1 restoration=1 failures=%d" % failures)
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P27 feedback: " + message)
