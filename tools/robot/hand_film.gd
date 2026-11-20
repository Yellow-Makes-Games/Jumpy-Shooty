extends SceneTree
## Films the free hand (FreeHand) in the real game, to check it as players see it:
## snatching a weapon and a power-up, throwing the crane's lever, pressing a terminal,
## planting and defusing the bomb, each with a caption. Used by tools/robot/hand_film.sh.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/hand_film.gd --
##       [--weapon=ID] [--character=ID]
##       [--scene=site] (site: a Deathmatch on the Construction Site: a weapon, a second
##                       one, a power-up, the crane's lever; terminal: Halcyon's terminal;
##                       bomb: Search and Destroy: planting, then defusing)
##       [--side] (a camera of the film's own, ahead of the body and to its left)

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var scene := "site"
	var view := "first"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene = arg.substr(8)
		elif arg == "--side":
			view = "side"
	var runner: Node = load("res://tools/robot/hand_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", scene, view)
