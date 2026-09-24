class_name ProgressionView
extends Control

signal opened

enum Mode { SHOP, RACK, BOOKLET }
const BEACH_DEFINITION := preload("res://data/world/beach_01.tres")

@onready var title_label: Label = %Title
@onready var wallet_label: Label = %Wallet
@onready var result_label: Label = %Result
@onready var list: VBoxContainer = %OfferList
@onready var offer_scroll: ScrollContainer = $Margin/Panel/Rows/Scroll
@onready var close_button: Button = %CloseButton

var service: ProgressionService
var player: BeachPlayer
var mode := Mode.SHOP
var booklet_page := 0
var _previous_pause := false
var _pending_focus: Control
var _focus_delay := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(close)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	set_process(false)
	hide()


func configure(progression: ProgressionService, player_body: BeachPlayer) -> void:
	service = progression
	player = player_body
	if not player.settings_store.prompt_device_changed.is_connected(_on_prompt_device_changed):
		player.settings_store.prompt_device_changed.connect(_on_prompt_device_changed)
	if not player.settings_store.bindings_changed.is_connected(_refresh):
		player.settings_store.bindings_changed.connect(_refresh)


func open_shop() -> void:
	_open(Mode.SHOP)


func open_rack() -> void:
	_open(Mode.RACK)


func open_booklet() -> void:
	booklet_page = 0
	_open(Mode.BOOKLET)


func close() -> void:
	if not visible:
		return
	hide()
	player.set_input_enabled(true)
	player.set_paused(_previous_pause)
	result_label.text = ""


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"booklet"):
		close()
		get_viewport().set_input_as_handled()


func _open(next_mode: Mode) -> void:
	if visible or service == null:
		return
	mode = next_mode
	_previous_pause = get_tree().paused
	player.set_paused(true)
	player.set_input_enabled(false)
	result_label.text = ""
	show()
	opened.emit()
	_refresh()


func _refresh() -> void:
	if not visible or service == null:
		return
	close_button.text = "Close [%s]" % player.settings_store.binding_text(&"ui_cancel")
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var record := service.session.state.players[&"local"] as Dictionary
	wallet_label.text = "WALLET  $%d" % int(record.money)
	match mode:
		Mode.SHOP:
			title_label.text = "EQUIPMENT SHOP"
			for purchase_id in service.ordered_offers(UpgradeDefinition.Source.SHOP):
				_add_purchase_row(purchase_id, UpgradeDefinition.Source.SHOP)
		Mode.BOOKLET:
			title_label.text = "FIELD BOOKLET"
			_add_booklet_tabs()
			match booklet_page:
				0: _add_booklet_text(_section_tasks())
				1:
					_add_booklet_text(_discoveries())
					_add_discovery_filters()
				2:
					_add_booklet_text("Skills are learned here. Equipment is bought at the beach shop.")
					for purchase_id in service.ordered_offers(UpgradeDefinition.Source.BOOKLET):
						_add_purchase_row(purchase_id, UpgradeDefinition.Source.BOOKLET)
				3: _add_booklet_text(_controls())
		Mode.RACK:
			title_label.text = "TOOL RACK · EQUIP"
			_add_rack_rows(record)
	var enabled_buttons: Array[Button] = []
	for row in list.get_children():
		for child in row.get_children():
			if child is Button and not (child as Button).disabled:
				enabled_buttons.append(child as Button)
	close_button.focus_neighbor_top = NodePath()
	close_button.focus_neighbor_bottom = NodePath()
	if mode != Mode.BOOKLET and not enabled_buttons.is_empty():
		for index in enabled_buttons.size():
			var button := enabled_buttons[index]
			button.focus_neighbor_top = button.get_path_to(close_button if index == 0 else enabled_buttons[index - 1])
			button.focus_neighbor_bottom = button.get_path_to(close_button if index == enabled_buttons.size() - 1 else enabled_buttons[index + 1])
		close_button.focus_neighbor_top = close_button.get_path_to(enabled_buttons[-1])
		close_button.focus_neighbor_bottom = close_button.get_path_to(enabled_buttons[0])
	var focus_target := enabled_buttons[0] if not enabled_buttons.is_empty() else close_button
	if mode == Mode.BOOKLET:
		focus_target = (list.get_child(0) as HBoxContainer).get_child(booklet_page) as Button
	focus_target.grab_focus()


