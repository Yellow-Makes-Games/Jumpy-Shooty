extends SceneTree
## Movement variants for A/B testing (see MovementTuning.VARIANTS, LobbySettings.movement).
## The checks are in tests/movement_variant_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/movement_variant_test.gd
##
## Variant ids are cleaned (unknown ones are classic) in tuning and in the lobby
## settings; classic is exactly the plain MovementTuning numbers; every player gets their
## own copy; Practice and Vs Bots start with the variant picked, and you and every bot
## move with it; the HUD says so while Variant B is on.

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/movement_variant_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
