extends SceneTree
## The zoom (a pseudo aim down sights): middle mouse by default; it lowers the field of
## view by CameraRig.ZOOM_FOV from whatever yours is (easing there and back), turns the
## view slower by as much, toggles or is held as the setting says, drops when you die,
## and the setting is saved. The checks are in tests/zoom_runner.gd.
## Run: godot --headless --path . --script tests/zoom_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/zoom_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
