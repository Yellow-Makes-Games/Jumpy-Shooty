extends SceneTree
## The lobby's close look at a player: levels sync and show on each row, the hover
## card shows their loadout and cosmetics (the ones you lack in red, with what unlocks
## them), the stage shows their robot while you look, and a click keeps the card open.
## The checks are in tests/lobby_player_card_runner.gd.
## Run: godot --headless --path . --script tests/lobby_player_card_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/lobby_player_card_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
