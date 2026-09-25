extends SceneTree
## Records the game-feel vocabulary in one staged pass through the real game (seed
## feedback-sequence): hover a can, a stick collect into the bag and a blocked target (full bag);
## a chair held and thrown, then placed (ghost glide, arc and drop, settle) to complete its set
## (shine, +$15); a stain cleaned to "Clean!"; sorting at S1 (cascade, arcs into bins, stamps,
## seals and rack drops); deposits and the truck call (phone, lift-off, receipt, coins) that
## restores the starter shore (wave); then the finale after ACCELERATED completion of the rest of
## the beach. Staging uses the same calls as the checks, and ownership is asserted throughout.
## Movie: --write-movie <file>.avi --fixed-fps 30 --resolution 1920x1080 --script res://tests/record_feedback.gd
## Add `-- --reduced` for the reduced-motion walk.
## Each beat prints "P27_BEAT <name> frame=<n>" so stills can be cut from the movie.

var failures := 0
var main: BeachMain
var session: RunSession
var player: BeachPlayer


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as BeachMain
	root.add_child(main)
	main.save_service.save_root = "user://test_runs/p27_movie"
	# -- --reduced walks the same sequence with reduced motion (the J14 audit), using its own
	# settings file so the player's settings are untouched.
	if "--reduced" in OS.get_cmdline_user_args():
		main.settings_store.settings_path = "user://p27-movie-reduced.cfg"
		main.settings_store.set_value(&"reduced_motion", true)
	main.seed_input.text = "feedback-sequence"
	session = main.start_run() as RunSession
	if session == null:
		push_error("Feedback recording could not start the beach")
		quit(1)
		return
	main.save_service._autosave_pending = true
	player = session.get_node("Player") as BeachPlayer
	var placement := session.placement_service
	var prop_ids: Array[StringName] = []
	var waste_ids: Array[StringName] = []
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.home_section_id != &"arrival:start" or not item.required:
			continue
		if (session.definitions[item.definition_id] as ItemDefinition).kind == ItemDefinition.Kind.PROP:
			prop_ids.append(item.item_id)
		else:
			waste_ids.append(item.item_id)
	prop_ids.sort()
	waste_ids.sort()
	if prop_ids.size() != 10 or waste_ids.size() != 80:
		push_error("Feedback recording starter-section counts changed")
		quit(1)
		return
	var last_prop := StringName()
	for item_id in prop_ids:
		if (session.state.items[item_id] as ItemRecord).definition_id == &"prop_beach_chair":
			last_prop = item_id
			break
	if last_prop.is_empty():
		last_prop = prop_ids[prop_ids.size() - 1]
	prop_ids.erase(last_prop)
	var staged := PackedStringArray()
	for item_id in prop_ids:
		var item := session.state.items[item_id] as ItemRecord
		var slot := _free_slot(item)
		if not slot.is_empty():
			item.dirty_patches_remaining.clear()
			placement._commit_to_slot(item_id, slot)
			staged.append(str(item_id))
	if staged.size() != 9:
		push_error("Feedback recording could not stage starter props")
		quit(1)
		return
	session.finalize_action(staged)
	var prop := session.state.items[last_prop] as ItemRecord
	prop.dirty_patches_remaining.clear()
	var slot_id := _free_slot(prop)
	if slot_id.is_empty():
		push_error("Feedback recording has no final prop slot")
		quit(1)
		return
	await create_timer(1.5).timeout
	main._clear_notices()
	main.guidance_panel.hide()

	# 1. Hover a can, collect it with the stick, then a blocked target: the full bag.
	var stick_ids: Array[StringName] = []
	for item_id in waste_ids:
		var item := session.state.items[item_id] as ItemRecord
		if item.location == ItemRecord.Location.WORLD and ItemStore.collection_tool_for(item, session.definitions[item.definition_id] as ItemDefinition).is_empty():
			stick_ids.append(item_id)
	var cans: Array[StringName] = []
	for item_id in stick_ids:
		if str((session.state.items[item_id] as ItemRecord).definition_id).contains("can"):
			cans.append(item_id)
	var first_can := cans[0] if not cans.is_empty() else stick_ids[0]
	var blocked_can := cans[1] if cans.size() > 1 else stick_ids[1]
	await _face((session.state.items[first_can] as ItemRecord).last_world_transform.origin, 1.4)
	await create_timer(1.0).timeout
	_beat("hover_can")
	_check(StringName(str(player.interactor.current_target.get("id", ""))) == first_can, "hover the can")
	player.interactor.request_primary()
	await create_timer(0.9).timeout
	_beat("stick_collect")
	_check((session.state.items[first_can] as ItemRecord).location == ItemRecord.Location.BAG, "the stick collects the can into the bag")
	for item_id in stick_ids:
		if item_id == first_can or item_id == blocked_can:
			continue
		if not session.item_store.try_collect(&"local", item_id).ok:
			break
	await _face((session.state.items[blocked_can] as ItemRecord).last_world_transform.origin, 1.4)
	await create_timer(0.8).timeout
	player.interactor.request_primary()
	await create_timer(0.5).timeout
	_beat("blocked_full_bag")
	_check((session.state.items[blocked_can] as ItemRecord).location == ItemRecord.Location.WORLD, "a full bag blocks the next can")
	await create_timer(0.7).timeout

	# 2. Hold and throw the chair, pick it back up and place it: ghost glide, arc, drop and settle,
	# which completes its set (shine, +$15).
	var prop_position := prop.last_world_transform.origin
	await _face(prop_position + Vector3.UP * 0.45, 1.6)
	await create_timer(0.8).timeout
	var target := player.interactor.update_target()
	_check(StringName(str(target.get("id", ""))) == last_prop, "aim at the last Synty prop")
	player.carry._hold_target(target)
	_check(prop.location == ItemRecord.Location.HELD, "pick up the last Synty prop")
	await create_timer(0.8).timeout
	player.carry._on_throw_requested()
	_check(prop.location == ItemRecord.Location.WORLD, "throw the prop")
	await create_timer(0.3).timeout
	_beat("throw_impact")
	await create_timer(0.9).timeout
	_check(session.item_store.try_hold(&"local", last_prop).ok, "pick the thrown prop back up")
	player.carry.refresh_hand_visuals()
	await create_timer(0.6).timeout
	var destination := placement.slot_transform(slot_id).origin
	var neighbour := _neighbour_slot(prop, slot_id)
	# Stand in reach of both slots: the ghost shows over the neighbour, then glides to the target
	# as the aim turns.
	var middle := destination if neighbour.is_empty() else (destination + placement.slot_transform(neighbour).origin) * 0.5
	var stand_at := middle + Vector3(0, 0, 1.5)
	stand_at.y = maxf(Coastline.surface_y(stand_at.x, stand_at.z), destination.y - 0.5) + 0.05
	player.global_position = stand_at
	await create_timer(0.2).timeout
	if not neighbour.is_empty():
		_aim(placement.slot_transform(neighbour).origin + Vector3.UP * 0.3)
		await create_timer(0.9).timeout
		_beat("ghost_neighbour")
	_aim(destination + Vector3.UP * 0.3)
	await create_timer(0.7).timeout
	_beat("ghost_glide")
	if StringName(str(player.interactor.current_target.get("slot_id", ""))) == slot_id:
		player.interactor.request_primary()
	else:
		placement.try_place(&"local", slot_id)
	_check(prop.location == ItemRecord.Location.SLOTTED and prop.slot_id == slot_id, "snap the last prop and show group sweep")
	await create_timer(0.35).timeout
	_beat("place_arc_drop")
	await create_timer(1.0).timeout
	_beat("set_shine")
	await create_timer(1.2).timeout

	# 3. The cloth (staged into the hands) cleans a stain to "Clean!".
	var record := session.state.players[&"local"] as Dictionary
	(record.owned_tools as Array[StringName]).append(&"cloth")
	var equipped: Array[StringName] = [&"cloth", &"stick"]
	record.equipped_handheld_ids = equipped
	record.active_slot = 0
	session.progression.refresh_tool_visual()
	session.finalize_action(PackedStringArray(), PackedStringArray(["local"]))
	main._clear_notices()
	main.guidance_panel.hide()
	var cleaned := await _clean_nearest_stain()
	_beat("clean")
	_check(cleaned, "the cloth cleans a stain to Clean!")
	await create_timer(1.2).timeout
	record.active_slot = 1
	session.progression.refresh_tool_visual()
	session.finalize_action(PackedStringArray(), PackedStringArray(["local"]))

	# 4. Sort at S1: the bag unloads in a cascade, a few items arc into their bins and stamp.
	var station := session.sorting_stations[&"sorting:S1"] as SortingStation
	player.global_position = station.global_position + Vector3(0, 0.05, 2.5)
	await create_timer(0.3).timeout
	station.enter()
	var view := main.sorting_view
	view._zoom(-1.3)
	view._pan(Vector2(0.0, -0.8))
	await create_timer(0.6).timeout
	view._unload()
	await create_timer(0.35).timeout
	_beat("table_cascade")
	await create_timer(0.9).timeout
	var view_sorted := 0
	for index in SortingStation.CELL_COUNT:
		var item_id := station.item_at(index)
		if item_id.is_empty():
			continue
		var category := (session.definitions[(session.state.items[item_id] as ItemRecord).definition_id] as ItemDefinition).waste_category
		if view._sort(item_id, category):
			view_sorted += 1
			await create_timer(0.35).timeout
			if view_sorted == 2:
				_beat("table_arc_stamp")
			await create_timer(0.45).timeout
		if view_sorted == 3:
			break
	_check(view_sorted == 3, "three items sort through the table view")
	await create_timer(0.8).timeout
	station.exit()
	await create_timer(0.3).timeout
	# The rest of the starter waste goes through the same station calls (staged onto the table).
	staged.clear()
	for item_id in waste_ids:
		var item := session.state.items[item_id] as ItemRecord
		if item.location not in [ItemRecord.Location.WORLD, ItemRecord.Location.BURIED, ItemRecord.Location.ATTACHED]:
			continue
		if item.location == ItemRecord.Location.ATTACHED:
			var site_id := StringName(str(item.attachment_id).get_slice("/", 0))
			(session.rescue_knife.sites[site_id] as RescueSite).remove_attachment(item_id)
			item.rescuer_id = &"local"
		item.buried = false
		item.revealed = true
		var cell := station.first_free_cell()
		(station.table_record().cells as Dictionary)[cell] = item_id
		item.location = ItemRecord.Location.TABLE
		item.container_id = station.station_id
		item.slot_id = cell
		staged.append(str(item_id))
	session.finalize_action(staged)
	station._contents_committed()
	for index in SortingStation.CELL_COUNT:
		var item_id := station.item_at(index)
		if item_id.is_empty():
			continue
		var category := (session.definitions[(session.state.items[item_id] as ItemRecord).definition_id] as ItemDefinition).waste_category
		_check(station.try_sort(item_id, SortingStation.CATEGORIES[category]).ok, "sort starter waste")
	# Seal each filled bin while facing the station: the bags drop onto the rack.
	player.global_position = station.global_position + Vector3(0, 0.05, 3.2)
	await create_timer(0.2).timeout
	_aim(station.global_position + Vector3.UP * 0.8)
	await create_timer(0.5).timeout
	for category in SortingStation.CATEGORIES:
		if not (station.bin_record(category).items as Array).is_empty():
			_check(station.try_seal(category).ok, "seal starter bags")
			await create_timer(0.45).timeout
	_beat("seal_rack_drop")
	await create_timer(0.6).timeout

	# 5. Deposit every bag in its container, then call the truck from the hotline: the phone
	# rings, the containers lift off, the receipt types and counts, coins fly, and the starter
	# shore restores behind them (wave).
	var call_point: CollectionCallPoint
	for node in get_nodes_in_group("collection_call_points"):
		if (node as CollectionCallPoint).station_id == &"S1":
			call_point = node as CollectionCallPoint
	var nature := session.get_node("RestorationSection") as RestorationSection
	var shore := nature.section_origin(&"arrival:start")
	var away := call_point.global_position - shore
	away.y = 0.0
	var stand := call_point.global_position + away.normalized() * 7.0
	stand.y = Coastline.surface_y(stand.x, stand.z) + 0.05
	player.global_position = stand
	await create_timer(0.2).timeout
	_aim(call_point.global_position.lerp(shore, 0.35) + Vector3.UP * 0.6)
	await create_timer(0.4).timeout
	for bag_key in session.state.bag_records.keys():
		var bag_id := StringName(str(bag_key))
		var bag := session.state.bag_records[bag_id] as Dictionary
		if str(bag.location) != "RACK":
			continue
		var container := session.waste_containers[StringName("container:S1:%s" % str(bag.category))] as WasteContainer
		_check(session.item_store.try_hold_bag(&"local", bag_id).ok and container.try_deposit_bag(&"local", bag_id).ok, "deposit starter bag")
		await create_timer(0.35).timeout
	_beat("deposit")
	await create_timer(0.5).timeout
	call_point._on_interact_requested({"id": "collection:S1"})
	await create_timer(0.4).timeout
	_beat("truck_call")
	# Cut to the restoring shore (the hut hides it from the hotline): the wave sweeps out and the
	# palm pops in, while the receipt counts and its coins fly on the HUD.
	var shore_view := shore + Vector3(-5.0, 0.0, 6.0)
	shore_view.y = Coastline.surface_y(shore_view.x, shore_view.z) + 0.1
	player.global_position = shore_view
	await create_timer(0.05).timeout
	_aim(shore + Vector3(1.5, 0.6, -2.0))
	await create_timer(0.3).timeout
	_beat("restoration_wave")
	await create_timer(0.8).timeout
	_beat("receipt_coins")
	await create_timer(2.2).timeout
	_check(bool((session.state.section_states[&"arrival:start"] as Dictionary).restored_once), "starter shore restored")
	_check(session.state.validate_invariants(session.definitions).is_empty(), "recording preserves item ownership")

	# 6. The finale, after ACCELERATED completion: every other required prop committed to a free
	# slot and every other required waste item collected in one commit (as validate_full_run.gd
	# and validate_wildlife.gd stage them); the last chair is then placed for real.
	var final_prop := _stage_rest_of_beach()
	await create_timer(5.0).timeout
	main._clear_notices()
	main.guidance_panel.hide()
	var final_item := session.state.items[final_prop] as ItemRecord
	final_item.dirty_patches_remaining.clear()
	var final_slot := _free_slot(final_item)
	_check(not final_slot.is_empty() and session.item_store.try_hold(&"local", final_prop).ok, "hold the final prop")
	player.carry.refresh_hand_visuals()
	var final_at := placement.slot_transform(final_slot).origin
	player.global_position = final_at + Vector3(0, 0, 1.8)
	await create_timer(0.2).timeout
	_aim(final_at + Vector3.UP * 0.3)
	await create_timer(0.8).timeout
	_check(placement.try_place(&"local", final_slot).ok and session.results_open and paused, "the last placement opens the finale")
	await create_timer(1.2).timeout
	_beat("finale_flash")
	await create_timer(0.9).timeout
	_beat("finale_postcard")
	await create_timer(1.6).timeout
	_beat("finale_final")
	await create_timer(1.0).timeout
	main.results_view.continue_roaming()
	await create_timer(0.8).timeout
	_check(session.state.validate_invariants(session.definitions).is_empty(), "the finished recording preserves item ownership")
	print("P27_FEEDBACK pickup=1 throw=1 snap=1 sweep=1 restoration=1 finale=1 failures=%d" % failures)
	quit(failures)


