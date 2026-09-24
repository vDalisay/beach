class_name WorldItem
extends RigidBody3D

signal fell_out_of_bounds(item_id: StringName)
signal physics_settled(item_id: StringName)

const WATER_LEVEL := 0.08
const WORLD_LAYER := 1
const LOOSE_LAYER := 4
const FIXED_LAYER := 8
const HOVER_SHADER := preload("res://shaders/hover_outline.gdshader")

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _shape_cache: Dictionary = {}
static var _outline_material: ShaderMaterial

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
var _outline_overlays: Array[MeshInstance3D] = []
var _presentation_tween: Tween
var _dirt_visuals: Dictionary = {}


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


func pulse() -> void:
	visual_root.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3.ONE * 1.08, 0.125)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.125)


func set_highlighted(value: bool) -> void:
	if _highlighted == value:
		return
	_highlighted = value
	if value and _outline_overlays.is_empty():
		_build_outline_overlays()
	for overlay in _outline_overlays:
		overlay.visible = value


func is_highlighted() -> bool:
	return _highlighted


func outline_overlay_count() -> int:
	return _outline_overlays.size()


func travel_to(socket: Node3D, duration: float, shrink: bool, finished: Callable) -> void:
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	set_dirt_interactive(false)
	set_highlighted(false)
	reparent(socket, true)
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(self, "transform", Transform3D.IDENTITY, duration)
	if shrink:
		_presentation_tween.tween_property(visual_root, "scale", Vector3.ONE * 0.12, duration)
	_presentation_tween.chain().tween_callback(finished)


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
	for child in visual_root.get_children():
		if child != fallback_mesh:
			child.free()
	var visual_scene := load(definition.visual_scene_path) as PackedScene
	if visual_scene != null and definition.visual_scene_path != "res://art/placeholders/missing_asset.tscn":
		fallback_mesh.hide()
		visual_root.add_child(visual_scene.instantiate())
		_limit_small_item_draws(visual_root)
		return
	var profile := int(definition.collision_profile)
	var size := profile_size(profile)
	fallback_mesh.mesh = _shared_mesh(profile, size)
	fallback_mesh.material_override = _shared_material(_material_key())
	fallback_mesh.position.y = size.y * 0.5
	fallback_mesh.show()
	_limit_small_item_draws(visual_root)


func _limit_small_item_draws(node: Node) -> void:
	if definition.collision_profile == ItemDefinition.CollisionProfile.LARGE:
		return
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = minf(geometry.visibility_range_end, 35.0) if geometry.visibility_range_end > 0.0 else 35.0
	for child in node.get_children():
		_limit_small_item_draws(child)


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


func _build_outline_overlays() -> void:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = HOVER_SHADER
	var sources: Array[MeshInstance3D] = []
	_collect_visible_meshes(visual_root, sources)
	for source in sources:
		var overlay := MeshInstance3D.new()
		overlay.set_meta(&"hover_outline", true)
		overlay.mesh = source.mesh
		overlay.skin = source.skin
		overlay.skeleton = source.skeleton
		overlay.transform = source.transform
		overlay.material_override = _outline_material
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overlay.extra_cull_margin = 0.05
		overlay.visible = false
		source.get_parent().add_child(overlay)
		_outline_overlays.append(overlay)


func _collect_visible_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.visible and child.mesh != null and not child.has_meta(&"hover_outline"):
			result.append(child)
		_collect_visible_meshes(child, result)
