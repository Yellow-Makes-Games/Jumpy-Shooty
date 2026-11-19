extends SceneTree
## Films the grappling hook in the real game, to check how the body hangs on its rope
## (RopeSwing) as a player sees it: a Practice match on the Testing Grounds' grapple
## lane, played by a script. Used by tools/robot/rope_film.sh, which records it.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/rope_film.gd --
##       [--scene=swing] (swing: beam to beam, shooting on the way, letting go on the way up;
##                        pump: hanging under a beam, working the swing; player: hooking a player)
##       [--third-person]

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var scene := "swing"
	var third := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene = arg.substr(8)
		elif arg == "--third-person":
			third = true
	var runner: Node = load("res://tools/robot/rope_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", scene, third)
