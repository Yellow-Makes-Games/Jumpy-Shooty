extends SceneTree
## Your own colour in a free-for-all: the one you picked is yours when you host or
## play alone, a lobby gives it to you if no other player has it (a bot hands it
## over), and the swatch on the robot stage offers every colour that is free. The
## checks are in tests/player_color_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/player_color_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/player_color_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
