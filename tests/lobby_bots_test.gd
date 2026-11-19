extends SceneTree
## Vs Bots is the lobby, offline: it opens set up as last time (each bot at its own
## difficulty), the host adds bots up to what the mode takes, a click on a bot's
## difficulty changes it, Remove takes it out, Start needs a bot, and what was set up
## is remembered for the rematch. The checks are in tests/lobby_bots_runner.gd.
## Run: godot --headless --path . --script tests/lobby_bots_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/lobby_bots_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
