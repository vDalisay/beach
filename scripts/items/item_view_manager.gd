class_name ItemViewManager
extends Node3D

signal views_built(count: int)
signal item_recovered(item_id: StringName)

const WORLD_ITEM_SCENE := preload("res://scenes/items/world_item.tscn")
const STREAM_LOAD_RADIUS := 45.0
const STREAM_UNLOAD_RADIUS := 70.0
const BATCH_LOAD_RADIUS := 12.0
const BATCH_UNLOAD_RADIUS := 24.0
const STREAM_SPAWNS_PER_FRAME := 2

var session: RunSession
var definitions: Dictionary
var player: Node3D
var views: Dictionary = {}
var distant_visuals: DistantItemVisuals
var recovery_bounds: RecoveryBounds
var build_time_ms := 0.0
var _stream_candidates: Array[StringName] = []
var _stream_pending: Array[StringName] = []
var _stream_elapsed := 0.0


func configure(run_session: RunSession, item_definitions: Dictionary, recovery_anchors: Dictionary, player_node: Node3D = null) -> void:
	session = run_session
	definitions = item_definitions
	player = player_node
	recovery_bounds = RecoveryBounds.new()
	recovery_bounds.name = "RecoveryBounds"
	add_child(recovery_bounds)
	recovery_bounds.configure(session.state, definitions, recovery_anchors)
	if player != null:
		distant_visuals = DistantItemVisuals.new()
		distant_visuals.name = "DistantItemVisuals"
		add_child(distant_visuals)
		distant_visuals.configure(session.state, definitions)
	if not session.items_changed.is_connected(_on_items_changed):
		session.items_changed.connect(_on_items_changed)
	set_process(player != null)


func build_views() -> void:
	var started := Time.get_ticks_usec()
	if distant_visuals != null:
		distant_visuals.build()
	for item_id_text in _sorted_item_ids():
		var item_id := StringName(item_id_text)
		var record := session.state.items[item_id] as ItemRecord
		var definition := definitions.get(record.definition_id) as ItemDefinition
		if player != null and definition != null and definition.collision_profile != ItemDefinition.CollisionProfile.LARGE:
			_stream_candidates.append(item_id)
		if record.location == ItemRecord.Location.WORLD and (player == null or definition == null or definition.collision_profile == ItemDefinition.CollisionProfile.LARGE or not record.sleeping or _distance_to_player(record) <= _load_radius(record)):
			_spawn_view(record)
	build_time_ms = float(Time.get_ticks_usec() - started) / 1000.0
	views_built.emit(views.size())


func view_for(item_id: StringName) -> WorldItem:
	if not views.has(item_id) and session.state.items.has(item_id):
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.WORLD:
			_spawn_view(record)
	return views.get(item_id) as WorldItem


func _process(delta: float) -> void:
	if player == null or session == null:
		return
	_stream_elapsed += delta
	if _stream_elapsed >= 0.4:
		_stream_elapsed = 0.0
		_refresh_stream()
	var spawned := 0
	while spawned < STREAM_SPAWNS_PER_FRAME and not _stream_pending.is_empty():
		var item_id: StringName = _stream_pending.pop_back()
		if views.has(item_id):
			continue
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.WORLD and _distance_to_player(record) <= _load_radius(record):
			_spawn_view(record)
			spawned += 1


func _refresh_stream() -> void:
	_stream_pending.clear()
	var pending_distances := {}
	for item_id in _stream_candidates:
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.WORLD and not views.has(item_id):
			var distance := _distance_to_player(record)
			if distance <= _load_radius(record):
				_stream_pending.append(item_id)
				pending_distances[item_id] = distance
	_stream_pending.sort_custom(func(a: StringName, b: StringName) -> bool: return float(pending_distances[a]) > float(pending_distances[b]))
	for item_id in views.keys():
		var view := views[item_id] as WorldItem
		if view.definition.collision_profile != ItemDefinition.CollisionProfile.LARGE and view.freeze and view.sleeping and not view.is_highlighted() and _distance_to_player(view.record) > _unload_radius(view.record):
			_remove_view(item_id, true)


func _distance_to_player(record: ItemRecord) -> float:
	return Vector2(record.last_world_transform.origin.x, record.last_world_transform.origin.z).distance_to(Vector2(player.global_position.x, player.global_position.z))


func _load_radius(record: ItemRecord) -> float:
	return BATCH_LOAD_RADIUS if distant_visuals != null and distant_visuals.has_item(record.item_id) else STREAM_LOAD_RADIUS


