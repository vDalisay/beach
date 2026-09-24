extends SceneTree

const MANIFEST_PATH := "res://data/asset_manifest.json"
const SOURCE_PREFIXES := {
	"res://POLYGON_Palm_City/": "res://Assets/Synty/POLYGON_Palm_City/",
	"res://shaders/": "res://Assets/Synty/shaders/",
}
const STAGED_PREFIX := "res://art/synty/"
const TEXT_EXTENSIONS := ["tscn", "tres", "gdshader"]
const PROJECT_SHADERS := {
	"res://shaders/polygon.gdshader": "res://shaders/beach_polygon.gdshader",
	"res://shaders/foliage.gdshader": "res://shaders/beach_foliage.gdshader",
}

var _reference_regex := RegEx.new()
var _errors: PackedStringArray = []
var _staged_paths: PackedStringArray = []


func _init() -> void:
	_reference_regex.compile('path="(res://[^"]+)"')
	var manifest: Dictionary = _load_manifest()
	if manifest.is_empty():
		_finish()
		return

	var pending: Array[String] = []
	for path in manifest.get("extra_resources", []):
		pending.append(str(path))
	var scene_root: String = str(manifest.get("source_scene_root", ""))
	for asset_value in manifest.get("assets", []):
		var asset := asset_value as Dictionary
		for component_value in asset.get("components", []):
			var component := component_value as Dictionary
			var scene_name := str(component.get("source_scene", ""))
			if not _is_safe_relative_path(scene_name):
				_errors.append("Unsafe source scene path: %s" % scene_name)
				continue
			pending.append(scene_root + scene_name)

	var seen: Dictionary = {}
	while not pending.is_empty():
		var source_path: String = pending.pop_front()
		if seen.has(source_path):
			continue
		seen[source_path] = true
		for dependency in _stage_resource(source_path):
			if not seen.has(dependency):
				pending.append(dependency)

	if _errors.is_empty():
		for asset_value in manifest.get("assets", []):
			_write_wrapper(asset_value as Dictionary, scene_root)
		_write_hash_index()

	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_errors.append("Missing manifest: %s" % MANIFEST_PATH)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_errors.append("Manifest is not a JSON object: %s" % MANIFEST_PATH)
		return {}
	return parsed as Dictionary


func _stage_resource(source_path: String) -> PackedStringArray:
	var dependencies: PackedStringArray = []
	var local_source: String = _local_source_path(source_path)
	var target_path: String = _staged_path(source_path)
	if local_source.is_empty() or target_path.is_empty():
		_errors.append("Unsupported resource root: %s" % source_path)
		return dependencies
	if source_path.contains("/../") or source_path.ends_with("/.."):
		_errors.append("Resource path escapes its source root: %s" % source_path)
		return dependencies
	if not FileAccess.file_exists(local_source):
		_errors.append("Missing source dependency: %s" % local_source)
		return dependencies

	_make_parent_directory(target_path)
	if source_path.get_extension().to_lower() in TEXT_EXTENSIONS:
		var content: String = FileAccess.get_file_as_string(local_source)
		for match_result in _reference_regex.search_all(content):
			var dependency: String = match_result.get_string(1)
			if _staged_path(dependency).is_empty():
				_errors.append("Unrecognized dependency root in %s: %s" % [source_path, dependency])
			else:
				dependencies.append(dependency)
		content = _rewrite_resource_declarations(content)
		# These supplied material options require project-specific normal/lighting settings.
		content = content.replace("shader_parameter/enable_triplanar_normals = true", "shader_parameter/enable_triplanar_normals = false")
		if source_path == "res://POLYGON_Palm_City/materials/PalmTree_01.tres":
			for feature in ["emission", "light_wind", "strong_wind", "wind_twist"]:
				content = content.replace("shader_parameter/enable_%s = true" % feature, "shader_parameter/enable_%s = false" % feature)
			content = content.replace("shader_parameter/breeze_strength = 0.2", "shader_parameter/breeze_strength = 0.025")
			content = content.replace("shader_parameter/trunk_smoothness = 0.2", "shader_parameter/trunk_smoothness = 0.05")
		var output: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
		if output == null:
			_errors.append("Cannot write staged resource: %s" % target_path)
			return dependencies
		output.store_string(content)
	else:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(local_source)
		var output: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
		if output == null:
			_errors.append("Cannot write staged resource: %s" % target_path)
			return dependencies
		output.store_buffer(bytes)
		if source_path.get_file() in ["Sand_01.png", "Noise_Small.png", "WaterNormals_01.png", "caustic_height.png", "Fan_01.tga", "Fan_01_Normals.png", "PalmBark_02.png", "PalmBark_02_Normals.png"]:
			# Sampler mipmap hints cannot create mip levels. Preserve these import settings on clean staging too.
			var settings := ConfigFile.new()
			settings.load(target_path + ".import")
			settings.set_value("remap", "importer", "texture")
			settings.set_value("remap", "type", "CompressedTexture2D")
			settings.set_value("params", "mipmaps/generate", true)
			if settings.save(target_path + ".import") != OK:
				_errors.append("Cannot configure mipmaps: %s" % target_path)

	_staged_paths.append(target_path)
	return dependencies


