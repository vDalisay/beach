class_name BeachMain
extends Node

signal run_started(run_root: Node)
signal run_stopped

const BEACH_SCENE := preload("res://scenes/world/beach.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BEACH_DEFINITION := preload("res://data/world/beach_01.tres")

@onready var status_label: Label = %StatusLabel
@onready var seed_input: LineEdit = %SeedInput
@onready var start_button: Button = %StartButton
@onready var continue_button: Button = %ContinueButton
@onready var load_button: Button = %LoadButton
@onready var load_panel: PanelContainer = %LoadPanel
@onready var save_list: ItemList = %SaveList
@onready var open_save_button: Button = %OpenSaveButton
@onready var back_from_load_button: Button = %BackFromLoadButton
@onready var settings_button: Button = %SettingsButton
@onready var settings_store: SettingsStore = %SettingsStore
@onready var settings_menu: SettingsMenu = %SettingsMenu
@onready var error_panel: PanelContainer = %ErrorPanel
@onready var error_label: Label = %ErrorLabel
@onready var target_label: TargetLabel = %TargetLabel
@onready var sorting_view: SortingView = %SortingOverlay
@onready var collection_receipt: CollectionReceipt = %CollectionReceipt
@onready var progression_view: ProgressionView = %ProgressionView
@onready var detector_meter: Control = %DetectorMeter
@onready var oxygen_meter: Control = %OxygenMeter
@onready var faint_fade: ColorRect = %FaintFade
@onready var progress_panel: PanelContainer = %ProgressPanel
@onready var progress_label: Label = %ProgressLabel
@onready var context_panel: PanelContainer = %ContextPanel
@onready var context_label: Label = %ContextLabel
@onready var guidance_panel: PanelContainer = %GuidancePanel
@onready var guidance_label: Label = %GuidanceLabel
@onready var results_view: ResultsView = %ResultsView
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var scanner_overlay: Control = %ScannerOverlay
@onready var backdrop: ColorRect = $UI/Backdrop
@onready var menu_container: CenterContainer = $UI/Center

var run_root: Node
var save_service: SaveService
var _listed_saves: Array[Dictionary] = []
var _settings_from_pause := false
var _notice_serial := 0
var _notice_queue: Array[Dictionary] = []
var _current_notice: Dictionary = {}
var _pending_guidance: Dictionary = {}
var _notice_active := false
var _pending_group_count := 0
var _pending_group_reward := 0
var _pending_group_family := ""


func _ready() -> void:
	save_service = SaveService.new()
	save_service.name = "SaveService"
	add_child(save_service)
	save_service.save_failed.connect(func(slot_id: StringName, message: String) -> void:
		if slot_id == &"autosave":
			show_error("Autosave failed: %s. Pause and choose Save to retry." % message)
	)
	start_button.pressed.connect(start_run)
	continue_button.pressed.connect(_continue_run)
	load_button.pressed.connect(_show_load_panel)
	open_save_button.pressed.connect(_load_selected)
	back_from_load_button.pressed.connect(_hide_load_panel)
	settings_button.pressed.connect(_open_settings_from_title)
	settings_menu.closed.connect(_on_settings_closed)
	pause_menu.resume_requested.connect(_resume_run)
	pause_menu.settings_requested.connect(_open_settings_from_pause)
	pause_menu.save_requested.connect(_manual_save)
	pause_menu.save_quit_requested.connect(_save_and_quit)
	pause_menu.quit_without_save_requested.connect(_quit_without_saving)
	settings_store.controller_disconnected.connect(_on_controller_disconnected)
	settings_store.controller_reconnected.connect(_on_controller_reconnected)
	show_menu()


func start_run() -> Node:
	clear_error()
	var generator := ManifestGenerator.new()
	var generation := generator.generate(seed_input.text)
	if not generation.ok:
		show_error(str(generation.error))
		return null
	seed_input.text = str(generation.seed)
	var initial_state := generator.create_run_state(generation, "run_%d_%08x" % [int(Time.get_unix_time_from_system()), randi()])
	return _open_run(initial_state, generation.definitions, str(generation.manifest_hash))


func _open_run(initial_state: RunState, definitions: Dictionary, manifest_hash: String) -> Node:
	clear_run()
	clear_error()
	var session := RunSession.new()
	session.initialize(initial_state, definitions)
	run_root = session
	run_root.name = "RunRoot"
	add_child(run_root)
	var beach := BEACH_SCENE.instantiate() as Node3D
	beach.name = "Beach"
	run_root.add_child(beach)
	var restoration := RestorationSection.new()
	restoration.name = "RestorationSection"
	run_root.add_child(restoration)
	restoration.configure(session, beach, settings_store)
	var player := PLAYER_SCENE.instantiate() as BeachPlayer
	player.name = "Player"
	run_root.add_child(player)
	var saved_pose := (initial_state.players[&"local"] as Dictionary).transform as Transform3D
	player.global_transform = (beach.get_node("%PlayerSpawn") as Marker3D).global_transform if saved_pose == Transform3D.IDENTITY else saved_pose
	player.velocity = (initial_state.players[&"local"] as Dictionary).velocity as Vector3
	player.configure(settings_store, session)
	player.pause_changed.connect(_on_player_pause_changed.bind(player))
	target_label.configure(player.interactor, player.camera)
	player.carry.feedback_requested.connect(_show_gameplay_feedback)
	var item_views := ItemViewManager.new()
	item_views.name = "Items"
	run_root.add_child(item_views)
	session.item_view_manager = item_views
	item_views.configure(session, definitions, BEACH_DEFINITION.recovery_anchors, player)
	item_views.build_views()
	var placements := PlacementService.new()
	placements.name = "PlacementService"
	run_root.add_child(placements)
	placements.configure(session, beach, player)
	placements.feedback_requested.connect(_show_gameplay_feedback)
	var cloth := ClothTool.new()
	cloth.name = "ClothTool"
	run_root.add_child(cloth)
	cloth.configure(session, player)
	cloth.feedback_requested.connect(_show_gameplay_feedback)
	for station_node in get_tree().get_nodes_in_group("sorting_stations"):
		var station := station_node as SortingStation
		station.configure(session, player, sorting_view)
		station.feedback_requested.connect(_show_gameplay_feedback)
		session.sorting_stations[station.station_id] = station
	for container_node in get_tree().get_nodes_in_group("waste_containers"):
		var container := container_node as WasteContainer
		container.configure(session, player)
		container.feedback_requested.connect(_show_gameplay_feedback)
		session.waste_containers[container.container_id] = container
	var collection := CollectionService.new()
	collection.name = "CollectionService"
	run_root.add_child(collection)
	collection.configure(session)
	collection.receipt_created.connect(collection_receipt.show_receipt)
	collection.receipt_created.connect(func(_receipt: Dictionary) -> void:
		_show_guidance(session, &"collection", "Truck collection credits trash and pays for correctly sorted items.")
	)
	session.collection_service = collection
	for call_node in get_tree().get_nodes_in_group("collection_call_points"):
		var call_point := call_node as CollectionCallPoint
		call_point.configure(collection, player)
		call_point.feedback_requested.connect(_show_gameplay_feedback)
	var progression := ProgressionService.new()
	progression.name = "ProgressionService"
	run_root.add_child(progression)
	progression.configure(session, player)
	var sand := SandCleaner.new()
	sand.name = "SandCleaner"
	run_root.add_child(sand)
	sand.configure(session, player)
	sand.feedback_requested.connect(_show_gameplay_feedback)
	var vacuum := VacuumTool.new()
	vacuum.name = "VacuumTool"
	run_root.add_child(vacuum)
	vacuum.configure(session, player)
	vacuum.feedback_requested.connect(_show_gameplay_feedback)
	var finds := BuriedFind.new()
	finds.name = "BuriedFinds"
	run_root.add_child(finds)
	finds.configure(session, player)
	var detector := MetalDetector.new()
	detector.name = "MetalDetector"
	run_root.add_child(detector)
	detector.configure(session, player, finds, detector_meter)
	detector.feedback_requested.connect(_show_gameplay_feedback)
	session.metal_detector = detector
	var swim := SwimService.new()
	swim.name = "SwimService"
	run_root.add_child(swim)
	swim.configure(session, player, beach.get_node("Water/SwimVolume") as WaterVolume, oxygen_meter, faint_fade, BEACH_DEFINITION.recovery_anchors)
	session.swim_service = swim
	swim.faint_completed.connect(func(receipt: Dictionary) -> void:
		_show_gameplay_feedback("Recovered at %s; dropped items marked underwater" % str(receipt.anchor_id))
	)
	var rescue := RescueKnife.new()
	rescue.name = "RescueKnife"
	run_root.add_child(rescue)
	rescue.configure(session, player)
	rescue.feedback_requested.connect(_show_gameplay_feedback)
	var scanner := ScannerService.new()
	scanner.name = "Scanner"
	run_root.add_child(scanner)
	scanner.configure(session, player, scanner_overlay)
	scanner.feedback_requested.connect(_show_gameplay_feedback)
	scanner.pulse_succeeded.connect(clear_error)
	session.progress_changed.connect(func(_waste: int, _props: int, _required: int) -> void: _update_progress(session))
	session.group_completed.connect(func(payload: Dictionary) -> void:
		if _pending_group_count == 0:
			_pending_group_family = str(payload.get("family_id", "props")).replace("_", " ").capitalize()
			call_deferred("_flush_group_notice")
		_pending_group_count += 1
		_pending_group_reward += int(payload.get("reward", 0))
	)
	session.section_restored.connect(func(section_id: StringName) -> void:
		_queue_notice("%s restored" % str(section_id).replace("_", " ").replace(":", " · ").capitalize(), 2.8, &"", null, 2)
	)
	session.zone_restored.connect(func(zone_id: StringName) -> void:
		_queue_notice("%s nature returns" % str(zone_id).replace("_", " ").capitalize(), 3.0, &"", null, 2)
	)
	session.wallet_changed.connect(func(_player_id: StringName) -> void:
		_update_progress(session)
		_update_context(session)
		if &"cloth" in (session.state.players[&"local"] as Dictionary).owned_tools:
			_show_guidance(session, &"cloth", "Equip the cloth at the shop rack, then clean marked props before placing them.")
	)
	session.hands_changed.connect(func(_player_id: StringName) -> void:
		_update_context(session)
		var held := (session.state.players[&"local"] as Dictionary).held_objects as Array
		for object_ref in held:
			if str(object_ref.get("kind", "")) == "bag":
				_show_guidance(session, &"carry_sealed", "Carry sealed bags to the matching collection container.")
	)
	session.items_changed.connect(func(ids: PackedStringArray) -> void:
		_update_context(session)
		for item_id in ids:
			var item := session.state.items.get(StringName(item_id)) as ItemRecord
			if item == null:
				continue
			if not item.rescuer_id.is_empty():
				_show_guidance(session, &"rescue", "Cutting frees the animal; collect the removed litter too.")
			if item.location == ItemRecord.Location.BAG:
				_show_guidance(session, &"pickup", "Bagged trash must be sorted, sealed and collected by the truck.")
			elif item.location == ItemRecord.Location.BIN:
				_show_guidance(session, &"sorting", "Check the material before sealing; items can still move between bins.")
			elif item.location == ItemRecord.Location.SEALED:
				_show_guidance(session, &"sealing", "This bag is sealed. Carry it to the matching collection container.")
	)
	session.run_completed.connect(func(receipt: Dictionary) -> void:
		_clear_notices()
		collection_receipt.clear_receipt()
		results_view.show_receipt(receipt, player, session)
	)
	_update_progress(session)
	_update_context(session)
	progress_panel.show()
	context_panel.show()
	progression_view.configure(progression, player)
	if not progression_view.opened.is_connected(collection_receipt.clear_receipt):
		progression_view.opened.connect(collection_receipt.clear_receipt)
	var shop := beach.get_node("ServicePoints/EquipmentShop/ShopStations") as EquipmentShop
	shop.configure(progression, player, progression_view)
	player.booklet_requested.connect(progression_view.open_booklet)
	save_service.configure(session, player, BEACH_DEFINITION.beach_id)
	backdrop.hide()
	menu_container.hide()
	load_panel.hide()
	status_label.text = "Beach run active: %s" % manifest_hash
	start_button.text = "Restart beach run"
	if not initial_state.completion_receipt.is_empty() and session.progress_service.completed_waste + session.progress_service.completed_props == initial_state.required_total:
		results_view.show_receipt(initial_state.completion_receipt, player, session)
	run_started.emit(run_root)
	return run_root


func clear_run() -> void:
	get_tree().paused = false
	save_service.session = null
	save_service.player = null
	save_service._autosave_pending = false
	target_label.clear_target()
	sorting_view.close()
	collection_receipt.clear_receipt()
	progression_view.close()
	scanner_overlay.hide()
	detector_meter.hide()
	oxygen_meter.hide()
	faint_fade.hide()
	faint_fade.color.a = 0.0
	results_view.reset_view()
	pause_menu.close_menu()
	_clear_notices()
	progress_panel.hide()
	context_panel.hide()
	if not is_instance_valid(run_root):
		return

	remove_child(run_root)
	run_root.free()
	run_root = null
	run_stopped.emit()


func show_menu() -> void:
	clear_error()
	_refresh_saves()
	backdrop.show()
	menu_container.show()
	load_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status_label.text = "Choose a new beach or continue a saved run."
	start_button.text = "New run"
	start_button.grab_focus()


func load_run(run_id: String, slot_id: StringName) -> Dictionary:
	var candidate := save_service.load_slot(BEACH_DEFINITION.beach_id, run_id, slot_id)
	if not bool(candidate.ok):
		show_error(str(candidate.message))
		return candidate
	var state := candidate.state as RunState
	seed_input.text = state.seed_text
	_open_run(state, candidate.definitions as Dictionary, state.initial_manifest_hash)
	if not str(candidate.notice).is_empty():
		_show_gameplay_feedback(str(candidate.notice))
	return candidate


func _refresh_saves() -> void:
	_listed_saves = save_service.list_slots(BEACH_DEFINITION.beach_id)
	continue_button.disabled = _listed_saves.is_empty() or bool(_listed_saves[0].get("damaged", false))
	load_button.disabled = _listed_saves.is_empty()


func _continue_run() -> void:
	for entry in _listed_saves:
		if not bool(entry.get("damaged", false)):
			if bool(load_run(str(entry.run_id), StringName(str(entry.slot_id))).ok):
				return
	show_error("No usable save is available. Open Load to inspect the saved slots.")


func _show_load_panel() -> void:
	_refresh_saves()
	save_list.clear()
	for entry in _listed_saves:
		var description := "%s  ·  %s  ·  %s%s" % [str(entry.get("seed", "Unknown seed")), str(entry.slot_id).capitalize(), str(entry.run_id), "  ·  DAMAGED" if bool(entry.get("damaged", false)) else ""]
		save_list.add_item(description)
	menu_container.hide()
	load_panel.show()
	if not _listed_saves.is_empty():
		save_list.select(0)
		open_save_button.grab_focus()


func _hide_load_panel() -> void:
	load_panel.hide()
	menu_container.show()
	load_button.grab_focus()


func _load_selected() -> void:
	var selected := save_list.get_selected_items()
	if selected.is_empty():
		return
	var entry := _listed_saves[selected[0]] as Dictionary
	load_run(str(entry.run_id), StringName(str(entry.slot_id)))


func _manual_save() -> void:
	var result := save_service.save_slot(&"manual")
	if bool(result.ok):
		pause_menu.note.text = "Saved to manual slot (generation %d)." % int(result.sequence)
		pause_menu.quit_without_save_button.hide()
	else:
		pause_menu.show_save_failure(str(result.message))


func _save_and_quit() -> void:
	var result := save_service.save_slot(&"manual")
	if bool(result.ok):
		clear_run()
		show_menu()
	else:
		pause_menu.show_save_failure(str(result.message))


func _quit_without_saving() -> void:
	clear_run()
	show_menu()


func show_error(message: String) -> void:
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.64))
	error_panel.show()


