extends SceneTree

const ASSET_MANIFEST_PATH := "res://data/asset_manifest.json"
const STAGE_INDEX_PATH := "res://art/synty/stage_hashes.json"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "main scene loads")
	if packed != null:
		var main := packed.instantiate() as BeachMain
		root.add_child(main)
		main.save_service.save_root = "user://test_runs/legacy"
		await process_frame
		check(main != null, "main scene uses BeachMain")
		var first_run := main.start_run()
		check(first_run is RunSession, "start creates a RunSession")
		if first_run is RunSession:
			var first_session := first_run as RunSession
			check(first_session.state.required_total == 5700 and first_session.state.items.size() == 5740, "playable run starts from the full manifest")
			check(not first_session.state.initial_manifest_hash.is_empty(), "playable run retains its manifest hash")
			check(first_session.item_view_manager != null and first_session.item_view_manager.views.size() > 0 and first_session.item_view_manager.views.size() < 5376, "playable run streams nearby views while retaining all WORLD records")
		check(first_run.get_parent() == main, "run root is attached")
		var second_run := main.start_run()
		check(not is_instance_valid(first_run), "old run root is freed before replacement")
		check(second_run.get_parent() == main, "replacement run root is attached")
		main.settings_store.settings_path = "user://p03-menu-check.cfg"
		main.settings_menu.open_menu(main.settings_store)
		await process_frame
		check(main.settings_menu.visible and paused, "settings opens as a paused modal")
		var first_focus := root.gui_get_focus_owner()
		check(first_focus != null, "settings assigns keyboard/controller focus")
		var down := InputEventJoypadButton.new()
		down.button_index = JOY_BUTTON_DPAD_DOWN
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame
		down.pressed = false
		Input.parse_input_event(down)
		check(root.gui_get_focus_owner() != first_focus, "controller direction follows the focus graph")
		var cancel := InputEventJoypadButton.new()
		cancel.button_index = JOY_BUTTON_B
		cancel.pressed = true
		Input.parse_input_event(cancel)
		await process_frame
		cancel.pressed = false
		Input.parse_input_event(cancel)
		check(not main.settings_menu.visible, "controller cancel exits settings")
		check(not paused, "closing settings restores the prior pause state")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_store.settings_path))
		main.free()
	check_asset_closure()
	check_ownership()
	await check_input_bindings()
	check_manifest_generation()

	if failures == 0:
		print("PASS: boot, asset_closure, ownership, input_bindings, manifest")
	quit(failures)


