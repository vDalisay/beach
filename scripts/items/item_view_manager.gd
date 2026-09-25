class_name ItemViewManager
extends Node3D

signal views_built(count: int)
signal item_recovered(item_id: StringName)

const WORLD_ITEM_SCENE := preload("res://scenes/items/world_item.tscn")
const STREAM_LOAD_RADIUS := 45.0
const STREAM_UNLOAD_RADIUS := 70.0
const BATCH_LOAD_RADIUS := 12.0
const BATCH_UNLOAD_RADIUS := 24.0
const STREAM_REFRESH_SECONDS := 0.25
# Streamed spawns run under a per-frame time budget; the cap bounds a frame's burst.
const STREAM_SPAWNS_PER_FRAME := 8
const STREAM_SPAWN_BUDGET_USEC := 1200
# Stream candidates are bucketed in square cells so a refresh scans only the cells around the
# player instead of every record: one grid for batched litter (12 m load radius) and one for the
# rest (45 m). Moved records are re-bucketed when their view is released and, as a safety net, a
# slice of all candidates is re-bucketed each refresh.
const STREAM_CELL := 16.0
const REBUCKET_PER_REFRESH := 128
# Live views are checked for demotion and shadow budget a few at a time, round-robin.
const VIEW_CHECKS_PER_FRAME := 48
# Released views wait here, out of the physics space and hidden, for the next streamed record.
const VIEW_POOL_LIMIT := 96
# Views stop casting sun shadows this far beyond their quality budget, and start again inside it.
const SHADOW_HYSTERESIS := 2.0

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
var _batched_cells: Dictionary = {}
var _free_cells: Dictionary = {}
var _cell_of: Dictionary = {}
var _rebucket_cursor := 0
var _maintenance_queue: Array[StringName] = []
var _pool: Array[WorldItem] = []


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
			_bucket(item_id, record)
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
	if _stream_elapsed >= STREAM_REFRESH_SECONDS:
		_stream_elapsed = 0.0
		_refresh_stream()
	_maintain_views()
	var started := Time.get_ticks_usec()
	var spawned := 0
	while spawned < STREAM_SPAWNS_PER_FRAME and not _stream_pending.is_empty() and (spawned == 0 or Time.get_ticks_usec() - started < STREAM_SPAWN_BUDGET_USEC):
		var item_id: StringName = _stream_pending.pop_back()
		if views.has(item_id):
			continue
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.WORLD and _distance_to_player(record) <= _load_radius(record):
			_spawn_view(record)
			spawned += 1


func _refresh_stream() -> void:
	_stream_pending.clear()
	_rebucket_slice()
	var pending_distances := {}
	_scan_cells(_batched_cells, BATCH_LOAD_RADIUS, pending_distances)
	_scan_cells(_free_cells, STREAM_LOAD_RADIUS, pending_distances)
	_stream_pending.sort_custom(func(a: StringName, b: StringName) -> bool: return float(pending_distances[a]) > float(pending_distances[b]))


func _scan_cells(grid: Dictionary, radius: float, pending_distances: Dictionary) -> void:
	var eye := Vector2(player.global_position.x, player.global_position.z)
	var center := _cell_for(player.global_position)
	var reach := ceili(radius / STREAM_CELL)
	for offset_x in range(-reach, reach + 1):
		for offset_z in range(-reach, reach + 1):
			var cell: Variant = grid.get(center + Vector2i(offset_x, offset_z))
			if cell == null:
				continue
			for item_id in cell as Array[StringName]:
				if views.has(item_id):
					continue
				var record := session.state.items.get(item_id) as ItemRecord
				if record == null or record.location != ItemRecord.Location.WORLD:
					continue
				var origin := record.last_world_transform.origin
				var distance := Vector2(origin.x, origin.z).distance_to(eye)
				if distance <= radius:
					_stream_pending.append(item_id)
					pending_distances[item_id] = distance


