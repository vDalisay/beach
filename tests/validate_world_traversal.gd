extends SceneTree

var failures := 0
var player: BeachPlayer


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	await process_frame
	main.settings_store.reset_all()
	main.start_run()
	await _physics_frames(5)
	player = main.run_root.get_node("Player") as BeachPlayer
	var definition := load("res://data/world/beach_01.tres") as BeachDefinition
	var route := definition.starting_state.get("walk_route", []) as Array

	Engine.time_scale = 8.0
	var traversed := 0.0
	for index in range(1, route.size()):
		var target := route[index] as Vector3
		var reached := false
		for frame in 480:
			var before := player.global_position
			var flat_target := Vector3(target.x, player.global_position.y, target.z)
			player.look_at(flat_target, Vector3.UP)
			_send_stick(-1.0)
			await physics_frame
			traversed += Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length()
			if player.global_position.y < -1.0:
				break
			if Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length() < 1.2:
				reached = true
				break
		check(reached, "controller route reaches waypoint %d" % index)
		if not reached:
			break
	_send_stick(0.0)
	Engine.time_scale = 1.0
	check(player.global_position.y >= -1.0, "coastline traversal stays on authored terrain")

	var hut_entries := 0
	for service_value in definition.starting_state.get("service_points", {}).values():
		var service := service_value as Vector3
		player.global_position = service + Vector3(0, 0.05, 5)
		player.velocity = Vector3.ZERO
		player.look_at(Vector3(service.x, player.global_position.y, service.z), Vector3.UP)
		_send_stick(-1.0)
		await _physics_frames(80)
		_send_stick(0.0)
		var local := player.global_position - service
		if absf(local.x) < 1.2 and local.z < 2.7 and local.z > -2.6:
			hut_entries += 1
	check(hut_entries == 3, "controller enters all three service huts through the carry-width doors")

	print("P05_TRAVERSAL waypoints=%d distance=%.1fm huts=%d failures=%d" % [route.size(), traversed, hut_entries, failures])
	quit(failures)


func _send_stick(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	Input.parse_input_event(event)


func _physics_frames(count: int) -> void:
	for frame in count:
		await physics_frame


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P05 TRAVERSAL FAIL: %s" % message)
