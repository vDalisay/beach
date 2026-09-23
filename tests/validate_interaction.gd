extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := (load("res://tests/scenes/interaction_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	var settings := SettingsStore.new()
	settings.settings_path = "user://p08-interaction.cfg"
	lab.add_child(settings)
	var generator := ManifestGenerator.new()
	var definitions := generator.load_catalog()
	var state := _fixture_state()
	var session := RunSession.new()
	session.initialize(state, definitions)
	lab.add_child(session)
	var manager := ItemViewManager.new()
	session.add_child(manager)
	session.item_view_manager = manager
	manager.configure(session, definitions, {&"recovery:lab": Vector3(0, 0.05, 4)})
	manager.build_views()
	var player := lab.get_node("%Player") as BeachPlayer
	player.configure(settings)
	player.interactor.configure(session)
	var target_label := lab.get_node("%TargetLabel") as TargetLabel
	target_label.configure(player.interactor, player.camera)
	await _physics_frames(3)

	var glass := manager.view_for(&"glass")
	var result := await _aim_and_scan(player, glass.global_position + Vector3.UP * 0.08)
	check(result.get("id") == &"glass" and result.get("actions", PackedStringArray()).has("collect"), "small glass is selected from the camera centre")
	check(glass.is_highlighted() and glass.outline_overlay_count() > 0, "target receives a per-view white outline")
	await process_frame
	check(target_label.visible and target_label.text_label.text.contains("Glass bottle") and target_label.text_label.text.contains(settings.binding_text(&"primary")), "target label shows the player-facing name and current pickup binding")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_P
	rebound.pressed = true
	settings.rebind(&"primary", rebound)
	check(target_label.text_label.text.contains(settings.binding_text(&"primary")), "target prompt updates immediately after keyboard remap")
	settings.reset_all()
	var controller_input := InputEventJoypadButton.new()
	controller_input.button_index = JOY_BUTTON_A
	controller_input.pressed = true
	settings.note_input(controller_input)
	check(target_label.text_label.text.contains(settings.binding_text(&"primary")), "same target prompt switches to the active controller binding")
	settings.note_input(rebound)

	var net := manager.view_for(&"thin:net")
	result = await _aim_and_scan(player, net.global_position + Vector3.UP * 0.05)
	check(result.get("id") == &"thin:net" and str(result.get("reason", "")).contains("Knife"), "thin net remains targetable and reports its tool reason")
	check(net.is_highlighted() and not glass.is_highlighted(), "target switch cleans the previous effect only")

	var chair := manager.view_for(&"chair")
	result = await _aim_and_scan(player, chair.global_position + Vector3.UP * 0.45)
	check(result.get("id") == &"chair" and result.get("actions", PackedStringArray()).has("hold"), "multi-part chair exposes the contextual hold action")
	check(chair.outline_overlay_count() >= 1, "chair outline covers its visible meshes")
	await process_frame
	check(target_label.text_label.text.contains("Beach chair"), "target label follows target switches")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var capture_path := ProjectSettings.globalize_path("res://docs/handoffs/images/P08-interaction-lab.png")
		check(root.get_texture().get_image().save_png(capture_path) == OK, "interaction evidence capture saves")
		print("P08_CAPTURE %s" % capture_path)

	var rear := manager.view_for(&"rear")
	result = await _aim_and_scan(player, rear.global_position + Vector3.UP * 0.08)
	check(result.get("id") == &"front", "frontmost eligible item wins an overlapping ray")

	var hidden := manager.view_for(&"hidden")
	result = await _aim_and_scan(player, hidden.global_position + Vector3.UP * 0.08)
	check(result.is_empty(), "world occluder blocks item targeting")

	var far := manager.view_for(&"far")
	result = await _aim_and_scan(player, far.global_position + Vector3.UP * 0.08)
	check(result.is_empty(), "items beyond current reach are excluded")

	var cube := manager.view_for(&"cube")
	result = await _aim_and_scan(player, cube.global_position + Vector3(0.19, 0.08, 0))
	check(result.get("id") == &"cube", "near-ray tolerance selects unobstructed tiny litter after a centre miss")

	var local_player := state.players[&"local"] as Dictionary
	var full_bag := local_player.trash_bag as Array[StringName]
	for index in range(int(local_player.bag_capacity)):
		full_bag.append(StringName("fixture:%02d" % index))
	result = await _aim_and_scan(player, glass.global_position + Vector3.UP * 0.08)
	check(result.get("id") == &"glass" and result.get("actions", PackedStringArray()).is_empty() and result.get("reason") == "Bag full", "full bag leaves target visible with a contextual reason")
	full_bag.clear()

	result = await _aim_and_scan(player, cube.global_position + Vector3.UP * 0.08)
	var primary_observation := {"count": 0}
	player.interactor.primary_requested.connect(func(_target: Dictionary) -> void: primary_observation.count += 1)
	var primary := InputEventMouseButton.new()
	primary.button_index = MOUSE_BUTTON_LEFT
	primary.pressed = true
	Input.parse_input_event(primary)
	await _physics_frames(3)
	check(int(primary_observation.count) == 1, "held primary input emits one fresh action edge")
	primary.pressed = false
	Input.parse_input_event(primary)
	await process_frame
	await physics_frame
	primary.pressed = true
	Input.parse_input_event(primary)
	await _physics_frames(2)
	check(int(primary_observation.count) == 2, "a released and re-pressed primary emits the next edge")
	primary.pressed = false
	Input.parse_input_event(primary)

	await _aim_and_scan(player, cube.global_position + Vector3.UP * 0.08)
	var before_basis := player.camera.global_basis
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.9
	Input.parse_input_event(stick)
	await _physics_frames(4)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	check(not player.camera.global_basis.is_equal_approx(before_basis), "controller look moves the same centre-ray aim")

	await _aim_and_scan(player, glass.global_position + Vector3.UP * 0.08)
	check(target_label.visible, "label is visible before its view leaves WORLD")
	check(session.item_store.try_collect(&"local", &"glass").ok, "fixture uses the real collection route to remove a target")
	await _physics_frames(3)
	player.interactor.update_target()
	await process_frame
	check(manager.view_for(&"glass") == null and not target_label.visible, "freed target clears its outline and label")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.settings_path))
	print("P08_INTERACTION target_format=id/kind/hit_point/distance/actions/reason reach=%.1fm failures=%d" % [player.interactor.reach, failures])
	lab.free()
	quit(failures)


