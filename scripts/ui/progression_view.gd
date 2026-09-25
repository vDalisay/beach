class_name ProgressionView
extends Control
## The equipment shop, the tool rack and the field booklet in one card over the frosted game.
## Booklet pages: section progress grouped by zone, discoveries with their rendered icons and the
## scanner filters, skills to learn, and the current controls with input icons. Purchases and
## equips go through ProgressionService exactly as before; this view only shows the result
## (a coin burst and a wallet pop on success, a shake on failure).

signal opened

enum Mode { SHOP, RACK, BOOKLET }
const BEACH_DEFINITION := preload("res://data/world/beach_01.tres")
const P := preload("res://scripts/ui/kit/ui_palette.gd")
const ICON_OUTLINE := preload("res://data/ui/icon_outline.tres")
const TITLE_ICONS := {
	Mode.SHOP: preload("res://art/synty/ui/icons_3d/SPR_ModernMenus_Icon_Shop_01_Ortho.png"),
	Mode.RACK: preload("res://art/synty/ui/icons_3d/SPR_ModernMenus_Icon_Settings_05_Ortho.png"),
	Mode.BOOKLET: preload("res://art/synty/ui/icons_3d/SPR_ModernMenus_Icon_Book_02_Ortho.png"),
}
const TAB_NAMES := ["Sections", "Discoveries", "Skills", "Controls"]
const TAB_ICONS := [
	preload("res://art/synty/ui/icons_flat/ICON_ModernMenus_Flag_01_Stroke.png"),
	preload("res://art/synty/ui/icons_flat/ICON_ModernMenus_Camera_01_Stroke.png"),
	preload("res://art/synty/ui/icons_flat/ICON_ModernMenus_Lightning_02_Stroke.png"),
	preload("res://art/synty/ui/icons_flat/ICON_ModernMenus_Controller_01_Stroke.png"),
]
const CHECK_ICON := preload("res://art/synty/ui/icons_flat/ICON_ModernMenus_Confirm_01_Stroke.png")
const SKILL_ICON := preload("res://art/synty/ui/icons_3d/SPR_ModernMenus_Icon_Lightning_02_Ortho.png")
const CONTROL_ACTIONS: Array[StringName] = [&"primary", &"interact", &"throw", &"switch_tool", &"select_held_prop", &"booklet", &"scanner_pulse", &"pause", &"jump", &"crouch", &"sprint"]

@onready var title_label: Label = %Title
@onready var title_icon: TextureRect = %TitleIcon
@onready var wallet_label: Label = %Wallet
@onready var wallet_chip: Control = %WalletChip
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
var _shown_money := -1


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


## Every label on the current page, in order, as plain text (the tab row is left out).
func page_text() -> String:
	var parts := PackedStringArray()
	for index in range(1 if mode == Mode.BOOKLET else 0, list.get_child_count()):
		_collect_text(list.get_child(index), parts)
	return "\n".join(parts)


## The buttons in list row `index`, in order (a shop row has one, a rack row two).
func row_buttons(index: int) -> Array[Button]:
	var buttons: Array[Button] = []
	if index >= 0 and index < list.get_child_count():
		_collect_buttons(list.get_child(index), buttons)
	return buttons


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
	_shown_money = -1
	show()
	opened.emit()
	_refresh()
	if UiKit.kit() != null:
		UiKit.kit().screen_in($Margin/Panel as Control, 0.95)


## Rebuilds the page. `keep_focus` names a purchase row whose button keeps focus afterwards, so a
## controller player stays on the row they just bought (or failed to buy) from.
func _refresh(keep_focus := StringName()) -> void:
	if not visible or service == null:
		return
	close_button.text = "Close [%s]" % player.settings_store.binding_text(&"ui_cancel")
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var record := service.session.state.players[&"local"] as Dictionary
	_set_wallet(int(record.money))
	title_icon.texture = TITLE_ICONS[mode]
	match mode:
		Mode.SHOP:
			title_label.text = "EQUIPMENT SHOP"
			for purchase_id in service.ordered_offers(UpgradeDefinition.Source.SHOP):
				_add_purchase_row(purchase_id, UpgradeDefinition.Source.SHOP)
		Mode.BOOKLET:
			title_label.text = "FIELD BOOKLET"
			_add_booklet_tabs()
			match booklet_page:
				0: _add_sections()
				1: _add_discoveries()
				2:
					_add_booklet_text("Skills are learned here. Equipment is bought at the beach shop.")
					for purchase_id in service.ordered_offers(UpgradeDefinition.Source.BOOKLET):
						_add_purchase_row(purchase_id, UpgradeDefinition.Source.BOOKLET)
				3: _add_controls()
		Mode.RACK:
			title_label.text = "TOOL RACK · EQUIP"
			_add_rack_rows(record)
	var enabled_buttons: Array[Button] = []
	for index in range(1 if mode == Mode.BOOKLET else 0, list.get_child_count()):
		for button in row_buttons(index):
			if not button.disabled:
				enabled_buttons.append(button)
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
	var kept := false
	if not keep_focus.is_empty():
		for index in list.get_child_count():
			var row := list.get_child(index)
			if row.get_meta(&"purchase_id", StringName()) == keep_focus:
				var buttons := row_buttons(index)
				if not buttons.is_empty() and not buttons[0].disabled:
					focus_target = buttons[0]
				kept = true
				break
	focus_target.grab_focus()
	if UiKit.kit() != null and not kept:
		UiKit.kit().stagger_in(list, 0.02)


