class_name DistantItemVisuals
extends Node3D

var state: RunState
var definitions: Dictionary
var _sources: Dictionary = {}
var _entries: Dictionary = {}


func configure(run_state: RunState, item_definitions: Dictionary) -> void:
	state = run_state
	definitions = item_definitions


func build() -> void:
	var groups := {}
	for value in state.items.values():
		var record := value as ItemRecord
		if record.location != ItemRecord.Location.WORLD:
			continue
		var definition := definitions.get(record.definition_id) as ItemDefinition
		if definition == null or definition.collision_profile == ItemDefinition.CollisionProfile.LARGE:
			continue
		var source := _source_for(definition)
		if source.is_empty():
			continue
		var key := "%s|%s" % [record.home_section_id, record.definition_id]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(record)
	for key in groups:
		var records := groups[key] as Array
		var source := _sources[(records[0] as ItemRecord).definition_id] as Dictionary
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = source.mesh
		instances.instance_count = records.size()
		var visual := MultiMeshInstance3D.new()
		visual.name = "Litter_%s" % str(key).replace(":", "_")
		visual.multimesh = instances
		visual.material_override = source.material
		visual.visibility_range_end = 55.0
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
		for index in records.size():
			var record := records[index] as ItemRecord
			var pose := record.last_world_transform * (source.offset as Transform3D)
			instances.set_instance_transform(index, pose)
			_entries[record.item_id] = {"mesh": instances, "index": index, "offset": source.offset}


func has_item(item_id: StringName) -> bool:
	return _entries.has(item_id)


func is_item_visible(item_id: StringName) -> bool:
	if not _entries.has(item_id):
		return false
	var entry := _entries[item_id] as Dictionary
	return not is_zero_approx((entry.mesh as MultiMesh).get_instance_transform(int(entry.index)).basis.determinant())


func set_item_visible(item_id: StringName, visible: bool) -> void:
	if not _entries.has(item_id):
		return
	var entry := _entries[item_id] as Dictionary
	var record := state.items[item_id] as ItemRecord
	var pose := record.last_world_transform * (entry.offset as Transform3D)
	if not visible or record.location != ItemRecord.Location.WORLD:
		pose.basis = Basis.IDENTITY.scaled(Vector3.ZERO)
	(entry.mesh as MultiMesh).set_instance_transform(int(entry.index), pose)


func instance_count() -> int:
	return _entries.size()


func batch_count() -> int:
	return get_child_count()


func _source_for(definition: ItemDefinition) -> Dictionary:
	if _sources.has(definition.definition_id):
		return _sources[definition.definition_id] as Dictionary
	var result := {}
	var scene := load(definition.visual_scene_path) as PackedScene
	if scene != null:
		var wrapper := scene.instantiate() as Node3D
		if wrapper != null:
			var meshes := wrapper.find_children("*", "MeshInstance3D", true, false)
			if meshes.size() == 1:
				var source := meshes[0] as MeshInstance3D
				if source.mesh is ArrayMesh:
					var mesh := source.mesh as ArrayMesh
					for surface in mesh.get_surface_count():
						var material := source.get_surface_override_material(surface)
						if material != null:
							if mesh == source.mesh:
								mesh = mesh.duplicate() as ArrayMesh
							mesh.surface_set_material(surface, material)
					var offset := Transform3D.IDENTITY
					var cursor: Node = source
					while cursor != wrapper:
						offset = (cursor as Node3D).transform * offset
						cursor = cursor.get_parent()
					result = {"mesh": mesh, "material": source.material_override, "offset": offset}
			wrapper.free()
	_sources[definition.definition_id] = result
	return result
