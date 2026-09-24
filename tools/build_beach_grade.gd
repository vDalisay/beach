extends SceneTree

const SIZE := 32


func _init() -> void:
	# The dummy headless renderer cannot read ImageTexture3D slices for ResourceSaver.
	if DisplayServer.get_name() == "headless":
		push_error("Build the LUT with the real Compatibility renderer (omit --headless).")
		quit(1)
		return
	var identity := "--identity" in OS.get_cmdline_user_args()
	var slices: Array[Image] = []
	for blue in SIZE:
		var slice := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBH)
		for green in SIZE:
			for red in SIZE:
				var c := Vector3(red, green, blue) / float(SIZE - 1)
				var result := c if identity else grade(c)
				slice.set_pixel(red, green, Color(result.x, result.y, result.z))
		slices.append(slice)
	var texture := ImageTexture3D.new()
	var error := texture.create(Image.FORMAT_RGBH, SIZE, SIZE, SIZE, false, slices)
	if error == OK and texture.get_data().size() != SIZE:
		error = ERR_CANT_CREATE
	var path := "res://art/look/beach_identity.res" if identity else "res://art/look/beach_grade.res"
	if error == OK:
		error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error == OK:
		error = ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Cannot build beach grade: %s" % error_string(error))
	print("BEACH_GRADE size=%d identity=%s path=%s status=%s" % [SIZE, identity, path, error_string(error)])
	quit(error)


func grade(c: Vector3) -> Vector3:
	# Compatibility's native LUT is sampled in display space, after its tonemapper.
	var luma := c.dot(Vector3(0.2126, 0.7152, 0.0722))
	var neutral := 1.0 - smoothstep(0.10, 0.35, maxf(c.x, maxf(c.y, c.z)) - minf(c.x, minf(c.y, c.z)))
	var shadow := 1.0 - smoothstep(0.08, 0.45, luma)
	var highlight := smoothstep(0.55, 0.95, luma)
	var tint := shadow * Vector3(0.004, 0.0, 0.010) + highlight * Vector3(0.010, 0.004, -0.010)
	tint *= smoothstep(0.0, 0.08, luma) * (1.0 - smoothstep(0.95, 1.0, luma))
	return (c + neutral * tint).clamp(Vector3.ZERO, Vector3.ONE)
