extends GutTest
## Start menu, settings, the debug config menu, and the session config.

var menu: StartMenu


func before_each() -> void:
	GameSession.reset()
	menu = (load("res://scenes/start_menu.tscn") as PackedScene).instantiate() as StartMenu
	menu.navigate = false
	add_child_autofree(menu)


func after_each() -> void:
	GameSession.reset()  # don't leak debug edits into other tests


func _debug() -> DebugMenu:
	menu.settings_button.pressed.emit()
	menu.debug_button.pressed.emit()
	return menu.debug_menu


func _spin(key: String) -> SpinBox:
	return menu.debug_menu.fields[key] as SpinBox


func _game_screen() -> MainScreen:
	var screen := (load("res://scenes/main.tscn") as PackedScene).instantiate() as MainScreen
	screen.navigate = false
	add_child_autofree(screen)
	return screen


# --- GameSession -------------------------------------------------------------

func test_session_config_is_a_copy_of_shipped_data() -> void:
	var session := GameSession.config()
	var shipped := load(GameSession.CONFIG_PATH) as GameConfig
	assert_ne(session, shipped)
	assert_eq(session.start_energy, shipped.start_energy)
	assert_same(GameSession.config(), session, "one config per session")
	session.get_card(&"study").gloom_delta = 1
	session.study_streak_percent[0] = 1
	assert_eq(shipped.get_card(&"study").gloom_delta, 15, "shipped card untouched")
	assert_eq(shipped.study_streak_percent[0], 100, "shipped array untouched")
	assert_same(session.final_day_event, session.get_event(&"exam"), "references stay inside the copy")


func test_session_reset() -> void:
	GameSession.config().start_energy = 9
	GameSession.reset()
	assert_eq(GameSession.config().start_energy, 3)


# --- Start menu ----------------------------------------------------------------

func test_start_menu_buttons() -> void:
	assert_true(menu.main_panel.visible)
	assert_false(menu.settings_panel.visible)
	assert_eq(menu.play_button.text, "Play")
	assert_eq(menu.settings_button.text, "Settings")
	assert_eq(menu.quit_button.text, "Quit")


func test_settings_and_back() -> void:
	menu.settings_button.pressed.emit()
	assert_false(menu.main_panel.visible)
	assert_true(menu.settings_panel.visible)
	menu.back_button.pressed.emit()
	assert_true(menu.main_panel.visible)
	assert_false(menu.settings_panel.visible)


func test_debug_button_only_in_debug_builds() -> void:
	assert_eq(menu.debug_button.visible, OS.is_debug_build())
	assert_eq(menu.no_settings_label.visible, not OS.is_debug_build())


func test_debug_menu_opens_and_closes() -> void:
	var debug := _debug()
	assert_true(debug.visible)
	debug.close_button.pressed.emit()
	assert_false(debug.visible)
	assert_true(menu.settings_panel.visible, "back on the settings screen")


# --- Debug menu fields --------------------------------------------------------

func test_debug_menu_lists_tuning_fields() -> void:
	var fields := _debug().fields
	for key in [
		"config/num_days", "config/start_energy", "config/start_intellect",
		"config/start_gloom", "config/gloom_lockout_threshold", "config/gloom_loss_threshold",
		"config/intellect_loss_threshold", "config/study_streak_percent",
		"config/first_check_day", "config/final_day_event", "config/random_event_count",
		"config/schedule_lookahead_days", "config/debug_seed",
		"card/study/energy_cost", "card/study/intellect_delta", "card/study/gloom_delta",
		"card/study/uses_study_streak", "card/game/gloom_delta", "card/party/intellect_delta",
		"event/exam/check_min", "event/exam/count_per_run", "event/lab/gloom_delta",
		"event/study_group/intellect_delta", "event/bad_news/gloom_delta",
	]:
		assert_has(fields, key)
	for key in ["event/exam/kind", "event/exam/check_stat", "card/study/id",
			"card/study/display_name", "card/study/color", "config/cards"]:
		assert_does_not_have(fields, key, "%s is not a tuning number" % key)


func test_spinbox_edits_session_config() -> void:
	_debug()
	_spin("config/start_energy").value = 5
	_spin("card/study/gloom_delta").value = 4
	_spin("event/exam/check_min").value = 42
	var config := GameSession.config()
	assert_eq(config.start_energy, 5)
	assert_eq(config.get_card(&"study").gloom_delta, 4)
	assert_eq(config.get_event(&"exam").check_min, 42)


func test_bool_edit() -> void:
	var check := _debug().fields["card/study/uses_study_streak"] as CheckBox
	assert_true(check.button_pressed)
	check.button_pressed = false
	assert_false(GameSession.config().get_card(&"study").uses_study_streak)


func test_int_array_edit() -> void:
	var edit := _debug().fields["config/study_streak_percent"] as LineEdit
	assert_eq(edit.text, "100, 110, 120")
	edit.text_changed.emit("100, 150, 200, 250")
	assert_eq(GameSession.config().study_streak_percent, [100, 150, 200, 250] as Array[int])
	edit.text_changed.emit("100, oops")
	assert_eq(GameSession.config().study_streak_percent, [100, 150, 200, 250] as Array[int],
			"invalid text is ignored")
	assert_true(edit.has_theme_color_override("font_color"), "invalid text is highlighted")


func test_final_day_event_edit() -> void:
	var option := _debug().fields["config/final_day_event"] as OptionButton
	assert_eq(option.get_item_text(option.selected), "Exam")
	option.item_selected.emit(0)
	assert_null(GameSession.config().final_day_event)


func test_reset_button_restores_defaults_and_fields() -> void:
	var debug := _debug()
	_spin("config/start_energy").value = 7
	debug.reset_button.pressed.emit()
	assert_eq(GameSession.config().start_energy, 3)
	assert_eq(_spin("config/start_energy").value, 3.0, "fields rebuilt from the fresh config")


# --- Edits reach the next run ----------------------------------------------------

func test_next_run_uses_debug_edits() -> void:
	_debug()
	_spin("config/start_energy").value = 5
	_spin("config/start_intellect").value = 44
	_spin("card/game/gloom_delta").value = -20
	var screen := _game_screen()
	assert_eq(screen.run.energy, 5)
	assert_eq(screen.energy_pips.get_child_count(), 5)
	assert_eq(screen.intellect_bar.value, 44)
	for button: CardButton in screen.card_buttons:
		if button.card.id == &"game":
			assert_string_contains(button.text, "-20 gloom")


func test_fixed_seed_from_debug_menu() -> void:
	_debug()
	_spin("config/debug_seed").value = 77
	var screen := _game_screen()
	assert_eq(screen.run.rng_seed, 77)
	assert_true(screen.run.seed_was_fixed)


# --- Game screen menu buttons ---------------------------------------------------

func test_game_has_menu_buttons() -> void:
	var screen := _game_screen()
	assert_eq(screen.menu_button.text, "Menu")
	watch_signals(screen.game_over_overlay)
	screen.game_over_overlay.menu_button.pressed.emit()
	assert_signal_emitted(screen.game_over_overlay, "menu_requested")
