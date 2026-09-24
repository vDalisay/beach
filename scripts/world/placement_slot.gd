@tool
class_name PlacementSlot
extends Marker3D

enum Layout {
	ROW,
	SHELF,
	UPRIGHT,
	MOORING,
}

@export var pool_id: StringName
@export var accepted_families: PackedStringArray
@export_range(1, 200, 1) var capacity := 1
@export_range(0.1, 5.0, 0.1) var spacing := 0.8
@export var layout := Layout.ROW
@export_range(0, 32, 1) var columns := 0

const SHELF_MODULE := preload("res://art/replacements/world/storage_shelf.tscn")
# The shelf module's top surface height; shelf pools are authored at this height above their ground.
const SHELF_HEIGHT := 0.8


func _ready() -> void:
	if layout != Layout.SHELF:
		return
	# Presentation only: no collision, so slot capture volumes and pickup rays are unchanged.
	for index in capacity:
		var module := SHELF_MODULE.instantiate() as Node3D
		module.name = "ShelfModule%02d" % index
		add_child(module)
		module.position = local_slot_transform(index).origin + Vector3(0.0, -SHELF_HEIGHT, 0.0)
		module.scale = Vector3(spacing, 1.0, 1.0)


func derived_slot_id(index: int) -> StringName:
	return StringName("%s:%03d" % [pool_id, index])


func local_slot_transform(index: int) -> Transform3D:
	var width := mini(columns, capacity) if columns > 0 and layout == Layout.ROW else capacity
	var offset := (float(index % width) - float(width - 1) * 0.5) * spacing
	var depth := float(floori(float(index) / float(width))) * spacing * 1.6 if columns > 0 and layout == Layout.ROW else 0.0
	var slot_basis := Basis.IDENTITY
	if layout == Layout.UPRIGHT:
		slot_basis = Basis(Vector3.FORWARD, PI * 0.5)
	return Transform3D(slot_basis, Vector3(offset, 0.0, depth))


func capture_size() -> Vector3:
	return Vector3(maxf(0.45, spacing * 0.7), 1.35, 1.0 if layout != Layout.MOORING else 2.4)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if pool_id.is_empty():
		warnings.append("Pool ID is required.")
	if accepted_families.is_empty():
		warnings.append("Accepted families are required.")
	return warnings