func _set_wallet(money: int) -> void:
	wallet_label.text = "$%s" % _comma(money)
	if _shown_money >= 0 and money != _shown_money and UiKit.kit() != null:
		UiKit.kit().pop(wallet_chip, 1.12, 0.22)
	_shown_money = money


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


# ---------------------------------------------------------------- building blocks

func _add_booklet_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	list.add_child(tabs)
	for index in TAB_NAMES.size():
		var button := Button.new()
		button.text = TAB_NAMES[index]
		button.icon = TAB_ICONS[index]
		button.theme_type_variation = &"TabButton"
		button.toggle_mode = true
		button.button_pressed = index == booklet_page
		button.custom_minimum_size.y = 50
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta(&"ui_quiet", true)
		button.pressed.connect(func() -> void:
			booklet_page = index
			_refresh()
		)
		tabs.add_child(button)


func _add_booklet_text(value: String, variation := &"Body") -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(label)
	return label


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PaperRow"
	return card


func _icon_rect(texture: Texture2D, size := 52.0, outlined := false) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if outlined:
		icon.material = ICON_OUTLINE
	return icon


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.22)
	style.set_corner_radius_all(9)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override(&"panel", style)
	var label := _label(text, &"Caption")
	label.add_theme_color_override(&"font_color", color.darkened(0.45))
	chip.add_child(label)
	return chip


# ---------------------------------------------------------------- sections

func _add_sections() -> void:
	_add_booklet_text("Trash counts after truck collection; placing clean props counts immediately.", &"Caption")
	var zones := {}
	for section_id in BEACH_DEFINITION.ordered_sections:
		var zone := str(section_id).get_slice(":", 0)
		if not zones.has(zone):
			zones[zone] = []
		(zones[zone] as Array).append(section_id)
	for zone in zones:
		list.add_child(_label(str(zone).replace("_", " ").to_upper(), &"Subheading"))
		for section_id in zones[zone]:
			list.add_child(_section_row(section_id))


func _section_row(section_id: StringName) -> Control:
	var section := service.session.state.section_states[section_id] as Dictionary
	var awaiting := 0
	for item_id in service.session.progress_service.section_items.get(section_id, []):
		var item := service.session.state.items[item_id] as ItemRecord
		var definition := service.session.definitions[item.definition_id] as ItemDefinition
		if definition.kind == ItemDefinition.Kind.WASTE and item.location in [ItemRecord.Location.BAG, ItemRecord.Location.HELD, ItemRecord.Location.TABLE, ItemRecord.Location.BIN, ItemRecord.Location.SEALED]:
			awaiting += 1
	var area := int(section.required_waste) - int(section.collected_waste) - awaiting
	var props := int(section.required_props) - int(section.slotted_props)
	var total := int(section.required_waste) + int(section.required_props)
	var done := int(section.collected_waste) + int(section.slotted_props)
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 4)
	row.add_child(stack)
	var head := HBoxContainer.new()
	stack.add_child(head)
	var name := _label(str(section_id).get_slice(":", 1).replace("_", " ").capitalize(), &"Subheading")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(_label("%d / %d" % [done, total], &"Value"))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.max_value = float(maxi(total, 1))
	bar.value = float(done)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(bar)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	stack.add_child(chips)
	# The full sentence stays in page_text for checks and screen readers; chips show the parts.
	chips.set_meta(&"text", "%s  ·  %d in area  ·  %d awaiting collection  ·  %d props to place" % [str(section_id).replace(":", " · ").replace("_", " ").capitalize(), area, awaiting, props])
	chips.add_child(_chip("%d in area" % area, P.AQUA_SHADE))
	chips.add_child(_chip("%d awaiting collection" % awaiting, P.GOLD_SHADE))
	chips.add_child(_chip("%d props to place" % props, P.INK_SOFT))
	if bool(section.get("complete", false)) or bool(section.get("restored_once", false)):
		row.add_child(_icon_rect(CHECK_ICON, 40.0))
	return card