## Demotes far resting views and applies the shadow budget, a slice of the live views per frame.
func _maintain_views() -> void:
	if _maintenance_queue.is_empty():
		_maintenance_queue.assign(views.keys())
	var eye := Vector2(player.global_position.x, player.global_position.z)
	for step in mini(VIEW_CHECKS_PER_FRAME, _maintenance_queue.size()):
		var item_id: StringName = _maintenance_queue.pop_back()
		var view := views.get(item_id) as WorldItem
		if view == null:
			continue
		if view.definition.collision_profile != ItemDefinition.CollisionProfile.LARGE and view.freeze and view.sleeping and not view.is_highlighted() and _distance_to_player(view.record) > _unload_radius(view.record):
			_remove_view(item_id, true)
			continue
		_update_shadow(view, Vector2(view.global_position.x, view.global_position.z).distance_to(eye))


## Sun-shadow budget: small litter and furniture cast only within their quality distance.
func _update_shadow(view: WorldItem, distance: float) -> void:
	var limit := RenderQuality.large_item_shadow_distance if view.definition.collision_profile == ItemDefinition.CollisionProfile.LARGE else RenderQuality.small_item_shadow_distance
	if view.casts_shadow and distance > limit + SHADOW_HYSTERESIS:
		view.set_shadow_casting(false)
	elif not view.casts_shadow and distance < limit:
		view.set_shadow_casting(true)


## Re-applies the view-distance and shadow budgets to every live view after a Graphics change.
func refresh_detail_ranges() -> void:
	for item_id in views:
		(views[item_id] as WorldItem).apply_detail_range()
	if player != null:
		var eye := Vector2(player.global_position.x, player.global_position.z)
		for item_id in views:
			var view := views[item_id] as WorldItem
			_update_shadow(view, Vector2(view.global_position.x, view.global_position.z).distance_to(eye))


func _cell_for(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / STREAM_CELL), floori(position.z / STREAM_CELL))


func _bucket(item_id: StringName, record: ItemRecord) -> void:
	var cell := _cell_for(record.last_world_transform.origin)
	var previous: Variant = _cell_of.get(item_id)
	if previous == cell:
		return
	# Whether an item has a batch instance is fixed at build, so it never changes grid.
	var grid := _batched_cells if distant_visuals != null and distant_visuals.has_item(item_id) else _free_cells
	if previous != null:
		(grid[previous] as Array[StringName]).erase(item_id)
	if not grid.has(cell):
		grid[cell] = [] as Array[StringName]
	(grid[cell] as Array[StringName]).append(item_id)
	_cell_of[item_id] = cell


func _rebucket_slice() -> void:
	var count := _stream_candidates.size()
	for step in mini(REBUCKET_PER_REFRESH, count):
		_rebucket_cursor = (_rebucket_cursor + 1) % count
		var item_id := _stream_candidates[_rebucket_cursor]
		# A live view's record can lag its body; it is re-bucketed when the view is released.
		if not views.has(item_id) and session.state.items.has(item_id):
			_bucket(item_id, session.state.items[item_id] as ItemRecord)


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
	var view: WorldItem
	if not _pool.is_empty():
		view = _pool.pop_back()
		view.process_mode = Node.PROCESS_MODE_INHERIT
		view.show()
	else:
		view = WORLD_ITEM_SCENE.instantiate() as WorldItem
		add_child(view)
		view.fell_out_of_bounds.connect(_on_item_fell_out)
	view.configure(record, definitions[record.definition_id], recovery_bounds.is_outside)
	views[record.item_id] = view
	if player != null:
		_update_shadow(view, _distance_to_player(record))
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
	if _cell_of.has(item_id) and session.state.items.has(item_id):
		_bucket(item_id, session.state.items[item_id] as ItemRecord)
	_release_view(view)


## Pools a released view for the next streamed record; frees it when the pool is full.
func _release_view(view: WorldItem) -> void:
	if _pool.size() < VIEW_POOL_LIMIT and view.get_parent() == self and not view.is_queued_for_deletion():
		view.release_to_pool()
		_pool.append(view)
		return
	view.collision_layer = 0
	view.collision_mask = 0
	view.hide()
	view.queue_free()


func pooled_view_count() -> int:
	return _pool.size()


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
