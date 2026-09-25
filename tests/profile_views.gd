extends SceneTree
## Frame-cost probe over fixed views of the real beach run (main.tscn, seed "first-shore").
## One line per view: wall-clock frame median/p95, native GPU and render-CPU medians, the CPU
## split into script processing, drawing and physics/other, draw calls, primitives and objects;
## then a sprint along the beach that exercises item streaming. Run with a window (not
## --headless). Optional user args:
##   --views=lounge,pier  measure a subset   --frames=300  measured frames per view
##   --restored  show every restoration visual first   --graphics=low|medium|high|ultra  preset
##   --breakdown  per view, also measure with each scenery group hidden and each effect off
##   --no-walk  skip the streaming sprint

# [eye position, look target, underwater]
const VIEWS := {
	"spawn": [Vector3(-73, 1.7, 7), Vector3(0, 1.4, 12), false],
	"lounge": [Vector3(-17, 1.7, 24), Vector3(-17, 1.2, -18), false],
	"along-shore": [Vector3(-65, 1.7, 32), Vector3(60, 1.7, 37), false],
	"sea": [Vector3(0, 1.7, 45), Vector3(0, 0, 180), false],
	"pier": [Vector3(62.5, 3.1, 60), Vector3(62.5, 3.0, 84), false],
	"city": [Vector3(5, 1.7, -33), Vector3(0, 12, -83), false],
	"reef": [Vector3(2.5, -1.25, 101), Vector3(2.5, -2.25, 107.5), true],
	"aerial": [Vector3(-15, 65, 135), Vector3(0, 0, 0), false],
}
const GROUPS := ["Beach/CityBackdrop", "Beach/Skyline", "Beach/Foliage", "Beach/Zones", "Beach/ServicePoints", "Beach/ActivityAreas", "Beach/PierBlockout", "Beach/Terrain", "Beach/Water", "Items"]
const EYE_HEIGHT := 1.65

var _viewport: RID
var _pre_draw := 0
var _post_draw := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_viewport = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport, true)
	RenderingServer.frame_pre_draw.connect(func() -> void: _pre_draw = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _post_draw = Time.get_ticks_usec())
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/profile_views"
	# In memory only: the player's saved settings file is not written.
	var preset := _arg("graphics") if not _arg("graphics").is_empty() else "high"
	main.settings_store.apply_graphics_preset(StringName(preset))
	main.settings_store.set_value(&"vsync", false)
	main.settings_store.set_value(&"max_fps", 0)
	main.seed_input.text = "first-shore"
	var started := Time.get_ticks_usec()
	var session := main.start_run() as RunSession
	print("PROFILE_START run_ms=%.0f views_built_ms=%.0f preset=%s" % [float(Time.get_ticks_usec() - started) / 1000.0, session.item_view_manager.build_time_ms, preset])
	var player := session.get_node("Player") as BeachPlayer
	player.set_physics_process(false)
	session.swim_service.set_physics_process(false)
	(main.get_node("UI") as CanvasLayer).visible = false
	if "--restored" in OS.get_cmdline_user_args():
		_restore_everything(session)
	var names := VIEWS.keys()
	if not _arg("views").is_empty():
		names = Array(_arg("views").split(","))
	var frames := int(_arg("frames")) if not _arg("frames").is_empty() else 300
	for view_name in names:
		var view := VIEWS[view_name] as Array
		_place(player, view[0] as Vector3, view[1] as Vector3)
		player.camera.environment = SwimService.UNDERWATER_ENVIRONMENT if bool(view[2]) else null
		await _settle(session)
		await _measure(str(view_name), frames)
		if "--breakdown" in OS.get_cmdline_user_args():
			await _breakdown(session, player, str(view_name), frames)
	player.camera.environment = null
	if not "--no-walk" in OS.get_cmdline_user_args():
		await _walk(session, player)
	print("PROFILE_MEMORY nodes=%d static_mb=%.1f video_mb=%.1f texture_mb=%.1f buffer_mb=%.1f" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
	])
	print("PROFILE_DEVICE cpu=%s gpu=%s size=%s" % [OS.get_processor_name(), RenderingServer.get_video_adapter_name(), str(root.size)])
	main.free()
	quit()


func _place(player: BeachPlayer, eye: Vector3, target: Vector3) -> void:
	player.global_position = eye - Vector3(0, EYE_HEIGHT, 0)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.look_at(target)


func _settle(session: RunSession) -> void:
	# Let nearby item views stream in and shaders compile before measuring.
	var manager := session.item_view_manager
	var quiet := 0
	for frame in 900:
		await process_frame
		quiet = quiet + 1 if manager._stream_pending.is_empty() else 0
		if quiet >= 60 and frame >= 90:
			return


