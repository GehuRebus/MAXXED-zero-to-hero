class_name EventPopup
extends Control
## End-of-day results: each event, requirement vs Kimmy's stat, pass/fail,
## and what the events did to her stats.

signal closed

const PASS_COLOR := Color(0.45, 0.9, 0.5, 1)
const FAIL_COLOR := Color(1, 0.45, 0.4, 1)

@onready var title_label: Label = %TitleLabel
@onready var lines_box: VBoxContainer = %LinesBox
@onready var continue_button: Button = %ContinueButton

## Plain-text copy of the shown lines, for tests.
var shown_lines: Array[String] = []


func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	hide()


## `result` is the Dictionary returned by RunState.end_day().
func show_result(result: Dictionary) -> void:
	for child: Node in lines_box.get_children():
		lines_box.remove_child(child)
		child.free()  # plain display nodes; free now, not at frame end
	shown_lines.clear()
	title_label.text = "End of day %d" % result.day

	for check: Dictionary in result.checks:
		var event := check.event as EventData
		var stat := ScheduleStrip._stat_short(event.check_stat)
		_add_line("%s - needs %s %d, Kimmy has %d: %s" % [
				event.display_name, stat, check.required, check.actual,
				"PASS" if check.passed else "FAIL"],
				PASS_COLOR if check.passed else FAIL_COLOR)

	for effect: Dictionary in result.effects:
		var event := effect.event as EventData
		var parts: Array[String] = []
		if effect.intellect != 0:
			parts.append("%+d intellect" % effect.intellect)
		if effect.gloom != 0:
			parts.append("%+d gloom" % effect.gloom)
		var prefix := "%s: " % event.display_name
		if not event.is_check():
			prefix = "Surprise! %s: " % event.display_name
		_add_line(prefix + ", ".join(parts), Color.WHITE)

	if result.lost:
		_add_line(str(result.loss_reason), FAIL_COLOR)
	continue_button.text = "See what happened" if result.lost else "Continue"
	show()


func _add_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	lines_box.add_child(label)
	shown_lines.append(text)


func _on_continue() -> void:
	hide()
	closed.emit()
