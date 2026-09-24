extends SceneTree

const REVIEW_VIEWS := [
	{"name": "aerial", "origin": Vector3(-15, 65, 135), "target": Vector3(0, 0, 0)},
	{"name": "sports-eye", "origin": Vector3(-45, 2.1, 32), "target": Vector3(-43.75, 1.7, 12)},
	{"name": "reef", "origin": Vector3(2.5, -1.25, 101), "target": Vector3(2.5, -2.25, 107.5)},
	{"name": "along-shore", "origin": Vector3(-65, 2.1, 32), "target": Vector3(60, 2.1, 37)},
	{"name": "lounge-pocket", "origin": Vector3(-34, 2.1, 0), "target": Vector3(-22, 1.2, 18)},
	{"name": "pier-head", "origin": Vector3(62.5, 3.1, 60), "target": Vector3(62.5, 3.0, 84)},
	{"name": "pier-overhead", "origin": Vector3(44, 24, 57), "target": Vector3(62.5, 1.5, 82)},
]

var review_lines := PackedStringArray()

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_msec()
	var review_pair := "--review-pair" in OS.get_cmdline_user_args()
	var audit_slots := "--audit-slots" in OS.get_cmdline_user_args()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/c04_review" if review_pair else "user://test_runs/c03_full_run"
	main.seed_input.text = "full-run-integration"
	var session := main.start_run() as RunSession
	if session == null or session.state.items.size() != 5740:
		_fail("full beach did not start with 5,740 records")
		return
	var player := session.get_node("Player") as BeachPlayer
	var placement := session.placement_service
	if review_pair and not await _capture_review(main, session, "initial"):
		_fail("initial review captures failed")
		return
	if review_pair and "--review-initial-only" in OS.get_cmdline_user_args():
		_write_review_log(session)
		main.free()
		quit(0)
		return
	var waste_ids: Array[StringName] = []
	var prop_ids: Array[StringName] = []
	for value in session.state.items.values():
		var item := value as ItemRecord
		if not item.required:
			continue
		if (session.definitions[item.definition_id] as ItemDefinition).kind == ItemDefinition.Kind.PROP:
			prop_ids.append(item.item_id)
		else:
			waste_ids.append(item.item_id)
	waste_ids.sort()
	prop_ids.sort()
	var final_special_mode := "--final-special" in OS.get_cmdline_user_args()
	var final_special := StringName()
	if final_special_mode:
		for item_id in waste_ids:
			var candidate := session.state.items[item_id] as ItemRecord
			if candidate.definition_id == &"waste_buried_metal" and candidate.dig_surface_position.y >= -0.1:
				final_special = item_id
				break
		if final_special.is_empty():
			_fail("no accessible buried metal for final input path")
			return
		waste_ids.erase(final_special)
	if waste_ids.size() != (5399 if final_special_mode else 5400) or prop_ids.size() != 300:
		_fail("required waste/prop split changed")
		return
	var final_prop := StringName()
	for item_id in prop_ids:
		var item := session.state.items[item_id] as ItemRecord
		if item.home_section_id == &"arrival:start" and item.definition_id == &"prop_beach_chair":
			final_prop = item_id
			break
	if final_prop.is_empty():
		_fail("no final starter chair")
		return
	prop_ids.erase(final_prop)
	var staged := PackedStringArray()
	for item_id in prop_ids:
		var item := session.state.items[item_id] as ItemRecord
		var slot_id := _free_slot(placement, session, item)
		if slot_id.is_empty():
			_fail("no compatible slot for %s" % item_id)
			return
		item.dirty_patches_remaining.clear() # Accelerated setup; P16 separately exercises cloth cleaning.
		placement._commit_to_slot(item_id, slot_id)
		placement._ensure_slotted_view(item_id)
		staged.append(str(item_id))
	session.finalize_action(staged)
	var final_item := session.state.items[final_prop] as ItemRecord
	final_item.dirty_patches_remaining.clear()
	var final_slot := _free_slot(placement, session, final_item)
	if final_slot.is_empty() or session.progress_service.completed_props != 299:
		_fail("could not reserve the final prop slot")
		return
	if final_special_mode:
		placement._commit_to_slot(final_prop, final_slot)
		placement._ensure_slotted_view(final_prop)
		session.finalize_action(PackedStringArray([str(final_prop)]))
	print("FULL_RUN props_staged=299 final_slot=%s elapsed_ms=%d" % [final_slot, Time.get_ticks_msec() - started])

	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	var container := session.waste_containers[&"container:S1:pmd"] as WasteContainer
	for start in range(0, waste_ids.size(), 200):
		staged.clear()
		var end := mini(start + 200, waste_ids.size())
		for index in range(start, end):
			var item_id := waste_ids[index]
			var item := session.state.items[item_id] as ItemRecord
			if item.location == ItemRecord.Location.ATTACHED:
				var site_id := StringName(str(item.attachment_id).get_slice("/", 0))
				(session.rescue_knife.sites[site_id] as RescueSite).remove_attachment(item_id)
			var cell := station.first_free_cell()
			if cell.is_empty():
				_fail("S1 table filled before batch end")
				return
			(station.table_record().cells as Dictionary)[cell] = item_id
			item.location = ItemRecord.Location.TABLE
			item.container_id = station.station_id
			item.slot_id = cell
			item.buried = false
			item.revealed = true
			staged.append(str(item_id))
		for site_key in session.state.rescue_states:
			var rescue := session.state.rescue_states[site_key] as Dictionary
			if bool(rescue.released):
				continue
			var attached := false
			for attachment_text in rescue.attachment_ids:
				if (session.state.items[StringName(str(attachment_text))] as ItemRecord).location == ItemRecord.Location.ATTACHED:
					attached = true
			if not attached:
				rescue.released = true
				(session.rescue_knife.sites[site_key] as RescueSite).release_animal()
		session.finalize_action(staged)
		station._contents_committed()
		for index in range(start, end):
			if not station.try_sort(waste_ids[index], &"pmd").ok:
				_fail("sorting failed at item %d" % index)
				return
		if end - start < 200 and not station.try_seal(&"pmd").ok:
			_fail("partial batch would not seal")
			return
		var bag_ids: Array[StringName] = []
		for bag_key in session.state.bag_records:
			var bag := session.state.bag_records[bag_key] as Dictionary
			if str(bag.location) == "RACK" and StringName(str(bag.station_id)) == station.station_id:
				bag_ids.append(StringName(str(bag_key)))
		if bag_ids.size() != 4:
			_fail("expected four sealed bags for batch %d" % start)
			return
		for bag_id in bag_ids:
			if not session.item_store.try_hold_bag(&"local", bag_id).ok or not container.try_deposit_bag(&"local", bag_id).ok:
				_fail("bag transfer failed at batch %d" % start)
				return
		var collected := session.collection_service.try_collect_containers(&"local")
		if not collected.ok or int(collected.receipt.item_count) != end - start:
			_fail("truck failed at batch %d" % start)
			return
		print("FULL_RUN collected=%d elapsed_ms=%d" % [session.progress_service.completed_waste, Time.get_ticks_msec() - started])
	if session.progress_service.completed_waste != (5399 if final_special_mode else 5400) or session.progress_service.completed_props != (300 if final_special_mode else 299) or session.results_open:
		_fail("pre-final progress is not exactly 5,699")
		return
	if not final_special_mode and bool((session.state.section_states[&"arrival:start"] as Dictionary).restored_once):
		_fail("final starter section restored too early")
		return
	for frame in 3:
		await physics_frame
	var populated_ids := PackedStringArray()
	for item_id in session.item_view_manager.views:
		populated_ids.append(str(item_id))
	await session.item_view_manager._reconcile_at_boundary(populated_ids)
	if final_special_mode:
		if not await _finish_with_special_input(session, player, station, container, final_special):
			_fail("last buried waste did not complete through detector, stick, table and truck")
			return
	else:
		if not session.item_store.try_hold(&"local", final_prop).ok:
			_fail("could not hold the final chair")
			return
		player.global_position = placement.slot_transform(final_slot).origin + Vector3(0, 0, 1.8)
		var final_placement := placement.try_place(&"local", final_slot)
		if not final_placement.ok:
			_fail("final chair would not snap into its authored slot: %s" % final_placement.message)
			return
	var receipt := session.state.completion_receipt as Dictionary
	if not session.results_open or not paused or int(receipt.get("required_total", 0)) != 5700 or int(receipt.get("collected_waste", 0)) != 5400 or int(receipt.get("slotted_props", 0)) != 300:
		_fail("first full-run completion receipt did not latch")
		return
	if receipt.get("participant_ids", []) != ["local"] or int(receipt.get("participant_count", 0)) != 1 or str(receipt.get("ruleset", "")) != "solo-beach-1" or int(receipt.get("faint_count", -1)) != 0 or int((receipt.get("gameplay_settings", {}) as Dictionary).get("bin_capacity", 0)) != SortingStation.BIN_CAPACITY:
		_fail("first full-run receipt lacks local ruleset, participant or faint metadata")
		return
	if not bool((session.state.section_states[&"arrival:start"] as Dictionary).restored_once) or not session.state.validate_invariants(session.definitions).is_empty():
		_fail("completed full beach violates restoration or ownership")
		return
	var run_id := session.state.run_id
	var completion_save := main.save_service.save_slot(&"manual")
	if not bool(completion_save.ok):
		_fail("completed full beach would not save: %s" % str(completion_save.get("message", "")))
		return
	var loaded := main.load_run(run_id, &"manual")
	if not bool(loaded.ok):
		_fail("completed full beach would not reload")
		return
	session = main.run_root as RunSession
	var restored_receipt := session.state.completion_receipt as Dictionary
	var persisted_receipt := JSON.parse_string(JSON.stringify(receipt)) as Dictionary
	if not main.results_view.visible or not paused or session.progress_service.completed_waste != 5400 or session.progress_service.completed_props != 300 or not _same_receipt(restored_receipt, persisted_receipt) or not session.state.validate_invariants(session.definitions).is_empty():
		_fail("reloaded full completion lost progress, receipt, or results")
		return
	main.results_view.continue_roaming()
	if paused or session.results_open or not _same_receipt(session.state.completion_receipt, persisted_receipt):
		_fail("completed run could not continue roaming with its receipt")
		return
	if audit_slots and not await _audit_occupied_slots(session):
		_fail("occupied destinations have blocked targets or intersecting colliders")
		return
	if "--audit-family-walk" in OS.get_cmdline_user_args() and not await _audit_family_walk(session):
		_fail("an occupied prop family lacks a normal walking approach")
		return
	if "--audit-mesh" in OS.get_cmdline_user_args() and not _audit_occupied_meshes(session):
		_fail("occupied visual bounds intersect outside the shaded lounge groups")
		return
	if (review_pair or audit_slots) and not await _exercise_review_prop(session, &"row:lounges:chairs:11:000"):
		_fail("completed lounge pocket could not remove, preview, throw-capture and restore a real chair")
		return
	if (review_pair or audit_slots) and not await _exercise_review_prop(session, &"row:sports:chairs:01:000"):
		_fail("completed shore-side sports pocket could not approach, remove and restore a real chair")
		return
	if (review_pair or audit_slots) and not await _exercise_review_prop(session, &"upright:pier:paddles:000", Vector3(4.2, 0, 5), Vector3(1.8, 0, 0), false):
		_fail("completed pier paddle rack could not be approached, picked up and replaced")
		return
	if review_pair and not await _capture_review(main, session, "restored"):
		_fail("restored review captures failed")
		return
	if review_pair and not _write_review_log(session):
		_fail("review capture log failed")
		return
	var earned_money := int((session.state.players[&"local"] as Dictionary).money)
	if not session.placement_service.try_remove(&"local", final_slot).ok or session.progress_service.completed_props != 299 or not _same_receipt(session.state.completion_receipt, persisted_receipt):
		_fail("post-results chair removal lost the original receipt")
		return
	if not bool(main.save_service.save_slot(&"manual").ok) or not bool(main.load_run(run_id, &"manual").ok):
		_fail("post-results incomplete progress would not save and reload")
		return
	session = main.run_root as RunSession
	if main.results_view.visible or paused or session.progress_service.completed_props != 299 or not _same_receipt(session.state.completion_receipt, persisted_receipt) or not bool((session.state.section_states[&"arrival:start"] as Dictionary).restored_once):
		_fail("post-results reload lost incomplete progress, receipt, or restoration")
		return
	(session.get_node("Player") as BeachPlayer).global_position = session.placement_service.slot_transform(final_slot).origin + Vector3(0, 0, 1.8)
	if not session.placement_service.try_place(&"local", final_slot).ok or session.progress_service.completed_props != 300 or int((session.state.players[&"local"] as Dictionary).money) != earned_money or not _same_receipt(session.state.completion_receipt, persisted_receipt) or not session.state.validate_invariants(session.definitions).is_empty():
		_fail("replacing the post-results chair changed its receipt, reward, or ownership")
		return
	print("FULL_RUN_COMPLETE mode=%s waste=5400 props=300 results=1 receipt=1 reloaded=2 roam_replacement=1 elapsed_ms=%d" % ["special-input" if final_special_mode else "final-prop", Time.get_ticks_msec() - started])
	quit()


