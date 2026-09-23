class_name ScannerService
extends Node

signal feedback_requested(message: String)
signal pulse_succeeded

const MARKER_SCENE := preload("res://scenes/ui/scanner_marker.tscn")
const MARKER_LIMIT := 8
const NEAR_RANGE := 30.0

var session: RunSession
var player: BeachPlayer
var overlay: Control
var summary: Label
var marker_layer: Control
var markers: Array[PanelContainer] = []
var _expires_at := 0
var _refresh_at := 0


func configure(run_session: RunSession, player_body: BeachPlayer, scanner_overlay: Control) -> void:
	session = run_session
	player = player_body
	overlay = scanner_overlay
	summary = overlay.get_node("SummaryPanel/Summary") as Label
	marker_layer = overlay.get_node("Markers") as Control
	overlay.hide()
	session.scanner = self
	player.scanner_requested.connect(pulse)
	session.items_changed.connect(func(_ids: PackedStringArray) -> void:
		if overlay.visible:
			_refresh()
	)
	set_process(true)


func available_filters() -> Array[StringName]:
	var keys: Array[String] = []
	for key in (session.state.players[&"local"] as Dictionary).discoveries as Array[StringName]:
		if str(key).begins_with("definition:") or str(key).begins_with("material:"):
			keys.append(str(key))
	keys.sort()
	var result: Array[StringName] = []
	for key in keys:
		result.append(StringName(key))
	return result


func filter_label(key: StringName) -> String:
	var value := str(key)
	if value.begins_with("definition:"):
		var definition := session.definitions.get(StringName(value.trim_prefix("definition:"))) as ItemDefinition
		if definition == null:
			return "Unknown object"
		var tags := PackedStringArray()
		for tag in definition.material_tags:
			tags.append(str(tag).replace("_", " "))
		return "Type · %s (%s)" % [definition.display_name, ", ".join(tags)]
	return "Material · %s" % value.trim_prefix("material:").replace("_", " ").capitalize()


func try_select_filter(key: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_select_filter.bind(key))
	if not session.progression.is_owned(&"local", &"scanner"):
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "Learn Scanner in the field booklet first")
	if key not in available_filters():
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Discover this object or material before scanning for it")
	var record := session.state.players[&"local"] as Dictionary
	if StringName(str(record.scanner_filter)) != key:
		record.scanner_filter = key
		session.finalize_action(PackedStringArray())
	if overlay.visible:
		_refresh()
	return ActionResult.accepted(PackedStringArray(), {"filter": str(key)})


func query_matches(key: StringName = StringName()) -> Dictionary:
	if not session.progression.is_owned(&"local", &"scanner"):
		return {"ok": false, "message": "Learn Scanner in the field booklet first"}
	if key.is_empty():
		key = StringName(str((session.state.players[&"local"] as Dictionary).scanner_filter))
	if key.is_empty() or key not in available_filters():
		return {"ok": false, "message": "Choose a discovered scanner filter in the booklet"}
	var ids := PackedStringArray()
	var groups := {}
	var carried := 0
	for value in session.state.items.values():
		var item := value as ItemRecord
		var definition := session.definitions.get(item.definition_id) as ItemDefinition
		if definition == null or not _matches(definition, key):
			continue
		if item.location in [ItemRecord.Location.COLLECTED, ItemRecord.Location.SOLD, ItemRecord.Location.BAG, ItemRecord.Location.HELD]:
			continue
		if item.location == ItemRecord.Location.SLOTTED and item.dirty_patches_remaining.is_empty():
			continue
		if item.location == ItemRecord.Location.BURIED and not item.revealed:
			continue
		var target := _target_for(item, definition)
		if target.is_empty():
			continue
		ids.append(str(item.item_id))
		if bool(target.get("carried", false)):
			carried += 1
			continue
		var owner_key := str(target.key)
		if not groups.has(owner_key):
			groups[owner_key] = target
			(groups[owner_key] as Dictionary)["count"] = 0
			(groups[owner_key] as Dictionary)["actions"] = PackedStringArray()
		var group := groups[owner_key] as Dictionary
		group.count = int(group.count) + 1
		var action := str(target.get("action", ""))
		var actions := group.actions as PackedStringArray
		if not action.is_empty() and action not in actions:
			actions.append(action)
			group.actions = actions
	var targets: Array[Dictionary] = []
	for target in groups.values():
		var actions := (target as Dictionary).actions as PackedStringArray
		if not actions.is_empty():
			(target as Dictionary).label = "%s · %s" % [(target as Dictionary).label, ", ".join(actions)]
		targets.append(target as Dictionary)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := player.global_position.distance_squared_to(a.position as Vector3)
		var db := player.global_position.distance_squared_to(b.position as Vector3)
		return str(a.key) < str(b.key) if is_equal_approx(da, db) else da < db
	)
	ids.sort()
	return {"ok": true, "filter": str(key), "ids": ids, "targets": targets, "carried_count": carried}


