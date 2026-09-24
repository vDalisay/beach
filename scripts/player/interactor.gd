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
var _highlight_root: Node3D
var _highlight_root_style := -1
# Targeting runs every physics tick; its query objects are reused instead of allocated each time.
var _ray_query := PhysicsRayQueryParameters3D.new()
var _line_query := PhysicsRayQueryParameters3D.new()
var _tiny_shape := CapsuleShape3D.new()
var _tiny_query := PhysicsShapeQueryParameters3D.new()
var _excluded: Array[RID] = []


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
	_ray_query.from = origin
	_ray_query.to = origin + direction * reach
	_ray_query.collision_mask = TARGET_MASK
	_ray_query.exclude = _excluded_rids()
	_ray_query.collide_with_areas = true
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(_ray_query)
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
	_tiny_shape.radius = TINY_TOLERANCE
	_tiny_shape.height = reach
	_tiny_query.shape = _tiny_shape
	_tiny_query.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction)), origin + direction * reach * 0.5)
	_tiny_query.collision_mask = ITEM_MASK
	_tiny_query.exclude = _excluded_rids()
	var candidates: Array[Dictionary] = []
	for hit in camera.get_world_3d().direct_space_state.intersect_shape(_tiny_query, 32):
		var view := hit.collider as WorldItem
		if view == null or view.definition.collision_profile != ItemDefinition.CollisionProfile.SMALL:
			continue
		var offset := view.global_position - origin
		var along := offset.dot(direction)
		var perpendicular := (offset - direction * along).length()
		if along <= 0.0 or along > reach or perpendicular > TINY_TOLERANCE:
			continue
		_line_query.from = origin
		_line_query.to = view.global_position + Vector3.UP * 0.05
		_line_query.collision_mask = TARGET_MASK
		_line_query.exclude = _excluded_rids()
		var line_hit := camera.get_world_3d().direct_space_state.intersect_ray(_line_query)
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
		var required_tool := ItemStore.collection_tool_for(view.record, view.definition)
		if not required_tool.is_empty() and _active_tool() != required_tool:
			reason = "Needs %s" % str(required_tool).capitalize()
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
		var station_actions: PackedStringArray = collider.get_meta(&"interaction_actions", PackedStringArray(["interact"]))
		var station_reason := str(collider.get_meta(&"interaction_reason", ""))
		if station_actions.has("cut") and _active_tool() != &"knife":
			# Display text only: the actions and their routing stay unchanged.
			station_reason = "Needs Rescue knife"
		return {
			"actions": station_actions,
			"collider": collider,
			"display_name": str(collider.get_meta(&"display_name", "Interact")),
			"distance": distance,
			"hit_point": hit_point,
			"id": StringName(str(collider.get_meta(&"target_id"))),
			"kind": "station",
			"reason": station_reason,
			"verb": str(collider.get_meta(&"interaction_verb", "")),
		}
	return {}


## Hover style for a target result, shared by the outline, reticle and target label so the
## three cues always agree. -1 means no highlight.
func style_for(result: Dictionary) -> int:
	if result.is_empty():
		return -1
	var kind := str(result.get("kind", ""))
	var actions := result.get("actions", PackedStringArray()) as PackedStringArray
	if kind == "slot":
		return -1
	if kind == "dirt_patch":
		return HoverHighlight.Style.ACTION if actions.has("clean") else HoverHighlight.Style.BLOCKED
	if kind == "station":
		if actions.has("cut"):
			return HoverHighlight.Style.BLOCKED if _active_tool() != &"knife" else HoverHighlight.Style.ACTION
		return HoverHighlight.Style.SOFT
	for action in ["collect", "hold", "hold_bag", "place", "clean", "carry_dirty", "interact"]:
		if actions.has(action):
			return HoverHighlight.Style.ACTION
	return HoverHighlight.Style.BLOCKED


## Visual root for targets that do not own a hover (slotted props, bags, stations).
## WorldItem and DirtVisual targets return null; they keep their own lift and outline.
func _highlight_root_for(result: Dictionary) -> Node3D:
	var collider: Variant = result.get("collider")
	if collider == null or not is_instance_valid(collider) or collider is WorldItem or collider is DirtVisual:
		return null
	var kind := str(result.get("kind", ""))
	if kind == "item" and result.has("slot_id"):
		return session.placement_service.slotted_visual_root(StringName(str(result.id))) if session.placement_service != null else null
	if collider is DisposalBag:
		return collider as Node3D
	if kind == "station":
		var node := collider as Node
		if node.has_meta(&"highlight_root"):
			var root: Variant = node.get_meta(&"highlight_root")
			if root is Node3D and is_instance_valid(root):
				return root as Node3D
		if collider is Area3D and (collider as Node).find_children("*", "MeshInstance3D", true, false).is_empty():
			return null
		return collider as Node3D
	return null


func _set_target(result: Dictionary) -> void:
	var style := style_for(result)
	var player := get_parent() as BeachPlayer
	var reduced := FeelMotion.reduced(player.settings_store) if player != null else false
	var next_view := result.get("collider") as WorldItem if result.get("collider") is WorldItem else null
	var next_dirt := result.get("collider") as DirtVisual if result.get("collider") is DirtVisual else null
	if _highlighted_view != next_view:
		if is_instance_valid(_highlighted_view):
			_highlighted_view.set_highlighted(false)
		_highlighted_view = next_view
	if is_instance_valid(_highlighted_view):
		# Re-applies when the same target changes style, e.g. the bag fills while aiming.
		_highlighted_view.set_highlighted(true, maxi(style, 0), reduced)
	if _highlighted_dirt != next_dirt:
		if is_instance_valid(_highlighted_dirt):
			_highlighted_dirt.set_highlighted(false)
		_highlighted_dirt = next_dirt
	if is_instance_valid(_highlighted_dirt):
		_highlighted_dirt.set_highlighted(true, style == HoverHighlight.Style.ACTION, reduced)
	if not is_instance_valid(_highlight_root):
		_highlight_root = null
	var next_root := _highlight_root_for(result) if style >= 0 else null
	if next_root != _highlight_root or (next_root != null and style != _highlight_root_style):
		if is_instance_valid(_highlight_root) and _highlight_root != next_root:
			HoverHighlight.set_active(_highlight_root, false)
		_highlight_root = next_root
		_highlight_root_style = style if next_root != null else -1
		if is_instance_valid(_highlight_root):
			HoverHighlight.set_active(_highlight_root, true, style, reduced)
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
	# The player body's RID never changes, so the exclusion list is built once.
	if _excluded.is_empty():
		var owner := get_parent() as CollisionObject3D
		if owner != null:
			_excluded.append(owner.get_rid())
	return _excluded