func _audit_occupied_slots(session: RunSession) -> bool:
	var placement := session.placement_service
	var player := session.get_node("Player") as BeachPlayer
	var previous_position := player.global_position
	var previous_processing := player.is_physics_processing()
	player.set_physics_process(false)
	var families := {}
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.location != ItemRecord.Location.SLOTTED:
			continue
		var family := str((session.definitions[item.definition_id] as ItemDefinition).sorting_family)
		if not families.has(family):
			families[family] = []
		(families[family] as Array).append(item.item_id)
	var reachable := 0
	var total := 0
	var blocked := PackedStringArray()
	for family in families.keys():
		var family_reachable := 0
		for item_id in families[family]:
			total += 1
			var found := false
			var seen := PackedStringArray()
			var record := session.state.items[item_id] as ItemRecord
			var body := placement.slotted_views.get(item_id) as StaticBody3D
			if body != null:
				var shape := body.get_child(1) as CollisionShape3D
				if shape != null:
					var target := shape.global_position
					for offset in [Vector3(0, 0, 1.8), Vector3(1.8, 0, 0), Vector3(0, 0, -1.8), Vector3(-1.8, 0, 0)]:
						player.global_position = placement.slot_transform(record.slot_id).origin + offset
						player.camera.look_at(target)
						await physics_frame
						var aimed := player.interactor.update_target()
						seen.append("%s:%s" % [offset, aimed.get("id", "")])
						if str(aimed.get("id", "")) == str(item_id):
							found = true
							break
			if found:
				reachable += 1
				family_reachable += 1
			else:
				blocked.append(str(record.slot_id))
				print("C04_SLOT_BLOCKED slot=%s position=%s seen=%s" % [record.slot_id, placement.slot_transform(record.slot_id).origin, seen])
		print("C04_SLOT_AUDIT family=%s reachable=%d/%d" % [family, family_reachable, (families[family] as Array).size()])
	var overlaps := PackedStringArray()
	var seen_pairs := {}
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.location != ItemRecord.Location.SLOTTED:
			continue
		var body := placement.slotted_views.get(item.item_id) as StaticBody3D
		if body == null:
			continue
		var shape := body.get_child(1) as CollisionShape3D
		if shape == null:
			continue
		var probe := PhysicsShapeQueryParameters3D.new()
		probe.shape = shape.shape
		probe.transform = shape.global_transform
		probe.collision_mask = 4 | 8
		var excluded: Array[RID] = [body.get_rid()]
		probe.exclude = excluded
		for hit in body.get_world_3d().direct_space_state.intersect_shape(probe, 32):
			var other := hit.collider as StaticBody3D
			if other == null or not other.has_meta(&"placement_slot_id"):
				continue
			var ids := [str(item.slot_id), str(other.get_meta(&"placement_slot_id"))]
			ids.sort()
			var pair := "%s / %s" % ids
			if ids[0] != ids[1] and not seen_pairs.has(pair):
				seen_pairs[pair] = true
				overlaps.append(pair)
	player.global_position = previous_position
	player.set_physics_process(previous_processing)
	if not blocked.is_empty():
		push_error("C04 SLOT AUDIT: %d blocked targets; first IDs: %s" % [blocked.size(), ", ".join(blocked.slice(0, 12))])
	if not overlaps.is_empty():
		push_error("C04 SLOT AUDIT: %d overlapping occupied collider pairs; first IDs: %s" % [overlaps.size(), ", ".join(overlaps.slice(0, 12))])
	print("C04_SLOT_AUDIT targets=%d/%d families=%d overlaps=%d" % [reachable, total, families.size(), overlaps.size()])
	return reachable == total and overlaps.is_empty()


