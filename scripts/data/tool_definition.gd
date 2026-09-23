class_name ToolDefinition
extends Resource

@export var tool_id: StringName
@export var display_name := ""
@export_file("*.tscn") var scene_path := ""
@export var handheld := true
@export var allowed_target_tags: Array[StringName] = []
@export var range := 2.5
@export var radius := 0.0
@export var use_interval := 0.0
@export var max_items_per_use := 1
@export var cone_degrees := 0.0
@export var shop_price := 0
@export var upgrade_prerequisite: StringName
@export var effect_text := ""
@export var implemented := false


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if tool_id.is_empty():
		errors.append("tool_id is empty")
	if display_name.is_empty():
		errors.append("display_name is empty for %s" % tool_id)
	if range < 0.0 or radius < 0.0 or use_interval < 0.0:
		errors.append("tool distances and intervals must be nonnegative: %s" % tool_id)
	if max_items_per_use < 1 or cone_degrees < 0.0 or cone_degrees > 180.0:
		errors.append("tool count or cone is invalid: %s" % tool_id)
	if shop_price < 0:
		errors.append("shop_price is negative: %s" % tool_id)
	return errors
