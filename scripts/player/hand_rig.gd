class_name HandRig
extends Node3D

# Where the palms rest when nothing is held (camera space).
const LEFT_IDLE := Vector3(-0.3, -0.48, -0.58)
const RIGHT_IDLE := Vector3(0.3, -0.48, -0.58)
# Hand poses are framed for the default FOV. At other settings the visible hands, tools and
# props are scaled across the view (a view-model FOV) so they keep this framing. Gameplay
# sockets stay put: placement and throws never depend on the FOV setting.
const REFERENCE_FOV := 85.0

@export var bag_socket: Marker3D
@export var tool_socket: Marker3D
@export var left_prop_socket: Marker3D
@export var right_prop_socket: Marker3D
@export var large_prop_socket: Marker3D
@export var bag_placeholder: Node3D

var arms: FirstPersonArms
var _tool_active := false
var _left_prop := false
var _right_prop := false
var _large_prop := false
var _views := {}
var _anchor_rest := {}
var _applied_fov := -1.0


func _ready() -> void:
	# Held visuals hang under a per-socket view node that carries the FOV correction.
	for socket in [bag_socket, tool_socket, left_prop_socket, right_prop_socket, large_prop_socket]:
		var view := Node3D.new()
		view.name = "View"
		(socket as Marker3D).add_child(view)
		_views[socket] = view
	bag_placeholder.reparent(_views[bag_socket] as Node3D, false)
	for anchor_name in ["LeftHandAnchor", "RightHandAnchor"]:
		var anchor := get_node_or_null(anchor_name) as Node3D
		if anchor != null:
			_anchor_rest[anchor] = anchor.transform
	# Synty arms when they have been staged; otherwise the project-owned hands remain.
	if FirstPersonArms.available():
		arms = FirstPersonArms.new()
		arms.name = "FirstPersonArms"
		add_child(arms)
		for anchor in _anchor_rest:
			(anchor as Node3D).hide()
		_update_arms()
		arms.snap()
	_apply_view_fov()


func _process(_delta: float) -> void:
	var camera := get_parent() as Camera3D
	if camera != null and camera.fov != _applied_fov:
		_apply_view_fov()


## Where a travelling item should end, in the socket's space, to meet the visible hand.
func view_offset(socket: Marker3D) -> Vector3:
	return (_views[socket] as Node3D).transform.origin if _views.has(socket) else Vector3.ZERO


## The socket as it appears on screen, for presentations that start from the hand.
func presentation_transform(socket: Marker3D) -> Transform3D:
	return Transform3D(socket.global_basis, socket.global_transform * view_offset(socket))


func _apply_view_fov() -> void:
	var camera := get_parent() as Camera3D
	_applied_fov = camera.fov if camera != null else REFERENCE_FOV
	var spread := tan(deg_to_rad(_applied_fov) * 0.5) / tan(deg_to_rad(REFERENCE_FOV) * 0.5)
	var correction := Transform3D(Basis.from_scale(Vector3(spread, spread, 1.0)), Vector3.ZERO)
	for socket in _views:
		var pose := (socket as Marker3D).transform
		(_views[socket] as Node3D).transform = pose.affine_inverse() * correction * pose
	for anchor in _anchor_rest:
		(anchor as Node3D).transform = correction * (_anchor_rest[anchor] as Transform3D)
	if arms != null:
		arms.transform = correction


func show_bag(visible_value: bool) -> void:
	bag_placeholder.visible = visible_value
	_update_arms()


func set_tool_scene(scene: PackedScene) -> Node3D:
	var instance := _replace_socket_scene(tool_socket, scene)
	_tool_active = instance != null
	_update_arms()
	return instance


func set_small_prop_scenes(left_scene: PackedScene, right_scene: PackedScene) -> Array[Node3D]:
	var visuals: Array[Node3D] = [
		_replace_socket_scene(left_prop_socket, left_scene),
		_replace_socket_scene(right_prop_socket, right_scene),
	]
	_left_prop = visuals[0] != null
	_right_prop = visuals[1] != null
	_update_arms()
	return visuals


func set_large_prop_scene(scene: PackedScene) -> Node3D:
	_clear_socket(tool_socket)
	_clear_socket(left_prop_socket)
	_clear_socket(right_prop_socket)
	_tool_active = false
	_left_prop = false
	_right_prop = false
	show_bag(false)
	var instance := _replace_socket_scene(large_prop_socket, scene)
	_large_prop = instance != null
	_update_arms()
	return instance


func clear_carry_visuals() -> void:
	_clear_socket(left_prop_socket)
	_clear_socket(right_prop_socket)
	_clear_socket(large_prop_socket)
	_left_prop = false
	_right_prop = false
	_large_prop = false
	_update_arms()


func clear_tool() -> void:
	_clear_socket(tool_socket)
	_tool_active = false
	_update_arms()


func socket_transform(socket_name: StringName) -> Transform3D:
	match socket_name:
		&"bag":
			return bag_socket.transform
		&"tool":
			return tool_socket.transform
		&"left_prop":
			return left_prop_socket.transform
		&"right_prop":
			return right_prop_socket.transform
		&"large_prop":
			return large_prop_socket.transform
	return Transform3D.IDENTITY


func _update_arms() -> void:
	if arms == null:
		return
	if _large_prop:
		# Both palms under the sides of the two-handed prop.
		var base := large_prop_socket.position
		arms.set_hand(&"L", base + Vector3(-0.2, 0.05, 0.12), FirstPersonArms.Grip.HOLD)
		arms.set_hand(&"R", base + Vector3(0.2, 0.05, 0.12), FirstPersonArms.Grip.HOLD)
		return
	if _right_prop:
		arms.set_hand(&"R", right_prop_socket.position + Vector3(0.01, 0.0, 0.03), FirstPersonArms.Grip.HOLD)
	elif _tool_active:
		arms.set_hand(&"R", tool_socket.position + Vector3(0.0, -0.02, 0.04), FirstPersonArms.Grip.GRIP)
	else:
		arms.set_hand(&"R", RIGHT_IDLE, FirstPersonArms.Grip.RELAXED)
	if _left_prop:
		arms.set_hand(&"L", left_prop_socket.position + Vector3(-0.01, 0.0, 0.03), FirstPersonArms.Grip.HOLD)
	elif bag_placeholder.visible:
		arms.set_hand(&"L", bag_socket.position + Vector3(0.0, 0.03, 0.03), FirstPersonArms.Grip.GRIP)
	else:
		arms.set_hand(&"L", LEFT_IDLE, FirstPersonArms.Grip.RELAXED)


func _replace_socket_scene(socket: Marker3D, scene: PackedScene) -> Node3D:
	_clear_socket(socket)
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return null
	(_views[socket] as Node3D).add_child(instance)
	return instance


func _clear_socket(socket: Marker3D) -> void:
	var view := _views.get(socket) as Node3D
	for child in socket.get_children() + (view.get_children() if view != null else []):
		if child != view:
			child.queue_free()
