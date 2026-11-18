extends SceneTree
## Calling cards and icons: the tables are sound, the plain ones are free and the rest
## are locked behind achievements, the menu's picker takes a free one and refuses a
## locked one (saying what it needs), the lobby carries everyone's card and icon (real
## ones only), and every design draws. The checks are in tests/calling_card_runner.gd
## (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/calling_card_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/calling_card_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
