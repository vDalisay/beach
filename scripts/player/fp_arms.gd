class_name FirstPersonArms
extends Node3D
## Synty character arms for the first-person view. tools/blender/build_fp_arms.py cuts them
## from the licensed character rig into the Git-ignored art/synty/hands/. A native TwoBoneIK3D
## reaches each palm to the hand-rig position chosen for the current carry or tool state, and
## the fingers curl per grip. Presentation only: sockets, items and input are unchanged.

enum Grip { RELAXED, HOLD, GRIP }

const ARMS_PATH := "res://art/synty/hands/fp_arms.glb"
const ATLAS := "res://art/synty/POLYGON_Palm_City/textures/PolygonPalmCity_01_A.png"
const SKIN_MASK := "res://art/synty/POLYGON_Palm_City/textures/Skin_01_Mask.png"
const CHARACTER_SHADER := preload("res://shaders/beach_character.gdshader")
# The rig faces +Z with its shoulders at about 1.39 m. View-model placement: shoulders sit
# just ahead of and well below the eye (outside the view), slightly enlarged so the palms
# reach the existing hand-rig sockets.
const MODEL_SCALE := 1.1
const MODEL_OFFSET := Vector3(0.0, -1.86, -0.13)
# Distance from the wrist bone to the palm centre that should meet the target.
const PALM_REACH := 0.08
const FOLLOW_RATE := 14.0
const CURLS := {
	Grip.RELAXED: [0.25, 0.2, 0.15],
	Grip.HOLD: [0.6, 0.55, 0.35],
	Grip.GRIP: [1.35, 1.2, 0.95],
}
const FINGER_CHAINS := [["IndexFinger_01", "IndexFinger_02", "IndexFinger_03"], ["Finger_01", "Finger_02", "Finger_03"]]
const THUMB_CHAIN := ["Thumb_01", "Thumb_02", "Thumb_03"]
const FINGER_WEIGHTS: Array[float] = [1.0, 0.95, 0.8]
const THUMB_WEIGHTS: Array[float] = [0.35, 0.55, 0.5]

var skeleton: Skeleton3D
var _targets := {}
var _goals := {}
var _grips := {&"L": Grip.RELAXED, &"R": Grip.RELAXED}
var _curl := {&"L": 0.2, &"R": 0.2}
var _rest := {}
var _finger_bones := {}
var _applied_curl := {}


static func available() -> bool:
	return ResourceLoader.exists(ARMS_PATH)


func _ready() -> void:
	var model := (load(ARMS_PATH) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.rotation.y = PI
	model.position = MODEL_OFFSET
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var material := ShaderMaterial.new()
	material.shader = CHARACTER_SHADER
	material.set_shader_parameter("base_texture", load(ATLAS))
	material.set_shader_parameter("skin_mask", load(SKIN_MASK))
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ik := TwoBoneIK3D.new()
	ik.name = "ArmIK"
	skeleton.add_child(ik)
	ik.setting_count = 2
	for index in 2:
		var side := &"L" if index == 0 else &"R"
		var target := Marker3D.new()
		target.name = "%sPalmTarget" % side
		add_child(target)
		var pole := Marker3D.new()
		pole.name = "%sElbowPole" % side
		add_child(pole)
		# Elbows fall down and out to the sides of the view.
		pole.position = Vector3(-0.7 if side == &"L" else 0.7, -1.0, 0.3)
		ik.set_root_bone_name(index, "Shoulder_%s" % side)
		ik.set_middle_bone_name(index, "Elbow_%s" % side)
		ik.set_end_bone_name(index, "Hand_%s" % side)
		ik.set_extend_end_bone(index, true)
		# Left-side bones point along +X, the mirrored right side along -X.
		ik.set_end_bone_direction(index, 0 if side == &"L" else 1)
		ik.set_end_bone_length(index, PALM_REACH)
		ik.set_target_node(index, ik.get_path_to(target))
		ik.set_pole_node(index, ik.get_path_to(pole))
		_targets[side] = target
		_goals[side] = Vector3(-0.3 if side == &"L" else 0.3, -0.5, -0.6)
		target.position = _goals[side]
	for bone in skeleton.get_bone_count():
		_rest[bone] = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()


func set_hand(side: StringName, position_value: Vector3, grip: Grip) -> void:
	_goals[side] = position_value
	_grips[side] = grip


func snap() -> void:
	for side in _targets:
		(_targets[side] as Marker3D).position = _goals[side]
		_curl[side] = float((CURLS[_grips[side]] as Array)[0])
	_apply_fingers()


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-FOLLOW_RATE * delta)
	for side in _targets:
		var target := _targets[side] as Marker3D
		if not target.position.is_equal_approx(_goals[side]):
			target.position = target.position.lerp(_goals[side], weight)
		_curl[side] = lerpf(float(_curl[side]), float((CURLS[_grips[side]] as Array)[0]), weight)
	_apply_fingers()


func _apply_fingers() -> void:
	if skeleton == null:
		return
	if _finger_bones.is_empty():
		# Bone indices are looked up once rather than by name for every finger every frame.
		for side in [&"L", &"R"]:
			var chains: Array = []
			for chain in FINGER_CHAINS + [THUMB_CHAIN]:
				var bones: Array[int] = []
				for segment in (chain as Array).size():
					bones.append(skeleton.find_bone("%s_%s" % [chain[segment], side]))
				chains.append(bones)
			_finger_bones[side] = chains
	for side in [&"L", &"R"]:
		var amount := float(_curl[side])
		# A settled grip leaves the finger poses as they are.
		if absf(amount - float(_applied_curl.get(side, -1.0))) < 0.0005:
			continue
		_applied_curl[side] = amount
		var closed := amount / maxf(float((CURLS[Grip.GRIP] as Array)[0]), 0.01)
		var chains := _finger_bones[side] as Array
		for chain_index in chains.size():
			var thumb := chain_index == chains.size() - 1
			var bones := chains[chain_index] as Array[int]
			for segment in bones.size():
				_curl_bone(bones[segment], Vector3(0, 0, 1), -(closed * THUMB_WEIGHTS[segment] if thumb else amount * FINGER_WEIGHTS[segment]))


func _curl_bone(bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0:
		return
	skeleton.set_bone_pose_rotation(bone, (_rest[bone] as Quaternion) * Quaternion(axis, angle))
