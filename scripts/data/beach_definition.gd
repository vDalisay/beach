class_name BeachDefinition
extends Resource

@export var beach_id: StringName
@export var version := "1"
@export_file("*.tscn") var scene_path := ""
@export var ordered_zones: Array[StringName] = []
@export var ordered_sections: Array[StringName] = []
@export var zone_budgets: Dictionary = {}
@export var section_budgets: Dictionary = {}
@export var slot_inventories: Dictionary = {}
@export var spawn_anchor_resource: Resource
@export var recovery_anchors: Dictionary = {}
@export var restoration_recipes: Dictionary = {}
@export var starting_state: Dictionary = {}


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if beach_id.is_empty():
		errors.append("beach_id is empty")
	if version.is_empty():
		errors.append("beach version is empty: %s" % beach_id)
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		errors.append("beach scene is missing: %s" % scene_path)
	var seen_zones := {}
	for zone_id in ordered_zones:
		if zone_id.is_empty() or seen_zones.has(zone_id):
			errors.append("zone IDs must be nonempty and unique: %s" % zone_id)
		seen_zones[zone_id] = true
	var seen := {}
	var section_waste := 0
	var section_props := 0
	for section_id in ordered_sections:
		if section_id.is_empty() or seen.has(section_id):
			errors.append("section IDs must be nonempty and unique: %s" % section_id)
		seen[section_id] = true
		if not section_budgets.has(section_id):
			errors.append("section budget is missing: %s" % section_id)
			continue
		var budget := section_budgets[section_id] as Dictionary
		section_waste += int(budget.get("waste", -1))
		section_props += int(budget.get("props", -1))
	var zone_waste := 0
	var zone_props := 0
	for zone_id in ordered_zones:
		if not zone_budgets.has(zone_id):
			errors.append("zone budget is missing: %s" % zone_id)
			continue
		var budget := zone_budgets[zone_id] as Dictionary
		zone_waste += int(budget.get("waste", -1))
		zone_props += int(budget.get("props", -1))
	if section_waste != zone_waste or section_props != zone_props:
		errors.append("section totals do not match zone totals")
	return errors
