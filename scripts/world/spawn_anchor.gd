@tool
class_name SpawnAnchor
extends Marker3D

enum ClearanceClass {
	SMALL,
	MEDIUM,
	LARGE,
}

@export var anchor_id: StringName
@export var section_id: StringName
@export var tags: PackedStringArray
@export var clearance_class := ClearanceClass.SMALL
@export_range(0.1, 10.0, 0.1) var clearance_radius := 0.35


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if anchor_id.is_empty() or section_id.is_empty():
		warnings.append("Anchor and section IDs are required.")
	if tags.is_empty():
		warnings.append("At least one spawn tag is required.")
	return warnings
