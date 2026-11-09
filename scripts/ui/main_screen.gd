class_name MainScreen
extends Control
## The day screen. Reads RunState and forwards clicks to it; holds no rules.

const PIP_FULL := Color(1, 0.85, 0.2, 1)
const PIP_EMPTY := Color(0.25, 0.25, 0.28, 1)

@export var config: GameConfig = preload("res://data/GameConfig.tres")

var run: RunState
var card_buttons: Array[CardButton] = []

@onready var day_label: Label = %DayLabel
@onready var energy_pips: HBoxContainer = %EnergyPips
@onready var streak_label: Label = %StreakLabel
@onready var intellect_bar: StatBar = %IntellectBar
@onready var gloom_bar: StatBar = %GloomBar
@onready var lock_label: Label = %LockLabel
@onready var log_label: Label = %LogLabel
@onready var status_label: Label = %StatusLabel
@onready var card_row: HBoxContainer = %CardRow
@onready var end_day_button: Button = %EndDayButton


func _ready() -> void:
	end_day_button.pressed.connect(_on_end_day_pressed)
	start_run()


func start_run() -> void:
	run = RunState.new(config)
	run.changed.connect(_refresh)
	_build_cards()
	_build_energy_pips()
	log_label.text = "Day 1. Kimmy has %d energy. Click a card to spend it." % run.energy
	_refresh()


func _build_cards() -> void:
	for button: CardButton in card_buttons:
		button.queue_free()
	card_buttons.clear()
	for card: CardData in config.cards:
		var button := CardButton.new()
		button.setup(card)
		button.pressed.connect(_on_card_pressed.bind(card))
		card_row.add_child(button)
		card_buttons.append(button)


func _build_energy_pips() -> void:
	for child: Node in energy_pips.get_children():
		energy_pips.remove_child(child)
		child.queue_free()
	for i in config.start_energy:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(28, 28)
		energy_pips.add_child(pip)


func _on_card_pressed(card: CardData) -> void:
	var before_intellect := run.intellect
	var before_gloom := run.gloom
	if not run.play_card(card):
		return
	var parts: Array[String] = []
	if run.intellect != before_intellect:
		parts.append("%+d intellect" % (run.intellect - before_intellect))
	if run.gloom != before_gloom:
		parts.append("%+d gloom" % (run.gloom - before_gloom))
	log_label.text = "%s: %s." % [card.display_name, ", ".join(parts) if not parts.is_empty() else "no change"]
	if run.energy == 0:
		log_label.text += " Out of energy - end the day."


func _on_end_day_pressed() -> void:
	var finished_day := run.day
	run.end_day()
	if run.is_lost:
		log_label.text = "Day %d ended." % finished_day
	elif run.is_won:
		log_label.text = "Kimmy survived all %d days!" % config.num_days
	else:
		log_label.text = "Day %d ended. Day %d begins: energy refilled to %d." % [
			finished_day, run.day, run.energy]
		if run.locked:
			log_label.text += " Kimmy is too gloomy to study today."


func _refresh() -> void:
	day_label.text = "Day %d / %d" % [run.day, config.num_days]
	streak_label.text = "Study streak: %d" % run.study_streak
	if run.study_streak > 0:
		streak_label.text += "  (next Study x%.1f)" % (config.streak_percent(run.study_streak + 1) / 100.0)

	var pips := energy_pips.get_children()
	for i in pips.size():
		(pips[i] as ColorRect).color = PIP_FULL if i < run.energy else PIP_EMPTY

	intellect_bar.set_values(run.intellect, config.intellect_display_max)
	gloom_bar.set_values(run.gloom, config.gloom_loss_threshold,
			config.gloom_lockout_threshold, "lockout %d" % config.gloom_lockout_threshold)
	lock_label.visible = run.locked
	lock_label.text = "LOCKED: gloom was %d+ at the end of yesterday. Study is unavailable today." % config.gloom_lockout_threshold

	for button: CardButton in card_buttons:
		button.refresh(run)

	end_day_button.disabled = run.is_over()
	status_label.visible = run.is_over()
	if run.is_lost:
		status_label.text = "RUN OVER - %s" % run.loss_reason
	elif run.is_won:
		status_label.text = "YOU WIN! Kimmy made it through all %d days." % config.num_days
