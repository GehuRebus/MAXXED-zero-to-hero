extends GutTest
## The shipped data files load and hold the DESIGN.md starting values.
## When tuning changes a number on purpose, update the matching assert.

const CONFIG_PATH := "res://data/GameConfig.tres"

var config: GameConfig


func before_each() -> void:
	config = load(CONFIG_PATH) as GameConfig


func test_config_loads() -> void:
	assert_not_null(config, "GameConfig.tres loads as a GameConfig")


func test_config_values() -> void:
	assert_eq(config.num_days, 14)
	assert_eq(config.start_energy, 3)
	assert_eq(config.start_intellect, 20)
	assert_eq(config.start_gloom, 20)
	assert_eq(config.gloom_lockout_threshold, 80)
	assert_eq(config.gloom_loss_threshold, 100)
	assert_eq(config.intellect_loss_threshold, 0)
	assert_eq(config.study_streak_percent, [100, 110, 120] as Array[int])
	assert_gt(config.intellect_display_max, 0)


func test_config_lists_all_content() -> void:
	assert_eq(config.cards.size(), 3)
	assert_eq(config.events.size(), 4)
	for id: StringName in [&"study", &"game", &"party"]:
		assert_not_null(config.get_card(id), "card %s" % id)
	for id: StringName in [&"exam", &"lab", &"study_group", &"bad_news"]:
		assert_not_null(config.get_event(id), "event %s" % id)


func test_cards() -> void:
	var study := config.get_card(&"study")
	assert_eq([study.energy_cost, study.intellect_delta, study.gloom_delta], [1, 10, 15])
	assert_true(study.uses_study_streak)
	assert_true(study.has_tag(CardData.TAG_BLOCKED_BY_GLOOM))

	var game := config.get_card(&"game")
	assert_eq([game.energy_cost, game.intellect_delta, game.gloom_delta], [1, 0, -6])
	assert_false(game.uses_study_streak)
	assert_eq(game.tags.size(), 0)

	var party := config.get_card(&"party")
	assert_eq([party.energy_cost, party.intellect_delta, party.gloom_delta], [1, -7, -11])
	assert_false(party.uses_study_streak)
	assert_eq(party.tags.size(), 0)


func test_events() -> void:
	var exam := config.get_event(&"exam")
	assert_true(exam.is_check())
	assert_eq(exam.check_stat, EventData.Stat.INTELLECT)
	assert_eq([exam.check_min, exam.intellect_delta, exam.gloom_delta], [50, 0, 0])

	var lab := config.get_event(&"lab")
	assert_true(lab.is_check())
	assert_eq(lab.check_stat, EventData.Stat.INTELLECT)
	assert_eq([lab.check_min, lab.intellect_delta, lab.gloom_delta], [35, 0, 10])

	var group := config.get_event(&"study_group")
	assert_false(group.is_check())
	assert_eq([group.intellect_delta, group.gloom_delta], [8, 10])

	var news := config.get_event(&"bad_news")
	assert_false(news.is_check())
	assert_eq([news.intellect_delta, news.gloom_delta], [0, 12])
