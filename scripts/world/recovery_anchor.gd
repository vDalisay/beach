@tool
class_name RecoveryAnchor
extends Marker3D

@export var anchor_id: StringName
@export var zone_id: StringName
@export_range(0.5, 8.0, 0.1) var clearance_radius := 1.5
@export var dry := true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if anchor_id.is_empty() or zone_id.is_empty():
		warnings.append("Recovery anchor and zone IDs are required.")
	if not dry:
		warnings.append("Safe player recovery anchors must be dry.")
	return warnings
