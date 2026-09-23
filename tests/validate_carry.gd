extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := (load("res://tests/scenes/interaction_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	var settings := SettingsStore.new()
	settings.settings_path = "user://p09-carry.cfg"
	lab.add_child(settings)
	var definitions := ManifestGenerator.new().load_catalog()
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
	player.configure(settings, session)
	var target_label := lab.get_node("%TargetLabel") as TargetLabel
	target_label.configure(player.interactor, player.camera)
	var feedback := {"message": ""}
	player.carry.feedback_requested.connect(func(message: String) -> void: feedback.message = message)
	await _physics_frames(3)
	var required_before := state.required_total
	var money_before := int((state.players[&"local"] as Dictionary).money)

	await _primary_item(player, manager, &"waste:a")
	await _primary_item(player, manager, &"waste:b")
	await _primary_item(player, manager, &"waste:c")
	var player_record := state.players[&"local"] as Dictionary
	check((player_record.trash_bag as Array[StringName]) == [&"waste:a", &"waste:b", &"waste:c"], "A/B/C collect in stable bag order while presentation overlaps")
	check((state.items[&"waste:a"] as ItemRecord).location == ItemRecord.Location.BAG and manager.view_for(&"waste:a") == null, "collection commits before its travel view finishes")
	check(&"definition:waste_can" in player_record.discoveries and &"material:metal" in player_record.discoveries, "collection discovers definition and material")

	player.camera.look_at(Vector3(-6, 1.65, 6))
	player.interactor.request_throw()
	await _physics_frames(24)
	check((state.items[&"waste:c"] as ItemRecord).location == ItemRecord.Location.WORLD and (player_record.trash_bag as Array[StringName]) == [&"waste:a", &"waste:b"], "first bag throw releases C")
	check(manager.view_for(&"waste:c") != null, "thrown bag item regains one physical view")
	player.interactor.request_throw()
	await _physics_frames(4)
	check((state.items[&"waste:b"] as ItemRecord).location == ItemRecord.Location.WORLD and (player_record.trash_bag as Array[StringName]) == [&"waste:a"], "second bag throw releases B")

	player_record.bag_capacity = 1
	var full_context := {"target_id": "waste:d", "visible": true, "distance": 1.0, "reach": 2.5}
	var full_result := session.item_store.try_collect(&"local", &"waste:d", full_context)
	check(not full_result.ok and full_result.reason == ActionResult.Reason.CAPACITY and (state.items[&"waste:d"] as ItemRecord).location == ItemRecord.Location.WORLD, "full shared bag rejects waste without mutation")
	player_record.equipped_handheld_ids = [&"stick"] as Array[StringName]
	var valuable_context := {"target_id": "valuable", "visible": true, "distance": 1.0, "reach": 2.5}
	var valuable_result := session.item_store.try_collect(&"local", &"valuable", valuable_context)
	check(not valuable_result.ok and valuable_result.reason == ActionResult.Reason.CAPACITY and (state.items[&"valuable"] as ItemRecord).location == ItemRecord.Location.WORLD, "optional valuables share the same capacity limit")
	player_record.equipped_handheld_ids = [&"stick"] as Array[StringName]
	player_record.bag_capacity = 20

	await _primary_item(player, manager, &"prop:bucket")
	await _primary_item(player, manager, &"prop:ball")
	var held := player_record.held_objects as Array[Dictionary]
	check(_held_ids(held) == [&"prop:bucket", &"prop:ball"], "two small props occupy the two ordered hand units")
	check(not player.hand_rig.bag_placeholder.visible, "bag and tool presentation stows while carrying")
	player.carry.cycle_selected()
	check(player.carry.selected_held_item() == &"prop:bucket", "held selection cycles independently of pickup order")
	player.camera.look_at(Vector3(6, 1.65, 6))
	player.interactor.request_throw()
	await _physics_frames(4)
	check((state.items[&"prop:ball"] as ItemRecord).location == ItemRecord.Location.WORLD and player.carry.selected_held_item() == &"prop:bucket", "RMB throws latest held prop, not selected prop")
	check(manager.view_for(&"prop:ball") != null and not manager.view_for(&"prop:ball").sleeping, "throw during pickup travel cancels the proxy and activates one world body")

	await _primary_item(player, manager, &"prop:spade")
	var third_small := session.item_store.try_hold(&"local", &"prop:speaker")
	check(not third_small.ok and third_small.reason == ActionResult.Reason.CAPACITY, "third small prop is rejected when both hands are full")
	var large_while_full := session.item_store.try_hold(&"local", &"prop:chair")
	check(not large_while_full.ok and large_while_full.reason == ActionResult.Reason.CAPACITY, "large prop cannot enter partially occupied hands")

	var release_transforms := {}
	var release_index := 0
	for item_id in _carried_item_ids(player_record):
		release_transforms[item_id] = Transform3D(Basis.IDENTITY, Vector3(-3.0 + release_index * 0.5, 0.05, 2.5))
		release_index += 1
	var release_result := player.carry.release_all_items(release_transforms)
	check(release_result.ok and (player_record.held_objects as Array).is_empty() and (player_record.trash_bag as Array).is_empty(), "shared release-all transaction drops every carried item once")
	await _physics_frames(3)

	var chair_view := manager.view_for(&"prop:chair")
	chair_view.global_position = Vector3(0, 0.05, -1.5)
	chair_view.synchronize_record()
	await _primary_item(player, manager, &"prop:chair")
	await _physics_frames(18)
	check((state.items[&"prop:chair"] as ItemRecord).location == ItemRecord.Location.HELD and is_equal_approx(player.movement.carry_speed_multiplier, 0.8), "large prop consumes both hands and applies the carry movement multiplier")
	feedback.message = ""
	check(not player.carry.request_tool_switch() and str(feedback.message).contains("Place or throw"), "tool switching is rejected while hands are occupied")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var capture_path := ProjectSettings.globalize_path("res://docs/handoffs/images/P09-large-carry.png")
		check(root.get_texture().get_image().save_png(capture_path) == OK, "carry evidence capture saves")
		print("P09_CAPTURE %s" % capture_path)

	player.camera.look_at((lab.get_node("Occluder") as Node3D).global_position)
	feedback.message = ""
	player.interactor.request_throw()
	await _physics_frames(2)
	check((state.items[&"prop:chair"] as ItemRecord).location == ItemRecord.Location.HELD and str(feedback.message).contains("room"), "blocked throw leaves the large prop in hand")
	player.camera.look_at(Vector3(0, 1.2, 6))
	player.interactor.request_throw()
	await _physics_frames(4)
	check((state.items[&"prop:chair"] as ItemRecord).location == ItemRecord.Location.WORLD and manager.view_for(&"prop:chair") != null, "clear throw restores the same large prop to physics")
	check(player.hand_rig.bag_placeholder.visible and is_equal_approx(player.movement.carry_speed_multiplier, 1.0), "empty hands restore bag presentation and movement speed")

	check(state.required_total == required_before and int(player_record.money) == money_before, "pickup and throws do not change completion totals or money")
	check(state.validate_invariants(definitions).is_empty(), "carry flow preserves one-owner invariants")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.settings_path))
	print("P09_CARRY_LIFO bag=A/B/C throws=C/B hands=2 large_cost=2 failures=%d" % failures)
	lab.free()
	quit(failures)


