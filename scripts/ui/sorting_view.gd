class_name SortingView
extends Control

@onready var status: Label = %Status
@onready var unload_button: Button = %UnloadButton
@onready var exit_button: Button = %ExitButton
@onready var selected_bin_label: Label = %SelectedBin
@onready var selected_item_label: Label = %SelectedItem
@onready var bin_list: ItemList = %BinList
@onready var seal_button: Button = %SealButton
@onready var return_button: Button = %ReturnButton
@onready var tray_label: Label = %TrayLabel
@onready var tray_list: ItemList = %TrayList
@onready var sell_button: Button = %SellButton
@onready var hint: Label = %Hint
@onready var drag_preview: Label = %DragPreview
@onready var bin_bar: HBoxContainer = %Bins

var station: SortingStation
var selected_category := 0
var focused_cell := 0
var inspecting_bin := false
var bin_focus := 0
var selected_bin_item: StringName
var selected_valuable: StringName
var pressed_cell := -1
var press_position := Vector2.ZERO
var dragging := false
var panning := false
var last_mouse := Vector2.ZERO
var bin_buttons: Array[Button] = []


func _ready() -> void:
	bin_buttons = [
		bin_bar.get_node("PMDButton") as Button,
		bin_bar.get_node("OrganicButton") as Button,
		bin_bar.get_node("GeneralButton") as Button,
		bin_bar.get_node("GlassButton") as Button,
	]
	unload_button.pressed.connect(_unload)
	exit_button.pressed.connect(_exit)
	return_button.pressed.connect(_return_selected)
	seal_button.pressed.connect(_seal_selected)
	sell_button.pressed.connect(_sell_selected)
	tray_list.item_selected.connect(_on_tray_item_selected)
	bin_list.item_selected.connect(_on_bin_item_selected)
	for index in range(bin_buttons.size()):
		bin_buttons[index].pressed.connect(_on_bin_pressed.bind(index))
	set_process(false)


func open(active_station: SortingStation) -> void:
	station = active_station
	if not station.contents_changed.is_connected(_on_contents_changed):
		station.contents_changed.connect(_on_contents_changed)
	var settings := station.player.settings_store
	if not settings.prompt_device_changed.is_connected(_on_prompt_device_changed):
		settings.prompt_device_changed.connect(_on_prompt_device_changed)
	if not settings.bindings_changed.is_connected(_refresh_prompts):
		settings.bindings_changed.connect(_refresh_prompts)
	show()
	set_process(true)
	_refresh()
	_refresh_prompts()
	_say("Select a bin, then click or drag an item. %s inspects and corrects bin contents." % settings.binding_text(&"table_inspect_bin"))


func _on_prompt_device_changed(_device: SettingsStore.PromptDevice) -> void:
	_refresh_prompts()


func _refresh_prompts() -> void:
	if station == null:
		return
	var settings := station.player.settings_store
	exit_button.text = "Exit [%s]" % settings.binding_text(&"ui_cancel")
	sell_button.text = "Sell selected valuable [%s]" % settings.binding_text(&"interact")


func close() -> void:
	pressed_cell = -1
	dragging = false
	drag_preview.hide()
	selected_bin_item = &""
	selected_valuable = &""
	inspecting_bin = false
	hide()
	set_process(false)
	station = null


