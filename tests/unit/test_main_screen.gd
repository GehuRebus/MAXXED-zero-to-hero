extends GutTest
## Drives the real main scene by "clicking" (emitting pressed) its buttons.

var screen: MainScreen


func before_each() -> void:
	screen = (load("res://scenes/main.tscn") as PackedScene).instantiate() as MainScreen
	add_child_autofree(screen)
	_use_schedule({})


## Replaces the random schedule with a fixed one: { day: [event_id, ...] }.
func _use_schedule(days: Dictionary) -> void:
	var schedule := Schedule.new()
	for d: int in days:
		for id: StringName in days[d]:
			schedule.add(d, screen.config.get_event(id))
	screen.run.schedule = schedule
	screen.refresh()


func _cell_text(index: int) -> String:
	return (screen.schedule_strip.get_child(index).get_child(0) as Label).text


func _button(card_id: StringName) -> CardButton:
	for button: CardButton in screen.card_buttons:
		if button.card.id == card_id:
			return button
	return null


func _lit_pips() -> int:
	var lit := 0
	for pip: Node in screen.energy_pips.get_children():
		if (pip as ColorRect).color == MainScreen.PIP_FULL:
			lit += 1
	return lit


func test_one_button_per_card_in_config() -> void:
	assert_eq(screen.card_buttons.size(), screen.config.cards.size())
	for id: StringName in [&"study", &"game", &"party"]:
		assert_not_null(_button(id), "button for %s" % id)


func test_initial_display() -> void:
	assert_eq(screen.day_label.text, "Day 1 / 14")
	assert_eq(screen.energy_pips.get_child_count(), 3)
	assert_eq(_lit_pips(), 3)
	assert_eq(screen.intellect_bar.value, 20)
	assert_eq(screen.gloom_bar.value, 20)
	assert_eq(screen.gloom_bar.marker, 80, "lockout line marked on gloom bar")
	assert_eq(screen.streak_label.text, "Study streak: 0")
	assert_false(screen.game_over_overlay.visible)
	assert_false(screen.end_day_button.disabled)


func test_card_text_shows_effects() -> void:
	var text := _button(&"study").text
	assert_string_contains(text, "STUDY")
	assert_string_contains(text, "+10 intellect")
	assert_string_contains(text, "+15 gloom")
	assert_string_contains(_button(&"party").text, "-7 intellect")


func test_clicking_card_updates_display() -> void:
	_button(&"study").pressed.emit()
	assert_eq(screen.run.intellect, 30)
	assert_eq(screen.intellect_bar.value, 30)
	assert_eq(screen.gloom_bar.value, 35)
	assert_eq(_lit_pips(), 2)
	assert_eq(screen.streak_label.text.begins_with("Study streak: 1"), true)
	assert_string_contains(_button(&"study").text, "+11 intellect", "shows next streak gain")
	assert_string_contains(screen.log_label.text, "+10 intellect")


func test_out_of_energy_greys_out_cards() -> void:
	for i in 3:
		_button(&"game").pressed.emit()
	assert_eq(_lit_pips(), 0)
	for button: CardButton in screen.card_buttons:
		assert_true(button.disabled, "%s disabled" % button.card.id)
		assert_string_contains(button.text, RunState.REASON_NO_ENERGY)
	_button(&"game").pressed.emit()  # ignored
	assert_eq(screen.run.gloom, 2)


func test_end_day_advances() -> void:
	_button(&"game").pressed.emit()
	screen.end_day_button.pressed.emit()
	assert_eq(screen.day_label.text, "Day 2 / 14")
	assert_eq(_lit_pips(), 3)
	assert_false(_button(&"game").disabled)
	assert_string_contains(screen.log_label.text, "Day 2 begins")


func test_locked_study_is_greyed_with_reason() -> void:
	screen.run.gloom = 90
	screen.end_day_button.pressed.emit()
	assert_true(_button(&"study").disabled)
	assert_string_contains(_button(&"study").text, "gloomy")
	assert_false(_button(&"game").disabled)
	assert_true(screen.lock_label.visible)


func test_full_run_ends_in_win() -> void:
	for i in screen.config.num_days:
		screen.end_day_button.pressed.emit()
	assert_true(screen.run.is_won)
	assert_true(screen.game_over_overlay.visible, "no events on day 14: win screen right away")
	assert_true(screen.game_over_overlay.is_win)
	assert_true(screen.end_day_button.disabled)
	for button: CardButton in screen.card_buttons:
		assert_true(button.disabled)


# --- Milestone 3: game over and restart ---------------------------------------

func test_game_over_hidden_at_start() -> void:
	assert_false(screen.game_over_overlay.visible)


func test_gloom_loss_shows_game_over() -> void:
	screen.run.gloom = 95
	_button(&"study").pressed.emit()  # 110 gloom; still fine mid-day
	assert_false(screen.game_over_overlay.visible, "losses wait for end of day")
	screen.end_day_button.pressed.emit()
	assert_true(screen.game_over_overlay.visible)
	assert_eq(screen.game_over_overlay.title_label.text, "GAME OVER")
	assert_string_contains(screen.game_over_overlay.reason_label.text, "gloom")
	assert_string_contains(screen.game_over_overlay.summary_label.text, "day 1 of 14")
	assert_true(screen.end_day_button.disabled)
	for button: CardButton in screen.card_buttons:
		assert_true(button.disabled)


