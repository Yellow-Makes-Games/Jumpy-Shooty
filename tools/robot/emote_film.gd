extends SceneTree
## Films the emote wheel and the emotes (EmoteWheel, Emote) in the real game, to check
## them as players see them: the wheel picked from, a wave, pointing, a laugh, the dance
## cut short by walking off, a tap for the last one again, a shot cutting that short,
## each with a caption. Used by tools/robot/emote_film.sh.
##
##   godot --fixed-fps 60 --write-movie OUT.avi --path . --script tools/robot/emote_film.gd --
##       [--weapon=ID] [--character=ID]
##       [--side] (a camera of the film's own, in front of the body; otherwise your own
##                 view, which starts in first person and pulls back for each emote)

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var view := "first"
	for arg in OS.get_cmdline_user_args():
		if arg == "--side":
			view = "side"
	var runner: Node = load("res://tools/robot/emote_film_runner.gd").new()
	root.add_child(runner)
	runner.call("run", view)
