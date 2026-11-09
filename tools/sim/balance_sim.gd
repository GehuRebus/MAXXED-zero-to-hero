class_name BalanceSim
extends RefCounted
## Headless balance simulator: plays many seeded runs through the real
## RunState rules with simple strategies and reports win rates.
## Strategies only use what a player can see: stats, cards, and the
## schedule strip (stat checks within the lookahead window). Hidden random
## events are never peeked at.

const STRATEGIES: Array[String] = ["good", "pattern", "always_study", "random"]


## Plays `runs` runs (seeds base_seed .. base_seed+runs-1) and summarizes.
static func run_batch(config: GameConfig, strategy: String, runs: int, base_seed: int = 1) -> Dictionary:
	var wins := 0
	var causes := {}
	var loss_days := 0
	var final_intellect := 0
	var final_gloom := 0
	var lockout_days := 0
	var close_calls := 0
	for i in runs:
		var r := play_run(config, strategy, base_seed + i)
		final_intellect += r.intellect
		final_gloom += r.gloom
		lockout_days += r.lockout_days
		close_calls += r.close_calls
		if r.won:
			wins += 1
		else:
			causes[r.cause] = causes.get(r.cause, 0) + 1
			loss_days += r.day
	var losses := runs - wins
	return {
		"strategy": strategy, "runs": runs, "wins": wins,
		"win_rate": float(wins) / runs,
		"loss_causes": causes,
		"avg_loss_day": float(loss_days) / losses if losses > 0 else 0.0,
		"avg_final_intellect": float(final_intellect) / runs,
		"avg_final_gloom": float(final_gloom) / runs,
		"avg_lockout_days": float(lockout_days) / runs,
		"avg_close_calls": float(close_calls) / runs,
	}


## One full run. Returns { won, cause, day, intellect, gloom, lockout_days, close_calls }.
## close_calls counts check passes by 5 or less and days ending at 85+ gloom:
## a rough "tension" signal.
static func play_run(config: GameConfig, strategy: String, seed_value: int) -> Dictionary:
	var run := RunState.new(config, null, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var lockout_days := 0
	var close_calls := 0
	while not run.is_over():
		if run.locked:
			lockout_days += 1
		for card: CardData in choose_day(run, strategy, rng):
			if not run.play_card(card):
				break
		var result := run.end_day()
		for check: Dictionary in result.checks:
			if check.passed and int(check.actual) - int(check.required) <= 5:
				close_calls += 1
		if not run.is_over() and run.gloom >= 85:
			close_calls += 1
	return {
		"won": run.is_won, "cause": run.loss_cause, "day": run.day,
		"intellect": run.intellect, "gloom": run.gloom,
		"lockout_days": lockout_days, "close_calls": close_calls,
	}


static func choose_day(run: RunState, strategy: String, rng: RandomNumberGenerator) -> Array[CardData]:
	match strategy:
		"always_study":
			return _always_study(run)
		"pattern":
			return _pattern(run)
		"random":
			return _random(run, rng)
		_:
			return _good(run)


# --- Baselines -------------------------------------------------------------

## Study whenever allowed, Game otherwise. The "careless grinder".
static func _always_study(run: RunState) -> Array[CardData]:
	var study := run.config.get_card(&"study")
	var game := run.config.get_card(&"game")
	var out: Array[CardData] = []
	var sim := run.copy()
	while sim.energy > 0:
		var card := study if sim.can_play(study) else game
		if not sim.play_card(card):
			break
		out.append(card)
	return out


## Fixed Study, Game, Game every day (the "≈ +10 intellect, +3 gloom" line
## from DESIGN.md).
static func _pattern(run: RunState) -> Array[CardData]:
	var study := run.config.get_card(&"study")
	var game := run.config.get_card(&"game")
	var first := study if run.can_play(study) else game
	return [first, game, game]


static func _random(run: RunState, rng: RandomNumberGenerator) -> Array[CardData]:
	var out: Array[CardData] = []
	var sim := run.copy()
	while sim.energy > 0:
		var options: Array[CardData] = []
		for card: CardData in run.config.cards:
			if sim.can_play(card):
				options.append(card)
		if options.is_empty():
			break
		var card := options[rng.randi_range(0, options.size() - 1)]
		sim.play_card(card)
		out.append(card)
	return out


# --- "Good player" ---------------------------------------------------------

## Tries every card sequence for today (including stopping early) and keeps
## the one with the best score from `_evaluate`.
static func _good(run: RunState) -> Array[CardData]:
	var best: Array[CardData] = []
	var best_score := -INF
	for seq: Array[CardData] in _sequences(run.config.cards, run.energy):
		var sim := run.copy()
		var ok := true
		for card: CardData in seq:
			if not sim.play_card(card):
				ok = false
				break
		if not ok:
			continue
		var score := _evaluate(sim)
		if score > best_score:
			best_score = score
			best = seq
	return best


static func _sequences(cards: Array[CardData], length: int) -> Array:
	var out: Array = [[] as Array[CardData]]
	var frontier: Array = [[] as Array[CardData]]
	for i in length:
		var next: Array = []
		for seq: Array[CardData] in frontier:
			for card: CardData in cards:
				var longer: Array[CardData] = seq.duplicate()
				longer.append(card)
				next.append(longer)
		out.append_array(next)
		frontier = next
	return out


## Score of the state after today's plays, judged only on visible info.
## Weights are a plain-language player model:
##  - never fail a visible check or hit a loss threshold
##  - keep a buffer below the gloom limit for unknown bad news
##  - avoid tomorrow's lockout
##  - be on track for the visible upcoming checks
##  - otherwise, more intellect is good and gloom is mildly bad
static func _evaluate(sim: RunState) -> float:
	var cfg := sim.config
	var today := sim.day
	var intellect := sim.intellect
	var gloom := sim.gloom
	for event: EventData in sim.schedule.visible_on(today):
		if intellect < event.check_min:
			return -1e9
	for event: EventData in sim.schedule.visible_on(today):
		intellect = maxi(intellect + event.intellect_delta, 0)
		gloom = maxi(gloom + event.gloom_delta, 0)
	if intellect <= cfg.intellect_loss_threshold or gloom >= cfg.gloom_loss_threshold:
		return -1e9

	var score := 0.0
	var headroom := cfg.gloom_loss_threshold - gloom
	if headroom <= 15:
		score -= 400.0  # one piece of bad news away from losing
	if gloom >= cfg.gloom_lockout_threshold and today < cfg.num_days:
		score -= 40.0  # Study locked tomorrow
	score -= gloom * 0.4

	var last := mini(today + cfg.schedule_lookahead_days, cfg.num_days)
	var planned_intellect := intellect
	for d in range(today + 1, last + 1):
		for event: EventData in sim.schedule.visible_on(d):
			var need := event.check_min - planned_intellect
			if need > 0:
				var days := d - today
				score -= need * 10.0 / days
				if need > days * 33:
					score -= 1000.0  # out of reach even with Study x3 every day
	score += intellect * 1.0
	return score
