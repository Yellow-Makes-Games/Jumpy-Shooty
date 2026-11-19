extends SceneTree
## The portrait banner (the character on its stage in the lobby and the Character
## Creator, and the results screen's killcam): the 3D is drawn at the screen's own size
## and follows the graphics picks;
## the camera keeps every character's head and the ring under it inside the frame, and
## the name ends short of the head; every weapon goes through its three holds and its
## flourish; dragging turns the character and letting go turns it back; another
## character taking the stage builds in.
## The checks are in tests/portrait_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --fixed-fps 60 --script tests/portrait_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/portrait_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
