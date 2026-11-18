extends SceneTree
## HUD icons: the headshot icon draws (at every size it is used) and is as wide as it
## says, and a headshot in the kill feed and on the death screen lays out, with the
## host's word on the killing blow (Match.death_fx) deciding it. The checks are in
## tests/hud_icons_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/hud_icons_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/hud_icons_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
