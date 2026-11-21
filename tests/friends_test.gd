extends SceneTree
## Friends (no network: the server is a stand-in): statuses and usernames, the
## server's state read safely (friends sorted, offline after a while, bad invites
## dropped), each action sends the right function and arguments, errors come back as
## the server's own words, a new invite is announced once, signing out forgets it all,
## and the Friends panels (Profile, the lobby's invite window) and the main menu's
## invite note show it. The checks are in tests/friends_runner.gd (a Node, so it can
## use the autoloads).
## Run: godot --headless --path . --script tests/friends_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/friends_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