# ---------------------------------------------------------------- discoveries

func _add_discoveries() -> void:
	var found: Array[ItemDefinition] = []
	var materials := PackedStringArray()
	for key in service.session.state.discoveries:
		var parts := str(key).split(":", false, 1)
		if parts.size() != 2:
			continue
		if parts[0] == "definition":
			var definition := service.session.definitions.get(StringName(parts[1])) as ItemDefinition
			if definition != null:
				found.append(definition)
		elif parts[0] == "material":
			materials.append(parts[1].replace("_", " ").capitalize())
	found.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool: return a.display_name < b.display_name)
	materials.sort()
	_add_booklet_text("Known objects: %d" % found.size(), &"Subheading")
	if found.is_empty():
		_add_booklet_text("None yet. Everything you pick up is added here.", &"Caption")
	else:
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		list.add_child(grid)
		for definition in found:
			grid.add_child(_discovery_card(definition))
	_add_booklet_text("Known materials: %s" % (", ".join(materials) if not materials.is_empty() else "None yet"), &"Body")
	var instruction := "Select a filter below, then pulse with %s." % player.settings_store.binding_text(&"scanner_pulse") if service.is_owned(&"local", &"scanner") else "Learn Scanner under Skills to use these discoveries."
	_add_booklet_text(instruction, &"Caption")
	_add_discovery_filters()


func _discovery_card(definition: ItemDefinition) -> Control:
	var card := _card()
	card.custom_minimum_size = Vector2(150, 0)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(stack)
	var texture: Texture2D = null
	if UiKit.kit() != null:
		texture = UiKit.kit().icons.icon("item:%s" % definition.definition_id, definition.visual_scene(), 96)
	var icon := _icon_rect(texture, 64.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(icon)
	var label := _label(definition.display_name, &"Caption")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120
	stack.add_child(label)
	return card


func _add_discovery_filters() -> void:
	var scanner := service.session.scanner
	if scanner == null or not service.is_owned(&"local", &"scanner"):
		return
	var selected := StringName(str((service.session.state.players[&"local"] as Dictionary).scanner_filter))
	for filter_key in scanner.available_filters():
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 50
		list.add_child(row)
		var label := _label(scanner.filter_label(filter_key), &"Body")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 46)
		button.theme_type_variation = &"PrimaryButton" if filter_key == selected else &"SoftButton"
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
				var chosen: bool = child.get_meta(&"scanner_filter") == filter_key
				(child as Button).text = "Selected" if chosen else "Select"
				(child as Button).theme_type_variation = &"PrimaryButton" if chosen else &"SoftButton"


# ---------------------------------------------------------------- controls

func _add_controls() -> void:
	var settings := player.settings_store
	_add_booklet_text("Current %s bindings:" % ("controller" if settings.prompt_device == SettingsStore.PromptDevice.CONTROLLER else "keyboard and mouse"), &"Caption")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	for action in CONTROL_ACTIONS:
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var glyph := InputGlyph.new()
		glyph.rimmed = false
		glyph.glyph_height = 32.0
		glyph.configure(settings, action)
		row.add_child(glyph)
		var label := _label("%s  ·  %s" % [SettingsMenu.ACTION_NAMES.get(action, str(action).capitalize()), settings.binding_text(action)], &"Body")
		label.set_meta(&"plain", "%s  ·  %s" % [str(action).replace("_", " ").capitalize(), settings.binding_text(action)])
		row.add_child(label)
		grid.add_child(card)


# ---------------------------------------------------------------- shop, skills and rack

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
	var card := _card()
	card.set_meta(&"purchase_id", purchase_id)
	list.add_child(card)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 64
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(_icon_rect(_offer_icon(purchase_id, tool), 56.0))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 0)
	row.add_child(details)
	details.add_child(_label(name, &"Subheading"))
	var effect_label := _label(effect, &"Body")
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(effect_label)
	details.set_meta(&"text", "%s  ·  $%d\n%s" % [name, price, effect])
	var button := Button.new()
	button.custom_minimum_size = Vector2(170, 50)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.theme_type_variation = &"PrimaryButton"
	button.text = "Buy $%d" % price
	if not implemented:
		button.text = "Coming later"
		button.disabled = true
	elif service.is_owned(&"local", purchase_id):
		button.text = "Owned"
		button.icon = CHECK_ICON
		button.disabled = true
	elif not prerequisite.is_empty() and not service.is_owned(&"local", prerequisite):
		button.text = "Needs %s" % service.offer_name(prerequisite)
		button.disabled = true
	elif int((service.session.state.players[&"local"] as Dictionary).money) < price:
		# Still pressable: the purchase is refused with its own message ("Need $N more").
		button.theme_type_variation = &"SoftButton"
	button.pressed.connect(_attempt_purchase.bind(purchase_id, source, button))
	row.add_child(button)


