extends SceneTree
## Empyrean Tower in a real Practice match: what its new systems do to a real player.
## Run: godot --headless --path . --script tests/empyrean_play_test.gd
##
## Gravity: 1.0 standing inside, 0.4 on the docking ring, and it eases over about a
## second on the way out through a force-field doorway (which does not stop you).
## Hazard: touching the Engine's core is a death (the same as a fall). Burn layer:
## falling below it is a death; flying off sideways or upward is not.
## Lift: a tractor beam carries you up at about 9 m/s and you can shoot on the way.
## Portal Surge: dormant gates do nothing; a 2 s hold at the altar (within 2 m) powers
## up all four pairs; letting go early or leaving the range cancels, taking damage does
## not; it cannot be used again while the surge runs or cools down; a player who walks
## into a gate comes out of the other with their speed carried through, facing out of
## it; a rocket flies straight through an open gate and comes out the back; the portal
## gun's own portals work beside them; the gates close after 30 s and stop teleporting.

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/empyrean_play_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
