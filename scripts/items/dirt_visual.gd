class_name DirtVisual
extends Area3D

const DIRT_PATCH_SCENE := preload("res://scenes/items/dirt_patch.tscn")

@onready var mesh: MeshInstance3D = %Mesh

var item_id: StringName
var patch_id: StringName
var _base_scale := Vector3.ONE


func configure(owner_item_id: StringName, owner_patch_id: StringName, anchor: Vector3, interactive := true) -> void:
	item_id = owner_item_id
	patch_id = owner_patch_id
	position = anchor
	set_meta(&"dirt_item_id", item_id)
	set_meta(&"dirt_patch_id", patch_id)
	if not interactive:
		collision_layer = 0
		collision_mask = 0
		monitoring = false
		monitorable = false


func clean() -> void:
	collision_layer = 0
	collision_mask = 0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(mesh, "transparency", 1.0, 0.18)
	tween.tween_property(self, "scale", _base_scale * 0.72, 0.18)
	tween.chain().tween_callback(queue_free)


func set_highlighted(value: bool) -> void:
	scale = _base_scale * (1.12 if value else 1.0)


static func attach_remaining(parent: Node3D, record: ItemRecord, definition: ItemDefinition, interactive := true) -> Dictionary:
	var result := {}
	for index in range(record.dirty_patches_remaining.size()):
		var patch_id := record.dirty_patches_remaining[index]
		var patch := DIRT_PATCH_SCENE.instantiate() as DirtVisual
		parent.add_child(patch)
		patch.configure(record.item_id, patch_id, anchor_for(definition, index_for(patch_id, index)), interactive)
		result[patch_id] = patch
	return result


static func anchor_for(definition: ItemDefinition, index: int) -> Vector3:
	if index >= 0 and index < definition.dirt_patch_anchors.size():
		return definition.dirt_patch_anchors[index]
	var size := WorldItem.profile_size(definition.collision_profile)
	return Vector3((float(index) - 1.0) * size.x * 0.22, size.y + 0.02, 0)


static func index_for(patch_id: StringName, fallback: int) -> int:
	var text := str(patch_id)
	if text.begins_with("patch_") and text.trim_prefix("patch_").is_valid_int():
		return maxi(0, int(text.trim_prefix("patch_")) - 1)
	return fallback
