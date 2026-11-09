class_name GameOverOverlay
extends Control
## Full-screen end-of-run panel (loss or win): says why the run ended and
## offers a restart.

signal restart_requested
signal menu_requested

const LOSE_COLOR := Color(1, 0.45, 0.4, 1)
const WIN_COLOR := Color(0.45, 0.9, 0.5, 1)

@onready var panel: PanelContainer = $Center/Panel
@onready var title_label: Label = %TitleLabel
@onready var reason_label: Label = %ReasonLabel
@onready var summary_label: Label = %SummaryLabel
@onready var seed_label: Label = %SeedLabel
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MainMenuButton

var is_win: bool = false


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	hide()


## `result` is the Dictionary returned by RunState.end_day().
func show_loss(run: RunState, result: Dictionary) -> void:
	is_win = false
	_style(LOSE_COLOR, Color(0.22, 0.12, 0.14, 1))
	title_label.text = "GAME OVER"
	reason_label.text = run.loss_reason
	restart_button.text = "Restart"

	var lines: Array[String] = []
	lines.append("Kimmy made it to the end of day %d of %d." % [run.day, run.config.num_days])
	for check: Dictionary in result.get("checks", []):
		var event := check.event as EventData
		lines.append("%s: needed %d, had %d - %s" % [
			event.display_name, check.required, check.actual,
			"PASS" if check.passed else "FAIL"])
	lines.append("Final intellect: %d    Final gloom: %d" % [run.intellect, run.gloom])
	summary_label.text = "\n".join(lines)
	_show_common(run)


func show_win(run: RunState) -> void:
	is_win = true
	_style(WIN_COLOR, Color(0.12, 0.22, 0.15, 1))
	title_label.text = "YOU WIN!"
	reason_label.text = "Kimmy survived all %d days of college." % run.config.num_days
	restart_button.text = "Play again"
	summary_label.text = "Exams and labs passed: %d\nFinal intellect: %d    Final gloom: %d" % [
		run.checks_passed, run.intellect, run.gloom]
	_show_common(run)


func _show_common(run: RunState) -> void:
	seed_label.text = "Seed %d%s" % [run.rng_seed, " (fixed)" if run.seed_was_fixed else ""]
	show()


func _style(accent: Color, background: Color) -> void:
	var box := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.border_color = accent
	box.bg_color = background
	panel.add_theme_stylebox_override("panel", box)
	title_label.add_theme_color_override("font_color", accent)