func _process(delta: float) -> void:
	if station == null:
		return
	var pan := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if pan.length_squared() > 0.04:
		_pan(Vector2(pan.x, pan.y) * delta * 2.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or station == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_zoom(-0.25)
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_zoom(0.25)
			return
		if mouse.button_index == MOUSE_BUTTON_MIDDLE:
			panning = mouse.pressed
			last_mouse = mouse.position
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				pressed_cell = _cell_at(mouse.position)
				press_position = mouse.position
				if pressed_cell >= 0:
					focused_cell = pressed_cell
					_show_item(station.item_at(pressed_cell))
			else:
				_mouse_release(mouse.position)
			return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if panning:
			_pan((last_mouse - motion.position) * station.table_camera.size / size.y)
			last_mouse = motion.position
		elif pressed_cell >= 0 and motion.position.distance_to(press_position) > 6.0:
			dragging = true
			drag_preview.text = _name_of(station.item_at(pressed_cell))
			drag_preview.position = motion.position + Vector2(16, 12)
			drag_preview.show()
		return
	if event is InputEventJoypadMotion:
		if event.is_action_pressed(&"primary"):
			_zoom(-0.25)
		elif event.is_action_pressed(&"throw"):
			_zoom(0.25)
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		_back()
	elif event.is_action_pressed(&"table_inspect_bin"):
		inspecting_bin = not inspecting_bin
		selected_bin_item = &""
		bin_focus = 0
		_refresh()
	elif event.is_action_pressed(&"table_bin_previous"):
		_select_category(posmod(selected_category - 1, 4))
	elif event.is_action_pressed(&"table_bin_next"):
		_select_category((selected_category + 1) % 4)
	elif event.is_action_pressed(&"table_bin_1"):
		_select_category(0)
	elif event.is_action_pressed(&"table_bin_2"):
		_select_category(1)
	elif event.is_action_pressed(&"table_bin_3"):
		_select_category(2)
	elif event.is_action_pressed(&"table_bin_4"):
		_select_category(3)
	elif event.is_action_pressed(&"table_focus_left"):
		_move_focus(-1, 0)
	elif event.is_action_pressed(&"table_focus_right"):
		_move_focus(1, 0)
	elif event.is_action_pressed(&"table_focus_up"):
		_move_focus(0, -1)
	elif event.is_action_pressed(&"table_focus_down"):
		_move_focus(0, 1)
	elif event.is_action_pressed(&"table_select"):
		if sell_button.has_focus() or tray_list.has_focus():
			_sell_selected()
		else:
			_select_focused()
	elif event.is_action_pressed(&"interact") and not selected_valuable.is_empty():
		_sell_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	if station == null or not visible or inspecting_bin:
		return
	var center := _cell_screen(focused_cell)
	var radius := clampf(0.22 * size.y / station.table_camera.size * 0.48, 10.0, 26.0)
	draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color.WHITE, false, 2.0)


func _unload() -> void:
	var result := station.try_unload(&"local")
	_say("Unloaded %d waste and %d valuables" % [int(result.receipt.get("waste", 0)), int(result.receipt.get("valuables", 0))] if result.ok else result.message)
	_refresh()


func _exit() -> void:
	if station != null:
		station.exit()


func _back() -> void:
	if pressed_cell >= 0:
		pressed_cell = -1
		dragging = false
		drag_preview.hide()
	elif not selected_bin_item.is_empty():
		_return_selected()
	elif inspecting_bin:
		inspecting_bin = false
		_refresh()
	else:
		_exit()


func _mouse_release(point: Vector2) -> void:
	if pressed_cell < 0:
		return
	var item_id := station.item_at(pressed_cell)
	var was_dragging := dragging
	pressed_cell = -1
	dragging = false
	drag_preview.hide()
	if item_id.is_empty():
		return
	if was_dragging:
		for index in range(bin_buttons.size()):
			if bin_buttons[index].get_global_rect().has_point(point):
				_sort(item_id, index)
				return
		_say("Returned %s to its cell" % _name_of(item_id))
	elif _cell_at(point) == focused_cell:
		_sort(item_id, selected_category)


func _sort(item_id: StringName, category_index: int) -> void:
	var result := station.try_sort(item_id, SortingStation.CATEGORIES[category_index])
	if result.ok:
		_say("%s → %s: %s" % [_name_of(item_id), SortingStation.CATEGORY_NAMES[category_index], "correct" if bool(result.receipt.correct) else "wrong category — you can correct it before sealing"])
		selected_bin_item = &""
	else:
		_say(result.message)
	_refresh()


