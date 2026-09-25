class_name CoinFlyer
extends Control
## Flies up to FEEL.coin_max coin glyphs from a screen point into a target control. Several
## flights may overlap; clear() cancels them all without running their callbacks.

const FEEL := preload("res://data/feel/feel_tuning.tres")

var _coins: Array[FeelIcon] = []
var _epoch := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func fly(from_global: Vector2, target: Control, count: int, on_coin: Callable, on_done: Callable) -> void:
	var epoch := _epoch
	count = clampi(count, 1, FEEL.coin_max)
	for index in count:
		var coin := FeelIcon.new()
		coin.kind = FeelIcon.Kind.COIN
		coin.color = FEEL.money_color
		coin.size = Vector2(18, 18)
		coin.pivot_offset = coin.size * 0.5
		add_child(coin)
		_coins.append(coin)
		coin.global_position = from_global - coin.size * 0.5
		coin.modulate.a = 0.0
		var side := (FeelMotion.cosmetic_random(index, 7) - 0.5) * 120.0
		var t := FeelMotion.tween(coin)
		t.tween_interval(index * FEEL.coin_stagger)
		t.tween_property(coin, "modulate:a", 1.0, 0.05)
		t.tween_method(func(p: float) -> void:
			if not is_instance_valid(target):
				return
			var end := target.get_global_rect().get_center() - coin.size * 0.5
			var start := from_global - coin.size * 0.5
			var control := (start + end) * 0.5 + Vector2(side, -140.0)
			var e := FeelMotion.ease_in_out_cubic(p)
			var u := 1.0 - e
			coin.global_position = start * (u * u) + control * (2.0 * u * e) + end * (e * e)
			# A spinning coin: the width flips while it swells in mid-flight.
			coin.scale = Vector2(absf(cos(p * TAU * 1.5)) * 0.9 + 0.1, 1.0) * lerpf(0.7, 1.0, sin(p * PI))
		, 0.0, 1.0, FEEL.coin_seconds)
		t.tween_callback(func() -> void:
			if epoch != _epoch:
				return
			coin.queue_free()
			_coins.erase(coin)
			on_coin.call(index, count)
			if index == count - 1:
				on_done.call()
		)


func live_count() -> int:
	var live := 0
	for coin in _coins:
		if is_instance_valid(coin):
			live += 1
	return live


func clear() -> void:
	_epoch += 1
	for coin in _coins:
		if is_instance_valid(coin):
			coin.queue_free()
	_coins.clear()
