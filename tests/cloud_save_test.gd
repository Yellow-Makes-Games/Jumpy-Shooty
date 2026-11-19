extends SceneTree
## Accounts and cloud saves (no network): two copies of a player's data merge the way
## CloudSave says (counts take the bigger, sets join, best times keep the best, the
## newer profile wins, custom characters join by name), a cloud copy restores into this
## computer's profile and progress without announcing achievements, and the sign-in's
## PKCE challenge and redirect parsing are right. The checks are in
## tests/cloud_save_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/cloud_save_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/cloud_save_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