func _return_selected() -> void:
	if selected_bin_item.is_empty():
		_say("Select an item in the bin first")
		return
	var result := station.try_unsort(selected_bin_item)
	_say("Returned %s to table" % _name_of(selected_bin_item) if result.ok else result.message)
	if result.ok:
		selected_bin_item = &""
	_refresh()


func _seal_selected() -> void:
	var result := station.try_seal(SortingStation.CATEGORIES[selected_category])
	_say("Sealed %d items into %s. Contents cannot be corrected now." % [int(result.receipt.get("count", 0)), str(result.receipt.get("bag_id", ""))] if result.ok else result.message)
	selected_bin_item = &""
	_refresh()


func _sell_selected() -> void:
	if selected_valuable.is_empty():
		_say("Select a valuable on the tray first")
		return
	var result := station.try_sell_valuable(&"local", selected_valuable)
	_say("Sold %s for $%d" % [_name_of(selected_valuable), int(result.receipt.get("amount", 0))] if result.ok else result.message)
	if result.ok:
		selected_valuable = &""
	_refresh()


func _on_tray_item_selected(index: int) -> void:
	var tray := station.table_record().tray as Array
	if index < 0 or index >= tray.size():
		return
	selected_valuable = StringName(str(tray[index]))
	_show_item(selected_valuable)
	sell_button.disabled = false


func _on_bin_pressed(index: int) -> void:
	if not selected_bin_item.is_empty() and index != selected_category:
		_sort(selected_bin_item, index)
	else:
		_select_category(index)


func _select_category(index: int) -> void:
	selected_category = index
	_refresh()


func _on_bin_item_selected(index: int) -> void:
	var contents := station.bin_record(SortingStation.CATEGORIES[selected_category]).items as Array
	if index < 0 or index >= contents.size():
		return
	selected_bin_item = StringName(str(contents[index]))
	bin_focus = index
	_show_item(selected_bin_item)
	_say("Select another bin to move this item, or Return to table")


func _move_focus(dx: int, dy: int) -> void:
	if inspecting_bin:
		var contents := station.bin_record(SortingStation.CATEGORIES[selected_category]).items as Array
		if contents.is_empty():
			return
		bin_focus = clampi(bin_focus + (dy if dy != 0 else dx), 0, contents.size() - 1)
		bin_list.select(bin_focus)
		_show_item(StringName(str(contents[bin_focus])))
		return
	var column := clampi(focused_cell % SortingStation.CELL_COLUMNS + dx, 0, SortingStation.CELL_COLUMNS - 1)
	var row := clampi(focused_cell / SortingStation.CELL_COLUMNS + dy, 0, SortingStation.CELL_ROWS - 1)
	focused_cell = row * SortingStation.CELL_COLUMNS + column
	_show_item(station.item_at(focused_cell))
	queue_redraw()


func _select_focused() -> void:
	if inspecting_bin:
		var contents := station.bin_record(SortingStation.CATEGORIES[selected_category]).items as Array
		if selected_bin_item.is_empty():
			if contents.is_empty():
				_say("Bin is empty")
				return
			selected_bin_item = StringName(str(contents[clampi(bin_focus, 0, contents.size() - 1)]))
			_show_item(selected_bin_item)
			_say("LB/RB selects destination; A moves, B returns to table")
		else:
			_sort(selected_bin_item, selected_category)
		return
	var item_id := station.item_at(focused_cell)
	if item_id.is_empty():
		_say("Empty cell")
		return
	_sort(item_id, selected_category)


