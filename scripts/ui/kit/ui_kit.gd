class_name UiKit
extends CanvasLayer
## Autoload "Ui". Gives every button in the game the same answer-back motion (lean in on hover or
## focus, squash on press, spring and sparkle on click), owns the screen-in / stagger helpers and
## the 2D particle bursts, and sets the menu cursor. Presentation only: it never changes what a
## button does, when it fires or which control has focus. Reduced motion turns every motion off
## and keeps the colour states.

enum Burst { SPARKLE, STAR, CONFETTI, COIN }

const P := preload("res://scripts/ui/kit/ui_palette.gd")
const SPARKLE_TEXTURE := preload("res://art/synty/fx/PolygonParticles_Sparkle.png")
const STAR_TEXTURE := preload("res://art/synty/ui/icons_flat/ICON_ModernMenus_Star_02_Stroke.png")
const COIN_TEXTURE := preload("res://art/synty/ui/icons_3d/SPR_ModernMenus_Icon_Currency_Coin_01_Ortho.png")
const CURSOR_ARROW := preload("res://art/synty/ui/cursors/SPR_ModernMenus_Cursor_Pointer_04.png")
const CURSOR_HAND := preload("res://art/synty/ui/cursors/SPR_ModernMenus_Cursor_Pointer_05.png")

const HOVER_GROW_PX := 9.0
const HOVER_TILT_DEGREES := -1.5
const HOVER_SECONDS := 0.14
const PRESS_SCALE := 0.93
const RELEASE_PEAK := 1.08
const SCREEN_IN_SECONDS := 0.26
const STAGGER_SECONDS := 0.04

static var instance: UiKit

## Set by BeachMain so motion follows the reduced-motion setting.
var settings: SettingsStore
## Model-rendered icons for tools, items and POLYGON Icons.
var icons: IconStudio
## True while the last meaningful input came from the mouse. Focus looks like hover only for
## keyboard and controller players; a mouse click that leaves focus behind does not stay lit.
var mouse_active := true
var _pool: Array[CPUParticles2D] = []
var _confetti_ramp: Gradient
var _cursor_size := 0


static func kit() -> UiKit:
	return instance if is_instance_valid(instance) else null


static func reduced() -> bool:
	var k := kit()
	# The store belongs to a main scene, which can be freed and replaced while the autoload lives on.
	return k != null and is_instance_valid(k.settings) and FeelMotion.reduced(k.settings)


func _enter_tree() -> void:
	instance = self
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _ready() -> void:
	icons = IconStudio.new()
	icons.name = "IconStudio"
	add_child(icons)
	_confetti_ramp = Gradient.new()
	_confetti_ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	_confetti_ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	_confetti_ramp.colors = PackedColorArray([P.GOLD, P.AQUA_BOTTOM, P.CORAL, P.MINT, P.WHITE])
	get_tree().root.size_changed.connect(_update_cursor)
	_update_cursor()


func _input(event: InputEvent) -> void:
	var was_mouse := mouse_active
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_active = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		mouse_active = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		mouse_active = false
	if was_mouse != mouse_active:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton:
			_refresh(focused as BaseButton)


# ---------------------------------------------------------------- buttons

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(&"ui_static"):
		_attach(node as BaseButton)


func _attach(button: BaseButton) -> void:
	if button.has_meta(&"ui_juiced"):
		return
	button.set_meta(&"ui_juiced", true)
	if button.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_refresh.bind(button))
	button.mouse_exited.connect(_refresh.bind(button))
	button.focus_entered.connect(_refresh.bind(button))
	button.focus_exited.connect(_refresh.bind(button))
	button.button_down.connect(_on_down.bind(button))
	button.pressed.connect(_on_pressed.bind(button))
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.visibility_changed.connect(func() -> void:
		if not button.is_visible_in_tree():
			_rest(button)
	)


func _lit(button: BaseButton) -> bool:
	if button.disabled or not button.is_visible_in_tree():
		return false
	return button.is_hovered() or (button.has_focus() and not mouse_active)


