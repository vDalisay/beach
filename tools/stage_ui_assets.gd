extends SceneTree
## Stages the interface sprites, input icons, particle textures and icon models the UI pass uses,
## straight from the local Synty source archives. Licensed files stay local: everything lands
## under res://art/synty/ (git-ignored), like the 3D art staged by stage_assets.gd.
##
##   godot --headless --path . -s res://tools/stage_ui_assets.gd
##   godot --headless --path . --editor --import
##
## Re-running it rewrites nothing that is already identical. 2D sprites import lossless with
## mipmaps (they are drawn well below their 256–512 px source size); particle textures and icon
## palettes import like the rest of the 3D art.

const PACKS := {
	"menus": "res://Assets/Synty/INTERFACE_Modern_Menus_SourceFiles_v1.zip",
	"icons": "res://Assets/Synty/POLYGON_Icons_SourceFiles_v3.zip",
	"fx": "res://Assets/Synty/POLYGON_Particle_FX_SourceFiles_v2.zip",
}
const UI_ROOT := "res://art/synty/ui/"
const FX_ROOT := "res://art/synty/fx/"
const ICON_MODEL_ROOT := "res://art/synty/icon_models/"

## POLYGON Icons models rendered by IconStudio (sorting categories, stations, HUD accents).
const ICON_MODELS := [
	"Trash_01", "Glass_01", "Food_Apple_01", "Food_Soda_Cup_01", "Food_Tuna_Can_01", "Paper_01",
	"Shopping_Cart_01", "Megaphone_01", "Phone_01", "Island_01", "Weather_Sun_01", "Weather_Wind_01",
	"Food_Fish_Raw_01", "Butterfly_01", "Heart_01", "MagnifyingGlass_01", "Magnet_01", "Key_01",
	"Baggie_01", "Basket_01", "Gem_01", "Coin_01", "Coins_01", "Star_01", "Trophy_01", "Present_01",
	"Crafting_Book_01", "Crafting_Cloth_01", "Crafting_Leaf_01", "Wrench_01", "Tick_01", "Location_01",
	"Flag_01", "Home_01", "Bell_01", "Hourglass_01", "Stopwatch_01", "Food_Coffee_Cup_01",
]
## Particle FX meshes used as 3D confetti pieces.
const FX_MODELS := ["FX_Money_Coin_01", "FX_Star", "FX_Heart_01"]
## Modern Menus general sprites (the rest of that folder is sci-fi framing we do not use).
const GENERAL_SPRITES := [
	"SPR_ModernMenus_Menu_Gradient_Vignette_01", "SPR_ModernMenus_Menu_Background_Vignette_01",
	"SPR_ModernMenus_Menu_Ring_Loading_01", "SPR_ModernMenus_Menu_Shield_01",
	"SPR_ModernMenus_Menu_Arrow_05_Underlay", "SPR_ModernMenus_Menu_Arrow_05_Clean",
	"SPR_ModernMenus_Menu_Triangle_Small_01", "SPR_ModernMenus_Menu_Ring_Small_01",
]
const MENU_SPRITES := [
	"SPR_ModernMenus_Box_Selected_05_Gold_Front", "SPR_ModernMenus_Box_Selected_02_Front",
	"SPR_ModernMenus_Banner_01",
]

var _errors: PackedStringArray = []
var _written := 0
var _unchanged := 0


func _init() -> void:
	var readers := {}
	for pack in PACKS:
		var reader := ZIPReader.new()
		var path := ProjectSettings.globalize_path(PACKS[pack])
		if reader.open(path) != OK:
			_errors.append("Missing Synty source archive: %s" % path)
			continue
		readers[pack] = reader
	if _errors.is_empty():
		_stage_all(readers)
	for reader in readers.values():
		(reader as ZIPReader).close()
	print("stage_ui_assets: %d written, %d unchanged" % [_written, _unchanged])
	if not _errors.is_empty():
		for message in _errors:
			push_error(message)
		quit(1)
		return
	quit(0)


