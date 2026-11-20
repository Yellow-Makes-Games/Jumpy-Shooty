extends SceneTree
## Films a player being hit in the real game, to check the flinch (HitReaction) as players
## see it: a Practice match on the Testing Grounds, the hits made up by a script, each
## with a caption saying what it is. Used by tools/robot/hit_film.sh, which records it.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/hit_film.gd --
##       [--weapon=ID] [--character=ID]
##       [--scenes=all] (a comma list of: small, medium, big, head, melee, rapid (fast hits,
##                       then a crash into the floor), air (a big hit at the top of a
##                       jump); all: every one of them)
##       [--third-person] [--side] (a camera beside the gun arm: the body in profile)
##       [--front] (a camera ahead and to the gun side) [--back] (one behind the gun shoulder)

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
		elif arg == "--front":
			view = "front"
		elif arg == "--back":
			view = "back"
	var runner: Node = load("res://tools/robot/hit_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", scenes, view)
