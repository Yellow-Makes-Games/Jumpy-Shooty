extends SceneTree
## Spectating in a real Vs Bots match: you go from player to spectator and back, a
## spectator has no robot and is not counted or scored, and the free camera flies
## through walls. The checks are in tests/spectator_runner.gd (a Node, so it can use
## the autoloads).
## Run: godot --headless --path . --script tests/spectator_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/spectator_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
