extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := (load("res://tests/scenes/placement_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	var settings := SettingsStore.new()
	settings.settings_path = "user://p16-tools.cfg"
	lab.add_child(settings)
	var definitions := ManifestGenerator.new().load_catalog()
	var state := RunState.new()
	state.run_id = "tool-filter-lab"
	var record := state.add_player()
	for row in [
		["s1", "waste_can", Vector3(4, 0.05, 0.0), ItemRecord.Location.WORLD, true],
		["s2", "waste_plastic_bottle", Vector3(3.45, 0.05, -0.12), ItemRecord.Location.WORLD, true],
		["s3", "waste_food_scrap", Vector3(4.55, 0.05, -0.12), ItemRecord.Location.WORLD, true],
		["s4", "waste_paper", Vector3(4.0, 0.05, -0.62), ItemRecord.Location.WORLD, true],
		["valuable", "valuable_keys", Vector3(3.5, 0.05, 0.45), ItemRecord.Location.WORLD, false],
		["chair", "prop_beach_chair", Vector3(5.2, 0.05, 0.6), ItemRecord.Location.WORLD, true],
		["large", "waste_bundled_scrap", Vector3(4.8, 0.05, -0.5), ItemRecord.Location.WORLD, true],
		["residue", "waste_residue", Vector3(3.25, 0.05, 0.35), ItemRecord.Location.WORLD, true],
		["hidden", "waste_buried_metal", Vector3(4.1, -0.4, -0.3), ItemRecord.Location.BURIED, true],
		["attached", "waste_rescue_ring", Vector3(4.1, 0.05, -0.3), ItemRecord.Location.ATTACHED, true],
	]:
		_add_item(state, StringName(row[0]), StringName(row[1]), row[2], row[3], row[4])
	for row in [
		["v1", Vector3(4, 0.05, -1.35)],
		["v2", Vector3(3.45, 0.05, -1.45)],
		["v3", Vector3(4.1, 0.05, -1.55)],
		["v_blocked", Vector3(4.7, 0.05, -1.45)],
		["v_behind", Vector3(4, 0.05, 3.45)],
	]:
		_add_item(state, StringName(row[0]), &"waste_can", row[1], ItemRecord.Location.WORLD, true)
	(state.items[&"chair"] as ItemRecord).dirty_patches_remaining = [&"patch_1"] as Array[StringName]
	var session := RunSession.new()
	session.initialize(state, definitions)
	lab.add_child(session)
	var manager := ItemViewManager.new()
	manager.name = "Items"
	session.add_child(manager)
	session.item_view_manager = manager
	manager.configure(session, definitions, {&"recovery:lab": Vector3(0, 0.05, 4)})
	manager.build_views()
	var player := lab.get_node("%Player") as BeachPlayer
	player.configure(settings, session)
	var progression := ProgressionService.new()
	session.add_child(progression)
	progression.configure(session, player)
	(record.owned_tools as Array[StringName]).append_array([&"sand_cleaner", &"vacuum"])
	record.equipped_handheld_ids = [&"sand_cleaner", &"vacuum"] as Array[StringName]
	record.active_slot = 0
	progression.refresh_tool_visual()
	var sand := SandCleaner.new()
	session.add_child(sand)
	sand.configure(session, player)
	var vacuum := VacuumTool.new()
	session.add_child(vacuum)
	vacuum.configure(session, player)
	player.global_position = Vector3(4, 0, 1.0)
	player.camera.look_at(Vector3(4, 0, 0))
	await _physics_frames(3)
	check(sand.is_active() and sand.preview.visible, "purchased sand cleaner shows a valid ground patch ring")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P16-sand-cleaner.png")
	record.bag_capacity = 1
	var first := sand.try_click()
	check(first.ok and first.changed_ids == PackedStringArray(["s1"]) and (state.items[&"s1"] as ItemRecord).location == ItemRecord.Location.BAG, "nearly full bag collects only nearest eligible sand item")
	var duplicate := sand.try_click()
	check(not duplicate.ok and duplicate.reason == ActionResult.Reason.CAPACITY and (record.trash_bag as Array).size() == 1, "animation/presentation cannot duplicate a committed pickup")
	record.bag_capacity = 20
	var rest := sand.try_click()
	var sand_ids := rest.changed_ids.duplicate()
	sand_ids.sort()
	check(rest.ok and sand_ids == PackedStringArray(["s2", "s3", "s4"]), "sand click collects exactly exposed small litter in radius")
	for excluded_id in [&"valuable", &"chair", &"large", &"residue", &"hidden", &"attached"]:
		check((state.items[excluded_id] as ItemRecord).location != ItemRecord.Location.BAG, "sand cleaner excludes %s" % excluded_id)
	(record.upgrade_levels as Dictionary)[&"sand_cleaner_2"] = 2
	check(sand.max_count() == 12 and is_equal_approx(sand.radius(), 1.5), "sand upgrade gives 12 items and 1.5 m radius without another tool")
	player.camera.look_at(Vector3(4, 4, 2))
	await _physics_frames(2)
	check(not sand.try_click().ok and not sand.preview.visible, "invalid surface gives no collection and hides preview")

	var wall := StaticBody3D.new()
	wall.collision_layer = 8
	wall.collision_mask = 0
	wall.position = Vector3(4.45, 1.0, -0.65)
	lab.add_child(wall)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.42, 2.0, 0.2)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	var wall_visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	wall_visual.mesh = mesh
	wall.add_child(wall_visual)
	record.active_slot = 1
	progression.refresh_tool_visual()
	player.camera.look_at(Vector3(4, 0.15, -1.4))
	await _physics_frames(3)
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P16-vacuum.png")
	var manual_tick := vacuum.try_collect_next()
	check(manual_tick.ok and manual_tick.changed_ids == PackedStringArray(["v1"]), "vacuum picks closest eligible visible cone item")
	record.bag_capacity = (record.trash_bag as Array).size() + 2
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await _physics_frames(24)
	check((state.items[&"v2"] as ItemRecord).location == ItemRecord.Location.BAG and (state.items[&"v3"] as ItemRecord).location == ItemRecord.Location.BAG and (state.items[&"v_blocked"] as ItemRecord).location == ItemRecord.Location.WORLD and (state.items[&"v_behind"] as ItemRecord).location == ItemRecord.Location.WORLD, "vacuum hold repeats at capped rate, then obeys capacity, cone and occluding wall")
	var held_count := (record.trash_bag as Array).size()
	await _physics_frames(12)
	check((record.trash_bag as Array).size() == held_count, "full bag stops held vacuum immediately")
	press.pressed = false
	Input.parse_input_event(press)
	await _physics_frames(3)
	record.bag_capacity = 20
	check(not vacuum.try_collect_next().ok and (state.items[&"v_blocked"] as ItemRecord).location == ItemRecord.Location.WORLD, "blocked litter cannot be vacuumed through wall")
	(record.upgrade_levels as Dictionary)[&"vacuum_2"] = 2
	check(is_equal_approx(vacuum.interval_seconds(), 1.0 / 16.0) and is_equal_approx(vacuum.range_meters(), 4.0), "vacuum upgrade gives 16/sec and 4 m without consumables")
	check(state.validate_invariants(definitions).is_empty(), "tool pickups preserve original IDs and single owners")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.settings_path))
	print("P16_TOOL_FILTERS sand=s1+s2+s3+s4 vacuum=v1+v2+v3 blocked=wall/behind capacity=held upgrades=12/16 failures=%d" % failures)
	lab.free()
	quit(failures)


func _add_item(state: RunState, id: StringName, definition_id: StringName, position: Vector3, location: ItemRecord.Location, required: bool) -> void:
	var item := ItemRecord.new()
	item.item_id = id
	item.definition_id = definition_id
	item.home_section_id = &"lab:sand"
	item.home_zone_id = &"lab"
	item.required = required
	item.location = location
	item.last_world_transform = Transform3D(Basis.IDENTITY, position)
	item.buried = location == ItemRecord.Location.BURIED
	item.revealed = not item.buried
	if item.buried:
		item.dig_surface_position = Vector3(position.x, 0.0, position.z)
		item.reveal_transform = Transform3D(Basis.IDENTITY, item.dig_surface_position + Vector3.UP * 0.035)
	state.add_item(item)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(path) == OK, "tool screenshot saved")
	print("P16_CAPTURE " + path)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P16 FAIL: " + message)
