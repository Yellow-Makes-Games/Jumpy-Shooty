extends SceneTree
## The Multiplayer page: Create lobby and Join lobby, side by side in the middle; Join
## lobby opens a window with the lobby code and Join as Player or Spectator; a bad code
## says so there; leaving the page takes the window with it.
## Run: godot --headless --path . --script tests/multiplayer_page_test.gd

var _fails: Array[String] = []


func _initialize() -> void:
	var menu: Control = load("res://game/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.call("_show_multiplayer")
	await process_frame
	var create := menu.find_child("Create", true, false) as Button
	var join := menu.find_child("Join", true, false) as Button
	_expect(create != null and join != null and create.text.to_lower() == "create lobby" and join.text.to_lower() == "join lobby",
		"two buttons: Create lobby and Join lobby")
	var window := menu.find_child("JoinWindow", true, false) as FloatingPanel
	_expect(window != null and not window.is_open(), "the join window waits, closed")
	join.pressed.emit()
	await process_frame
	_expect(window.is_open(), "Join lobby opens it")
	var player := window.find_child("Player", true, false) as Button
	var watch := window.find_child("Spectator", true, false) as Button
	var code := window.content.get_child(0) as LineEdit
	_expect(code != null and player != null and watch != null, "with the code box, and Join as Player or Spectator")
	code.text = "not a code"
	watch.pressed.emit()
	await process_frame
	var note: Label = menu.get("_join_status")
	_expect(note.visible and note.text != "" and not (root.get_node("Net") as Node).get("is_online"), "a bad code says so in the window, and nothing is joined (%s)" % note.text)
	menu.call("_show_main")
	await process_frame
	await process_frame
	_expect(not is_instance_valid(window) or window.is_queued_for_deletion(), "leaving the page takes the window with it")
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	quit(1 if not _fails.is_empty() else 0)


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
