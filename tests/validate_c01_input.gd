extends SceneTree

const STAGE := Transform3D(Basis.IDENTITY, Vector3(-74, 10, 4.6))
const OFFSTAGE := Transform3D(Basis.IDENTITY, Vector3(-68, 10, 4.6))
const TOOLS := [&"stick", &"cloth", &"sand_cleaner", &"vacuum", &"detector", &"knife"]

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/c01"
	main.seed_input.text = "c01-context"
	var session := main.start_run() as RunSession
	var player := session.get_node("Player") as BeachPlayer
	var record := session.state.players[&"local"] as Dictionary
	player.set_physics_process(false)
	session.swim_service.set_physics_process(false)
	var bucket: ItemRecord
	var can: ItemRecord
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.definition_id == &"prop_bucket" and bucket == null and item.location == ItemRecord.Location.WORLD:
			bucket = item
		if item.definition_id == &"waste_can" and can == null and item.location == ItemRecord.Location.WORLD:
			can = item
	check(bucket != null and can != null, "real beach contains a clean bucket and can")
	if bucket == null or can == null:
		quit(failures)
		return
	check(session.item_store.try_collect(&"local", can.item_id).ok, "setup collects original can")
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	check(station.try_unload(&"local").ok and station.try_sort(can.item_id, &"pmd").ok, "setup sorts through real S1 table")
	var sealed := station.try_seal(&"pmd")
	check(sealed.ok, "setup seals a physical bag")
	if not sealed.ok:
		quit(failures)
		return
	var bag_id := StringName(str(sealed.receipt.bag_id))
	check(session.item_store.try_hold_bag(&"local", bag_id).ok and session.item_store.try_throw(&"local", STAGE, Vector3.ZERO).ok, "setup moves bag into input area")
	player.carry.refresh_hand_visuals()
	for tool in TOOLS:
		if tool not in record.owned_tools:
			(record.owned_tools as Array[StringName]).append(tool)
		record.equipped_handheld_ids = [tool] as Array[StringName]
		record.active_slot = 0
		session.progression.refresh_tool_visual()
		var bag := session.state.bag_records[bag_id] as Dictionary
		bag.world_transform = ItemRecord._transform_to_array(OFFSTAGE)
		bag.sleeping = true
		var bag_view := station.bag_view_for(bag_id)
		bag_view.restore_from_record()
		bucket.last_world_transform = STAGE
		bucket.sleeping = true
		var item_view := session.item_view_manager.view_for(bucket.item_id)
		item_view.restore_from_record()
		check(await _click_target(player, session, bucket.item_id, "hold") and bucket.location == ItemRecord.Location.HELD, "%s picks up clean prop through primary input" % tool)
		if bucket.location == ItemRecord.Location.HELD:
			check(session.item_store.try_throw(&"local", STAGE, Vector3.ZERO).ok, "prop returns to world for next tool")
			player.carry.cancel_all_presentations()
			player.carry.refresh_hand_visuals()
		bucket.last_world_transform = OFFSTAGE
		bucket.sleeping = true
		item_view = session.item_view_manager.view_for(bucket.item_id)
		item_view.restore_from_record()
		bag.world_transform = ItemRecord._transform_to_array(STAGE)
		bag.sleeping = true
		bag_view.restore_from_record()
		check(await _click_target(player, session, bag_id, "hold_bag") and str(bag.location) == "HELD", "%s picks up sealed bag through primary input" % tool)
		if str(bag.location) == "HELD":
			check(session.item_store.try_throw(&"local", STAGE, Vector3.ZERO).ok, "sealed bag returns to world for next tool")
			player.carry.refresh_hand_visuals()
	check(session.state.validate_invariants(session.definitions).is_empty(), "tool-context pickup preserves original item and bag ownership")
	print("C01_CONTEXT_INPUT tools=%d bucket=%s bag=%s failures=%d" % [TOOLS.size(), bucket.item_id, bag_id, failures])
	quit(failures)


func _click_target(player: BeachPlayer, session: RunSession, target_id: StringName, expected_action: String) -> bool:
	player.global_position = STAGE.origin + Vector3(0, -0.1, 1.4)
	player.velocity = Vector3.ZERO
	player.camera.look_at(STAGE.origin + Vector3.UP * 0.1)
	await physics_frame
	var target := player.interactor.update_target()
	if str(target.get("id", "")) != str(target_id) or not (target.get("actions", PackedStringArray()) as PackedStringArray).has(expected_action):
		print("C01_AIM expected=%s action=%s actual=%s actions=%s reason=%s" % [target_id, expected_action, target.get("id", ""), target.get("actions", []), target.get("reason", "")])
		return false
	var revision := session.state.revision
	player.set_physics_process(true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	for _index in range(3):
		await physics_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await physics_frame
	player.set_physics_process(false)
	return session.state.revision == revision + 1


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("C01 FAIL: " + message)
