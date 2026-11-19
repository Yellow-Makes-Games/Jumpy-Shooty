extends SceneTree
## Headless checks for seeing through portal gun portals (Portal.update_view,
## Portals.update_views). Run:
##   godot --headless --path . --script tests/portal_view_test.gd
## Nothing is drawn headless, so this checks the maths: looking at a point on one
## portal shows exactly what is straight on through the other (for a wall pair, a
## wall-to-floor pair, and a camera off to one side), the camera behind a portal or
## a portal out of view opens no view, a lone portal (no partner) never does, at most
## Portals.MAX_VIEWS are live, the view is sized to the portal on screen, and the
## portal cameras see the plain faces and your whole body, never a window.


func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/portal_view_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
