extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(3840, 2160)
	viewport.size_2d_override = Vector2i(1280, 720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	viewport.add_child(main)
	main.save_service.save_root = "user://test_runs/p27_4k"
	main.settings_store.settings_path = "user://test_runs/p27_4k_settings.cfg"
	main.seed_input.text = "4k-layout-check"
	var session := main.start_run() as RunSession
	if session == null:
		push_error("4K layout: beach did not start")
		quit(1)
		return
	for _frame in range(120):
		await physics_frame
	if session.progress_service.completed_props != 0 or session.state.revision != 0:
		push_error("4K layout: a new run changed before player input")
		quit(1)
		return
	await _capture(viewport, "P27-hud-3840.png")
	main.progression_view.open_booklet()
	await process_frame
	await _capture(viewport, "P27-booklet-3840.png")
	main.progression_view.close()
	(session.get_node("Player") as BeachPlayer).set_paused(true)
	await process_frame
	await _capture(viewport, "P27-pause-3840.png")
	print("P27_4K offscreen_size=%s hud=1 booklet=1 pause=1" % viewport.size)
	quit()


func _capture(viewport: SubViewport, filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image.get_size() != Vector2i(3840, 2160):
		push_error("4K layout: unexpected capture size %s" % image.get_size())
		quit(1)
		return
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	if image.save_png(path) != OK:
		push_error("4K layout: could not save %s" % path)
		quit(1)
		return
	print("P27_CAPTURE " + path)