func _rewrite_resource_declarations(content: String) -> String:
	var lines: PackedStringArray = content.split("\n")
	for index in lines.size():
		if not lines[index].begins_with("[ext_resource"):
			continue
		var project_shader := false
		for source in PROJECT_SHADERS:
			if lines[index].contains('path="%s"' % source):
				lines[index] = lines[index].replace('path="%s"' % source, 'path="%s"' % PROJECT_SHADERS[source])
				project_shader = true
				break
		if project_shader:
			continue
		lines[index] = lines[index].replace('path="res://POLYGON_Palm_City/', 'path="res://art/synty/POLYGON_Palm_City/')
		lines[index] = lines[index].replace('path="res://shaders/', 'path="res://art/synty/shaders/')
	return "\n".join(lines)


func _write_wrapper(asset: Dictionary, scene_root: String) -> void:
	var asset_id: String = str(asset.get("id", ""))
	var wrapper_path: String = str(asset.get("wrapper_scene", ""))
	if asset_id.is_empty() or not wrapper_path.begins_with(STAGED_PREFIX) or not wrapper_path.ends_with(".tscn"):
		_errors.append("Invalid wrapper declaration for asset: %s" % asset_id)
		return

	var components := asset.get("components", []) as Array
	var material_count := 0
	for component_value in components:
		if (component_value as Dictionary).has("material_override"):
			material_count += 1
	var lines: PackedStringArray = ["[gd_scene load_steps=%d format=3]" % (components.size() + material_count + 1), ""]
	for index in components.size():
		var component := components[index] as Dictionary
		var dependency := scene_root + str(component.get("source_scene", ""))
		lines.append('[ext_resource type="PackedScene" path="%s" id="%d_asset"]' % [_staged_path(dependency), index + 1])
	for index in components.size():
		var component := components[index] as Dictionary
		if not component.has("material_override"):
			continue
		var material := component.get("material_override") as Dictionary
		var color := _color(material.get("albedo_color", [1.0, 1.0, 1.0, 0.5]))
		lines.append("")
		lines.append('[sub_resource type="StandardMaterial3D" id="Material_%d"]' % index)
		lines.append("transparency = 1")
		lines.append("cull_mode = 2")
		lines.append("albedo_color = %s" % _color_literal(color))
		lines.append("metallic = %s" % float(material.get("metallic", 0.0)))
		lines.append("roughness = %s" % float(material.get("roughness", 0.5)))
	lines.append("")
	lines.append('[node name="%s" type="Node3D"]' % _node_name(asset_id))
	lines.append("")
	lines.append('[node name="Visual" type="Node3D" parent="."]')
	var visual_position: Vector3 = _vector3(asset.get("visual_position", [0.0, 0.0, 0.0]))
	if visual_position != Vector3.ZERO:
		lines.append("position = %s" % _vector3_literal(visual_position))
	for index in components.size():
		var component := components[index] as Dictionary
		lines.append("")
		lines.append('[node name="%s" parent="Visual" instance=ExtResource("%d_asset")]' % [_node_name(str(component.get("name", "Part%d" % index))), index + 1])
		if component.has("material_override"):
			lines.append('material_override = SubResource("Material_%d")' % index)

	_make_parent_directory(wrapper_path)
	var output: FileAccess = FileAccess.open(wrapper_path, FileAccess.WRITE)
	if output == null:
		_errors.append("Cannot write wrapper: %s" % wrapper_path)
		return
	output.store_string("\n".join(lines) + "\n")
	_staged_paths.append(wrapper_path)


func _write_hash_index() -> void:
	_staged_paths.sort()
	var rows: Array[Dictionary] = []
	for path in _staged_paths:
		rows.append({"path": path, "sha256": _sha256(FileAccess.get_file_as_bytes(path))})
	var serialized: String = JSON.stringify(rows, "  ") + "\n"
	var index_path: String = STAGED_PREFIX + "stage_hashes.json"
	_make_parent_directory(index_path)
	var output: FileAccess = FileAccess.open(index_path, FileAccess.WRITE)
	if output == null:
		_errors.append("Cannot write stage index: %s" % index_path)
		return
	output.store_string(serialized)
	print("STAGED %d files; closure_sha256=%s" % [_staged_paths.size(), _sha256(serialized.to_utf8_buffer())])


func _local_source_path(source_path: String) -> String:
	for prefix in SOURCE_PREFIXES:
		if source_path.begins_with(prefix):
			return str(SOURCE_PREFIXES[prefix]) + source_path.trim_prefix(prefix)
	return ""


func _staged_path(source_path: String) -> String:
	for prefix in SOURCE_PREFIXES:
		if source_path.begins_with(prefix):
			return STAGED_PREFIX + source_path.trim_prefix("res://")
	return ""


func _is_safe_relative_path(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not path.contains("..") and path.get_extension() == "tscn"


func _make_parent_directory(path: String) -> void:
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK and error != ERR_ALREADY_EXISTS:
		_errors.append("Cannot create directory for %s: %s" % [path, error_string(error)])


func _vector3(value: Variant) -> Vector3:
	var values: Array = value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _color(value: Variant) -> Color:
	var values: Array = value as Array
	return Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _vector3_literal(value: Vector3) -> String:
	return "Vector3(%s, %s, %s)" % [value.x, value.y, value.z]


func _color_literal(value: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [value.r, value.g, value.b, value.a]


func _node_name(value: String) -> String:
	return value.to_pascal_case().validate_node_name()


func _sha256(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _finish() -> void:
	if _errors.is_empty():
		quit(0)
		return
	for message in _errors:
		push_error(message)
	quit(1)
