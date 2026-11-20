extends SceneTree
## Films reloads off the ground in the real game, to check them as players see them (the
## body joining in in the air, OneHandReload on the rope and a wall run, a reload going
## on through a flip): a Practice match on the Testing Grounds, played by a script, with
## a caption for each. Used by tools/robot/reload_film.sh, which records it.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/reload_film.gd --
##       --weapon=ID [--character=ID]
##       [--scenes=all] (a comma list of: rope, jump, glide, flip, wall; all: every one)
##       [--third-person] [--side] (a camera of the film's own, ahead of the body and to its gun side)

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var scenes := ["all"]
	var view := "first"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenes="):
			scenes = Array(arg.substr(9).split(","))
		elif arg == "--third-person":
			view = "third"
		elif arg == "--side":
			view = "side"
	var runner: Node = load("res://tools/robot/reload_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", scenes, view)
