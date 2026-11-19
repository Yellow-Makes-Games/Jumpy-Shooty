extends SceneTree
## Grappling Hook 2 (see HookShot, HookLine, HookRope), in a real Practice match on
## the Testing Grounds.
## Run: godot --headless --fixed-fps 60 --path . --script tests/hook_shot_test.gd
##
## The hook is a projectile: nothing pulls when it is fired; it takes the distance at
## its speed to arrive; it bites with slack in the rope, which the winch takes in;
## then the rope pulls tight and yanks like the first grappling hook. A miss and a
## hook called back in flight catch nothing. The rope drawn is longer than the straight
## line while there is slack, and straight once tight.
##
## Let go, the hook comes back to the wrist, and while the button is held it catches
## the first surface in its way (after a miss, or pressed again as it comes back; not
## after a jump off the rope). In first person the rope starts on the arm as drawn.
##
## The rope lines up for everyone: the shot is rebuilt from the snapshots a player
## sends (any one of them, with packets lost and all of them late) and must put the
## hook, the slack and the rope where the player's own game had them at every moment;
## the killcam's frame of it draws the same rope again.

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/hook_shot_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