func _on_gui_focus_changed(target: Control) -> void:
	if visible and is_instance_valid(target) and offer_scroll.is_ancestor_of(target):
		offer_scroll.ensure_control_visible(target)
		_pending_focus = target
		_focus_delay = 4
		set_process(true)


func _process(_delta: float) -> void:
	_focus_delay -= 1
	if _focus_delay > 0:
		return
	set_process(false)
	if visible and is_instance_valid(_pending_focus) and _pending_focus.has_focus():
		offer_scroll.ensure_control_visible(_pending_focus)


func _on_prompt_device_changed(_device: SettingsStore.PromptDevice) -> void:
	_refresh()


func _add_booklet_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	list.add_child(tabs)
	for index in 4:
		var button := Button.new()
		button.text = ["Sections", "Discoveries", "Skills", "Controls"][index]
		button.toggle_mode = true
		button.button_pressed = index == booklet_page
		button.custom_minimum_size.y = 46
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			booklet_page = index
			_refresh()
		)
		tabs.add_child(button)


func _add_booklet_text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(label)


func _section_tasks() -> String:
	var lines := PackedStringArray(["Trash counts after truck collection; placing clean props counts immediately."])
	for section_id in BEACH_DEFINITION.ordered_sections:
		var section := service.session.state.section_states[section_id] as Dictionary
		var awaiting := 0
		for item_id in service.session.progress_service.section_items.get(section_id, []):
			var item := service.session.state.items[item_id] as ItemRecord
			var definition := service.session.definitions[item.definition_id] as ItemDefinition
			if definition.kind == ItemDefinition.Kind.WASTE and item.location in [ItemRecord.Location.BAG, ItemRecord.Location.HELD, ItemRecord.Location.TABLE, ItemRecord.Location.BIN, ItemRecord.Location.SEALED]:
				awaiting += 1
		var area := int(section.required_waste) - int(section.collected_waste) - awaiting
		var props := int(section.required_props) - int(section.slotted_props)
		var name := str(section_id).replace(":", " · ").replace("_", " ").capitalize()
		lines.append("%s  ·  %d in area  ·  %d awaiting collection  ·  %d props to place" % [name, area, awaiting, props])
	return "\n\n".join(lines)


func _discoveries() -> String:
	var found := PackedStringArray()
	var materials := PackedStringArray()
	for key in service.session.state.discoveries:
		var parts := str(key).split(":", false, 1)
		if parts.size() != 2:
			continue
		if parts[0] == "definition":
			var definition := service.session.definitions.get(StringName(parts[1])) as ItemDefinition
			if definition != null:
				found.append(definition.display_name)
		elif parts[0] == "material":
			materials.append(parts[1].replace("_", " ").capitalize())
	found.sort()
	materials.sort()
	var instruction := "Select a filter below, then pulse with %s." % player.settings_store.binding_text(&"scanner_pulse") if service.is_owned(&"local", &"scanner") else "Learn Scanner under Skills to use these discoveries."
	return "Known objects: %d\n%s\n\nKnown materials: %s\n\n%s" % [found.size(), ", ".join(found) if not found.is_empty() else "None yet", ", ".join(materials) if not materials.is_empty() else "None yet", instruction]


func _add_discovery_filters() -> void:
	var scanner := service.session.scanner
	if scanner == null or not service.is_owned(&"local", &"scanner"):
		return
	var selected := StringName(str((service.session.state.players[&"local"] as Dictionary).scanner_filter))
	for filter_key in scanner.available_filters():
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 46
		list.add_child(row)
		var label := Label.new()
		label.text = scanner.filter_label(filter_key)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 17)
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size.x = 120
		button.text = "Selected" if filter_key == selected else "Select"
		button.set_meta(&"scanner_filter", filter_key)
		button.pressed.connect(_select_scan_filter.bind(filter_key))
		row.add_child(button)