func _audit_occupied_meshes(session: RunSession) -> bool:
	var bounds := {}
	var visuals := {}
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.location != ItemRecord.Location.SLOTTED:
			continue
		var body := session.placement_service.slotted_views.get(item.item_id) as StaticBody3D
		if body == null:
			continue
		var visual := body.get_node("VisualRoot")
		var box := _visual_bounds(visual)
		if box.has_surface():
			bounds[str(item.slot_id)] = box
			visuals[str(item.slot_id)] = visual
	var keys := bounds.keys()
	var shade_candidates := 0
	var shade_contacts := PackedStringArray()
	var overlaps := PackedStringArray()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if (bounds[keys[i]] as AABB).intersects(bounds[keys[j]] as AABB):
				var shade_id := str(keys[i]) if str(keys[i]).contains("parasol") else str(keys[j])
				if shade_id.contains("parasol"):
					shade_candidates += 1
					var other_id := str(keys[j]) if shade_id == str(keys[i]) else str(keys[i])
					if not _shade_clears_occupied(visuals[shade_id], bounds[other_id]):
						shade_contacts.append("%s / %s" % [shade_id, other_id])
				else:
					overlaps.append("%s / %s" % [keys[i], keys[j]])
	print("C04_MESH_AABB occupied=%d nonshade=%d shade_candidates=%d shade_contacts=%d first=%s" % [keys.size(), overlaps.size(), shade_candidates, shade_contacts.size(), ", ".join((overlaps + shade_contacts).slice(0, 10))])
	return overlaps.is_empty() and shade_contacts.is_empty()


