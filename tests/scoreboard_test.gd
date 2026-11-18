extends SceneTree
## The Tab scoreboard: a SCORE column (each kill's killcam points) in every mode, with
## KILLS beside POINTS in Killcam; online, a PING column (HOST for the host, a dash for
## bots, each client's ping as the host measured it). The checks are in
## tests/scoreboard_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/scoreboard_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/scoreboard_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
