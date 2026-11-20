extends SceneTree
## Films weapons being taken out and put away in the real game (WeaponDraw,
## StowedWeapon), played by a script on the Testing Grounds. Used by
## tools/robot/swap_film.sh, which records it.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/swap_film.gd --
##       --gun=ID [--other=ID] [--character=ID]
##       [--scene=swap] (swap: a Deathmatch: ID is picked up (it comes out), OTHER is picked
##                        up (it rides on the body), then OTHER, ID, and OTHER again with a
##                        shot fired a moment into the draw (it cuts the draw short);
##                       hand: Gun Game's hand-over: OTHER breaks up into light and ID
##                        comes out, twice)
##       [--third-person] [--side] [--front] [--back] (cameras as in recoil_film.gd)

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var scene := "swap"
	var view := "first"
	var gun := "pistol"
	var other := "rifle"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene = arg.substr(8)
		elif arg.begins_with("--gun="):
			gun = arg.substr(6)
		elif arg.begins_with("--other="):
			other = arg.substr(8)
		elif arg == "--third-person":
			view = "third"
		elif arg in ["--side", "--front", "--back"]:
			view = arg.substr(2)
	var runner: Node = load("res://tools/robot/swap_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", scene, view, gun, other)
