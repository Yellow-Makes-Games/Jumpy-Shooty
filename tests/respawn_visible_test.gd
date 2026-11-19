extends SceneTree
## Another player is never left invisible after a respawn, whichever order their
## snapshots and the news of the respawn arrive in. Drives a remote Player in a real
## Practice arena through the arena's own death and respawn handlers:
##  - respawn then snapshot (the usual order): hidden until the snapshot, then shown;
##  - snapshot then respawn (the respawn message held up): shown the moment the respawn
##    arrives, where the new snapshot says, with nothing of the old life to blend from,
##    whether or not the body was hidden for a ragdoll at death;
##  - killed again before any snapshot from the new life: stays down, and the next
##    respawn waits for a snapshot from that next life (the stale one is not enough);
##  - a snapshot that arrives late, out of order, does not undo the respawn;
##  - a new robot or gun (Arena.rebuild_player, a Gun Game swap) while waiting to see
##    them back, and a rebuild while dead with the snapshot first;
##  - a respawn while alive (a new round) with the snapshot first;
##  - the safety net: alive by the host's word, snapshots coming, but none from the new
##    life for over a second: shown anyway (RESPAWN_SHOW_LATE).
## Each ends with the player alive, drawn and on the players' collision layer.
## The checks are in tests/respawn_visible_runner.gd (a Node, so it can use the autoloads).
## Run: godot --headless --path . --script tests/respawn_visible_test.gd

func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var runner: Node = load("res://tests/respawn_visible_runner.gd").new()
	root.add_child(runner)
	runner.call("run")
