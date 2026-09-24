class_name FlapAnimator
extends Node
## Flaps the named limb parts of a wildlife model around the body's forward axis.
## Presentation only; routes and rescue state live elsewhere.

@export var part_names: PackedStringArray = []
@export var amplitude := 0.35
@export var speed := 2.2
@export var rear_scale := 0.6

var _parts: Array[Node3D] = []
var _signs: Array[float] = []
var _scales: Array[float] = []
var _phase := 0.0


func _ready() -> void:
	var owner_node := get_parent()
	for part_name in part_names:
		var part := owner_node.find_child(part_name, true, false) as Node3D
		if part == null:
			continue
		_parts.append(part)
		_signs.append(1.0 if part.position.x >= 0.0 else -1.0)
		_scales.append(rear_scale if part_name.contains("B") else 1.0)
	_phase = float(get_instance_id() % 1000) * 0.01


func _process(delta: float) -> void:
	_phase += delta * speed
	for index in _parts.size():
		_parts[index].rotation.z = _signs[index] * sin(_phase + float(index) * 0.4) * amplitude * _scales[index]
