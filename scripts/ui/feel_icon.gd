class_name FeelIcon
extends Control
## A small glyph drawn with antialiased primitives inside its rect, so nothing depends on font
## coverage. The shape carries the meaning (a check, a question mark), not only the colour.

enum Kind { CHECK, QUESTION, STAR, COIN, ARROW, INFO }

@export var kind := Kind.CHECK:
	set(value):
		kind = value
		queue_redraw()
@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size
	var center := s * 0.5
	var radius := minf(s.x, s.y) * 0.46
	match kind:
		Kind.CHECK:
			var width := s.y * 0.14
			var points := PackedVector2Array([Vector2(0.18, 0.55) * s, Vector2(0.42, 0.78) * s, Vector2(0.84, 0.28) * s])
			draw_polyline(points, color, width, true)
			# Round caps and joint.
			for point in points:
				draw_circle(point, width * 0.5, color, true, -1.0, true)
		Kind.QUESTION:
			var font := get_theme_default_font()
			var font_size := maxi(int(s.y * 0.9), 8)
			var text_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var baseline := (s.y - text_size.y) * 0.5 + font.get_ascent(font_size)
			draw_string(font, Vector2((s.x - text_size.x) * 0.5, baseline), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		Kind.STAR:
			var star := PackedVector2Array()
			for index in 8:
				var angle := -PI * 0.5 + index * PI / 4.0
				star.append(center + Vector2(cos(angle), sin(angle)) * (radius if index % 2 == 0 else radius * 0.38))
			draw_colored_polygon(star, color)
		Kind.COIN:
			draw_circle(center, radius, color, true, -1.0, true)
			draw_arc(center, radius * 0.72, 0.0, TAU, 32, color.darkened(0.3), maxf(radius * 0.12, 1.0), true)
			draw_arc(center, radius * 0.5, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.75), maxf(radius * 0.12, 1.0), true)
		Kind.ARROW:
			# A chevron pointing +X; rotate the control to aim it.
			draw_colored_polygon(PackedVector2Array([Vector2(0.22, 0.12) * s, Vector2(0.84, 0.5) * s, Vector2(0.22, 0.88) * s, Vector2(0.42, 0.5) * s]), color)
		Kind.INFO:
			var width := maxf(radius * 0.14, 1.0)
			draw_arc(center, radius - width * 0.5, 0.0, TAU, 32, color, width, true)
			draw_circle(center + Vector2(0.0, -radius * 0.42), radius * 0.12, color, true, -1.0, true)
			draw_rect(Rect2(center + Vector2(-radius * 0.09, -radius * 0.18), Vector2(radius * 0.18, radius * 0.62)), color)
