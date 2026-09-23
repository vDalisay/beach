extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := (load("res://tests/scenes/placement_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	var settings := SettingsStore.new()
	settings.settings_path = "user://p11-dirt.cfg"
	lab.add_child(settings)
	var definitions := ManifestGenerator.new().load_catalog()
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
	var placement := PlacementService.new()
	placement.name = "PlacementService"
	session.add_child(placement)
	placement.configure(session, lab, player)
	var cloth := ClothTool.new()
	cloth.name = "ClothTool"
	session.add_child(cloth)
	cloth.configure(session, player)
	var canvas := CanvasLayer.new()
	lab.add_child(canvas)
	var target_label := (load("res://scenes/ui/target_label.tscn") as PackedScene).instantiate() as TargetLabel
	canvas.add_child(target_label)
	target_label.configure(player.interactor, player.camera)
	await _physics_frames(3)

	var dirty_record := state.items[&"chair:dirty"] as ItemRecord
	var dirty_view := manager.view_for(&"chair:dirty")
	check(state.required_total == 2 and dirty_record.dirty_patches_remaining.size() == 3, "one dirty chair is one required prop with three properties, not four objectives")
	check(dirty_view.dirt_visual_count() == 3 and manager.view_for(&"chair:clean").dirt_visual_count() == 0, "per-instance dirt appears only on the authored dirty chair")
	var no_cloth_target := await _aim_patch(player, dirty_view, &"patch_1")
	check(no_cloth_target.get("kind") == "dirt_patch" and not (no_cloth_target.get("actions", PackedStringArray()) as PackedStringArray).has("clean") and str(no_cloth_target.get("reason", "")).contains("cloth"), "dirty patch gives cloth precedence and advertises explicit E carry; got %s" % no_cloth_target)
	player.interactor.request_primary()
	await physics_frame
	check(dirty_record.location == ItemRecord.Location.WORLD and dirty_record.dirty_patches_remaining.size() == 3, "primary without cloth cannot accidentally carry or clean furniture")
	player.interactor.request_interact()
	await _physics_frames(18)
	check(dirty_record.location == ItemRecord.Location.HELD and dirty_record.dirty_patches_remaining.size() == 3 and _count_dirt(player.hand_rig) == 3, "E carries dirty furniture and its patches follow the held presentation")
	player.camera.look_at(Vector3(6, 1.65, 6))
	player.interactor.request_throw()
	await _physics_frames(5)
	dirty_view = manager.view_for(&"chair:dirty")
	check(dirty_record.location == ItemRecord.Location.WORLD and dirty_view != null and dirty_view.dirt_visual_count() == 3, "throwing restores the same chair with all dirt properties")

	var player_record := state.players[&"local"] as Dictionary
	(player_record.owned_tools as Array[StringName]).append(&"cloth")
	player_record.equipped_handheld_ids = [&"cloth"] as Array[StringName]
	player_record.active_slot = 0
	player.hand_rig.set_tool_scene(load("res://scenes/tools/cloth_placeholder.tscn") as PackedScene)
	var clean_target := await _aim_patch(player, dirty_view, &"patch_1")
	check((clean_target.actions as PackedStringArray).has("clean") and (clean_target.actions as PackedStringArray).has("carry_dirty"), "cloth LMB cleans while E remains the alternate carry action")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(player, "P11-dirt-before.png", dirty_view.global_position)
		clean_target = await _aim_patch(player, dirty_view, &"patch_1")
	player.interactor.request_primary()
	await _physics_frames(2)
	check(dirty_record.location == ItemRecord.Location.WORLD and dirty_record.dirty_patches_remaining == [&"patch_2", &"patch_3"] and dirty_view.dirt_visual_count() == 2, "one fresh cloth press removes exactly one targeted patch")

	check(session.item_store.try_hold(&"local", &"chair:dirty").ok, "partly cleaned chair remains movable")
	await _physics_frames(2)
	player.carry.refresh_hand_visuals()
	_near_slot(player, placement, &"row:lab:chairs:000")
	var partial_place := placement.preview_slot(&"local", &"row:lab:chairs:000")
	check(not partial_place.ok and partial_place.message.contains("cloth"), "partly cleaned furniture remains placement-ineligible")
	var loaded := RunState.from_snapshot(state.to_snapshot())
	var loaded_record := loaded.items[&"chair:dirty"] as ItemRecord
	var reload_view := (load("res://scenes/items/world_item.tscn") as PackedScene).instantiate() as WorldItem
	lab.add_child(reload_view)
	reload_view.configure(loaded_record, definitions[loaded_record.definition_id])
	check(loaded_record.dirty_patches_remaining == [&"patch_2", &"patch_3"] and reload_view.dirt_visual_count() == 2, "snapshot reload restores the exact remaining patch IDs and visuals")
	reload_view.queue_free()
	player.camera.look_at(Vector3(6, 1.65, 6))
	player.interactor.request_throw()
	await _physics_frames(5)
	dirty_view = manager.view_for(&"chair:dirty")

	player_record.bag_capacity = 0
	var residue_view := manager.view_for(&"residue")
	var full_residue := await _aim_item(player, residue_view)
	check(full_residue.get("id") == &"residue" and full_residue.get("reason") == "Bag full", "cloth-recognized residue reports full shared bag capacity")
	player.interactor.request_primary()
	await physics_frame
	check((state.items[&"residue"] as ItemRecord).location == ItemRecord.Location.WORLD and manager.view_for(&"residue") != null, "full bag leaves standalone residue visible and unchanged")
	player_record.bag_capacity = 1
	var residue_target := await _aim_item(player, residue_view)
	check((residue_target.actions as PackedStringArray).has("collect"), "equipped cloth enables collection of the existing residue ID")
	player.interactor.request_primary()
	await _physics_frames(2)
	check((state.items[&"residue"] as ItemRecord).location == ItemRecord.Location.BAG and (player_record.trash_bag as Array[StringName]) == [&"residue"], "residue enters the bag once and remains unfinished until truck collection")

	for patch_id in [&"patch_2", &"patch_3"]:
		var target := await _aim_patch(player, dirty_view, patch_id)
		check((target.actions as PackedStringArray).has("clean"), "remaining authored patch is independently targetable: %s" % patch_id)
		player.interactor.request_primary()
		await _physics_frames(2)
	check(dirty_record.dirty_patches_remaining.is_empty() and dirty_view.dirt_visual_count() == 0, "last cloth click marks the same chair clean without adding waste")

	check(session.item_store.try_hold(&"local", &"chair:dirty").ok, "clean chair can be picked up for placement")
	await _physics_frames(2)
	_near_slot(player, placement, &"row:lab:chairs:000")
	check(placement.preview_slot(&"local", &"row:lab:chairs:000").ok and placement.try_place(&"local", &"row:lab:chairs:000").ok, "cleaned chair becomes eligible for the existing P10 placement path")
	await _physics_frames(35)

	check(state.required_total == 2 and (state.items[&"residue"] as ItemRecord).location != ItemRecord.Location.COLLECTED, "dirt cleaning and residue bagging do not change completion denominator or finish loose waste")
	check(state.validate_invariants(definitions).is_empty(), "dirt, carry, bag and slot transitions preserve one-owner invariants")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(player, "P11-dirt-after.png", placement.slot_transform(&"row:lab:chairs:000").origin)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.settings_path))
	print("P11_DIRT patches=3->2->0 residue=world/full->bag required=2 failures=%d" % failures)
	lab.free()
	quit(failures)


