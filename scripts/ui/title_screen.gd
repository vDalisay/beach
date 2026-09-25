class_name TitleScreen
extends Control
## The title screen: the live beach drifting behind a frosted shade, the wordmark, the main menu,
## and the New beach and Load panels. BeachMain decides what the buttons do (start, continue,
## load, settings); this scene owns how the screen looks, moves and navigates between its panels.

const P := preload("res://scripts/ui/kit/ui_palette.gd")
## Friendly random seeds: "sunny-gull-42".
const SEED_WORDS_A := ["sunny", "breezy", "salty", "golden", "lazy", "sparkly", "tidal", "coral", "sandy", "misty", "happy", "quiet"]
const SEED_WORDS_B := ["gull", "crab", "wave", "shell", "palm", "pier", "dune", "reef", "kite", "surf", "tide", "cove"]

@onready var backdrop: MenuBackdrop = %Backdrop
@onready var frost: ColorRect = %Frost
@onready var column: VBoxContainer = $Column
@onready var logo: TextureRect = %Logo
@onready var logo_sparkles: CPUParticles2D = %LogoSparkles
@onready var menu: VBoxContainer = %Menu
@onready var continue_button: Button = %ContinueButton
@onready var new_button: Button = %NewButton
@onready var load_button: Button = %LoadButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var summary_label: Label = %SummaryLabel
@onready var new_panel: PanelContainer = %NewRunPanel
@onready var seed_input: LineEdit = %SeedInput
@onready var random_seed_button: Button = %RandomSeedButton
@onready var start_button: Button = %StartButton
@onready var back_from_new_button: Button = %BackFromNewButton
@onready var load_panel: PanelContainer = %LoadPanel
@onready var save_list: ItemList = %SaveList
@onready var open_save_button: Button = %OpenSaveButton
@onready var back_from_load_button: Button = %BackFromLoadButton
@onready var status_label: Label = %StatusLabel
@onready var footer: HBoxContainer = %Footer

var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.frost = frost.material as ShaderMaterial
	backdrop.cut.connect(_on_backdrop_cut)
	new_button.pressed.connect(show_new_panel)
	back_from_new_button.pressed.connect(hide_panels)
	random_seed_button.pressed.connect(_random_seed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	get_viewport().size_changed.connect(_fit_menu)
	_rng.randomize()
	hide()


## Footer prompts follow the player's device and bindings.
func configure(settings: SettingsStore) -> void:
	for child in footer.get_children():
		child.queue_free()
	footer.add_child(PromptChip.new().setup(settings, &"ui_accept", "Select"))
	footer.add_child(PromptChip.new().setup(settings, &"ui_cancel", "Back"))


func open() -> void:
	var was_open := visible and backdrop.running()
	show()
	backdrop.start()
	new_panel.hide()
	load_panel.hide()
	column.show()
	menu.show()
	_fit_menu()
	set_process(true)
	if not was_open:
		_intro()


func close() -> void:
	backdrop.stop()
	set_process(false)
	hide()


func focus_default() -> void:
	if not continue_button.disabled:
		continue_button.grab_focus()
	else:
		new_button.grab_focus()


## "first-shore · 1,234 / 5,700 · 25 Sep 14:02" under the menu when there is a run to continue.
func set_continue_summary(text: String) -> void:
	summary_label.text = text
	summary_label.visible = not text.is_empty()


func show_new_panel() -> void:
	column.hide()
	load_panel.hide()
	new_panel.show()
	_screen_in(new_panel)
	start_button.grab_focus()


func show_load_panel() -> void:
	column.hide()
	new_panel.hide()
	load_panel.show()
	_screen_in(load_panel)


func hide_panels() -> void:
	var from_load := load_panel.visible
	new_panel.hide()
	load_panel.hide()
	column.show()
	menu.show()
	if UiKit.kit() != null:
		UiKit.kit().stagger_in(menu)
	(load_button if from_load else new_button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo() or not event.is_action_pressed(&"ui_cancel"):
		return
	if new_panel.visible or load_panel.visible:
		hide_panels()
		get_viewport().set_input_as_handled()


## Short screens (a 16:9 window at 150 % UI scale is 480 px tall) get slimmer buttons, so the
## wordmark keeps some room above the menu.
func _fit_menu() -> void:
	var short := get_viewport_rect().size.y < 560.0
	menu.add_theme_constant_override(&"separation", 7 if short else 12)
	for child in menu.get_children():
		if child is Button:
			(child as Button).custom_minimum_size.y = 44.0 if short else 56.0
			(child as Button).add_theme_font_size_override(&"font_size", 18 if short else 21)
	logo_sparkles.position = logo.size * 0.5
	logo_sparkles.emission_rect_extents = logo.size * 0.4


func _process(delta: float) -> void:
	_time += delta
	if UiKit.reduced():
		logo.rotation = 0.0
		FeelMotion.nudge_y(logo, 0.0)
		return
	# The wordmark floats: a slow bob and a slight rock, like a sign in a sea breeze.
	logo.pivot_offset = logo.size * 0.5
	FeelMotion.nudge_y(logo, sin(_time * 1.1) * 5.0)
	logo.rotation = deg_to_rad(sin(_time * 0.7) * 0.8)


func _intro() -> void:
	var kit := UiKit.kit()
	if kit == null or UiKit.reduced():
		logo.scale = Vector2.ONE
		logo.modulate.a = 1.0
		return
	logo.pivot_offset = logo.size * 0.5
	logo.scale = Vector2.ONE * 0.6
	logo.modulate.a = 0.0
	var t := FeelMotion.replace(logo, &"intro", FeelMotion.tween(logo).set_parallel(true))
	t.tween_property(logo, "modulate:a", 1.0, 0.25)
	t.tween_property(logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(func() -> void: kit.burst(logo.get_global_rect().get_center(), UiKit.Burst.STAR, 12))
	kit.stagger_in(menu, 0.25)
	kit.stagger_in(footer, 0.5)


func _screen_in(panel: Control) -> void:
	if UiKit.kit() != null:
		UiKit.kit().fit(panel)
		UiKit.kit().screen_in(panel)


func _on_backdrop_cut() -> void:
	if not UiKit.reduced():
		logo_sparkles.restart()


func _random_seed() -> void:
	seed_input.text = "%s-%s-%d" % [SEED_WORDS_A[_rng.randi() % SEED_WORDS_A.size()], SEED_WORDS_B[_rng.randi() % SEED_WORDS_B.size()], _rng.randi_range(10, 99)]
	if UiKit.kit() != null:
		UiKit.kit().pop(seed_input, 1.06, 0.2)
