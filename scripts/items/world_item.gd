class_name WorldItem
extends RigidBody3D

signal fell_out_of_bounds(item_id: StringName)
signal physics_settled(item_id: StringName)
## A thrown view hit something hard enough to show a landing (presentation only).
signal impacted(item_id: StringName, position: Vector3, speed: float)

const WATER_LEVEL := 0.08
const WORLD_LAYER := 1
const LOOSE_LAYER := 4
const FIXED_LAYER := 8
const MISSING_ASSET_PATH := "res://art/placeholders/missing_asset.tscn"
# Small resting items stop drawing beyond this (scaled by the View distance setting).
const SMALL_ITEM_DRAW_DISTANCE := 35.0
const FEEL := preload("res://data/feel/feel_tuning.tres")

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _shape_cache: Dictionary = {}

@onready var visual_root: Node3D = %VisualRoot
@onready var fallback_mesh: MeshInstance3D = %FallbackMesh
@onready var collision_shape: CollisionShape3D = %CollisionShape

var item_id: StringName
var record: ItemRecord
var definition: ItemDefinition
var outside_check: Callable
var _floating := false
var _reported_outside := false
var _idle_physics_frames := 0
var _highlighted := false
var _highlight_style := -1
var _presentation_tween: Tween
var _dirt_visuals: Dictionary = {}
## Whether the visual currently casts sun shadows (ItemViewManager applies the distance budget).
var casts_shadow := true
# The instantiated visual's scene and profile; a pooled view keeps it when the next record matches.
var _visual_key := ""
var _shadow_meshes: Array[GeometryInstance3D] = []
## Presentation owner for puffs and sparkles around this view; set by ItemViewManager.
var effects: ItemViewManager
var _impact_armed_until := 0
var _last_speed := 0.0


func _ready() -> void:
	sleeping_state_changed.connect(_on_sleeping_state_changed)
	set_physics_process(false)


func configure(item_record: ItemRecord, item_definition: ItemDefinition, bounds_check: Callable = Callable()) -> void:
	record = item_record
	definition = item_definition
	item_id = record.item_id
	outside_check = bounds_check
	set_meta(&"item_id", item_id)
	name = "Item_%s" % str(item_id).replace(":", "_")
	visual_root.scale = Vector3.ONE
	_reported_outside = false
	_idle_physics_frames = 0
	_configure_collision()
	_configure_visual()
	_rebuild_dirt_visuals()
	_floating = definition.float_mode == ItemDefinition.FloatMode.FLOAT
	gravity_scale = 0.0 if definition.float_mode == ItemDefinition.FloatMode.NEUTRAL else 1.0
	continuous_cd = definition.collision_profile == ItemDefinition.CollisionProfile.SMALL
	restore_from_record()


func activate() -> void:
	freeze = false
	sleeping = false
	_reported_outside = false
	_idle_physics_frames = 0
	set_physics_process(true)


func apply_throw(impulse: Vector3, torque_impulse := Vector3.ZERO) -> void:
	activate()
	apply_central_impulse(impulse)
	if not torque_impulse.is_zero_approx():
		apply_torque_impulse(torque_impulse)


func freeze_view() -> void:
	synchronize_record()
	freeze = true
	sleeping = true
	record.sleeping = true
	record.linear_velocity = Vector3.ZERO
	record.angular_velocity = Vector3.ZERO
	set_physics_process(false)


func restore_from_record() -> void:
	freeze = true
	global_transform = record.last_world_transform
	linear_velocity = record.linear_velocity
	angular_velocity = record.angular_velocity
	freeze = record.sleeping
	sleeping = record.sleeping
	_reported_outside = false
	set_physics_process(not record.sleeping)


func synchronize_record() -> void:
	if record == null:
		return
	record.last_world_transform = global_transform
	record.linear_velocity = linear_velocity
	record.angular_velocity = angular_velocity
	record.sleeping = sleeping


## Parks this view for reuse by ItemViewManager: out of the physics space (processing disabled
## removes the body and its dirt areas), hidden, and detached from its record.
func release_to_pool() -> void:
	set_highlighted(false)
	# No hover pose carries over to the next record, and its outlines are rebuilt on its first
	# highlight (the next record may show another model).
	FeelMotion.replace(visual_root, &"hover", null)
	visual_root.transform = Transform3D.IDENTITY
	HoverHighlight.discard(visual_root)
	set_physics_process(false)
	freeze = true
	record = null
	item_id = StringName()
	remove_meta(&"item_id")
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()