func clear_error() -> void:
	error_panel.hide()


func _on_controller_disconnected(_device_id: int) -> void:
	if is_instance_valid(run_root):
		(run_root.get_node("Player") as BeachPlayer).set_paused(true)
	show_error("Controller disconnected. The game is paused; reconnect it or use keyboard and mouse.")


func _on_controller_reconnected(_device_id: int) -> void:
	if error_label.text.begins_with("Controller disconnected"):
		clear_error()


func _show_gameplay_feedback(message: String) -> void:
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color(0.82, 0.95, 0.91))
	error_panel.show()
	var shown_message := message
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(error_label) and error_label.text == shown_message:
			clear_error()
	)


func _update_progress(session: RunSession) -> void:
	var service := session.progress_service
	var waste_total := 0
	var props_total := 0
	for section_value in session.state.section_states.values():
		var section := section_value as Dictionary
		waste_total += int(section.required_waste)
		props_total += int(section.required_props)
	var money := int((session.state.players[&"local"] as Dictionary).money)
	var complete := service.completed_waste + service.completed_props
	progress_label.text = "Completed %s / %s\nRemaining %s\nProps %s / %s\nTrash collected %s / %s\n$%s" % [_comma(complete), _comma(session.state.required_total), _comma(session.state.required_total - complete), _comma(service.completed_props), _comma(props_total), _comma(service.completed_waste), _comma(waste_total), _comma(money)]


