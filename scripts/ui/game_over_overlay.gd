class_name GameOverOverlay
extends Control
## Full-screen game-over panel: says why the run ended and offers a restart.

signal restart_requested

@onready var title_label: Label = %TitleLabel
@onready var reason_label: Label = %ReasonLabel
@onready var summary_label: Label = %SummaryLabel
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	hide()


## `result` is the Dictionary returned by RunState.end_day().
func show_loss(run: RunState, result: Dictionary) -> void:
	title_label.text = "GAME OVER"
	reason_label.text = run.loss_reason

	var lines: Array[String] = []
	lines.append("Kimmy made it to the end of day %d of %d." % [run.day, run.config.num_days])
	for check: Dictionary in result.get("checks", []):
		var event := check.event as EventData
		lines.append("%s: needed %d, had %d - %s" % [
			event.display_name, check.required, check.actual,
			"PASS" if check.passed else "FAIL"])
	lines.append("Final intellect: %d    Final gloom: %d" % [run.intellect, run.gloom])
	summary_label.text = "\n".join(lines)
	show()
