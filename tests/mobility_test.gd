extends SceneTree
## The mobility slot (see Mobility): blink, the portal gun and picking a tool, in a
## real Practice match on the Testing Grounds.
## Run: godot --headless --path . --script tests/mobility_test.gd
##
## Blink: goes where you aim, stops short of a wall, keeps you moving, uses a charge
## and the charges come back. Portal gun: shoots portals onto floors and walls,
## alternating blue and orange; a body walking or falling into one comes out of the
## other moving out of it, and does not bounce straight back; the portals go when
## their owner dies. Picking: the pick is refused while alive and taken while dead,
## the player then has that tool, a race always has the grapple, and bots take one.

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/mobility_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