func _update_context(session: RunSession) -> void:
	var record := session.state.players[&"local"] as Dictionary
	var bag_count := (record.trash_bag as Array).size() + (record.valuable_bag as Array).size()
	var tool_id := session.progression.active_tool_id(&"local")
	var tool_name := "Poking stick" if tool_id == &"stick" else session.progression.offer_name(tool_id)
	var held := record.held_objects as Array
	var holding := "Hands free"
	if not held.is_empty():
		var index := clampi(int(record.selected_held_index), 0, held.size() - 1)
		var object_ref := held[index] as Dictionary
		if str(object_ref.get("kind", "")) == "bag":
			holding = "Holding sealed bag %d / %d" % [index + 1, held.size()]
		else:
			var item := session.state.items.get(StringName(str(object_ref.get("id", "")))) as ItemRecord
			if item != null:
				holding = "Holding %s %d / %d" % [(session.definitions[item.definition_id] as ItemDefinition).display_name, index + 1, held.size()]
	context_label.text = "Bag %d / %d\nTool %s\n%s" % [bag_count, int(record.bag_capacity), tool_name, holding]
	if bag_count == int(record.bag_capacity):
		_show_guidance(session, &"full_bag", "Bag full. Unload it onto a sorting table, then collect more.")


func _show_guidance(session: RunSession, key: StringName, message: String) -> void:
	if key in session.state.guidance_seen or _pending_guidance.has(key):
		return
	_pending_guidance[key] = true
	_queue_notice(message, 4.0, key, session)


