class_name LoadingCurtain
extends Control
## Covers the screen while a run is built or loaded (the build blocks the main thread for a moment),
## then lifts to reveal the beach. Shows the wordmark, the Modern Menus loading ring and a tip.

const TIPS := [
	"Trash only counts once the truck collects it: sort it, seal the bag, then call the truck.",
	"Every item in the right bin adds a bonus to the truck's payment.",
	"Wipe a stained chair with the cloth before you place it back.",
	"Finishing a set of props pays a reward the first time.",
	"Surface before your air runs out, or what you carry drops to the sea floor.",
	"The field booklet shows what is left in every part of the beach.",
]

@onready var ring: TextureRect = %Ring
@onready var tip_label: Label = %Tip

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	hide()
	set_process(false)


## Shows the curtain and waits until it has actually been drawn, so a blocking build that follows
## happens behind it rather than on a frozen menu.
func cover() -> void:
	tip_label.text = TIPS[_rng.randi() % TIPS.size()]
	FeelMotion.replace(self, &"curtain", null)
	modulate.a = 1.0
	show()
	set_process(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


## Lifts the curtain: a short fade (instant under reduced motion).
func reveal() -> void:
	if not visible:
		return
	if UiKit.reduced():
		hide()
		set_process(false)
		return
	var t := FeelMotion.replace(self, &"curtain", FeelMotion.tween(self))
	t.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		hide()
		set_process(false)
		modulate.a = 1.0
	)


func _process(delta: float) -> void:
	ring.pivot_offset = ring.size * 0.5
	ring.rotation += delta * TAU * 0.6
