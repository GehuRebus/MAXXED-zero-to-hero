class_name CardData
extends Resource
## A playable card. All numbers come from the .tres file, never from code.

## Tag: card can't be played while the gloom lockout is active.
const TAG_BLOCKED_BY_GLOOM: StringName = &"blocked_by_gloom"

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var energy_cost: int = 0
@export var intellect_delta: int = 0
@export var gloom_delta: int = 0
## If true, intellect_delta is scaled by GameConfig.study_streak_percent and
## playing it extends the study streak. Any other card resets the streak.
@export var uses_study_streak: bool = false
@export var tags: Array[StringName] = []


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