func _audit_family_walk(session: RunSession) -> bool:
	var player := session.get_node("Player") as BeachPlayer
	var previous_position := player.global_position
	var families := {}
	for item_value in session.state.items.values():
		var item := item_value as ItemRecord
		if item.location != ItemRecord.Location.SLOTTED:
			continue
		var family := str((session.definitions[item.definition_id] as ItemDefinition).sorting_family)
		if not families.has(family):
			families[family] = []
		(families[family] as Array).append(item)
	var passed := 0
	for family in families:
		var reached := false
		for item in (families[family] as Array).slice(0, 12):
			var record := item as ItemRecord
			var body := session.placement_service.slotted_views.get(record.item_id) as StaticBody3D
			if body == null:
				continue
			var target := (body.get_child(1) as CollisionShape3D).global_position
			var origin := session.placement_service.slot_transform(record.slot_id).origin
			for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
				var start: Vector3 = origin + direction * 5.0
				var stop_distance := 1.15 if family == "surfboard" else 1.8
				var stop: Vector3 = origin + direction * stop_distance
				var ray := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 8.0, start + Vector3.DOWN * 12.0, 1)
				var ground := player.get_world_3d().direct_space_state.intersect_ray(ray)
				if ground.is_empty():
					continue
				player.global_position = Vector3(start.x, (ground.position as Vector3).y + 0.05, start.z)
				player.velocity = Vector3.ZERO
				player.look_at(Vector3(stop.x, player.global_position.y, stop.z), Vector3.UP)
				_stick(-1.0)
				for frame in 140:
					await physics_frame
					if Vector2(player.global_position.x - stop.x, player.global_position.z - stop.z).length() < 0.35:
						break
				_stick(0.0)
				player.velocity = Vector3.ZERO
				if Vector2(player.global_position.x - stop.x, player.global_position.z - stop.z).length() >= 0.35:
					continue
				player.camera.look_at(target)
				await physics_frame
				var aimed := player.interactor.update_target()
				if str(aimed.get("id", "")) == str(record.item_id):
					reached = true
					print("C04_FAMILY_WALK family=%s slot=%s start=%s end=%s" % [family, record.slot_id, start, player.global_position])
					break
			if reached:
				break
		if reached:
			passed += 1
		else:
			print("C04_FAMILY_WALK_BLOCKED family=%s" % family)
	_stick(0.0)
	player.global_position = previous_position
	player.velocity = Vector3.ZERO
	print("C04_FAMILY_WALK reachable=%d/%d" % [passed, families.size()])
	return passed == families.size()