func _stage_all(readers: Dictionary) -> void:
	var menus := readers["menus"] as ZIPReader
	var menu_files := menus.get_files()
	_copy_matching(menus, menu_files, "Sprites/Icons_ModernMenus_Flat/*_Stroke.png", UI_ROOT + "icons_flat/", true)
	_copy_matching(menus, menu_files, "Sprites/Icons_ModernMenus/SPR_ModernMenus_Icon_*_Ortho.png", UI_ROOT + "icons_3d/", true)
	_copy_matching(menus, menu_files, "Core/Icons_Input/MouseKeyboard/*_Underlay.png", UI_ROOT + "input/", true)
	_copy_matching(menus, menu_files, "Core/Icons_Input/Xbox/*_Underlay.png", UI_ROOT + "input/", true)
	_copy_matching(menus, menu_files, "Core/Icons_Input/GamepadGeneric/*Stick*_Underlay.png", UI_ROOT + "input/", true)
	_copy_matching(menus, menu_files, "Sprites/Cursors/*.png", UI_ROOT + "cursors/", true)
	_copy_matching(menus, menu_files, "Sprites/FX/*.png", UI_ROOT + "fx/", true)
	for sprite in GENERAL_SPRITES:
		_copy_one(menus, "Sprites/General/%s.png" % sprite, UI_ROOT + "general/", true)
	for sprite in MENU_SPRITES:
		_copy_one(menus, "Sprites/ModernMenus/%s.png" % sprite, UI_ROOT + "general/", true)

	var fx := readers["fx"] as ZIPReader
	_copy_matching(fx, fx.get_files(), "Source Files/Textures/*.png", FX_ROOT, false)
	for model in FX_MODELS:
		_copy_one(fx, "Source Files/FBX/%s.fbx" % model, FX_ROOT, false)

	var icons := readers["icons"] as ZIPReader
	_copy_one(icons, "_SourceFiles/Textures/PolygonIcons_Texture_01_A.png", ICON_MODEL_ROOT, false)
	for model in ICON_MODELS:
		_copy_one(icons, "_SourceFiles/FBX/SM_Icon_%s.fbx" % model, ICON_MODEL_ROOT, false)


func _copy_matching(reader: ZIPReader, files: PackedStringArray, pattern: String, target_folder: String, ui_texture: bool) -> void:
	var found := 0
	for file in files:
		if file.match(pattern):
			_copy_one(reader, file, target_folder, ui_texture)
			found += 1
	if found == 0:
		_errors.append("No archive entries match %s" % pattern)


func _copy_one(reader: ZIPReader, entry: String, target_folder: String, ui_texture: bool) -> void:
	if not reader.file_exists(entry):
		_errors.append("Missing archive entry: %s" % entry)
		return
	var bytes := reader.read_file(entry)
	var target := target_folder + entry.get_file()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_folder))
	if FileAccess.file_exists(target) and FileAccess.get_file_as_bytes(target) == bytes:
		_unchanged += 1
	else:
		var output := FileAccess.open(target, FileAccess.WRITE)
		if output == null:
			_errors.append("Cannot write %s" % target)
			return
		output.store_buffer(bytes)
		output.close()
		_written += 1
	if target.get_extension() == "png":
		_configure_texture_import(target, ui_texture)


func _configure_texture_import(path: String, ui_texture: bool) -> void:
	var settings := ConfigFile.new()
	settings.load(path + ".import")
	var before := settings.encode_to_text()
	settings.set_value("remap", "importer", "texture")
	settings.set_value("remap", "type", "CompressedTexture2D")
	# UI: lossless so rims and keycap letters stay clean. 3D: VRAM-compressed like the rest.
	settings.set_value("params", "compress/mode", 0 if ui_texture else 2)
	settings.set_value("params", "mipmaps/generate", true)
	settings.set_value("params", "detect_3d/compress_to", 0)
	if settings.encode_to_text() != before and settings.save(path + ".import") != OK:
		_errors.append("Cannot configure texture import: %s" % path)