func _select_scan_filter(filter_key: StringName) -> void:
	var result := service.session.scanner.try_select_filter(filter_key)
	result_label.text = "Scanning %s" % service.session.scanner.filter_label(filter_key) if result.ok else result.message
	if not result.ok:
		return
	for row in list.get_children():
		for child in row.get_children():
			if child is Button and child.has_meta(&"scanner_filter"):
				(child as Button).text = "Selected" if child.get_meta(&"scanner_filter") == filter_key else "Select"


func _controls() -> String:
	var settings := player.settings_store
	var lines := PackedStringArray(["Current %s bindings:" % ("controller" if settings.prompt_device == SettingsStore.PromptDevice.CONTROLLER else "keyboard and mouse")])
	for action in [&"primary", &"interact", &"throw", &"switch_tool", &"select_held_prop", &"booklet", &"pause", &"jump", &"sprint"]:
		lines.append("%s  ·  %s" % [str(action).replace("_", " ").capitalize(), settings.binding_text(action)])
	return "\n\n".join(lines)


func _add_purchase_row(purchase_id: StringName, source: UpgradeDefinition.Source) -> void:
	var definition := service.offers.get(purchase_id) as Resource
	if definition == null:
		return
	var tool := definition as ToolDefinition
	var upgrade := definition as UpgradeDefinition
	var name := tool.display_name if tool != null else upgrade.display_name
	var price := tool.shop_price if tool != null else upgrade.price
	var effect := tool.effect_text if tool != null else upgrade.effect_text
	var implemented := tool.implemented if tool != null else upgrade.implemented
	var prerequisite := tool.upgrade_prerequisite if tool != null else upgrade.prerequisite
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 72
	row.add_theme_constant_override("separation", 12)
	list.add_child(row)
	var details := Label.new()
	details.text = "%s  ·  $%d\n%s" % [name, price, effect]
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("font_size", 18)
	row.add_child(details)
	var button := Button.new()
	button.custom_minimum_size = Vector2(155, 46)
	button.add_theme_color_override("font_disabled_color", Color(0.85, 0.9, 0.89))
	button.text = "Buy $%d" % price
	if not implemented:
		button.text = "COMING LATER"
		button.disabled = true
	elif service.is_owned(&"local", purchase_id):
		button.text = "OWNED"
		button.disabled = true
	elif not prerequisite.is_empty() and not service.is_owned(&"local", prerequisite):
		button.text = "Requires %s" % service.offer_name(prerequisite)
		button.disabled = true
	button.pressed.connect(_attempt_purchase.bind(purchase_id, source))
	row.add_child(button)


func _add_rack_rows(record: Dictionary) -> void:
	var equipped := record.equipped_handheld_ids as Array[StringName]
	for tool_id in record.owned_tools as Array[StringName]:
		var definition := service.offers.get(tool_id) as ToolDefinition
		if tool_id != &"stick" and (definition == null or not definition.handheld):
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 58
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var name := Label.new()
		name.text = "Poking stick" if tool_id == &"stick" else definition.display_name
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_theme_font_size_override("font_size", 18)
		row.add_child(name)
		for slot in 2:
			var button := Button.new()
			button.custom_minimum_size = Vector2(150, 46)
			button.text = "Equip slot %d" % (slot + 1) if slot >= equipped.size() else "Replace slot %d" % (slot + 1)
			if slot < equipped.size() and equipped[slot] == tool_id:
				button.text = "In slot %d" % (slot + 1)
				button.disabled = true
			elif tool_id in equipped:
				button.text = "In other slot"
				button.disabled = true
			button.pressed.connect(_attempt_equip.bind(tool_id, slot))
			row.add_child(button)


func _attempt_purchase(purchase_id: StringName, source: UpgradeDefinition.Source) -> void:
	var result := service.try_purchase(&"local", purchase_id, source)
	result_label.text = "%s purchased" % service.offer_name(purchase_id) if result.ok else result.message
	_refresh()


func _attempt_equip(tool_id: StringName, slot: int) -> void:
	var result := service.try_equip(&"local", tool_id, slot)
	result_label.text = "%s equipped in slot %d" % [service.offer_name(tool_id), slot + 1] if result.ok else result.message
	_refresh()
