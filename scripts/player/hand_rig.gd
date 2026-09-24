class_name HandRig
extends Node3D
## First-person hands, bag and tool sockets. Presentation only.
## Gameplay sockets never move. The view-model FOV correction and ViewmodelAnimator's motion
## (sway, arm clips, tool activity) are composed into each socket's View node, the fallback
## hand anchors and the IK arm targets.

const FEEL := preload("res://data/feel/feel_tuning.tres")
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
@export var animator: ViewmodelAnimator

var arms: FirstPersonArms
var _tool_active := false
var _left_prop := false
var _right_prop := false
var _large_prop := false
var _views := {}
var _anchor_rest := {}
var _applied_fov := -1.0
var _correction := Transform3D.IDENTITY
var _sway := Transform3D.IDENTITY
var _left_motion := Transform3D.IDENTITY
var _right_motion := Transform3D.IDENTITY
var _tool_motion := Transform3D.IDENTITY
var _tool_scene: PackedScene
var _tool_id := StringName()
var _tool_instance: Node3D
var _tool_tip: Marker3D
var _small_visuals: Array[Node3D] = []


func _ready() -> void:
	# Held visuals hang under a per-socket view node that carries the FOV correction and motion.
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
	_update_correction()
	_apply_views()


func _process(_delta: float) -> void:
	var camera := get_parent() as Camera3D
	if camera != null and camera.fov != _applied_fov:
		_update_correction()
		_apply_views()


## Where a travelling item should end, in the socket's space, to meet the visible hand.
func view_offset(socket: Marker3D) -> Vector3:
	return (_views[socket] as Node3D).transform.origin if _views.has(socket) else Vector3.ZERO


## The socket as it appears on screen, for presentations that start from the hand.
func presentation_transform(socket: Marker3D) -> Transform3D:
	return Transform3D(socket.global_basis, socket.global_transform * view_offset(socket))


## The node held visuals hang from for `socket` (its View).
func visual_parent(socket: Marker3D) -> Node3D:
	return _views.get(socket, socket) as Node3D


## Called by ViewmodelAnimator every frame: `sway` in camera space, each arm's clip about its
## pivot (rig space) and the tool's working motion in tool-socket space.
func apply_motion(sway: Transform3D, left: Transform3D, right: Transform3D, tool: Transform3D) -> void:
	_sway = sway
	_left_motion = left
	_right_motion = right
	_tool_motion = tool
	_apply_views()


func show_bag(visible_value: bool) -> void:
	var was_visible := bag_placeholder.visible
	bag_placeholder.visible = visible_value
	_update_arms()
	if visible_value and not was_visible and animator != null:
		animator.play(&"bag_raise", &"left")


## Returns the live tool instance. Re-setting the same scene keeps the instance (no animation).
## The previous tool leaves the socket's View at once and drops out of view on its own.
func set_tool_scene(scene: PackedScene, tool_id: StringName = &"") -> Node3D:
	var view := _views[tool_socket] as Node3D
	if scene != null and scene == _tool_scene and is_instance_valid(_tool_instance) and _tool_instance.get_parent() == view:
		if not tool_id.is_empty():
			_tool_id = tool_id
		return _tool_instance
	_drop_current_tool(true)
	_tool_scene = scene
	_tool_id = tool_id
	_tool_active = false
	if scene != null:
		_tool_instance = scene.instantiate() as Node3D
		if _tool_instance != null:
			view.add_child(_tool_instance)
			_tool_active = true
	_update_arms()
	if _tool_active and animator != null:
		animator.play(&"equip_raise", &"right")
	return _tool_instance if _tool_active else null


func set_small_prop_scenes(left_scene: PackedScene, right_scene: PackedScene) -> Array[Node3D]:
	var visuals: Array[Node3D] = [
		_replace_socket_scene(left_prop_socket, left_scene),
		_replace_socket_scene(right_prop_socket, right_scene),
	]
	_small_visuals = visuals
	_left_prop = visuals[0] != null
	_right_prop = visuals[1] != null
	_update_arms()
	return visuals


func set_large_prop_scene(scene: PackedScene) -> Node3D:
	_drop_current_tool(true)
	_tool_scene = null
	_clear_socket(left_prop_socket)
	_clear_socket(right_prop_socket)
	_small_visuals = []
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
	_small_visuals = []
	_left_prop = false
	_right_prop = false
	_large_prop = false
	_update_arms()


func clear_tool() -> void:
	_drop_current_tool(true)
	_tool_scene = null
	_tool_active = false
	_update_arms()


## Socket transform in rig space.
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


func play_cue(cue: StringName, info: Dictionary) -> void:
	if animator != null:
		animator.on_cue(cue, info)


func active_tool_id() -> StringName:
	return _tool_id if is_instance_valid(_tool_instance) else StringName()


