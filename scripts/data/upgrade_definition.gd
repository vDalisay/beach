class_name UpgradeDefinition
extends Resource

enum Source { SHOP, BOOKLET }

@export var upgrade_id: StringName
@export var display_name := ""
@export var level := 1
@export var price := 0
@export var prerequisite: StringName
@export var source: Source = Source.SHOP
@export var affected_stat: StringName
@export var exact_value := 0.0
@export var secondary_stat: StringName
@export var secondary_value := 0.0
@export var effect_text := ""
@export var implemented := true


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if upgrade_id.is_empty():
		errors.append("upgrade_id is empty")
	if display_name.is_empty():
		errors.append("display_name is empty for %s" % upgrade_id)
	if level < 1:
		errors.append("level must be positive: %s" % upgrade_id)
	if price < 0:
		errors.append("price is negative: %s" % upgrade_id)
	if affected_stat.is_empty():
		errors.append("affected_stat is empty: %s" % upgrade_id)
	if not is_finite(exact_value):
		errors.append("exact_value is not finite: %s" % upgrade_id)
	return errors