func check(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: %s" % message)


func check_asset_closure() -> void:
	check(FileAccess.file_exists(STAGE_INDEX_PATH), "staged asset index exists")
	if not FileAccess.file_exists(STAGE_INDEX_PATH):
		return

	var rows_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGE_INDEX_PATH))
	check(rows_value is Array, "staged asset index is valid JSON")
	if not rows_value is Array:
		return
	for row_value in rows_value as Array:
		var row := row_value as Dictionary
		var path := str(row.get("path", ""))
		check(FileAccess.file_exists(path), "staged dependency exists: %s" % path)
		if FileAccess.file_exists(path):
			check(_sha256(FileAccess.get_file_as_bytes(path)) == str(row.get("sha256", "")), "staged dependency hash matches: %s" % path)

	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSET_MANIFEST_PATH))
	check(manifest_value is Dictionary, "asset manifest is valid JSON")
	if not manifest_value is Dictionary:
		return
	for asset_value in (manifest_value as Dictionary).get("assets", []):
		var wrapper_path := str((asset_value as Dictionary).get("wrapper_scene", ""))
		var packed := load(wrapper_path) as PackedScene
		check(packed != null, "staged wrapper loads: %s" % wrapper_path)
		if packed != null:
			packed.instantiate().free()


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func check_ownership() -> void:
	var definitions := _fixture_definitions()
	var state_a := _fixture_state()
	var state_b := _fixture_state()
	var session := RunSession.new()
	session.initialize(state_a, definitions)
	root.add_child(session)

	var observation := {
		"revision": -1,
		"saw_finalized_item": false,
		"kept_followup_deferred": false,
	}
	session.items_changed.connect(func(ids: PackedStringArray) -> void:
		if not ids.has("waste:can"):
			return
		observation["revision"] = state_a.revision
		var can_record := state_a.items[&"waste:can"] as ItemRecord
		observation["saw_finalized_item"] = can_record.location == ItemRecord.Location.BAG
		var deferred_result := session.item_store.try_collect(&"local", &"waste:bottle")
		var bottle_record := state_a.items[&"waste:bottle"] as ItemRecord
		observation["kept_followup_deferred"] = deferred_result.reason == ActionResult.Reason.DEFERRED and bottle_record.location == ItemRecord.Location.WORLD
	)

	var first_collect := session.item_store.try_collect(&"local", &"waste:can")
	check(first_collect.ok, "first collection succeeds")
	check(int(observation["revision"]) == 1 and bool(observation["saw_finalized_item"]), "item signal observes finalized revision")
	check(bool(observation["kept_followup_deferred"]), "signal-triggered follow-up cannot run during publication")
	check(state_a.revision == 2, "deferred follow-up commits after publication")
	var player_a := state_a.players[&"local"] as Dictionary
	var trash_bag := player_a[&"trash_bag"] as Array[StringName]
	check(trash_bag == [&"waste:can", &"waste:bottle"], "bag order is stable")

	var before_rejection := JSON.stringify(state_a.to_snapshot())
	var duplicate_collect := session.item_store.try_collect(&"local", &"waste:can")
	check(not duplicate_collect.ok and duplicate_collect.reason == ActionResult.Reason.WRONG_STATE, "collecting the same ID twice is rejected")
	check(JSON.stringify(state_a.to_snapshot()) == before_rejection, "rejected duplicate collection does not mutate state")

	var attached_collect := session.item_store.try_collect(&"local", &"waste:ring")
	check(not attached_collect.ok and attached_collect.reason == ActionResult.Reason.WRONG_STATE, "attached item cannot bypass rescue state")
	check(JSON.stringify(state_a.to_snapshot()) == before_rejection, "invalid source rejection is atomic")

	var full_collect := session.item_store.try_collect(&"local", &"waste:paper")
	check(not full_collect.ok and full_collect.reason == ActionResult.Reason.CAPACITY, "full bag rejects destination transfer")
	check(JSON.stringify(state_a.to_snapshot()) == before_rejection, "capacity rejection is atomic")

	check(session.item_store.try_hold(&"local", &"prop:bucket").ok, "first small prop uses one hand")
	check(session.item_store.try_hold(&"local", &"prop:ball").ok, "second small prop uses second hand")
	var before_large_hold := JSON.stringify(state_a.to_snapshot())
	var large_hold := session.item_store.try_hold(&"local", &"prop:chair")
	check(not large_hold.ok and large_hold.reason == ActionResult.Reason.CAPACITY, "large prop is rejected when both hands are occupied")
	check(JSON.stringify(state_a.to_snapshot()) == before_large_hold, "hand-capacity rejection is atomic")

	check((state_b.items[&"waste:can"] as ItemRecord).location == ItemRecord.Location.WORLD and state_b.revision == 0, "two run states sharing definitions remain independent")
	check(state_a.validate_invariants(definitions).is_empty(), "ownership fixture preserves all invariants")

	var snapshot_json := JSON.stringify(state_a.to_snapshot())
	var restored_value: Variant = JSON.parse_string(snapshot_json)
	var restored := RunState.from_snapshot(restored_value as Dictionary)
	var restored_player := restored.players[&"local"] as Dictionary
	check((restored_player[&"trash_bag"] as Array[StringName]) == [&"waste:can", &"waste:bottle"], "snapshot round-trip retains ordered stable IDs")
	check(restored.validate_invariants(definitions).is_empty(), "snapshot round-trip preserves invariants")

	var required_before := state_a.required_total
	var presentation_node := Node3D.new()
	root.add_child(presentation_node)
	presentation_node.free()
	check(state_a.required_total == required_before, "deleting a scene node cannot change domain totals")
	session.free()


