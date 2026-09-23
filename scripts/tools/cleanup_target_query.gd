class_name CleanupTargetQuery
extends RefCounted

const SIGHT_MASK := 1 | 4 | 8 | 16 | 64


static func nearby_waste(session: RunSession, player: BeachPlayer, center: Vector3, radius: float) -> Array[WorldItem]:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 4
	query.exclude = [player.get_rid()]
	var result: Array[WorldItem] = []
	for hit in player.get_world_3d().direct_space_state.intersect_shape(query, 96):
		var view := hit.collider as WorldItem
		if view == null or view.record == null or view.record.location != ItemRecord.Location.WORLD:
			continue
		var definition := view.definition
		if definition == null or definition.kind != ItemDefinition.Kind.WASTE or definition.collision_profile == ItemDefinition.CollisionProfile.LARGE or not ItemStore.collection_tool_for(view.record, definition).is_empty():
			continue
		result.append(view)
	result.sort_custom(func(a: WorldItem, b: WorldItem) -> bool:
		var distance_a := center.distance_squared_to(a.global_position)
		var distance_b := center.distance_squared_to(b.global_position)
		return str(a.item_id) < str(b.item_id) if is_equal_approx(distance_a, distance_b) else distance_a < distance_b
	)
	return result


static func visible_from_camera(player: BeachPlayer, view: WorldItem) -> bool:
	var origin := player.camera.global_position
	var target := view.global_position + Vector3.UP * WorldItem.profile_size(view.definition.collision_profile).y * 0.5
	var query := PhysicsRayQueryParameters3D.create(origin, target, SIGHT_MASK, [player.get_rid()])
	query.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == view