## Stands `distance` away from `target` (level with it, toward +z unless `from` is given) and
## turns to it as mouse look does.
func _face(target: Vector3, distance: float, from := Vector3.INF) -> void:
	var toward := Vector3(0, 0, 1) if not from.is_finite() else (from - target)
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		toward = Vector3(0, 0, 1)
	var at := target + toward.normalized() * distance
	at.y = maxf(Coastline.surface_y(at.x, at.z), target.y - 0.5) + 0.05
	player.global_position = at
	await create_timer(0.1).timeout
	_aim(target)


func _aim(target: Vector3) -> void:
	var flat := Vector3(target.x, player.global_position.y, target.z)
	if flat.distance_to(player.global_position) > 0.01:
		player.look_at(flat, Vector3.UP)
	player.camera.look_at(target)


## The dirty prop nearest the player, its stains cleaned one by one with the cloth.
func _clean_nearest_stain() -> bool:
	var best := StringName()
	var best_distance := INF
	for value in session.state.items.values():
		var item := value as ItemRecord
		if item.location != ItemRecord.Location.WORLD or item.dirty_patches_remaining.is_empty():
			continue
		var distance := item.last_world_transform.origin.distance_to(player.global_position)
		if distance < best_distance:
			best = item.item_id
			best_distance = distance
	if best.is_empty():
		return false
	var at := (session.state.items[best] as ItemRecord).last_world_transform.origin
	await _face(at, 2.4)
	await create_timer(0.6).timeout
	var view := session.item_view_manager.view_for(best)
	if view == null:
		return false
	for patch_id in view.record.dirty_patches_remaining.duplicate():
		var patch := view._dirt_visuals.get(patch_id) as DirtVisual
		if patch == null:
			continue
		for attempt in 8:
			# Stand 1.3 m from the stain on the ground, trying sides until nothing blocks it.
			var around := Vector3(cos(attempt * TAU / 8.0), 0.0, sin(attempt * TAU / 8.0))
			var stand := patch.global_position + around * 1.3
			stand.y = maxf(Coastline.surface_y(stand.x, stand.z), patch.global_position.y - 0.6) + 0.05
			player.global_position = stand
			player.velocity = Vector3.ZERO
			await create_timer(0.1).timeout
			_aim(patch.global_position)
			await create_timer(0.4).timeout
			if str(player.interactor.current_target.get("kind", "")) == "dirt_patch":
				break
		player.interactor.request_primary()
		await create_timer(0.6).timeout
	return is_instance_valid(view) and view.record.dirty_patches_remaining.is_empty()


