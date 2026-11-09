class_name GameSession
extends RefCounted
## The GameConfig used by runs this session. It's a deep copy of
## data/GameConfig.tres, so the debug menu can edit it freely: changes last
## until the game closes and never touch the shipped data files.

const CONFIG_PATH := "res://data/GameConfig.tres"

static var _config: GameConfig


static func config() -> GameConfig:
	if _config == null:
		reset()
	return _config


## Throws away debug edits and starts again from the shipped values.
static func reset() -> void:
	var shipped := load(CONFIG_PATH) as GameConfig
	_config = shipped.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameConfig


## The debug menu only exists in debug builds (editor runs, debug exports).
static func debug_tools_enabled() -> bool:
	return OS.is_debug_build()
