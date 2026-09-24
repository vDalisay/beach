class_name HoverHighlight
extends RefCounted
## Lazily built hover overlays under one visual root. Only the hovered object shows them.
## Materials are shared per style: only one target is hovered at a time (plan §4 rule 6).

enum Style { ACTION, BLOCKED, SOFT }

const FEEL := preload("res://data/feel/feel_tuning.tres")
const OUTLINE_SHADER := preload("res://shaders/hover_outline.gdshader")
const RIM_SHADER := preload("res://shaders/hover_rim.gdshader")
const OVERLAYS := &"hover_overlays"
## Existing marker: sweeps, mesh collectors and outline builders must skip these meshes.
const MARK := &"hover_outline"

static var _chains: Dictionary = {}
static var _outlines: Dictionary = {}
static var _outline_meshes: Dictionary = {}
static var _width_tween: Tween


static func set_active(root: Node3D, active: bool, style: Style = Style.ACTION, reduced_motion := false, see_through := false) -> void:
	if root == null or not is_instance_valid(root):
		return
	var overlays := _overlays(root, active)
	for overlay_value in overlays:
		var overlay := overlay_value as MeshInstance3D
		overlay.visible = active
		if active:
			overlay.material_override = _material(style, see_through or bool(overlay.get_meta(&"see_through", false)))
	if active:
		_animate_width(style, reduced_motion)
		for chain_value in _chains.values():
			_set_breath(chain_value as Material, reduced_motion)


## Frees the overlays built under `root`, so its next highlight builds them again. A pooled item
## view calls this when it changes model or is parked for the next record.
static func discard(root: Node3D) -> void:
	if root == null or not is_instance_valid(root) or not root.has_meta(OVERLAYS):
		return
	for overlay in root.get_meta(OVERLAYS) as Array:
		if is_instance_valid(overlay):
			(overlay as Node).free()
	root.remove_meta(OVERLAYS)


static func overlay_count(root: Node3D) -> int:
	return (root.get_meta(OVERLAYS, []) as Array).size() if root != null and is_instance_valid(root) else 0


