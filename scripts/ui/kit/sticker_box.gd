@tool
class_name StickerBox
extends StyleBox
## The wordmark's sticker look as a StyleBox: a solid drop shadow, a navy rim, a white inner line
## and a vertical gradient fill with an optional gloss band. It is drawn as antialiased geometry,
## so it stays sharp at every UI scale and resolution. Everything but the shadow stays inside the
## control's rect, so layouts are unchanged.

@export var fill_top := Color.WHITE:
	set(value):
		fill_top = value
		emit_changed()
@export var fill_bottom := Color.WHITE:
	set(value):
		fill_bottom = value
		emit_changed()
@export var rim_color := UiPalette.NAVY:
	set(value):
		rim_color = value
		emit_changed()
@export var rim_width := 3.0:
	set(value):
		rim_width = value
		emit_changed()
@export var line_color := Color.WHITE:
	set(value):
		line_color = value
		emit_changed()
@export var line_width := 2.0:
	set(value):
		line_width = value
		emit_changed()
@export var corner_radius := 12.0:
	set(value):
		corner_radius = value
		emit_changed()
@export var shadow_color := Color(UiPalette.NAVY, 0.55):
	set(value):
		shadow_color = value
		emit_changed()
@export var shadow_offset := Vector2(0.0, 4.0):
	set(value):
		shadow_offset = value
		emit_changed()
## Strength of the white band over the upper part of the fill (0 = none).
@export_range(0.0, 1.0) var gloss := 0.0:
	set(value):
		gloss = value
		emit_changed()

const CORNER_STEPS := 6


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var radius := minf(corner_radius, minf(rect.size.x, rect.size.y) * 0.5)
	if shadow_color.a > 0.0 and shadow_offset != Vector2.ZERO:
		_shape(to_canvas_item, Rect2(rect.position + shadow_offset, rect.size), radius, shadow_color, shadow_color)
	var inner := rect
	if rim_width > 0.0 and rim_color.a > 0.0:
		_shape(to_canvas_item, rect, radius, rim_color, rim_color)
		inner = rect.grow(-rim_width)
		radius = maxf(radius - rim_width, 0.0)
	if line_width > 0.0 and line_color.a > 0.0:
		_shape(to_canvas_item, inner, radius, line_color, line_color)
		inner = inner.grow(-line_width)
		radius = maxf(radius - line_width, 0.0)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	if fill_top.a > 0.0 or fill_bottom.a > 0.0:
		_shape(to_canvas_item, inner, radius, fill_top, fill_bottom)
	if gloss > 0.0:
		var band := Rect2(inner.position + Vector2(radius * 0.35, inner.size.y * 0.08), Vector2(inner.size.x - radius * 0.7, inner.size.y * 0.38))
		if band.size.x > 2.0 and band.size.y > 2.0:
			_shape(to_canvas_item, band, minf(radius * 0.6, band.size.y * 0.5), Color(1, 1, 1, 0.55 * gloss), Color(1, 1, 1, 0.05 * gloss))


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.merge(Rect2(rect.position + shadow_offset, rect.size)).grow(1.0)


## Fills a rounded rectangle with a top-to-bottom gradient and an antialiased edge.
func _shape(item: RID, rect: Rect2, radius: float, top: Color, bottom: Color) -> void:
	var points := _rounded(rect, radius)
	var colors := PackedColorArray()
	colors.resize(points.size())
	var same := top == bottom
	for index in points.size():
		colors[index] = top if same else top.lerp(bottom, clampf((points[index].y - rect.position.y) / rect.size.y, 0.0, 1.0))
	RenderingServer.canvas_item_add_polygon(item, points, colors)
	var outline := points.duplicate()
	outline.append(points[0])
	var outline_colors := colors.duplicate()
	outline_colors.append(colors[0])
	RenderingServer.canvas_item_add_polyline(item, outline, outline_colors, 1.0, true)


static func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if radius <= 0.5:
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var centers := [
		Vector2(rect.end.x - radius, rect.position.y + radius),
		Vector2(rect.end.x - radius, rect.end.y - radius),
		Vector2(rect.position.x + radius, rect.end.y - radius),
		Vector2(rect.position.x + radius, rect.position.y + radius),
	]
	for corner in 4:
		var start := -PI * 0.5 + corner * PI * 0.5
		for step in CORNER_STEPS + 1:
			var angle := start + PI * 0.5 * float(step) / float(CORNER_STEPS)
			points.append((centers[corner] as Vector2) + Vector2(cos(angle), sin(angle)) * radius)
	return points
