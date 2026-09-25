class_name BeachMain
extends Node

signal run_started(run_root: Node)
signal run_stopped

const BEACH_SCENE := preload("res://scenes/world/beach.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BEACH_DEFINITION := preload("res://data/world/beach_01.tres")
const FEEL := preload("res://data/feel/feel_tuning.tres")

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
@onready var reticle: Reticle = $UI/Reticle
@onready var sorting_view: SortingView = %SortingOverlay
@onready var collection_receipt: CollectionReceipt = %CollectionReceipt
@onready var progression_view: ProgressionView = %ProgressionView
@onready var detector_meter: Control = %DetectorMeter
@onready var oxygen_meter: Control = %OxygenMeter
@onready var faint_fade: ColorRect = %FaintFade
@onready var progress_panel: PanelContainer = %ProgressPanel
@onready var progress_label: Label = %ProgressLabel
@onready var completion_bar: ProgressBar = %CompletionBar
@onready var money_label: Label = %MoneyLabel
@onready var bag_bar: ProgressBar = %BagBar
@onready var notice_icon: FeelIcon = %NoticeIcon
@onready var coin_flyer: CoinFlyer = $UI/CoinFlyer
@onready var restoration_pointer: RestorationPointer = $UI/RestorationPointer
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
# HUD presentation: displayed values roll toward the real ones; nothing here is saved.
var _shown := {}
var _shown_session: RunSession
var _progress_tween: Tween
var _money_hold_until := 0
var _money_floaters: Array[Label] = []
var _last_bag_count := -1
var _bag_styles: Array[StyleBoxFlat] = []
var _notice_style_default: StyleBox
var _notice_style_gold: StyleBoxFlat
# Money shown while coins fly: amounts still in the air are held back from the display.
var _last_totals := {}
var _money_pending := 0
var _money_hold_serial := 0
# Restorations committed together are announced at the end of the frame: one banner for a batch.
var _restoration: RestorationSection
var _pending_sections: Array[StringName] = []
var _pending_zones: Array[StringName] = []


func _ready() -> void:
	collection_receipt.settings = settings_store
	collection_receipt.total_ready.connect(_on_receipt_total_ready)
	restoration_pointer.settings = settings_store
	for color in [FEEL.bag_color_normal, FEEL.bag_color_warn, FEEL.bag_color_full]:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(3)
		_bag_styles.append(style)
	_notice_style_default = guidance_panel.get_theme_stylebox(&"panel")
	var gold := (_notice_style_default.duplicate() as StyleBoxFlat) if _notice_style_default is StyleBoxFlat else StyleBoxFlat.new()
	gold.border_color = FEEL.money_color
	gold.set_border_width_all(2)
	_notice_style_gold = gold
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
	SaveService.remember_manifest(generation)
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
	# Graphics budgets are set before any item view or restoration visual reads them.
	var render_quality := RenderQuality.new()
	render_quality.name = "RenderQuality"
	run_root.add_child(render_quality)
	render_quality.configure(settings_store, beach, session)
	var restoration := RestorationSection.new()
	restoration.name = "RestorationSection"
	run_root.add_child(restoration)
	restoration.configure(session, beach, settings_store)
	_restoration = restoration
	# Repeated static scenery draws as one MultiMesh per cell instead of one call per copy.
	var scenery_roots: Array[Node3D] = []
	for path in ["Foliage", "ActivityAreas", "Skyline", "PierBlockout", "Terrain", "CityBackdrop"]:
		scenery_roots.append(beach.get_node(path) as Node3D)
	for hut in beach.get_node("ServicePoints").find_children("Hut", "Node3D", true, false):
		scenery_roots.append(hut as Node3D)
	for pool in get_tree().get_nodes_in_group(&"placement_pools"):
		if beach.is_ancestor_of(pool):
			scenery_roots.append(pool as Node3D)
	SceneryBatcher.batch(scenery_roots)
	var player := PLAYER_SCENE.instantiate() as BeachPlayer
	player.name = "Player"
	run_root.add_child(player)
	var saved_pose := (initial_state.players[&"local"] as Dictionary).transform as Transform3D
	player.global_transform = (beach.get_node("%PlayerSpawn") as Marker3D).global_transform if saved_pose == Transform3D.IDENTITY else saved_pose
	player.velocity = (initial_state.players[&"local"] as Dictionary).velocity as Vector3
	player.configure(settings_store, session)
	player.pause_changed.connect(_on_player_pause_changed.bind(player))
	target_label.configure(player.interactor, player.camera)
	reticle.configure(player)
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
	collection.receipt_created.connect(_on_receipt_created)
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
	player.cue_played.connect(_on_player_cue)
	session.group_completed.connect(func(payload: Dictionary) -> void:
		player.play_cue(&"set_complete", payload)
		if int(payload.get("reward", 0)) > 0:
			_hold_money(int(payload.reward))
		if _pending_group_count == 0:
			_pending_group_family = str(payload.get("family_id", "props")).replace("_", " ").capitalize()
			call_deferred("_flush_group_notice")
		_pending_group_count += 1
		_pending_group_reward += int(payload.get("reward", 0))
	)
	session.section_restored.connect(func(section_id: StringName) -> void:
		player.play_cue(&"section_restored", {"section_id": str(section_id)})
		_on_area_restored(section_id, false)
	)
	session.zone_restored.connect(func(zone_id: StringName) -> void:
		player.play_cue(&"zone_restored", {"zone_id": str(zone_id)})
		_on_area_restored(zone_id, true)
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
		player.play_cue(&"run_complete")
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
	# Compile every material's shader variants now, not the first time the player sees each one.
	var warmup_scenes: Array[PackedScene] = []
	for definition_value in definitions.values():
		var visual := (definition_value as ItemDefinition).visual_scene()
		if visual != null and not warmup_scenes.has(visual):
			warmup_scenes.append(visual)
	for offer in progression.offers.values():
		if offer is ToolDefinition and (offer as ToolDefinition).scene() != null:
			warmup_scenes.append((offer as ToolDefinition).scene())
	var warmup := ShaderWarmup.new()
	warmup.name = "ShaderWarmup"
	run_root.add_child(warmup)
	warmup.start(run_root, warmup_scenes)
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
	reticle.clear()
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
	if pause_menu.slot_picker.item_count > 0:
		pause_menu.slot_picker.select(0)
	_clear_notices()
	progress_panel.hide()
	context_panel.hide()
	coin_flyer.clear()
	restoration_pointer.clear()
	_restoration = null
	_pending_sections.clear()
	_pending_zones.clear()
	_shown.clear()
	_shown_session = null
	_money_hold_until = 0
	_money_pending = 0
	_last_bag_count = -1
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
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
	if pause_menu.slot_picker.item_count == 0:
		pause_menu.set_slot_summaries(save_service.checkpoint_summaries())
	pause_menu.slot_picker.select(maxi([&"manual", &"manual_2", &"manual_3"].find(slot_id), 0))
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
		var slot_index := [&"manual", &"manual_2", &"manual_3"].find(StringName(str(entry.slot_id)))
		var slot_name := "Checkpoint %d" % (slot_index + 1) if slot_index >= 0 else str(entry.slot_id).capitalize()
		var detail := "DAMAGED" if bool(entry.get("damaged", false)) else "%s — %d/%d" % [Time.get_datetime_string_from_unix_time(int(entry.saved_at), true), int(entry.get("completed", 0)), int(entry.get("required", 0))]
		var description := "%s  ·  %s  ·  %s  ·  %s" % [str(entry.get("seed", "Unknown seed")), slot_name, detail, str(entry.run_id)]
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
	var slot_id := pause_menu.selected_slot_id()
	var result := save_service.save_slot(slot_id)
	if bool(result.ok):
		pause_menu.note.text = "Saved checkpoint %d (generation %d)." % [pause_menu.slot_picker.selected + 1, int(result.sequence)]
		pause_menu.set_slot_summaries(save_service.checkpoint_summaries())
		pause_menu.quit_without_save_button.hide()
	else:
		pause_menu.show_save_failure(str(result.message))


func _save_and_quit() -> void:
	var result := save_service.save_slot(pause_menu.selected_slot_id())
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
	FeelMotion.replace(error_panel, &"toast", null)
	error_panel.hide()
	error_panel.modulate.a = 1.0
	FeelMotion.nudge_y(error_panel, 0.0)


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
	var was_visible := error_panel.visible
	error_panel.show()
	if not was_visible and not FeelMotion.reduced(settings_store):
		# The toast eases in: a short fade and a 6 px rise.
		error_panel.modulate.a = 0.0
		FeelMotion.nudge_y(error_panel, 6.0)
		var t := FeelMotion.replace(error_panel, &"toast", FeelMotion.tween(error_panel).set_parallel(true))
		t.tween_property(error_panel, "modulate:a", 1.0, 0.1)
		t.tween_method(func(pixels: float) -> void: FeelMotion.nudge_y(error_panel, pixels), 6.0, 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var shown_message := message
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(error_label) and error_label.text == shown_message:
			clear_error()
	)


## Progress, completion bar and money roll toward their new values; the first render of a run
## (and every change under reduced motion) is instant.
func _update_progress(session: RunSession) -> void:
	var service := session.progress_service
	var waste_total := 0
	var props_total := 0
	for section_value in session.state.section_states.values():
		var section := section_value as Dictionary
		waste_total += int(section.required_waste)
		props_total += int(section.required_props)
	var target := {
		"complete": float(service.completed_waste + service.completed_props),
		"props": float(service.completed_props),
		"waste": float(service.completed_waste),
		"money": float(int((session.state.players[&"local"] as Dictionary).money)),
	}
	var totals := {"required": session.state.required_total, "props_total": props_total, "waste_total": waste_total}
	var first := _shown_session != session or _shown.is_empty()
	var start := target.duplicate() if first else _shown.duplicate()
	_shown_session = session
	var reduced := FeelMotion.reduced(settings_store)
	var largest := 0.0
	for key in target:
		largest = maxf(largest, absf(float(target[key]) - float(start[key])))
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_react_to_progress(start, target, first, reduced)
	if first or reduced or largest <= 1.0 or _money_held():
		_shown = target.duplicate()
		if _money_held():
			_shown["money"] = start["money"]
		_render_progress(totals)
		return
	_progress_tween = FeelMotion.tween(progress_panel)
	_progress_tween.tween_method(func(t: float) -> void:
		for key in target:
			if key == "money" and _money_held():
				continue
			_shown[key] = lerpf(float(start[key]), float(target[key]), t)
		_render_progress(totals)
	, 0.0, 1.0, FeelMotion.count_seconds(largest)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_progress_tween.tween_callback(func() -> void:
		var keep_money := float(_shown.get("money", target["money"]))
		_shown = target.duplicate()
		if _money_held():
			_shown["money"] = keep_money
		_render_progress(totals)
	)


func _render_progress(totals: Dictionary) -> void:
	if totals.is_empty():
		return
	_last_totals = totals
	var complete := roundi(float(_shown.get("complete", 0.0)))
	var required := int(totals.required)
	progress_label.text = "Completed %s / %s\nRemaining %s\nProps %s / %s\nTrash collected %s / %s" % [_comma(complete), _comma(required), _comma(required - complete), _comma(roundi(float(_shown.get("props", 0.0)))), _comma(int(totals.props_total)), _comma(roundi(float(_shown.get("waste", 0.0)))), _comma(int(totals.waste_total))]
	completion_bar.max_value = maxf(float(required), 1.0)
	completion_bar.value = float(_shown.get("complete", 0.0))
	money_label.text = "$" + _comma(roundi(float(_shown.get("money", 0.0))))


func _react_to_progress(start: Dictionary, target: Dictionary, first: bool, reduced: bool) -> void:
	if first:
		return
	var money_gain := float(target["money"]) - float(start["money"])
	if reduced:
		if money_gain > 0.0:
			_react_money.call_deferred(roundi(money_gain), roundi(float(target["money"])))
		return
	if float(target["complete"]) > float(start["complete"]):
		_shine(completion_bar)
		FeelMotion.bump_control(completion_bar, 1.04, 0.14)
	if money_gain > 0.0:
		_react_money.call_deferred(roundi(money_gain), roundi(float(target["money"])))


## "+$N" rises from the money line and fades (at most three at once). It starts past the width
## the money text will have once the roll ends, so the growing number never runs into it.
func _float_money(amount: int, final_money := -1) -> void:
	# By index: erasing a freed label from a typed array is an engine error.
	for index in range(_money_floaters.size() - 1, -1, -1):
		if not is_instance_valid(_money_floaters[index]):
			_money_floaters.remove_at(index)
	if _money_floaters.size() >= 3 or amount <= 0:
		return
	var floater := Label.new()
	floater.text = "+$%d" % amount
	floater.add_theme_color_override("font_color", FEEL.money_color)
	floater.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.02, 0.9))
	floater.add_theme_constant_override("outline_size", 6)
	floater.add_theme_font_size_override("font_size", 19)
	floater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_label.get_parent().get_parent().get_parent().get_parent().add_child(floater)
	var rect := money_label.get_global_rect()
	var width := rect.size.x
	if final_money >= 0:
		var font := money_label.get_theme_font(&"font")
		width = maxf(width, font.get_string_size("$" + _comma(final_money), HORIZONTAL_ALIGNMENT_LEFT, -1, money_label.get_theme_font_size(&"font_size")).x * money_label.get_global_transform().get_scale().x)
	floater.global_position = Vector2(rect.position.x + width + 6.0, rect.position.y)
	_money_floaters.append(floater)
	var t := FeelMotion.tween(floater).set_parallel(true)
	t.tween_property(floater, "position:y", floater.position.y - 24.0, FEEL.money_float_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(floater, "modulate:a", 0.0, FEEL.money_float_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(floater.queue_free)


## J10 holds the money display while coins fly, so each arrival can step it.
func _money_held() -> bool:
	return Time.get_ticks_msec() < _money_hold_until


func _react_money(gain: int, final_money: int) -> void:
	if _money_held() or not is_instance_valid(run_root):
		return
	if FeelMotion.reduced(settings_store):
		_flash_money()
		return
	FeelMotion.bump_control(money_label, FEEL.bump_scale, FEEL.bump_seconds)
	_float_money(gain, final_money)


func _flash_money() -> void:
	money_label.modulate = Color(1.3, 1.25, 1.0)
	FeelMotion.replace(money_label, &"flash", FeelMotion.tween(money_label)).tween_property(money_label, "modulate", Color.WHITE, 0.3)


## Holds `amount` back from the money line until its coins land (or a safety timeout).
func _hold_money(amount: int) -> void:
	if not is_instance_valid(run_root) or amount <= 0:
		return
	var wallet := int(((run_root as RunSession).state.players[&"local"] as Dictionary).money)
	_money_pending += amount
	_money_hold_until = Time.get_ticks_msec() + 5000
	_money_hold_serial += 1
	var serial := _money_hold_serial
	_shown["money"] = float(wallet - _money_pending)
	_render_progress(_last_totals)
	get_tree().create_timer(5.2, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(self) and serial == _money_hold_serial and _money_pending > 0:
			_release_money(_money_pending)
	)


## Lands `amount`: the display settles to the true wallet minus whatever is still in the air.
func _release_money(amount: int) -> void:
	_money_pending = maxi(_money_pending - amount, 0)
	if _money_pending == 0:
		_money_hold_until = 0
	if not is_instance_valid(run_root):
		return
	var wallet := int(((run_root as RunSession).state.players[&"local"] as Dictionary).money)
	_shown["money"] = float(wallet - _money_pending)
	_render_progress(_last_totals)
	if amount > 0:
		if FeelMotion.reduced(settings_store):
			_flash_money()
		else:
			_float_money(amount, wallet - _money_pending)


func _on_receipt_created(receipt: Dictionary) -> void:
	_hold_money(int(receipt.get("total_pay", 0)))


func _on_receipt_total_ready(total: int, from_global: Vector2) -> void:
	if total <= 0 or FeelMotion.reduced(settings_store) or not is_instance_valid(run_root):
		_release_money(total)
		return
	_fly_coins(from_global, total, clampi(total / FEEL.coin_value, FEEL.coin_min, FEEL.coin_max))


## Coins arc from `from_global` into the money line; each arrival steps the display and bumps it.
func _fly_coins(from_global: Vector2, amount: int, count: int) -> void:
	coin_flyer.fly(from_global, money_label, count, func(_index: int, total_count: int) -> void:
		_shown["money"] = float(_shown.get("money", 0.0)) + float(amount) / float(total_count)
		_render_progress(_last_totals)
		FeelMotion.bump_control(money_label, FEEL.bump_scale, FEEL.bump_seconds)
	, func() -> void: _release_money(amount))


func _shine(control: Control) -> void:
	var material := control.material as ShaderMaterial
	if material == null or FeelMotion.reduced(settings_store):
		return
	material.set_shader_parameter("rect_size", control.size)
	FeelMotion.replace(control, &"shine", FeelMotion.tween(control)).tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), -0.3, 1.3, FEEL.bar_shine_seconds)


## A quick horizontal shake that ends exactly at the panel's laid-out position. It moves only the
## horizontal offsets, so it composes with the toast's vertical ease-in.
func _shake(panel: Control) -> void:
	if FeelMotion.reduced(settings_store):
		return
	var t := FeelMotion.replace(panel, &"shake", FeelMotion.tween(panel))
	t.tween_method(func(elapsed: float) -> void: FeelMotion.nudge_x(panel, FeelMotion.shake_offset(elapsed, 0.2, 5.0)), 0.0, 0.2, 0.2)
	t.tween_callback(func() -> void: FeelMotion.nudge_x(panel, 0.0))


func _on_player_cue(cue: StringName, info: Dictionary) -> void:
	if cue != &"rejected" and cue != &"vacuum_full":
		return
	if error_panel.visible:
		_shake(error_panel)
	if cue == &"vacuum_full" or str(info.get("reason", "")).contains("Bag full"):
		_shake(context_panel)
		bag_bar.modulate = Color(1.5, 1.2, 1.2)
		FeelMotion.replace(bag_bar, &"flash", FeelMotion.tween(bag_bar)).tween_property(bag_bar, "modulate", Color.WHITE, 0.3)


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
			var bag_id := StringName(str(object_ref.get("id", "")))
			var category := str((session.state.bag_records[bag_id] as Dictionary).category).capitalize()
			holding = "Holding %s bag %d / %d" % [category, index + 1, held.size()]
		else:
			var item := session.state.items.get(StringName(str(object_ref.get("id", "")))) as ItemRecord
			if item != null:
				holding = "Holding %s %d / %d" % [(session.definitions[item.definition_id] as ItemDefinition).display_name, index + 1, held.size()]
	context_label.text = "Bag %d / %d\nTool %s\n%s" % [bag_count, int(record.bag_capacity), tool_name, holding]
	_update_bag_bar(bag_count, int(record.bag_capacity))
	if bag_count == int(record.bag_capacity):
		_show_guidance(session, &"full_bag", "Bag full. Unload it onto a sorting table, then collect more.")


## The bag bar fills, turns amber near capacity and red when full, and bumps on each new item.
func _update_bag_bar(bag_count: int, capacity: int) -> void:
	var reduced := FeelMotion.reduced(settings_store)
	var ratio := float(bag_count) / float(maxi(capacity, 1))
	bag_bar.max_value = float(maxi(capacity, 1))
	var style := _bag_styles[2] if ratio >= 1.0 else (_bag_styles[1] if ratio >= FEEL.bag_warn_ratio else _bag_styles[0])
	bag_bar.add_theme_stylebox_override(&"fill", style)
	if reduced or _last_bag_count < 0:
		FeelMotion.replace(bag_bar, &"value", null)
		bag_bar.value = float(bag_count)
	else:
		FeelMotion.replace(bag_bar, &"value", FeelMotion.tween(bag_bar)).tween_property(bag_bar, "value", float(bag_count), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if bag_count > _last_bag_count:
			FeelMotion.bump_control(bag_bar, 1.08, 0.14)
	_last_bag_count = bag_count


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
	var reward_amount := _pending_group_reward
	_pending_group_count = 0
	_pending_group_reward = 0
	_pending_group_family = ""
	_queue_notice(label + reward, 2.5, &"", null, 1)
	if reward_amount > 0:
		# First-time set rewards send a few coins from the notice to the wallet.
		if FeelMotion.reduced(settings_store):
			_release_money(reward_amount)
		else:
			_fly_coins(guidance_panel.get_global_rect().get_center(), reward_amount, clampi(reward_amount / 5, 1, 3))


func _on_area_restored(area_id: StringName, zone: bool) -> void:
	if _pending_sections.is_empty() and _pending_zones.is_empty():
		call_deferred("_flush_restored_notices")
	if zone:
		_pending_zones.append(area_id)
	else:
		_pending_sections.append(area_id)


## Three or more sections restored together get one "N areas restored" banner. Far areas add
## their distance and direction, and the pointer turns the player toward the nearest one they
## cannot see.
func _flush_restored_notices() -> void:
	var section_ids := _pending_sections.duplicate()
	var zone_ids := _pending_zones.duplicate()
	_pending_sections.clear()
	_pending_zones.clear()
	if not is_instance_valid(run_root) or not is_instance_valid(_restoration):
		return
	var player := run_root.get_node("Player") as BeachPlayer
	var origins: Array[Vector3] = []
	if section_ids.size() >= FEEL.banner_batch_threshold:
		for section_id in section_ids:
			origins.append(_restoration.section_origin(section_id))
		_queue_notice("%d areas restored" % section_ids.size(), 3.0, &"", null, 2)
	else:
		for section_id in section_ids:
			var origin := _restoration.section_origin(section_id)
			origins.append(origin)
			_queue_notice("%s restored%s" % [str(section_id).replace("_", " ").replace(":", " · ").capitalize(), _where(origin, player)], 2.8, &"", null, 2)
	for zone_id in zone_ids:
		var origin := _restoration.zone_origin(zone_id)
		origins.append(origin)
		_queue_notice("%s nature returns%s" % [str(zone_id).replace("_", " ").capitalize(), _where(origin, player)], 3.0, &"", null, 2)
	var camera := player.camera
	var nearest := Vector3.INF
	for origin in origins:
		var distance := camera.global_position.distance_to(origin)
		var seen := distance <= FEEL.pointer_far_distance and camera.is_position_in_frustum(origin)
		if not seen and (not nearest.is_finite() or distance < camera.global_position.distance_to(nearest)):
			nearest = origin
	if nearest.is_finite():
		restoration_pointer.point_to(nearest, camera)


## " · 42 m ahead-left" for an area far enough away that the player may not see it restore.
func _where(origin: Vector3, player: BeachPlayer) -> String:
	var scanner := (run_root as RunSession).scanner
	var distance := player.global_position.distance_to(origin)
	if distance <= FEEL.pointer_far_distance or scanner == null:
		return ""
	return " · %d m %s" % [roundi(distance), scanner.direction_words(origin)]


func _show_next_notice() -> void:
	if _notice_queue.is_empty():
		_notice_active = false
		_current_notice = {}
		if guidance_panel.visible and not FeelMotion.reduced(settings_store):
			var serial_out := _notice_serial
			var out := FeelMotion.replace(guidance_panel, &"notice", FeelMotion.tween(guidance_panel))
			out.tween_property(guidance_panel, "modulate:a", 0.0, FEEL.notice_out_seconds)
			out.tween_callback(func() -> void:
				if serial_out == _notice_serial and not _notice_active:
					guidance_panel.hide()
					guidance_panel.modulate.a = 1.0
			)
		else:
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
	_present_notice(int(notice.get("priority", 0)))
	_notice_serial += 1
	var serial := _notice_serial
	get_tree().create_timer(float(notice.duration), false).timeout.connect(func() -> void:
		if is_instance_valid(self) and serial == _notice_serial:
			_show_next_notice()
	)


## Tier glyph and motion: info for tips, a check for sets, a star (gold border, shine) for
## restoration. Visibility is set synchronously; only alpha and position animate.
func _present_notice(priority: int) -> void:
	notice_icon.kind = FeelIcon.Kind.STAR if priority >= 2 else (FeelIcon.Kind.CHECK if priority == 1 else FeelIcon.Kind.INFO)
	notice_icon.color = FEEL.money_color if priority >= 2 else (FEEL.ghost_color if priority == 1 else Color.WHITE)
	if priority >= 2:
		guidance_panel.add_theme_stylebox_override(&"panel", _notice_style_gold)
	else:
		guidance_panel.remove_theme_stylebox_override(&"panel")
	if FeelMotion.reduced(settings_store):
		FeelMotion.replace(guidance_panel, &"notice", null)
		guidance_panel.modulate.a = 1.0
		FeelMotion.nudge_y(guidance_panel, 0.0)
		return
	guidance_panel.modulate.a = 0.0
	FeelMotion.nudge_y(guidance_panel, -FEEL.notice_rise_px)
	var t := FeelMotion.replace(guidance_panel, &"notice", FeelMotion.tween(guidance_panel).set_parallel(true))
	t.tween_property(guidance_panel, "modulate:a", 1.0, FEEL.notice_in_seconds)
	t.tween_method(func(pixels: float) -> void: FeelMotion.nudge_y(guidance_panel, pixels), -FEEL.notice_rise_px, 0.0, FEEL.notice_in_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if priority >= 2:
		FeelMotion.bump_control(guidance_panel, 1.05, 0.2)
		_shine(guidance_panel)


func _clear_notices() -> void:
	FeelMotion.replace(guidance_panel, &"notice", null)
	guidance_panel.modulate.a = 1.0
	FeelMotion.nudge_y(guidance_panel, 0.0)
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
	if paused and not progression_view.visible and not results_view.visible and not settings_menu.visible:
		pause_menu.open_menu()
		pause_menu.set_slot_summaries(save_service.checkpoint_summaries())
	else:
		pause_menu.close_menu()


func _resume_run() -> void:
	if is_instance_valid(run_root):
		pause_menu.close_menu()
		(run_root.get_node("Player") as BeachPlayer).set_paused(false)
		if sorting_view.visible:
			sorting_view.resume_from_pause()


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
		(run_root.get_node("Player") as BeachPlayer).set_input_enabled(not sorting_view.visible)
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
