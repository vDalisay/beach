class_name PlacementService
extends Node3D

signal feedback_requested(message: String)
signal group_completed(payload: Dictionary)

const SLOT_SCENE := preload("res://scenes/items/placement_slot.tscn")
const WORLD_ITEM_SCENE := preload("res://scenes/items/world_item.tscn")
const GHOST_SHADER := preload("res://shaders/placement_ghost.gdshader")
const PLAYER_ID := &"local"
const CLEARANCE_MASK := 1 | 4 | 8
const FEEL := preload("res://data/feel/feel_tuning.tres")

var session: RunSession
var world_root: Node3D
var player: BeachPlayer
var carry: PlayerCarry
var slots: Dictionary = {}
var pools: Dictionary = {}
var slotted_views: Dictionary = {}
var validation_errors: PackedStringArray = []
## Presentation pools for landings (created with a player).
var sparkles: ParticlePool
var dust: ParticlePool
var _preview_slot_id: StringName
var _group_sweep_serials: Dictionary = {}
var _pending_group_sweeps: Dictionary = {}
var _group_rewards: Dictionary = {}
# The one live placement ghost: it glides between slots and fades when the aim leaves.
var _ghost_visual: Node3D
var _ghost_item_id: StringName
var _ghost_blob: MeshInstance3D


func configure(run_session: RunSession, beach_root: Node3D, player_body: BeachPlayer = null) -> void:
	session = run_session
	world_root = beach_root
	player = player_body
	carry = player.carry if player != null else null
	session.placement_service = self
	_register_authored_pools()
	_rebuild_slotted_views()
	session.group_completed.connect(_on_group_completed)
	if player != null:
		if not player.interactor.primary_requested.is_connected(_on_primary_requested):
			player.interactor.primary_requested.connect(_on_primary_requested)
			player.interactor.target_changed.connect(_on_target_changed)
		if sparkles == null:
			sparkles = ParticlePool.create(ParticlePool.Kind.SPARKLE, 128, true)
			add_child(sparkles)
			dust = ParticlePool.create(ParticlePool.Kind.DUST, 32, true)
			dust.tint = FEEL.dust_color
			add_child(dust)


func preview_slot(player_id: StringName, slot_id: StringName) -> ActionResult:
	var item_id := _selected_held_item(player_id)
	var result := _validate_placement(player_id, item_id, slot_id, ItemRecord.Location.HELD, true)
	if result.ok:
		_show_ghost(slot_id, item_id)
	else:
		clear_preview()
	return result


func try_place(player_id: StringName, slot_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_place.bind(player_id, slot_id))
	var item_id := _selected_held_item(player_id)
	var validation := _validate_placement(player_id, item_id, slot_id, ItemRecord.Location.HELD, true)
	if not validation.ok:
		return validation
	var player_record := session.state.players[player_id] as Dictionary
	var held := player_record[&"held_objects"] as Array[Dictionary]
	var selected := int(player_record.get("selected_held_index", -1))
	var source_transform := _held_source_transform(item_id)
	var arm := &"both" if _definition_for_item(item_id).hand_cost == 2 else (&"left" if selected == 0 else &"right")
	held.remove_at(selected)
	player_record[&"held_objects"] = held
	player_record[&"selected_held_index"] = mini(selected, held.size() - 1) if not held.is_empty() else -1
	_commit_to_slot(item_id, slot_id)
	clear_preview()
	session.finalize_action(PackedStringArray([str(item_id)]), PackedStringArray([str(player_id)]))
	if player != null:
		player.play_cue(&"place", {"arm": arm})
	if carry != null:
		# A pickup still flying into the hand ends now; the prop leaves from the hand instead.
		carry.cancel_presentation(item_id)
	_animate_to_slot(item_id, slot_id, source_transform)
	if carry != null:
		carry.refresh_hand_visuals()
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {
		"item_id": str(item_id),
		"slot_id": str(slot_id),
		"pool_id": str((slots[slot_id] as Dictionary).pool_id),
	})


func try_capture(item_id: StringName, slot_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_capture.bind(item_id, slot_id))
	var validation := _validate_placement(&"", item_id, slot_id, ItemRecord.Location.WORLD, false)
	if not validation.ok:
		return validation
	var view := session.item_view_manager.view_for(item_id) if session.item_view_manager != null else null
	if view == null or view.freeze or view.sleeping or not _capture_entry_is_valid(view, slot_id):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Prop has not entered the slot opening")
	var source_transform := view.global_transform
	_commit_to_slot(item_id, slot_id)
	session.finalize_action(PackedStringArray([str(item_id)]))
	var presentation := session.item_view_manager.take_view_for_presentation(item_id)
	_animate_to_slot(item_id, slot_id, source_transform, presentation)
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {
		"item_id": str(item_id),
		"slot_id": str(slot_id),
		"source": "physical_capture",
	})


