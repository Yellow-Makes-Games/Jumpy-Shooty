extends SceneTree
## Killcams: the kill scores and the best-kill pick, the numbers that travel with a
## death, recording and blending a player's frames, playing a clip back from the
## killer's eyes, and the results page with the best kills on it. The checks are in
## tests/killcam_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/killcam_test.gd
## (tests/run_killcam_test.sh plays real matches, offline and online.)

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/killcam_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