func test_intellect_loss_shows_game_over() -> void:
	screen.run.intellect = 7
	_button(&"party").pressed.emit()
	screen.end_day_button.pressed.emit()
	assert_true(screen.game_over_overlay.visible)
	assert_string_contains(screen.game_over_overlay.reason_label.text, "intellect")
	assert_string_contains(screen.game_over_overlay.summary_label.text, "Final intellect: 0")


func test_restart_starts_a_fresh_run() -> void:
	_button(&"study").pressed.emit()
	screen.run.gloom = 100
	screen.end_day_button.pressed.emit()
	var old_run := screen.run
	screen.game_over_overlay.restart_button.pressed.emit()
	assert_false(screen.game_over_overlay.visible)
	assert_ne(screen.run, old_run)
	assert_eq(screen.day_label.text, "Day 1 / 14")
	assert_eq(screen.intellect_bar.value, screen.config.start_intellect)
	assert_eq(screen.gloom_bar.value, screen.config.start_gloom)
	assert_eq(_lit_pips(), screen.config.start_energy)
	assert_eq(screen.streak_label.text, "Study streak: 0")
	assert_false(screen.lock_label.visible)
	assert_false(screen.end_day_button.disabled)
	assert_eq(screen.card_buttons.size(), 3)
	assert_eq(screen.card_row.get_child_count(), 3, "old buttons removed")
	_button(&"game").pressed.emit()
	assert_eq(screen.run.gloom, screen.config.start_gloom - 6, "new buttons drive the new run")
	await wait_process_frames(1)  # let the old run's queue_free()d nodes go


# --- Milestone 4: schedule and events -----------------------------------------

func test_strip_shows_today_plus_lookahead() -> void:
	assert_eq(screen.schedule_strip.shown_days, [1, 2, 3, 4] as Array[int])
	screen.run.day = 13
	screen.refresh()
	assert_eq(screen.schedule_strip.shown_days, [13, 14] as Array[int], "stops at the last day")


func test_strip_shows_checks_but_hides_random_events() -> void:
	_use_schedule({2: [&"bad_news"], 3: [&"lab"], 4: [&"exam", &"study_group"]})
	assert_string_contains(_cell_text(0), "Today")
	assert_false(_cell_text(1).contains("Bad News"))
	assert_string_contains(_cell_text(2), "Lab: intellect 35+")
	assert_string_contains(_cell_text(3), "Exam: intellect 50+")
	assert_false(_cell_text(3).contains("Study Group"))


func test_strip_hides_checks_beyond_lookahead() -> void:
	_use_schedule({6: [&"lab"]})
	for i in screen.schedule_strip.get_child_count():
		assert_false(_cell_text(i).contains("Lab"))
	assert_eq(screen.intellect_bar.marker, -1, "no marker for a check out of view")


func test_intellect_bar_marks_next_check() -> void:
	_use_schedule({3: [&"lab"], 4: [&"exam"]})
	assert_eq(screen.intellect_bar.marker, 35)
	assert_string_contains(screen.intellect_bar.marker_label, "Lab day 3")


func test_no_popup_on_uneventful_day() -> void:
	screen.end_day_button.pressed.emit()
	assert_false(screen.event_popup.visible)


func test_passed_check_popup() -> void:
	_use_schedule({1: [&"lab"]})
	screen.run.intellect = 40
	screen.end_day_button.pressed.emit()
	assert_true(screen.event_popup.visible)
	assert_string_contains(screen.event_popup.shown_lines[0], "needs intellect 35, Kimmy has 40: PASS")
	assert_string_contains(screen.event_popup.shown_lines[1], "Lab: +10 gloom")
	screen.event_popup.continue_button.pressed.emit()
	assert_false(screen.event_popup.visible)
	assert_false(screen.game_over_overlay.visible)
	assert_eq(screen.day_label.text, "Day 2 / 14")


func test_failed_check_popup_then_game_over() -> void:
	_use_schedule({1: [&"exam"]})
	screen.end_day_button.pressed.emit()
	assert_true(screen.event_popup.visible)
	assert_string_contains(screen.event_popup.shown_lines[0], "Kimmy has 20: FAIL")
	assert_false(screen.game_over_overlay.visible, "game over waits for the popup")
	screen.event_popup.continue_button.pressed.emit()
	assert_true(screen.game_over_overlay.visible)
	assert_string_contains(screen.game_over_overlay.reason_label.text, "Failed Exam")
	assert_string_contains(screen.game_over_overlay.summary_label.text, "FAIL")


func test_surprise_event_popup() -> void:
	_use_schedule({1: [&"bad_news"]})
	screen.end_day_button.pressed.emit()
	assert_true(screen.event_popup.visible)
	assert_eq(screen.event_popup.shown_lines, ["Surprise! Bad News From Home: +12 gloom"] as Array[String])
	assert_eq(screen.gloom_bar.value, 32)


