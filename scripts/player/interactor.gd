class_name PlayerInteractor
extends Node

signal target_changed(result: Dictionary)
signal primary_requested(result: Dictionary)
signal interact_requested(result: Dictionary)
signal throw_requested
signal action_blocked(reason: String)

const TARGET_MASK := 1 | 4 | 8 | 16 | 64
const ITEM_MASK := 4
const TINY_TOLERANCE := 0.22

@export var camera: Camera3D
@export_range(1.0, 6.0, 0.1) var reach := 2.5

var session: RunSession
var current_target: Dictionary = {}
var _highlighted_view: WorldItem
var _highlighted_dirt: DirtVisual


func configure(run_session: RunSession) -> void:
	session = run_session


func binding_text(action: StringName) -> String:
	var player := get_parent() as BeachPlayer
	return player.settings_store.binding_text(action) if player != null and player.settings_store != null else str(action)


func update_target() -> Dictionary:
	var result := scan()
	_set_target(result)
	return result


func scan() -> Dictionary:
	if camera == null or not camera.is_inside_tree() or session == null:
		return {}
	var origin := camera.global_position
	var direction := -camera.global_basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * reach, TARGET_MASK, _excluded_rids())
	query.collide_with_areas = true
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var direct_result := _result_for_collider(hit.collider, hit.position, origin.distance_to(hit.position))
		if not direct_result.is_empty():
			return direct_result
	return _near_tiny_result(origin, direction)


func request_primary() -> void:
	if current_target.is_empty():
		return
	var actions := current_target.get("actions", PackedStringArray()) as PackedStringArray
	var has_primary := actions.has("collect") or actions.has("hold") or actions.has("hold_bag") or actions.has("place") or actions.has("clean")
	if not has_primary:
		action_blocked.emit(str(current_target.get("reason", "Unavailable")))
		return
	primary_requested.emit(current_target.duplicate())


func request_interact() -> void:
	if not current_target.is_empty():
		interact_requested.emit(current_target.duplicate())


func request_throw() -> void:
	throw_requested.emit()


func clear_target() -> void:
	_set_target({})


func _near_tiny_result(origin: Vector3, direction: Vector3) -> Dictionary:
	var shape := CapsuleShape3D.new()
	shape.radius = TINY_TOLERANCE
	shape.height = reach
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = shape
	parameters.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction)), origin + direction * reach * 0.5)
	parameters.collision_mask = ITEM_MASK
	parameters.exclude = _excluded_rids()
	var candidates: Array[Dictionary] = []
	for hit in camera.get_world_3d().direct_space_state.intersect_shape(parameters, 32):
		var view := hit.collider as WorldItem
		if view == null or view.definition.collision_profile != ItemDefinition.CollisionProfile.SMALL:
			continue
		var offset := view.global_position - origin
		var along := offset.dot(direction)
		var perpendicular := (offset - direction * along).length()
		if along <= 0.0 or along > reach or perpendicular > TINY_TOLERANCE:
			continue
		var line_query := PhysicsRayQueryParameters3D.create(origin, view.global_position + Vector3.UP * 0.05, TARGET_MASK, _excluded_rids())
		var line_hit := camera.get_world_3d().direct_space_state.intersect_ray(line_query)
		if line_hit.is_empty() or line_hit.collider != view:
			continue
		candidates.append({"view": view, "point": line_hit.position, "distance": origin.distance_to(line_hit.position)})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.view.item_id) < str(b.view.item_id) if is_equal_approx(float(a.distance), float(b.distance)) else float(a.distance) < float(b.distance)
	)
	var first := candidates[0]
	return _result_for_collider(first.view, first.point, first.distance)


