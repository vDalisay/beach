extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/legacy"
	main.seed_input.text = "wildlife-fixture"
	var session := main.start_run() as RunSession
	check(session != null, "full beach opens with wildlife and restoration roots")
	if session == null:
		quit(1)
		return
	var nature := session.get_node("RestorationSection") as RestorationSection
	var player := session.get_node("Player") as BeachPlayer
	player.set_input_enabled(false)
	var outer := nature.sections[&"reef_west:outer"] as BeachSection
	var coral := nature.sections[&"reef_west:coral"] as BeachSection
	var zone_root := nature.zone_roots[&"reef_west"] as Node3D
	check(nature.populations.size() == 13 and (nature.populations[&"ambient:reef_west"] as FishSchool).mover.looping and (nature.populations[&"ambient:reef_east"] as FishSchool).mover.looping, "two ambient schools coexist with four local and six regional restoration schools and one turtle route")
	var ambient := nature.populations[&"ambient:reef_west"] as FishSchool
	var fish_start := ambient.mover.position
	for frame in range(20):
		await process_frame
	var fish_motion := ambient.mover.position - fish_start
	check(fish_motion.length() > 0.01 and ambient.mover.basis.z.dot(fish_motion.normalized()) > 0.75 and (ambient.mover.get_node("Fish_01") as Node3D).basis.x.normalized().dot(Vector3.BACK) > 0.99, "fish swim head-first along their live route")
	check(not outer.restoration_visual_root.visible and not coral.restoration_visual_root.visible and not zone_root.visible, "unrestored reef art and regional fish remain hidden")
	var origin := (nature.anchors[&"reef_west:outer"] as Array)[0] as Vector3
	player.global_position = origin + Vector3(0, 0.2, -4.0)
	player.camera.look_at(origin + Vector3(0, 0.55, 2.5))
	session.swim_service.step_environment(0.0)
	var camera_pose := player.camera.global_transform
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P21-reef-before.png")
	_complete_section(session, &"reef_west:outer")
	check(bool((session.state.section_states[&"reef_west:outer"] as Dictionary).restored_once) and outer.restoration_visual_root.visible and not zone_root.visible and (nature.populations[&"section:reef_west:outer:fish"] as FishSchool).mover.looping and not (nature.populations[&"zone:reef_west:01"] as FishSchool).mover.looping, "first restored reef section reveals local habitat and fish before the whole zone completes")
	check(outer.restoration_visual_root.get_child_count() == 16 and coral.restoration_visual_root.get_child_count() == 16, "each reef section has a clarity patch, twelve coral clusters, two starfish and one local school")
	var partial_state := RunState.from_snapshot(session.state.to_snapshot())
	var partial_session := RunSession.new()
	partial_session.initialize(partial_state, session.definitions)
	root.add_child(partial_session)
	var partial_beach := (load("res://scenes/world/beach.tscn") as PackedScene).instantiate() as Node3D
	partial_session.add_child(partial_beach)
	var partial_nature := RestorationSection.new()
	partial_session.add_child(partial_nature)
	partial_nature.configure(partial_session, partial_beach, main.settings_store)
	check((partial_nature.populations[&"section:reef_west:outer:fish"] as FishSchool).mover.looping and not (partial_nature.populations[&"section:reef_west:coral:fish"] as FishSchool).mover.looping and not (partial_nature.zone_roots[&"reef_west"] as Node3D).visible, "partial reef reload resumes only the restored section's fish")
	partial_session.free()
	for frame in range(90):
		await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(1.3).timeout
	check(player.camera.global_transform.is_equal_approx(camera_pose), "before/after reef viewpoints stay identical")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("P21-reef-after.png")
	_complete_section(session, &"reef_west:coral")
	check(bool((session.state.zone_states[&"reef_west"] as Dictionary).restored_once) and zone_root.visible and (nature.populations[&"zone:reef_west:01"] as FishSchool).mover.looping, "second section unlocks regional fish schools once")
	var population_count := nature.populations.size()
	var visual_count := outer.restoration_visual_root.get_child_count()
	session.section_restored.emit(&"reef_west:outer")
	session.zone_restored.emit(&"reef_west")
	check(nature.populations.size() == population_count and outer.restoration_visual_root.get_child_count() == visual_count and zone_root.get_child_count() == 2, "replayed restoration signals never duplicate coral or fish")
	check(_nonblocking(zone_root) and _nonblocking(outer.restoration_visual_root), "restoration wildlife and plants have no interaction or physics colliders")
	check(session.state.validate_invariants(session.definitions).is_empty(), "staged completed reef preserves logical ownership and progress")
	var restored := RunState.from_snapshot(session.state.to_snapshot())
	var loaded_session := RunSession.new()
	loaded_session.initialize(restored, session.definitions)
	root.add_child(loaded_session)
	var loaded_beach := (load("res://scenes/world/beach.tscn") as PackedScene).instantiate() as Node3D
	loaded_session.add_child(loaded_beach)
	var loaded_nature := RestorationSection.new()
	loaded_session.add_child(loaded_nature)
	loaded_nature.configure(loaded_session, loaded_beach, main.settings_store)
	check((loaded_nature.sections[&"reef_west:outer"] as BeachSection).restoration_visual_root.visible and (loaded_nature.zone_roots[&"reef_west"] as Node3D).visible and (loaded_nature.populations[&"section:reef_west:outer:fish"] as FishSchool).mover.looping and (loaded_nature.populations[&"zone:reef_west:01"] as FishSchool).mover.looping, "reload resumes local and regional fish without replaying reward")
	check(loaded_nature.populations.size() == population_count and restored.validate_invariants(session.definitions).is_empty(), "snapshot preserves stable school keys and restoration latches")
	loaded_session.free()
	var turtle := nature.populations[&"zone:lounges:turtle"] as PathAnimal
	check((turtle.get_child(0) as Node3D).basis.z.dot(Vector3.FORWARD) > 0.99, "turtle head is aligned with the route component's forward direction")
	check(not turtle.looping and not (nature.zone_roots[&"lounges"] as Node3D).visible, "shoreline return turtle waits for lounges restoration")
	(session.state.zone_states[&"lounges"] as Dictionary).restored_once = true
	session.zone_restored.emit(&"lounges")
	Engine.time_scale = 12.0
	for frame in range(120):
		await physics_frame
	Engine.time_scale = 1.0
	check(turtle.looping and session.swim_service.water.contains_horizontal(turtle.global_position), "turtle completes beach walk into bounded water loop")
	for point in turtle.loop_points:
		var world_point := (turtle.get_parent() as Node3D).to_global(point)
		var ground_query := PhysicsRayQueryParameters3D.create(world_point + Vector3.UP * 2.0, world_point + Vector3.DOWN * 8.0, 1)
		var ground_hit := player.get_world_3d().direct_space_state.intersect_ray(ground_query)
		check(not ground_hit.is_empty() and world_point.y > (ground_hit.get("position", Vector3.ZERO) as Vector3).y + 0.25 and world_point.y < session.swim_service.water.surface_y - 0.2, "turtle water loop stays above seabed and below surface")
	check(_nonblocking(turtle) and get_nodes_in_group("visitors").is_empty(), "turtle has no collider and no human visitors return")
	var reduced := PathAnimal.new()
	root.add_child(reduced)
	reduced.configure(&"reduced-motion-probe", [Vector3.ZERO, Vector3(0, 0, 5)], [Vector3(0, 0, 5), Vector3(0, 0, 6)], 1.0, true)
	reduced.start_intro()
	check(reduced.looping and reduced.position == Vector3(0, 0, 5), "reduced motion skips flourish but retains looping wildlife")
	reduced.free()
	if "--capture" in OS.get_cmdline_user_args():
		player.hand_rig.hide()
		player.camera.global_position = turtle.global_position + Vector3(-0.8, 0.45, 1.5)
		player.camera.look_at(turtle.global_position)
		await _capture("P21-turtle-route.png")
	print("P21_WILDLIFE ambient=2 local=4 regional=6 turtle=1 reef_clusters=24 starfish=4 failures=%d" % failures)
	main.free()
	quit(failures)