func try_remove(player_id: StringName, slot_id: StringName, target_context: Dictionary = {}) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_remove.bind(player_id, slot_id, target_context))
	if not slots.has(slot_id) or not session.state.players.has(player_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing player or placement slot")
	var item_id := occupant_for(slot_id)
	if item_id.is_empty() or not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Placement slot is empty")
	var target_error := _validate_target_context(item_id, target_context)
	if target_error != null:
		return target_error
	var player_record := session.state.players[player_id] as Dictionary
	var definition := _definition_for_item(item_id)
	if _held_hand_cost(player_record) + definition.hand_cost > int(player_record.get("hand_capacity", 2)):
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Player %s hands are full" % player_id)
	var held := player_record[&"held_objects"] as Array[Dictionary]
	held.append({"kind": "item", "id": item_id})
	player_record[&"held_objects"] = held
	player_record[&"selected_held_index"] = held.size() - 1
	var record := session.state.items[item_id] as ItemRecord
	var slotted_root := slotted_visual_root(item_id)
	var from := slotted_root.global_transform if slotted_root != null else slot_transform(slot_id)
	_release_slot(slot_id)
	record.location = ItemRecord.Location.HELD
	record.holder_id = player_id
	record.slot_id = &""
	record.container_id = &""
	_remove_slotted_view(item_id)
	clear_preview()
	session.finalize_action(PackedStringArray([str(item_id)]), PackedStringArray([str(player_id)]))
	_wobble_neighbors(slot_id, 0.6)
	if carry != null:
		# Presentation only: a copy lifts off the slot and travels into the hands.
		var large := definition.hand_cost == 2
		carry.present_visual(item_id, _create_visual(definition), from, carry.hand_rig.large_prop_socket if large else carry.next_small_socket(), 0.4 if large else 0.35)
		if player != null:
			player.play_cue(&"hold", {"large": large})
		carry.refresh_hand_visuals()
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {
		"item_id": str(item_id),
		"source": "slot",
		"slot_id": str(slot_id),
	})


func target_result(slot_id: StringName, collider: CollisionObject3D, hit_point: Vector3, distance: float) -> Dictionary:
	if not slots.has(slot_id):
		return {}
	var occupant := occupant_for(slot_id)
	if not occupant.is_empty():
		clear_preview()
		var definition := _definition_for_item(occupant)
		var actions := PackedStringArray()
		var reason := ""
		var player_record := session.state.players.get(PLAYER_ID, {}) as Dictionary
		if definition == null:
			reason = "Missing item definition"
		elif _held_hand_cost(player_record) + definition.hand_cost > int(player_record.get("hand_capacity", 2)):
			reason = "Hands full"
		else:
			actions.append("hold")
		return {
			"actions": actions,
			"collider": collider,
			"display_name": definition.display_name if definition != null else str(occupant),
			"distance": distance,
			"hit_point": hit_point,
			"id": occupant,
			"kind": "item",
			"reason": reason,
			"slot_id": slot_id,
		}
	var preview := preview_slot(PLAYER_ID, slot_id)
	var selected := _selected_held_item(PLAYER_ID)
	var selected_definition := _definition_for_item(selected)
	return {
		"actions": PackedStringArray(["place"]) if preview.ok else PackedStringArray(),
		"collider": collider,
		"display_name": "Place %s" % selected_definition.display_name if selected_definition != null else "Placement slot",
		"distance": distance,
		"hit_point": hit_point,
		"id": slot_id,
		"kind": "slot",
		"reason": preview.message,
		"slot_id": slot_id,
	}


## Hides the placement ghost. `fade` (the aim left the slot) lets it dissolve briefly;
## placement, removal and occupied slots clear it at once.
func clear_preview(fade := false) -> void:
	if _preview_slot_id.is_empty() or not slots.has(_preview_slot_id):
		_preview_slot_id = &""
		if is_instance_valid(_ghost_visual):
			_ghost_visual.queue_free()
		_ghost_visual = null
		_ghost_item_id = &""
		_hide_blob(false)
		return
	var ghost := ((slots[_preview_slot_id] as Dictionary).area as Area3D).get_node("GhostRoot") as Node3D
	_preview_slot_id = &""
	if fade and is_instance_valid(_ghost_visual) and _ghost_visual.has_meta(&"ghost_material") and not _reduced_motion():
		var fading := _ghost_visual
		var material := fading.get_meta(&"ghost_material") as ShaderMaterial
		# A glide in flight would keep steering the transform in the new parent's space.
		FeelMotion.replace(fading, &"glide", null)
		fading.reparent(self, true)
		ghost.hide()
		var t := FeelMotion.replace(fading, &"appear", FeelMotion.tween(fading))
		t.tween_method(func(value: float) -> void: material.set_shader_parameter("appear", value), float(material.get_shader_parameter("appear")), 0.0, 0.06)
		t.tween_callback(fading.queue_free)
		_hide_blob(true)
	else:
		ghost.hide()
		for child in ghost.get_children():
			child.queue_free()
		_hide_blob(false)
	_ghost_visual = null
	_ghost_item_id = &""


func occupant_for(slot_id: StringName) -> StringName:
	if not slots.has(slot_id):
		return StringName()
	var pool_id := StringName(str((slots[slot_id] as Dictionary).pool_id))
	var pool_record := session.state.container_records.get(pool_id, {}) as Dictionary
	return StringName(str((pool_record.get("occupants", {}) as Dictionary).get(slot_id, "")))


func slot_transform(slot_id: StringName) -> Transform3D:
	return (slots[slot_id] as Dictionary).transform as Transform3D if slots.has(slot_id) else Transform3D.IDENTITY


## Visual root of a slotted prop's view (hover, landing and shine target), or null.
func slotted_visual_root(item_id: StringName) -> Node3D:
	var view: Variant = slotted_views.get(item_id)
	if view == null or not is_instance_valid(view):
		return null
	return (view as Node3D).get_node_or_null("VisualRoot") as Node3D


