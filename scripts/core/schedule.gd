class_name Schedule
extends RefCounted
## Which events happen on which day. Generated once per run.
## Stat checks are visible to the player ahead of time; random events are not.

var _days: Dictionary[int, Array] = {}


## Builds a run's schedule from the config, using only `rng` for randomness
## so the same seed always gives the same schedule.
static func generate(config: GameConfig, rng: RandomNumberGenerator) -> Schedule:
	var schedule := Schedule.new()

	# Stat checks: one per day, on distinct days from first_check_day onward.
	var checks: Array[EventData] = []
	for event: EventData in config.check_events():
		for i in event.count_per_run:
			checks.append(event)
	var last_open_day := config.num_days
	if config.final_day_event != null and checks.has(config.final_day_event):
		checks.erase(config.final_day_event)
		schedule.add(config.num_days, config.final_day_event)
		last_open_day -= 1
	var open_days: Array[int] = []
	for d in range(maxi(config.first_check_day, 1), last_open_day + 1):
		open_days.append(d)
	_shuffle(open_days, rng)
	_shuffle(checks, rng)
	if checks.size() > open_days.size():
		push_warning("Schedule: %d checks but only %d free days; dropping extras." % [
				checks.size(), open_days.size()])
	for i in mini(checks.size(), open_days.size()):
		schedule.add(open_days[i], checks[i])

	# Random events: any day, any number per day.
	var pool := config.random_events()
	if not pool.is_empty():
		for i in config.random_event_count:
			var d := rng.randi_range(1, config.num_days)
			schedule.add(d, pool[rng.randi_range(0, pool.size() - 1)])
	return schedule


func add(day: int, event: EventData) -> void:
	if not _days.has(day):
		_days[day] = []
	_days[day].append(event)


## Every event on `day`, checks first.
func events_on(day: int) -> Array[EventData]:
	var out: Array[EventData] = []
	for event: EventData in _days.get(day, []):
		if event.is_check():
			out.append(event)
	for event: EventData in _days.get(day, []):
		if not event.is_check():
			out.append(event)
	return out


## Only what the player is allowed to see ahead of time (stat checks).
func visible_on(day: int) -> Array[EventData]:
	var out: Array[EventData] = []
	for event: EventData in _days.get(day, []):
		if event.is_check():
			out.append(event)
	return out


## First day >= `from_day` with a visible check, or -1.
func next_check_day(from_day: int, last_day: int) -> int:
	for d in range(from_day, last_day + 1):
		if not visible_on(d).is_empty():
			return d
	return -1


func all_days() -> Array[int]:
	var out: Array[int] = []
	out.assign(_days.keys())
	out.sort()
	return out


static func _shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	# Array.shuffle() uses the global RNG; this one respects the run seed.
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = array[i]
		array[i] = array[j]
		array[j] = tmp
