class_name RenderQuality
extends Node
## Applies the Graphics settings to the running beach: sun-shadow cascades and distance, hut
## light shadows, SSAO and glow, and the distance budgets that streamed items and small scenery
## read. MSAA, render scale, VSync and the frame cap are global and applied by SettingsStore.

# Indexed by the shadow_quality setting: off, low, medium, high, ultra. Ultra is the pre-pass look.
const SHADOW_ATLAS := [2048, 2048, 2048, 4096, 4096]
const SHADOW_DISTANCE := [0.0, 50.0, 80.0, 100.0, 150.0]
const SHADOW_FOUR_SPLITS := [false, false, false, true, true]
const SHADOW_FILTER := [
	RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW,
]
# Per-object sun-shadow ranges for streamed items (0 never casts).
const SMALL_ITEM_SHADOW := [0.0, 0.0, 10.0, 15.0, 25.0]
const LARGE_ITEM_SHADOW := [0.0, 20.0, 30.0, 45.0, 70.0]
# Hut interior lights keep their cube shadow within this distance (0 drops the shadow).
const LIGHT_SHADOW := [0.0, 0.0, 0.0, 15.0, 30.0]
const LIGHT_FADE_BEGIN := 40.0
const LIGHT_FADE_LENGTH := 8.0
# The authored four-split layout; two splits give the near cascade a quarter of the range.
const FOUR_SPLITS := Vector3(0.08, 0.22, 0.5)
const TWO_SPLIT := 0.25

## Budgets read by streamed views and scenery as they are created; the defaults are High.
static var small_item_shadow_distance := 15.0
static var large_item_shadow_distance := 45.0
static var detail_distance_scale := 1.0

var settings: SettingsStore
var beach: Node3D
var session: RunSession


func configure(settings_store: SettingsStore, beach_root: Node3D, run_session: RunSession) -> void:
	settings = settings_store
	beach = beach_root
	session = run_session
	apply_all()
	if settings != null and not settings.settings_changed.is_connected(_on_setting_changed):
		settings.settings_changed.connect(_on_setting_changed)


func apply_all() -> void:
	_apply_budgets()
	_apply_sun()
	_apply_lights()
	_apply_environment()


## Sets a node's visibility range from a base distance that follows the View distance setting.
static func set_detail_range(geometry: GeometryInstance3D, base_distance: float) -> void:
	geometry.set_meta(&"detail_base_range", base_distance)
	geometry.add_to_group(&"detail_ranged")
	geometry.visibility_range_end = base_distance * detail_distance_scale


func _quality() -> int:
	return clampi(int(settings.get_value(&"shadow_quality")), 0, 4) if settings != null else 3


func _apply_budgets() -> void:
	var quality := _quality()
	small_item_shadow_distance = SMALL_ITEM_SHADOW[quality]
	large_item_shadow_distance = LARGE_ITEM_SHADOW[quality]
	detail_distance_scale = float(settings.get_value(&"view_distance")) if settings != null else 1.0


func _apply_sun() -> void:
	var sun := beach.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return
	var quality := _quality()
	sun.shadow_enabled = quality > 0
	if quality == 0:
		return
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[quality], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTER[quality])
	sun.directional_shadow_max_distance = SHADOW_DISTANCE[quality]
	if SHADOW_FOUR_SPLITS[quality]:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_split_1 = FOUR_SPLITS.x
		sun.directional_shadow_split_2 = FOUR_SPLITS.y
		sun.directional_shadow_split_3 = FOUR_SPLITS.z
		sun.directional_shadow_blend_splits = true
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_split_1 = TWO_SPLIT
		sun.directional_shadow_blend_splits = false


func _apply_lights() -> void:
	var shadow_range: float = LIGHT_SHADOW[_quality()]
	for node in get_tree().get_nodes_in_group(&"interior_lights"):
		var light := node as Light3D
		if light == null or not beach.is_ancestor_of(light):
			continue
		# The light and its cube-shadow passes switch off entirely when the player is far away.
		light.distance_fade_enabled = true
		light.distance_fade_begin = LIGHT_FADE_BEGIN
		light.distance_fade_length = LIGHT_FADE_LENGTH
		light.shadow_enabled = shadow_range > 0.0
		light.distance_fade_shadow = shadow_range


func _apply_environment() -> void:
	var world := beach.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null or settings == null:
		return
	world.environment.ssao_enabled = bool(settings.get_value(&"ssao"))
	world.environment.glow_enabled = bool(settings.get_value(&"glow"))


func _apply_detail_ranges() -> void:
	for node in get_tree().get_nodes_in_group(&"detail_ranged"):
		var geometry := node as GeometryInstance3D
		if geometry != null and geometry.has_meta(&"detail_base_range"):
			geometry.visibility_range_end = float(geometry.get_meta(&"detail_base_range")) * detail_distance_scale
	if session != null and session.item_view_manager != null:
		session.item_view_manager.refresh_detail_ranges()


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	match key:
		&"shadow_quality":
			_apply_budgets()
			_apply_sun()
			_apply_lights()
			if session != null and session.item_view_manager != null:
				session.item_view_manager.refresh_detail_ranges()
		&"view_distance":
			_apply_budgets()
			_apply_detail_ranges()
		&"ssao", &"glow":
			_apply_environment()
