extends SceneTree

# Bounded review diagnostic, not a gameplay test suite. Exit nonzero for observed gaps.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gaps := 0
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/systems_review"
	main.seed_input.text = "first-shore"
	var session := main.start_run() as RunSession
	var player := session.get_node("Player") as BeachPlayer
	player.set_physics_process(false)
	var reader := player.input_reader
	await physics_frame
	_mouse(true)
	await physics_frame
	reader.sample(1.0 / 60.0)
	var first := reader.primary_pressed
	# A physical release/repress may arrive between simulation samples.
	_mouse(false)
	_mouse(true)
	await physics_frame
	var engine_edge := Input.is_action_just_pressed(&"primary")
	reader.sample(1.0 / 60.0)
	var second := reader.primary_pressed
	_mouse(false)
	await physics_frame
	reader.sample(1.0 / 60.0)
	_mouse(true)
	await physics_frame
	reader.sample(1.0 / 60.0)
	var after_sampled_release := reader.primary_pressed
	_mouse(false)
	print("INPUT_EDGES first=%s engine_second=%s reader_second=%s sampled_release_control=%s" % [first, engine_edge, second, after_sampled_release])
	if not first or not engine_edge or not after_sampled_release:
		push_error("Input delivery control failed; this is not a valid reproduction")
		quit(99)
		return
	if first and engine_edge and not second and after_sampled_release:
		gaps += 1
	var gamepad := InputEventJoypadButton.new()
	gamepad.button_index = JOY_BUTTON_X
	gamepad.pressed = true
	main.settings_store.note_input(gamepad)
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	var label := main.target_label
	label._on_target_changed(player.interactor._result_for_collider(container, container.global_position, 1.0))
	print("STATION_PROMPT binding=%s text=%s" % [main.settings_store.binding_text(&"interact"), label.text_label.text.replace("\n", " | ")])
	if label.text_label.text.contains("E:"):
		gaps += 1
	print("STATE_ERRORS %d" % session.state.validate_invariants(session.definitions).size())
	main.free()
	if "--input-only" in OS.get_cmdline_user_args():
		print("REVIEW_GAPS %d" % gaps)
		quit(gaps)
		return

	# Isolate HEAD's changed rear-shelf exclusion scale from the rest of content-8.
	var old_reef := GDScript.new()
	old_reef.source_code = FileAccess.get_file_as_string("res://scripts/world/reef_dressing.gd").replace("return 1.4 if index in REAR_SHELF_ROCKS else 1.0", "return 1.0")
	if old_reef.reload() != OK:
		quit(99)
		return
	var old_script := GDScript.new()
	old_script.source_code = FileAccess.get_file_as_string("res://scripts/world/manifest_generator.gd").replace("class_name ManifestGenerator\n", "").replace('const REEF_DRESSING := preload("res://scripts/world/reef_dressing.gd")', 'var REEF_DRESSING: GDScript')
	if old_script.reload() != OK:
		quit(99)
		return
	var previous: RefCounted = old_script.new()
	previous.set("REEF_DRESSING", old_reef)
	var current := ManifestGenerator.new()
	var compared := 0
	for index in 20:
		var seed_text := "manifest-fixture-v1" if index == 0 else "first-shore" if index == 1 else "systems-review-%02d" % index
		var before: Dictionary = previous.call("generate", seed_text)
		var after := current.generate(seed_text)
		if not before.ok or not after.ok:
			print("GENERATION_FAILED %s" % seed_text)
			quit(99)
			return
		compared += 1
		if before.manifest_hash != after.manifest_hash:
			print("MANIFEST_CHANGED seed=%s same_content_hash=%s before=%s after=%s" % [seed_text, before.content_hash == after.content_hash, before.manifest_hash, after.manifest_hash])
			gaps += 1
			break
	print("SEEDS_COMPARED %d REVIEW_GAPS %d" % [compared, gaps])
	quit(gaps)


func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
