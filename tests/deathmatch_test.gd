extends SceneTree
## Deathmatch: the map lists, the weapon pickups on each map, the inventory rules and
## the pause menu's Loadout. The checks are in tests/deathmatch_runner.gd (a Node, so
## it can use the Net and Match autoloads).
## Run: godot --headless --path . --script tests/deathmatch_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/deathmatch_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
