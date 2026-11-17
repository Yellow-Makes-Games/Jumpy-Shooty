extends SceneTree
## Menu layout: at every common window size and shape (16:9, 16:10, ultrawide, 4:3,
## small windows), every page of every menu keeps all of its buttons on the screen,
## no robot or weapon button cuts its name short, and the death screen's two columns
## fit side by side. The checks are in tests/ui_layout_runner.gd (a Node, so it can
## use the autoloads).
## Run: godot --headless --path . --script tests/ui_layout_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/ui_layout_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
