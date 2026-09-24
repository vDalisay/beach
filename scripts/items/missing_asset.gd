class_name MissingAsset
extends Node3D

@export var asset_id := "A00"
@export var display_name := "Missing asset"
@export var compact_label := false
@export var cube_color := Color.MAGENTA
@export var dimensions := Vector3.ONE

@onready var mesh_instance: MeshInstance3D = %Mesh
@onready var label: Label3D = %Label


func _ready() -> void:
	_refresh()


func configure(entry: Dictionary) -> void:
	asset_id = str(entry.get("id", asset_id))
	display_name = str(entry.get("label", display_name))
	cube_color = Color.from_string("#" + str(entry.get("color", "ff00ff")), Color.MAGENTA)
	dimensions = _vector3(entry.get("dimensions", [1.0, 1.0, 1.0]))
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.position.y = dimensions.y * 0.5

	var material := StandardMaterial3D.new()
	material.albedo_color = cube_color
	material.roughness = 0.8
	mesh_instance.material_override = material

	label.text = asset_id if compact_label else "%s · %s" % [asset_id, display_name]
	label.position.y = dimensions.y + 0.25


func _vector3(value: Variant) -> Vector3:
	var values: Array = value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
