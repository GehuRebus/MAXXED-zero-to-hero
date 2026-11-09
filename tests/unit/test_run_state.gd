extends GutTest
## Rules from DESIGN.md, tested against the real GameConfig.tres so the
## tests follow the data. Stats are set directly where a scenario needs it.

var config: GameConfig
var run: RunState
var study: CardData
var game: CardData
var party: CardData


func before_each() -> void:
	config = load("res://data/GameConfig.tres") as GameConfig
	run = RunState.new(config)
	study = config.get_card(&"study")
	game = config.get_card(&"game")
	party = config.get_card(&"party")


func _events(ids: Array[StringName]) -> Array[EventData]:
	var out: Array[EventData] = []
	for id: StringName in ids:
		out.append(config.get_event(id))
	return out


# --- Start of run ---------------------------------------------------------

func test_starting_stats() -> void:
	assert_eq(run.day, 1)
	assert_eq(run.energy, config.start_energy)
	assert_eq(run.intellect, config.start_intellect)
	assert_eq(run.gloom, config.start_gloom)
	assert_eq(run.study_streak, 0)
	assert_false(run.locked)
	assert_false(run.is_over())


# --- Cards ----------------------------------------------------------------

func test_study_effect() -> void:
	assert_true(run.play_card(study))
	assert_eq(run.intellect, 30)
	assert_eq(run.gloom, 35)
	assert_eq(run.energy, 2)


func test_game_effect() -> void:
	assert_true(run.play_card(game))
	assert_eq(run.intellect, 20)
	assert_eq(run.gloom, 14)
	assert_eq(run.energy, 2)


func test_party_effect() -> void:
	assert_true(run.play_card(party))
	assert_eq(run.intellect, 13)
	assert_eq(run.gloom, 9)
	assert_eq(run.energy, 2)


func test_same_card_can_be_played_repeatedly_until_out_of_energy() -> void:
	for i in 3:
		assert_true(run.play_card(game), "play %d" % (i + 1))
	assert_eq(run.energy, 0)
	for card: CardData in [study, game, party]:
		assert_false(run.can_play(card))
		assert_eq(run.block_reason(card), RunState.REASON_NO_ENERGY)
		assert_false(run.play_card(card))
	assert_eq(run.gloom, 2, "blocked plays change nothing")


func test_stats_clamp_at_zero() -> void:
	run.gloom = 3
	run.intellect = 5
	run.play_card(party)
	assert_eq(run.intellect, 0)
	assert_eq(run.gloom, 0)


func test_energy_refills_each_day() -> void:
	run.play_card(game)
	run.play_card(game)
	run.end_day()
	assert_eq(run.day, 2)
	assert_eq(run.energy, config.start_energy)


func test_changed_signal() -> void:
	watch_signals(run)
	run.play_card(game)
	assert_signal_emit_count(run, "changed", 1)
	run.end_day()
	assert_signal_emit_count(run, "changed", 2)


# --- Study streak ---------------------------------------------------------

func test_streak_multiplies_intellect_not_gloom() -> void:
	run.gloom = 0
	var gains: Array[int] = []
	for i in 3:
		var before := run.intellect
		run.play_card(study)
		gains.append(run.intellect - before)
	assert_eq(gains, [10, 11, 12] as Array[int])
	assert_eq(run.gloom, 45, "gloom is +15 each time, never multiplied")
	assert_eq(run.study_streak, 3)


func test_other_card_resets_streak() -> void:
	run.play_card(study)
	run.play_card(game)
	assert_eq(run.study_streak, 0)
	var before := run.intellect
	run.play_card(study)
	assert_eq(run.intellect - before, 10)


func test_end_day_resets_streak() -> void:
	run.play_card(study)
	run.play_card(study)
	run.end_day()
	assert_eq(run.study_streak, 0)
	assert_eq(run.preview_intellect_delta(study), 10)


func test_streak_beyond_list_reuses_last_multiplier() -> void:
	run.energy = 5
	run.gloom = 0
	for i in 4:
		run.play_card(study)
	var before := run.intellect
	run.play_card(study)
	assert_eq(run.intellect - before, 12)


func test_multiplier_rounds_down() -> void:
	var odd := study.duplicate() as CardData
	odd.intellect_delta = 7
	run.play_card(odd)
	var before := run.intellect
	run.play_card(odd)
	assert_eq(run.intellect - before, 7, "7 x 1.1 = 7.7 rounds down to 7")


func test_preview_matches_play() -> void:
	run.play_card(study)
	var preview := run.preview_intellect_delta(study)
	var before := run.intellect
	run.play_card(study)
	assert_eq(run.intellect - before, preview)
	assert_eq(run.preview_intellect_delta(party), -7)


# --- Gloom lockout ----------------------------------------------------------