func _register_authored_pools() -> void:
	var authored: Array[PlacementSlot] = []
	_collect_pools(world_root, authored)
	authored.sort_custom(func(a: PlacementSlot, b: PlacementSlot) -> bool: return str(a.pool_id) < str(b.pool_id))
	var shared_capacity := -1
	var shared_families := PackedStringArray()
	for pool in authored:
		if pools.has(pool.pool_id):
			validation_errors.append("Duplicate placement pool: %s" % pool.pool_id)
			continue
		pools[pool.pool_id] = pool
		if pool.accepted_families.size() > 1:
			if shared_capacity < 0:
				shared_capacity = pool.capacity
				shared_families = pool.accepted_families
			elif pool.capacity != shared_capacity or pool.accepted_families != shared_families:
				validation_errors.append("Shared shelf pools must use uniform capacity and families")
		_ensure_pool_record(pool)
		for index in range(pool.capacity):
			_register_slot(pool, index)
	_reconcile_slotted_records()


func _collect_pools(node: Node, result: Array[PlacementSlot]) -> void:
	if node is PlacementSlot:
		result.append(node as PlacementSlot)
	for child in node.get_children():
		_collect_pools(child, result)


func _ensure_pool_record(pool: PlacementSlot) -> void:
	if not session.state.container_records.has(pool.pool_id):
		session.state.container_records[pool.pool_id] = {
			"kind": "placement_pool",
			"accepted_families": Array(pool.accepted_families),
			"capacity": pool.capacity,
			"claim": StringName(),
			"occupants": {},
		}
		return
	var record := session.state.container_records[pool.pool_id] as Dictionary
	record["kind"] = "placement_pool"
	record["accepted_families"] = Array(pool.accepted_families)
	record["capacity"] = pool.capacity
	if not record.has("claim"):
		record["claim"] = StringName()
	if not record.has("occupants"):
		record["occupants"] = {}


func _register_slot(pool: PlacementSlot, index: int) -> void:
	var slot_id := pool.derived_slot_id(index)
	if slots.has(slot_id):
		validation_errors.append("Duplicate placement slot: %s" % slot_id)
		return
	var area := SLOT_SCENE.instantiate() as Area3D
	area.name = "Slot_%03d" % index
	pool.add_child(area)
	area.transform = pool.local_slot_transform(index)
	area.set_meta(&"placement_slot_id", slot_id)
	area.set_meta(&"target_id", slot_id)
	area.set_meta(&"display_name", "Placement slot")
	var collision := area.get_node("CaptureShape") as CollisionShape3D
	var shape := collision.shape.duplicate() as BoxShape3D
	shape.size = pool.capture_size()
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	area.body_entered.connect(_on_slot_body_entered.bind(slot_id))
	slots[slot_id] = {
		"area": area,
		"index": index,
		"pool_id": pool.pool_id,
		"transform": pool.global_transform * pool.local_slot_transform(index),
	}


func _reconcile_slotted_records() -> void:
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if record.location != ItemRecord.Location.SLOTTED or not slots.has(record.slot_id):
			continue
		var pool_id := StringName(str((slots[record.slot_id] as Dictionary).pool_id))
		var pool_record := session.state.container_records[pool_id] as Dictionary
		var occupants := pool_record["occupants"] as Dictionary
		if not occupants.has(record.slot_id):
			occupants[record.slot_id] = record.item_id
		if StringName(str(pool_record.get("claim", ""))).is_empty():
			pool_record["claim"] = _definition_for_item(record.item_id).sorting_family


func _validate_placement(player_id: StringName, item_id: StringName, slot_id: StringName, source: ItemRecord.Location, require_range: bool) -> ActionResult:
	if item_id.is_empty():
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Hold a prop to place")
	if not slots.has(slot_id) or not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing item or placement slot")
	var record := session.state.items[item_id] as ItemRecord
	var definition := _definition_for_item(item_id)
	if definition == null or definition.kind != ItemDefinition.Kind.PROP:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Only reusable props use placement slots")
	if record.location != source:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "%s is not available for placement" % definition.display_name)
	if source == ItemRecord.Location.HELD and record.holder_id != player_id:
		return ActionResult.rejected(ActionResult.Reason.INVALID_OWNER, "%s is held by another player" % definition.display_name)
	if not record.dirty_patches_remaining.is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Needs cloth before placement")
	if not occupant_for(slot_id).is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Placement slot is occupied")
	var descriptor := slots[slot_id] as Dictionary
	var pool_id := StringName(str(descriptor.pool_id))
	var pool_record := session.state.container_records[pool_id] as Dictionary
	var accepted := pool_record["accepted_families"] as Array
	if definition.sorting_family not in accepted:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "This slot does not accept %s" % definition.sorting_family)
	var claim := StringName(str(pool_record.get("claim", "")))
	if not claim.is_empty() and claim != definition.sorting_family:
		return ActionResult.rejected(ActionResult.Reason.INVALID_CATEGORY, "Shelf is reserved for %s" % str(claim).replace("_", " "))
	if claim.is_empty() and accepted.size() > 1 and not _shared_claim_is_safe(pool_id, definition.sorting_family, item_id):
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Use an existing %s section with room" % str(definition.sorting_family).replace("_", " "))
	if require_range and (player == null or player.global_position.distance_to((descriptor.transform as Transform3D).origin) > player.interactor.reach):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Placement slot is out of reach")
	if not _slot_clear_for(item_id, slot_id, source == ItemRecord.Location.WORLD):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Placement slot is blocked")
	return ActionResult.accepted(PackedStringArray(), {
		"item_id": str(item_id),
		"slot_id": str(slot_id),
		"transform": descriptor.transform,
	})


