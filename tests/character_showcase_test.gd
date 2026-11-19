extends SceneTree
## The main menu's character showcase: every one of its cast is a real character
## (each creature's id names parts that exist, unchanged by normalize) holding a real
## weapon; the show includes every robot; your own characters join it near the
## start; and it steps through the whole cast and round again without an error.
## The checks are in tests/character_showcase_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/character_showcase_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/character_showcase_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