func test_lockout_design_example() -> void:
	# Ends day 10 at 90 gloom: Study fine on day 10, blocked on day 11.
	run.day = 10
	run.gloom = 90
	assert_true(run.can_play(study), "still playable during day 10")
	run.end_day()
	assert_eq(run.day, 11)
	assert_true(run.locked)
	assert_false(run.can_play(study))
	assert_string_contains(run.block_reason(study), "gloom")
	assert_false(run.play_card(study))
	assert_true(run.can_play(game), "Game is never locked")
	assert_true(run.can_play(party), "Party is never locked")


func test_lockout_starts_at_threshold() -> void:
	run.gloom = 79
	run.end_day()
	assert_false(run.locked)
	run.gloom = 80
	run.end_day()
	assert_true(run.locked)


func test_lockout_lifts_when_gloom_drops() -> void:
	run.gloom = 85
	run.end_day()
	assert_true(run.locked)
	run.play_card(party)  # 85 - 11 = 74
	assert_true(run.locked, "lock holds for the whole day")
	run.end_day()
	assert_false(run.locked)
	assert_true(run.can_play(study))


func test_lockout_uses_gloom_after_events() -> void:
	run.gloom = 70
	run.end_day(_events([&"bad_news"]))  # 70 + 12 = 82
	assert_true(run.locked)


# --- Events ---------------------------------------------------------------

func test_exam_pass_and_result_shape() -> void:
	run.intellect = 50
	var result := run.end_day(_events([&"exam"]))
	assert_false(run.is_lost)
	assert_eq(result.checks.size(), 1)
	var check: Dictionary = result.checks[0]
	assert_eq(check.required, 50)
	assert_eq(check.actual, 50)
	assert_true(check.passed)


func test_exam_fail_loses_run() -> void:
	run.intellect = 49
	var result := run.end_day(_events([&"exam"]))
	assert_true(run.is_lost)
	assert_true(result.lost)
	assert_false(result.checks[0].passed)
	assert_string_contains(run.loss_reason, "Exam")
	assert_eq(run.day, 1, "a lost run doesn't advance")


func test_checks_do_not_spend_stats() -> void:
	run.intellect = 60
	run.end_day(_events([&"exam"]))
	assert_eq(run.intellect, 60)


func test_lab_side_effect_applies_after_check() -> void:
	run.intellect = 35
	run.gloom = 20
	run.end_day(_events([&"lab"]))
	assert_false(run.is_lost)
	assert_eq(run.gloom, 30)


func test_all_checks_use_end_of_day_stats_before_any_effect() -> void:
	# Study Group's +8 intellect must not rescue a 45-intellect exam.
	run.intellect = 45
	run.end_day(_events([&"study_group", &"exam"]))
	assert_true(run.is_lost)
	assert_eq(run.intellect, 45, "no effects after a failed check")


func test_multiple_events_in_one_day() -> void:
	run.intellect = 55
	run.gloom = 20
	var result := run.end_day(_events([&"exam", &"lab", &"study_group", &"bad_news"]))
	assert_false(run.is_lost)
	assert_eq(result.checks.size(), 2)
	assert_eq(run.intellect, 63)
	assert_eq(run.gloom, 52)  # 20 + 10 + 10 + 12
	assert_eq(result.effects.size(), 3)


func test_random_events_apply() -> void:
	run.end_day(_events([&"study_group"]))
	assert_eq([run.intellect, run.gloom], [28, 30])
	run.end_day(_events([&"bad_news"]))
	assert_eq([run.intellect, run.gloom], [28, 42])


# --- Losses ---------------------------------------------------------------

func test_zero_intellect_loses() -> void:
	run.intellect = 7
	run.play_card(party)
	assert_eq(run.intellect, 0)
	assert_false(run.is_lost, "loss is checked at end of day, not mid-day")
	run.end_day()
	assert_true(run.is_lost)
	assert_string_contains(run.loss_reason, "intellect")


func test_hundred_gloom_loses() -> void:
	run.gloom = 99
	run.end_day()
	assert_false(run.is_lost)
	run.gloom = 100
	run.end_day()
	assert_true(run.is_lost)
	assert_string_contains(run.loss_reason, "gloom")


func test_event_gloom_can_cause_loss() -> void:
	run.gloom = 90
	run.end_day(_events([&"bad_news"]))
	assert_true(run.is_lost)


func test_nothing_playable_after_loss() -> void:
	run.gloom = 100
	run.end_day()
	assert_false(run.can_play(game))
	assert_eq(run.block_reason(game), RunState.REASON_RUN_OVER)
	var day_before := run.day
	run.end_day()
	assert_eq(run.day, day_before)


# --- Win ------------------------------------------------------------------

func test_surviving_last_day_wins() -> void:
	for i in config.num_days - 1:
		run.end_day()
		assert_false(run.is_won)
	assert_eq(run.day, config.num_days)
	var result := run.end_day()
	assert_true(run.is_won)
	assert_true(result.won)
	assert_false(run.is_lost)
	assert_eq(run.day, config.num_days, "day counter stops at the last day")
	assert_false(run.can_play(game))


func test_losing_on_last_day_is_not_a_win() -> void:
	run.day = config.num_days
	run.gloom = 100
	run.end_day()
	assert_true(run.is_lost)
	assert_false(run.is_won)
