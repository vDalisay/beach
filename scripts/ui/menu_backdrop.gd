class_name MenuBackdrop
extends TextureRect
## Title-screen backdrop: the real beach (no run, so no litter) rendered into a half-resolution
## SubViewport with its own world, while a camera drifts through a loop of slow establishing
## shots. The frosted shade above it blurs the picture; each cut dips the blur up and back down so
## shots dissolve into one another. Freed completely before a run builds its own beach.

## Emitted halfway through a cut, while the picture is at its softest.
signal cut

const BEACH_SCENE := preload("res://scenes/world/beach.tscn")
const RESOLUTION_SCALE := 0.5
const CUT_SECONDS := 1.4
## [from, to, look_from, look_to, seconds]: a slow dolly per shot.
const SHOTS := [
	[Vector3(42.0, 15.0, 98.0), Vector3(-18.0, 12.0, 84.0), Vector3(12.0, 0.0, 0.0), Vector3(-22.0, 0.0, 0.0), 26.0],
	[Vector3(37.0, 4.6, 33.0), Vector3(47.0, 6.4, 47.0), Vector3(72.0, 9.0, 94.0), Vector3(72.0, 9.5, 94.0), 20.0],
	[Vector3(-73.0, 2.2, 15.0), Vector3(-55.0, 2.8, 22.0), Vector3(-20.0, 1.0, 10.0), Vector3(22.0, 2.0, 34.0), 22.0],
	[Vector3(102.0, 7.0, 50.0), Vector3(96.0, 8.5, 72.0), Vector3(62.0, 3.0, 58.0), Vector3(38.0, 2.0, 18.0), 20.0],
]

var frost: ShaderMaterial
var _viewport: SubViewport
var _camera: Camera3D
var _shot := 0
var _elapsed := 0.0
var _cut_elapsed := -1.0
var _base_blur := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func running() -> bool:
	return is_instance_valid(_viewport)


func start() -> void:
	if running():
		return
	_viewport = SubViewport.new()
	_viewport.name = "MenuWorld"
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = _viewport_size()
	add_child(_viewport)
	var beach := BEACH_SCENE.instantiate() as Node3D
	beach.name = "Beach"
	_viewport.add_child(beach)
	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.far = 900.0
	_viewport.add_child(_camera)
	_camera.current = true
	texture = _viewport.get_texture()
	if frost != null:
		_base_blur = float(frost.get_shader_parameter(&"blur_lod"))
	_shot = 0
	_elapsed = 0.0
	_cut_elapsed = -1.0
	_place_camera()
	get_viewport().size_changed.connect(_on_size_changed)
	set_process(true)


func stop() -> void:
	set_process(false)
	texture = null
	if get_viewport().size_changed.is_connected(_on_size_changed):
		get_viewport().size_changed.disconnect(_on_size_changed)
	if is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.free()
	_viewport = null
	_camera = null
	if frost != null:
		frost.set_shader_parameter(&"blur_lod", _base_blur)


func _viewport_size() -> Vector2i:
	var window := get_tree().root.size
	return Vector2i(maxi(int(window.x * RESOLUTION_SCALE), 320), maxi(int(window.y * RESOLUTION_SCALE), 180))


func _on_size_changed() -> void:
	if running():
		_viewport.size = _viewport_size()


func _process(delta: float) -> void:
	var duration := float(SHOTS[_shot][4])
	_elapsed += delta
	if _cut_elapsed < 0.0 and _elapsed >= duration - CUT_SECONDS * 0.5:
		_cut_elapsed = 0.0
	if _cut_elapsed >= 0.0:
		var before := _cut_elapsed
		_cut_elapsed += delta
		if before < CUT_SECONDS * 0.5 and _cut_elapsed >= CUT_SECONDS * 0.5:
			_shot = (_shot + 1) % SHOTS.size()
			_elapsed = 0.0
			cut.emit()
		if frost != null:
			# Blur dips up to its peak at the cut and settles back down.
			var peak := sin(clampf(_cut_elapsed / CUT_SECONDS, 0.0, 1.0) * PI)
			frost.set_shader_parameter(&"blur_lod", _base_blur + peak * 2.4)
		if _cut_elapsed >= CUT_SECONDS:
			_cut_elapsed = -1.0
	_place_camera()


func _place_camera() -> void:
	if _camera == null:
		return
	var shot := SHOTS[_shot] as Array
	var t := smoothstep(0.0, 1.0, clampf(_elapsed / float(shot[4]), 0.0, 1.0))
	var position := (shot[0] as Vector3).lerp(shot[1] as Vector3, t)
	var look := (shot[2] as Vector3).lerp(shot[3] as Vector3, t)
	_camera.look_at_from_position(position, look, Vector3.UP)
