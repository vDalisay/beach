class_name Reticle
extends Control
## Centre reticle. Presentation only: it reads targets and cues, never input or state.
## A dot when nothing is targeted, a ring for actionable targets, eight amber dashes for
## blocked ones, mint corner brackets for a valid placement and a spinning dashed ring while
## the vacuum runs. It pops on accepted actions and shakes on rejections.

enum Mode { IDLE, ACTION, BLOCKED, PLACE }

const FEEL := preload("res://data/feel/feel_tuning.tres")
const SUCCESS_CUES: Array[StringName] = [
	&"poke", &"hold", &"hold_bag", &"place", &"deposit", &"clean", &"cut",
	&"reveal", &"sift", &"scanner_pulse", &"collect_call",
]

var player: BeachPlayer
var mode := Mode.IDLE
var _radius := 2.5
var _radius_velocity := 0.0
var _pop := 0.0
var _pop_velocity := 0.0
var _shake_elapsed := 99.0
var _flash := 0.0
var _spin := 0.0
var _reduced := false
var _vacuum := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keeps processing under pause so it can hide itself behind menus and results.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	set_process(false)


func configure(beach_player: BeachPlayer) -> void:
	player = beach_player
	if not player.interactor.target_changed.is_connected(_on_target_changed):
		player.interactor.target_changed.connect(_on_target_changed)
	if not player.cue_played.is_connected(_on_cue):
		player.cue_played.connect(_on_cue)
	mode = Mode.IDLE
	_radius = FEEL.reticle_dot_px
	_radius_velocity = 0.0
	_pop = 0.0
	_pop_velocity = 0.0
	_shake_elapsed = 99.0
	_flash = 0.0
	set_process(true)


func clear() -> void:
	player = null
	hide()
	set_process(false)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		hide()
		return
	var active := player.input_enabled and not get_tree().paused and player.camera.current \
		and player.input_reader.context == InputReader.Context.WORLD
	visible = active
	if not active:
		return
	_reduced = FeelMotion.reduced(player.settings_store)
	var target := _mode_radius()
	if _reduced:
		_radius = target
		_radius_velocity = 0.0
		_pop = 0.0
		_pop_velocity = 0.0
	else:
		var r := FeelMotion.spring(_radius, _radius_velocity, target, FEEL.reticle_spring_hz, delta)
		_radius = r.x
		_radius_velocity = r.y
		var p := FeelMotion.spring(_pop, _pop_velocity, 0.0, FEEL.reticle_spring_hz * 1.4, delta)
		_pop = p.x
		_pop_velocity = p.y
	_shake_elapsed += delta
	_flash = move_toward(_flash, 0.0, delta * 4.0)
	_vacuum = _vacuum_running()
	_spin += delta * (4.0 if _vacuum and not _reduced else 0.0)
	queue_redraw()


func _mode_radius() -> float:
	match mode:
		Mode.ACTION, Mode.BLOCKED:
			return FEEL.reticle_ring_px
		Mode.PLACE:
			return FEEL.reticle_place_px
	return FEEL.reticle_dot_px


func _vacuum_running() -> bool:
	var session := player.interactor.session
	return session != null and session.vacuum_tool != null and session.vacuum_tool.is_active() and player.input_reader.pressed(&"primary")


func _on_target_changed(result: Dictionary) -> void:
	if result.is_empty() or player == null:
		mode = Mode.IDLE
		return
	var actions := result.get("actions", PackedStringArray()) as PackedStringArray
	if actions.has("place"):
		mode = Mode.PLACE
	elif str(result.get("kind", "")) == "slot":
		mode = Mode.BLOCKED
	else:
		match player.interactor.style_for(result):
			HoverHighlight.Style.BLOCKED:
				mode = Mode.BLOCKED
			HoverHighlight.Style.ACTION, HoverHighlight.Style.SOFT:
				mode = Mode.ACTION
			_:
				mode = Mode.IDLE


func _on_cue(cue: StringName, _info: Dictionary) -> void:
	if cue == &"rejected" or cue == &"vacuum_full":
		# The flash is a colour change and stays under reduced motion; _draw drops the shake.
		_shake_elapsed = 0.0
		_flash = 1.0
		return
	if _reduced or player == null or FeelMotion.reduced(player.settings_store):
		return
	if cue in SUCCESS_CUES or cue == &"clean_done":
		_pop = -3.0
		_pop_velocity = FEEL.reticle_pop_px * 26.0 * (2.0 if cue == &"clean_done" else 1.0)


func _draw() -> void:
	if player == null:
		return
	var center := size * 0.5
	if not _reduced:
		center.x += FeelMotion.shake_offset(_shake_elapsed, FEEL.reticle_shake_seconds, FEEL.reticle_shake_px)
	var tint := Color.WHITE.lerp(FEEL.hover_blocked_color, _flash)
	var backing := Color(FEEL.hover_backing_color, 0.7)
	var width := FEEL.reticle_ring_width_px
	var radius := maxf(_radius + _pop, 1.0)
	if _vacuum and mode != Mode.BLOCKED and mode != Mode.PLACE:
		for index in 12:
			var start := _spin + TAU * float(index) / 12.0
			_arc(center, FEEL.reticle_ring_px, start, start + TAU / 36.0, backing, width + 2.0)
			_arc(center, FEEL.reticle_ring_px, start, start + TAU / 36.0, tint, width)
		draw_circle(center, 1.5, tint, true, -1.0, true)
		return
	match mode:
		Mode.IDLE:
			var collapse := clampf((radius - FEEL.reticle_dot_px) / maxf(FEEL.reticle_ring_px - FEEL.reticle_dot_px, 0.01), 0.0, 1.0)
			if collapse > 0.05:
				# A ring that is still springing back to the dot.
				_arc(center, radius, 0.0, TAU, Color(backing, backing.a * collapse), width + 2.0)
				_arc(center, radius, 0.0, TAU, Color(tint, 0.6 * collapse), width)
			draw_circle(center, FEEL.reticle_dot_px + 1.0, backing, true, -1.0, true)
			draw_circle(center, FEEL.reticle_dot_px, Color(tint, FEEL.reticle_idle_alpha), true, -1.0, true)
		Mode.ACTION:
			_arc(center, radius, 0.0, TAU, backing, width + 2.0)
			_arc(center, radius, 0.0, TAU, tint, width)
			draw_circle(center, 2.5, backing, true, -1.0, true)
			draw_circle(center, 1.5, tint, true, -1.0, true)
		Mode.BLOCKED:
			var amber := FEEL.hover_blocked_color
			for index in 8:
				var start := TAU * float(index) / 8.0
				_arc(center, radius, start, start + TAU / 16.0, backing, width + 2.0)
				_arc(center, radius, start, start + TAU / 16.0, amber, width)
			draw_circle(center, 2.5, backing, true, -1.0, true)
			draw_circle(center, 1.5, amber, true, -1.0, true)
		Mode.PLACE:
			var mint := FEEL.ghost_color.lerp(FEEL.hover_blocked_color, _flash)
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var tip := center + corner * radius
				# Each bracket runs 45% of the half edge from its corner, so the four read as corners.
				var points := PackedVector2Array([
					tip + Vector2(-corner.x * radius * 0.45, 0.0),
					tip,
					tip + Vector2(0.0, -corner.y * radius * 0.45),
				])
				draw_polyline(points, backing, width + 2.0, true)
				draw_polyline(points, mint, width, true)
			draw_circle(center, 1.5, mint, true, -1.0, true)


func _arc(center: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	draw_arc(center, radius, from, to, maxi(6, int(absf(to - from) / TAU * 48.0)), color, width, true)
