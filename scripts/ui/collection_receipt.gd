class_name CollectionReceipt
extends Control

@onready var title_label: Label = %Title
@onready var details_label: Label = %Details

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
	modulate.a = 1.0
	show()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(self) and serial == _display_serial:
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.4)
			tween.finished.connect(hide)
	)


func clear_receipt() -> void:
	_display_serial += 1
	hide()