func _unload_radius(record: ItemRecord) -> float:
	return BATCH_UNLOAD_RADIUS if distant_visuals != null and distant_visuals.has_item(record.item_id) else STREAM_UNLOAD_RADIUS


func activate_item(item_id: StringName) -> WorldItem:
	var view := view_for(item_id)
	if view != null:
		view.activate()
	return view


func take_view_for_presentation(item_id: StringName) -> WorldItem:
	if not views.has(item_id):
		return null
	var view := views[item_id] as WorldItem
	views.erase(item_id)
	view.set_highlighted(false)
	return view


func restore_world_view(item_id: StringName) -> WorldItem:
	if not session.state.items.has(item_id):
		return null
	var record := session.state.items[item_id] as ItemRecord
	if record.location != ItemRecord.Location.WORLD:
		return null
	var view := view_for(item_id)
	if view == null:
		view = _spawn_view(record)
	else:
		view.restore_from_record()
	view.activate()
	return view


func throw_item(item_id: StringName, from: Transform3D, impulse: Vector3, torque := Vector3.ZERO) -> bool:
	if not session.state.items.has(item_id):
		return false
	var record := session.state.items[item_id] as ItemRecord
	if record.location != ItemRecord.Location.WORLD:
		return false
	var view := view_for(item_id)
	if view == null:
		view = _spawn_view(record)
	record.last_world_transform = from
	record.linear_velocity = Vector3.ZERO
	record.angular_velocity = Vector3.ZERO
	record.sleeping = false
	view.restore_from_record()
	view.apply_throw(impulse, torque)
	return true


func synchronize_now() -> void:
	for item_id in views:
		(views[item_id] as WorldItem).synchronize_record()


func synchronize_at_physics_boundary() -> void:
	await get_tree().physics_frame
	synchronize_now()


func remove_view_at_physics_boundary(item_id: StringName) -> void:
	await get_tree().physics_frame
	_remove_view(item_id, true)


func awake_count() -> int:
	var count := 0
	for item_id in views:
		var view := views[item_id] as WorldItem
		if not view.freeze and not view.sleeping:
			count += 1
	return count


func visual_instance_count() -> int:
	var count := 0
	for item_id in views:
		count += _count_meshes(views[item_id])
	return count


func _spawn_view(record: ItemRecord) -> WorldItem:
	if views.has(record.item_id) or not definitions.has(record.definition_id):
		return views.get(record.item_id) as WorldItem
	if distant_visuals != null:
		distant_visuals.set_item_visible(record.item_id, false)
	var view := WORLD_ITEM_SCENE.instantiate() as WorldItem
	add_child(view)
	view.configure(record, definitions[record.definition_id], recovery_bounds.is_outside)
	view.fell_out_of_bounds.connect(_on_item_fell_out)
	views[record.item_id] = view
	return view


func _remove_view(item_id: StringName, synchronize: bool) -> void:
	if not views.has(item_id):
		return
	var view := views[item_id] as WorldItem
	if synchronize:
		view.synchronize_record()
	views.erase(item_id)
	if distant_visuals != null:
		distant_visuals.set_item_visible(item_id, view.record.location == ItemRecord.Location.WORLD and view.record.sleeping)
	view.collision_layer = 0
	view.collision_mask = 0
	view.hide()
	view.queue_free()


func _on_item_fell_out(item_id: StringName) -> void:
	var before_count := session.state.items.size()
	var player_money := _total_money()
	var view := view_for(item_id)
	if view != null:
		view.synchronize_record()
	if not recovery_bounds.recover_item(item_id):
		return
	if view != null:
		view.restore_from_record()
	assert(session.state.items.size() == before_count and _total_money() == player_money)
	session.finalize_action(PackedStringArray([str(item_id)]))
	item_recovered.emit(item_id)


func _on_items_changed(item_ids: PackedStringArray) -> void:
	_reconcile_at_boundary(item_ids)


func _reconcile_at_boundary(item_ids: PackedStringArray) -> void:
	await get_tree().physics_frame
	for item_id_text in item_ids:
		var item_id := StringName(item_id_text)
		if not session.state.items.has(item_id):
			_remove_view(item_id, false)
			continue
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.WORLD:
			if not views.has(item_id):
				_spawn_view(record)
			else:
				(views[item_id] as WorldItem).refresh_dirt_visuals()
		else:
			_remove_view(item_id, true)
			if distant_visuals != null:
				distant_visuals.set_item_visible(item_id, false)


func _total_money() -> int:
	var total := 0
	for player_id in session.state.players:
		total += int((session.state.players[player_id] as Dictionary).get("money", 0))
	return total


func _sorted_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in session.state.items:
		result.append(str(item_id))
	result.sort()
	return result


func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count
