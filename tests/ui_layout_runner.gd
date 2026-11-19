extends Node
## Menu layout: at every common window size and shape, every page of every menu
## must keep all of its buttons, text boxes and drop-downs on the screen. A control
## may only run past the edge if it is inside a scrolling area that is itself on the
## screen (the middle of a long page scrolls; its Back and Start buttons do not).
## Also: no weapon or robot button may cut its name short, the death screen's two
## columns must fit side by side, and the pages you pick a robot and weapon on must
## fit whole (no scrolling) at every size.
## Started by tests/ui_layout_test.gd (this is a Node, so it can use the autoloads).

## Window sizes: 16:9 from small to 4K, 16:10, ultrawide 21:9 and 32:9, 4:3 and 5:4,
## and a small and a tall window.
const SIZES := [
	Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
	Vector2i(1280, 800), Vector2i(1680, 1050), Vector2i(1920, 1200),
	Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(3840, 1080),
	Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1280, 1024),
	Vector2i(640, 360), Vector2i(900, 1000),
]
const BASE := Vector2(1600, 900)   # project.godot: the size menus are laid out for

var _fails: Array[String] = []
var _checked := 0
var _view: SubViewport


func run() -> void:
	# Each page is built in a viewport the size the game's stretch settings
	# (canvas_items, expand) would give that window: the window's shape, never
	# smaller than 1600 x 900.
	var holder := SubViewportContainer.new()
	add_child(holder)
	_view = SubViewport.new()
	holder.add_child(_view)
	for window in SIZES:
		var scale := minf(window.x / BASE.x, window.y / BASE.y)
		_view.size = Vector2i((Vector2(window) / scale).round())
		await _check_main_menu(window)
		await _check_lobby_and_results(window)
		await _check_pause_menu(window)
		_check_death_screen(window)
	if _fails.is_empty():
		print("PASS menu layout: %d pages checked across %d window sizes, nothing off screen" % [_checked, SIZES.size()])
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _check_main_menu(window: Vector2i) -> void:
	var menu: Control = load("res://game/ui/main_menu.tscn").instantiate()
	_view.add_child(menu)
	for page in ["_show_main", "_show_play", "_show_practice", "_show_bot", "_show_multiplayer", "_show_profile", "_show_creator", "_show_calling_card", "_show_achievements"]:
		menu.call(page)
		await _settle()
		_check(menu, "main menu %s" % page.trim_prefix("_show_"), window, page != "_show_achievements")   # (a long list: it scrolls)
	for tab in SettingsPanel.TABS.size():
		SettingsPanel.open_on_tab(tab)
		menu.call("_show_settings")
		await _settle()
		_check(menu, "settings: %s" % SettingsPanel.TABS[tab], window)
	SettingsPanel.open_on_tab(0)
	menu.queue_free()
	await get_tree().process_frame


func _check_lobby_and_results(window: Vector2i) -> void:
	for scene in ["lobby_menu", "results_menu"]:
		var page: Control = load("res://game/ui/%s.tscn" % scene).instantiate()
		_view.add_child(page)
		await _settle()
		_check(page, scene.replace("_", " "), window, true)
		page.queue_free()
		await get_tree().process_frame


func _check_pause_menu(window: Vector2i) -> void:
	for page in ["_show_main", "_show_loadout", "_show_settings"]:
		var menu := PauseMenu.new()
		_view.add_child(menu)
		await get_tree().process_frame
		menu.visible = true
		menu.call(page)
		await _settle()
		_check(menu, "pause menu %s" % page.trim_prefix("_show_"), window, page != "_show_settings")
		menu.queue_free()
		await get_tree().process_frame


## The death screen's left column and the scoreboard beside it fit the width, and the
## longest weapon column fits the height.
func _check_death_screen(window: Vector2i) -> void:
	var view := Vector2(_view.size)
	var wide := Hud.DEATH_W + Hud.DEATH_GAP + Hud.BOARD_W
	if wide > view.x - 24.0:
		_fails.append("%s: death screen needs %d px across, the screen has %d" % [window, wide, view.x])
	var longest := 0
	for g in WeaponData.GROUPS:
		longest = maxi(longest, (g[1] as Array).size())
	var bottom := Hud.DEATH_TOP + 164.0 + 24.0 + 56.0 + 28.0 + longest * 28.0
	if bottom > view.y - 12.0:
		_fails.append("%s: death screen's weapon list ends at %d, the screen is %d tall" % [window, bottom, view.y])


## A few frames for containers to sort and the page frame to fit itself.
func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


## whole: the page must also fit without scrolling.
func _check(page: Node, what: String, window: Vector2i, whole: bool = false) -> void:
	_checked += 1
	if whole:
		for frame in page.find_children("*", "MenuFrame", true, false):
			if (frame as MenuFrame).is_visible_in_tree() and (frame as MenuFrame).scrolling():
				_fails.append("%dx%d %s: the page does not fit and has to scroll" % [window.x, window.y, what])
	var screen := Rect2(Vector2.ZERO, Vector2(_view.size)).grow(0.5)
	var found := [0]
	_walk(page, screen, "%dx%d %s" % [window.x, window.y, what], found)
	if found[0] == 0:
		_fails.append("%dx%d %s: no controls found (page did not build?)" % [window.x, window.y, what])


func _walk(n: Node, screen: Rect2, what: String, found: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	if n is ScrollContainer:
		# What is inside scrolls; the scrolling area itself must be on screen.
		var area := (n as Control).get_global_rect()
		if not screen.encloses(area):
			_fails.append("%s: a scrolling area runs off the screen (%s, screen %s)" % [what, area, screen.size])
		_walk_inside_scroll(n, what, found)
		return
	if n is BaseButton or n is LineEdit or n is Slider:
		found[0] += 1
		var r := (n as Control).get_global_rect()
		if not screen.encloses(r):
			_fails.append("%s: %s is off the screen (%s, screen %s)" % [what, _name(n), r, screen.size])
		_check_text(n, what)
	for c in n.get_children():
		_walk(c, screen, what, found)


## Inside a scrolling area: only the text checks apply.
func _walk_inside_scroll(n: Node, what: String, found: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is BaseButton or n is LineEdit or n is Slider:
		found[0] += 1
	_check_text(n, what)
	for c in n.get_children():
		_walk_inside_scroll(c, what, found)


## A robot or weapon button must show its whole name.
func _check_text(n: Node, what: String) -> void:
	if n is WeaponPicker.Card:
		var card := n as WeaponPicker.Card
		var text := WeaponData.by_id(card.id).short_name.to_upper()
		var w := HudStyle.font(true).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		if w > card.size.x - 4.0:
			_fails.append("%s: weapon card '%s' is too narrow for its name (%d px)" % [what, text, card.size.x])
	elif n is Button and (n as Button).clip_text and (n as Button).text != "":
		var b := n as Button
		var font := b.get_theme_font("font")
		var need := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		var box := b.get_theme_stylebox("normal")
		var room := b.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
		if need > room + 1.0:
			_fails.append("%s: button '%s' cuts its text short (needs %d px, has %d)" % [what, b.text, need, room])


func _name(n: Node) -> String:
	if n is Button and (n as Button).text != "":
		return "button '%s'" % (n as Button).text
	if n is WeaponPicker.Card:
		return "weapon card '%s'" % (n as WeaponPicker.Card).id
	return n.get_class()
