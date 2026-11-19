extends SceneTree
## Movement variants for A/B testing (see MovementTuning.VARIANTS, LobbySettings.movement).
## The checks are in tests/movement_variant_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/movement_variant_test.gd
##
## Variant B is the only movement and the default: ids are cleaned (Classic, retired, and
## unknown ones are B) in tuning and in the lobby settings; every player gets their own
## copy; Practice and Vs Bots start with it, and you and every bot move with it; no
## movement switch is left in the menus and the HUD shows no tag.

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/movement_variant_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