func _aim_and_scan(player: BeachPlayer, point: Vector3) -> Dictionary:
	player.camera.look_at(point)
	await physics_frame
	return player.interactor.update_target()


func _fixture_state() -> RunState:
	var state := RunState.new()
	state.run_id = "interaction-lab"
	state.add_player()
	_add_record(state, &"glass", &"waste_glass_bottle", Vector3(0, 0.05, -1.4))
	_add_record(state, &"thin:net", &"waste_rescue_net", Vector3(1.0, 0.05, -1.4))
	_add_record(state, &"cube", &"waste_food_scrap", Vector3(-1.0, 0.05, -1.4))
	_add_record(state, &"chair", &"prop_beach_chair", Vector3(-1.6, 0.05, -1.2))
	_add_record(state, &"front", &"waste_can", Vector3(0.25, 0.78, -0.8))
	_add_record(state, &"rear", &"waste_food_scrap", Vector3(0.5, 0.05, -1.6))
	_add_record(state, &"hidden", &"waste_can", Vector3(1.5, 0.05, -0.7))
	_add_record(state, &"far", &"waste_can", Vector3(-3.0, 0.05, -1.0))
	return state


func _add_record(state: RunState, item_id: StringName, definition_id: StringName, position: Vector3) -> void:
	var record := ItemRecord.new()
	record.item_id = item_id
	record.definition_id = definition_id
	record.home_section_id = &"interaction:lab"
	record.home_zone_id = &"interaction"
	record.last_world_transform = Transform3D(Basis.IDENTITY, position)
	record.sleeping = true
	state.add_item(record)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P08 FAIL: %s" % message)
