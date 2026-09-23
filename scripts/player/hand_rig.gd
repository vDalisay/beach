class_name HandRig
extends Node3D

@export var bag_socket: Marker3D
@export var tool_socket: Marker3D
@export var left_prop_socket: Marker3D
@export var right_prop_socket: Marker3D
@export var large_prop_socket: Marker3D
@export var bag_placeholder: Node3D


func show_bag(visible_value: bool) -> void:
	bag_placeholder.visible = visible_value


func set_tool_scene(scene: PackedScene) -> Node3D:
	return _replace_socket_scene(tool_socket, scene)


func set_small_prop_scenes(left_scene: PackedScene, right_scene: PackedScene) -> Array[Node3D]:
	return [
		_replace_socket_scene(left_prop_socket, left_scene),
		_replace_socket_scene(right_prop_socket, right_scene),
	]


func set_large_prop_scene(scene: PackedScene) -> Node3D:
	_clear_socket(tool_socket)
	_clear_socket(left_prop_socket)
	_clear_socket(right_prop_socket)
	show_bag(false)
	return _replace_socket_scene(large_prop_socket, scene)


func clear_carry_visuals() -> void:
	_clear_socket(left_prop_socket)
	_clear_socket(right_prop_socket)
	_clear_socket(large_prop_socket)


func clear_tool() -> void:
	_clear_socket(tool_socket)


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


func _replace_socket_scene(socket: Marker3D, scene: PackedScene) -> Node3D:
	_clear_socket(socket)
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return null
	socket.add_child(instance)
	return instance


func _clear_socket(socket: Marker3D) -> void:
	for child in socket.get_children():
		child.queue_free()
