extends SceneTree
## Ragdolls (see Ragdoll and Remains). The checks are in tests/ragdoll_runner.gd (a
## Node, so it can use the Net, Match and Settings autoloads).
## Run: godot --headless --path . --fixed-fps 60 --script tests/ragdoll_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/ragdoll_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
