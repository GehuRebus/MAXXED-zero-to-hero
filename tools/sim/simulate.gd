extends SceneTree
## Command-line balance report.
##
##   godot --headless -s tools/sim/simulate.gd -- [--runs=N] [--seed=S]
##       [--strategy=good|pattern|always_study|random|all]
##       [--set=KEY=VALUE ...]
##
## KEY is a GameConfig field (start_intellect), or card.<id>.<field> /
## event.<id>.<field> (event.exam.check_min). --set edits a copy of
## GameConfig.tres for this report only; nothing is written to disk.


func _initialize() -> void:
	var runs := 1000
	var base_seed := 1
	var strategies: Array[String] = BalanceSim.STRATEGIES.duplicate()
	var config := (load("res://data/GameConfig.tres") as GameConfig).duplicate_deep(
			Resource.DEEP_DUPLICATE_ALL) as GameConfig
	var overrides: Array[String] = []

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = arg.trim_prefix("--runs=").to_int()
		elif arg.begins_with("--seed="):
			base_seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--strategy="):
			var s := arg.trim_prefix("--strategy=")
			if s != "all":
				strategies = [s]
		elif arg.begins_with("--set="):
			var kv := arg.trim_prefix("--set=")
			if not _apply_override(config, kv):
				printerr("Bad --set: ", kv)
				quit(1)
				return
			overrides.append(kv)

	print("Balance report: %d runs per strategy, seeds %d..%d" % [runs, base_seed, base_seed + runs - 1])
	if not overrides.is_empty():
		print("Overrides: ", ", ".join(overrides))
	print("%-13s %6s  %-44s %7s %7s %7s %6s %6s" % [
		"strategy", "win%", "losses by cause", "lossDay", "finInt", "finGlm", "lockD", "close"])
	for strategy in strategies:
		var start := Time.get_ticks_msec()
		var r := BalanceSim.run_batch(config, strategy, runs, base_seed)
		var causes: Array[String] = []
		var keys: Array = r.loss_causes.keys()
		keys.sort()
		for k: String in keys:
			causes.append("%s %d" % [k, r.loss_causes[k]])
		print("%-13s %5.1f%%  %-44s %7.1f %7.1f %7.1f %6.2f %6.2f   (%d ms)" % [
			strategy, r.win_rate * 100.0, ", ".join(causes) if not causes.is_empty() else "-",
			r.avg_loss_day, r.avg_final_intellect, r.avg_final_gloom,
			r.avg_lockout_days, r.avg_close_calls, Time.get_ticks_msec() - start])
	quit()


static func _apply_override(config: GameConfig, kv: String) -> bool:
	var eq := kv.find("=")
	if eq < 0:
		return false
	var key := kv.substr(0, eq)
	var raw := kv.substr(eq + 1)
	var target: Resource = config
	var field := key
	var parts := key.split(".")
	if parts.size() == 3 and parts[0] == "card":
		target = config.get_card(StringName(parts[1]))
		field = parts[2]
	elif parts.size() == 3 and parts[0] == "event":
		target = config.get_event(StringName(parts[1]))
		field = parts[2]
	if target == null or not field in target:
		return false
	var current: Variant = target.get(field)
	if current is int and raw.is_valid_int():
		target.set(field, raw.to_int())
	elif current is bool:
		target.set(field, raw == "true")
	elif current is Array:
		var arr: Array[int] = []
		for p in raw.split(",", false):
			arr.append(p.to_int())
		target.set(field, arr)
	else:
		return false
	return true
