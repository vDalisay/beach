@tool
class_name BeachSection
extends Node3D

@export var section_id: StringName
@export var zone_id: StringName
@export var required_waste := 0
@export var required_props := 0
@export var restoration_visual_root: Node3D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if section_id.is_empty():
		warnings.append("Section ID is required.")
	if zone_id.is_empty():
		warnings.append("Zone ID is required.")
	if required_waste < 0 or required_props < 0:
		warnings.append("Objective budgets cannot be negative.")
	if restoration_visual_root == null:
		warnings.append("Assign a separate restoration visual root.")
	return warnings
