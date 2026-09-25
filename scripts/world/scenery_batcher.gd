class_name SceneryBatcher
extends RefCounted
## Static instancing for scenery: repeated meshes (same mesh, materials, shadow and draw settings)
## under a static scenery root are merged into one MultiMesh per grid cell, so a row of palms,
## hut walls or pier chairs costs one draw call in each pass instead of one per copy. Cells keep
## frustum culling effective. Only visible, unscripted leaf meshes under scenery that is built
## once qualify; nodes in the "unbatched" group (such as the hut roof the sorting table hides)
## and physical bodies other than static ones are left alone. Collision is never touched. The
## replaced mesh nodes stay in the tree, hidden, so scene paths and inspection still work.

const CELL := 16.0
const MIN_COPIES := 2
# Scripts that only assemble scenery in _ready and never move or hide it afterwards.
const BUILDER_SCRIPTS := [
	"res://scripts/world/pier_visuals.gd", "res://scripts/world/shore_dressing.gd",
	"res://scripts/world/reef_dressing.gd", "res://scripts/world/city_backdrop.gd",
	"res://scripts/world/service_hut_visual.gd", "res://scripts/world/placement_slot.gd",
]

static var _baked_meshes: Dictionary = {}


## Batches repeated meshes under each root into MultiMeshes added to that root. Returns the number
## of mesh nodes replaced and batches created.
static func batch(roots: Array[Node3D]) -> Dictionary:
	var replaced := 0
	var batches := 0
	for root in roots:
		var groups := {}
		_collect(root, root, groups)
		for key in groups:
			var members := groups[key] as Array
			if members.size() < MIN_COPIES:
				continue
			root.add_child(_build(root, members))
			batches += 1
			replaced += members.size()
			for member in members:
				(member as MeshInstance3D).visible = false
				(member as MeshInstance3D).set_meta(&"batched", true)
	return {"replaced": replaced, "batches": batches}


static func _collect(root: Node3D, node: Node, groups: Dictionary) -> void:
	for child in node.get_children():
		if child.is_in_group(&"unbatched") or not (child is Node3D) or not (child as Node3D).visible:
			continue
		if child is CollisionObject3D and not child is StaticBody3D:
			continue
		var script := child.get_script() as Script
		if child is MeshInstance3D and script == null and child.get_child_count() == 0:
			_add_candidate(root, child as MeshInstance3D, groups)
			continue
		if script != null and script.resource_path not in BUILDER_SCRIPTS:
			continue
		_collect(root, child, groups)


static func _add_candidate(root: Node3D, mesh_node: MeshInstance3D, groups: Dictionary) -> void:
	if mesh_node.mesh == null or mesh_node.skin != null:
		return
	var overrides: Array = []
	var has_override := false
	for surface in mesh_node.mesh.get_surface_count():
		var material := mesh_node.get_surface_override_material(surface)
		overrides.append(material)
		has_override = has_override or material != null
	var origin := mesh_node.global_position
	var cell := Vector2i(floori(origin.x / CELL), floori(origin.z / CELL))
	var key := [mesh_node.mesh, overrides if has_override else [], mesh_node.material_override, mesh_node.material_overlay, mesh_node.cast_shadow, mesh_node.layers, mesh_node.visibility_range_begin, mesh_node.visibility_range_end, mesh_node.transparency, cell]
	if not groups.has(key):
		groups[key] = []
	(groups[key] as Array).append(mesh_node)


static func _build(root: Node3D, members: Array) -> MultiMeshInstance3D:
	var first := members[0] as MeshInstance3D
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = _mesh_with_overrides(first)
	instances.instance_count = members.size()
	var to_root := root.global_transform.affine_inverse()
	for index in members.size():
		instances.set_instance_transform(index, to_root * (members[index] as MeshInstance3D).global_transform)
	var batch := MultiMeshInstance3D.new()
	batch.name = "Batch_%s" % str(first.name).validate_node_name()
	batch.multimesh = instances
	batch.material_override = first.material_override
	batch.material_overlay = first.material_overlay
	batch.cast_shadow = first.cast_shadow
	batch.layers = first.layers
	batch.visibility_range_begin = first.visibility_range_begin
	batch.visibility_range_end = first.visibility_range_end
	batch.transparency = first.transparency
	return batch


## MultiMeshInstance3D has no per-surface overrides, so they are baked into a shared mesh copy.
static func _mesh_with_overrides(source: MeshInstance3D) -> Mesh:
	var overrides: Array = []
	var has_override := false
	for surface in source.mesh.get_surface_count():
		overrides.append(source.get_surface_override_material(surface))
		has_override = has_override or overrides[surface] != null
	if not has_override or source.mesh is not ArrayMesh:
		return source.mesh
	var key := [source.mesh, overrides]
	if not _baked_meshes.has(key):
		var baked := source.mesh.duplicate() as ArrayMesh
		for surface in overrides.size():
			if overrides[surface] != null:
				baked.surface_set_material(surface, overrides[surface])
		_baked_meshes[key] = baked
	return _baked_meshes[key] as Mesh
