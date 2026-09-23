extends SceneTree

var failures := 0
var bucket_events := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := (load("res://tests/scenes/placement_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	var settings := SettingsStore.new()
	settings.settings_path = "user://p10-placement.cfg"
	lab.add_child(settings)
	var definitions := _fixture_definitions()
	var state := _fixture_state()
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
	var service := PlacementService.new()
	service.name = "PlacementService"
	session.add_child(service)
	service.configure(session, lab, player)
	service.group_completed.connect(_on_group_completed)
	await _physics_frames(3)

	var shelf_a0 := &"shelf:lab:01:000"
	var shelf_a1 := &"shelf:lab:01:001"
	var shelf_b0 := &"shelf:lab:02:000"
	var chair_slot := &"row:lab:chairs:000"
	var board_slot := &"upright:lab:boards:000"
	var player_record := state.players[&"local"] as Dictionary
	var money_before := int(player_record.money)
	check(service.validation_errors.is_empty(), "authored shared shelves have uniform family domains and capacity")
	check(service.slots.size() == 8, "P05 pool markers expand to eight stable runtime slots")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(lab, player, "P10-placement-before.png")

	await _hold(session, &"bucket:red")
	_near_slot(player, service, shelf_a0)
	var preview := service.preview_slot(&"local", shelf_a0)
	var preview_ghost := ((service.slots[shelf_a0] as Dictionary).area as Area3D).get_node("GhostRoot") as Node3D
	check(preview.ok and preview_ghost.visible and service.occupant_for(shelf_a0).is_empty(), "preview is valid, visible and read-only for the selected clean bucket")
	var target := player.interactor.update_target()
	check(target.get("id") == shelf_a0 and (target.get("actions", PackedStringArray()) as PackedStringArray).has("place"), "aiming at the nearby slot exposes placement and its ghost; got %s" % target)
	player.interactor.request_primary()
	await _physics_frames(2)
	check((state.items[&"bucket:red"] as ItemRecord).location == ItemRecord.Location.SLOTTED and _pool_claim(state, &"shelf:lab:01") == &"bucket", "first placement claims its physical shelf section")

	await _hold(session, &"bucket:blue")
	_near_slot(player, service, shelf_b0)
	var unsafe_claim := service.preview_slot(&"local", shelf_b0)
	check(not unsafe_claim.ok and unsafe_claim.reason == ActionResult.Reason.CAPACITY and unsafe_claim.message.contains("existing"), "new shared claim is rejected when it would strand the remaining family")
	check(session.item_store.try_throw(&"local", Transform3D(Basis.IDENTITY, Vector3(-4, 0.05, 3)), Vector3.ZERO).ok, "capacity refusal leaves the selected bucket throwable")
	await _physics_frames(2)

	await _hold(session, &"ball")
	_near_slot(player, service, shelf_a1)
	var mixed := service.preview_slot(&"local", shelf_a1)
	check(not mixed.ok and mixed.reason == ActionResult.Reason.INVALID_CATEGORY and _pool_claim(state, &"shelf:lab:01") == &"bucket", "bucket shelf refuses a mixed beach-ball family")
	var throw_ball := session.item_store.try_throw(&"local", Transform3D(Basis.IDENTITY, Vector3(-3.2, 0.82, 3.0)), Vector3.ZERO)
	check(throw_ball.ok, "invalid click placement leaves the ball available for an ordinary throw")
	await _physics_frames(2)
	var ball_view := manager.view_for(&"ball")
	ball_view.global_transform = service.slot_transform(shelf_b0)
	ball_view.activate()
	await _physics_frames(3)
	check((state.items[&"ball"] as ItemRecord).location == ItemRecord.Location.SLOTTED and service.occupant_for(shelf_b0) == &"ball", "a body entering the clear trigger uses the same valid placement commit")

	await _hold(session, &"bucket:blue")
	_near_slot(player, service, shelf_a0)
	var occupied := service.try_place(&"local", shelf_a0)
	check(not occupied.ok and occupied.message.contains("occupied"), "occupied slot rejects a second prop without changing owners")
	_near_slot(player, service, shelf_a1)
	check(service.try_place(&"local", shelf_a1).ok, "a colour variant shares the bucket family claim")
	await _physics_frames(2)
	var bucket_group := state.group_states[&"home:sand/bucket"] as Dictionary
	check(bool(bucket_group.complete) and bucket_events == 1, "bucket group emits one event on its first false-to-true transition")

	_near_slot(player, service, shelf_a0)
	check(service.try_remove(&"local", shelf_a0).ok and not bool(bucket_group.complete), "re-pickup immediately reverses current group completion")
	_near_slot(player, service, shelf_a0)
	check(service.try_place(&"local", shelf_a0).ok and bucket_events == 2, "re-placement emits exactly one new false-to-true group event")
	_near_slot(player, service, shelf_a0)
	check(service.try_remove(&"local", shelf_a0).ok, "first bucket can be picked up repeatedly")
	_near_slot(player, service, shelf_a1)
	check(service.try_remove(&"local", shelf_a1).ok and _pool_claim(state, &"shelf:lab:01").is_empty(), "last removal empties the shelf and clears its family claim")
	player.carry.cycle_selected()
	_near_slot(player, service, shelf_a0)
	check(service.try_place(&"local", shelf_a0).ok, "released shelf accepts a fresh family claim")
	_near_slot(player, service, shelf_a1)
	check(service.try_place(&"local", shelf_a1).ok and bucket_events == 3, "variant pair can be restored after an empty reset")
	for _frame in range(90):
		await process_frame
		if service.slotted_views.has(&"bucket:red") and service.slotted_views.has(&"bucket:blue") and _has_sweep(service.slotted_views[&"bucket:red"] as Node) and _has_sweep(service.slotted_views[&"bucket:blue"] as Node):
			break
	check(_has_sweep(service.slotted_views[&"bucket:red"] as Node) and _has_sweep(service.slotted_views[&"bucket:blue"] as Node), "completed group sweeps only its own placed prop visuals")
	check(not _shares_sweep(service.slotted_views[&"bucket:red"] as Node, service.slotted_views[&"ball"] as Node), "unrelated slotted prop does not share the completed group sweep")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.15).timeout
		await _capture(lab, player, "P27-group-sweep.png")
	await create_timer(0.9).timeout
	check(not _has_sweep(service.slotted_views[&"bucket:red"] as Node), "group sweep clears its temporary overlay")
	settings.set_value(&"reduced_motion", true)
	_near_slot(player, service, shelf_a0)
	check(service.try_remove(&"local", shelf_a0).ok, "reduced-motion replay can pick up a completed group member")
	check(service.try_place(&"local", shelf_a0).ok, "reduced-motion replay can re-complete the group")
	await _physics_frames(20)
	check(not _has_sweep(service.slotted_views[&"bucket:red"] as Node), "reduced motion omits the group sweep")
	settings.set_value(&"reduced_motion", false)

	await _hold(session, &"chair:dirty")
	_near_slot(player, service, chair_slot)
	var dirty_click := service.preview_slot(&"local", chair_slot)
	check(not dirty_click.ok and dirty_click.message.contains("cloth"), "dirty chair cannot bypass cleaning through click placement")
	check(session.item_store.try_throw(&"local", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 3)), Vector3.ZERO).ok, "dirty chair returns to world physics")
	await _physics_frames(2)
	var dirty_view := manager.view_for(&"chair:dirty")
	dirty_view.global_transform = service.slot_transform(chair_slot)
	dirty_view.activate()
	await _physics_frames(3)
	check((state.items[&"chair:dirty"] as ItemRecord).location == ItemRecord.Location.WORLD and service.occupant_for(chair_slot).is_empty(), "dirty physical throw remains unsorted in the world")
	dirty_view.global_position = Vector3(5, 0.05, 3)
	dirty_view.freeze_view()

	await _hold(session, &"chair:clean")
	_near_slot(player, service, chair_slot)
	check(service.try_place(&"local", chair_slot).ok, "clean chair snaps to its authored front transform")
	await _hold(session, &"board")
	_near_slot(player, service, board_slot)
	check(service.try_place(&"local", board_slot).ok, "surfboard snaps into the authored upright orientation")
	await _physics_frames(35)

	var board_visual := (service.slotted_views[&"board"] as Node3D).get_node("VisualRoot") as Node3D
	check(board_visual.scale.is_equal_approx(Vector3.ONE), "placement pulse returns only the visual root to exact baseline scale")
	check(bucket_events == int(bucket_group.completion_transitions), "completion event count matches false-to-true transition count")
	check(int(player_record.money) == money_before + 4 * ProgressService.GROUP_REWARD and bool(bucket_group.reward_claimed), "four first-time groups pay once; replayed bucket transitions do not pay again")
	check(state.required_total == 5, "placement never changes the immutable required denominator")
	check(state.validate_invariants(definitions).is_empty(), "slot occupancy, claims and item records preserve one-owner invariants")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(lab, player, "P10-placement-after.png")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.settings_path))
	print("P10_SLOTS claims=bucket/beach_ball variants=shared group_events=%d captures=valid+dirty_reject failures=%d" % [bucket_events, failures])
	lab.free()
	quit(failures)


