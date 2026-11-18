extends SceneTree
## The host's random map and lobby song: the pool rules, the pick staying in the pool,
## the settings being cleaned, the lobby's controls (Random in the map drop-down, the
## pool's chips, the song drop-down; read-only lines for everyone else), the Vs Bots and
## Practice pages' Random, and the music's switch to a picked song. The checks are in
## tests/host_controls_runner.gd (a Node, so it can use the autoloads). The same in
## real online copies (clients and a late joiner): tests/run_host_controls_test.sh.
## Run: godot --headless --path . --script tests/host_controls_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/host_controls_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