func _shared_claim_is_safe(candidate_pool_id: StringName, family: StringName, placing_item_id: StringName) -> bool:
	var shared_pools: Array[StringName] = []
	var families: Array[StringName] = []
	var section_capacity := 0
	for pool_key in pools:
		var pool := pools[pool_key] as PlacementSlot
		if pool.accepted_families.size() <= 1:
			continue
		shared_pools.append(StringName(pool_key))
		section_capacity = pool.capacity
		for accepted_family in pool.accepted_families:
			var accepted_name := StringName(accepted_family)
			if accepted_name not in families:
				families.append(accepted_name)
	var unclaimed := 0
	var free_by_family: Dictionary = {}
	for pool_id in shared_pools:
		var pool_record := session.state.container_records[pool_id] as Dictionary
		var claim := StringName(str(pool_record.get("claim", "")))
		var occupant_count := (pool_record["occupants"] as Dictionary).size()
		if pool_id == candidate_pool_id and claim.is_empty():
			claim = family
			occupant_count += 1
		if claim.is_empty():
			unclaimed += 1
		else:
			free_by_family[claim] = int(free_by_family.get(claim, 0)) + int(pool_record.capacity) - occupant_count
	var needed_sections := 0
	for family_id in families:
		var remaining := 0
		for item_value in session.state.items.values():
			var record := item_value as ItemRecord
			var definition := _definition_for_item(record.item_id)
			if record.required and definition != null and definition.sorting_family == family_id and record.location != ItemRecord.Location.SLOTTED:
				remaining += 1
		if family_id == family and (session.state.items[placing_item_id] as ItemRecord).location != ItemRecord.Location.SLOTTED:
			remaining -= 1
		var deficit := maxi(0, remaining - int(free_by_family.get(family_id, 0)))
		needed_sections += ceili(float(deficit) / float(section_capacity)) if deficit > 0 else 0
	return needed_sections <= unclaimed


