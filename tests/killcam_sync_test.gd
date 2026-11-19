extends SceneTree
## Killcams that match the match: the killer's aim and the map's moving parts (see
## KillClip, KillcamView and MapReplay). The checks are in tests/killcam_sync_runner.gd
## (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/killcam_sync_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/killcam_sync_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
