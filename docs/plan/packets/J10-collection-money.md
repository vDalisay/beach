# J10 — Collection day: containers, receipt and coins

Dependencies: J09, which provides `MoneyLabel`, the money-hold mechanism and `FeelIcon`. Read first: [plan](../12-game-feel.md) §6 (payment row), §8 and §11.2 (`validate_payment.gd`: the receipt is visible with `$80` in `details_label.text` immediately after the call). Also D15: *"Collection briefly locks eligible bags, commits payment/completion once, then plays a short visual event."*

**Outcome:**

- **The call:** calling collection makes the hotline phone ring and wobble. Every container holding bags lifts off: its fill sinks with a whoosh of sparkles and dust, the container shakes and its label pops.
- **The receipt:** it slides in with a stamped title. Its details type out, and a big gold total counts up.
- **The coins:** gold coins arc from the total into the HUD money line. Each arrival ticks the money up with a bump.
- **Deposits:** depositing a sealed bag bounces the container's fill and shakes it. A thrown-in bag "swishes".
- **Set rewards:** first-time group rewards (`+$15`) also send three coins from the notice to the wallet.

**Own files:**

| File | Change |
|---|---|
| `scripts/ui/coin_flyer.gd` | New |
| `scenes/main.tscn` | Add `CoinFlyer` under `UI`, above HUD panels and below modal views |
| `scripts/main.gd` | Coin orchestration |
| `scripts/ui/collection_receipt.gd`, `scenes/ui/collection_receipt.tscn` | Add a `Total` label |
| `scripts/stations/waste_container.gd` | Visuals only |
| `scripts/stations/collection_call_point.gd` | Ring and cues |

## Steps

### 1. `CoinFlyer`

`scripts/ui/coin_flyer.gd` is a full-rect `Control` with `mouse_filter = IGNORE` and `process_mode = ALWAYS`:

```gdscript
class_name CoinFlyer
extends Control
## Flies up to FEEL.coin_max coin glyphs from a screen point into a target control.

const FEEL := preload("res://data/feel/feel_tuning.tres")

var _coins: Array[FeelIcon] = []
var _flight := 0


func fly(from_global: Vector2, target: Control, count: int, on_coin: Callable, on_done: Callable) -> void:
	clear()
	_flight += 1
	var flight := _flight
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
			coin.scale = Vector2(absf(cos(p * TAU * 1.5)) * 0.9 + 0.1, 1.0) * lerpf(0.7, 1.0, sin(p * PI))
		, 0.0, 1.0, FEEL.coin_seconds)
		t.tween_callback(func() -> void:
			if flight != _flight:
				return
			coin.queue_free()
			_coins.erase(coin)
			on_coin.call(index, count)
			if index == count - 1:
				on_done.call()
		)


func clear() -> void:
	_flight += 1
	for coin in _coins:
		if is_instance_valid(coin):
			coin.queue_free()
	_coins.clear()
```

### 2. Receipt motion (`CollectionReceipt`)

- In the scene, add `Total` (a `Label` with unique name `%Total`, font size 30, `FEEL.money_color` with an outline, centred) after `Details` in `Panel/Rows`.
- Add `signal total_ready(total_pay: int, from_global: Vector2)`.
- In `show_receipt(receipt)`, keep setting `title_label.text` and `details_label.text` exactly as today, so `details_label.text` is final at once. Then:
  - `total_label.text = "+$0"`, or the final value when reduced.
  - Unless reduced:
    - The panel starts `receipt_slide_px` to the right at alpha 0 and tweens in over `receipt_in_seconds` (`TRANS_BACK`/`EASE_OUT`). Use the base-position meta pattern from J09.
    - The title pops: pivot at centre, scale 1.3 → 1.0 over 0.18 s (`TRANS_BACK`).
    - `details_label.visible_ratio` goes 0 → 1 over `receipt_type_seconds` (a typewriter reveal; `text` is unchanged).
    - After the typing, the total counts from 0 to `total_pay` over `receipt_count_seconds` (`TRANS_EXPO`/`EASE_OUT`), then pops (`bump_control` 1.15).
  - At the end, or at once when reduced, emit `total_ready(int(receipt.total_pay), total_label.get_global_rect().get_center())`.
  - Extend the existing auto-hide timer by the intro time (3.0 s + 0.8 s).
- `clear_receipt()` also kills the intro tweens and resets `visible_ratio = 1` and the panel position.

### 3. Money orchestration (`main.gd`)

- Add `@onready var coin_flyer: CoinFlyer = $UI/CoinFlyer` and `var _last_totals := {}`. Store the totals in `_render_progress`.
- **Receipt created.** Connect `collection.receipt_created` to `_on_receipt_created(receipt)`, after the existing receipt connection:
  1. `_money_hold_until = Time.get_ticks_msec() + 5000`.
  2. `_shown["money"] = float(current_money - int(receipt.total_pay))`.
  3. `_render_progress(_last_totals)`.

  This runs in the same frame as the commit's `wallet_changed` roll, so the label never visibly jumps to the new total.
- **Total ready.** Connect `collection_receipt.total_ready` to `_on_receipt_total_ready(total, from)`:
  - When reduced, or `total <= 0`: `_release_money(total)`.
  - Otherwise, with `base := float(_shown.money)` and `count := clampi(total / FEEL.coin_value, FEEL.coin_min, FEEL.coin_max)`, call `coin_flyer.fly(from, money_label, count, per_coin, done)`:
    - `per_coin(i, n)`: set `_shown.money = base + total * float(i + 1) / n`, then `_render_progress(_last_totals)` and `FeelMotion.bump_control(money_label, FEEL.bump_scale, FEEL.bump_seconds)`.
    - `done`: `_release_money(total)`.