func _fixture_definitions() -> Dictionary:
	var definitions := ManifestGenerator.new().load_catalog()
	for variant in [[&"prop_bucket_red", "Red Bucket"], [&"prop_bucket_blue", "Blue Bucket"]]:
		var definition := (definitions[&"prop_bucket"] as ItemDefinition).duplicate(true) as ItemDefinition
		definition.definition_id = variant[0]
		definition.display_name = variant[1]
		definitions[variant[0]] = definition
	return definitions


func _fixture_state() -> RunState:
	var state := RunState.new()
	state.run_id = "placement-lab"
	state.add_player()
	_add_record(state, &"bucket:red", &"prop_bucket_red", &"home:sand", Vector3(-4.5, 0.05, 3))
	_add_record(state, &"bucket:blue", &"prop_bucket_blue", &"home:sand", Vector3(-4, 0.05, 3))
	_add_record(state, &"ball", &"prop_beach_ball", &"home:sport", Vector3(-3.2, 0.05, 3))
	_add_record(state, &"chair:clean", &"prop_beach_chair", &"home:lounge", Vector3(-0.8, 0.05, 3))
	_add_record(state, &"chair:dirty", &"prop_beach_chair", &"home:lounge", Vector3(0.8, 0.05, 3), false, [&"seat"])
	_add_record(state, &"board", &"prop_surfboard", &"home:pier", Vector3(3.2, 0.05, 3))
	return state


