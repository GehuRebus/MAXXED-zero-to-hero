class_name EventData
extends Resource
## A scheduled event. STAT_CHECK events end the run if the check fails;
## RANDOM events just apply their stat changes.

enum Kind { STAT_CHECK, RANDOM }
enum Stat { INTELLECT, GLOOM }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: Kind = Kind.RANDOM
## Only used when kind == STAT_CHECK: passes if the stat is >= check_min.
## Checks compare against the stat; they never spend it.
@export var check_stat: Stat = Stat.INTELLECT
@export var check_min: int = 0
## Applied after all checks of the day are made.
@export var intellect_delta: int = 0
@export var gloom_delta: int = 0


func is_check() -> bool:
	return kind == Kind.STAT_CHECK
