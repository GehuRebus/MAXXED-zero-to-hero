extends GutTest
## The balance simulator, and a guard that the shipped tuning stays in the
## milestone 6 target band (see docs/BALANCE.md).

const GUARD_RUNS := 300


func test_copy_is_independent() -> void:
	var run := RunState.new(TestFixtures.rules_config(), Schedule.new())
	run.play_card(run.config.get_card(&"study"))
	var c := run.copy()
	assert_eq([c.day, c.energy, c.intellect, c.gloom, c.study_streak],
			[run.day, run.energy, run.intellect, run.gloom, run.study_streak])
	assert_same(c.schedule, run.schedule)
	c.play_card(c.config.get_card(&"game"))
	assert_eq(run.energy, 2, "original untouched")
	assert_eq(run.study_streak, 1)


func test_loss_cause_recorded() -> void:
	var run := RunState.new(TestFixtures.rules_config(), Schedule.new())
	run.gloom = 100
	run.end_day()
	assert_eq(run.loss_cause, "gloom")
	var exam_run := RunState.new(TestFixtures.rules_config(), Schedule.new())
	exam_run.schedule.add(1, exam_run.config.get_event(&"exam"))
	exam_run.end_day()
	assert_eq(exam_run.loss_cause, "exam")


func test_strategies_only_choose_legal_plays() -> void:
	var cfg := TestFixtures.rules_config()
	for strategy in BalanceSim.STRATEGIES:
		for s in range(1, 21):
			var run := RunState.new(cfg, null, s)
			var rng := RandomNumberGenerator.new()
			while not run.is_over():
				for card: CardData in BalanceSim.choose_day(run, strategy, rng):
					if strategy == "pattern" and not run.can_play(card):
						continue  # fixed pattern may ask for a locked card; play_run just skips it
					assert_true(run.play_card(card), "%s seed %d day %d: %s" % [strategy, s, run.day, card.id])
				run.end_day()


func test_runs_are_deterministic() -> void:
	var cfg := TestFixtures.rules_config()
	for strategy in BalanceSim.STRATEGIES:
		assert_eq(BalanceSim.play_run(cfg, strategy, 99), BalanceSim.play_run(cfg, strategy, 99), strategy)


func test_good_player_beats_baselines() -> void:
	var cfg := load("res://data/GameConfig.tres") as GameConfig
	var good := BalanceSim.run_batch(cfg, "good", 150)
	var pattern := BalanceSim.run_batch(cfg, "pattern", 150)
	var random := BalanceSim.run_batch(cfg, "random", 150)
	assert_gt(good.win_rate, pattern.win_rate, "skill should matter")
	assert_gt(pattern.win_rate, random.win_rate)


## Balance guard: fails if a data change moves the shipped tuning out of the
## target band. If that's intentional, update the band and docs/BALANCE.md.
func test_shipped_tuning_in_target_band() -> void:
	var cfg := load("res://data/GameConfig.tres") as GameConfig
	var good := BalanceSim.run_batch(cfg, "good", GUARD_RUNS, 1)
	var careless := BalanceSim.run_batch(cfg, "always_study", GUARD_RUNS, 1)
	assert_between(good.win_rate, 0.60, 0.80,
			"good player win rate %.1f%% (target ~60-75%%)" % (good.win_rate * 100.0))
	assert_lt(careless.win_rate, 0.05, "always-Study should almost never win")
