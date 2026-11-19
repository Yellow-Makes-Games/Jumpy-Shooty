extends SceneTree
## Films the bullet glide in the real game, to check how it looks and moves as a player
## sees it: a Practice match on the Testing Grounds, played by a script. Used by
## tools/robot/glide_film.sh, which records it.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/glide_film.gd --
##       [--scene=glide] (glide: off a high ledge, glide at the top of the jump, turn and
##                        shoot to the side and behind while it flies on, hold it into the
##                        weakened dive, let go: the backflip out of it;
##                        release: a short glide let go early, for a closer look at the backflip)
##       [--third-person] [--side] (a camera off to the side, following the flight: the body in profile)

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var scene := "glide"
	var third := false
	var side := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene = arg.substr(8)
		elif arg == "--third-person":
			third = true
		elif arg == "--side":
			side = true
	var runner: Node = load("res://tools/robot/glide_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", scene, third, side)
