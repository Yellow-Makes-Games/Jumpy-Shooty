extends SceneTree
## The sky engine (SkyPreset, SkyRig, game/maps/sky/): every map has a sky preset, the
## rig builds both skies and the lighting from it, the still sky never uses TIME or
## POSITION (either would recapture the map's lighting every frame), the moving sky
## follows the Sun, events blend skies, and the Moving sky setting switches the
## backdrop. The checks are in tests/sky_engine_runner.gd (a Node, for the autoloads).
## Run: godot --headless --path . --script tests/sky_engine_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/sky_engine_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
