extends SceneTree
## Shooting through portal gun portals, and portals on moving parts of the map, in a
## real Practice match on the Testing Grounds.
## Run: godot --headless --path . --script tests/portal_shot_test.gd
##
## A bullet into one portal of a pair comes out of the other, turned to match, and hits
## a target dummy there that the gun was pointing away from; its shot effect bends
## through the portals; damage falls off over the whole way. A rocket flies through
## (host and the rocket everyone sees alike) and blows up on the dummy. A lone portal
## lets bullets fly on. A portal put up on a moving part rides it, keeps its spot on
## it, and closes when the part goes; one put up from elsewhere lands on the same spot.


func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/portal_shot_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