func _fixture_state() -> RunState:
	var state := RunState.new()
	state.run_id = "dirt-lab"
	state.add_player()
	_add_record(state, &"chair:dirty", &"prop_beach_chair", Vector3(0, 0.05, 1.2), true, [&"patch_1", &"patch_2", &"patch_3"])
	_add_record(state, &"residue", &"waste_residue", Vector3(-1.5, 0.05, 1.2), true)
	_add_record(state, &"chair:clean", &"prop_beach_chair", Vector3(2.0, 0.05, 1.2), false)
	return state


func _add_record(state: RunState, item_id: StringName, definition_id: StringName, position: Vector3, required: bool, dirt: Array[StringName] = []) -> void:
	var record := ItemRecord.new()
	record.item_id = item_id
	record.definition_id = definition_id
	record.home_section_id = &"home:lounge"
	record.home_zone_id = &"home"
	record.required = required
	record.last_world_transform = Transform3D(Basis.IDENTITY, position)
	record.dirty_patches_remaining = dirt
	state.add_item(record)


func _aim_patch(player: BeachPlayer, view: WorldItem, patch_id: StringName) -> Dictionary:
	var patch := _find_patch(view, patch_id)
	if patch == null:
		check(false, "missing visible dirt patch: %s" % patch_id)
		return {}
	player.global_position = view.global_position + Vector3(0, 0, 1.1)
	player.camera.look_at(patch.global_position)
	await physics_frame
	return player.interactor.update_target()


func _aim_item(player: BeachPlayer, view: WorldItem) -> Dictionary:
	player.global_position = view.global_position + Vector3(0, 0, 2.0)
	player.camera.look_at(view.global_position + Vector3.UP * 0.06)
	await physics_frame
	return player.interactor.update_target()


func _find_patch(node: Node, patch_id: StringName) -> DirtVisual:
	if node is DirtVisual and (node as DirtVisual).patch_id == patch_id:
		return node as DirtVisual
	for child in node.get_children():
		var found := _find_patch(child, patch_id)
		if found != null:
			return found
	return null


func _count_dirt(node: Node) -> int:
	var count := 1 if node is DirtVisual else 0
	for child in node.get_children():
		count += _count_dirt(child)
	return count


func _near_slot(player: BeachPlayer, placement: PlacementService, slot_id: StringName) -> void:
	var destination := placement.slot_transform(slot_id).origin
	player.global_position = destination + Vector3(0, 0, 1.8)
	player.camera.look_at(destination + Vector3.UP * 0.65)


func _capture(player: BeachPlayer, filename: String, focus: Vector3) -> void:
	player.global_position = focus + Vector3(0, 0, 2.3)
	player.camera.look_at(focus + Vector3.UP * 0.5)
	await RenderingServer.frame_post_draw
	var capture_path := ProjectSettings.globalize_path("res://docs/handoffs/images/%s" % filename)
	check(root.get_texture().get_image().save_png(capture_path) == OK, "dirt evidence capture saves: %s" % filename)
	print("P11_CAPTURE %s" % capture_path)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("P11 FAIL: %s" % message)
