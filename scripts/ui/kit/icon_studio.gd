class_name IconStudio
extends Node
## Renders a 3D scene to a transparent texture once and caches it, so tools, items and props get
## icons that always match their in-game models, and POLYGON Icons models become flat icons.
## One hidden SubViewport renders one job per frame. `icon()` returns the texture at once; it is
## transparent until its frame has rendered, then fills in (TextureRects redraw on `changed`).
## Scripts on rendered scenes are stripped, so gameplay nodes never run here.

const ICON_MODEL_PATH := "res://art/synty/icon_models/SM_Icon_%s.fbx"
const ICON_PALETTE := "res://art/synty/icon_models/PolygonIcons_Texture_01_A.png"
## Three-quarter view from above and to the left, like a product shot.
const DEFAULT_VIEW := Vector3(-0.55, 0.5, 1.0)

var _cache := {}
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _palette_material: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.name = "IconViewport"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(128, 128)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.92, 0.95, 1.0)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	_viewport.add_child(fill)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)


func _exit_tree() -> void:
	# Pending jobs hold scenes and the palette; release them so nothing outlives the tree at quit.
	if RenderingServer.frame_post_draw.is_connected(_capture):
		RenderingServer.frame_post_draw.disconnect(_capture)
	_queue.clear()
	_cache.clear()
	_current = {}
	_palette_material = null
	for child in _stage.get_children():
		child.queue_free()


## Icon for any scene. `key` names it in the cache; `view` is the camera direction from the model.
func icon(key: String, scene: PackedScene, size := 128, view := DEFAULT_VIEW, material: Material = null, roll_degrees := 0.0) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var texture := ImageTexture.create_from_image(Image.create(size, size, false, Image.FORMAT_RGBA8))
	_cache[key] = texture
	if scene == null:
		return texture
	_queue.append({"scene": scene, "size": size, "view": view.normalized(), "texture": texture, "material": material, "roll": roll_degrees})
	if _current.is_empty():
		_next.call_deferred()
	return texture


## A POLYGON Icons model ("Trash_01", "Food_Apple_01"…) rendered head-on with the pack's palette.
func model_icon(model: String, size := 128) -> Texture2D:
	var path := ICON_MODEL_PATH % model
	if not ResourceLoader.exists(path):
		return icon("missing:" + model, null, size)
	if _palette_material == null:
		_palette_material = StandardMaterial3D.new()
		_palette_material.albedo_texture = load(ICON_PALETTE) as Texture2D
		_palette_material.roughness = 0.85
	return icon("model:" + model, load(path) as PackedScene, size, Vector3(-0.28, 0.2, 1.0), _palette_material)


## Stages the next job and asks for one render; `_capture` reads it after the frame is drawn.
## No coroutine waits on the frame, so a quit mid-job leaves nothing holding the job.
func _next() -> void:
	if not _current.is_empty() or not is_inside_tree():
		return
	while not _queue.is_empty():
		var job := _queue.pop_front() as Dictionary
		var node := (job.scene as PackedScene).instantiate()
		_strip_scripts(node)
		if not node is Node3D:
			node.free()
			continue
		var model := node as Node3D
		_stage.add_child(model)
		if job.material != null:
			for geometry in model.find_children("*", "GeometryInstance3D", true, false):
				(geometry as GeometryInstance3D).material_override = job.material as Material
		_frame(model, job.view as Vector3, float(job.roll))
		_viewport.size = Vector2i(int(job.size), int(job.size))
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		job["model"] = model
		_current = job
		RenderingServer.frame_post_draw.connect(_capture, CONNECT_ONE_SHOT)
		return


func _capture() -> void:
	if _current.is_empty():
		return
	var job := _current
	_current = {}
	var image := _viewport.get_texture().get_image()
	if image != null:
		image.generate_mipmaps()
		(job.texture as ImageTexture).set_image(image)
	var model := job.model as Node3D
	if is_instance_valid(model):
		_stage.remove_child(model)
		model.queue_free()
	if not _queue.is_empty():
		_next.call_deferred()


## Centres the model, looks at it from `view` (rolled about the view axis, so long tools can lie
## diagonally) and sizes the orthographic frame to the model's projected bounds.
func _frame(model: Node3D, view: Vector3, roll_degrees: float) -> void:
	var bounds := AABB()
	var first := true
	for geometry in model.find_children("*", "GeometryInstance3D", true, false):
		var visual := geometry as GeometryInstance3D
		var box := model.global_transform.affine_inverse() * visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first:
		bounds = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	model.position = -bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.01)
	_camera.near = 0.01
	_camera.far = radius * 6.0
	_camera.look_at_from_position(view * radius * 3.0, Vector3.ZERO, Vector3.UP)
	if roll_degrees != 0.0:
		_camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll_degrees))
	var extent := 0.0
	var to_camera := _camera.global_transform.affine_inverse()
	for corner in 8:
		var local := to_camera * (bounds.get_endpoint(corner) - bounds.get_center())
		extent = maxf(extent, maxf(absf(local.x), absf(local.y)))
	_camera.size = maxf(extent * 2.0 * 1.08, 0.01)


static func _strip_scripts(node: Node) -> void:
	for child in node.get_children():
		_strip_scripts(child)
	if node.get_script() != null:
		node.set_script(null)
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
