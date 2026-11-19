extends SceneTree
## Achievements: your own kills, deaths, wins and race finishes are counted (a bot's
## are not), an achievement completes at its goal and unlocks its items, the Character
## Creator shows a locked item but won't save it, Randomize keeps to what you have,
## what your saved characters wear stays yours, and the counts survive a restart. The
## checks are in tests/achievements_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/achievements_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/achievements_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
