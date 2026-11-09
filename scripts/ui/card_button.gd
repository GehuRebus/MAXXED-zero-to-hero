class_name CardButton
extends Button
## Placeholder card: a solid-colored button showing the card's name, cost,
## and current effect. Greyed out with the reason when it can't be played.

const DISABLED_COLOR := Color(0.3, 0.3, 0.33, 1)

var card: CardData


func setup(card_data: CardData) -> void:
	card = card_data
	name = "Card_%s" % card.id
	custom_minimum_size = Vector2(230, 250)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_mode = Control.FOCUS_NONE
	add_theme_font_size_override("font_size", 20)
	add_theme_stylebox_override("normal", _box(card.color))
	add_theme_stylebox_override("hover", _box(card.color.lightened(0.15)))
	add_theme_stylebox_override("pressed", _box(card.color.darkened(0.2)))
	add_theme_stylebox_override("disabled", _box(DISABLED_COLOR))
	add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.68, 1))


func refresh(run: RunState) -> void:
	var lines: Array[String] = [card.display_name.to_upper(), "Cost: %d energy" % card.energy_cost]
	var intellect := run.preview_intellect_delta(card)
	if intellect != 0:
		lines.append("%+d intellect" % intellect)
	if card.gloom_delta != 0:
		lines.append("%+d gloom" % card.gloom_delta)
	if card.uses_study_streak and run.study_streak > 0:
		lines.append("(streak x%.1f)" % (run.config.streak_percent(run.study_streak + 1) / 100.0))
	var reason := run.block_reason(card)
	disabled = not reason.is_empty()
	if disabled:
		lines.append(reason)
	text = "\n".join(lines)
	tooltip_text = card.description


func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(10)
	box.set_border_width_all(3)
	box.border_color = color.darkened(0.4)
	box.set_content_margin_all(12)
	return box
