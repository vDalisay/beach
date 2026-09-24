# J03 — Living hands: viewmodel rig, locomotion, clips and equip

Dependencies: J00, and J01 for `HoverHighlight`, which marks the selected held prop. Read first: [plan](../12-game-feel.md) §2 pillar 6 (no camera motion), §4 rules 2, 4, 5 and 12, and §8. Also [C08 hand fit](../../handoffs/C08.md#beach-hand-views--24-september-2026) and [P04](P04-player.md) step 3.

**Outcome:**

- The hands, bag and tool have weight:
  - a figure-eight walking bob
  - a lagging sway when looking
  - idle breathing
  - a dip on landing
  - a slow float while swimming
  - heavier motion with a large prop
- Short procedural clips (poke, reach, place, toss, wipe, slash, dig, sift, recoil, reject and others) play on either arm.
- Tools drop away and rise in when switched.
- The bag swells as it fills and squashes when litter lands in it.
- The selected held prop lifts slightly so the player sees which one LMB will place.
- The camera never moves. Only the viewmodel does.

**Own files:**

| File | Change |
|---|---|
| `scenes/player/player.tscn` | `HandRig` subtree |
| `scripts/player/hand_rig.gd` | Rewrite, same public API plus additions |
| `scripts/player/viewmodel_animator.gd` | New |
| `scripts/player/player.gd` | Wiring |
| `scripts/core/progression.gd` | Pass `tool_id`, `equip` cue |
| `scripts/player/carry.gd` | Bag fill, selection indicator |

## Steps

### 1. Restructure the hand rig (same on-screen positions)

Add a `Sway` pivot at the camera origin and two arm pivots at "elbow" points. Arm rotations then swing forearms and tools naturally instead of orbiting the eye. Child offsets are chosen so every socket keeps its current camera-space position (C08's fitted values):

- `RightArm` pivot: (0.30, −0.50, −0.45)
- `LeftArm` pivot: (−0.30, −0.50, −0.45)

Replace the `HandRig` subtree of `scenes/player/player.tscn` with the text below. Add `[ext_resource type="Script" path="res://scripts/player/viewmodel_animator.gd" id="9_viewmodel"]` to the header and raise `load_steps` by one. Prefer doing this in the editor (reparent, then check the values below), then diff the saved file against this listing.

```text
[node name="HandRig" type="Node3D" parent="Head/Camera" node_paths=PackedStringArray("bag_socket", "tool_socket", "left_prop_socket", "right_prop_socket", "large_prop_socket", "bag_placeholder", "sway", "left_arm", "right_arm", "animator")]
unique_name_in_owner = true
script = ExtResource("4_hands")
bag_socket = NodePath("Sway/LeftArm/BagSocket")
tool_socket = NodePath("Sway/RightArm/ToolSocket")
left_prop_socket = NodePath("Sway/LeftArm/LeftPropSocket")
right_prop_socket = NodePath("Sway/RightArm/RightPropSocket")
large_prop_socket = NodePath("Sway/LargePropSocket")
bag_placeholder = NodePath("Sway/LeftArm/BagSocket/BagPlaceholder")
sway = NodePath("Sway")
left_arm = NodePath("Sway/LeftArm")
right_arm = NodePath("Sway/RightArm")
animator = NodePath("ViewmodelAnimator")

[node name="Sway" type="Node3D" parent="Head/Camera/HandRig"]

[node name="LeftArm" type="Node3D" parent="Head/Camera/HandRig/Sway"]
position = Vector3(-0.3, -0.5, -0.45)

[node name="LeftHandAnchor" type="Node3D" parent="Head/Camera/HandRig/Sway/LeftArm"]
position = Vector3(-0.06, 0.06, -0.27)
rotation = Vector3(-0.18, -0.12, -0.08)

[node name="LeftHand" parent="Head/Camera/HandRig/Sway/LeftArm/LeftHandAnchor" instance=ExtResource("8_hand")]
scale = Vector3(-0.75, 0.75, 0.75)

[node name="Label" type="Label3D" parent="Head/Camera/HandRig/Sway/LeftArm/LeftHandAnchor"]
visible = false
position = Vector3(0, 0.071, 0.03)
text = "HAND"
font_size = 20
pixel_size = 0.0015
outline_size = 4

[node name="BagSocket" type="Marker3D" parent="Head/Camera/HandRig/Sway/LeftArm"]
position = Vector3(-0.13, 0.12, -0.33)
rotation = Vector3(-0.1, -0.18, 0)

[node name="BagPlaceholder" type="Node3D" parent="Head/Camera/HandRig/Sway/LeftArm/BagSocket"]

[node name="SyntyBag" parent="Head/Camera/HandRig/Sway/LeftArm/BagSocket/BagPlaceholder" instance=ExtResource("7_bag")]
position = Vector3(0, -0.17, 0)
scale = Vector3(0.45, 0.5, 0.35)

[node name="Label" type="Label3D" parent="Head/Camera/HandRig/Sway/LeftArm/BagSocket/BagPlaceholder"]
visible = false
position = Vector3(0, 0, 0.1)
text = "BAG"
font_size = 22
pixel_size = 0.0018
outline_size = 5

[node name="LeftPropSocket" type="Marker3D" parent="Head/Camera/HandRig/Sway/LeftArm"]
position = Vector3(-0.01, 0.09, -0.28)

[node name="RightArm" type="Node3D" parent="Head/Camera/HandRig/Sway"]
position = Vector3(0.3, -0.5, -0.45)

[node name="RightHandAnchor" type="Node3D" parent="Head/Camera/HandRig/Sway/RightArm"]
position = Vector3(0.06, 0.06, -0.27)
rotation = Vector3(-0.18, 0.12, 0.08)

[node name="RightHand" parent="Head/Camera/HandRig/Sway/RightArm/RightHandAnchor" instance=ExtResource("8_hand")]
scale = Vector3(0.75, 0.75, 0.75)

[node name="Label" type="Label3D" parent="Head/Camera/HandRig/Sway/RightArm/RightHandAnchor"]
visible = false
position = Vector3(0, 0.071, 0.03)
text = "HAND"
font_size = 20
pixel_size = 0.0015
outline_size = 4

[node name="ToolSocket" type="Marker3D" parent="Head/Camera/HandRig/Sway/RightArm"]
position = Vector3(0.07, 0.16, -0.27)
rotation = Vector3(-0.16, 0.12, 0.04)

[node name="RightPropSocket" type="Marker3D" parent="Head/Camera/HandRig/Sway/RightArm"]
position = Vector3(0.01, 0.09, -0.28)

[node name="LargePropSocket" type="Marker3D" parent="Head/Camera/HandRig/Sway"]
position = Vector3(0.35, -0.48, -0.9)

[node name="ViewmodelAnimator" type="Node" parent="Head/Camera/HandRig"]
script = ExtResource("9_viewmodel")
```

Before any animation code, verify the restructure. Capture the default view at FOV 70 and 110 and compare it with the C08 stills (`docs/handoffs/images/C08-v1/default-70.png`): hands, bag and stick must be in the same places.

### 2. Rewrite `hand_rig.gd`

Keep every existing public method and its behaviour. `show_bag` must still set `visible` synchronously: `validate_carry.gd` reads it.

```gdscript
class_name HandRig
extends Node3D
## First-person hands, bag and tool sockets. Presentation only; ViewmodelAnimator moves them.

const FEEL := preload("res://data/feel/feel_tuning.tres")

@export var bag_socket: Marker3D
@export var tool_socket: Marker3D
@export var left_prop_socket: Marker3D
@export var right_prop_socket: Marker3D
@export var large_prop_socket: Marker3D
@export var bag_placeholder: Node3D
@export var sway: Node3D
@export var left_arm: Node3D
@export var right_arm: Node3D
@export var animator: ViewmodelAnimator

var _tool_scene: PackedScene
var _tool_id := StringName()
var _tool_instance: Node3D
var _tool_tip: Marker3D
var _small_visuals: Array[Node3D] = []


func show_bag(visible_value: bool) -> void:
	var was_visible := bag_placeholder.visible
	bag_placeholder.visible = visible_value
	if visible_value and not was_visible and animator != null:
		animator.play(&"bag_raise", &"left")


## Returns the live tool instance. Re-setting the same scene keeps the instance (no animation).
func set_tool_scene(scene: PackedScene, tool_id: StringName = &"") -> Node3D:
	if scene != null and scene == _tool_scene and is_instance_valid(_tool_instance) and _tool_instance.get_parent() == tool_socket:
		return _tool_instance
	_drop_current_tool(true)
	_tool_scene = scene
	_tool_id = tool_id
	if scene == null:
		return null
	_tool_instance = scene.instantiate() as Node3D
	if _tool_instance == null:
		return null
	tool_socket.add_child(_tool_instance)
	if animator != null:
		animator.play(&"equip_raise", &"right")
	return _tool_instance


func set_small_prop_scenes(left_scene: PackedScene, right_scene: PackedScene) -> Array[Node3D]:
	_small_visuals = [
		_replace_socket_scene(left_prop_socket, left_scene),
		_replace_socket_scene(right_prop_socket, right_scene),
	]
	return _small_visuals


func set_large_prop_scene(scene: PackedScene) -> Node3D:
	_drop_current_tool(true)
	_tool_scene = null
	_clear_socket(left_prop_socket)
	_clear_socket(right_prop_socket)
	_small_visuals = []
	show_bag(false)
	return _replace_socket_scene(large_prop_socket, scene)


func clear_carry_visuals() -> void:
	_clear_socket(left_prop_socket)
	_clear_socket(right_prop_socket)
	_clear_socket(large_prop_socket)
	_small_visuals = []


func clear_tool() -> void:
	_drop_current_tool(true)
	_tool_scene = null


## Socket transform in rig space (stable across the Sway/arm pivots).
func socket_transform(socket_name: StringName) -> Transform3D:
	var socket: Node3D = {
		&"bag": bag_socket, &"tool": tool_socket, &"left_prop": left_prop_socket,
		&"right_prop": right_prop_socket, &"large_prop": large_prop_socket,
	}.get(socket_name)
	return global_transform.affine_inverse() * socket.global_transform if socket != null else Transform3D.IDENTITY


func play_cue(cue: StringName, info: Dictionary) -> void:
	if animator != null:
		animator.on_cue(cue, info)


func active_tool_id() -> StringName:
	return _tool_id if is_instance_valid(_tool_instance) else StringName()


## Marker at the working end of the current tool (stick tip, vacuum nozzle); falls back to the socket.
func tool_tip() -> Node3D:
	if not is_instance_valid(_tool_instance):
		return tool_socket
	if not is_instance_valid(_tool_tip):
		_tool_tip = Marker3D.new()
		_tool_tip.name = "FeelTip"
		_tool_instance.add_child(_tool_tip)
		var tip_socket_space: Vector3 = FEEL.tool_tips.get(_tool_id, Vector3(0.0, 0.0, -0.3))
		_tool_tip.position = _tool_instance.transform.affine_inverse() * tip_socket_space
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


## Lifts the selected small prop in hand (index 0 = left, 1 = right).
func mark_selected(index: int, reduced: bool) -> void:
	for visual_index in _small_visuals.size():
		var visual := _small_visuals[visual_index]
		if not is_instance_valid(visual):
			continue
		var selected := visual_index == index and _small_visuals.size() > 1 and is_instance_valid(_small_visuals[1 - visual_index])
		var target := FEEL.held_selected_lift if selected else Vector3.ZERO
		HoverHighlight.set_active(visual, selected, HoverHighlight.Style.SOFT, reduced)
		if reduced:
			visual.position = target
		else:
			var t := FeelMotion.replace(visual, &"select", FeelMotion.tween(visual))
			t.tween_property(visual, "position", target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _drop_current_tool(animate: bool) -> void:
	_tool_tip = null
	if not is_instance_valid(_tool_instance):
		_tool_instance = null
		_clear_socket(tool_socket)
		return
	var old := _tool_instance
	_tool_instance = null
	var reduced := animator == null or FeelMotion.reduced(animator.settings)
	if not animate or reduced or sway == null:
		old.get_parent().remove_child(old)
		old.queue_free()
		return
	old.reparent(sway, true)
	var t := FeelMotion.tween(old)
	t.tween_property(old, "position:y", old.position.y - 0.28, FEEL.equip_drop_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(old, "rotation:x", old.rotation.x + 0.7, FEEL.equip_drop_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(old.queue_free)


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
		socket.remove_child(child)
		child.queue_free()
```

Why removal is immediate (`remove_child` before `queue_free`): `tool_socket.get_child_count()` is exactly 1 right after a switch, which `validate_purchases.gd` and `validate_release_pack.gd` read. The dropping tool now lives under `Sway` for 0.14 s, and the tip marker lives inside the tool instance.

### 3. Create `viewmodel_animator.gd`

```gdscript
class_name ViewmodelAnimator
extends Node
## Procedural first-person motion. Continuous locomotion drives Sway, one-shot clips
## drive the arm pivots (tweens), tool activity drives ToolSocket, springs drive the bag.
## Never moves the camera, never touches gameplay state.

const FEEL := preload("res://data/feel/feel_tuning.tres")
const E := 2.718281828

## Clip key: [seconds, position offset (m, arm space), rotation offset (deg), transition, ease].
## 0 seconds snaps. The last key returns to zero. Values are for the RIGHT arm; the left mirrors X.
const CLIPS := {
	&"poke": [
		[0.05, Vector3(0.0, 0.015, -0.13), Vector3(-8, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.03, Vector3(0.0, 0.015, -0.14), Vector3(-9, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.16, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"catch": [
		[0.05, Vector3(0.0, -0.012, 0.0), Vector3(3, 0, 0), Tween.TRANS_QUAD, Tween.EASE_OUT],
		[0.14, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]],
	&"reach": [
		[0.08, Vector3(-0.02, 0.03, -0.09), Vector3(-6, 4, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"place": [
		[0.08, Vector3(0.0, 0.02, -0.10), Vector3(-5, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.18, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"toss": [
		[0.07, Vector3(0.01, -0.02, 0.05), Vector3(10, 0, -4), Tween.TRANS_QUAD, Tween.EASE_OUT],
		[0.07, Vector3(-0.01, 0.05, -0.12), Vector3(-18, 0, 6), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"wipe": [
		[0.05, Vector3(0.03, 0.0, -0.04), Vector3(0, 0, 6), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.06, Vector3(0.0, 0.03, -0.05), Vector3(0, 0, -4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.06, Vector3(-0.03, 0.0, -0.04), Vector3(0, 0, 6), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.06, Vector3(0.0, -0.02, -0.03), Vector3(0, 0, -3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.12, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"slash": [
		[0.06, Vector3(0.04, 0.03, 0.02), Vector3(0, -10, 20), Tween.TRANS_QUAD, Tween.EASE_OUT],
		[0.08, Vector3(-0.08, -0.02, -0.06), Vector3(0, 12, -35), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"dig": [
		[0.08, Vector3(0.0, -0.05, -0.06), Vector3(-14, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.06, Vector3(0.0, -0.045, -0.05), Vector3(-12, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]],
	&"sift": [
		[0.07, Vector3(0.0, -0.04, -0.06), Vector3(-10, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.04, Vector3(0.012, -0.04, -0.06), Vector3(-10, 0, 3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.04, Vector3(-0.012, -0.04, -0.06), Vector3(-10, 0, -3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.04, Vector3(0.012, -0.04, -0.06), Vector3(-10, 0, 3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.18, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"recoil": [
		[0.03, Vector3(0.0, 0.0, 0.012), Vector3(2, 0, 0), Tween.TRANS_QUAD, Tween.EASE_OUT],
		[0.08, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_QUAD, Tween.EASE_IN_OUT]],
	&"choke": [
		[0.05, Vector3(0.006, 0.0, 0.0), Vector3(0, 0, 4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.05, Vector3(-0.006, 0.0, 0.0), Vector3(0, 0, -4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.05, Vector3(0.004, 0.0, 0.0), Vector3(0, 0, 3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.10, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"reject": [
		[0.05, Vector3.ZERO, Vector3(0, 4, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.05, Vector3.ZERO, Vector3(0, -4, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.05, Vector3.ZERO, Vector3(0, 2, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.08, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]],
	&"equip_raise": [
		[0.0, Vector3(0.0, -0.25, 0.05), Vector3(35, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.22, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]],
	&"bag_raise": [
		[0.0, Vector3(0.0, -0.20, 0.04), Vector3(30, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.20, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]],
}

var rig: HandRig
var body: CharacterBody3D
var movement: PlayerMovement
var input_reader: InputReader
var settings: SettingsStore

var _tool_rest := Transform3D.IDENTITY
var _bob_phase := 0.0
var _bob_weight := 0.0
var _look_rate := Vector2.ZERO
var _sway := Vector2.ZERO
var _sway_velocity := Vector2.ZERO
var _land := 0.0
var _land_velocity := 0.0
var _was_grounded := true
var _air_time := 0.0
var _activity_kind := StringName()
var _activity := 0.0
var _activity_target := 0.0
var _activity_until := 0
var _bag_fill_target := 0.0
var _bag_fill := 1.0
var _bag_fill_velocity := 0.0
var _bag_squash := Vector3.ZERO
var _bag_squash_velocity := Vector3.ZERO
var _bag_roll := 0.0
var _bag_roll_velocity := 0.0


func configure(hand_rig: HandRig, player_body: CharacterBody3D, player_movement: PlayerMovement, reader: InputReader) -> void:
	rig = hand_rig
	body = player_body
	movement = player_movement
	input_reader = reader
	_tool_rest = rig.tool_socket.transform
	_bag_fill = lerpf(FEEL.bag_fill_scale_empty, FEEL.bag_fill_scale_full, 0.0)


func on_cue(cue: StringName, info: Dictionary) -> void:
	var arm := StringName(str(info.get("arm", "right")))
	match cue:
		&"poke":
			play(&"poke", &"right")
		&"whiff":
			match rig.active_tool_id():
				&"stick": play(&"poke", &"right", 0.6)
				&"cloth": play(&"wipe", &"right", 0.5)
				&"knife": play(&"slash", &"right", 0.6)
		&"bag_catch":
			bag_catch(float(info.get("strength", 1.0)))
			play(&"catch", &"left", 0.6)
		&"rejected":
			if str(info.get("reason", "")).contains("Bag full"):
				bag_wobble()
				play(&"reject", &"left")
			else:
				play(&"reject", &"right")
		&"hold", &"hold_bag":
			play(&"reach", &"both", 1.3 if bool(info.get("large", false)) else 1.0)
		&"throw":
			play(&"toss", arm)
		&"place", &"deposit":
			play(&"place", arm)
		&"clean", &"clean_done":
			play(&"wipe", &"right")
		&"cut":
			play(&"slash", &"right")
		&"reveal":
			play(&"dig", &"right")
		&"sift":
			play(&"sift", &"right")
		&"vacuum_tick":
			play(&"recoil", &"right")
		&"vacuum_full":
			play(&"choke", &"right")


func play(clip: StringName, arm: StringName, strength := 1.0) -> void:
	var keys: Array = CLIPS.get(clip, [])
	if keys.is_empty() or rig == null:
		return
	var reduced := FeelMotion.reduced(settings)
	var amount := strength * (FEEL.reduced_clip_strength if reduced else 1.0)
	if arm == &"left" or arm == &"both":
		_play_on(rig.left_arm, keys, amount, true, reduced)
	if arm == &"right" or arm == &"both":
		_play_on(rig.right_arm, keys, amount, false, reduced)


func set_activity(kind: StringName, amount: float) -> void:
	_activity_kind = kind
	_activity_target = clampf(amount, 0.0, 1.0)
	_activity_until = Time.get_ticks_msec() + 120


func set_bag_fill(ratio: float) -> void:
	_bag_fill_target = clampf(ratio, 0.0, 1.0)


func bag_catch(strength := 1.0) -> void:
	var omega := TAU * FEEL.bag_spring_hz * 1.5
	_bag_squash_velocity += FEEL.bag_squash_kick * omega * E * strength


func bag_wobble() -> void:
	_bag_roll_velocity += deg_to_rad(10.0) * TAU * 3.0 * E


func _play_on(node: Node3D, keys: Array, amount: float, mirrored: bool, reduced: bool) -> void:
	var t := FeelMotion.replace(node, &"clip", FeelMotion.tween(node))
	for key in keys:
		var position := (key[1] as Vector3) * amount
		var rotation := (key[2] as Vector3) * amount
		if mirrored:
			position.x = -position.x
			rotation.y = -rotation.y
			rotation.z = -rotation.z
		var trans: int = key[3]
		if reduced and trans == Tween.TRANS_BACK:
			trans = Tween.TRANS_QUAD
		if float(key[0]) <= 0.0:
			node.position = position
			node.rotation_degrees = rotation
			continue
		t.tween_property(node, "position", position, float(key[0])).set_trans(trans).set_ease(key[4])
		t.parallel().tween_property(node, "rotation_degrees", rotation, float(key[0])).set_trans(trans).set_ease(key[4])


func _physics_process(delta: float) -> void:
	if input_reader == null or delta <= 0.0:
		return
	_look_rate = _look_rate.lerp(input_reader.look_delta / delta, 0.5)


func _process(delta: float) -> void:
	if rig == null or body == null or not rig.is_visible_in_tree() or delta <= 0.0:
		return
	var reduced := FeelMotion.reduced(settings)
	var time := Time.get_ticks_msec() * 0.001
	_update_locomotion(delta, reduced, time)
	_update_tool(delta, reduced, time)
	_update_bag(delta, reduced)
```

Complete the three update functions from these rules:

- **`_update_locomotion(delta, reduced, time)`**
  - Speed ratio: `speed_ratio = clamp(horizontal_speed / movement.walk_speed, 0, 1.6)`.
  - `grounded = body.is_on_floor() and not movement.is_swimming`.
  - Bob frequency: `FEEL.bob_hz`, × `bob_sprint_scale` when the ratio is above 1.2, × `bob_crouch_scale` when crouched.
  - Advance `_bob_phase` by `delta * TAU * hz` only while grounded and moving, and wrap it at `TAU * 2`.
  - `_bob_weight` lerps (`1 - exp(-8·delta)`) toward `bob_amplitude * min(ratio, 1.3)`, × `bob_carry_large_scale` when `movement.carry_speed_multiplier < 0.99`. It lerps toward 0 when not grounded.
  - Bob vector: `(sin(phase*0.5)·w, −|sin(phase*0.5)|·w·0.8, 0)`. This is a figure-eight: two vertical dips per horizontal swing.
  - Breathing: `(0, sin(time·TAU·idle_breath_hz)·idle_breath_amplitude, 0)`. While swimming, use a slow float of `swim_float_amplitude` at `swim_float_hz` on Y and 60% of that on X.
  - Look sway: the target pitch is `−_look_rate.y · sway_gain` and the target yaw is `−_look_rate.x · sway_gain`. Clamp each to ±`deg_to_rad(sway_max_degrees)`, then drive `_sway.x` (pitch) and `_sway.y` (yaw) with `FeelMotion.spring` at `sway_spring_hz`. `look_delta.x` is yaw and `.y` is pitch (see `BeachPlayer._apply_look`).
  - Landing: when `grounded and not _was_grounded and _air_time > 0.12`, set `peak = land_kick * clamp(_air_time / 0.5, 0.25, 1.0)` and `_land_velocity -= peak * TAU * land_spring_hz * E`. The spring peak then equals `peak`. Spring `_land` toward 0.
  - When reduced: `rig.sway.transform = Transform3D.IDENTITY` and return. Otherwise:
    ```gdscript
    rig.sway.position = bob + breathe + Vector3(0, _land, 0)
    rig.sway.rotation = Vector3(_sway.x, _sway.y, _sway.y * 0.5)
    ```
- **`_update_tool(delta, reduced, time)`**
  - If `Time.get_ticks_msec() > _activity_until`, set `_activity_target = 0`. Move `_activity` toward the target at 6/s.
  - Start the position and rotation offsets at zero. Unless reduced, fill them by activity kind:
    - `vacuum`: position `(sin(t·TAU·vacuum_jitter_hz)·j, sin(t·TAU·vacuum_jitter_hz·1.37 + 1.1)·j, −0.015·a)` with `j = vacuum_jitter·a`.
    - `detector`: rotation Y `sin(t·TAU·detector_sweep_hz)·deg_to_rad(detector_sweep_degrees)·(0.6 + 0.4·a)`.
    - `sand_cleaner`: rotation X `sin(t·TAU·1.2)·deg_to_rad(2)·a`.
  - `rig.tool_socket.transform = _tool_rest * Transform3D(Basis.from_euler(rotation), position)`.
- **`_update_bag(delta, reduced)`**
  - Spring `_bag_fill` toward `lerp(bag_fill_scale_empty, bag_fill_scale_full, _bag_fill_target)` at `bag_spring_hz`.
  - Spring `_bag_squash` (with `spring3`) toward zero at `bag_spring_hz·1.5`.
  - Spring `_bag_roll` toward 0 at 3 Hz.
  - When reduced, zero the squash and roll.
  - `rig.bag_placeholder.scale = Vector3(lerp(0.94, 1.06, fill_t) + sq.x, _bag_fill + sq.y, lerp(0.94, 1.06, fill_t) + sq.z)`, where `fill_t = _bag_fill_target`.
  - `rig.bag_placeholder.rotation.z = _bag_roll`.

### 4. Wire it

- `player.gd`, `_ready()`: after `movement.configure(...)`, call `hand_rig.animator.configure(hand_rig, self, movement, input_reader)`.
- `player.gd`, `configure(settings, ...)`: set `hand_rig.animator.settings = settings`.
- `progression.gd`, `refresh_tool_visual()`: call `player.hand_rig.set_tool_scene(scene, tool_id)`. Keep the grip transforms exactly as they are, applied to the returned instance.
- `progression.gd`: after a successful `try_switch_tool` and `try_equip`, call `player.play_cue(&"equip")`. The viewmodel already animated through `set_tool_scene`; the cue exists for rumble (J13).
- `carry.gd`, `configure()`: connect `session.items_changed` to `_on_bag_items_changed` (guard duplicates). It computes `(trash_bag.size() + valuable_bag.size()) / bag_capacity` from the player record and calls `hand_rig.set_bag_fill(ratio)`. Call it once at the end of `configure()`.
- `carry.gd`, `refresh_hand_visuals()`: after `_style_hand_visual(...)` for the two small visuals, call `hand_rig.mark_selected(int(_player_record().selected_held_index), FeelMotion.reduced(player.settings_store))`.
- `carry.gd`, `cycle_selected()`: after `finalize_action`, call the same `mark_selected`.

## Tuning notes

- Tune at FOV 70 and 110 while walking, sprinting, crouching, jumping, swimming, carrying one large prop and carrying two small props.
- No clip or bob may move a tool, prop or hand across the aim point. Keep the C08 rule: the centre of view stays clear.
- If the bob reads as nausea-inducing, lower `bob_amplitude` before touching frequency.
- Sway should feel like weight, not lag. If aiming feels sluggish, lower `sway_gain`.

## Reduced motion

- No bob, sway, breathing, landing dip, tool jitter or bag squash or roll.
- Clips play at 50% with no overshoot.
- Bag fill still follows the fill level; this is positional, and its motion is a slow spring.

## Validation

1. Re-run these checks:
   - `validate_movement.gd` (socket sides)
   - `validate_carry.gd` (bag visibility, hand counts)
   - `validate_purchases.gd` and `validate_release_pack.gd` (tool child count, `Visual/Shaft`)
   - `validate_dirt.gd` (single-argument `set_tool_scene`)
   - `validate_tool_filters.gd`
2. In `tests/scenes/movement_lab.tscn` (via `validate_movement.gd`, or a probe with the real player), record 10-second clips of:
   - walking
   - sprinting
   - a crouch walk
   - a jump and landing
   - swimming (main scene, the Z 45–62 water used in C08)
   - holding a chair
3. Capture the views at FOV 70 and 110 while moving.
4. In `scenes/main.tscn`, buy or stage the tools with a probe (state the staging in the handoff). Switch through the loadout and record the drop/raise. Pick up and release props and watch the tool come back up.
5. Fill the bag from 0 to 20 and record the bag growing. Cycle two held props with the mouse wheel and record the lift moving between hands.
6. Watch for a 10 s idle: breathing only, with no drift. The `Sway` transform returns exactly to identity when still and reduced motion is on.

## Done when

- The viewmodel has bob, sway, breathing, landing, swim and carry weight, and all clips play.
- Tool switch animates while the tests' one-child contract holds.
- Bag fill and squash work.
- The selected prop is visible.
- Nothing crosses the aim point at FOV 70 or 110.
- Reduced motion is observed.
- Checks pass.
- Clips are in J-feel.
