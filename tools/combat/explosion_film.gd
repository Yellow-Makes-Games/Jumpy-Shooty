extends SceneTree
## Films the blast of every explosive weapon in a real Practice match, to see them as
## players do. Used by tools/combat/explosion_film.sh.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/combat/explosion_film.gd --
##       [--map=ID] [--only=ground|first|wall]
##
## Three parts: each blast on open ground from a few metres off, the same seen through
## the player's own eyes, and real rockets, grenades and shells flown into a wall that
## breaks (on a map with fine destruction).

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var map := "construction_site"
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7)
	var runner: Node = load("res://tools/combat/explosion_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", map, only)
