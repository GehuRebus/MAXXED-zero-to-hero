class_name RunState
extends RefCounted
## Pure game logic for one run. No Node or UI dependencies, so it can be
## unit-tested headless. The UI reads the fields and listens to `changed`.

signal changed

const REASON_RUN_OVER := "The run is over."
const REASON_NO_ENERGY := "No energy left today."
const REASON_GLOOM_LOCK := "Too gloomy to study (gloom was %d+ at the end of yesterday)."
const LOSS_INTELLECT := "Kimmy's intellect hit %d. She dropped out."
const LOSS_GLOOM := "Kimmy ended the day at %d gloom (the limit is %d). She gave up."
const LOSS_EVENT := "Failed %s: needed %s %d, had %d."

var config: GameConfig
var day: int = 1
var energy: int = 0
var intellect: int = 0
var gloom: int = 0
## Number of consecutive streak cards played so far today.
var study_streak: int = 0
## True while cards tagged blocked_by_gloom can't be played.
var locked: bool = false
var is_lost: bool = false
var is_won: bool = false
var loss_reason: String = ""
## Machine-readable cause: "intellect", "gloom", or the failed event's id.
var loss_cause: String = ""
var schedule: Schedule
## Seed that generated this run's schedule (reuse it to replay the run).
var rng_seed: int = 0
## True when the seed was supplied rather than rolled.
var seed_was_fixed: bool = false
## Stat checks passed so far this run.
var checks_passed: int = 0


## Pass `run_schedule` to use a fixed schedule (tests); otherwise one is
## generated from `seed_value`, or from a random seed if it's negative.
func _init(game_config: GameConfig, run_schedule: Schedule = null, seed_value: int = -1) -> void:
	assert(game_config != null, "RunState needs a GameConfig")
	config = game_config
	energy = config.start_energy
	intellect = maxi(config.start_intellect, 0)
	gloom = maxi(config.start_gloom, 0)
	# Pick the seed explicitly: after randomize(), rng.seed doesn't report a
	# value that reproduces the sequence.
	seed_was_fixed = seed_value >= 0
	rng_seed = seed_value if seed_was_fixed else randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	schedule = run_schedule if run_schedule != null else Schedule.generate(config, rng)


## Cheap copy sharing config and schedule, for "what if" planning (the
## balance simulator). Signals are not copied.
func copy() -> RunState:
	var c := RunState.new(config, schedule, rng_seed)
	c.seed_was_fixed = seed_was_fixed
	c.day = day
	c.energy = energy
	c.intellect = intellect
	c.gloom = gloom
	c.study_streak = study_streak
	c.locked = locked
	c.is_lost = is_lost
	c.is_won = is_won
	c.loss_reason = loss_reason
	c.loss_cause = loss_cause
	c.checks_passed = checks_passed
	return c


func is_over() -> bool:
	return is_lost or is_won


## Empty string means the card can be played. The gloom lock is reported
## before "no energy" because it's the more useful thing to tell the player.
func block_reason(card: CardData) -> String:
	if is_over():
		return REASON_RUN_OVER
	if locked and card.has_tag(CardData.TAG_BLOCKED_BY_GLOOM):
		return REASON_GLOOM_LOCK % config.gloom_lockout_threshold
	if energy < card.energy_cost:
		return REASON_NO_ENERGY
	return ""


func can_play(card: CardData) -> bool:
	return block_reason(card).is_empty()


## Intellect the card would give if played right now (streak included).
func preview_intellect_delta(card: CardData) -> int:
	if card.uses_study_streak:
		return (card.intellect_delta * config.streak_percent(study_streak + 1)) / 100
	return card.intellect_delta


func play_card(card: CardData) -> bool:
	if not can_play(card):
		return false
	var intellect_gain := preview_intellect_delta(card)
	if card.uses_study_streak:
		study_streak += 1
	else:
		study_streak = 0
	energy -= card.energy_cost
	_add_stats(intellect_gain, card.gloom_delta)
	changed.emit()
	return true


## Resolves today's scheduled events in DESIGN.md order, runs end-of-day
## checks, and advances to the next day. Returns:
## { day, events: Array[EventData], checks: Array[Dictionary],
##   effects: Array[Dictionary], lost, won, loss_reason }
## Each check: { event, stat, required, actual, passed }.
## Each effect: { event, intellect, gloom }.
func end_day() -> Dictionary:
	var events := schedule.events_on(day)
	var result := {
		"day": day, "events": events, "checks": [], "effects": [],
		"lost": false, "won": false, "loss_reason": "",
	}
	if is_over():
		result.lost = is_lost
		result.won = is_won
		result.loss_reason = loss_reason
		return result

	# 1. All stat checks against the stats Kimmy ended the day with.
	for event: EventData in events:
		if not event.is_check():
			continue
		var actual := _stat_value(event.check_stat)
		var passed := actual >= event.check_min
		if passed:
			checks_passed += 1
		result.checks.append({
			"event": event, "stat": event.check_stat,
			"required": event.check_min, "actual": actual, "passed": passed,
		})
		if not passed and not is_lost:
			_lose(LOSS_EVENT % [event.display_name, _stat_name(event.check_stat),
					event.check_min, actual], String(event.id))

	# 2. Side effects and random-event effects (only if the run survived).
	if not is_lost:
		for event: EventData in events:
			if event.intellect_delta == 0 and event.gloom_delta == 0:
				continue
			_add_stats(event.intellect_delta, event.gloom_delta)
			result.effects.append({
				"event": event,
				"intellect": event.intellect_delta, "gloom": event.gloom_delta,
			})

	# 3. End-of-day checks.
	if not is_lost:
		locked = gloom >= config.gloom_lockout_threshold
		if intellect <= config.intellect_loss_threshold:
			_lose(LOSS_INTELLECT % config.intellect_loss_threshold, "intellect")
		elif gloom >= config.gloom_loss_threshold:
			_lose(LOSS_GLOOM % [gloom, config.gloom_loss_threshold], "gloom")

	# 4. Advance.
	study_streak = 0
	if not is_lost:
		if day >= config.num_days:
			is_won = true
		else:
			day += 1
			energy = config.start_energy

	result.lost = is_lost
	result.won = is_won
	result.loss_reason = loss_reason
	changed.emit()
	return result


func _add_stats(intellect_delta: int, gloom_delta: int) -> void:
	intellect = maxi(intellect + intellect_delta, 0)
	gloom = maxi(gloom + gloom_delta, 0)


func _lose(reason: String, cause: String) -> void:
	is_lost = true
	loss_reason = reason
	loss_cause = cause


func _stat_value(stat: EventData.Stat) -> int:
	match stat:
		EventData.Stat.GLOOM:
			return gloom
		_:
			return intellect


func _stat_name(stat: EventData.Stat) -> String:
	match stat:
		EventData.Stat.GLOOM:
			return "gloom"
		_:
			return "intellect"
