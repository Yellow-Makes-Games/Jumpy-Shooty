extends SceneTree
## Films a player arriving (SpawnIn) in the real game, to check it as players see it:
## knocked out and back twice in a Practice match, once standing where they arrive and once
## running off and shooting from the first frame. Used by tools/robot/spawn_film.sh.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/spawn_film.gd --
##       [--weapon=ID] [--character=ID]
##       [--side] (a camera of the film's own, ahead of the body and to its left)

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var view := "first"
	for arg in OS.get_cmdline_user_args():
		if arg == "--side":
			view = "side"
	var runner: Node = load("res://tools/robot/spawn_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", view)
