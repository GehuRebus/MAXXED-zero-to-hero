extends GutTest
## Schedule generation rules, checked across many seeds.

const SEEDS := 300

var config: GameConfig


func before_each() -> void:
	config = load("res://data/GameConfig.tres") as GameConfig


func _generate(seed_value: int) -> Schedule:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Schedule.generate(config, rng)


## { event_id: count } over the whole run, plus check days.
func _tally(schedule: Schedule) -> Dictionary:
	var counts := {}
	var check_days: Array[int] = []
	for d in schedule.all_days():
		for event: EventData in schedule.events_on(d):
			counts[event.id] = counts.get(event.id, 0) + 1
			if event.is_check():
				check_days.append(d)
	return {"counts": counts, "check_days": check_days}


func _sum_random(counts: Dictionary) -> int:
	var total := 0
	for event: EventData in config.random_events():
		total += counts.get(event.id, 0)
	return total


func test_config_schedule_values() -> void:
	assert_eq(config.get_event(&"exam").count_per_run, 2)
	assert_eq(config.get_event(&"lab").count_per_run, 3)
	assert_eq(config.random_event_count, 3)
	assert_eq(config.first_check_day, 3)
	assert_eq(config.final_day_event, config.get_event(&"exam"))
	assert_eq(config.schedule_lookahead_days, 3)


func test_counts_match_config() -> void:
	for s in SEEDS:
		var counts: Dictionary = _tally(_generate(s)).counts
		assert_eq(counts.get(&"exam", 0), 2, "seed %d exams" % s)
		assert_eq(counts.get(&"lab", 0), 3, "seed %d labs" % s)
		assert_eq(_sum_random(counts), 3, "seed %d random events" % s)


func test_final_day_is_an_exam() -> void:
	for s in SEEDS:
		var final_checks := _generate(s).visible_on(config.num_days)
		assert_eq(final_checks.size(), 1, "seed %d" % s)
		assert_eq(final_checks[0].id, &"exam", "seed %d" % s)


func test_checks_on_distinct_days_within_window() -> void:
	for s in SEEDS:
		var check_days: Array[int] = _tally(_generate(s)).check_days
		var unique := {}
		for d in check_days:
			unique[d] = true
			assert_between(d, config.first_check_day, config.num_days, "seed %d" % s)
		assert_eq(unique.size(), check_days.size(), "seed %d: one check per day" % s)


func test_all_events_within_run() -> void:
	for s in SEEDS:
		for d in _generate(s).all_days():
			assert_between(d, 1, config.num_days, "seed %d" % s)


func test_random_events_are_hidden() -> void:
	var schedule := Schedule.new()
	schedule.add(5, config.get_event(&"study_group"))
	schedule.add(5, config.get_event(&"lab"))
	assert_eq(schedule.events_on(5).size(), 2)
	assert_eq(schedule.visible_on(5).size(), 1)
	assert_eq(schedule.visible_on(5)[0].id, &"lab")
	assert_eq(schedule.events_on(5)[0].id, &"lab", "checks listed first")


func test_next_check_day() -> void:
	var schedule := Schedule.new()
	schedule.add(4, config.get_event(&"bad_news"))
	schedule.add(6, config.get_event(&"lab"))
	assert_eq(schedule.next_check_day(1, 14), 6)
	assert_eq(schedule.next_check_day(6, 14), 6)
	assert_eq(schedule.next_check_day(7, 14), -1)


func test_same_seed_same_schedule() -> void:
	for s in [1, 42, 9999]:
		var a := _generate(s)
		var b := _generate(s)
		assert_eq(a.all_days(), b.all_days())
		for d in a.all_days():
			assert_eq(a.events_on(d), b.events_on(d), "seed %d day %d" % [s, d])


func test_different_seeds_vary() -> void:
	var layouts := {}
	for s in 50:
		layouts[str(_tally(_generate(s)).check_days)] = true
	assert_gt(layouts.size(), 10, "check placement actually varies")


func test_too_many_checks_are_dropped_not_crashed() -> void:
	var cramped := config.duplicate() as GameConfig
	cramped.first_check_day = 12  # days 12, 13 free + final day
	var schedule := Schedule.generate(cramped, RandomNumberGenerator.new())
	var check_days: Array[int] = _tally(schedule).check_days
	assert_eq(check_days.size(), 3)


func test_run_state_seed_reproduces_schedule() -> void:
	var a := RunState.new(config, null, 1234)
	var b := RunState.new(config, null, 1234)
	assert_eq(a.rng_seed, 1234)
	for d in range(1, config.num_days + 1):
		assert_eq(a.schedule.events_on(d), b.schedule.events_on(d))
	var random_run := RunState.new(config)
	var replay := RunState.new(config, null, random_run.rng_seed)
	for d in range(1, config.num_days + 1):
		assert_eq(random_run.schedule.events_on(d), replay.schedule.events_on(d),
				"a random run can be replayed from its seed")


func test_run_state_resolves_scheduled_events() -> void:
	var schedule := Schedule.new()
	schedule.add(1, config.get_event(&"bad_news"))
	var run := RunState.new(config, schedule)
	var result := run.end_day()
	assert_eq(run.gloom, config.start_gloom + 12)
	assert_eq((result.events as Array).size(), 1)
	run.end_day()  # day 2: nothing scheduled
	assert_eq(run.gloom, config.start_gloom + 12)