func _slot_clear_for(item_id: StringName, slot_id: StringName, exclude_world_item: bool) -> bool:
	var definition := _definition_for_item(item_id)
	var size := WorldItem.profile_size(definition.collision_profile)
	var descriptor := slots[slot_id] as Dictionary
	var destination := descriptor.transform as Transform3D
	var offset := _upright_offset(destination.basis, size)
	var shape := BoxShape3D.new()
	shape.size = size * 0.92
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(destination.basis, destination.origin + Vector3.UP * offset + destination.basis * Vector3(0, size.y * 0.5, 0))
	query.collision_mask = CLEARANCE_MASK
	if exclude_world_item and session.item_view_manager != null:
		var view := session.item_view_manager.view_for(item_id)
		if view != null:
			query.exclude = [view.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _capture_entry_is_valid(view: WorldItem, slot_id: StringName) -> bool:
	var area := (slots[slot_id] as Dictionary).area as Area3D
	if view not in area.get_overlapping_bodies():
		return false
	var destination := slot_transform(slot_id).origin + Vector3.UP * 0.15
	var ray := PhysicsRayQueryParameters3D.create(view.global_position + Vector3.UP * 0.15, destination, 1 | 8, [view.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _commit_to_slot(item_id: StringName, slot_id: StringName) -> void:
	var record := session.state.items[item_id] as ItemRecord
	var definition := _definition_for_item(item_id)
	var descriptor := slots[slot_id] as Dictionary
	var pool_id := StringName(str(descriptor.pool_id))
	var pool_record := session.state.container_records[pool_id] as Dictionary
	var occupants := pool_record["occupants"] as Dictionary
	occupants[slot_id] = item_id
	pool_record["claim"] = definition.sorting_family
	record.location = ItemRecord.Location.SLOTTED
	record.holder_id = &""
	record.container_id = &""
	record.slot_id = slot_id
	record.last_world_transform = descriptor.transform
	record.linear_velocity = Vector3.ZERO
	record.angular_velocity = Vector3.ZERO
	record.sleeping = true


func _release_slot(slot_id: StringName) -> void:
	var pool_id := StringName(str((slots[slot_id] as Dictionary).pool_id))
	var pool_record := session.state.container_records[pool_id] as Dictionary
	var occupants := pool_record["occupants"] as Dictionary
	occupants.erase(slot_id)
	if occupants.is_empty():
		pool_record["claim"] = StringName()


func _show_ghost(slot_id: StringName, item_id: StringName) -> void:
	if _preview_slot_id == slot_id and _ghost_item_id == item_id and is_instance_valid(_ghost_visual):
		return
	var descriptor := slots[slot_id] as Dictionary
	var area := descriptor.area as Area3D
	var ghost_root := area.get_node("GhostRoot") as Node3D
	var definition := _definition_for_item(item_id)
	var offset := area.global_basis.inverse() * Vector3.UP * _upright_offset((descriptor.transform as Transform3D).basis, WorldItem.profile_size(definition.collision_profile))
	var reduced := _reduced_motion()
	if is_instance_valid(_ghost_visual) and _ghost_item_id == item_id and not reduced:
		# Glide: the same ghost slides magnetically to the next slot instead of popping.
		var previous_root := _ghost_visual.get_parent() as Node3D
		ghost_root.position = offset
		_ghost_visual.reparent(ghost_root, true)
		ghost_root.show()
		if previous_root != null and previous_root != ghost_root:
			previous_root.hide()
		var t := FeelMotion.replace(_ghost_visual, &"glide", FeelMotion.tween(_ghost_visual))
		t.tween_property(_ghost_visual, "transform", Transform3D.IDENTITY, FEEL.ghost_glide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_show_blob(slot_id, definition, true, reduced)
		_preview_slot_id = slot_id
		return
	clear_preview()
	ghost_root.position = offset
	_ghost_visual = _create_visual(definition)
	_ghost_visual.name = "Ghost"
	ghost_root.add_child(_ghost_visual)
	var material := ShaderMaterial.new()
	material.shader = GHOST_SHADER
	material.set_shader_parameter("ghost_color", FEEL.ghost_color)
	material.set_shader_parameter("fill_alpha", FEEL.ghost_fill_alpha)
	material.set_shader_parameter("rim_alpha", FEEL.ghost_rim_alpha)
	material.set_shader_parameter("scan_density", FEEL.ghost_scan_density)
	material.set_shader_parameter("breath_amount", 0.0 if reduced else FEEL.ghost_breath)
	if reduced:
		material.set_shader_parameter("scan_speed", 0.0)
	_apply_ghost_material(_ghost_visual, material)
	_ghost_visual.set_meta(&"ghost_material", material)
	ghost_root.show()
	_ghost_item_id = item_id
	if reduced:
		material.set_shader_parameter("appear", 1.0)
	else:
		# Materialize: a slight grow with the hologram fading in.
		material.set_shader_parameter("appear", 0.0)
		_ghost_visual.scale = Vector3.ONE * 0.92
		var t := FeelMotion.replace(_ghost_visual, &"appear", FeelMotion.tween(_ghost_visual))
		t.tween_property(_ghost_visual, "scale", Vector3.ONE, FEEL.ghost_appear_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_method(func(value: float) -> void: material.set_shader_parameter("appear", value), 0.0, 1.0, FEEL.ghost_appear_seconds)
	_show_blob(slot_id, definition, false, reduced)
	_preview_slot_id = slot_id


## Soft contact shadow under the ghost; skipped on moorings, where it would sit on water.
func _show_blob(slot_id: StringName, definition: ItemDefinition, glide: bool, reduced: bool) -> void:
	var pool := pools.get(StringName(str((slots[slot_id] as Dictionary).pool_id))) as PlacementSlot
	if pool == null or pool.layout == PlacementSlot.Layout.MOORING:
		_hide_blob(false)
		return
	if _ghost_blob == null:
		# A broad core with a soft edge, so the shadow still reads on bright sand.
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, 1))
		gradient.set_color(1, Color(0, 0, 0, 0))
		gradient.add_point(0.55, Color(0, 0, 0, 0.7))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.albedo_texture = texture
		material.albedo_color = Color(0, 0, 0, FEEL.ghost_blob_alpha)
		_ghost_blob = MeshInstance3D.new()
		_ghost_blob.name = "GhostBlob"
		_ghost_blob.mesh = PlaneMesh.new()
		_ghost_blob.material_override = material
		_ghost_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ghost_blob)
	(_ghost_blob.mesh as PlaneMesh).size = _slot_footprint(slot_id, definition) * 1.3
	var target := Transform3D(Basis(Vector3.UP, pool.global_rotation.y), _contact_point(slot_id) + Vector3.UP * 0.006)
	var material := _ghost_blob.material_override as StandardMaterial3D
	var was_visible := _ghost_blob.visible and material.albedo_color.a > 0.0
	_ghost_blob.show()
	if glide and was_visible and not reduced:
		var t := FeelMotion.replace(_ghost_blob, &"blob", FeelMotion.tween(_ghost_blob))
		t.tween_property(_ghost_blob, "global_transform", target, FEEL.ghost_glide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(material, "albedo_color:a", FEEL.ghost_blob_alpha, FEEL.ghost_glide_seconds)
		return
	_ghost_blob.global_transform = target
	if reduced:
		FeelMotion.replace(_ghost_blob, &"blob", null)
		material.albedo_color.a = FEEL.ghost_blob_alpha
		return
	material.albedo_color.a = 0.0
	var t := FeelMotion.replace(_ghost_blob, &"blob", FeelMotion.tween(_ghost_blob))
	t.tween_property(material, "albedo_color:a", FEEL.ghost_blob_alpha, FEEL.ghost_appear_seconds)


## Ground footprint (slot-yaw x/z, metres) of the prop as the slot holds it: an upright
## board stands on its edge.
func _slot_footprint(slot_id: StringName, definition: ItemDefinition) -> Vector2:
	var size := WorldItem.profile_size(definition.collision_profile)
	var pool := pools.get(StringName(str((slots[slot_id] as Dictionary).pool_id))) as PlacementSlot
	var held := pool.local_slot_transform(int((slots[slot_id] as Dictionary).index)).basis if pool != null else Basis.IDENTITY
	return Vector2(
		absf(held.x.x) * size.x + absf(held.y.x) * size.y + absf(held.z.x) * size.z,
		absf(held.x.z) * size.x + absf(held.y.z) * size.y + absf(held.z.z) * size.z
	)


## Where contact effects sit: the slot origin, lifted onto sand that rises above it. Shelf
## modules have no collision, so shelf slots keep their authored top.
func _contact_point(slot_id: StringName) -> Vector3:
	var origin := slot_transform(slot_id).origin
	if not is_inside_tree():
		return origin
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.4, origin - Vector3.UP * 0.2, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return Vector3(origin.x, maxf(origin.y, (hit.position as Vector3).y), origin.z) if not hit.is_empty() else origin


func _hide_blob(fade: bool) -> void:
	if _ghost_blob == null:
		return
	if not fade or not _ghost_blob.visible:
		FeelMotion.replace(_ghost_blob, &"blob", null)
		_ghost_blob.hide()
		return
	var material := _ghost_blob.material_override as StandardMaterial3D
	var t := FeelMotion.replace(_ghost_blob, &"blob", FeelMotion.tween(_ghost_blob))
	t.tween_property(material, "albedo_color:a", 0.0, 0.06)
	t.tween_callback(_ghost_blob.hide)


func _animate_to_slot(item_id: StringName, slot_id: StringName, source_transform: Transform3D, physical_view: WorldItem = null) -> void:
	var descriptor := slots[slot_id] as Dictionary
	var area := descriptor.area as Area3D
	var definition := _definition_for_item(item_id)
	var destination := Marker3D.new()
	area.add_child(destination)
	destination.position = area.global_basis.inverse() * Vector3.UP * _upright_offset((descriptor.transform as Transform3D).basis, WorldItem.profile_size(definition.collision_profile))
	var reduced := _reduced_motion()
	var capture := physical_view != null
	var finish := func() -> void:
		if is_instance_valid(destination):
			destination.queue_free()
		var record := session.state.items[item_id] as ItemRecord
		if record.location == ItemRecord.Location.SLOTTED and record.slot_id == slot_id:
			_ensure_slotted_view(item_id)
			_land_slotted_view(item_id, slot_id, capture)
			_try_start_pending_sweeps()
	var distance := source_transform.origin.distance_to(destination.global_position)
	var seconds := FEEL.capture_travel_seconds if capture else FeelMotion.travel_seconds(distance, FEEL.place_travel_base, FEEL.place_travel_per_meter, FEEL.place_travel_max)
	# Rise, then come straight down the last few centimetres onto the slot.
	var options := {} if reduced else {"arc": FEEL.place_arc_height * (0.5 if capture else 1.0), "drop": FEEL.place_drop_height}
	if capture:
		options["reduced"] = reduced
		physical_view.travel_to(destination, seconds, false, finish, options)
		return
	var presentation := _create_visual(definition)
	add_child(presentation)
	presentation.global_transform = source_transform
	# Leaves at the in-hand scale (PlayerCarry._scale_hand_visual) and grows on the way.
	presentation.scale = Vector3.ONE * (0.4 if definition.hand_cost == 2 else 0.35)
	options["shrink_to"] = 1.0
	options["shrink_from"] = 0.0
	FeelMotion.travel(presentation, self, global_transform.affine_inverse() * destination.global_transform, seconds, options, func() -> void:
		presentation.queue_free()
		finish.call()
	)


func _ensure_slotted_view(item_id: StringName) -> void:
	if slotted_views.has(item_id) or not session.state.items.has(item_id):
		return
	var record := session.state.items[item_id] as ItemRecord
	if record.location != ItemRecord.Location.SLOTTED or not slots.has(record.slot_id):
		return
	var definition := _definition_for_item(item_id)
	var descriptor := slots[record.slot_id] as Dictionary
	var area := descriptor.area as Area3D
	var body := StaticBody3D.new()
	body.name = "Placed_%s" % str(item_id).replace(":", "_")
	body.collision_layer = 4 | (8 if definition.collision_profile == ItemDefinition.CollisionProfile.LARGE else 0)
	body.collision_mask = 0
	body.set_meta(&"placement_slot_id", record.slot_id)
	area.add_child(body)
	var size := WorldItem.profile_size(definition.collision_profile)
	var offset_local := area.global_basis.inverse() * Vector3.UP * _upright_offset((descriptor.transform as Transform3D).basis, size)
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.position = offset_local
	body.add_child(visual_root)
	visual_root.add_child(_create_visual(definition))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = offset_local + Vector3(0, size.y * 0.5, 0)
	body.add_child(collision)
	slotted_views[item_id] = body


func _remove_slotted_view(item_id: StringName) -> void:
	if not slotted_views.has(item_id):
		return
	var view: Variant = slotted_views[item_id]
	slotted_views.erase(item_id)
	if is_instance_valid(view):
		if view is CollisionObject3D:
			(view as CollisionObject3D).collision_layer = 0
			(view as CollisionObject3D).collision_mask = 0
		(view as Node).queue_free()


## Landing: squash, rebound and settle, with a contact ring, dust, sparkles and a neighbour
## wobble. A physical capture gets a wider, brighter ring and twice the sparkles.
func _land_slotted_view(item_id: StringName, slot_id: StringName, capture: bool) -> void:
	var root := slotted_visual_root(item_id)
	if root == null:
		return
	var base := _contact_point(slot_id)
	var sparkle_count := FEEL.land_sparkles * (2 if capture else 1)
	if _reduced_motion():
		# R09's pulse is removed under reduced motion (P27); a few glints remain.
		root.scale = Vector3.ONE
		_land_sparkles(base, maxi(1, sparkle_count / 2))
		return
	FeelMotion.squash_land(root, FEEL.land_squash, FEEL.land_rebound, FEEL.land_seconds)
	# The ring clears the prop's own footprint, so a chair or cooler does not hide it.
	var reach := _slot_footprint(slot_id, _definition_for_item(item_id)).length() * 0.5
	FeelRing.spawn(self, base + Vector3.UP * 0.02, maxf(0.15, reach * 0.6), maxf(0.8 if capture else 0.55, reach + (0.45 if capture else 0.3)), 0.28, FEEL.shine_core_color if capture else FEEL.ghost_color, 0.05)
	_land_sparkles(base, sparkle_count)
	var pool := pools.get(StringName(str((slots[slot_id] as Dictionary).pool_id))) as PlacementSlot
	if dust != null and (pool == null or pool.layout != PlacementSlot.Layout.MOORING):
		dust.burst(base + Vector3.UP * 0.03, Vector3.UP, 5, 0.5, 0.4, Vector2(0.04, 0.07), 0.45)
	_wobble_neighbors(slot_id, 1.0)


func _land_sparkles(base: Vector3, count: int) -> void:
	var palette := FEEL.sparkle_colors
	if sparkles == null or palette.is_empty():
		return
	# Split across the palette so a landing glints in more than one colour.
	for index in palette.size():
		var share := count / palette.size() + (1 if index < count % palette.size() else 0)
		if share > 0:
			sparkles.burst(base + Vector3.UP * 0.1, Vector3.UP, share, 0.6, 0.5, Vector2(0.05, 0.08), 0.5, palette[index])


## Props sharing the shelf rock slightly, like books settling, fading with distance.
func _wobble_neighbors(slot_id: StringName, strength: float) -> void:
	if _reduced_motion() or not slots.has(slot_id):
		return
	var origin := slot_transform(slot_id).origin
	var pool_id := StringName(str((slots[slot_id] as Dictionary).pool_id))
	var occupants := (session.state.container_records[pool_id] as Dictionary).get("occupants", {}) as Dictionary
	for other_key in occupants:
		var other_slot := StringName(str(other_key))
		if other_slot == slot_id or not slots.has(other_slot):
			continue
		var root := slotted_visual_root(StringName(str(occupants[other_key])))
		var distance := origin.distance_to(slot_transform(other_slot).origin)
		if root == null or distance > FEEL.neighbor_wobble_radius:
			continue
		var angle := deg_to_rad(FEEL.neighbor_wobble_degrees) * strength * (1.0 - distance / FEEL.neighbor_wobble_radius)
		var t := FeelMotion.replace(root, &"wobble", FeelMotion.tween(root))
		t.tween_interval(distance * 0.04)
		t.tween_property(root, "rotation:z", angle, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(root, "rotation:z", -angle * 0.5, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(root, "rotation:z", 0.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_group_completed(payload: Dictionary) -> void:
	group_completed.emit(payload)
	var group_id := StringName(str(payload.get("group_id", "")))
	_group_rewards[group_id] = int(payload.get("reward", 0))
	_group_sweep_serials[group_id] = int(_group_sweep_serials.get(group_id, 0)) + 1
	_pending_group_sweeps[group_id] = int(_group_sweep_serials[group_id])
	call_deferred("_try_start_pending_sweeps")


func _try_start_pending_sweeps() -> void:
	for group_id in _pending_group_sweeps.keys():
		if not session.state.group_states.has(group_id) or not bool((session.state.group_states[group_id] as Dictionary).complete):
			_pending_group_sweeps.erase(group_id)
			continue
		var ready := true
		for item_id in session.progress_service.group_items.get(group_id, []):
			if not slotted_views.has(item_id):
				ready = false
				break
		if ready:
			var serial := int(_pending_group_sweeps[group_id])
			_pending_group_sweeps.erase(group_id)
			_show_group_sweep(group_id, serial)


## The set's "done" gleam: a floater rises (+$ on the first completion, "Tidy!" on replays)
## and a warm band sweeps across every prop in the set with sparkles popping as it passes.
func _show_group_sweep(group_id: StringName, serial: int) -> void:
	if not is_inside_tree() or int(_group_sweep_serials.get(group_id, 0)) != serial:
		return
	if not session.state.group_states.has(group_id) or not bool((session.state.group_states[group_id] as Dictionary).complete):
		return
	var meshes: Array[MeshInstance3D] = []
	var tops: Array[Vector3] = []
	for item_id in session.progress_service.group_items.get(group_id, []):
		var root := slotted_visual_root(item_id)
		if root == null:
			continue
		_collect_sweep_meshes(root, meshes)
		tops.append(root.global_position + Vector3.UP * WorldItem.profile_size(_definition_for_item(item_id).collision_profile).y)
	if tops.is_empty():
		return
	var reduced := _reduced_motion()
	var reward := int(_group_rewards.get(group_id, 0))
	var center := Vector3.ZERO
	var highest := -INF
	for top in tops:
		center += top
		highest = maxf(highest, top.y)
	center /= float(tops.size())
	FeelFloater.spawn(self, Vector3(center.x, highest + 0.35, center.z), "+$%d" % reward if reward > 0 else "Tidy!", FEEL.money_color if reward > 0 else FEEL.shine_core_color, reduced)
	if reduced:
		return
	var shine := FeelShine.play(self, meshes, FEEL.group_sweep_seconds)
	if shine.is_empty():
		return
	for top in tops:
		var along := clampf((top - (shine.origin as Vector3)).dot(shine.direction as Vector3) / float(shine.distance), 0.0, 1.0)
		get_tree().create_timer(along * FEEL.group_sweep_seconds).timeout.connect(func() -> void:
			if is_instance_valid(sparkles):
				sparkles.burst(top, Vector3.UP, FEEL.set_sparkles_per_item, 0.4, 0.3, Vector2(0.05, 0.09), 0.6)
		)


func _collect_sweep_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child.has_meta(HoverHighlight.MARK):
			continue
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			result.append(child as MeshInstance3D)
		_collect_sweep_meshes(child, result)


func _reduced_motion() -> bool:
	return player != null and player.settings_store != null and bool(player.settings_store.get_value(&"reduced_motion"))


func _rebuild_slotted_views() -> void:
	for item_value in session.state.items.values():
		var record := item_value as ItemRecord
		if record.location == ItemRecord.Location.SLOTTED:
			_ensure_slotted_view(record.item_id)


func _create_visual(definition: ItemDefinition) -> Node3D:
	var root := Node3D.new()
	var packed := definition.visual_scene()
	if packed != null and definition.visual_scene_path != "res://art/placeholders/missing_asset.tscn":
		root.add_child(packed.instantiate())
		return root
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	var size := WorldItem.profile_size(definition.collision_profile)
	box.size = size
	mesh.mesh = box
	mesh.position.y = size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("efad47")
	material.roughness = 0.78
	mesh.material_override = material
	root.add_child(mesh)
	return root


func _apply_ghost_material(node: Node, material: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_ghost_material(child, material)


func _upright_offset(basis: Basis, size: Vector3) -> float:
	var minimum_y := INF
	for x in [-size.x * 0.5, size.x * 0.5]:
		for y in [0.0, size.y]:
			for z in [-size.z * 0.5, size.z * 0.5]:
				minimum_y = minf(minimum_y, (basis * Vector3(x, y, z)).y)
	return -minimum_y + 0.015


func _selected_held_item(player_id: StringName) -> StringName:
	if not session.state.players.has(player_id):
		return StringName()
	var player_record := session.state.players[player_id] as Dictionary
	var held := player_record[&"held_objects"] as Array[Dictionary]
	var selected := int(player_record.get("selected_held_index", -1))
	if selected < 0 or selected >= held.size():
		return StringName()
	return StringName(str(held[selected].get("id", "")))


func _held_source_transform(item_id: StringName) -> Transform3D:
	if carry == null:
		return Transform3D.IDENTITY
	var definition := _definition_for_item(item_id)
	if definition.hand_cost == 2:
		return carry.hand_rig.presentation_transform(carry.hand_rig.large_prop_socket)
	var player_record := session.state.players[PLAYER_ID] as Dictionary
	return carry.hand_rig.presentation_transform(carry.hand_rig.left_prop_socket if int(player_record.get("selected_held_index", 0)) == 0 else carry.hand_rig.right_prop_socket)


func _held_hand_cost(player_record: Dictionary) -> int:
	var cost := 0
	for object_value in player_record.get("held_objects", []):
		var item_id := StringName(str((object_value as Dictionary).get("id", "")))
		var definition := _definition_for_item(item_id)
		if definition != null:
			cost += definition.hand_cost
	return cost


func _definition_for_item(item_id: StringName) -> ItemDefinition:
	if not session.state.items.has(item_id):
		return null
	return session.definitions.get((session.state.items[item_id] as ItemRecord).definition_id) as ItemDefinition


func _validate_target_context(item_id: StringName, context: Dictionary) -> ActionResult:
	if context.is_empty():
		return null
	if StringName(str(context.get("target_id", ""))) != item_id or not bool(context.get("visible", false)):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "%s is not the visible target" % item_id)
	if float(context.get("distance", INF)) > float(context.get("reach", 0.0)) + 0.01:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "%s is out of reach" % item_id)
	return null


func _on_slot_body_entered(body: Node3D, slot_id: StringName) -> void:
	var view := body as WorldItem
	if view == null or view.record == null or view.record.location != ItemRecord.Location.WORLD:
		return
	try_capture(view.item_id, slot_id)


func _on_primary_requested(target: Dictionary) -> void:
	if not (target.get("actions", PackedStringArray()) as PackedStringArray).has("place"):
		return
	var result := try_place(PLAYER_ID, StringName(str(target.get("slot_id", target.get("id", "")))))
	if not result.ok:
		feedback_requested.emit(result.message)
		if player != null:
			player.play_cue(&"rejected", {"reason": result.message})


func _on_target_changed(target: Dictionary) -> void:
	var actions := target.get("actions", PackedStringArray()) as PackedStringArray
	if not actions.has("place") or StringName(str(target.get("slot_id", ""))) != _preview_slot_id:
		# The aim left the slot: let the ghost dissolve rather than blink out.
		clear_preview(true)