func _fixture_definitions() -> Dictionary:
	var definitions := {}
	definitions[&"can"] = _item_definition(&"can", ItemDefinition.Kind.WASTE, ItemDefinition.WasteCategory.PMD, 1)
	definitions[&"bottle"] = _item_definition(&"bottle", ItemDefinition.Kind.WASTE, ItemDefinition.WasteCategory.GLASS, 1)
	definitions[&"paper"] = _item_definition(&"paper", ItemDefinition.Kind.WASTE, ItemDefinition.WasteCategory.GENERAL, 1)
	definitions[&"bucket"] = _item_definition(&"bucket", ItemDefinition.Kind.PROP, ItemDefinition.WasteCategory.NONE, 1)
	definitions[&"ball"] = _item_definition(&"ball", ItemDefinition.Kind.PROP, ItemDefinition.WasteCategory.NONE, 1)
	definitions[&"chair"] = _item_definition(&"chair", ItemDefinition.Kind.PROP, ItemDefinition.WasteCategory.NONE, 2)
	definitions[&"keys"] = _item_definition(&"keys", ItemDefinition.Kind.VALUABLE, ItemDefinition.WasteCategory.NONE, 1)
	definitions[&"ring"] = _item_definition(&"ring", ItemDefinition.Kind.WASTE, ItemDefinition.WasteCategory.GENERAL, 1)
	return definitions


func _item_definition(
	definition_id: StringName,
	kind: ItemDefinition.Kind,
	category: ItemDefinition.WasteCategory,
	hand_cost: int
) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.definition_id = definition_id
	definition.display_name = str(definition_id).capitalize()
	definition.kind = kind
	definition.waste_category = category
	definition.sorting_family = definition_id
	definition.hand_cost = hand_cost
	return definition


func _fixture_state() -> RunState:
	var state := RunState.new()
	state.run_id = "fixture"
	state.seed_text = "state-check"
	var player := state.add_player()
	player["bag_capacity"] = 2
	state.add_item(_item_record(&"waste:can", &"can"))
	state.add_item(_item_record(&"waste:bottle", &"bottle"))
	state.add_item(_item_record(&"waste:paper", &"paper"))
	state.add_item(_item_record(&"prop:bucket", &"bucket"))
	state.add_item(_item_record(&"prop:ball", &"ball"))
	var chair := _item_record(&"prop:chair", &"chair")
	chair.dirty_patches_remaining = [&"seat", &"back"]
	state.add_item(chair)
	state.add_item(_item_record(&"valuable:keys", &"keys", false))
	var attached := _item_record(&"waste:ring", &"ring")
	attached.location = ItemRecord.Location.ATTACHED
	attached.attachment_id = &"rescue:turtle-01/ring"
	state.add_item(attached)
	return state


func _item_record(item_id: StringName, definition_id: StringName, required: bool = true) -> ItemRecord:
	var record := ItemRecord.new()
	record.item_id = item_id
	record.definition_id = definition_id
	record.home_section_id = &"arrival:start"
	record.home_zone_id = &"arrival"
	record.required = required
	return record


