extends SceneTree
## Main menu mode switch: on the Practice and Vs Bots pages, pressing "Race" and then
## "Shoot-out" must refill the map list with that mode's maps (and not error).
## Run: godot --headless --path . --script tests/menu_mode_test.gd

var _fails: Array[String] = []


func _initialize() -> void:
	var menu: Node = load("res://game/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	for page in ["_show_practice"]:   # (Vs Bots is the lobby now: see lobby_bots_test)
		menu.call(page)
		await process_frame
		for step in [["Race", "race"], ["Shoot-out", "ffa"], ["Race", "race"]]:
			var button := _find(menu, step[0]) as Button
			if button == null:
				_fails.append("%s: no '%s' button" % [page, step[0]])
				continue
			button.pressed.emit()
			await process_frame
			var maps := _map_ids(menu)
			if maps != Maps.ids_for(step[1]) + [null, Maps.RANDOM]:   # (a separator, then "Random map")
				_fails.append("%s after '%s': map list is %s" % [page, step[0], maps])
	if _fails.is_empty():
		print("PASS menu mode switch refills the map list")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	quit(1 if not _fails.is_empty() else 0)


func _find(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text.begins_with(text) and (n as Button).is_visible_in_tree():
		return n
	for c in n.get_children():
		var r := _find(c, text)
		if r:
			return r
	return null


func _map_ids(n: Node) -> Array:
	if n is OptionButton and (n as OptionButton).is_visible_in_tree() and (n as OptionButton).get_item_metadata(0) is String:
		var pick := n as OptionButton
		return range(pick.item_count).map(func(i): return pick.get_item_metadata(i))
	for c in n.get_children():
		var r := _map_ids(c)
		if not r.is_empty():
			return r
	return []
