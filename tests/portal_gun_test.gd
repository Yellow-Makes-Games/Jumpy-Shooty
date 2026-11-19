extends SceneTree
## The portal gun: where its portals go, how they open and close, and what going
## through one is like. In a real Practice match on the Construction Site.
## Run: godot --headless --fixed-fps 60 --path . --script tests/portal_gun_test.gd
##
## Placing (PortalFit): on a flat wall a portal lies on the wall; on a ribbed shipping
## container (ribs and signs are drawn, not solid) it stands on the ribs, with nothing
## through its face or its rim and a collar back to the wall; on a wall with a solid
## beam across it, on the beam. Shot near an edge it moves onto the surface, shot by a
## crate against the wall it moves off the crate, shot at the foot of a wall it stands
## clear of the floor. A post too narrow for one takes none: the shot fizzles.
##
## Opening and closing: a new portal springs open; the one it replaces is nobody's
## portal at once, plays its closing and is gone.
##
## Going through: a fall at 45 m/s into a floor portal comes out of the wall portal as
## fast (no step lost against the floor first); you come out where you went in on the
## other oval, looking the way you would through a doorway (up and down too); running
## from wall to wall you stay on your feet, and can turn round and walk straight back;
## a fall that would just miss a floor portal is drawn onto it; shots through a portal
## make it ripple.


func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/portal_gun_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