func _refresh() -> void:
	if station == null:
		return
	var player_record := station.session.state.players[&"local"] as Dictionary
	var bag_count := (player_record.trash_bag as Array).size() + (player_record.valuable_bag as Array).size()
	status.text = "Table %d/%d  •  Bag %d  •  Rack %d/%d" % [SortingStation.CELL_COUNT - station.free_cell_count(), SortingStation.CELL_COUNT, bag_count, (station.rack_record().slots as Dictionary).size(), SortingStation.RACK_CAPACITY]
	for index in range(bin_buttons.size()):
		var count := (station.bin_record(SortingStation.CATEGORIES[index]).items as Array).size()
		bin_buttons[index].text = "%s %d/%d" % [SortingStation.CATEGORY_NAMES[index], count, SortingStation.BIN_CAPACITY]
		bin_buttons[index].modulate = Color.WHITE if index == selected_category else Color(0.72, 0.72, 0.72)
	selected_bin_label.text = "%s bin%s" % [SortingStation.CATEGORY_NAMES[selected_category], " · INSPECT" if inspecting_bin else ""]
	bin_list.clear()
	for item_value in station.bin_record(SortingStation.CATEGORIES[selected_category]).items:
		var item_id := StringName(str(item_value))
		bin_list.add_item(_name_of(item_id))
		bin_list.set_item_metadata(bin_list.item_count - 1, item_id)
	if inspecting_bin and bin_list.item_count > 0:
		bin_focus = clampi(bin_focus, 0, bin_list.item_count - 1)
		bin_list.select(bin_focus)
	var tray := station.table_record().tray as Array
	tray_label.text = "Valuables tray: %d  •  Sold: %d" % [tray.size(), station.session.state.valuable_sales.size()]
	tray_list.clear()
	for item_value in tray:
		var item_id := StringName(str(item_value))
		var item_record := station.session.state.items[item_id] as ItemRecord
		var item_definition := station.session.definitions[item_record.definition_id] as ItemDefinition
		tray_list.add_item("%s  ·  $%d" % [item_definition.display_name, item_definition.base_sale_value])
		if item_id == selected_valuable:
			tray_list.select(tray_list.item_count - 1)
	sell_button.disabled = selected_valuable.is_empty() or selected_valuable not in tray
	return_button.disabled = selected_bin_item.is_empty()
	seal_button.disabled = (station.bin_record(SortingStation.CATEGORIES[selected_category]).items as Array).is_empty()
	_show_item(selected_bin_item if not selected_bin_item.is_empty() else station.item_at(focused_cell))
	queue_redraw()


func _show_item(item_id: StringName) -> void:
	if item_id.is_empty():
		selected_item_label.text = "No item selected"
		return
	var record := station.session.state.items[item_id] as ItemRecord
	var definition := station.session.definitions[record.definition_id] as ItemDefinition
	selected_item_label.text = "%s\nID: %s" % [definition.display_name, item_id]


func _name_of(item_id: StringName) -> String:
	if item_id.is_empty() or not station.session.state.items.has(item_id):
		return "Item"
	var record := station.session.state.items[item_id] as ItemRecord
	return (station.session.definitions[record.definition_id] as ItemDefinition).display_name


func _cell_at(point: Vector2) -> int:
	if $TopPanel.get_global_rect().has_point(point) or bin_bar.get_global_rect().has_point(point) or $SidePanel.get_global_rect().has_point(point):
		return -1
	var best := -1
	var best_distance := INF
	for index in range(SortingStation.CELL_COUNT):
		var distance := point.distance_to(_cell_screen(index))
		if distance < best_distance:
			best_distance = distance
			best = index
	var radius := clampf(0.22 * size.y / station.table_camera.size * 0.5, 12.0, 28.0)
	return best if best_distance <= radius else -1


func _cell_screen(index: int) -> Vector2:
	var local := Vector3((index % SortingStation.CELL_COLUMNS - 9.5) * 0.22, 1.0, (index / SortingStation.CELL_COLUMNS - 5.5) * 0.22)
	return station.table_camera.unproject_position(station.to_global(local))


func _zoom(amount: float) -> void:
	station.table_camera.size = clampf(station.table_camera.size + amount, 3.3, 6.5)
	queue_redraw()


func _pan(amount: Vector2) -> void:
	var camera := station.table_camera
	camera.position.x = clampf(camera.position.x + amount.x, -1.6, 1.6)
	camera.position.z = clampf(camera.position.z + amount.y, -1.1, 1.1)
	queue_redraw()


func _say(message: String) -> void:
	hint.text = message


func _on_contents_changed() -> void:
	if station != null and visible:
		_refresh()