func _add_record(state: RunState, item_id: StringName, definition_id: StringName, home_section: StringName, position: Vector3, required := true, dirt: Array[StringName] = []) -> void:
	var record := ItemRecord.new()
	record.item_id = item_id
	record.definition_id = definition_id
	record.home_section_id = home_section
	record.home_zone_id = StringName(str(home_section).get_slice(":", 1))
	record.required = required
	record.last_world_transform = Transform3D(Basis.IDENTITY, position)
	record.dirty_patches_remaining = dirt
	state.add_item(record)


func _hold(session: RunSession, item_id: StringName) -> void:
	var result := session.item_store.try_hold(&"local", item_id)
	check(result.ok, "hold succeeds for %s" % item_id)
	await _physics_frames(2)


func _near_slot(player: BeachPlayer, service: PlacementService, slot_id: StringName) -> void:
	var destination := service.slot_transform(slot_id).origin
	player.global_position = destination + Vector3(0, 0, 1.8)
	player.camera.look_at(destination + Vector3.UP * 0.65)


func _pool_claim(state: RunState, pool_id: StringName) -> StringName:
	return StringName(str((state.container_records[pool_id] as Dictionary).get("claim", "")))


func _has_sweep(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).material_overlay != null:
		return true
	for child in node.get_children():
		if _has_sweep(child):
			return true
	return false


func _shares_sweep(left: Node, right: Node) -> bool:
	var left_material := _first_sweep_material(left)
	return left_material != null and left_material == _first_sweep_material(right)


func _first_sweep_material(node: Node) -> Material:
	if node is MeshInstance3D and (node as MeshInstance3D).material_overlay != null:
		return (node as MeshInstance3D).material_overlay
	for child in node.get_children():
		var material := _first_sweep_material(child)
		if material != null:
			return material
	return null


func _on_group_completed(payload: Dictionary) -> void:
	if StringName(str(payload.get("group_id", ""))) == &"home:sand/bucket":
		bucket_events += 1


func _capture(_lab: Node3D, player: BeachPlayer, filename: String) -> void:
	player.global_position = Vector3(0, 0, 6.4)
	player.camera.look_at(Vector3(0, 0.75, 0.35))
	await RenderingServer.frame_post_draw
	var capture_path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(capture_path) == OK, "placement evidence capture saves: %s" % filename)
	print("P10_CAPTURE %s" % capture_path)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P10 FAIL: %s" % message)