func pulse() -> ActionResult:
	var result := query_matches()
	if not bool(result.ok):
		feedback_requested.emit(str(result.message))
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, str(result.message))
	_expires_at = Time.get_ticks_msec() + 6000
	_refresh_at = 0
	overlay.show()
	_refresh(result)
	pulse_succeeded.emit()
	return ActionResult.accepted(PackedStringArray(), {"count": (result.ids as PackedStringArray).size(), "filter": str(result.filter)})


func _process(_delta: float) -> void:
	if overlay == null or not overlay.visible:
		return
	if Time.get_ticks_msec() >= _expires_at:
		overlay.hide()
		return
	if Time.get_ticks_msec() >= _refresh_at:
		_refresh()
		_refresh_at = Time.get_ticks_msec() + 500


func _refresh(existing: Dictionary = {}) -> void:
	var result := existing if not existing.is_empty() else query_matches()
	if not bool(result.get("ok", false)):
		overlay.hide()
		return
	for marker in markers:
		marker.hide()
	var shown := 0
	var nearby := 0
	var farther := 0
	var nearest_far := INF
	var far_position := Vector3.ZERO
	var occupied_cells := {}
	for target in result.targets as Array[Dictionary]:
		var position := target.position as Vector3
		var distance := player.global_position.distance_to(position)
		var count := int(target.count)
		if distance <= NEAR_RANGE and _on_screen(position):
			nearby += count
			var screen := player.camera.unproject_position(position) + Vector2(26, -38)
			var cell := Vector2i(int(screen.x / 230.0), int(screen.y / 76.0))
			if shown < MARKER_LIMIT and not occupied_cells.has(cell) and _marker_position_clear(screen):
				occupied_cells[cell] = true
				_show_marker(shown, target, distance, screen)
				shown += 1
		else:
			farther += count
			if distance < nearest_far:
				nearest_far = distance
				far_position = position
	var total := (result.ids as PackedStringArray).size()
	var title := "SCAN · %s\n%d remaining · %d nearby (%d shown)\n%d offscreen/distant" % [filter_label(StringName(str(result.filter))), total, nearby, shown, farther]
	if int(result.carried_count) > 0:
		title += "\n%d in a carried sealed bag · deposit it" % int(result.carried_count)
	if farther > 0:
		title += "\nNearest: %s · %dm" % [_direction(far_position), roundi(nearest_far)]
	if total == 0:
		title = "SCAN · %s\nNo remaining matches" % filter_label(StringName(str(result.filter)))
	title += "\n◆ Hints may be occluded; move close to interact"
	summary.text = title


func _show_marker(index: int, target: Dictionary, distance: float, screen: Vector2) -> void:
	if index >= markers.size():
		var marker := MARKER_SCENE.instantiate() as PanelContainer
		marker_layer.add_child(marker)
		markers.append(marker)
	var marker := markers[index]
	(marker.get_node("Text") as Label).text = "◆ %s%s · %dm" % [str(target.label), " ×%d" % int(target.count) if int(target.count) > 1 else "", roundi(distance)]
	marker.position = screen
	marker.show()


func _marker_position_clear(screen: Vector2) -> bool:
	var marker_rect := Rect2(screen, Vector2(220, 72))
	var viewport_size := overlay.get_viewport_rect().size
	if marker_rect.intersects(Rect2(viewport_size * 0.5 - Vector2(70, 50), Vector2(140, 100))):
		return false
	for path in ["ProgressPanel", "ContextPanel", "GuidancePanel"]:
		var panel := overlay.get_parent().get_node(path) as Control
		if panel.visible and marker_rect.intersects(panel.get_global_rect()):
			return false
	return not marker_rect.intersects((summary.get_parent() as Control).get_global_rect())


