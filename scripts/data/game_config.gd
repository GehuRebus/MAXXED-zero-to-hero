class_name GameConfig
extends Resource
## Every tunable number in the game. Edit data/GameConfig.tres, not scripts.
## Defaults here are deliberately neutral (0 / empty): the real values live
## only in the .tres file.

@export_group("Run")
@export var num_days: int = 0

@export_group("Starting stats")
@export var start_energy: int = 0
@export var start_intellect: int = 0
@export var start_gloom: int = 0

@export_group("Thresholds")
## End a day at or above this gloom and the next day starts locked.
@export var gloom_lockout_threshold: int = 0
## End a day at or above this gloom and the run is lost.
@export var gloom_loss_threshold: int = 0
## End a day at or below this intellect and the run is lost.
@export var intellect_loss_threshold: int = 0

@export_group("Study streak")
## Intellect multiplier, in percent, for the 1st, 2nd, 3rd... consecutive
## streak card in a day. Streaks longer than the list reuse the last value.
## Applied as (base * percent) / 100 with integer division (rounds down).
@export var study_streak_percent: Array[int] = []

@export_group("Presentation")
## Intellect has no maximum; this is the value that fills the intellect bar.
@export var intellect_display_max: int = 0

@export_group("Content")
@export var cards: Array[CardData] = []
@export var events: Array[EventData] = []


func streak_percent(streak: int) -> int:
	if study_streak_percent.is_empty() or streak <= 0:
		return 100
	return study_streak_percent[mini(streak, study_streak_percent.size()) - 1]


func get_card(card_id: StringName) -> CardData:
	for card: CardData in cards:
		if card.id == card_id:
			return card
	return null


func get_event(event_id: StringName) -> EventData:
	for event: EventData in events:
		if event.id == event_id:
			return event
	return null