func _measure(label: String, frames: int) -> void:
	var times: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var scripts: Array[float] = []
	var drawing: Array[float] = []
	var other: Array[float] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	var objects: Array[float] = []
	await process_frame
	var previous := Time.get_ticks_usec()
	for frame in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		# The previous frame ran: process (scripts) -> draw -> physics/input -> this process_frame.
		scripts.append(float(_pre_draw - previous) / 1000.0)
		drawing.append(float(_post_draw - _pre_draw) / 1000.0)
		other.append(float(now - _post_draw) / 1000.0)
		times.append(float(now - previous) / 1000.0)
		previous = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_viewport))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_viewport))
		draws.append(RenderingServer.viewport_get_render_info(_viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		prims.append(RenderingServer.viewport_get_render_info(_viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		objects.append(RenderingServer.viewport_get_render_info(_viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
	# Draw calls include the shadow passes in the Compatibility renderer.
	print("VIEW %-24s frame_med=%.2f p95=%.2f gpu=%.2f render_cpu=%.2f script=%.2f draw=%.2f physics_other=%.2f draws=%d prims=%d objects=%d" % [
		label, _median(times), _percentile(times, 0.95), _median(gpu), _median(cpu), _median(scripts), _median(drawing), _median(other),
		int(_median(draws)), int(_median(prims)), int(_median(objects)),
	])


func _breakdown(session: RunSession, player: BeachPlayer, view_name: String, frames: int) -> void:
	for path in GROUPS:
		var node := session.get_node_or_null(path) as Node3D
		if node == null:
			continue
		node.visible = false
		await _measure("%s -%s" % [view_name, path.get_file()], frames)
		node.visible = true
	var sun := session.get_node("Beach/Sun") as DirectionalLight3D
	sun.shadow_enabled = false
	await _measure("%s -sun_shadow" % view_name, frames)
	sun.shadow_enabled = true
	var lamps := session.find_children("*", "OmniLight3D", true, false)
	for lamp in lamps:
		(lamp as Light3D).visible = false
	await _measure("%s -omni_lights" % view_name, frames)
	for lamp in lamps:
		(lamp as Light3D).visible = true
	var environment := (session.get_node("Beach/WorldEnvironment") as WorldEnvironment).environment
	for property in ["ssao_enabled", "glow_enabled", "fog_enabled", "adjustment_enabled"]:
		environment.set(property, false)
		await _measure("%s -%s" % [view_name, property.trim_suffix("_enabled")], frames)
		environment.set(property, true)
	var msaa := root.msaa_3d
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _measure("%s -msaa" % view_name, frames)
	root.msaa_3d = msaa


func _walk(session: RunSession, player: BeachPlayer) -> void:
	# Sprint-speed pass along the littered beach: item views stream in and out as it moves.
	var start := Vector3(-70, 0.0, 22)
	var finish := Vector3(70, 0.0, 22)
	_place(player, start + Vector3.UP * EYE_HEIGHT, start + Vector3(10, EYE_HEIGHT, 0))
	await _settle(session)
	var times: Array[float] = []
	var scripts: Array[float] = []
	var worst := [0.0, 0.0, 0.0, 0.0, 0.0]
	await process_frame
	var previous := Time.get_ticks_usec()
	var travelled := 0.0
	var views_before := session.item_view_manager.views.size()
	while travelled < start.distance_to(finish):
		await process_frame
		var now := Time.get_ticks_usec()
		var script_ms := float(_pre_draw - previous) / 1000.0
		scripts.append(script_ms)
		var delta := float(now - previous) / 1000000.0
		if delta * 1000.0 > float(worst[0]):
			worst = [delta * 1000.0, script_ms, float(_post_draw - _pre_draw) / 1000.0, float(now - _post_draw) / 1000.0, travelled]
		previous = now
		times.append(delta * 1000.0)
		travelled += 7.0 * delta
		player.global_position = start.lerp(finish, minf(travelled / start.distance_to(finish), 1.0))
	var over := times.filter(func(value: float) -> bool: return value > 16.7).size()
	print("WALK frames=%d frame_med=%.2f p95=%.2f p99=%.2f max=%.2f script_med=%.2f script_p99=%.2f script_max=%.2f over_16ms=%d views=%d->%d" % [
		times.size(), _median(times), _percentile(times, 0.95), _percentile(times, 0.99), times.max(),
		_median(scripts), _percentile(scripts, 0.99), scripts.max(), over, views_before, session.item_view_manager.views.size(),
	])
	print("WALK_WORST frame=%.2f script=%.2f draw=%.2f physics_other=%.2f at_m=%.1f" % worst)


func _restore_everything(session: RunSession) -> void:
	var restoration := session.get_node("RestorationSection") as RestorationSection
	for section_id in restoration.sections:
		restoration._on_section_restored(section_id)
	for zone_id in restoration.zone_roots:
		restoration._on_zone_restored(zone_id)


func _median(values: Array[float]) -> float:
	return _percentile(values, 0.5)


func _percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(sorted.size() * fraction), 0, sorted.size() - 1)]


func _arg(key: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % key):
			return argument.get_slice("=", 1)
	return ""
