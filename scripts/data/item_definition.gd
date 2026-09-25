class_name ItemDefinition
extends Resource

enum Kind { WASTE, PROP, VALUABLE }
enum WasteCategory { PMD, ORGANIC, GENERAL, GLASS, NONE }
enum CollisionProfile { SMALL, LARGE, FLAT, FLOATING }
enum FloatMode { FLOAT, SINK, NEUTRAL }

@export var definition_id: StringName
@export var display_name := ""
@export var kind: Kind = Kind.WASTE
@export var waste_category: WasteCategory = WasteCategory.NONE
@export var material_tags: Array[StringName] = []
@export var sorting_family: StringName
@export_file("*.tscn") var visual_scene_path := ""
@export var collision_profile: CollisionProfile = CollisionProfile.SMALL
@export_range(1, 2) var hand_cost := 1
@export var float_mode: FloatMode = FloatMode.NEUTRAL
@export var required_tool: StringName
@export var base_sale_value := 0
@export var eligible_spawn_tags: Array[StringName] = []
@export_range(1, 100) var spawn_weight := 1
@export var dirt_patch_anchors: Array[Vector3] = []
## Share of resting items of this type that lie on their side (bottles, cans, cups); presentation only.
@export_range(0.0, 1.0, 0.05) var lying_chance := 0.0

# Loaded visuals stay referenced here. A PackedScene nothing holds is freed, and the next load()
# parses the wrapper scene again: about 2 ms for every streamed item view.
static var _visual_scenes: Dictionary = {}


## The item's visual scene, loaded once per path; null when it cannot be loaded.
func visual_scene() -> PackedScene:
	if not _visual_scenes.has(visual_scene_path):
		_visual_scenes[visual_scene_path] = load(visual_scene_path) as PackedScene if not visual_scene_path.is_empty() else null
	return _visual_scenes[visual_scene_path] as PackedScene


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if definition_id.is_empty():
		errors.append("definition_id is empty")
	if display_name.is_empty():
		errors.append("display_name is empty for %s" % definition_id)
	if hand_cost < 1 or hand_cost > 2:
		errors.append("hand_cost must be 1 or 2 for %s" % definition_id)
	if kind == Kind.WASTE and waste_category == WasteCategory.NONE:
		errors.append("waste category is missing for %s" % definition_id)
	if kind != Kind.WASTE and waste_category != WasteCategory.NONE:
		errors.append("non-waste definition has a waste category: %s" % definition_id)
	if base_sale_value < 0:
		errors.append("base_sale_value is negative for %s" % definition_id)
	if spawn_weight < 1:
		errors.append("spawn_weight must be positive for %s" % definition_id)
	if dirt_patch_anchors.size() > 3:
		errors.append("at most three dirt anchors are supported for %s" % definition_id)
	return errors
