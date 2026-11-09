class_name TestFixtures
extends RefCounted
## A GameConfig with every tuning number pinned to DESIGN.md's original
## values, so rule tests keep passing when data/GameConfig.tres is retuned.
## (tests/unit/test_data.gd is the one place that checks the shipped values.)


static func rules_config() -> GameConfig:
	var cfg := (load("res://data/GameConfig.tres") as GameConfig).duplicate_deep(
			Resource.DEEP_DUPLICATE_ALL) as GameConfig
	cfg.num_days = 14
	cfg.start_energy = 3
	cfg.start_intellect = 20
	cfg.start_gloom = 20
	cfg.gloom_lockout_threshold = 80
	cfg.gloom_loss_threshold = 100
	cfg.intellect_loss_threshold = 0
	cfg.study_streak_percent = [100, 110, 120] as Array[int]
	cfg.first_check_day = 3
	cfg.random_event_count = 3
	cfg.schedule_lookahead_days = 3
	cfg.intellect_display_max = 100
	cfg.debug_seed = -1

	_card(cfg, &"study", 1, 10, 15)
	_card(cfg, &"game", 1, 0, -6)
	_card(cfg, &"party", 1, -7, -11)
	_event(cfg, &"exam", 2, 50, 0, 0)
	_event(cfg, &"lab", 3, 35, 0, 10)
	_event(cfg, &"study_group", 0, 0, 8, 10)
	_event(cfg, &"bad_news", 0, 0, 0, 12)
	cfg.final_day_event = cfg.get_event(&"exam")
	return cfg


static func _card(cfg: GameConfig, id: StringName, cost: int, intellect: int, gloom: int) -> void:
	var card := cfg.get_card(id)
	card.energy_cost = cost
	card.intellect_delta = intellect
	card.gloom_delta = gloom


static func _event(cfg: GameConfig, id: StringName, count: int, check_min: int, intellect: int, gloom: int) -> void:
	var event := cfg.get_event(id)
	event.count_per_run = count
	event.check_min = check_min
	event.intellect_delta = intellect
	event.gloom_delta = gloom
