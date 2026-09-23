class_name RecoveryBounds
extends Node

const MINIMUM := Vector3(-85.0, -12.0, -55.0)
const MAXIMUM := Vector3(85.0, 35.0, 220.0)

var state: RunState
var definitions: Dictionary
var recovery_anchors: Dictionary


func configure(run_state: RunState, item_definitions: Dictionary, anchors: Dictionary) -> void:
	state = run_state
	definitions = item_definitions
	recovery_anchors = anchors


func is_outside(position: Vector3) -> bool:
	return position.x < MINIMUM.x or position.y < MINIMUM.y or position.z < MINIMUM.z or position.x > MAXIMUM.x or position.y > MAXIMUM.y or position.z > MAXIMUM.z


func recover_item(item_id: StringName) -> bool:
	if state == null or not state.items.has(item_id) or recovery_anchors.is_empty():
		return false
	var record := state.items[item_id] as ItemRecord
	if record.location != ItemRecord.Location.WORLD or not definitions.has(record.definition_id):
		return false
	var anchors: Array[Dictionary] = []
	for anchor_id in recovery_anchors:
		anchors.append({"id": str(anchor_id), "position": recovery_anchors[anchor_id] as Vector3})
	anchors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var distance_a := (a.position as Vector3).distance_squared_to(record.last_world_transform.origin)
		var distance_b := (b.position as Vector3).distance_squared_to(record.last_world_transform.origin)
		return str(a.id) < str(b.id) if is_equal_approx(distance_a, distance_b) else distance_a < distance_b
	)
	var radius := WorldItem.clearance_radius((definitions[record.definition_id] as ItemDefinition).collision_profile)
	for anchor in anchors:
		for offset in _candidate_offsets():
			var candidate := (anchor.position as Vector3) + offset
			if _clear_of_items(item_id, candidate, radius):
				record.last_world_transform = Transform3D(record.last_world_transform.basis, candidate)
				record.linear_velocity = Vector3.ZERO
				record.angular_velocity = Vector3.ZERO
				record.sleeping = true
				return true
	return false


func _clear_of_items(item_id: StringName, candidate: Vector3, radius: float) -> bool:
	for other_id in state.items:
		if other_id == item_id:
			continue
		var other := state.items[other_id] as ItemRecord
		if other.location != ItemRecord.Location.WORLD or not definitions.has(other.definition_id):
			continue
		var other_radius := WorldItem.clearance_radius((definitions[other.definition_id] as ItemDefinition).collision_profile)
		var delta := other.last_world_transform.origin - candidate
		if Vector2(delta.x, delta.z).length() < radius + other_radius + 0.2 and absf(delta.y) < 1.5:
			return false
	return true


func _candidate_offsets() -> Array[Vector3]:
	var result: Array[Vector3] = [Vector3.ZERO]
	for distance in [2.0, 4.0, 6.0]:
		for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(1, 0, -1).normalized(), Vector3(-1, 0, -1).normalized()]:
			result.append(direction * distance)
	return result