func _offer_icon(purchase_id: StringName, tool: ToolDefinition) -> Texture2D:
	if UiKit.kit() == null:
		return null
	if tool != null and tool.scene() != null:
		var roll := -40.0 if purchase_id in [&"detector", &"knife", &"sand_cleaner"] else 0.0
		return UiKit.kit().icons.icon("tool:%s" % purchase_id, tool.scene(), 96, IconStudio.DEFAULT_VIEW, null, roll)
	return SKILL_ICON


func _add_rack_rows(record: Dictionary) -> void:
	var equipped := record.equipped_handheld_ids as Array[StringName]
	for tool_id in record.owned_tools as Array[StringName]:
		var definition := service.offers.get(tool_id) as ToolDefinition
		if tool_id != &"stick" and (definition == null or not definition.handheld):
			continue
		var card := _card()
		list.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 58
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var scene: PackedScene = ProgressionService.STICK_SCENE if tool_id == &"stick" else definition.scene()
		var texture: Texture2D = null
		if UiKit.kit() != null:
			texture = UiKit.kit().icons.icon("tool:%s" % tool_id, scene, 96, IconStudio.DEFAULT_VIEW, null, -40.0 if tool_id in [&"stick", &"detector", &"knife", &"sand_cleaner"] else 0.0)
		row.add_child(_icon_rect(texture, 52.0))
		var name := _label("Poking stick" if tool_id == &"stick" else definition.display_name, &"Subheading")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		for slot in 2:
			var button := Button.new()
			button.custom_minimum_size = Vector2(160, 48)
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.theme_type_variation = &"SoftButton"
			button.text = "Equip slot %d" % (slot + 1) if slot >= equipped.size() else "Replace slot %d" % (slot + 1)
			if slot < equipped.size() and equipped[slot] == tool_id:
				button.text = "In slot %d" % (slot + 1)
				button.icon = CHECK_ICON
				button.disabled = true
			elif tool_id in equipped:
				button.text = "In other slot"
				button.disabled = true
			button.pressed.connect(_attempt_equip.bind(tool_id, slot))
			row.add_child(button)


func _attempt_purchase(purchase_id: StringName, source: UpgradeDefinition.Source, button: Button = null) -> void:
	var result := service.try_purchase(&"local", purchase_id, source)
	result_label.text = "%s purchased" % service.offer_name(purchase_id) if result.ok else result.message
	result_label.add_theme_color_override(&"font_color", P.AQUA_SHADE if result.ok else P.CORAL.darkened(0.2))
	var at := button.get_global_rect().get_center() if is_instance_valid(button) else wallet_chip.get_global_rect().get_center()
	_refresh(purchase_id)
	if not result.ok and not UiKit.reduced():
		_shake(wallet_chip)
	if result.ok and UiKit.kit() != null:
		UiKit.kit().burst(at, UiKit.Burst.COIN, 10)
		UiKit.kit().burst(at, UiKit.Burst.STAR, 8)


func _attempt_equip(tool_id: StringName, slot: int) -> void:
	var result := service.try_equip(&"local", tool_id, slot)
	result_label.text = "%s equipped in slot %d" % [service.offer_name(tool_id), slot + 1] if result.ok else result.message
	result_label.add_theme_color_override(&"font_color", P.AQUA_SHADE if result.ok else P.CORAL.darkened(0.2))
	_refresh()


func _shake(control: Control) -> void:
	var start := control.position.x
	var t := FeelMotion.replace(control, &"shake", FeelMotion.tween(control))
	t.tween_method(func(elapsed: float) -> void: control.position.x = start + FeelMotion.shake_offset(elapsed, 0.25, 6.0), 0.0, 0.25, 0.25)
	t.tween_callback(func() -> void: control.position.x = start)


# ---------------------------------------------------------------- text helpers

static func _collect_text(node: Node, parts: PackedStringArray) -> void:
	if node.has_meta(&"text"):
		parts.append(str(node.get_meta(&"text")))
		return
	if node is Label:
		parts.append(str(node.get_meta(&"plain")) if node.has_meta(&"plain") else (node as Label).text)
		return
	for child in node.get_children():
		_collect_text(child, parts)


static func _collect_buttons(node: Node, buttons: Array[Button]) -> void:
	if node is Button:
		buttons.append(node as Button)
		return
	for child in node.get_children():
		_collect_buttons(child, buttons)


static func _comma(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