- **`_release_money(amount)`:** set `_money_hold_until = 0`, set `_shown.money` to the actual wallet value, call `_render_progress(_last_totals)`, and call `_float_money(amount)` unless reduced. When reduced, flash the money line instead.
- **Group rewards.**
  - In the `group_completed` handler (which runs after `wallet_changed` in the same `finalize_action`): when `int(payload.reward) > 0`, hold the money and subtract the reward from `_shown.money` the same way.
  - In `_flush_group_notice()`, after `_queue_notice(...)`, if `_pending_group_reward > 0` and not reduced, fly `clampi(_pending_group_reward / 5, 1, 3)` coins from `guidance_panel.get_global_rect().get_center()` to `money_label`, with the same per-coin and done logic.
  - Capture the reward amount before `_flush_group_notice` resets it.
- **Safety.** In `clear_run()` and when results open (J12), call `coin_flyer.clear()` and `_release_money(0)`, so the wallet always ends at the true value.

`validate_payment.gd` checks `(state) money == 80`, receipt visibility and `details_label.text.contains("$80")` immediately. All of these hold, because the displayed money is presentation only.

### 4. Containers (`WasteContainer`)

1. Add `var _shown_count := -1`. In `configure()`, `_update_visuals()` sets it without animation.
2. Change `_on_bags_changed(bag_ids)` to `_update_visuals(bag_ids)`.
3. Rewrite `_update_visuals(changed := PackedStringArray())`. Keep the label, meta and colour logic, then compare `count` with `_shown_count`:
   - **Lifted off by collection:** the count dropped and one of `changed` now has `location == "COLLECTED"`. Unless reduced:
     1. Tween `fill.scale.y` to 0 over `FEEL.container_lift_seconds` (`TRANS_BACK`/`EASE_IN`: it dips before it vanishes), then hide the fill.
     2. Burst 10 sparkles upward from the opening (`session.item_view_manager.feel_sparkles(opening.global_position + Vector3.UP * 0.4, 10)`) and 6 dust particles.
     3. Wobble `SyntyContainer` `rotation.z` ±2° over 0.3 s.
     4. `FeelMotion.pop(label, Vector3.ONE * 1.2, 0.06, 0.14)`.

     When reduced, set the final state.
   - **Taken back:** the count dropped for any other reason. Tween the fill down 0.15 s and pop the label.
   - **Deposited:** the count rose. Tween the fill to the new height over 0.25 s (`TRANS_BACK`/`EASE_OUT`), wobble the container and make a small dust puff.
   - Finally, set `_shown_count = count`.
4. `try_deposit_bag`, on success: `player.play_cue(&"deposit", {"arm": &"right"})`.
5. `try_capture_bag`, on success: `FeelRing.spawn(self, opening.global_position + Vector3.UP * 0.1, 0.25, 0.8, 0.3, FEEL.shine_core_color, 0.05)` plus 8 sparkles. This is the "swish".
6. On failure branches in `_on_interact_requested` and `_on_body_entered`: `player.play_cue(&"rejected", {"reason": result.message})`.

### 5. Hotline (`CollectionCallPoint`)

- On success: `_ring(true)` and `player.play_cue(&"collect_call")`.
- On failure: `_ring(false)` and `player.play_cue(&"rejected", {"reason": result.message})`.
- `_ring(success)`:
  - The `SyntyPhone` node wobbles through a `tween_method` over `FEEL.phone_ring_seconds`: `rotation.z = sin(t * TAU * 6.0) * deg_to_rad(FEEL.phone_ring_degrees) * (1.0 - t)`.
  - A failure uses a single 0.15 s shake at half the angle.
  - The `Label` pops.
  - A success also spawns a `FeelRing` at the phone.
  - When reduced, only the label pops (no motion).

## Reduced motion

- **Receipt:** appears in place, full text, final total.
- **Coins:** none. The money line flashes once and shows the final value.
- **Containers:** final fill state at once.
- **Phone:** no wobble.
- **Particles:** half counts.

## Validation

1. Re-run:
   - `validate_payment.gd`: 50 + 30 = $80, repeat call pays 0, receipt text, `Nothing to collect`
   - `validate_sealing.gd`: deposits and captures
   - `validate_completion.gd`: 720p lanes with the taller receipt; confirm the `Total` label keeps the receipt clear of guidance and progress
2. In `scenes/main.tscn` (seed `first-shore`), run a real collection:
   1. Two bags in two containers.
   2. Call collection.
   3. Record the phone, the container lift-off, the receipt typing and count, the coin flight and the money ticking.
   4. Repeat the call with nothing to collect (rejection).
   5. Complete a first-time set (three coins).
   6. Pause mid-flight (coins keep flying; the wallet settles to the true value) and quit to the menu mid-flight (no stray coins next run).
3. Screen checks at 720p and 150% UI scale: coin paths stay on-screen and the total never overlaps the notice lane.

## Done when

- Collection plays as one readable event from call to wallet.
- Deposits and captures react.
- Money display and state always converge.
- Checks pass.
- Reduced motion is observed.
- Clips are in J-feel.