func test_event_pushing_gloom_over_limit_ends_run_after_popup() -> void:
	_use_schedule({1: [&"bad_news"]})
	screen.run.gloom = 95
	screen.end_day_button.pressed.emit()
	assert_true(screen.event_popup.visible)
	screen.event_popup.continue_button.pressed.emit()
	assert_true(screen.game_over_overlay.visible)
	assert_string_contains(screen.game_over_overlay.reason_label.text, "107 gloom")


func test_restart_rolls_a_new_schedule() -> void:
	screen.run.gloom = 100
	screen.end_day_button.pressed.emit()
	screen.game_over_overlay.restart_button.pressed.emit()
	var checks := 0
	for d in range(1, screen.config.num_days + 1):
		checks += screen.run.schedule.visible_on(d).size()
	assert_eq(checks, 5, "2 exams + 3 labs")
	await wait_process_frames(1)


# --- Milestone 5: win screen, restart, debug seed -------------------------------

## Fresh screen whose config has the given debug seed (set before _ready).
func _screen_with_seed(seed_value: int) -> MainScreen:
	var cfg := (load("res://data/GameConfig.tres") as GameConfig).duplicate() as GameConfig
	cfg.debug_seed = seed_value
	var other := (load("res://scenes/main.tscn") as PackedScene).instantiate() as MainScreen
	other.config = cfg
	add_child_autofree(other)
	return other


func test_win_after_final_exam_popup() -> void:
	_use_schedule({4: [&"lab"], 14: [&"exam"]})
	screen.run.intellect = 60
	for i in screen.config.num_days:
		screen.end_day_button.pressed.emit()
		if screen.event_popup.visible:
			assert_false(screen.game_over_overlay.visible, "end screen waits for the popup")
			screen.event_popup.continue_button.pressed.emit()
	var over := screen.game_over_overlay
	assert_true(screen.run.is_won)
	assert_true(over.visible)
	assert_eq(over.title_label.text, "YOU WIN!")
	assert_string_contains(over.reason_label.text, "all 14 days")
	assert_string_contains(over.summary_label.text, "Exams and labs passed: 2")
	assert_eq(over.restart_button.text, "Play again")
	assert_string_contains(over.seed_label.text, "Seed %d" % screen.run.rng_seed)


func test_play_again_after_win() -> void:
	for i in screen.config.num_days:
		screen.end_day_button.pressed.emit()
	screen.game_over_overlay.restart_button.pressed.emit()
	assert_false(screen.game_over_overlay.visible)
	assert_false(screen.run.is_over())
	assert_eq(screen.day_label.text, "Day 1 / 14")
	assert_false(screen.end_day_button.disabled)
	await wait_process_frames(1)


func test_loss_screen_after_win_screen_is_restyled() -> void:
	for i in screen.config.num_days:
		screen.end_day_button.pressed.emit()
	screen.game_over_overlay.restart_button.pressed.emit()
	_use_schedule({})
	screen.run.gloom = 100
	screen.end_day_button.pressed.emit()
	assert_false(screen.game_over_overlay.is_win)
	assert_eq(screen.game_over_overlay.title_label.text, "GAME OVER")
	assert_eq(screen.game_over_overlay.restart_button.text, "Restart")
	await wait_process_frames(1)


func test_random_seed_by_default() -> void:
	assert_eq(screen.config.debug_seed, -1)
	assert_false(screen.run.seed_was_fixed)


func test_debug_seed_from_config_repeats_schedule_on_restart() -> void:
	var fixed := _screen_with_seed(4242)
	assert_eq(fixed.run.rng_seed, 4242)
	assert_true(fixed.run.seed_was_fixed)
	assert_string_contains(fixed.log_label.text, "fixed seed 4242")
	var first := fixed.run.schedule
	fixed.run.gloom = 100
	fixed.run.schedule = Schedule.new()  # make sure day 1 just loses
	fixed.end_day_button.pressed.emit()
	assert_string_contains(fixed.game_over_overlay.seed_label.text, "Seed 4242 (fixed)")
	fixed.game_over_overlay.restart_button.pressed.emit()
	assert_eq(fixed.run.rng_seed, 4242)
	var reference := RunState.new(fixed.config, null, 4242).schedule
	for d in range(1, fixed.config.num_days + 1):
		assert_eq(fixed.run.schedule.events_on(d), reference.events_on(d), "day %d" % d)
	assert_ne(first, fixed.run.schedule, "restart builds a new (identical) schedule")
	await wait_process_frames(1)


func test_parse_seed_arg() -> void:
	assert_eq(MainScreen.parse_seed_arg(PackedStringArray()), -1)
	assert_eq(MainScreen.parse_seed_arg(PackedStringArray(["--seed=123"])), 123)
	assert_eq(MainScreen.parse_seed_arg(PackedStringArray(["--foo", "--seed=0"])), 0)
	assert_eq(MainScreen.parse_seed_arg(PackedStringArray(["--seed=abc"])), -1)
	assert_eq(MainScreen.parse_seed_arg(PackedStringArray(["--seed=-5"])), -1)
