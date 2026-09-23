extends SceneTree

# Review reproduction against 3c6b431; staged setup, real scene and input dispatch.
var failures := 0


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/checkpoint_review"
	main.seed_input.text = "full-run-integration"
	var session := main.start_run() as RunSession
	var player := session.get_node("Player") as BeachPlayer
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	main.settings_store.reset_all()
	await physics_frame
	await physics_frame
	var overlaps: Array[String] = []
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.location != ItemRecord.Location.WORLD:
			continue
		var query := PhysicsPointQueryParameters3D.new()
		query.position = item.last_world_transform.origin
		query.collision_mask = 1
		for hit in player.get_world_3d().direct_space_state.intersect_point(query):
			if str(hit.collider.name).begins_with("ReefRock"):
				overlaps.append("%s at %s inside %s" % [item.item_id, query.position, hit.collider.name])
	print("REEF_OVERLAP count=%d examples=%s" % [overlaps.size(), overlaps.slice(0, 4)])
	var trapped := session.state.items[&"item:reef_east:coral:00070"] as ItemRecord
	player.set_physics_process(false)
	session.swim_service.set_physics_process(false)
	player.global_position = trapped.last_world_transform.origin + Vector3(0, 1, 0)
	var trapped_view := session.item_view_manager.view_for(trapped.item_id)
	for frame in 120:
		await physics_frame
	var blocked_rays := 0
	var target := trapped_view.global_position + Vector3.UP * WorldItem.profile_size(trapped_view.definition.collision_profile).y * 0.5
	for direction in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var query := PhysicsRayQueryParameters3D.create(target + direction * 3.0, target, CleanupTargetQuery.SIGHT_MASK, [player.get_rid()])
		query.collide_with_areas = true
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.get("collider") != trapped_view:
			blocked_rays += 1
	print("REEF_PICKUP id=%s definition=%s position=%s frozen=%s blocked_approaches=%d/5" % [trapped.item_id, trapped.definition_id, trapped_view.global_position, trapped_view.freeze, blocked_rays])
	if blocked_rays == 5:
		failures += 1
	player.set_physics_process(true)
	session.swim_service.set_physics_process(true)
	var can: ItemRecord
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.location == ItemRecord.Location.WORLD and item.definition_id == &"waste_can":
			can = item
			break
	assert(can != null and session.item_store.try_collect(&"local", can.item_id).ok)
	player.global_position = station.global_position + Vector3(0, 0, 2.2)
	station.enter()
	var remap := InputEventJoypadButton.new()
	remap.button_index = JOY_BUTTON_Y
	remap.pressed = true
	var conflicts := main.settings_store.rebind(&"ui_accept", remap)
	main.sorting_view.unload_button.grab_focus()
	await joy(JOY_BUTTON_Y)
	var unloaded := can.location == ItemRecord.Location.TABLE
	print("REMAP_Y conflicts=%s unloaded=%s inspecting=%s focus=%s" % [conflicts, unloaded, main.sorting_view.inspecting_bin, root.gui_get_focus_owner().name])
	if not unloaded:
		failures += 1
	main.settings_store.reset_all()
	station.exit()
	var first := main.save_service.save_slot(&"manual")
	var second := main.save_service.save_slot(&"manual_2")
	assert(first.ok and second.ok)
	var run_id := session.state.run_id
	assert(main.load_run(run_id, &"manual_2").ok)
	player = main.run_root.get_node("Player") as BeachPlayer
	player.set_paused(true)
	await process_frame
	await process_frame
	print("CHECKPOINT_AFTER_LOAD loaded=manual_2 selected=%s" % main.pause_menu.selected_slot_id())
	if main.pause_menu.selected_slot_id() != &"manual_2":
		failures += 1
	main.pause_menu.save_button.grab_focus()
	await joy(JOY_BUTTON_A)
	var first_after := main.save_service.load_slot(&"beach_01", run_id, &"manual")
	var second_after := main.save_service.load_slot(&"beach_01", run_id, &"manual_2")
	print("CHECKPOINT_AFTER_SAVE first_sequence=%d->%d second_sequence=%d->%d" % [first.sequence, first_after.sequence, second.sequence, second_after.sequence])
	main.pause_menu.slot_picker.grab_focus()
	await joy(JOY_BUTTON_A)
	print("PICKER_BEFORE_CANCEL paused=%s popup=%s" % [paused, main.pause_menu.slot_picker.get_popup().visible])
	await joy(JOY_BUTTON_START)
	print("PICKER_AFTER_START paused=%s menu=%s popup=%s" % [paused, main.pause_menu.visible, main.pause_menu.slot_picker.get_popup().visible])
	print("CHECKPOINT_REVIEW reproduced_failures=%d" % failures)
	quit(failures)


func joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var released := event.duplicate() as InputEventJoypadButton
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame
