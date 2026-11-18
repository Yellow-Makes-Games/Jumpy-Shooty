extends SceneTree
## What a bot match on a map costs the CPU: the average time of a frame's scripts and of
## its physics steps (where the bots think), and the worst frame, over half a minute.
##
##   godot --headless --path . --script tools/perf/bot_load.gd -- --perf-map=empyrean [--perf-bots=4] [--perf-seconds=30]
##
## Compare with another map (cirrus, halcyon): a map where the bots cost many times
## more has something they keep searching for. --perf-bots=0 plays alone (Practice).
func _init() -> void:
	_start.call_deferred()

func _start() -> void:
	var runner: Node = load("res://tools/perf/bot_load_runner.gd").new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-map="):
			runner.map_id = a.trim_prefix("--perf-map=")
		if a.begins_with("--perf-bots="):
			runner.bots = int(a.trim_prefix("--perf-bots="))
		if a.begins_with("--perf-seconds="):
			runner.seconds = int(a.trim_prefix("--perf-seconds="))
	root.add_child(runner)
	runner.call("run")