func _shade_clears_occupied(parasol_visual: Node, other: AABB) -> bool:
	# The umbrella mesh has a narrow shaft below 1.7 m and a canopy above it.
	var meshes := parasol_visual.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return false
	var pole := (meshes[0] as MeshInstance3D).global_position
	if other.end.y >= pole.y + 1.65:
		return false
	return pole.x < other.position.x - 0.1 or pole.x > other.end.x + 0.1 or pole.z < other.position.z - 0.1 or pole.z > other.end.z + 0.1


func _visual_bounds(node: Node) -> AABB:
	var box := AABB()
	var found := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
		found = true
	for child in node.get_children():
		var child_box := _visual_bounds(child)
		if not child_box.has_surface():
			continue
		box = box.merge(child_box) if found else child_box
		found = true
	return box


func _exercise_review_prop(session: RunSession, slot_id: StringName, walk_start_offset := Vector3(-3, 0, -5), walk_target_offset := Vector3(0, 0, -1.8), verify_throw := true) -> bool:
	var placement := session.placement_service
	var item_id := placement.occupant_for(slot_id)
	if item_id.is_empty():
		return false
	var player := session.get_node("Player") as BeachPlayer
	var body := placement.slotted_views.get(item_id) as StaticBody3D
	if body == null:
		return false
	var target := (body.get_child(1) as CollisionShape3D).global_position
	var slot_origin := placement.slot_transform(slot_id).origin
	var walk_target := slot_origin + walk_target_offset
	player.global_position = slot_origin + walk_start_offset
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(walk_target.x, player.global_position.y, walk_target.z), Vector3.UP)
	var walk_radius := 0.5 if not verify_throw else 1.25
	_stick(-1.0)
	for frame in 120:
		await physics_frame
		if Vector2(player.global_position.x - walk_target.x, player.global_position.z - walk_target.z).length() < walk_radius:
			break
	_stick(0.0)
	player.velocity = Vector3.ZERO
	if Vector2(player.global_position.x - walk_target.x, player.global_position.z - walk_target.z).length() >= walk_radius:
		print("C04_LOUNGE_APPROACH stopped=%s target=%s" % [player.global_position, walk_target])
		return false
	player.set_physics_process(false)
	var aimed := false
	if not verify_throw:
		player.camera.look_at(target)
		await physics_frame
		var reached_target := player.interactor.update_target()
		aimed = str(reached_target.get("id", "")) == str(item_id)
		if not aimed:
			print("C04_PIER_PADDLE_WALK_AIM position=%s target=%s seen=%s" % [player.global_position, target, reached_target])
			return false
	if not aimed:
		for offset in [Vector3(0, 0, 1.8), Vector3(1.8, 0, 0), Vector3(0, 0, -1.8), Vector3(-1.8, 0, 0)]:
			player.global_position = placement.slot_transform(slot_id).origin + offset
			player.camera.look_at(target)
			await physics_frame
			if str(player.interactor.update_target().get("id", "")) == str(item_id):
				aimed = true
				break
	player.set_physics_process(true)
	if not aimed:
		return false
	await _click()
	if (session.state.items[item_id] as ItemRecord).location != ItemRecord.Location.HELD:
		return false
	for frame in 20:
		await physics_frame
	var preview := placement.preview_slot(&"local", slot_id)
	var area := (placement.slots[slot_id] as Dictionary).area as Area3D
	if not preview.ok or not (area.get_node("GhostRoot") as Node3D).visible:
		return false
	player.camera.look_at((area.get_node("CaptureShape") as CollisionShape3D).global_position)
	await physics_frame
	var placing := player.interactor.update_target()
	if str(placing.get("id", "")) != str(slot_id) or not (placing.get("actions", PackedStringArray()) as PackedStringArray).has("place"):
		return false
	await _click()
	if placement.occupant_for(slot_id) != item_id:
		return false
	if not verify_throw:
		return session.progress_service.completed_props == 300 and session.state.validate_invariants(session.definitions).is_empty()
	for frame in 20:
		await physics_frame
	body = placement.slotted_views.get(item_id) as StaticBody3D
	if body == null:
		return false
	player.camera.look_at((body.get_child(1) as CollisionShape3D).global_position)
	await physics_frame
	if str(player.interactor.update_target().get("id", "")) != str(item_id):
		return false
	await _click()
	if (session.state.items[item_id] as ItemRecord).location != ItemRecord.Location.HELD:
		return false
	for frame in 20:
		await physics_frame
	if not placement.preview_slot(&"local", slot_id).ok:
		return false
	player.camera.look_at((area.get_node("CaptureShape") as CollisionShape3D).global_position)
	await physics_frame
	await _click(MOUSE_BUTTON_RIGHT)
	for frame in 90:
		await physics_frame
	var captured := placement.occupant_for(slot_id) == item_id and session.progress_service.completed_props == 300 and session.state.validate_invariants(session.definitions).is_empty()
	if not captured:
		print("C04_LOUNGE_THROW item_location=%s player=%s world_view=%s slot=%s" % [(session.state.items[item_id] as ItemRecord).location, player.global_position, session.item_view_manager.view_for(item_id), placement.slot_transform(slot_id).origin])
	return captured


