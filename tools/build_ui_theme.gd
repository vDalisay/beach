extends SceneTree
## Builds res://data/ui/beach_theme.tres, the project-wide theme (gui/theme/custom). Edit the
## theme here, not in the .tres: this script is the single source of every style, font and colour.
##
##   godot --headless --path . -s res://tools/build_ui_theme.gd
##
## Look: the wordmark's navy-rimmed "sticker" pieces (StickerBox), Bungee for display text,
## Barlow Condensed for body text, UiPalette colours. Icons are small SVGs as DPITextures, so they
## stay sharp at every UI scale.

const OUT := "res://data/ui/beach_theme.tres"
const P := preload("res://scripts/ui/kit/ui_palette.gd")

var theme := Theme.new()
## Barlow Condensed lacks ◆ and arrows (binding names, upgrade texts); Bungee has them.
var body_bold := _with_fallback(P.FONT_BODY_BOLD)
var body := _with_fallback(P.FONT_BODY)


func _init() -> void:
	theme.default_font = body_bold
	theme.default_font_size = 20
	_labels()
	_panels()
	_buttons()
	_tabs()
	_ranges()
	_toggles()
	_inputs()
	_lists()
	_scrollbars()
	_popups()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var error := ResourceSaver.save(theme, OUT)
	if error != OK:
		push_error("Cannot save %s: %s" % [OUT, error_string(error)])
		quit(1)
		return
	print("build_ui_theme: saved ", OUT)
	quit(0)


# ---------------------------------------------------------------- building blocks

static func _with_fallback(font: Font) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.fallbacks = [P.FONT_DISPLAY]
	return variation


static func sticker(top: Color, bottom: Color, radius := 14.0, rim := 3.0, line := 2.0, shadow := 4.0, gloss := 0.35) -> StickerBox:
	var box := StickerBox.new()
	box.fill_top = top
	box.fill_bottom = bottom
	box.corner_radius = radius
	box.rim_width = rim
	box.line_width = line
	box.line_color = Color.WHITE if line > 0.0 else Color.TRANSPARENT
	box.shadow_offset = Vector2(0.0, shadow)
	box.shadow_color = Color(P.NAVY, 0.5 if shadow > 0.0 else 0.0)
	box.gloss = gloss
	return box


static func margins(box: StyleBox, left: float, top: float, right: float, bottom: float) -> StyleBox:
	box.content_margin_left = left
	box.content_margin_top = top
	box.content_margin_right = right
	box.content_margin_bottom = bottom
	return box