func check_input_bindings() -> void:
	var test_path := "user://p03-input-check.cfg"
	var first := SettingsStore.new()
	first.settings_path = test_path
	root.add_child(first)
	first.reset_all()

	for action in SettingsStore.REQUIRED_ACTIONS:
		check(InputMap.has_action(action), "input action exists: %s" % action)
		check(not InputMap.action_get_events(action).is_empty(), "input action has a default: %s" % action)
	for action in [&"move_left", &"move_right", &"move_forward", &"move_back", &"primary", &"throw", &"interact", &"jump", &"crouch", &"sprint", &"switch_tool", &"select_held_prop", &"booklet", &"scanner_pulse", &"pause", &"ui_accept", &"ui_cancel"]:
		check(_has_controller_binding(action), "controller default exists: %s" % action)
		check(_has_keyboard_or_mouse_binding(action), "keyboard/mouse default exists: %s" % action)

	var quiet_axis := InputEventJoypadMotion.new()
	quiet_axis.axis = JOY_AXIS_RIGHT_X
	quiet_axis.axis_value = 0.1
	first.note_input(quiet_axis)
	check(first.prompt_device == SettingsStore.PromptDevice.KEYBOARD_MOUSE, "stick noise does not change prompt device")
	quiet_axis.axis_value = 0.8
	first.note_input(quiet_axis)
	check(first.prompt_device == SettingsStore.PromptDevice.CONTROLLER, "meaningful stick input changes prompt device")

	var primary_key := _pressed_key(KEY_P)
	var move_key := _pressed_key(KEY_UP)
	var accept_key := _pressed_key(KEY_K)
	first.rebind(&"primary", primary_key)
	first.rebind(&"move_forward", move_key)
	first.rebind(&"ui_accept", accept_key)
	first.set_value(&"fov", 103.0)
	check(first.save_settings() == OK, "input overrides save")
	first.free()

	var loaded := SettingsStore.new()
	loaded.settings_path = test_path
	root.add_child(loaded)
	check(_has_physical_key(&"primary", KEY_P), "primary override round-trips")
	check(_has_physical_key(&"move_forward", KEY_UP), "movement override round-trips")
	check(_has_physical_key(&"ui_accept", KEY_K), "UI accept override round-trips")
	check(_has_controller_binding(&"primary") and _has_controller_binding(&"move_forward") and _has_controller_binding(&"ui_accept"), "remapping one device preserves the other")
	check(is_equal_approx(float(loaded.get_value(&"fov")), 103.0), "settings values round-trip")
	check(not FileAccess.get_file_as_string(test_path).contains("hardware"), "settings do not serialize hardware paths")
	loaded.reset_all()
	check(_has_mouse_button(&"primary", MOUSE_BUTTON_LEFT), "reset restores primary default")
	check(_has_physical_key(&"move_forward", KEY_W), "reset restores movement default")
	check(_has_physical_key(&"ui_accept", KEY_ENTER), "reset preserves accessible confirm")
	check(_has_physical_key(&"ui_cancel", KEY_ESCAPE), "reset preserves accessible cancel")
	loaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	await process_frame