func _capture_review(main: BeachMain, session: RunSession, state_name: String) -> bool:
	var output_dir := "res://docs/handoffs/images/C04"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="):
			output_dir = arg.trim_prefix("--review-output=")
	var disk_dir := ProjectSettings.globalize_path(output_dir)
	if DirAccess.make_dir_recursive_absolute(disk_dir) != OK:
		return false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.msaa_3d = main.get_viewport().msaa_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = (session.get_node("Beach") as Node3D).get_world_3d()
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 85.0
	viewport.add_child(camera)
	camera.make_current()
	var player := session.get_node("Player") as BeachPlayer
	camera.near = player.camera.near
	camera.far = player.camera.far
	var ui := main.get_node("UI") as CanvasLayer
	var ui_was_visible := ui.visible
	var player_was_visible := player.visible
	var player_was_processing := player.is_physics_processing()
	var swim_was_processing := session.swim_service.is_physics_processing()
	ui.visible = false
	player.visible = false
	player.set_physics_process(false)
	session.swim_service.set_physics_process(false)
	var errors := session.state.validate_invariants(session.definitions)
	var succeeded := errors.is_empty()
	# Identical shader phase makes successive lighting/effect reviews comparable.
	var animated_materials: Array[ShaderMaterial] = []
	for path in ["res://shaders/beach_water.tres", "res://shaders/beach_sand.tres", "res://shaders/seabed_caustics.tres", "res://art/synty/POLYGON_Palm_City/materials/PalmTree_01.tres"]:
		var material := load(path) as ShaderMaterial
		material.set_shader_parameter("debug_time", 4.0)
		animated_materials.append(material)
	var views := REVIEW_VIEWS.duplicate()
	if "--mesh-views" in OS.get_cmdline_user_args():
		views.append_array([
			{"name": "sports-paddles", "origin": Vector3(-31, 2.1, 20), "target": Vector3(-25.75, 1.1, 15)},
			{"name": "pier-paddles", "origin": Vector3(63, 3.1, 47), "target": Vector3(59.5, 2.1, 42)},
			{"name": "arrival-tents", "origin": Vector3(-46, 2.1, 22), "target": Vector3(-41, 1.1, 15)},
			{"name": "pier-seating", "origin": Vector3(47, 2.1, 20), "target": Vector3(52, 1.1, 15)},
		])
	for view in views:
		var origin := view.origin as Vector3
		camera.global_position = origin
		camera.look_at(view.target as Vector3)
		camera.environment = SwimService.UNDERWATER_ENVIRONMENT if origin.y < 0.0 else null
		player.global_position = origin
		for frame in 180:
			await physics_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var file_path := disk_dir.path_join("%s-%s.png" % [view.name, state_name])
		if image.is_empty() or image.save_png(file_path) != OK:
			succeeded = false
		if "--review-effects" in OS.get_cmdline_user_args() and str(view.name) in ["aerial", "along-shore", "sports-eye", "reef"]:
			var original := camera.environment if camera.environment != null else (session.get_node("Beach/WorldEnvironment") as WorldEnvironment).environment
			var comparison := original.duplicate() as Environment
			camera.environment = comparison
			for mode in ["raw", "glow", "grade", "combined", "identity", "no-ao"]:
				comparison.glow_enabled = original.glow_enabled and mode in ["glow", "combined", "no-ao"]
				comparison.adjustment_enabled = mode in ["grade", "combined", "identity", "no-ao"]
				comparison.adjustment_color_correction = load("res://art/look/beach_identity.res") if mode == "identity" else original.adjustment_color_correction
				comparison.ssao_enabled = original.ssao_enabled and mode != "no-ao"
				for frame in 6:
					await physics_frame
				await RenderingServer.frame_post_draw
				if viewport.get_texture().get_image().save_png(disk_dir.path_join("%s-%s-%s.png" % [view.name, state_name, mode])) != OK:
					succeeded = false
			camera.environment = original if origin.y < 0.0 else null
		review_lines.append("%s %s %s -> %s fov=85 size=1920x1080 msaa=%d near=%s far=%s populated_views=%d" % [state_name, view.name, origin, view.target, viewport.msaa_3d, camera.near, camera.far, session.item_view_manager.views.size()])
	player.set_physics_process(player_was_processing)
	session.swim_service.set_physics_process(swim_was_processing)
	player.visible = player_was_visible
	ui.visible = ui_was_visible
	viewport.free()
	for material in animated_materials:
		material.set_shader_parameter("debug_time", -1.0)
	review_lines.append("%s waste=%d props=%d invariants=%d" % [state_name, session.progress_service.completed_waste, session.progress_service.completed_props, errors.size()])
	return succeeded


