class_name DirtVisual
extends Area3D

const DIRT_PATCH_SCENE := preload("res://scenes/items/dirt_patch.tscn")
const FEEL := preload("res://data/feel/feel_tuning.tres")

@onready var mesh: MeshInstance3D = %Mesh

var item_id: StringName
var patch_id: StringName
var _base_scale := Vector3.ONE
var _highlighted := false
var _highlight_actionable := true


func _ready() -> void:
	mesh.mesh = ModelLibrary.mesh("res://art/models/furniture_stain.glb")


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


## The stain smears sideways and fades as the cloth passes (a fade only under reduced motion).
func clean(reduced := false) -> void:
	collision_layer = 0
	collision_mask = 0
	var t := FeelMotion.tween(self)
	if reduced:
		t.tween_property(mesh, "transparency", 1.0, 0.18)
	else:
		t.set_parallel(true)
		t.tween_property(mesh, "transparency", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", _base_scale * Vector3(1.35, 0.6, 1.0), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "position", position + transform.basis.x.normalized() * 0.03, 0.22)
	t.chain().tween_callback(queue_free)


## Hover grows the stain visual (not its target collider) and outlines it; a stain the current
## tool cannot clean gets the blocked style.
func set_highlighted(value: bool, actionable := true, reduced := false) -> void:
	if value == _highlighted and (not value or actionable == _highlight_actionable):
		return
	_highlighted = value
	_highlight_actionable = actionable
	HoverHighlight.set_active(self, value, HoverHighlight.Style.ACTION if actionable else HoverHighlight.Style.BLOCKED, reduced)
	var target := Vector3.ONE * (1.12 if value else 1.0)
	var visuals: Array[Node3D] = [mesh]
	for overlay in get_meta(HoverHighlight.OVERLAYS, []) as Array:
		if is_instance_valid(overlay):
			visuals.append(overlay as Node3D)
	if reduced:
		FeelMotion.replace(self, &"hover", null)
		for visual in visuals:
			visual.scale = target
		return
	var t := FeelMotion.replace(self, &"hover", FeelMotion.tween(self).set_parallel(true))
	for visual in visuals:
		t.tween_property(visual, "scale", target, FEEL.hover_in_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
