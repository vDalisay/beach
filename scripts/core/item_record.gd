class_name ItemRecord
extends RefCounted

enum Location {
	WORLD,
	BURIED,
	ATTACHED,
	BAG,
	HELD,
	TABLE,
	BIN,
	SEALED,
	SLOTTED,
	COLLECTED,
	VALUABLE_TRAY,
	SOLD,
}

const LOCATION_NAMES: Array[StringName] = [
	&"WORLD",
	&"BURIED",
	&"ATTACHED",
	&"BAG",
	&"HELD",
	&"TABLE",
	&"BIN",
	&"SEALED",
	&"SLOTTED",
	&"COLLECTED",
	&"VALUABLE_TRAY",
	&"SOLD",
]

var item_id: StringName
var definition_id: StringName
var home_section_id: StringName
var home_zone_id: StringName
var required := true
var location: Location = Location.WORLD
var holder_id: StringName
var container_id: StringName
var slot_id: StringName
var attachment_id: StringName
var last_world_transform := Transform3D.IDENTITY
var linear_velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO
var sleeping := true
var dirty_patches_remaining: Array[StringName] = []
var buried := false
var revealed := true
var dig_surface_position := Vector3.ZERO
var reveal_transform := Transform3D.IDENTITY
var rescuer_id: StringName
var collector_id: StringName


func to_snapshot() -> Dictionary:
	return row_from_values(capture_values())


## The record's values in the order row_from_values() reads them. Copying them is cheap, so a
## save can do it on the main thread and build the row on its writer thread.
func capture_values() -> Array:
	return [
		item_id, definition_id, home_section_id, home_zone_id, required, location, holder_id,
		container_id, slot_id, attachment_id, last_world_transform, linear_velocity, angular_velocity,
		sleeping, dirty_patches_remaining.duplicate(), buried, revealed, dig_surface_position,
		reveal_transform, rescuer_id, collector_id,
	]


static func row_from_values(values: Array) -> Dictionary:
	return {
		"item_id": str(values[0]),
		"definition_id": str(values[1]),
		"home_section_id": str(values[2]),
		"home_zone_id": str(values[3]),
		"required": values[4],
		"location": str(LOCATION_NAMES[values[5]]),
		"holder_id": str(values[6]),
		"container_id": str(values[7]),
		"slot_id": str(values[8]),
		"attachment_id": str(values[9]),
		"last_world_transform": _transform_to_array(values[10]),
		"linear_velocity": _vector_to_array(values[11]),
		"angular_velocity": _vector_to_array(values[12]),
		"sleeping": values[13],
		"dirty_patches_remaining": _string_names_to_array(values[14]),
		"buried": values[15],
		"revealed": values[16],
		"dig_surface_position": _vector_to_array(values[17]),
		"reveal_transform": _transform_to_array(values[18]),
		"rescuer_id": str(values[19]),
		"collector_id": str(values[20]),
	}


static func from_snapshot(data: Dictionary) -> ItemRecord:
	var record := ItemRecord.new()
	record.item_id = StringName(str(data.get("item_id", "")))
	record.definition_id = StringName(str(data.get("definition_id", "")))
	record.home_section_id = StringName(str(data.get("home_section_id", "")))
	record.home_zone_id = StringName(str(data.get("home_zone_id", "")))
	record.required = bool(data.get("required", true))
	record.location = location_from_name(StringName(str(data.get("location", "WORLD"))))
	record.holder_id = StringName(str(data.get("holder_id", "")))
	record.container_id = StringName(str(data.get("container_id", "")))
	record.slot_id = StringName(str(data.get("slot_id", "")))
	record.attachment_id = StringName(str(data.get("attachment_id", "")))
	record.last_world_transform = _array_to_transform(data.get("last_world_transform", []) as Array)
	record.linear_velocity = _array_to_vector(data.get("linear_velocity", []) as Array)
	record.angular_velocity = _array_to_vector(data.get("angular_velocity", []) as Array)
	record.sleeping = bool(data.get("sleeping", true))
	for patch in data.get("dirty_patches_remaining", []):
		record.dirty_patches_remaining.append(StringName(str(patch)))
	record.buried = bool(data.get("buried", false))
	record.revealed = bool(data.get("revealed", true))
	record.dig_surface_position = _array_to_vector(data.get("dig_surface_position", []) as Array)
	record.reveal_transform = _array_to_transform(data.get("reveal_transform", []) as Array)
	record.rescuer_id = StringName(str(data.get("rescuer_id", "")))
	record.collector_id = StringName(str(data.get("collector_id", "")))
	return record


static func location_from_name(value: StringName) -> Location:
	var index := LOCATION_NAMES.find(value)
	return index as Location if index >= 0 else Location.WORLD


func finite_numbers() -> bool:
	for value in _transform_to_array(last_world_transform):
		if not is_finite(float(value)):
			return false
	return linear_velocity.is_finite() and angular_velocity.is_finite() and dig_surface_position.is_finite() and reveal_transform.is_finite()


static func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _array_to_vector(values: Array) -> Vector3:
	if values.size() != 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func _transform_to_array(value: Transform3D) -> Array[float]:
	return [
		value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z,
		value.origin.x, value.origin.y, value.origin.z,
	]


static func _array_to_transform(values: Array) -> Transform3D:
	if values.size() != 12:
		return Transform3D.IDENTITY
	var basis := Basis(
		Vector3(float(values[0]), float(values[1]), float(values[2])),
		Vector3(float(values[3]), float(values[4]), float(values[5])),
		Vector3(float(values[6]), float(values[7]), float(values[8]))
	)
	return Transform3D(basis, Vector3(float(values[9]), float(values[10]), float(values[11])))


static func _string_names_to_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
