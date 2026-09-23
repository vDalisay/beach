extends Node3D

const MANIFEST_PATH := "res://data/asset_manifest.json"
const MISSING_ASSET_SCENE := preload("res://art/placeholders/missing_asset.tscn")

@onready var staged_assets: Node3D = %StagedAssets
@onready var missing_assets: Node3D = %MissingAssets
@onready var summary_label: Label = %SummaryLabel


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_error("Asset gallery could not parse %s" % MANIFEST_PATH)
		return
	var manifest := parsed as Dictionary
	_load_staged_assets(manifest.get("assets", []) as Array)
	_load_missing_assets(manifest.get("missing_assets", []) as Array)
	summary_label.text = "%d staged roles · %d explicit placeholders" % [staged_assets.get_child_count(), missing_assets.get_child_count()]
	if "--capture-items" in OS.get_cmdline_user_args():
		var camera := $Camera as Camera3D
		camera.global_position = Vector3(-6, 1.8, 11.2)
		camera.look_at(Vector3(-6, 0.25, 8.0))
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://docs/handoffs/images/P13-synty-items.png")
		if get_viewport().get_texture().get_image().save_png(path) != OK:
			push_error("Could not capture Synty item row")
		get_tree().quit()


func _load_staged_assets(assets: Array) -> void:
	for asset_value in assets:
		var asset := asset_value as Dictionary
		var wrapper_path := str(asset.get("wrapper_scene", ""))
		var packed := load(wrapper_path) as PackedScene
		if packed == null:
			push_error("Missing staged wrapper: %s" % wrapper_path)
			continue
		var instance := packed.instantiate() as Node3D
		instance.position = _vector3(asset.get("gallery_position", [0.0, 0.0, 0.0]))
		staged_assets.add_child(instance)
		_add_label(instance, str(asset.get("label", asset.get("id", "Asset"))), float(asset.get("label_height", 1.0)))


func _load_missing_assets(entries: Array) -> void:
	for index in entries.size():
		var entry := entries[index] as Dictionary
		var instance := MISSING_ASSET_SCENE.instantiate() as MissingAsset
		instance.configure(entry)
		instance.position = Vector3(-7.5 + float(index % 6) * 3.0, 0.0, -12.0 - float(index / 6) * 2.5)
		missing_assets.add_child(instance)


func _add_label(parent: Node3D, text: String, height: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position.y = height
	label.font_size = 32
	label.outline_size = 8
	label.outline_modulate = Color(0.04, 0.06, 0.08, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)


func _vector3(value: Variant) -> Vector3:
	var values: Array = value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