func set_shadow_casting(enabled: bool) -> void:
	if casts_shadow == enabled:
		return
	casts_shadow = enabled
	var setting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for geometry in _shadow_meshes:
		geometry.cast_shadow = setting


## Small items stop drawing beyond the View-distance budget; large props keep their authored range.
func apply_detail_range() -> void:
	if definition == null:
		return
	var large := definition.collision_profile == ItemDefinition.CollisionProfile.LARGE
	var limit := SMALL_ITEM_DRAW_DISTANCE * RenderQuality.detail_distance_scale
	for geometry in visual_root.find_children("*", "GeometryInstance3D", true, false):
		if not geometry.has_meta(&"authored_range"):
			geometry.set_meta(&"authored_range", (geometry as GeometryInstance3D).visibility_range_end)
		var authored := float(geometry.get_meta(&"authored_range"))
		(geometry as GeometryInstance3D).visibility_range_end = authored if large else (minf(authored, limit) if authored > 0.0 else limit)


func set_highlighted(value: bool, style: int = HoverHighlight.Style.ACTION, reduced_motion := false) -> void:
	if _highlighted == value and (not value or _highlight_style == style):
		return
	_highlighted = value
	_highlight_style = style if value else -1
	# Meshes with a transparent material get the rim instead of a hull (HoverHighlight checks per
	# mesh); the current glass litter uses the opaque shared atlas, so it keeps the outline.
	HoverHighlight.set_active(visual_root, value, style, reduced_motion)
	_animate_hover(value and style == HoverHighlight.Style.ACTION and not reduced_motion)


func is_highlighted() -> bool:
	return _highlighted


func outline_overlay_count() -> int:
	return HoverHighlight.overlay_count(visual_root)


