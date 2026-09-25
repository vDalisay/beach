extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--menu-only" in OS.get_cmdline_user_args():
		var menu_main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
		root.add_child(menu_main)
		menu_main.save_service.save_root = "user://test_runs/p24"
		menu_main.show_menu()
		menu_main.load_button.pressed.emit()
		await RenderingServer.frame_post_draw
		var menu_path := ProjectSettings.globalize_path("res://docs/handoffs/images/P24-load-menu.png")
		_check(root.get_texture().get_image().save_png(menu_path) == OK, "load-menu screenshot captured")
		menu_main.free()
		quit(failures)
		return
	var generator := ManifestGenerator.new()
	var generated := generator.generate("save-fixture")
	_check(bool(generated.ok), "manifest generated")
	var state := generator.create_run_state(generated, "run_save_%d" % Time.get_ticks_msec())
	var session := RunSession.new()
	session.initialize(state, generated.definitions)
	root.add_child(session)
	var saver := SaveService.new()
	saver.save_root = "user://test_runs/p24"
	root.add_child(saver)
	var first := saver.write_snapshot(&"beach_01", state.run_id, &"manual", state.to_snapshot())
	_check(bool(first.ok), "first generation: %s" % first.get("message", ""))
	var loaded := saver.load_slot(&"beach_01", state.run_id, &"manual")
	_check(bool(loaded.ok), "load first generation: %s" % loaded.get("message", ""))
	if bool(loaded.ok):
		_check(_equivalent(state.to_snapshot(), (loaded.state as RunState).to_snapshot()), "initial semantic snapshot roundtrip matches")
	var same_seed := generator.create_run_state(generated, "run_other_%d" % Time.get_ticks_msec())
	_check(same_seed.run_id != state.run_id and bool(saver.write_snapshot(&"beach_01", same_seed.run_id, &"manual", same_seed.to_snapshot()).ok), "same-seed second run saves under distinct run ID")
	var other := saver.load_slot(&"beach_01", same_seed.run_id, &"manual")
	_check(bool(other.ok) and int(((other.state as RunState).players[&"local"] as Dictionary).money) == 0 and (other.state as RunState).bag_records.is_empty(), "same-seed second run starts with fresh money and equipment")
	var slot_folder := saver.save_root.path_join("beach_01").path_join(state.run_id).path_join("manual")
	var blocked := FileAccess.open("user://test_runs/p24/blocked_root", FileAccess.WRITE)
	_check(blocked != null, "failure fixture created under test save root")
	if blocked != null:
		blocked.store_string("not a directory")
		blocked.close()
	var prior_root := saver.save_root
	saver.save_root = "user://test_runs/p24/blocked_root"
	_check(not bool(saver.write_snapshot(&"beach_01", state.run_id, &"manual", state.to_snapshot()).ok), "write failure reports failure")
	saver.save_root = prior_root
	_check(bool(saver.load_slot(&"beach_01", state.run_id, &"manual").ok), "write failure retained previous generation")
	state.elapsed_active_seconds = 12.0
	_check(bool(saver.write_snapshot(&"beach_01", state.run_id, &"manual", state.to_snapshot()).ok), "second generation written")
	var latest_path := slot_folder.path_join("B.json")
	var malformed := (saver._read_generation(latest_path).envelope as Dictionary).duplicate(true)
	var malformed_payload := malformed.payload as Dictionary
	malformed_payload.schema_version = 99
	malformed.payload = JSON.stringify(malformed_payload, "", true, true)
	malformed.checksum = saver._generation_checksum(malformed)
	var broken := FileAccess.open(latest_path, FileAccess.WRITE)
	if broken != null:
		broken.store_string(JSON.stringify(malformed, "", true, true))
		broken.close()
	_check(bool(saver.load_slot(&"beach_01", state.run_id, &"manual").ok), "checksum-valid but schema-invalid latest falls back before scene replacement")
	_check(bool(saver.write_snapshot(&"beach_01", state.run_id, &"manual", state.to_snapshot()).ok) and int(saver._read_generation(latest_path).sequence) == 3 and int(saver._read_generation(slot_folder.path_join("A.json")).sequence) == 1, "a write after the latest file changed on disk replaces it and keeps the valid generation")
	broken = FileAccess.open(latest_path, FileAccess.WRITE)
	_check(broken != null, "latest generation accessible for damage fixture")
	if broken != null:
		broken.store_string("truncated")
		broken.close()
	var recovered := saver.load_slot(&"beach_01", state.run_id, &"manual")
	_check(bool(recovered.ok) and not str(recovered.notice).is_empty() and is_zero_approx((recovered.state as RunState).elapsed_active_seconds), "corrupt latest falls back to earlier valid generation")
	broken = FileAccess.open(slot_folder.path_join("A.json"), FileAccess.WRITE)
	if broken != null:
		broken.store_string("also broken")
		broken.close()
	_check(not bool(saver.load_slot(&"beach_01", state.run_id, &"manual").ok) and FileAccess.file_exists(slot_folder.path_join("A.json")), "both corrupt generations remain untouched and report failure")
	print("P24_STAGE backend")
	saver.free()
	session.free()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/p24"
	main.seed_input.text = "save-beach"
	var beach_run := main.start_run() as RunSession
	_check(beach_run != null, "full beach starts")
	if beach_run == null:
		quit(failures)
		return
	var first_id := beach_run.state.run_id
	var player := beach_run.get_node("Player") as BeachPlayer
	var bottle: ItemRecord
	var can: ItemRecord
	for item_value in beach_run.state.items.values():
		var item := item_value as ItemRecord
		if item.location == ItemRecord.Location.WORLD and item.definition_id == &"waste_plastic_bottle" and bottle == null:
			bottle = item
		if item.location == ItemRecord.Location.WORLD and item.definition_id == &"waste_can" and can == null:
			can = item
	_check(bottle != null and can != null, "real Synty bottle and can are present")
	_check(beach_run.item_store.try_collect(&"local", bottle.item_id).ok, "bottle collected")
	var station := beach_run.sorting_stations[&"sorting:S1"] as SortingStation
	_check(station.try_unload(&"local").ok and station.try_sort(bottle.item_id, &"pmd").ok, "bottle sorted at Synty table")
	var sealed := station.try_seal(&"pmd")
	_check(sealed.ok, "disposal bag sealed")
	var bag_id := StringName(str(sealed.receipt.get("bag_id", "")))
	var pose := player.global_transform.translated(Vector3(1.5, 0, 0))
	player.global_transform = pose
	player.set_paused(true)
	await process_frame
	main.pause_menu.save_button.pressed.emit()
	_check(main.pause_menu.note.text.begins_with("Saved checkpoint"), "pause menu writes selected checkpoint")
	var earlier := main.save_service.load_slot(&"beach_01", first_id, &"manual")
	_check(bool(earlier.ok), "first full-beach save loads")
	player.global_position += Vector3(2, 0, 0)
	var later_pose := player.global_transform
	main.pause_menu.save_button.pressed.emit()
	var later := main.save_service.load_slot(&"beach_01", first_id, &"manual")
	_check(bool(later.ok) and int(later.sequence) > int(earlier.sequence), "same revision gets a new manual generation")
	if bool(later.ok):
		_check(((later.state as RunState).players[&"local"] as Dictionary).transform.origin.distance_to(later_pose.origin) < 0.001, "paused save captures current world pose")
	var loaded_run := main.load_run(first_id, &"manual")
	_check(bool(loaded_run.ok), "title load reconstructs beach")
	beach_run = main.run_root as RunSession
	player = beach_run.get_node("Player") as BeachPlayer
	_check(player.global_position.distance_to(later_pose.origin) < 0.001 and (beach_run.state.bag_records[bag_id] as Dictionary).location == "RACK", "pose and sealed rack bag restore")
	_check(beach_run.state.validate_invariants(beach_run.definitions).is_empty(), "loaded rack ownership is valid")
	print("P24_STAGE rack")
	station = beach_run.sorting_stations[&"sorting:S1"] as SortingStation
	_check(beach_run.item_store.try_collect(&"local", can.item_id).ok and station.try_unload(&"local").ok, "can enters sorting table")
	station.enter()
	_check(main.sorting_view.visible and station.active, "table interaction is open")
	_check(bool(main.save_service.save_slot(&"manual").ok), "table-open save succeeds")
	loaded_run = main.load_run(first_id, &"manual")
	beach_run = main.run_root as RunSession
	_check(bool(loaded_run.ok) and not main.sorting_view.visible and (beach_run.state.items[can.item_id] as ItemRecord).location == ItemRecord.Location.TABLE, "load closes transient table UI and keeps committed cell")
	_check(beach_run.state.validate_invariants(beach_run.definitions).is_empty(), "table-open load preserves ownership")
	player = beach_run.get_node("Player") as BeachPlayer
	player.global_position += Vector3(3, 0, 0)
	beach_run.state.elapsed_active_seconds += 7.0
	var quit_pose := player.global_position
	var quit_time := beach_run.state.elapsed_active_seconds
	var quit_revision := beach_run.state.revision
	player.set_paused(true)
	await process_frame
	main.save_service.save_root = "res://invalid_save_root"
	main.pause_menu.save_quit_button.pressed.emit()
	_check(main.run_root == beach_run and main.pause_menu.quit_without_save_button.visible and main.pause_menu.note.text.begins_with("Save failed"), "failed Save and quit keeps run and offers retry or quit without saving")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image_path := ProjectSettings.globalize_path("res://docs/handoffs/images/P24-save-failure.png")
		_check(root.get_texture().get_image().save_png(image_path) == OK, "save-failure screenshot captured")
	main.save_service.save_root = "user://test_runs/p24"
	main.pause_menu.save_quit_button.pressed.emit()
	_check(main.run_root == null and main.menu_container.visible and main.continue_button.disabled == false, "successful Save and quit returns to title with Continue")
	var quit_save := main.save_service.load_slot(&"beach_01", first_id, &"manual")
	if bool(quit_save.ok):
		var quit_state := quit_save.state as RunState
		_check((quit_state.players[&"local"] as Dictionary).transform.origin.distance_to(quit_pose) < 0.001 and is_equal_approx(quit_state.elapsed_active_seconds, quit_time) and quit_state.revision == quit_revision, "Save and quit persisted later pose and time at unchanged revision")
	else:
		_check(false, "Save and quit generation validates")
	main.load_button.pressed.emit()
	_check(main.load_panel.visible and main.save_list.item_count > 0, "title Load lists saved slots")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var load_image_path := ProjectSettings.globalize_path("res://docs/handoffs/images/P24-load-menu.png")
		_check(root.get_texture().get_image().save_png(load_image_path) == OK, "load-menu screenshot captured")
	main.free()
	print("P24_SAVE initial=1 recovery=1 rack=1 pose=1 table=1 quit=1 failures=%d" % failures)
	quit(failures)


func _check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)


func _equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for index in a.size():
			if not _equivalent(a[index], b[index]):
				return false
		return true
	return a == b
