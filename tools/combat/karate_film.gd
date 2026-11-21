extends SceneTree
## Films Karate in the real game (a Practice match on the Testing Grounds, in front of the
## 5 m target dummy), the button worked by this script: the six-hit combo, a full wind-up
## on the ground, a jump and a full wind-up in the air, then standing a while so the guard
## drops. Used by tools/combat/karate_film.sh, which records it.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/combat/karate_film.gd --
##       --weapon=karate [--character=ID] [--pick=G,A] (which heavy blow on the ground and in the air,
##       see MeleeSwing.pick_of) [--scene=all|combo|heavy|air|slam] [--third-person] [--side] [--front]

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var scene := "all"
	var view := "first"
	var pick := Vector2i(0, 0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene = arg.substr(8)
		elif arg.begins_with("--pick="):
			var p := arg.substr(7).split(",")
			pick = Vector2i(int(p[0]), int(p[1]) if p.size() > 1 else 0)
		elif arg == "--third-person":
			view = "third"
		elif arg in ["--side", "--front", "--back"]:
			view = arg.substr(2)
	var runner: Node = load("res://tools/combat/karate_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", scene, view, pick)
