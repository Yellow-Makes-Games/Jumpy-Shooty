extends SceneTree
## Kill feed icons and the death screen's "how": every icon for what made a kill (the
## boot, the flying kick, the grapple hook, the wall) draws without errors and is as
## wide as the feed makes room for, and the death screen says how you were got (a kick,
## kicked into a wall, a rocket into a wall). The checks are in tests/kill_feed_runner.gd
## (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/kill_feed_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/kill_feed_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