## Marker at the working end of the current tool (stick tip, vacuum nozzle); falls back to the
## tool socket. It lives inside the tool instance, so it follows the visible tool.
func tool_tip() -> Node3D:
	if not is_instance_valid(_tool_instance):
		return tool_socket
	if not is_instance_valid(_tool_tip):
		_tool_tip = Marker3D.new()
		_tool_tip.name = "FeelTip"
		_tool_instance.add_child(_tool_tip)
		var tip_view_space: Vector3 = FEEL.tool_tips.get(_tool_id, Vector3(0.0, 0.0, -0.3))
		_tool_tip.position = _tool_instance.transform.affine_inverse() * tip_view_space
	return _tool_tip


func set_tool_activity(kind: StringName, amount: float) -> void:
	if animator != null:
		animator.set_activity(kind, amount)


func set_bag_fill(ratio: float) -> void:
	if animator != null:
		animator.set_bag_fill(ratio)


func bag_catch(strength := 1.0) -> void:
	if animator != null:
		animator.bag_catch(strength)


## Lifts the selected small prop in hand (index 0 = left, 1 = right) so the player can see
## which one the next placement uses. Only shown while two props are held.
func mark_selected(index: int, reduced: bool) -> void:
	for visual_index in _small_visuals.size():
		var visual := _small_visuals[visual_index]
		if not is_instance_valid(visual):
			continue
		var other_valid := _small_visuals.size() > 1 and is_instance_valid(_small_visuals[1 - visual_index])
		var selected := visual_index == index and other_valid
		var target := FEEL.held_selected_lift if selected else Vector3.ZERO
		HoverHighlight.set_active(visual, selected, HoverHighlight.Style.SOFT, reduced)
		if reduced:
			FeelMotion.replace(visual, &"select", null)
			visual.position = target
		else:
			var t := FeelMotion.replace(visual, &"select", FeelMotion.tween(visual))
			t.tween_property(visual, "position", target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_correction() -> void:
	var camera := get_parent() as Camera3D
	_applied_fov = camera.fov if camera != null else REFERENCE_FOV
	var spread := tan(deg_to_rad(_applied_fov) * 0.5) / tan(deg_to_rad(REFERENCE_FOV) * 0.5)
	_correction = Transform3D(Basis.from_scale(Vector3(spread, spread, 1.0)), Vector3.ZERO)


func _apply_views() -> void:
	for socket in _views:
		var pose := (socket as Marker3D).transform
		var view_transform := pose.affine_inverse() * _correction * _motion_for(socket) * pose
		if socket == tool_socket:
			view_transform = view_transform * _tool_motion
		(_views[socket] as Node3D).transform = view_transform
	for anchor in _anchor_rest:
		var side := _left_motion if str((anchor as Node).name).begins_with("Left") else _right_motion
		(anchor as Node3D).transform = _correction * _sway * side * (_anchor_rest[anchor] as Transform3D)
	if arms != null:
		arms.transform = _correction * _sway
		arms.set_motion(&"L", _left_motion)
		var right := _right_motion
		if _tool_active and not _right_prop and not _large_prop:
			# The gripping hand follows the tool's own working motion (vacuum hum, detector sweep).
			var pose := tool_socket.transform
			right = right * pose * _tool_motion * pose.affine_inverse()
		arms.set_motion(&"R", right)


func _motion_for(socket: Marker3D) -> Transform3D:
	if socket == bag_socket or socket == left_prop_socket:
		return _sway * _left_motion
	if socket == tool_socket or socket == right_prop_socket:
		return _sway * _right_motion
	return _sway


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


func _drop_current_tool(animate: bool) -> void:
	_tool_tip = null
	if not is_instance_valid(_tool_instance):
		_tool_instance = null
		_clear_socket(tool_socket)
		return
	var old := _tool_instance
	_tool_instance = null
	var reduced := animator == null or FeelMotion.reduced(animator.settings)
	if not animate or reduced or not is_inside_tree() or not old.is_inside_tree():
		if old.get_parent() != null:
			old.get_parent().remove_child(old)
		old.queue_free()
		return
	# Leave the View immediately (the socket shows exactly one tool) and fall out of view.
	old.reparent(self, true)
	var start := old.transform
	var t := FeelMotion.tween(old)
	t.tween_method(func(progress: float) -> void:
		var eased := progress * progress
		old.transform = Transform3D(start.basis * Basis(Vector3.RIGHT, 0.7 * eased), start.origin + Vector3.DOWN * 0.28 * eased)
	, 0.0, 1.0, FEEL.equip_drop_seconds)
	t.tween_callback(old.queue_free)


func _replace_socket_scene(socket: Marker3D, scene: PackedScene) -> Node3D:
	_clear_socket(socket)
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return null
	(_views[socket] as Node3D).add_child(instance)
	return instance


## Frees the hand visuals under the socket's View. Other children of the socket are in-flight
## presentations travelling into the hand, which finish and free themselves.
func _clear_socket(socket: Marker3D) -> void:
	var view := _views.get(socket) as Node3D
	if view == null:
		return
	for child in view.get_children():
		view.remove_child(child)
		child.queue_free()
