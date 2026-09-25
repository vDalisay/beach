extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.settings_store.settings_path = "user://p22-ui-check.cfg"
	var first_choice := main.continue_button if not main.continue_button.disabled else main.title_screen.new_button
	check(first_choice.has_focus() and main.continue_button.text == "Continue" and main.load_button.text == "Load run", "menu focuses Continue or New beach and exposes real save choices")
	main.seed_input.text = "ui-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "full beach starts from the menu")
	if session == null:
		quit(1)
		return
	var player := session.get_node("Player") as BeachPlayer
	check(main.complete_value.text == "0" and main.complete_total.text == "/ 5,700" and main.complete_caption.text == "COMPLETED · 5,700 LEFT" and main.props_label.text == "PROPS 0 / 300" and main.trash_label.text == "TRASH COLLECTED 0 / 5,400", "HUD names truck-based trash credit and remaining total")
	check(main.bag_count_label.text == "0 / 20" and main.tool_name_label.text == "POKING STICK", "separate bag/tool context is visible")
	var chosen: ItemRecord
	for value in session.state.items.values():
		var item := value as ItemRecord
		var definition := session.definitions[item.definition_id] as ItemDefinition
		if item.location == ItemRecord.Location.WORLD and definition.kind == ItemDefinition.Kind.WASTE and definition.required_tool.is_empty():
			chosen = item
			break
	check(chosen != null and session.item_store.try_collect(&"local", chosen.item_id).ok, "real world litter enters the player bag")
	check(main.bag_count_label.text == "1 / 20" and main.complete_value.text == "0", "pickup changes bag but not truck completion")
	check(&"pickup" in session.state.guidance_seen and main.guidance_panel.visible, "first pickup guidance is acknowledged in run state")
	main.settings_store.prompt_device = SettingsStore.PromptDevice.CONTROLLER
	main.settings_store._on_joy_connection_changed(1, false)
	await process_frame
	check(paused and main.pause_menu.visible and main.pause_menu.resume_button.has_focus(), "controller disconnect pauses into a focusable menu rather than a hidden pause")
	main.settings_store._on_joy_connection_changed(1, true)
	check(paused and not main.error_panel.visible, "reconnection clears its warning but leaves Resume to the player")
	main.pause_menu.resume_button.pressed.emit()
	check(not paused, "controller or keyboard can resume after reconnection")
	main.progression_view.open_booklet()
	check(main.progression_view.visible and paused and main.progression_view.booklet_page == 0, "booklet opens on section tasks while gameplay is paused")
	var tasks := main.progression_view.page_text()
	check(tasks.contains("awaiting collection") and tasks.contains("1 awaiting collection"), "section task stage identifies collected-but-not-trucked litter")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P22-booklet-%s.png" % root.size.x)
	main.settings_store.set_value(&"ui_scale", 1.5)
	await process_frame
	check(is_equal_approx(root.content_scale_factor, 1.5), "UI scale setting applies to the live viewport")
	if "--capture" in OS.get_cmdline_user_args() and root.size.x == 1280:
		await _capture("P22-booklet-scale-1280.png")
	main.settings_store.set_value(&"ui_scale", 1.0)
	var tabs := main.progression_view.list.get_child(0) as HBoxContainer
	_send_joy(JOY_BUTTON_DPAD_RIGHT)
	await process_frame
	tabs = main.progression_view.list.get_child(0) as HBoxContainer
	check((tabs.get_child(1) as Button).has_focus(), "controller moves between booklet tabs")
	_send_joy(JOY_BUTTON_A)
	await process_frame
	check(main.progression_view.page_text().contains("Known objects: 1"), "discoveries display the actual collected object's definition")
	tabs = main.progression_view.list.get_child(0) as HBoxContainer
	(tabs.get_child(2) as Button).pressed.emit()
	check(main.progression_view.list.get_child_count() > 2, "skills remain purchasable in the booklet")
	tabs = main.progression_view.list.get_child(0) as HBoxContainer
	(tabs.get_child(3) as Button).pressed.emit()
	check(main.progression_view.page_text().contains("Interact"), "controls show current bindings")
	main.progression_view.close()
	check(not paused and player.input_enabled, "booklet returns control to the beach")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P22-hud-%s.png" % root.size.x)
	player.set_paused(true)
	await process_frame
	check(main.pause_menu.visible and main.pause_menu.resume_button.has_focus(), "pause opens with visible Resume focus")
	check(not main.pause_menu.save_button.disabled and not main.pause_menu.save_quit_button.disabled, "pause exposes working save actions")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P22-pause-%s.png" % root.size.x)
	_send_joy(JOY_BUTTON_DPAD_DOWN)
	await process_frame
	check(main.pause_menu.settings_button.has_focus(), "controller reaches pause Settings alongside save actions")
	_send_joy(JOY_BUTTON_A)
	await process_frame
	check(main.settings_menu.visible and not main.pause_menu.visible, "settings opens from pause without a second overlay")
	var cancel := InputEventKey.new()
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await process_frame
	check(main.pause_menu.visible and main.pause_menu.settings_button.has_focus(), "closing settings restores originating pause focus")
	main.pause_menu.resume_button.pressed.emit()
	check(not paused and not main.pause_menu.visible, "Resume restores gameplay")
	check(&"pickup" in RunState.from_snapshot(session.state.to_snapshot()).guidance_seen, "acknowledged guidance survives snapshot reconstruction")
	check(session.state.validate_invariants(session.definitions).is_empty(), "UI actions preserve actual run state")
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://p22-ui-check.cfg"))
	print("P22_UI hud=1 booklet=4 pause=1 guidance=1 failures=%d" % failures)
	quit(failures)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "UI screenshot saved")
	print("P22_CAPTURE " + path)


func _send_joy(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = false
	Input.parse_input_event(event)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P22 FAIL: " + message)