## Hover and keyboard/controller focus share one look: the theme's hover style plus a small lean.
func _refresh(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var lit := _lit(button)
	_set_focus_look(button, lit and button.has_focus() and not button.is_hovered())
	if reduced() or button.disabled:
		_rest(button, lit)
		return
	button.pivot_offset = button.size * 0.5
	var grow := 1.0 + clampf(HOVER_GROW_PX / maxf(button.size.x, 1.0), 0.012, 0.07) if lit else 1.0
	var tilt := deg_to_rad(HOVER_TILT_DEGREES) if lit and button.size.x < 280.0 and not button.has_meta(&"ui_no_tilt") else 0.0
	var t := FeelMotion.replace(button, &"ui_hover", FeelMotion.tween(button).set_parallel(true))
	t.tween_property(button, "scale", Vector2.ONE * grow, HOVER_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(button, "rotation", tilt, HOVER_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Draws the hover style while focused (controller / keyboard) without touching any override the
## button's own scene set, which is restored exactly when focus leaves.
func _set_focus_look(button: BaseButton, on: bool) -> void:
	if not button is Button:
		return
	var control := button as Button
	var active := control.has_meta(&"ui_focus_look")
	if on == active:
		return
	if on:
		var saved := {}
		for key in [&"normal", &"pressed"]:
			saved[key] = control.get_theme_stylebox(key) if control.has_theme_stylebox_override(key) else null
		saved[&"font_color"] = control.get_theme_color(&"font_color") if control.has_theme_color_override(&"font_color") else null
		control.set_meta(&"ui_focus_look", saved)
		var hover := control.get_theme_stylebox(&"hover")
		control.add_theme_stylebox_override(&"normal", hover)
		if not (control.toggle_mode and control.button_pressed):
			control.add_theme_stylebox_override(&"pressed", control.get_theme_stylebox(&"hover_pressed"))
		control.add_theme_color_override(&"font_color", control.get_theme_color(&"font_hover_color"))
	else:
		var saved := control.get_meta(&"ui_focus_look") as Dictionary
		control.remove_meta(&"ui_focus_look")
		for key in [&"normal", &"pressed"]:
			if saved[key] != null:
				control.add_theme_stylebox_override(key, saved[key] as StyleBox)
			else:
				control.remove_theme_stylebox_override(key)
		if saved[&"font_color"] != null:
			control.add_theme_color_override(&"font_color", saved[&"font_color"] as Color)
		else:
			control.remove_theme_color_override(&"font_color")


func _rest(button: BaseButton, lit := false) -> void:
	FeelMotion.replace(button, &"ui_hover", null)
	FeelMotion.replace(button, &"ui_press", null)
	button.scale = Vector2.ONE
	button.rotation = 0.0
	if not lit:
		_set_focus_look(button, false)


func _on_down(button: BaseButton) -> void:
	if reduced() or button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var t := FeelMotion.replace(button, &"ui_press", FeelMotion.tween(button))
	t.tween_property(button, "scale", Vector2.ONE * PRESS_SCALE, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_pressed(button: BaseButton) -> void:
	if reduced() or not is_instance_valid(button) or not button.is_visible_in_tree():
		return
	FeelMotion.replace(button, &"ui_hover", null)
	button.pivot_offset = button.size * 0.5
	var rest := 1.0 + clampf(HOVER_GROW_PX / maxf(button.size.x, 1.0), 0.012, 0.07) if _lit(button) else 1.0
	var t := FeelMotion.replace(button, &"ui_press", FeelMotion.tween(button))
	t.tween_property(button, "scale", Vector2.ONE * RELEASE_PEAK, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", Vector2.ONE * rest, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not button.has_meta(&"ui_quiet"):
		var at := button.get_global_rect().get_center()
		if mouse_active and button.get_global_rect().has_point(button.get_global_mouse_position()):
			at = button.get_global_mouse_position()
		burst(at, Burst.SPARKLE, 7)


# ---------------------------------------------------------------- screens

## Scales a centred card down (never up) until it fits the visible area, so a tall card still fits
## a short screen at 150 % UI scale. screen_in / screen_out settle on this scale.
func fit(control: Control, margin := 14.0) -> float:
	var view := control.get_viewport_rect().size
	var need := control.get_combined_minimum_size()
	var scale_to_fit := 1.0
	if need.x > 0.0 and need.y > 0.0:
		scale_to_fit = minf(1.0, minf((view.x - margin * 2.0) / need.x, (view.y - margin * 2.0) / need.y))
	control.set_meta(&"ui_fit", scale_to_fit)
	# A card in a CenterContainer is laid out at its minimum size, which may not have happened yet.
	control.pivot_offset = Vector2(maxf(control.size.x, need.x), maxf(control.size.y, need.y)) * 0.5
	control.scale = Vector2.ONE * scale_to_fit
	return scale_to_fit


## Brings a panel in: fade, grow from 94 % around its lower centre, slight overshoot.
func screen_in(control: Control, from_scale := 0.94) -> void:
	FeelMotion.replace(control, &"ui_screen", null)
	var rest := float(control.get_meta(&"ui_fit", 1.0))
	if reduced():
		control.modulate.a = 1.0
		control.scale = Vector2.ONE * rest
		return
	control.pivot_offset = Vector2(control.size.x * 0.5, control.size.y * (0.5 if rest < 1.0 else 0.62))
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * from_scale * rest
	var t := FeelMotion.replace(control, &"ui_screen", FeelMotion.tween(control).set_parallel(true))
	t.tween_property(control, "modulate:a", 1.0, SCREEN_IN_SECONDS * 0.6)
	t.tween_property(control, "scale", Vector2.ONE * rest, SCREEN_IN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fades and shrinks a panel out, then calls `finished` (at once under reduced motion).
func screen_out(control: Control, finished := Callable()) -> void:
	FeelMotion.replace(control, &"ui_screen", null)
	var rest := float(control.get_meta(&"ui_fit", 1.0))
	if reduced() or not control.is_visible_in_tree():
		control.modulate.a = 1.0
		control.scale = Vector2.ONE * rest
		if finished.is_valid():
			finished.call()
		return
	control.pivot_offset = control.size * 0.5
	var t := FeelMotion.replace(control, &"ui_screen", FeelMotion.tween(control).set_parallel(true))
	t.tween_property(control, "modulate:a", 0.0, 0.14)
	t.tween_property(control, "scale", Vector2.ONE * 0.97 * rest, 0.14)
	t.chain().tween_callback(func() -> void:
		control.modulate.a = 1.0
		control.scale = Vector2.ONE * rest
		if finished.is_valid():
			finished.call()
	)


## Children of `container` pop in one after another.
func stagger_in(container: Control, delay := 0.0) -> void:
	var index := 0
	for child in container.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		FeelMotion.replace(control, &"ui_stagger", null)
		if reduced():
			control.modulate.a = 1.0
			control.scale = Vector2.ONE
			continue
		control.pivot_offset = control.size * 0.5
		control.modulate.a = 0.0
		control.scale = Vector2.ONE * 0.86
		var t := FeelMotion.replace(control, &"ui_stagger", FeelMotion.tween(control).set_parallel(true))
		var start := delay + STAGGER_SECONDS * index
		t.tween_property(control, "modulate:a", 1.0, 0.12).set_delay(start)
		t.tween_property(control, "scale", Vector2.ONE, 0.24).set_delay(start).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		index += 1


## A quick scale pop that ends exactly at ONE.
func pop(control: Control, peak := 1.18, seconds := 0.22) -> void:
	if reduced() or control == null:
		return
	FeelMotion.bump_control(control, peak, seconds)


# ---------------------------------------------------------------- particles

## A one-shot 2D burst at a canvas position. Pooled; nothing plays under reduced motion.
func burst(at: Vector2, kind := Burst.SPARKLE, amount := 8, tint := Color.WHITE) -> void:
	if reduced() or amount <= 0:
		return
	var particles := _take()
	particles.position = at
	particles.amount = amount
	particles.color_initial_ramp = null
	particles.color = tint
	particles.gravity = Vector2.ZERO
	particles.spread = 180.0
	particles.direction = Vector2.UP
	particles.angle_min = 0.0
	particles.angle_max = 0.0
	particles.angular_velocity_min = 0.0
	particles.angular_velocity_max = 0.0
	particles.damping_min = 0.0
	particles.damping_max = 0.0
	match kind:
		Burst.SPARKLE:
			particles.texture = SPARKLE_TEXTURE
			particles.lifetime = 0.45
			particles.initial_velocity_min = 90.0
			particles.initial_velocity_max = 190.0
			particles.damping_min = 260.0
			particles.damping_max = 380.0
			particles.scale_amount_min = 0.05
			particles.scale_amount_max = 0.09
			if tint == Color.WHITE:
				particles.color = Color(1.0, 0.95, 0.7)
		Burst.STAR:
			particles.texture = STAR_TEXTURE
			particles.lifetime = 0.7
			particles.initial_velocity_min = 120.0
			particles.initial_velocity_max = 260.0
			particles.damping_min = 240.0
			particles.damping_max = 320.0
			particles.gravity = Vector2(0, 260)
			particles.angular_velocity_min = -260.0
			particles.angular_velocity_max = 260.0
			particles.scale_amount_min = 0.07
			particles.scale_amount_max = 0.12
		Burst.CONFETTI:
			particles.texture = null
			particles.lifetime = 1.6
			particles.direction = Vector2.UP
			particles.spread = 70.0
			particles.initial_velocity_min = 260.0
			particles.initial_velocity_max = 520.0
			particles.damping_min = 60.0
			particles.damping_max = 120.0
			particles.gravity = Vector2(0, 520)
			particles.angle_min = 0.0
			particles.angle_max = 360.0
			particles.angular_velocity_min = -400.0
			particles.angular_velocity_max = 400.0
			particles.scale_amount_min = 5.0
			particles.scale_amount_max = 9.0
			particles.color_initial_ramp = _confetti_ramp
			particles.color = Color.WHITE
		Burst.COIN:
			particles.texture = COIN_TEXTURE
			particles.lifetime = 0.8
			particles.direction = Vector2.UP
			particles.spread = 55.0
			particles.initial_velocity_min = 200.0
			particles.initial_velocity_max = 360.0
			particles.gravity = Vector2(0, 900)
			particles.angular_velocity_min = -200.0
			particles.angular_velocity_max = 200.0
			particles.scale_amount_min = 0.05
			particles.scale_amount_max = 0.075
	particles.restart()
	particles.emitting = true


func _take() -> CPUParticles2D:
	for particles in _pool:
		if not particles.emitting:
			return particles
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.emitting = false
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	particles.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.6))
	shrink.add_point(Vector2(0.15, 1.0))
	shrink.add_point(Vector2(1.0, 0.35))
	particles.scale_amount_curve = shrink
	add_child(particles)
	_pool.append(particles)
	return particles


# ---------------------------------------------------------------- cursor

## The menu cursor from Modern Menus, sized to the window so it is not tiny at 4K.
func _update_cursor() -> void:
	var height := get_tree().root.size.y
	var size := clampi(roundi(height / 1080.0 * 34.0), 26, 64)
	if size == _cursor_size or DisplayServer.get_name() == "headless":
		return
	_cursor_size = size
	for pair in [[CURSOR_ARROW, Input.CURSOR_ARROW, Vector2(0.02, 0.02)], [CURSOR_HAND, Input.CURSOR_POINTING_HAND, Vector2(0.3, 0.04)]]:
		var image := (pair[0] as Texture2D).get_image()
		if image == null:
			continue
		if image.is_compressed():
			image.decompress()
		image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(image), pair[1] as Input.CursorShape, (pair[2] as Vector2) * size)
