class_name PromptChip
extends HBoxContainer
## "[glyph] VERB": an input icon for an action followed by what it does. Used by the target
## prompt, HUD hints, the sorting table and menus. `style` picks the label look: HudVerb on the
## world, Subheading on paper.

var glyph := InputGlyph.new()
var label := Label.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(glyph)
	label.theme_type_variation = &"HudVerb"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func setup(settings: SettingsStore, action: StringName, verb: String, style := &"HudVerb", height := 26.0) -> PromptChip:
	glyph.glyph_height = height
	glyph.configure(settings, action)
	label.text = verb.to_upper()
	label.theme_type_variation = style
	label.visible = not verb.is_empty()
	return self


## "Verb [binding]" in words, as the old text prompts read.
func plain_text() -> String:
	return "%s [%s]" % [label.text.capitalize(), glyph.text()] if label.visible else "[%s]" % glyph.text()