## Accelerated: every required prop but one chair committed to a free slot, and every required
## waste item still in play collected, in one commit each. Returns the chair left for the finale.
func _stage_rest_of_beach() -> StringName:
	var placement := session.placement_service
	var final_prop := StringName()
	var props: Array[StringName] = []
	var wastes: Array[StringName] = []
	for value in session.state.items.values():
		var item := value as ItemRecord
		if not item.required:
			continue
		if (session.definitions[item.definition_id] as ItemDefinition).kind == ItemDefinition.Kind.PROP:
			if item.location != ItemRecord.Location.SLOTTED:
				props.append(item.item_id)
		elif item.location != ItemRecord.Location.COLLECTED:
			wastes.append(item.item_id)
	props.sort()
	wastes.sort()
	for item_id in props:
		if (session.state.items[item_id] as ItemRecord).definition_id == &"prop_beach_chair":
			final_prop = item_id
			break
	props.erase(final_prop)
	var staged := PackedStringArray()
	for item_id in props:
		var item := session.state.items[item_id] as ItemRecord
		var slot := _free_slot(item)
		if slot.is_empty():
			continue
		item.dirty_patches_remaining.clear()
		placement._commit_to_slot(item_id, slot)
		placement._ensure_slotted_view(item_id)
		staged.append(str(item_id))
	session.finalize_action(staged)
	staged = PackedStringArray()
	for item_id in wastes:
		var item := session.state.items[item_id] as ItemRecord
		if item.location == ItemRecord.Location.ATTACHED:
			var site_id := StringName(str(item.attachment_id).get_slice("/", 0))
			(session.rescue_knife.sites[site_id] as RescueSite).remove_attachment(item_id)
			item.rescuer_id = &"local"
		item.location = ItemRecord.Location.COLLECTED
		item.container_id = &"collection:visual-fixture"
		item.holder_id = &""
		item.slot_id = &""
		item.buried = false
		item.revealed = true
		staged.append(str(item_id))
	for site_key in session.state.rescue_states:
		var rescue := session.state.rescue_states[site_key] as Dictionary
		var attached := false
		for attachment_text in rescue.attachment_ids:
			if (session.state.items[StringName(str(attachment_text))] as ItemRecord).location == ItemRecord.Location.ATTACHED:
				attached = true
		if not attached and not bool(rescue.released):
			rescue.released = true
			(session.rescue_knife.sites[site_key] as RescueSite).release_animal()
	session.finalize_action(staged)
	return final_prop


func _free_slot(item: ItemRecord) -> StringName:
	var placement := session.placement_service
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


## A free slot beside `slot_id` that the same prop could take, for the ghost to glide from.
func _neighbour_slot(item: ItemRecord, slot_id: StringName) -> StringName:
	var placement := session.placement_service
	var family := (session.definitions[item.definition_id] as ItemDefinition).sorting_family
	var origin := placement.slot_transform(slot_id).origin
	var best := StringName()
	var best_distance := 1.4
	for slot_key in placement.slots:
		if StringName(str(slot_key)) == slot_id or not placement.occupant_for(slot_key).is_empty():
			continue
		var pool := session.state.container_records[StringName(str((placement.slots[slot_key] as Dictionary).pool_id))] as Dictionary
		var claim := StringName(str(pool.claim))
		if family not in (pool.accepted_families as Array) or (not claim.is_empty() and claim != family):
			continue
		var distance := placement.slot_transform(slot_key).origin.distance_to(origin)
		if distance > 0.5 and distance < best_distance:
			best = StringName(str(slot_key))
			best_distance = distance
	return best


func _beat(name: String) -> void:
	print("P27_BEAT %s frame=%d" % [name, Engine.get_frames_drawn()])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P27 feedback: " + message)