func _queue_notice(message: String, duration: float, guidance_key: StringName = &"", session: RunSession = null, priority: int = 0) -> void:
	_notice_queue.append({"message": message, "duration": duration, "guidance_key": guidance_key, "session": session, "priority": priority})
	if _notice_active and priority > int(_current_notice.get("priority", 0)):
		_notice_queue.append(_current_notice)
		_notice_serial += 1
		_notice_active = false
	if not _notice_active:
		_show_next_notice()


func _flush_group_notice() -> void:
	if _pending_group_count == 0 or not is_instance_valid(run_root):
		return
	var label := "%s set complete" % _pending_group_family if _pending_group_count == 1 else "%d prop sets complete" % _pending_group_count
	var reward := " · +$%d" % _pending_group_reward if _pending_group_reward > 0 else " · restored again"
	_pending_group_count = 0
	_pending_group_reward = 0
	_pending_group_family = ""
	_queue_notice(label + reward, 2.5, &"", null, 1)


func _show_next_notice() -> void:
	if _notice_queue.is_empty():
		_notice_active = false
		_current_notice = {}
		guidance_panel.hide()
		return
	_notice_active = true
	var selected := 0
	for index in range(1, _notice_queue.size()):
		if int(_notice_queue[index].get("priority", 0)) > int(_notice_queue[selected].get("priority", 0)):
			selected = index
	var notice := _notice_queue[selected] as Dictionary
	_notice_queue.remove_at(selected)
	_current_notice = notice
	var guidance_key := StringName(str(notice.guidance_key))
	if not guidance_key.is_empty():
		_pending_guidance.erase(guidance_key)
		var session := notice.session as RunSession
		if is_instance_valid(session) and guidance_key not in session.state.guidance_seen:
			session.state.guidance_seen.append(guidance_key)
	guidance_label.text = str(notice.message)
	guidance_panel.show()
	_notice_serial += 1
	var serial := _notice_serial
	get_tree().create_timer(float(notice.duration), false).timeout.connect(func() -> void:
		if is_instance_valid(self) and serial == _notice_serial:
			_show_next_notice()
	)


