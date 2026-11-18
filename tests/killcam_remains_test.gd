extends SceneTree
## Remains in killcams (see KillcamView and KillClip.Wreck). The checks are in
## tests/killcam_remains_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --fixed-fps 60 --script tests/killcam_remains_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/killcam_remains_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
