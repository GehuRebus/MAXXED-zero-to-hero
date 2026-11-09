class_name ScheduleStrip
extends HBoxContainer
## "Coming up": today plus the next few days, showing only the stat checks
## (random events are surprises). Placeholder art: one colored block per day.

const TODAY_COLOR := Color(0.32, 0.36, 0.46, 1)
const DAY_COLOR := Color(0.22, 0.25, 0.32, 1)
const CHECK_COLOR := Color(0.75, 0.3, 0.3, 1)

## Day number shown in each cell, for tests.
var shown_days: Array[int] = []


func refresh(run: RunState) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()  # plain display nodes; free now, not at frame end
	shown_days.clear()

	var last := mini(run.day + run.config.schedule_lookahead_days, run.config.num_days)
	for d in range(run.day, last + 1):
		shown_days.append(d)
		add_child(_cell(run, d))


func _cell(run: RunState, d: int) -> Control:
	var checks := run.schedule.visible_on(d)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 92)
	var box := StyleBoxFlat.new()
	box.bg_color = TODAY_COLOR if d == run.day else DAY_COLOR
	box.set_corner_radius_all(8)
	box.set_content_margin_all(8)
	if not checks.is_empty():
		box.set_border_width_all(3)
		box.border_color = CHECK_COLOR
	panel.add_theme_stylebox_override("panel", box)

	var lines: Array[String] = ["Today (day %d)" % d if d == run.day else "Day %d" % d]
	if checks.is_empty():
		lines.append("-")
	for event: EventData in checks:
		lines.append("%s: %s %d+" % [event.display_name, _stat_short(event.check_stat), event.check_min])

	var label := Label.new()
	label.text = "\n".join(lines)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)
	return panel


static func _stat_short(stat: EventData.Stat) -> String:
	return "gloom" if stat == EventData.Stat.GLOOM else "intellect"