static func flat(color: Color, radius := 8.0, border := 0.0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.corner_detail = 8
	box.anti_aliasing = true
	if border > 0.0:
		box.set_border_width_all(int(border))
		box.border_color = border_color
	return box


static func ring(color: Color, radius := 16.0, width := 3.0, expand := 3.0) -> StyleBoxFlat:
	var box := flat(Color.TRANSPARENT, radius, width, color)
	box.draw_center = false
	box.set_expand_margin_all(expand)
	return box


static func svg(source: String) -> DPITexture:
	return DPITexture.create_from_string(source)


func label_variation(name: StringName, font: Font, size: int, color: Color, outline := 0, outline_color := P.NAVY, shadow := Vector2.ZERO) -> void:
	theme.set_type_variation(name, &"Label")
	theme.set_font(&"font", name, font)
	theme.set_font_size(&"font_size", name, size)
	theme.set_color(&"font_color", name, color)
	theme.set_constant(&"outline_size", name, outline)
	theme.set_color(&"font_outline_color", name, outline_color)
	if shadow != Vector2.ZERO:
		theme.set_color(&"font_shadow_color", name, Color(P.NAVY, 0.45))
		theme.set_constant(&"shadow_offset_x", name, int(shadow.x))
		theme.set_constant(&"shadow_offset_y", name, int(shadow.y))
		theme.set_constant(&"shadow_outline_size", name, outline)


# ---------------------------------------------------------------- types

func _labels() -> void:
	theme.set_font(&"font", &"Label", body_bold)
	theme.set_font_size(&"font_size", &"Label", 20)
	theme.set_color(&"font_color", &"Label", P.NAVY)
	theme.set_color(&"font_outline_color", &"Label", P.NAVY)
	theme.set_constant(&"line_spacing", &"Label", 1)
	# On cards and paper.
	label_variation(&"Heading", P.FONT_DISPLAY, 30, P.NAVY)
	label_variation(&"Subheading", P.FONT_DISPLAY, 19, P.NAVY)
	label_variation(&"Body", body, 20, P.NAVY)
	label_variation(&"Caption", body_bold, 17, P.INK_SOFT)
	label_variation(&"Value", P.FONT_DISPLAY, 17, P.AQUA_SHADE)
	# Straight on the world or on the blurred shade: white, navy outline, soft drop.
	label_variation(&"WorldTitle", P.FONT_DISPLAY, 46, P.WHITE, 10, P.NAVY, Vector2(0, 4))
	label_variation(&"HudValue", P.FONT_DISPLAY, 30, P.WHITE, P.WORLD_OUTLINE, P.NAVY, Vector2(0, 3))
	label_variation(&"HudTitle", P.FONT_DISPLAY, 21, P.WHITE, 7, P.NAVY, Vector2(0, 2))
	label_variation(&"HudLabel", body_bold, 20, P.WHITE, P.WORLD_OUTLINE_SMALL, P.NAVY, Vector2(0, 2))
	label_variation(&"HudCaption", body_bold, 16, Color("dff8ff"), 5, P.NAVY, Vector2(0, 2))
	label_variation(&"HudMoney", P.FONT_DISPLAY, 27, P.MONEY, P.WORLD_OUTLINE, P.NAVY, Vector2(0, 3))
	label_variation(&"HudVerb", P.FONT_DISPLAY, 15, P.WHITE, 6, P.NAVY, Vector2(0, 2))
	label_variation(&"HudWarn", P.FONT_DISPLAY, 17, P.AMBER, 7, P.NAVY, Vector2(0, 2))
	label_variation(&"PillText", body_bold, 19, P.WHITE, 0)


func _panels() -> void:
	var card := margins(sticker(P.SAND, P.SAND_DEEP, 20.0, 3.0, 3.0, 6.0, 0.0), 24, 20, 24, 24)
	theme.set_stylebox(&"panel", &"PanelContainer", card)
	theme.set_stylebox(&"panel", &"Panel", card)
	# A tighter card for side columns (the sorting table).
	theme.set_type_variation(&"SideCard", &"PanelContainer")
	theme.set_stylebox(&"panel", &"SideCard", margins(sticker(P.SAND, P.SAND_DEEP, 16.0, 3.0, 2.0, 5.0, 0.0), 14, 12, 14, 14))
	# Invisible containers for HUD blocks drawn straight on the world.
	theme.set_type_variation(&"HudPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"HudPanel", StyleBoxEmpty.new())
	# Rows and tiles inside a card.
	theme.set_type_variation(&"PaperRow", &"PanelContainer")
	theme.set_stylebox(&"panel", &"PaperRow", margins(sticker(Color.WHITE, Color("fff9ee"), 12.0, 2.0, 0.0, 3.0, 0.0), 14, 10, 14, 12))
	theme.set_type_variation(&"PaperInset", &"PanelContainer")
	theme.set_stylebox(&"panel", &"PaperInset", margins(flat(Color(P.NAVY, 0.07), 12.0), 14, 10, 14, 10))
	# Dark translucent pills for notices, toasts and hint chips over the world.
	theme.set_type_variation(&"Pill", &"PanelContainer")
	theme.set_stylebox(&"panel", &"Pill", margins(sticker(Color(P.NAVY, 0.9), Color(P.NAVY_DEEP, 0.9), 22.0, 0.0, 2.0, 3.0, 0.0), 16, 8, 18, 9))
	theme.set_type_variation(&"PillGold", &"PanelContainer")
	var gold_pill := sticker(Color(P.NAVY, 0.92), Color(P.NAVY_DEEP, 0.92), 22.0, 0.0, 2.0, 3.0, 0.0)
	gold_pill.line_color = P.GOLD
	theme.set_stylebox(&"panel", &"PillGold", margins(gold_pill, 16, 8, 18, 9))
	theme.set_type_variation(&"PillWarn", &"PanelContainer")
	var warn_pill := sticker(Color(P.NAVY, 0.92), Color(P.NAVY_DEEP, 0.92), 22.0, 0.0, 2.0, 3.0, 0.0)
	warn_pill.line_color = P.CORAL
	theme.set_stylebox(&"panel", &"PillWarn", margins(warn_pill, 16, 8, 18, 9))
	# Receipt and small reward cards.
	theme.set_type_variation(&"GoldCard", &"PanelContainer")
	theme.set_stylebox(&"panel", &"GoldCard", margins(sticker(P.GOLD_TOP, P.GOLD, 16.0, 3.0, 3.0, 5.0, 0.2), 18, 12, 18, 14))
	theme.set_type_variation(&"NavyCard", &"PanelContainer")
	theme.set_stylebox(&"panel", &"NavyCard", margins(sticker(Color(P.NAVY, 0.94), Color(P.NAVY_DEEP, 0.94), 16.0, 0.0, 2.0, 4.0, 0.0), 18, 12, 18, 14))
	theme.set_stylebox(&"panel", &"TooltipPanel", margins(sticker(P.NAVY, P.NAVY_DEEP, 12.0, 0.0, 2.0, 3.0, 0.0), 12, 7, 12, 8))
	theme.set_font(&"font", &"TooltipLabel", body_bold)
	theme.set_font_size(&"font_size", &"TooltipLabel", 18)
	theme.set_color(&"font_color", &"TooltipLabel", P.WHITE)


func _button_set(type: StringName, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox, font: Font, size: int, colors: Dictionary, outline: int) -> void:
	theme.set_stylebox(&"normal", type, normal)
	theme.set_stylebox(&"hover", type, hover)
	theme.set_stylebox(&"pressed", type, pressed)
	theme.set_stylebox(&"hover_pressed", type, pressed)
	theme.set_stylebox(&"disabled", type, disabled)
	theme.set_stylebox(&"focus", type, ring(P.GOLD, 18.0, 3.0, 4.0))
	theme.set_font(&"font", type, font)
	theme.set_font_size(&"font_size", type, size)
	for key in colors:
		theme.set_color(StringName(key), type, colors[key])
	theme.set_color(&"font_outline_color", type, P.NAVY)
	theme.set_constant(&"outline_size", type, outline)
	theme.set_constant(&"h_separation", type, 10)
	theme.set_constant(&"icon_max_width", type, 30)


func _buttons() -> void:
	var white_text := {
		"font_color": P.WHITE, "font_hover_color": P.WHITE, "font_pressed_color": P.WHITE,
		"font_focus_color": P.WHITE, "font_hover_pressed_color": P.WHITE,
		"font_disabled_color": Color(1, 1, 1, 0.75),
		"icon_normal_color": P.WHITE, "icon_hover_color": P.WHITE, "icon_pressed_color": P.WHITE,
		"icon_focus_color": P.WHITE, "icon_disabled_color": Color(1, 1, 1, 0.6),
	}
	var navy_text := {
		"font_color": P.NAVY, "font_hover_color": P.NAVY, "font_pressed_color": P.NAVY,
		"font_focus_color": P.NAVY, "font_hover_pressed_color": P.NAVY,
		"font_disabled_color": Color(P.NAVY, 0.45),
		"icon_normal_color": P.WHITE, "icon_hover_color": P.WHITE, "icon_pressed_color": P.WHITE,
		"icon_focus_color": P.WHITE, "icon_disabled_color": Color(1, 1, 1, 0.5),
	}
	var m := Vector4(22, 10, 22, 13)
	var aqua := margins(sticker(P.AQUA, P.AQUA_BOTTOM), m.x, m.y, m.z, m.w)
	var gold := margins(sticker(P.GOLD_TOP, P.GOLD_BOTTOM), m.x, m.y, m.z, m.w)
	var gold_down := margins(sticker(P.GOLD, P.GOLD_SHADE, 14.0, 3.0, 2.0, 1.0, 0.1), m.x, m.y + 2, m.z, m.w - 2)
	var grey := margins(sticker(Color("dfe7ee"), Color("a9b9c7"), 14.0, 3.0, 2.0, 3.0, 0.0), m.x, m.y, m.z, m.w)
	(grey as StickerBox).rim_color = Color("5f7890")
	_button_set(&"Button", aqua, gold, gold_down, grey, P.FONT_DISPLAY, 18, white_text, 6)

	# Main call to action: gold at rest, brighter on hover.
	theme.set_type_variation(&"PrimaryButton", &"Button")
	var bright := margins(sticker(Color.WHITE, P.GOLD, 14.0, 3.0, 2.0, 4.0, 0.45), m.x, m.y, m.z, m.w)
	_button_set(&"PrimaryButton", gold, bright, gold_down, grey, P.FONT_DISPLAY, 21, white_text, 7)

	# Secondary rows (settings bindings, options, back): paper at rest, gold on hover.
	theme.set_type_variation(&"SoftButton", &"Button")
	var paper := margins(sticker(Color.WHITE, Color("f6ecd8"), 12.0, 2.0, 0.0, 3.0, 0.0), 16, 8, 16, 10)
	var paper_hover := margins(sticker(P.GOLD_TOP, P.GOLD, 12.0, 2.0, 0.0, 3.0, 0.25), 16, 8, 16, 10)
	var paper_down := margins(sticker(P.GOLD, P.GOLD_BOTTOM, 12.0, 2.0, 0.0, 1.0, 0.0), 16, 10, 16, 8)
	var paper_off := margins(sticker(Color("eef1f4"), Color("dde3e8"), 12.0, 2.0, 0.0, 2.0, 0.0), 16, 8, 16, 10)
	(paper_off as StickerBox).rim_color = Color("8fa3b5")
	_button_set(&"SoftButton", paper, paper_hover, paper_down, paper_off, body_bold, 20, navy_text, 0)

	theme.set_type_variation(&"DangerButton", &"Button")
	var coral := margins(sticker(P.CORAL_TOP, P.CORAL), m.x, m.y, m.z, m.w)
	var coral_hover := margins(sticker(Color("ffd6cf"), Color("ff7b6f"), 14.0, 3.0, 2.0, 4.0, 0.45), m.x, m.y, m.z, m.w)
	_button_set(&"DangerButton", coral, coral_hover, gold_down, grey, P.FONT_DISPLAY, 18, white_text, 6)

	# Tabs made of buttons (booklet): paper, gold when hovered, aqua when selected.
	theme.set_type_variation(&"TabButton", &"Button")
	var tab_on := margins(sticker(P.AQUA, P.AQUA_BOTTOM, 14.0, 3.0, 2.0, 3.0, 0.3), 16, 8, 16, 11)
	_button_set(&"TabButton", paper, paper_hover, tab_on, paper_off, P.FONT_DISPLAY, 16, navy_text, 0)

	# OptionButton / MenuButton share the paper look with a chevron.
	var chevron := svg('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M3 5.5 L8 10.5 L13 5.5" fill="none" stroke="#0b2a44" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/></svg>')
	for type in [&"OptionButton", &"MenuButton"]:
		_button_set(type, paper.duplicate(), paper_hover.duplicate(), paper_down.duplicate(), paper_off.duplicate(), body_bold, 20, navy_text, 0)
		theme.set_icon(&"arrow", type, chevron)
		theme.set_constant(&"arrow_margin", type, 12)
		(theme.get_stylebox(&"normal", type) as StyleBox).content_margin_right = 40
		(theme.get_stylebox(&"hover", type) as StyleBox).content_margin_right = 40
		(theme.get_stylebox(&"pressed", type) as StyleBox).content_margin_right = 40
		(theme.get_stylebox(&"disabled", type) as StyleBox).content_margin_right = 40


func _tabs() -> void:
	var selected := margins(sticker(P.GOLD_TOP, P.GOLD, 12.0, 3.0, 2.0, 3.0, 0.3), 18, 8, 18, 10)
	var unselected := margins(sticker(Color.WHITE, Color("f6ecd8"), 12.0, 2.0, 0.0, 3.0, 0.0), 18, 8, 18, 10)
	var hovered := margins(sticker(Color("fffbe9"), P.GOLD_TOP, 12.0, 2.0, 0.0, 3.0, 0.0), 18, 8, 18, 10)
	for type in [&"TabContainer", &"TabBar"]:
		theme.set_stylebox(&"tab_selected", type, selected)
		theme.set_stylebox(&"tab_unselected", type, unselected)
		theme.set_stylebox(&"tab_hovered", type, hovered)
		theme.set_stylebox(&"tab_disabled", type, unselected)
		theme.set_stylebox(&"tab_focus", type, ring(P.GOLD, 14.0, 3.0, 3.0))
		theme.set_font(&"font", type, P.FONT_DISPLAY)
		theme.set_font_size(&"font_size", type, 17)
		theme.set_color(&"font_selected_color", type, P.NAVY)
		theme.set_color(&"font_unselected_color", type, P.INK_SOFT)
		theme.set_color(&"font_hovered_color", type, P.NAVY)
		theme.set_constant(&"h_separation", type, 10)
		theme.set_constant(&"side_margin", type, 0)
		theme.set_constant(&"icon_max_width", type, 26)
	theme.set_stylebox(&"panel", &"TabContainer", margins(flat(Color(1, 1, 1, 0.55), 14.0), 18, 16, 18, 16))
	theme.set_stylebox(&"tabbar_background", &"TabContainer", margins(StyleBoxEmpty.new(), 0, 0, 0, 8))


func _ranges() -> void:
	var grabber := svg('<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6cf"/><stop offset="1" stop-color="#ff9f1c"/></linearGradient></defs><circle cx="13" cy="14" r="11" fill="#0b2a44" opacity="0.5"/><circle cx="13" cy="12.5" r="11" fill="#0b2a44"/><circle cx="13" cy="12.5" r="8.4" fill="#ffffff"/><circle cx="13" cy="12.5" r="6.6" fill="url(#g)"/></svg>')
	var grabber_hot := svg('<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#ffd257"/></linearGradient></defs><circle cx="13" cy="14" r="12" fill="#0b2a44" opacity="0.5"/><circle cx="13" cy="12.5" r="12" fill="#0b2a44"/><circle cx="13" cy="12.5" r="9.4" fill="#ffffff"/><circle cx="13" cy="12.5" r="7.6" fill="url(#g)"/></svg>')
	var grabber_off := svg('<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26"><circle cx="13" cy="12.5" r="11" fill="#5f7890"/><circle cx="13" cy="12.5" r="8.4" fill="#dfe7ee"/></svg>')
	var track := margins(flat(Color(P.NAVY, 0.85), 6.0), 0, 5, 0, 5)
	var fill := margins(flat(P.AQUA_BOTTOM, 6.0, 2.0, P.NAVY), 0, 5, 0, 5)
	var fill_hot := margins(flat(P.GOLD, 6.0, 2.0, P.NAVY), 0, 5, 0, 5)
	for type in [&"HSlider", &"VSlider"]:
		theme.set_stylebox(&"slider", type, track)
		theme.set_stylebox(&"grabber_area", type, fill)
		theme.set_stylebox(&"grabber_area_highlight", type, fill_hot)
		theme.set_icon(&"grabber", type, grabber)
		theme.set_icon(&"grabber_highlight", type, grabber_hot)
		theme.set_icon(&"grabber_disabled", type, grabber_off)
		theme.set_constant(&"center_grabber", type, 0)
		theme.set_constant(&"grabber_offset", type, 0)
	# Progress bars: navy capsule track, aqua sticker fill.
	theme.set_stylebox(&"background", &"ProgressBar", flat(Color(P.NAVY, 0.72), 7.0, 2.0, Color(1, 1, 1, 0.55)))
	theme.set_stylebox(&"fill", &"ProgressBar", flat(P.AQUA_BOTTOM, 7.0, 2.0, P.NAVY))
	theme.set_font(&"font", &"ProgressBar", body_bold)
	theme.set_font_size(&"font_size", &"ProgressBar", 15)
	theme.set_color(&"font_color", &"ProgressBar", P.WHITE)
	theme.set_color(&"font_outline_color", &"ProgressBar", P.NAVY)
	theme.set_constant(&"outline_size", &"ProgressBar", 4)
	theme.set_type_variation(&"HudBar", &"ProgressBar")
	theme.set_stylebox(&"background", &"HudBar", flat(Color(P.NAVY, 0.78), 6.0, 2.0, Color(1, 1, 1, 0.85)))
	theme.set_stylebox(&"fill", &"HudBar", flat(P.AQUA_BOTTOM, 6.0, 2.0, P.NAVY))


func _toggles() -> void:
	var on := svg('<svg xmlns="http://www.w3.org/2000/svg" width="50" height="28" viewBox="0 0 50 28"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#bff6ff"/><stop offset="1" stop-color="#3fc6e6"/></linearGradient></defs><rect x="1" y="3" width="48" height="24" rx="12" fill="#0b2a44" opacity="0.45"/><rect x="1" y="1" width="48" height="24" rx="12" fill="#0b2a44"/><rect x="4" y="4" width="42" height="18" rx="9" fill="url(#g)"/><circle cx="36" cy="13" r="10" fill="#0b2a44"/><circle cx="36" cy="13" r="7.5" fill="#ffffff"/><path d="M8.5 13.5 l3 3 l5.5 -6.5" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>')
	var off := svg('<svg xmlns="http://www.w3.org/2000/svg" width="50" height="28" viewBox="0 0 50 28"><rect x="1" y="3" width="48" height="24" rx="12" fill="#0b2a44" opacity="0.35"/><rect x="1" y="1" width="48" height="24" rx="12" fill="#0b2a44"/><rect x="4" y="4" width="42" height="18" rx="9" fill="#9fb3c4"/><circle cx="14" cy="13" r="10" fill="#0b2a44"/><circle cx="14" cy="13" r="7.5" fill="#ffffff"/></svg>')
	var on_off := svg('<svg xmlns="http://www.w3.org/2000/svg" width="50" height="28" viewBox="0 0 50 28"><rect x="1" y="1" width="48" height="24" rx="12" fill="#5f7890"/><rect x="4" y="4" width="42" height="18" rx="9" fill="#c9d6e0"/><circle cx="36" cy="13" r="8" fill="#eef2f5"/></svg>')
	var off_off := svg('<svg xmlns="http://www.w3.org/2000/svg" width="50" height="28" viewBox="0 0 50 28"><rect x="1" y="1" width="48" height="24" rx="12" fill="#5f7890"/><rect x="4" y="4" width="42" height="18" rx="9" fill="#c9d6e0"/><circle cx="14" cy="13" r="8" fill="#eef2f5"/></svg>')
	var row := margins(StyleBoxEmpty.new(), 10, 6, 10, 6)
	var row_hot := margins(flat(Color(P.GOLD, 0.35), 10.0), 10, 6, 10, 6)
	for type in [&"CheckButton", &"CheckBox"]:
		theme.set_icon(&"checked", type, on)
		theme.set_icon(&"unchecked", type, off)
		theme.set_icon(&"checked_disabled", type, on_off)
		theme.set_icon(&"unchecked_disabled", type, off_off)
		theme.set_icon(&"checked_mirrored", type, on)
		theme.set_icon(&"unchecked_mirrored", type, off)
		theme.set_stylebox(&"normal", type, row)
		theme.set_stylebox(&"pressed", type, row)
		theme.set_stylebox(&"hover", type, row_hot)
		theme.set_stylebox(&"hover_pressed", type, row_hot)
		theme.set_stylebox(&"disabled", type, row)
		theme.set_stylebox(&"focus", type, ring(P.GOLD, 12.0, 3.0, 2.0))
		theme.set_font(&"font", type, body_bold)
		theme.set_font_size(&"font_size", type, 20)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			theme.set_color(StringName(key), type, P.NAVY)
		theme.set_color(&"font_disabled_color", type, Color(P.NAVY, 0.45))
		theme.set_constant(&"h_separation", type, 14)
		# CheckButton inherits Button's outlined display text and icon cap; rows use plain body
		# text and the switch keeps its full size.
		theme.set_constant(&"outline_size", type, 0)
		theme.set_constant(&"icon_max_width", type, 0)


func _inputs() -> void:
	var normal := margins(sticker(Color.WHITE, Color("f7f2e8"), 12.0, 3.0, 0.0, 3.0, 0.0), 16, 9, 16, 11)
	var focus := ring(P.GOLD, 14.0, 3.0, 3.0)
	theme.set_stylebox(&"normal", &"LineEdit", normal)
	theme.set_stylebox(&"focus", &"LineEdit", focus)
	theme.set_stylebox(&"read_only", &"LineEdit", normal)
	theme.set_font(&"font", &"LineEdit", P.FONT_DISPLAY)
	theme.set_font_size(&"font_size", &"LineEdit", 19)
	theme.set_color(&"font_color", &"LineEdit", P.NAVY)
	theme.set_color(&"font_placeholder_color", &"LineEdit", Color(P.NAVY, 0.4))
	theme.set_color(&"caret_color", &"LineEdit", P.NAVY)
	theme.set_color(&"selection_color", &"LineEdit", Color(P.AQUA_BOTTOM, 0.55))
	theme.set_color(&"font_selected_color", &"LineEdit", P.NAVY)
	theme.set_constant(&"caret_width", &"LineEdit", 3)


func _lists() -> void:
	theme.set_stylebox(&"panel", &"ItemList", margins(sticker(Color.WHITE, Color("fbf6ec"), 14.0, 3.0, 0.0, 3.0, 0.0), 10, 10, 10, 10))
	theme.set_stylebox(&"focus", &"ItemList", ring(P.GOLD, 16.0, 3.0, 3.0))
	theme.set_stylebox(&"selected", &"ItemList", flat(Color(P.AQUA, 1.0), 10.0, 2.0, P.AQUA_SHADE))
	theme.set_stylebox(&"selected_focus", &"ItemList", flat(P.GOLD, 10.0, 2.0, P.NAVY))
	theme.set_stylebox(&"hovered", &"ItemList", flat(Color(P.GOLD, 0.35), 10.0))
	theme.set_stylebox(&"hovered_selected", &"ItemList", flat(P.GOLD_TOP, 10.0, 2.0, P.NAVY))
	theme.set_stylebox(&"hovered_selected_focus", &"ItemList", flat(P.GOLD, 10.0, 2.0, P.NAVY))
	theme.set_stylebox(&"cursor", &"ItemList", ring(P.NAVY, 10.0, 2.0, 0.0))
	theme.set_stylebox(&"cursor_unfocused", &"ItemList", StyleBoxEmpty.new())
	theme.set_font(&"font", &"ItemList", body_bold)
	theme.set_font_size(&"font_size", &"ItemList", 19)
	for key in ["font_color", "font_hovered_color", "font_selected_color", "font_hovered_selected_color"]:
		theme.set_color(StringName(key), &"ItemList", P.NAVY)
	theme.set_color(&"guide_color", &"ItemList", Color(P.NAVY, 0.08))
	theme.set_constant(&"v_separation", &"ItemList", 10)
	theme.set_constant(&"h_separation", &"ItemList", 10)
	theme.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	theme.set_stylebox(&"focus", &"ScrollContainer", StyleBoxEmpty.new())


func _scrollbars() -> void:
	for type in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox(&"scroll", type, margins(flat(Color(P.NAVY, 0.12), 6.0), 4, 4, 4, 4))
		theme.set_stylebox(&"scroll_focus", type, margins(flat(Color(P.NAVY, 0.12), 6.0), 4, 4, 4, 4))
		theme.set_stylebox(&"grabber", type, flat(Color(P.NAVY, 0.55), 6.0))
		theme.set_stylebox(&"grabber_highlight", type, flat(Color(P.NAVY, 0.8), 6.0))
		theme.set_stylebox(&"grabber_pressed", type, flat(P.AQUA_SHADE, 6.0))
		for icon in [&"increment", &"increment_highlight", &"increment_pressed", &"decrement", &"decrement_highlight", &"decrement_pressed"]:
			theme.set_icon(icon, type, ImageTexture.new())


func _popups() -> void:
	theme.set_stylebox(&"panel", &"PopupMenu", margins(sticker(Color.WHITE, P.SAND, 14.0, 3.0, 0.0, 4.0, 0.0), 8, 8, 8, 8))
	theme.set_stylebox(&"hover", &"PopupMenu", flat(P.GOLD, 10.0, 2.0, P.NAVY))
	theme.set_stylebox(&"panel", &"PopupPanel", margins(sticker(Color.WHITE, P.SAND, 14.0, 3.0, 0.0, 4.0, 0.0), 8, 8, 8, 8))
	theme.set_font(&"font", &"PopupMenu", body_bold)
	theme.set_font_size(&"font_size", &"PopupMenu", 20)
	for key in ["font_color", "font_hover_color", "font_accelerator_color"]:
		theme.set_color(StringName(key), &"PopupMenu", P.NAVY)
	theme.set_color(&"font_disabled_color", &"PopupMenu", Color(P.NAVY, 0.4))
	theme.set_constant(&"v_separation", &"PopupMenu", 10)
	theme.set_constant(&"item_start_padding", &"PopupMenu", 12)
	theme.set_constant(&"item_end_padding", &"PopupMenu", 12)
