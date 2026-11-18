extends SceneTree
## HUD options (Settings → HUD, see HudConfig): the defaults are the HUD as it was, they
## survive a save and load, bad saved values fall back to the defaults, and the HUD and
## the Settings preview draw without errors at the extremes (75% and 125%, every
## crosshair style on every weapon's crosshair, everything off). The checks are in
## tests/hud_settings_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/hud_settings_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/hud_settings_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
