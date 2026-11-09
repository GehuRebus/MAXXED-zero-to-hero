extends GutTest
## Drives the real main scene by "clicking" (emitting pressed) its buttons.

var screen: MainScreen


func before_each() -> void:
	screen = (load("res://scenes/main.tscn") as PackedScene).instantiate() as MainScreen
	add_child_autofree(screen)


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
	assert_false(screen.status_label.visible)
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
	assert_true(screen.status_label.visible)
	assert_string_contains(screen.status_label.text, "WIN")
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