## Copy of `source` with normals averaged across coincident vertices (welded), for the hull.
static func outline_mesh(source: Mesh) -> Mesh:
	if source == null:
		return null
	if _outline_meshes.has(source):
		return _outline_meshes[source]
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		if source is ArrayMesh and (source as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := source.surface_get_arrays(surface)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		if vertices.is_empty() or normals.size() != vertices.size():
			continue
		var summed := {}
		for index in vertices.size():
			var key := (vertices[index] * 10000.0).round()
			summed[key] = (summed.get(key, Vector3.ZERO) as Vector3) + normals[index]
		var welded := PackedVector3Array()
		welded.resize(vertices.size())
		for index in vertices.size():
			var total := summed[(vertices[index] * 10000.0).round()] as Vector3
			welded[index] = total.normalized() if total.length_squared() > 0.000001 else normals[index]
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = vertices
		out[Mesh.ARRAY_NORMAL] = welded
		out[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		if arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null:
			out[Mesh.ARRAY_BONES] = arrays[Mesh.ARRAY_BONES]
			out[Mesh.ARRAY_WEIGHTS] = arrays[Mesh.ARRAY_WEIGHTS]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var chosen: Mesh = result if result.get_surface_count() > 0 else source
	_outline_meshes[source] = chosen
	return chosen


static func _overlays(root: Node3D, build: bool) -> Array:
	if root.has_meta(OVERLAYS):
		var cached := (root.get_meta(OVERLAYS) as Array).filter(func(o: Variant) -> bool: return is_instance_valid(o))
		root.set_meta(OVERLAYS, cached)
		return cached
	if not build:
		return []
	var sources: Array[MeshInstance3D] = []
	_collect(root, sources)
	var overlays := []
	for source in sources:
		var overlay := MeshInstance3D.new()
		overlay.name = "HoverOverlay"
		overlay.set_meta(MARK, true)
		overlay.mesh = outline_mesh(source.mesh)
		overlay.skin = source.skin
		overlay.skeleton = source.skeleton
		overlay.transform = source.transform
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overlay.extra_cull_margin = 0.05
		overlay.visibility_range_end = source.visibility_range_end
		overlay.set_meta(&"see_through", _is_transparent(source))
		overlay.visible = false
		source.get_parent().add_child(overlay)
		overlays.append(overlay)
	root.set_meta(OVERLAYS, overlays)
	return overlays


static func _collect(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		# A nested physics object (a stain patch on a chair) is its own target with its own outline.
		if child is CollisionObject3D:
			continue
		if child is MeshInstance3D and (child as MeshInstance3D).visible and (child as MeshInstance3D).mesh != null and not child.has_meta(MARK):
			result.append(child as MeshInstance3D)
		_collect(child, result)


static func _is_transparent(source: MeshInstance3D) -> bool:
	for surface in source.get_surface_override_material_count():
		var material := source.get_active_material(surface)
		if material is BaseMaterial3D and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false


static func _material(style: Style, see_through: bool) -> Material:
	var key := "%d:%s" % [style, see_through]
	if _chains.has(key):
		return _chains[key]
	var rim := ShaderMaterial.new()
	rim.shader = RIM_SHADER
	var strength := FEEL.hover_rim_strength
	if style == Style.SOFT:
		strength = FEEL.hover_soft_rim_strength
	elif see_through:
		strength = FEEL.hover_see_through_rim_strength
	rim.set_shader_parameter("rim_strength", strength)
	var color := FEEL.hover_blocked_color if style == Style.BLOCKED else FEEL.hover_action_color
	rim.set_shader_parameter("rim_color", color)
	rim.set_shader_parameter("breath_hz", FEEL.hover_rim_hz)
	var head: Material = rim
	if style != Style.SOFT and not see_through:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter("outline_color", color)
		outline.set_shader_parameter("width_px", FEEL.hover_outline_px)
		outline.set_shader_parameter("max_world_width", FEEL.hover_max_world_width)
		outline.set_shader_parameter("dash_px", FEEL.hover_blocked_dash_px if style == Style.BLOCKED else 0.0)
		var backing := ShaderMaterial.new()
		backing.shader = OUTLINE_SHADER
		backing.set_shader_parameter("outline_color", FEEL.hover_backing_color)
		backing.set_shader_parameter("width_px", FEEL.hover_outline_px + FEEL.hover_backing_px)
		backing.set_shader_parameter("max_world_width", FEEL.hover_max_world_width * 1.6)
		outline.next_pass = backing
		_outlines[key] = [outline, backing]
		if style == Style.BLOCKED:
			head = outline
		else:
			rim.next_pass = outline
	_chains[key] = head
	return head


## Hover-in pop of the shared outline width; only the hovered object uses these materials.
static func _animate_width(_style: Style, reduced: bool) -> void:
	if _width_tween != null and _width_tween.is_valid():
		_width_tween.kill()
	_width_tween = null
	if reduced:
		_set_width(FEEL.hover_outline_px)
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_set_width(FEEL.hover_outline_px)
		return
	_width_tween = tree.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_width_tween.tween_method(_set_width, 0.0, FEEL.hover_outline_peak_px, FEEL.hover_in_seconds * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_width_tween.tween_method(_set_width, FEEL.hover_outline_peak_px, FEEL.hover_outline_px, FEEL.hover_in_seconds * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _set_width(width: float) -> void:
	for pair_value in _outlines.values():
		var pair := pair_value as Array
		(pair[0] as ShaderMaterial).set_shader_parameter("width_px", width)
		(pair[1] as ShaderMaterial).set_shader_parameter("width_px", width + FEEL.hover_backing_px)


static func _set_breath(material: Material, reduced: bool) -> void:
	var current := material
	while current != null:
		if current is ShaderMaterial and (current as ShaderMaterial).shader == RIM_SHADER:
			(current as ShaderMaterial).set_shader_parameter("breath_amount", 0.0 if reduced else FEEL.hover_rim_breath)
		current = current.next_pass
