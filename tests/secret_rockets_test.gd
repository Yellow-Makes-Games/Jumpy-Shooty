extends SceneTree
## The secret code and the Auto Rocket Launcher (see SecretRockets). The checks are in
## tests/secret_rockets_runner.gd (a Node, so it can use the Net autoload).
## Run: godot --headless --path . --script tests/secret_rockets_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/secret_rockets_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