func _pressed_key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _has_physical_key(action: StringName, code: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == code:
			return true
	return false


func _has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false


func _has_controller_binding(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if SettingsStore.is_controller_event(event):
			return true
	return false


func _has_keyboard_or_mouse_binding(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return true
	return false


func check_manifest_generation() -> void:
	var generator := ManifestGenerator.new()
	var hashes := {}
	var fixture: Dictionary
	for seed_text in ["manifest-fixture-v1", "alpha", "Bravo", "charlie-3", "delta,4", "echo/five", "foxtrot:six", "golf seven", "hotel_8", "Côte, \"Azure\" 🌊"]:
		var result := generator.generate(seed_text)
		check(bool(result.get("ok", false)), "manifest generates for seed %s" % seed_text)
		if not result.get("ok", false):
			continue
		check((result.rows as Array).size() == 5740, "manifest preserves required and optional totals for seed %s" % seed_text)
		hashes[result.manifest_hash] = true
		if seed_text == "manifest-fixture-v1":
			fixture = result
	check(hashes.size() == 10, "ten fixed seeds produce ten distinct valid layouts")
	if fixture.is_empty():
		return
	check(str(fixture.content_hash) == "e4f857a080bd43eb206bff6bb4001ffc20587e0e1e28c8913725716431448c0b", "fixture content hash is pinned")
	check(str(fixture.manifest_hash) == "9cd0b9d2dea7f8b73f40de41b8fe6fbdad32ff3d918c05dbde20b17ba550f221", "fixture manifest hash is pinned")
	var catalog_present := {}
	for row_value in fixture.rows:
		catalog_present[StringName(str((row_value as Dictionary).definition_id))] = true
	var catalog_missing := PackedStringArray()
	for definition_id in [&"waste_straw", &"waste_plastic_wrap", &"waste_drink_carton", &"waste_fries", &"waste_hamburger", &"waste_sealed_oil_container"]:
		if not catalog_present.has(definition_id):
			catalog_missing.append(str(definition_id))
	check(catalog_missing.is_empty(), "new litter families appear in the playable manifest: %s" % ", ".join(catalog_missing))
	var normalized := generator.normalize_seed("  Côte, \"Azure\" 🌊  ")
	check(normalized.ok and normalized.seed == "Côte, \"Azure\" 🌊", "seed normalization trims only surrounding whitespace")
	check(not generator.normalize_seed("bad\nseed").ok, "control characters are rejected")
	check(not generator.normalize_seed("é".repeat(33)).ok, "seed limit counts UTF-8 bytes")
	var stream := generator.derive_stream(str(normalized.seed), "reef_west:coral", "buried", str(fixture.content_hash))
	check(stream.canonical == "[\"manifest-1\",\"e4f857a080bd43eb206bff6bb4001ffc20587e0e1e28c8913725716431448c0b\",\"Côte, \\\"Azure\\\" 🌊\",\"reef_west:coral\",\"buried\"]", "Unicode stream canonical bytes are pinned")
	check(stream.hash == "828370bbaf8901f847c74cab3290fd5d9bd6bdd0fb8ffe37661664ae5c1e0763" and int(stream.rng_seed) == 587780274892869663, "Unicode stream SHA-256 and 60-bit seed are pinned")

	var state := generator.create_run_state(fixture, "manifest-check")
	check(state.required_total == 5700 and state.items.size() == 5740, "manifest creates one record per stable ID")
	check(state.validate_invariants(fixture.definitions).is_empty(), "generated RunState preserves domain invariants")

	var anchors := load(ManifestGenerator.ANCHORS_PATH) as Resource
	var missing_anchors := anchors.duplicate(true)
	var packs := (missing_anchors.get_meta(&"packs") as Dictionary).duplicate(true)
	packs.erase(&"reef_east:coral")
	missing_anchors.set_meta(&"packs", packs)
	var missing_result := generator.generate("missing-anchor", null, null, missing_anchors)
	check(not missing_result.ok and str(missing_result.error).contains("Missing anchor pack"), "missing anchor fails with a section diagnostic")

	var beach := (load(ManifestGenerator.BEACH_PATH) as BeachDefinition).duplicate(true) as BeachDefinition
	var inventories := beach.slot_inventories.duplicate(true)
	var chair_slots := (inventories[&"beach_chair"] as Dictionary).duplicate(true)
	chair_slots[&"capacity"] = 69
	inventories[&"beach_chair"] = chair_slots
	beach.slot_inventories = inventories
	var capacity_result := generator.generate("impossible-capacity", beach)
	check(not capacity_result.ok and str(capacity_result.error).contains("Destination capacity"), "impossible destination capacity fails visibly")

	var duplicate_rows := (fixture.rows as Array).duplicate(true)
	(duplicate_rows[1] as Dictionary).id = str((duplicate_rows[0] as Dictionary).id)
	var duplicate_generation := fixture.duplicate()
	duplicate_generation.rows = duplicate_rows
	var duplicate_errors := ManifestValidator.validate_manifest(
		duplicate_generation,
		load(ManifestGenerator.BEACH_PATH),
		load(ManifestGenerator.QUOTAS_PATH),
		anchors,
		fixture.definitions
	)
	check(_contains_fragment(duplicate_errors, "unique"), "duplicate manifest IDs are rejected")

	var first_probe := _run_manifest_probe("separate-process")
	var second_probe := _run_manifest_probe("separate-process")
	check(not first_probe.is_empty() and first_probe == second_probe, "separate processes produce the same canonical manifest hash")


func _run_manifest_probe(seed_text: String) -> String:
	var output: Array = []
	var arguments := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/manifest_probe.gd",
		"--", seed_text,
	])
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	check(exit_code == 0, "manifest probe process exits successfully")
	for line in "\n".join(output).split("\n"):
		if line.begins_with("MANIFEST_PROBE "):
			return line.strip_edges()
	return ""


func _contains_fragment(messages: PackedStringArray, fragment: String) -> bool:
	for message in messages:
		if message.contains(fragment):
			return true
	return false
