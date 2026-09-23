extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_msec()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/full_run"
	main.seed_input.text = "full-run-integration"
	var session := main.start_run() as RunSession
	if session == null or session.state.items.size() != 5740:
		_fail("full beach did not start with 5,740 records")
		return
	var player := session.get_node("Player") as BeachPlayer
	var placement := session.placement_service
	var waste_ids: Array[StringName] = []
	var prop_ids: Array[StringName] = []
	for value in session.state.items.values():
		var item := value as ItemRecord
		if not item.required:
			continue
		if (session.definitions[item.definition_id] as ItemDefinition).kind == ItemDefinition.Kind.PROP:
			prop_ids.append(item.item_id)
		else:
			waste_ids.append(item.item_id)
	waste_ids.sort()
	prop_ids.sort()
	if waste_ids.size() != 5400 or prop_ids.size() != 300:
		_fail("required waste/prop split changed")
		return
	var final_prop := StringName()
	for item_id in prop_ids:
		var item := session.state.items[item_id] as ItemRecord
		if item.home_section_id == &"arrival:start" and item.definition_id == &"prop_beach_chair":
			final_prop = item_id
			break
	if final_prop.is_empty():
		_fail("no final starter chair")
		return
	prop_ids.erase(final_prop)
	var staged := PackedStringArray()
	for item_id in prop_ids:
		var item := session.state.items[item_id] as ItemRecord
		var slot_id := _free_slot(placement, session, item)
		if slot_id.is_empty():
			_fail("no compatible slot for %s" % item_id)
			return
		item.dirty_patches_remaining.clear() # Accelerated setup; P16 separately exercises cloth cleaning.
		placement._commit_to_slot(item_id, slot_id)
		placement._ensure_slotted_view(item_id)
		staged.append(str(item_id))
	session.finalize_action(staged)
	var final_item := session.state.items[final_prop] as ItemRecord
	final_item.dirty_patches_remaining.clear()
	var final_slot := _free_slot(placement, session, final_item)
	if final_slot.is_empty() or session.progress_service.completed_props != 299:
		_fail("could not reserve the final prop slot")
		return
	print("FULL_RUN props_staged=299 final_slot=%s elapsed_ms=%d" % [final_slot, Time.get_ticks_msec() - started])

	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	for start in range(0, waste_ids.size(), 200):
		staged.clear()
		var end := mini(start + 200, waste_ids.size())
		for index in range(start, end):
			var item_id := waste_ids[index]
			var item := session.state.items[item_id] as ItemRecord
			if item.location == ItemRecord.Location.ATTACHED:
				var site_id := StringName(str(item.attachment_id).get_slice("/", 0))
				(session.rescue_knife.sites[site_id] as RescueSite).remove_attachment(item_id)
			var cell := station.first_free_cell()
			if cell.is_empty():
				_fail("S1 table filled before batch end")
				return
			(station.table_record().cells as Dictionary)[cell] = item_id
			item.location = ItemRecord.Location.TABLE
			item.container_id = station.station_id
			item.slot_id = cell
			item.buried = false
			item.revealed = true
			staged.append(str(item_id))
		for site_key in session.state.rescue_states:
			var rescue := session.state.rescue_states[site_key] as Dictionary
			if bool(rescue.released):
				continue
			var attached := false
			for attachment_text in rescue.attachment_ids:
				if (session.state.items[StringName(str(attachment_text))] as ItemRecord).location == ItemRecord.Location.ATTACHED:
					attached = true
			if not attached:
				rescue.released = true
				(session.rescue_knife.sites[site_key] as RescueSite).release_animal()
		session.finalize_action(staged)
		station._contents_committed()
		for index in range(start, end):
			if not station.try_sort(waste_ids[index], &"pmd").ok:
				_fail("sorting failed at item %d" % index)
				return
		var bag_ids: Array[StringName] = []
		for bag_key in session.state.bag_records:
			var bag := session.state.bag_records[bag_key] as Dictionary
			if str(bag.location) == "RACK" and StringName(str(bag.station_id)) == station.station_id:
				bag_ids.append(StringName(str(bag_key)))
		if bag_ids.size() != 4:
			_fail("expected four sealed bags for batch %d" % start)
			return
		for bag_id in bag_ids:
			if not session.item_store.try_hold_bag(&"local", bag_id).ok or not container.try_deposit_bag(&"local", bag_id).ok:
				_fail("bag transfer failed at batch %d" % start)
				return
		var collected := session.collection_service.try_collect_containers(&"local")
		if not collected.ok or int(collected.receipt.item_count) != 200:
			_fail("truck failed at batch %d" % start)
			return
		print("FULL_RUN collected=%d elapsed_ms=%d" % [session.progress_service.completed_waste, Time.get_ticks_msec() - started])
	if session.progress_service.completed_waste != 5400 or session.progress_service.completed_props != 299 or session.results_open:
		_fail("pre-final progress is not exactly 5,699")
		return
	if bool((session.state.section_states[&"arrival:start"] as Dictionary).restored_once):
		_fail("final starter section restored too early")
		return
	if not session.item_store.try_hold(&"local", final_prop).ok:
		_fail("could not hold the final chair")
		return
	player.global_position = placement.slot_transform(final_slot).origin + Vector3(0, 0, 1.8)
	if not placement.try_place(&"local", final_slot).ok:
		_fail("final chair would not snap into its authored slot")
		return
	var receipt := session.state.completion_receipt as Dictionary
	if not session.results_open or not paused or int(receipt.get("required_total", 0)) != 5700 or int(receipt.get("collected_waste", 0)) != 5400 or int(receipt.get("slotted_props", 0)) != 300:
		_fail("first full-run completion receipt did not latch")
		return
	if not bool((session.state.section_states[&"arrival:start"] as Dictionary).restored_once) or not session.state.validate_invariants(session.definitions).is_empty():
		_fail("completed full beach violates restoration or ownership")
		return
	var run_id := session.state.run_id
	if not bool(main.save_service.save_slot(&"manual").ok):
		_fail("completed full beach would not save")
		return
	var loaded := main.load_run(run_id, &"manual")
	if not bool(loaded.ok):
		_fail("completed full beach would not reload")
		return
	session = main.run_root as RunSession
	var restored_receipt := session.state.completion_receipt as Dictionary
	var persisted_receipt := JSON.parse_string(JSON.stringify(receipt)) as Dictionary
	if not main.results_view.visible or not paused or session.progress_service.completed_waste != 5400 or session.progress_service.completed_props != 300 or restored_receipt != persisted_receipt or not session.state.validate_invariants(session.definitions).is_empty():
		_fail("reloaded full completion lost progress, receipt, or results")
		return
	main.results_view.continue_roaming()
	if paused or session.results_open or session.state.completion_receipt != persisted_receipt:
		_fail("completed run could not continue roaming with its receipt")
		return
	var earned_money := int((session.state.players[&"local"] as Dictionary).money)
	if not session.placement_service.try_remove(&"local", final_slot).ok or session.progress_service.completed_props != 299 or session.state.completion_receipt != persisted_receipt:
		_fail("post-results chair removal lost the original receipt")
		return
	if not bool(main.save_service.save_slot(&"manual").ok) or not bool(main.load_run(run_id, &"manual").ok):
		_fail("post-results incomplete progress would not save and reload")
		return
	session = main.run_root as RunSession
	if main.results_view.visible or paused or session.progress_service.completed_props != 299 or session.state.completion_receipt != persisted_receipt or not bool((session.state.section_states[&"arrival:start"] as Dictionary).restored_once):
		_fail("post-results reload lost incomplete progress, receipt, or restoration")
		return
	if not session.placement_service.try_place(&"local", final_slot).ok or session.progress_service.completed_props != 300 or int((session.state.players[&"local"] as Dictionary).money) != earned_money or session.state.completion_receipt != persisted_receipt or not session.state.validate_invariants(session.definitions).is_empty():
		_fail("replacing the post-results chair changed its receipt, reward, or ownership")
		return
	print("FULL_RUN_COMPLETE waste=5400 props=300 results=1 receipt=1 reloaded=2 roam_replacement=1 elapsed_ms=%d" % (Time.get_ticks_msec() - started))
	quit()


func _free_slot(placement: PlacementService, session: RunSession, item: ItemRecord) -> StringName:
	var family := (session.definitions[item.definition_id] as ItemDefinition).sorting_family
	for slot_key in placement.slots:
		var pool_id := StringName(str((placement.slots[slot_key] as Dictionary).pool_id))
		var pool := session.state.container_records[pool_id] as Dictionary
		var claim := StringName(str(pool.claim))
		if not placement.occupant_for(slot_key).is_empty() or family not in (pool.accepted_families as Array) or (not claim.is_empty() and claim != family):
			continue
		if claim.is_empty() and (pool.accepted_families as Array).size() > 1 and not placement._shared_claim_is_safe(pool_id, family, item.item_id):
			continue
		return StringName(str(slot_key))
	return StringName()


func _fail(message: String) -> void:
	push_error("FULL_RUN: " + message)
	quit(1)