func _result_for_collider(collider: Object, hit_point: Vector3, distance: float) -> Dictionary:
	if collider is DirtVisual:
		var dirt := collider as DirtVisual
		if not session.state.items.has(dirt.item_id):
			return {}
		var dirt_record := session.state.items[dirt.item_id] as ItemRecord
		if dirt_record.location != ItemRecord.Location.WORLD or dirt.patch_id not in dirt_record.dirty_patches_remaining:
			return {}
		var dirt_definition := session.definitions.get(dirt_record.definition_id) as ItemDefinition
		var dirt_actions := PackedStringArray(["carry_dirty"])
		var dirt_reason := "Needs cloth · %s: Carry" % binding_text(&"interact")
		if _active_tool() == &"cloth":
			dirt_actions.insert(0, "clean")
			dirt_reason = ""
		return {
			"actions": dirt_actions,
			"collider": dirt,
			"display_name": "%s stain" % dirt_definition.display_name,
			"distance": distance,
			"hit_point": hit_point,
			"id": dirt.item_id,
			"kind": "dirt_patch",
			"patch_id": dirt.patch_id,
			"reason": dirt_reason,
		}
	if collider is CollisionObject3D and collider.has_meta(&"placement_slot_id") and session.placement_service != null:
		return session.placement_service.target_result(StringName(str(collider.get_meta(&"placement_slot_id"))), collider, hit_point, distance)
	if collider is DisposalBag:
		var bag := collider as DisposalBag
		var bag_record := session.state.bag_records.get(bag.bag_id, {}) as Dictionary
		if bag_record.is_empty() or str(bag_record.location) not in ["RACK", "WORLD", "CONTAINER"]:
			return {}
		return {
			"actions": PackedStringArray(["hold_bag"]),
			"collider": bag,
			"display_name": "%s disposal bag" % str(bag_record.category).to_upper(),
			"distance": distance,
			"hit_point": hit_point,
			"id": bag.bag_id,
			"kind": "disposal_bag",
			"reason": "%d sealed items · 1 hand" % (bag_record.item_ids as Array).size(),
		}
	if collider is WorldItem:
		var view := collider as WorldItem
		if view.record != null and view.record.location == ItemRecord.Location.SLOTTED and session.placement_service != null:
			return session.placement_service.target_result(view.record.slot_id, view, hit_point, distance)
		if view.record == null or view.record.location != ItemRecord.Location.WORLD:
			return {}
		var actions := PackedStringArray()
		var reason := ""
		if not view.definition.required_tool.is_empty() and _active_tool() != view.definition.required_tool:
			reason = "Needs %s" % str(view.definition.required_tool).capitalize()
		elif view.definition.kind == ItemDefinition.Kind.WASTE or view.definition.kind == ItemDefinition.Kind.VALUABLE:
			if _bag_is_full():
				reason = "Bag full"
			else:
				actions.append("collect")
		elif view.definition.kind == ItemDefinition.Kind.PROP:
			if not view.record.dirty_patches_remaining.is_empty():
				actions.append("carry_dirty")
				reason = "Aim at a stain to clean · %s: Carry" % binding_text(&"interact") if _active_tool() == &"cloth" else "Needs cloth · %s: Carry" % binding_text(&"interact")
			else:
				actions.append("hold")
		return {
			"actions": actions,
			"collider": view,
			"display_name": view.definition.display_name,
			"distance": distance,
			"hit_point": hit_point,
			"id": view.item_id,
			"kind": "item",
			"reason": reason,
		}
	if collider is Node and collider.has_meta(&"target_id"):
		return {
			"actions": collider.get_meta(&"interaction_actions", PackedStringArray(["interact"])),
			"collider": collider,
			"display_name": str(collider.get_meta(&"display_name", "Interact")),
			"distance": distance,
			"hit_point": hit_point,
			"id": StringName(str(collider.get_meta(&"target_id"))),
			"kind": "station",
			"reason": str(collider.get_meta(&"interaction_reason", "")),
		}
	return {}


func _set_target(result: Dictionary) -> void:
	var next_view := result.get("collider") as WorldItem if result.get("collider") is WorldItem else null
	var next_dirt := result.get("collider") as DirtVisual if result.get("collider") is DirtVisual else null
	if _highlighted_view != next_view:
		if is_instance_valid(_highlighted_view):
			_highlighted_view.set_highlighted(false)
		_highlighted_view = next_view
		if is_instance_valid(_highlighted_view):
			_highlighted_view.set_highlighted(true)
	if _highlighted_dirt != next_dirt:
		if is_instance_valid(_highlighted_dirt):
			_highlighted_dirt.set_highlighted(false)
		_highlighted_dirt = next_dirt
		if is_instance_valid(_highlighted_dirt):
			_highlighted_dirt.set_highlighted(true)
	var changed := str(current_target.get("id", "")) != str(result.get("id", "")) or str(current_target.get("reason", "")) != str(result.get("reason", ""))
	if not changed and current_target.has("hit_point") and result.has("hit_point"):
		changed = (current_target.hit_point as Vector3).distance_to(result.hit_point) > 0.02
	current_target = result
	if changed:
		target_changed.emit(current_target.duplicate())


func _bag_is_full() -> bool:
	if not session.state.players.has(&"local"):
		return true
	var player := session.state.players[&"local"] as Dictionary
	return (player.trash_bag as Array).size() + (player.valuable_bag as Array).size() >= int(player.bag_capacity)


func _active_tool() -> StringName:
	if not session.state.players.has(&"local"):
		return StringName()
	var player := session.state.players[&"local"] as Dictionary
	var equipped := player[&"equipped_handheld_ids"] as Array[StringName]
	var active_slot := int(player.get("active_slot", 0))
	return equipped[active_slot] if active_slot >= 0 and active_slot < equipped.size() else StringName()


func _excluded_rids() -> Array[RID]:
	var result: Array[RID] = []
	var owner := get_parent() as CollisionObject3D
	if owner != null:
		result.append(owner.get_rid())
	return result
