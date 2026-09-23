class_name DisposalBag
extends RigidBody3D

signal fell_out_of_bounds(bag_id: StringName)

const COLORS := {
	&"pmd": Color("2685b5"),
	&"organic": Color("4b913f"),
	&"general": Color("666b72"),
	&"glass": Color("4aaca9"),
}

@onready var mesh: MeshInstance3D = %BagMesh
@onready var label: Label3D = %BagLabel

var bag_id: StringName
var record: Dictionary
var outside_check: Callable
var _reported_outside := false


func _ready() -> void:
	sleeping_state_changed.connect(_on_sleeping_state_changed)
	set_physics_process(false)


func configure(bag_record: Dictionary, bounds_check: Callable = Callable(), held_visual := false) -> void:
	record = bag_record
	bag_id = StringName(str(record.bag_id))
	outside_check = bounds_check
	set_meta(&"disposal_bag_id", bag_id)
	var category := StringName(str(record.category))
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS.get(category, Color.MAGENTA)
	material.roughness = 0.88
	mesh.material_override = material
	label.text = "%s\n%d/%d" % [str(category).to_upper(), int(record.correct_count), (record.item_ids as Array).size()]
	if held_visual:
		freeze = true
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
		return
	restore_from_record()


func restore_from_record() -> void:
	global_transform = ItemRecord._array_to_transform(record.world_transform as Array)
	linear_velocity = ItemRecord._array_to_vector(record.linear_velocity as Array)
	angular_velocity = ItemRecord._array_to_vector(record.angular_velocity as Array)
	var is_world := str(record.location) == "WORLD"
	freeze = not is_world or bool(record.sleeping)
	sleeping = bool(record.sleeping)
	collision_layer = 4 if is_world else 8
	collision_mask = 1 | 4 | 8 if is_world else 0
	_reported_outside = false
	set_physics_process(is_world)


func launch(impulse: Vector3) -> void:
	freeze = false
	sleeping = false
	_reported_outside = false
	set_physics_process(true)
	apply_central_impulse(impulse)


func synchronize_record() -> void:
	if str(record.location) != "WORLD":
		return
	record.world_transform = ItemRecord._transform_to_array(global_transform)
	record.linear_velocity = ItemRecord._vector_to_array(linear_velocity)
	record.angular_velocity = ItemRecord._vector_to_array(angular_velocity)
	record.sleeping = sleeping


func _physics_process(_delta: float) -> void:
	if _reported_outside or not outside_check.is_valid() or not bool(outside_check.call(global_position)):
		return
	_reported_outside = true
	synchronize_record()
	freeze = true
	set_physics_process(false)
	fell_out_of_bounds.emit(bag_id)


func _on_sleeping_state_changed() -> void:
	if str(record.location) == "WORLD":
		synchronize_record()