func _primary_item(player: BeachPlayer, manager: ItemViewManager, item_id: StringName) -> void:
	var view := manager.view_for(item_id)
	if view == null:
		check(false, "missing fixture view %s" % item_id)
		return
	player.camera.look_at(view.global_position + Vector3.UP * WorldItem.profile_size(view.definition.collision_profile).y * 0.5)
	await physics_frame
	var target := player.interactor.update_target()
	check(target.get("id") == item_id, "aim resolves %s before primary" % item_id)
	player.interactor.request_primary()
	await physics_frame


func _fixture_state() -> RunState:
	var state := RunState.new()
	state.run_id = "carry-lab"
	state.add_player()
	_add_record(state, &"waste:a", &"waste_can", Vector3(-1.2, 0.05, -1.5))
	_add_record(state, &"waste:b", &"waste_can", Vector3(-0.4, 0.05, -1.6))
	_add_record(state, &"waste:c", &"waste_can", Vector3(0.4, 0.05, -1.6))
	_add_record(state, &"waste:d", &"waste_can", Vector3(1.2, 0.05, -1.5))
	_add_record(state, &"valuable", &"valuable_keys", Vector3(-1.8, 0.05, -1.0), false)
	_add_record(state, &"prop:bucket", &"prop_bucket", Vector3(-1.4, 0.05, -0.8))
	_add_record(state, &"prop:ball", &"prop_beach_ball", Vector3(-0.55, 0.05, -0.8))
	_add_record(state, &"prop:spade", &"prop_spade", Vector3(0.3, 0.05, -0.8))
	_add_record(state, &"prop:speaker", &"prop_speaker", Vector3(1.15, 0.05, -0.8))
	_add_record(state, &"prop:chair", &"prop_beach_chair", Vector3(4.0, 0.05, 0.0))
	return state


func _add_record(state: RunState, item_id: StringName, definition_id: StringName, position: Vector3, required := true) -> void:
	var record := ItemRecord.new()
	record.item_id = item_id
	record.definition_id = definition_id
	record.home_section_id = &"carry:lab"
	record.home_zone_id = &"carry"
	record.required = required
	record.last_world_transform = Transform3D(Basis.IDENTITY, position)
	record.sleeping = true
	state.add_item(record)


func _held_ids(held: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for object_ref in held:
		result.append(StringName(str(object_ref.id)))
	return result


func _carried_item_ids(player_record: Dictionary) -> Array[StringName]:
	var result := _held_ids(player_record.held_objects as Array[Dictionary])
	result.append_array(player_record.trash_bag as Array[StringName])
	result.append_array(player_record.valuable_bag as Array[StringName])
	return result


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P09 FAIL: %s" % message)
