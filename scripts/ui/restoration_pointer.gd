class_name RestorationPointer
extends Control
## A gold arrow with the distance to a restoration the player cannot see from where they are: on
## the screen edge when the spot is off screen or behind, above it when it is in view but far.
## It hides once the spot is in view and near, or after FEEL.pointer_seconds. Presentation only.

const FEEL := preload("res://data/feel/feel_tuning.tres")
# The edge arrow keeps this far in from the screen's top-left and bottom-right corners, clear of
# the HUD panels along the top and bottom.
const INSET_TOP_LEFT := Vector2(80.0, 140.0)
const INSET_BOTTOM_RIGHT := Vector2(80.0, 150.0)
# A spot projected inside the screen shrunk by this margin counts as on screen.
const ON_SCREEN_MARGIN := 40.0

## Set by main so the pulse follows the reduced-motion setting.
var settings: SettingsStore
var _arrow: FeelIcon
var _distance: Label
var _camera: Camera3D
var _target := Vector3.ZERO
var _left := 0.0
var _age := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow = FeelIcon.new()
	_arrow.name = "Arrow"
	_arrow.kind = FeelIcon.Kind.ARROW
	_arrow.color = FEEL.money_color
	_arrow.size = Vector2(28, 28)
	_arrow.pivot_offset = _arrow.size * 0.5
	add_child(_arrow)
	_distance = Label.new()
	_distance.name = "Distance"
	_distance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_distance.add_theme_color_override("font_color", FEEL.money_color)
	_distance.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.02, 0.9))
	_distance.add_theme_constant_override("outline_size", 6)
	_distance.add_theme_font_size_override("font_size", 16)
	add_child(_distance)
	clear()


func point_to(world_position: Vector3, camera: Camera3D, seconds := FEEL.pointer_seconds) -> void:
	_target = world_position
	_camera = camera
	_left = seconds
	_age = 0.0
	show()
	set_process(true)
	_process(0.0)


func clear() -> void:
	hide()
	set_process(false)
	_camera = null


func is_pointing() -> bool:
	return visible and _camera != null


func _process(delta: float) -> void:
	_left -= delta
	_age += delta
	if _left <= 0.0 or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		clear()
		return
	var center := size * 0.5
	var projected := _camera.unproject_position(_target)
	var behind := _camera.is_position_behind(_target)
	if behind:
		# Behind the camera the projection flips; mirror it so the arrow points the way to turn.
		projected = center * 2.0 - projected
	var distance := _camera.global_position.distance_to(_target)
	var view := Rect2(Vector2.ONE * ON_SCREEN_MARGIN, size - Vector2.ONE * ON_SCREEN_MARGIN * 2.0)
	var on_screen := not behind and view.has_point(projected)
	if on_screen and distance < FEEL.pointer_far_distance:
		clear()
		return
	var at: Vector2
	var label_at: Vector2
	_distance.text = "%d m" % roundi(distance)
	_distance.reset_size()
	if on_screen:
		# In view but far: hang above the spot, pointing down at it, with the distance on top.
		at = projected - Vector2(0.0, 30.0)
		_arrow.rotation = PI * 0.5
		label_at = at - Vector2(0.0, 30.0)
	else:
		var direction := projected - center
		if direction.length_squared() < 1.0:
			direction = Vector2.DOWN
		var box := Rect2(INSET_TOP_LEFT, size - INSET_TOP_LEFT - INSET_BOTTOM_RIGHT)
		at = _edge_point(center, direction, box)
		_arrow.rotation = direction.angle()
		# The distance sits on the arrow's inner side, toward the middle of the screen.
		label_at = at - direction.normalized() * 34.0
	_arrow.position = at - _arrow.size * 0.5
	var pulse := 1.0 if settings != null and FeelMotion.reduced(settings) else 1.075 - 0.075 * cos(_age * TAU * 1.5)
	_arrow.scale = Vector2.ONE * pulse
	_distance.position = label_at - _distance.size * 0.5


## Where the ray from `center` along `direction` leaves `box` (`center` lies inside it).
static func _edge_point(center: Vector2, direction: Vector2, box: Rect2) -> Vector2:
	var t := INF
	if direction.x > 0.0:
		t = minf(t, (box.end.x - center.x) / direction.x)
	elif direction.x < 0.0:
		t = minf(t, (box.position.x - center.x) / direction.x)
	if direction.y > 0.0:
		t = minf(t, (box.end.y - center.y) / direction.y)
	elif direction.y < 0.0:
		t = minf(t, (box.position.y - center.y) / direction.y)
	return center + direction * t
