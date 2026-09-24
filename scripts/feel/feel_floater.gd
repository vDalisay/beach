class_name FeelFloater
extends Label3D
## Self-freeing billboard text that rises and fades ("+$15", "Clean!", "Freed!").
## Use ASCII text: Label3D glyph coverage for symbols such as a check mark is not guaranteed.

const FEEL := preload("res://data/feel/feel_tuning.tres")
const LIVE_CAP := 3

static var _live: Array[FeelFloater] = []


static func spawn(parent: Node, at: Vector3, message: String, color: Color, reduced := false) -> FeelFloater:
	if parent == null or not parent.is_inside_tree():
		return null
	while _live.size() >= LIVE_CAP:
		var oldest: FeelFloater = _live.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var floater := FeelFloater.new()
	floater.name = "FeelFloater"
	floater.text = message
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.font_size = 56
	floater.pixel_size = 0.0035
	floater.outline_size = 12
	floater.modulate = color
	floater.outline_modulate = Color(0.04, 0.08, 0.1, 0.9)
	floater.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(floater)
	floater.global_position = at
	_live.append(floater)
	floater._play(reduced)
	return floater


func _play(reduced: bool) -> void:
	var t := FeelMotion.tween(self)
	if not reduced:
		scale = Vector3.ONE * 0.6
		t.tween_property(self, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "position:y", position.y + FEEL.floater_rise, FEEL.floater_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(maxf(FEEL.floater_seconds - 0.4, 0.0))
	t.chain().tween_callback(queue_free)


func _exit_tree() -> void:
	_live.erase(self)