func _animate_hover(active: bool) -> void:
	var t := FeelMotion.replace(visual_root, &"hover", FeelMotion.tween(self))
	if not active:
		t.tween_property(visual_root, "scale", Vector3.ONE, FEEL.hover_out_seconds)
		t.parallel().tween_property(visual_root, "position", Vector3.ZERO, FEEL.hover_out_seconds)
		t.parallel().tween_property(visual_root, "rotation", Vector3.ZERO, FEEL.hover_out_seconds)
		return
	var large := definition != null and definition.collision_profile == ItemDefinition.CollisionProfile.LARGE
	var lift := FEEL.hover_lift_large if large else FEEL.hover_lift_small
	t.tween_property(visual_root, "scale", Vector3.ONE * lift, FEEL.hover_in_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not large:
		var wiggle := deg_to_rad(FEEL.hover_wiggle_degrees) * (1.0 if FeelMotion.cosmetic_random(item_id) > 0.5 else -1.0)
		t.parallel().tween_property(visual_root, "position:y", FEEL.hover_hop_height, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(visual_root, "rotation:z", wiggle, 0.06)
		t.chain().tween_property(visual_root, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(visual_root, "rotation:z", -wiggle * 0.5, 0.06)
		t.chain().tween_property(visual_root, "rotation:z", 0.0, 0.08)


## Presentation travel of this already-committed view into `socket`. Collision is off for the
## whole trip and the record is already at its destination.
## options: reduced, delay, yoink_seconds, yoink_height, yoink_scale, wiggle_degrees, arc, via,
## via_fraction, spin_turns, spin_axis, shrink_from, end_scale, end_local, stretch, ease, drop.
func travel_to(socket: Node3D, duration: float, shrink: bool, finished: Callable, options: Dictionary = {}) -> void:
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	set_dirt_interactive(false)
	set_highlighted(false)
	FeelMotion.replace(visual_root, &"hover", null)
	visual_root.transform = Transform3D.IDENTITY
	reparent(socket, true)
	var reduced := bool(options.get("reduced", false))
	_presentation_tween = FeelMotion.tween(self)
	var delay := float(options.get("delay", 0.0))
	if delay > 0.0:
		_presentation_tween.tween_interval(delay)
	var yoink := 0.0 if reduced else float(options.get("yoink_seconds", 0.0))
	if yoink > 0.0:
		_presentation_tween.tween_property(visual_root, "position:y", float(options.get("yoink_height", FEEL.yoink_height)), yoink).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_presentation_tween.parallel().tween_property(visual_root, "scale", Vector3.ONE * float(options.get("yoink_scale", FEEL.yoink_scale)), yoink).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var wiggle := deg_to_rad(float(options.get("wiggle_degrees", 0.0)))
		if wiggle > 0.0:
			_presentation_tween.parallel().tween_method(func(t: float) -> void: visual_root.rotation.z = sin(t * TAU) * wiggle, 0.0, 1.0, yoink)
	var travel := options.duplicate()
	travel["visual"] = visual_root
	travel["shrink_to"] = float(options.get("end_scale", FEEL.bag_end_scale if shrink else 1.0))
	if reduced:
		for key in ["arc", "via", "spin_turns", "drop"]:
			travel.erase(key)
	FeelMotion.travel(self, socket, options.get("end_local", Transform3D.IDENTITY), duration, travel, finished, _presentation_tween)


## Listens for the next hard contact for a few seconds after a throw.
func arm_impact(seconds := 3.0) -> void:
	_impact_armed_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	if not body_entered.is_connected(_on_feel_contact):
		body_entered.connect(_on_feel_contact)


func play_impact(reduced: bool) -> void:
	if not reduced:
		FeelMotion.squash_land(visual_root, FEEL.impact_squash, Vector3(0.98, 1.04, 0.98), FEEL.impact_seconds)


func _on_feel_contact(_body: Node) -> void:
	if Time.get_ticks_msec() > _impact_armed_until:
		return
	_impact_armed_until = 0
	if _last_speed >= FEEL.impact_min_speed:
		impacted.emit(item_id, global_position, _last_speed)


func cancel_travel() -> void:
	if _presentation_tween != null and _presentation_tween.is_valid():
		_presentation_tween.kill()
	queue_free()


func refresh_dirt_visuals() -> void:
	if record == null or definition == null:
		return
	for patch_key in _dirt_visuals.keys():
		if StringName(patch_key) not in record.dirty_patches_remaining:
			var stale: Variant = _dirt_visuals[patch_key]
			_dirt_visuals.erase(patch_key)
			if is_instance_valid(stale):
				(stale as Node).queue_free()
	for index in range(record.dirty_patches_remaining.size()):
		var patch_id := record.dirty_patches_remaining[index]
		if _dirt_visuals.has(patch_id):
			continue
		var patch := DirtVisual.DIRT_PATCH_SCENE.instantiate() as DirtVisual
		visual_root.add_child(patch)
		patch.configure(item_id, patch_id, DirtVisual.anchor_for(definition, DirtVisual.index_for(patch_id, index)), true)
		_dirt_visuals[patch_id] = patch


func clean_dirt_patch(patch_id: StringName) -> void:
	if not _dirt_visuals.has(patch_id):
		return
	var patch: Variant = _dirt_visuals[patch_id]
	_dirt_visuals.erase(patch_id)
	if is_instance_valid(patch):
		(patch as DirtVisual).clean()


func set_dirt_interactive(value: bool) -> void:
	for patch_value in _dirt_visuals.values():
		var patch := patch_value as DirtVisual
		patch.collision_layer = 16 if value else 0
		patch.monitorable = value


func dirt_visual_count() -> int:
	return _dirt_visuals.size()


func _physics_process(_delta: float) -> void:
	_last_speed = linear_velocity.length()
	if not _reported_outside and outside_check.is_valid() and bool(outside_check.call(global_position)):
		_reported_outside = true
		freeze = true
		set_physics_process(false)
		fell_out_of_bounds.emit(item_id)
		return
	if linear_velocity.length_squared() < 0.0001 and angular_velocity.length_squared() < 0.0001:
		_idle_physics_frames += 1
		if _idle_physics_frames >= 30:
			sleeping = true
	else:
		_idle_physics_frames = 0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _floating or state.transform.origin.y >= WATER_LEVEL:
		return
	var depth := clampf(WATER_LEVEL - state.transform.origin.y, 0.0, 1.0)
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	state.apply_central_force(Vector3.UP * mass * gravity * (1.15 + depth * 1.5))
	state.linear_velocity *= 0.96
	state.angular_velocity *= 0.94


func _on_sleeping_state_changed() -> void:
	if not sleeping:
		set_physics_process(true)
		return
	synchronize_record()
	set_physics_process(false)
	physics_settled.emit(item_id)


func _configure_collision() -> void:
	var profile := int(definition.collision_profile)
	var size := profile_size(profile)
	collision_shape.shape = _shared_shape(profile, size)
	collision_shape.position.y = size.y * 0.5
	mass = 3.0 if profile == ItemDefinition.CollisionProfile.LARGE else 0.35
	collision_layer = LOOSE_LAYER | (FIXED_LAYER if profile == ItemDefinition.CollisionProfile.LARGE else 0)
	collision_mask = WORLD_LAYER | LOOSE_LAYER | FIXED_LAYER
	lock_rotation = profile == ItemDefinition.CollisionProfile.LARGE


func _configure_visual() -> void:
	var visual_scene := definition.visual_scene()
	var modelled := visual_scene != null and definition.visual_scene_path != MISSING_ASSET_PATH
	var key := "%s|%d" % [definition.visual_scene_path, definition.collision_profile] if modelled else ""
	if not key.is_empty() and key == _visual_key:
		# A pooled view already shows this model; only the dirt, pose and current draw range change.
		apply_detail_range()
		return
	for child in visual_root.get_children():
		if child != fallback_mesh:
			child.free()
	HoverHighlight.discard(visual_root)
	_dirt_visuals.clear()
	_visual_key = key
	if modelled:
		fallback_mesh.hide()
		visual_root.add_child(visual_scene.instantiate())
	else:
		var profile := int(definition.collision_profile)
		var size := profile_size(profile)
		fallback_mesh.mesh = _shared_mesh(profile, size)
		fallback_mesh.material_override = _shared_material(_material_key())
		fallback_mesh.position.y = size.y * 0.5
		fallback_mesh.show()
	apply_detail_range()
	_shadow_meshes.clear()
	casts_shadow = true
	for geometry in visual_root.find_children("*", "GeometryInstance3D", true, false):
		if (geometry as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_shadow_meshes.append(geometry as GeometryInstance3D)


func _rebuild_dirt_visuals() -> void:
	for patch_value in _dirt_visuals.values():
		if is_instance_valid(patch_value):
			(patch_value as Node).free()
	_dirt_visuals = DirtVisual.attach_remaining(visual_root, record, definition, true)


func _material_key() -> String:
	if definition.definition_id == &"waste_residue":
		return "residue"
	if definition.kind == ItemDefinition.Kind.PROP:
		return "prop"
	if definition.kind == ItemDefinition.Kind.VALUABLE:
		return "valuable"
	return ["pmd", "organic", "general", "glass", "none"][definition.waste_category]


static func profile_size(profile: int) -> Vector3:
	match profile:
		ItemDefinition.CollisionProfile.LARGE:
			return Vector3(1.15, 0.9, 0.8)
		ItemDefinition.CollisionProfile.FLAT:
			return Vector3(0.72, 0.08, 0.42)
		ItemDefinition.CollisionProfile.FLOATING:
			return Vector3(0.44, 0.18, 0.44)
	return Vector3(0.22, 0.18, 0.22)


static func clearance_radius(profile: int) -> float:
	var size := profile_size(profile)
	return maxf(size.x, size.z) * 0.5


static func _shared_mesh(profile: int, size: Vector3) -> Mesh:
	if not _mesh_cache.has(profile):
		var mesh := BoxMesh.new()
		mesh.size = size
		_mesh_cache[profile] = mesh
	return _mesh_cache[profile]


static func _shared_shape(profile: int, size: Vector3) -> Shape3D:
	if not _shape_cache.has(profile):
		var shape := BoxShape3D.new()
		shape.size = size
		_shape_cache[profile] = shape
	return _shape_cache[profile]


static func _shared_material(key: String) -> Material:
	if not _material_cache.has(key):
		var colors := {
			"pmd": Color("4aa9e9"),
			"organic": Color("78a84c"),
			"general": Color("777b82"),
			"glass": Color("78d4c5"),
			"prop": Color("efad47"),
			"valuable": Color("ffd85a"),
			"residue": Color("8c6848"),
			"none": Color.MAGENTA,
		}
		var material := StandardMaterial3D.new()
		material.albedo_color = colors.get(key, Color.MAGENTA)
		material.roughness = 0.78
		_material_cache[key] = material
	return _material_cache[key]

