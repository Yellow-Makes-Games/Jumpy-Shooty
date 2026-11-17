extends SceneTree
## Debug menu cheats and the Testing Grounds target dummies, in a real Practice match.
## Run: godot --headless --path . --script tests/debug_test.gd
##
## Dummies: the map has them; a body shot and a headshot on one are decided like a
## shot on a player (player_hit with the right damage and headshot flag); enough
## damage knocks it down, and it gets back up with full health.
## Cheats: god mode stops damage; infinite ammo keeps the magazine full; bots can be
## added and removed mid-match; the robot and gun can be changed on the spot.
## Melee: a tap is a weak blow; holding the button winds the swing up (and coils the
## body), and letting go of a full wind-up hits much harder.
## Online: every cheat is off and the menu will not open, even for the host.

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/debug_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