func _complete_section(session: RunSession, section_id: StringName) -> void:
	var changed := PackedStringArray()
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if not record.required or record.home_section_id != section_id:
			continue
		if record.location == ItemRecord.Location.ATTACHED:
			var site_id := StringName(str(record.attachment_id).get_slice("/", 0))
			(session.rescue_knife.sites[site_id] as RescueSite).remove_attachment(record.item_id)
			record.rescuer_id = &"local"
		record.location = ItemRecord.Location.COLLECTED
		record.container_id = &"collection:visual-fixture"
		record.holder_id = &""
		record.slot_id = &""
		changed.append(str(record.item_id))
	for rescue_value in session.state.rescue_states.values():
		var rescue := rescue_value as Dictionary
		if StringName(str(rescue.home_section_id)) == section_id:
			rescue.released = true
	session.finalize_action(changed)


func _nonblocking(node: Node) -> bool:
	if node is CollisionObject3D:
		return false
	for child in node.get_children():
		if not _nonblocking(child):
			return false
	return true


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var output_dir := "res://docs/handoffs/images"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output="):
			output_dir = arg.trim_prefix("--capture-output=")
	var disk_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var path := disk_dir.path_join(filename)
	check(root.get_texture().get_image().save_png(path) == OK, "wildlife screenshot saved")
	print("P21_CAPTURE " + path)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P21 FAIL: " + message)
