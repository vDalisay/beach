class_name CollectionReceipt
extends Control

## The gold total is on screen and final; main flies coins from `from_global` to the wallet.
signal total_ready(total_pay: int, from_global: Vector2)

const FEEL := preload("res://data/feel/feel_tuning.tres")

@onready var title_label: Label = %Title
@onready var details_label: Label = %Details
@onready var total_label: Label = %Total
@onready var panel: Control = $Panel

## Set by main so the intro follows the reduced-motion setting.
var settings: SettingsStore
var _display_serial := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_receipt(receipt: Dictionary) -> void:
	_display_serial += 1
	var serial := _display_serial
	title_label.text = "COLLECTION COMPLETE"
	details_label.text = "%d items collected · %d sorted correctly\nBase $%d + bonus $%d = $%d" % [
		int(receipt.item_count), int(receipt.correct_count), int(receipt.base_pay),
		int(receipt.bonus_pay), int(receipt.total_pay)]
	var total := int(receipt.total_pay)
	_reset_intro()
	modulate.a = 1.0
	show()
	var reduced := settings != null and FeelMotion.reduced(settings)
	if reduced:
		total_label.text = "+$%d" % total
		_emit_total_ready.call_deferred(total, serial)
	else:
		_play_intro(total, serial)
	get_tree().create_timer(3.0 + 0.8).timeout.connect(func() -> void:
		if is_instance_valid(self) and serial == _display_serial:
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.4)
			tween.finished.connect(hide)
	)


func clear_receipt() -> void:
	_display_serial += 1
	_reset_intro()
	hide()


## Slides in with a stamped title, types the details, counts the gold total up and pops it.
func _play_intro(total: int, serial: int) -> void:
	FeelMotion.nudge_x(panel, FEEL.receipt_slide_px)
	panel.modulate.a = 0.0
	title_label.pivot_offset = title_label.size * 0.5
	title_label.scale = Vector2.ONE * 1.3
	details_label.visible_ratio = 0.0
	total_label.text = "+$0"
	var t := FeelMotion.replace(self, &"intro", FeelMotion.tween(self).set_parallel(true))
	t.tween_method(func(pixels: float) -> void: FeelMotion.nudge_x(panel, pixels), FEEL.receipt_slide_px, 0.0, FEEL.receipt_in_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, FEEL.receipt_in_seconds)
	t.tween_property(title_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(details_label, "visible_ratio", 1.0, FEEL.receipt_type_seconds)
	t.chain().tween_method(func(value: float) -> void: total_label.text = "+$%d" % roundi(value), 0.0, float(total), FEEL.receipt_count_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(func() -> void:
		total_label.text = "+$%d" % total
		FeelMotion.bump_control(total_label, 1.15, 0.16)
		_emit_total_ready(total, serial)
	)


func _emit_total_ready(total: int, serial: int) -> void:
	if serial == _display_serial and visible:
		total_ready.emit(total, total_label.get_global_rect().get_center())


func _reset_intro() -> void:
	FeelMotion.replace(self, &"intro", null)
	details_label.visible_ratio = 1.0
	title_label.scale = Vector2.ONE
	panel.modulate.a = 1.0
	FeelMotion.nudge_x(panel, 0.0)
