extends SceneTree
## Films a gun being fired in the real game, to check its recoil (GunRecoil) as a player
## sees it: a Practice match on the Testing Grounds, played by a script. Used by
## tools/robot/recoil_film.sh, which records it.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/recoil_film.gd --
##       --weapon=ID [--character=ID]
##       [--scene=shots] (shots: standing: four shots one at a time, then the trigger held
##                        (or pulled as fast as the gun allows) for a second and a half;
##                        air: a jump, fired at the top of it and on the way down;
##                        move: the same shots while strafing)
##       [--third-person] [--side] (a camera beside the gun arm: the body in profile)
##       [--front] (a camera ahead and to the gun side) [--back] (one close behind the gun shoulder)

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var scene := "shots"
	var view := "first"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene = arg.substr(8)
		elif arg == "--third-person":
			view = "third"
		elif arg == "--side":
			view = "side"
		elif arg == "--front":
			view = "front"
		elif arg == "--back":
			view = "back"
	var runner: Node = load("res://tools/robot/recoil_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", scene, view)