func _on_screen(position: Vector3) -> bool:
	if player.camera.is_position_behind(position):
		return false
	var screen := player.camera.unproject_position(position)
	var size := overlay.get_viewport_rect().size
	return screen.x >= 24.0 and screen.y >= 24.0 and screen.x <= size.x - 240.0 and screen.y <= size.y - 84.0


func _direction(position: Vector3) -> String:
	var offset := player.global_basis.inverse() * (position - player.global_position)
	var angle := rad_to_deg(atan2(offset.x, -offset.z))
	if angle > -22.5 and angle <= 22.5:
		return "ahead"
	if angle > 22.5 and angle <= 67.5:
		return "ahead-right"
	if angle > 67.5 and angle <= 112.5:
		return "right"
	if angle > 112.5 and angle <= 157.5:
		return "behind-right"
	if angle <= -22.5 and angle > -67.5:
		return "ahead-left"
	if angle <= -67.5 and angle > -112.5:
		return "left"
	if angle <= -112.5 and angle > -157.5:
		return "behind-left"
	return "behind"


func _matches(definition: ItemDefinition, key: StringName) -> bool:
	var value := str(key)
	if value.begins_with("definition:"):
		return str(definition.definition_id) == value.trim_prefix("definition:")
	return value.begins_with("material:") and StringName(value.trim_prefix("material:")) in definition.material_tags


func _target_for(item: ItemRecord, definition: ItemDefinition) -> Dictionary:
	match item.location:
		ItemRecord.Location.WORLD:
			var view := session.item_view_manager.views.get(item.item_id) as WorldItem
			return {"key": str(item.item_id), "position": view.global_position if view != null else item.last_world_transform.origin, "label": definition.display_name, "count": 1}
		ItemRecord.Location.BURIED:
			return {"key": str(item.item_id), "position": item.reveal_transform.origin, "label": definition.display_name, "count": 1}
		ItemRecord.Location.ATTACHED:
			var site_id := StringName(str(item.attachment_id).get_slice("/", 0))
			var site := session.rescue_knife.sites.get(site_id) as RescueSite
			var area := site.attachment_area(item.item_id) if site != null else null
			if area != null:
				return {"key": "rescue:%s" % site_id, "position": area.global_position, "label": "Rescue site", "action": "cut litter", "count": 1}
		ItemRecord.Location.TABLE, ItemRecord.Location.BIN, ItemRecord.Location.VALUABLE_TRAY:
			var station_id := item.container_id
			if item.location == ItemRecord.Location.BIN:
				var text_id := str(station_id)
				station_id = StringName(text_id.substr(0, text_id.rfind(":")))
			var station := session.sorting_stations.get(station_id) as SortingStation
			if station != null:
				var action := "sell" if item.location == ItemRecord.Location.VALUABLE_TRAY else ("seal" if item.location == ItemRecord.Location.BIN else "sort")
				return {"key": "station:%s" % station_id, "position": station.global_position + Vector3.UP, "label": "Sorting station", "action": action, "count": 1}
		ItemRecord.Location.SEALED:
			var bag := session.state.bag_records.get(item.container_id, {}) as Dictionary
			if bag.is_empty():
				return {}
			match str(bag.location):
				"HELD": return {"carried": true}
				"RACK":
					var station := session.sorting_stations.get(StringName(str(bag.station_id))) as SortingStation
					if station != null:
						return {"key": "station:%s" % bag.station_id, "position": station.global_position + Vector3.UP, "label": "Sorting station", "action": "carry sealed bag", "count": 1}
				"CONTAINER":
					var container := session.waste_containers.get(StringName(str(bag.container_id))) as WasteContainer
					if container != null:
						return {"key": "container:%s" % bag.container_id, "position": container.global_position + Vector3.UP, "label": "Collection container", "action": "call truck", "count": 1}
				"WORLD":
					return {"key": "bag:%s" % item.container_id, "position": ItemRecord._array_to_transform(bag.world_transform as Array).origin, "label": "Sealed bag", "action": "carry to container", "count": 1}
		ItemRecord.Location.SLOTTED:
			if session.placement_service != null:
				return {"key": str(item.item_id), "position": session.placement_service.slot_transform(item.slot_id).origin, "label": "Prop needs cleaning", "count": 1}
	return {}
