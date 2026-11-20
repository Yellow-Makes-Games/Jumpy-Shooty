extends SceneTree
## The death screen's Respawn and Loadout buttons (in place of the old pick-a-weapon
## grids): in a match where you press to come back, both show once the killcam is over;
## Respawn counts down and can't be pressed until you may, then brings you back like jump
## or fire; Loadout opens the pause menu on its loadout page (and the buttons step
## aside while it is open). In Practice, where you come back on your own, only Loadout.
## The checks are in tests/death_buttons_runner.gd.
## Run: godot --headless --path . --script tests/death_buttons_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/death_buttons_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
