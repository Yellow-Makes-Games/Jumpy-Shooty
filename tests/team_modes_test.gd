extends SceneTree
## Team modes: Search and Destroy and Capture the Flag (see Teams). The checks are in
## tests/team_modes_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --fixed-fps 60 --path . --script tests/team_modes_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/team_modes_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
