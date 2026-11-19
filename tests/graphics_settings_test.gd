extends SceneTree
## Graphics quality (Settings → Graphics → Quality, see GraphicsQuality): the presets
## and Custom, bad saved values, what each pick does to a viewport and to a map's
## Environment, and the Settings tab's Quality and Advanced controls. The checks are in
## tests/graphics_settings_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/graphics_settings_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/graphics_settings_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
