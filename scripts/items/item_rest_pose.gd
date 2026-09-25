class_name ItemRestPose
extends RefCounted
## How a loose item lies where it rests, so it reads as dropped on the sand rather than placed:
##   - the body leans with the slope under it, plus a small tumble from its ID (not large items,
##     not items floating on the water);
##   - inside the body, the model is lifted so its lowest point just touches the ground, sunk a
##     little into sand, and bottles, cans and cups often lie on their side
##     (ItemDefinition.lying_chance).
## Everything comes from the item ID and the ground, so near views, distant batches, reloads and
## throws always agree. The physics box is unchanged: pickup, hover and throws behave as before.

## Largest tumble of a small item, degrees.
const WOBBLE_DEGREES := 7.0
## How far a resting model sinks into the sand, at most, and as a share of its thickness.
const SINK := 0.012
const SINK_SHARE := 0.08
## An item this close to the ground under it counts as lying on it (not on a heap or a deck).
const ON_GROUND := 0.03

static var _bounds: Dictionary = {}
static var _poses: Dictionary = {}


## Body orientation (before its yaw) for an item resting at `at`.
static func rest_basis(definition: ItemDefinition, item_id: StringName, at: Vector3) -> Basis:
	if definition == null:
		return Basis.IDENTITY
	var floating := definition.float_mode == ItemDefinition.FloatMode.FLOAT and is_equal_approx(at.y, BeachGround.WATER_Y)
	if floating:
		return Basis.IDENTITY
	var lean := Basis.IDENTITY
	var ground := Coastline.surface_y(at.x, at.z)
	if absf(at.y - ground) < ON_GROUND:
		lean = _align_up(BeachRelief.normal_from(at.x, at.z, ground))
	if definition.collision_profile == ItemDefinition.CollisionProfile.LARGE:
		return lean
	var angle := _unit(item_id, 11) * TAU
	var tilt := (_unit(item_id, 12) - 0.5) * 2.0 * deg_to_rad(WOBBLE_DEGREES)
	return lean * Basis(Vector3(cos(angle), 0.0, sin(angle)), tilt)


## Model transform inside the item body: lifted onto the ground and, for some items, on its side.
static func visual_transform(definition: ItemDefinition, item_id: StringName) -> Transform3D:
	if definition == null:
		return Transform3D.IDENTITY
	var key := "%s|%s" % [definition.definition_id, item_id]
	if _poses.has(key):
		return _poses[key] as Transform3D
	var bounds := model_bounds(definition)
	if bounds.size == Vector3.ZERO:
		return Transform3D.IDENTITY
	var basis := Basis.IDENTITY
	if definition.lying_chance > 0.0 and _unit(item_id, 1) < definition.lying_chance:
		# Onto its side along X, then rolled a quarter turn at a time so the box stays exact.
		basis = Basis(Vector3.RIGHT, float(int(_unit(item_id, 3) * 4.0) % 4) * PI * 0.5) * Basis(Vector3.BACK, PI * 0.5 * (1.0 if _unit(item_id, 2) < 0.5 else -1.0))
	var turned := Transform3D(basis, Vector3.ZERO) * bounds
	var thickness := turned.size.y
	var sink := minf(SINK, thickness * SINK_SHARE)
	var centre := turned.get_center()
	var offset := Vector3(-centre.x, -turned.position.y - sink, -centre.z)
	if basis == Basis.IDENTITY:
		# Upright models keep their authored footprint; only their height is corrected.
		offset.x = 0.0
		offset.z = 0.0
	var pose := Transform3D(basis, offset)
	if _poses.size() > 20000:
		_poses.clear()
	_poses[key] = pose
	return pose


## The model's bounds in its wrapper's space (all meshes), cached per scene.
static func model_bounds(definition: ItemDefinition) -> AABB:
	var path := definition.visual_scene_path
	if _bounds.has(path):
		return _bounds[path] as AABB
	var result := AABB()
	var scene := definition.visual_scene()
	if scene != null:
		var wrapper := scene.instantiate() as Node3D
		if wrapper != null:
			var first := true
			for mesh_value in wrapper.find_children("*", "MeshInstance3D", true, false):
				var mesh := mesh_value as MeshInstance3D
				var local := Transform3D.IDENTITY
				var cursor: Node = mesh
				while cursor != wrapper:
					local = (cursor as Node3D).transform * local
					cursor = cursor.get_parent()
				var box := local * mesh.get_aabb()
				result = box if first else result.merge(box)
				first = false
			wrapper.free()
	_bounds[path] = result
	return result


static func _align_up(normal: Vector3) -> Basis:
	var axis := Vector3.UP.cross(normal)
	if axis.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(axis.normalized(), Vector3.UP.angle_to(normal))


## A stable value in [0, 1) for this item and purpose.
static func _unit(item_id: StringName, salt: int) -> float:
	var h := hash("%s#%d" % [item_id, salt]) & 0xFFFFFF
	return float(h) / float(0x1000000)