func _write_review_log(session: RunSession) -> bool:
	var output_dir := "res://docs/handoffs/images/C04"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="):
			output_dir = arg.trim_prefix("--review-output=")
	var file := FileAccess.open(ProjectSettings.globalize_path(output_dir).path_join("capture-log.txt"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_line("Godot %s; content %s; seed full-run-integration; accelerated setup; main-scene source review (not an exported candidate)" % [Engine.get_version_info().string, session.state.content_version])
	var sun := session.get_node("Beach/Sun") as DirectionalLight3D
	file.store_line("Sun rotation=%s colour=%s energy=%s; renderer=%s; culling enabled" % [sun.rotation_degrees, sun.light_color, sun.light_energy, RenderingServer.get_current_rendering_method()])
	var environment := (session.get_node("Beach/WorldEnvironment") as WorldEnvironment).environment
	file.store_line("shadow_bias=%s normal_bias=%s range=%s; ambient=%s/%s; fog=%s density=%s begin=%s end=%s; AO=%s; glow=%s/%s; LUT=%s; shader phase=4s" % [sun.shadow_bias, sun.shadow_normal_bias, sun.directional_shadow_max_distance, environment.ambient_light_color, environment.ambient_light_energy, environment.fog_enabled, environment.fog_density, environment.fog_depth_begin, environment.fog_depth_end, environment.ssao_enabled, environment.glow_enabled, environment.glow_intensity, environment.adjustment_color_correction.resource_path])
	for line in review_lines:
		file.store_line(line)
	file.close()
	return true


func _finish_with_special_input(session: RunSession, player: BeachPlayer, station: SortingStation, container: WasteContainer, item_id: StringName) -> bool:
	var record := session.state.items[item_id] as ItemRecord
	var owner := session.state.players[&"local"] as Dictionary
	(owner.owned_tools as Array[StringName]).append(&"detector")
	owner.equipped_handheld_ids = [&"stick", &"detector"] as Array[StringName]
	owner.active_slot = 1
	session.progression.refresh_tool_visual()
	player.global_position = record.dig_surface_position + Vector3(0, 0, 0.9)
	player.camera.look_at(record.dig_surface_position)
	for _index in range(8):
		await physics_frame
	if session.metal_detector.nearest_find != record:
		return false
	await _click()
	if record.location != ItemRecord.Location.WORLD or not record.revealed:
		return false
	if not session.progression.try_switch_tool(&"local").ok:
		return false
	var view := session.item_view_manager.view_for(item_id)
	if view == null:
		return false
	player.global_position = view.global_position + Vector3(0, 0, 1.0)
	player.camera.look_at(view.global_position + Vector3.UP * 0.08)
	await physics_frame
	var target := player.interactor.update_target()
	if str(target.get("id", "")) != str(item_id) or not (target.get("actions", PackedStringArray()) as PackedStringArray).has("collect"):
		return false
	await _click()
	if record.location != ItemRecord.Location.BAG:
		return false
	if not station.try_unload(&"local").ok or not station.try_sort(item_id, &"pmd").ok:
		return false
	var sealed := station.try_seal(&"pmd")
	if not sealed.ok:
		return false
	var bag_id := StringName(str(sealed.receipt.bag_id))
	var truck := session.collection_service
	return session.item_store.try_hold_bag(&"local", bag_id).ok and container.try_deposit_bag(&"local", bag_id).ok and truck.try_collect_containers(&"local").ok


func _click(button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button_index
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	for _index in range(3):
		await physics_frame
	var release := InputEventMouseButton.new()
	release.button_index = button_index
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await physics_frame


func _stick(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _same_receipt(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a.get("active_seconds", -1)), float(b.get("active_seconds", -2))):
		return false
	var left := a.duplicate(true)
	var right := b.duplicate(true)
	left.erase("active_seconds")
	right.erase("active_seconds")
	return left == right


func _free_slot(placement: PlacementService, session: RunSession, item: ItemRecord) -> StringName:
	var family := (session.definitions[item.definition_id] as ItemDefinition).sorting_family
	for slot_key in placement.slots:
		var pool_id := StringName(str((placement.slots[slot_key] as Dictionary).pool_id))
		var pool := session.state.container_records[pool_id] as Dictionary
		var claim := StringName(str(pool.claim))
		if not placement.occupant_for(slot_key).is_empty() or family not in (pool.accepted_families as Array) or (not claim.is_empty() and claim != family):
			continue
		if claim.is_empty() and (pool.accepted_families as Array).size() > 1 and not placement._shared_claim_is_safe(pool_id, family, item.item_id):
			continue
		return StringName(str(slot_key))
	return StringName()


func _fail(message: String) -> void:
	push_error("FULL_RUN: " + message)
	quit(1)
