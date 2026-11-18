extends SceneTree
## Lobby settings (the host's allowed weapons): the rules, the host enforcing them for
## itself, remote players and bots, the death-screen pick, and every weapon picker
## (lobby, pause menu Loadout) offering only the allowed weapons. The checks are in
## tests/lobby_settings_runner.gd (a Node, so it can use the Net autoload).
## Run: godot --headless --path . --script tests/lobby_settings_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/lobby_settings_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