func _clear_notices() -> void:
	_notice_serial += 1
	_notice_queue.clear()
	_current_notice = {}
	_pending_guidance.clear()
	_notice_active = false
	_pending_group_count = 0
	_pending_group_reward = 0
	_pending_group_family = ""
	guidance_panel.hide()


func _process(_delta: float) -> void:
	if not is_instance_valid(run_root):
		return
	var session := run_root as RunSession
	if bool((session.state.players[&"local"] as Dictionary).immersed):
		_show_guidance(session, &"oxygen", "Air drains underwater. Surface before it reaches zero, or carried objects will drop.")


func _on_player_pause_changed(paused: bool, player: BeachPlayer) -> void:
	call_deferred("_sync_pause_menu", paused, player)


func _sync_pause_menu(paused: bool, player: BeachPlayer) -> void:
	if not is_instance_valid(run_root) or player != run_root.get_node_or_null("Player"):
		return
	if paused and not progression_view.visible and not sorting_view.visible and not results_view.visible and not settings_menu.visible:
		pause_menu.open_menu()
	else:
		pause_menu.close_menu()


func _resume_run() -> void:
	if is_instance_valid(run_root):
		pause_menu.close_menu()
		(run_root.get_node("Player") as BeachPlayer).set_paused(false)


func _open_settings_from_title() -> void:
	_settings_from_pause = false
	settings_menu.open_menu(settings_store)


func _open_settings_from_pause() -> void:
	_settings_from_pause = true
	pause_menu.close_menu()
	(run_root.get_node("Player") as BeachPlayer).set_input_enabled(false)
	settings_menu.open_menu(settings_store)


func _on_settings_closed() -> void:
	if _settings_from_pause and is_instance_valid(run_root):
		(run_root.get_node("Player") as BeachPlayer).set_input_enabled(true)
		pause_menu.open_menu()
		pause_menu.settings_button.grab_focus()
	else:
		settings_button.grab_focus()


func _comma(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
