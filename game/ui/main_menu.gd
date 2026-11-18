extends Control
## Main menu. The front page has the title and big buttons on the left and every
## robot lined up on the right; every other page (Play, Practice, Vs Bots,
## Multiplayer, Settings) is built in one MenuFrame, which keeps its buttons on
## screen whatever the window size. Built in code.

const MODE_LABELS := ["Shoot-out", "Deathmatch", "Race"]
## Shown where the weapon cards would be, in the modes that don't use your pick.
const NO_WEAPON_NOTES := {
	"race": "A race has no weapons: it is you, the course and the clock.",
	"dm": "Deathmatch: everyone starts unarmed. Weapons float about the map; walk over one to pick it up.",
	"gungame": "Gun Game hands out the weapons: every kill moves you to the next one.",
}

var _front: Control             # the front page
var _robot: RobotPreview
var _frame: MenuFrame           # every other page
var _name_edit: LineEdit
var _address_edit: LineEdit
var _status: Label


func _ready() -> void:
	theme = UiKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	_build_front()
	_frame = MenuFrame.new(900, false, false)
	add_child(_frame)
	match DevArgs.menu:
		"play": _show_play()
		"bot": _show_bot()
		"practice": _show_practice()
		"multiplayer": _show_multiplayer()
		"settings": _show_settings()
		_: _show_main()


func _build_front() -> void:
	_front = Control.new()
	_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front.draw.connect(_draw_front)
	_front.resized.connect(_front.queue_redraw)
	add_child(_front)
	_robot = RobotPreview.new(Vector2(820, 720), 0.92)
	_robot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 60)
	_robot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_robot.grow_vertical = Control.GROW_DIRECTION_BOTH
	_front.add_child(_robot)
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 120)
	left.grow_vertical = Control.GROW_DIRECTION_BOTH
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 12)
	left.name = "Column"
	_front.add_child(left)
	var notice := Label.new()
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 44)
	notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	notice.text = "MILESTONE 1  ·  WORK IN PROGRESS"
	notice.add_theme_font_override("font", HudStyle.font_spaced(2))
	notice.add_theme_font_size_override("font_size", 12)
	notice.add_theme_color_override("font_color", Color(UiKit.TEXT_DIM, 0.7))
	_front.add_child(notice)


## A ruled line down the left of the front page's column, and a caption under the robots.
func _draw_front() -> void:
	var s := _front.size
	var x := 92.0
	_front.draw_line(Vector2(x, s.y * 0.5 - 250.0), Vector2(x, s.y * 0.5 + 250.0), Color(UiKit.LINE, 0.3), 1.0)
	_front.draw_rect(Rect2(x - 2.0, s.y * 0.5 - 250.0, 5.0, 34.0), UiKit.ACCENT)
	for i in 9:
		_front.draw_line(Vector2(x, s.y * 0.5 - 180.0 + i * 52.0), Vector2(x + 8.0, s.y * 0.5 - 180.0 + i * 52.0), Color(UiKit.LINE, 0.4), 1.0)
	var cap := Vector2(s.x - 60.0 - 410.0, s.y * 0.5 + 200.0)
	HudStyle.label(_front, cap, "%d ROBOTS  ·  %d WEAPONS  ·  PICK YOURS" % [Characters.LIST.size(), WeaponData.IDS.size()], 12,
		Color(UiKit.CYAN, 0.75), HORIZONTAL_ALIGNMENT_CENTER)


## Start a page in the frame: `width` wide, with this heading.
func _page(width: float, heading: String = "", kicker: String = "") -> void:
	_front.visible = false
	_frame.visible = true
	_frame.clear(width)
	if heading != "":
		_frame.title(heading, kicker)


func _show_main() -> void:
	_front.visible = true
	_frame.visible = false
	_frame.clear()
	_robot.show_lineup(Characters.ids(), Net.PLAYER_COLORS)   # every robot, newest on the left
	var left: VBoxContainer = _front.get_node("Column")
	UiKit.clear(left)
	var kicker := Label.new()
	kicker.text = "HIGH-MOBILITY ARENA SHOOTER"
	kicker.add_theme_font_override("font", HudStyle.font_spaced(3))
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", UiKit.CYAN)
	left.add_child(kicker)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -34)   # the font's line height is generous
	left.add_child(logo)
	_big(logo, "JUMPY", Color.WHITE)
	_big(logo, "SHOOTY", UiKit.ACCENT)
	UiKit.label(left, "Grapple, wall-run, slide and shoot.", true, 18)
	if Game.pending_notice != "":
		var n := UiKit.label(left, Game.pending_notice, false, 17)
		n.add_theme_color_override("font_color", UiKit.ACCENT)
		Game.pending_notice = ""
	UiKit.spacer(left, 14)
	UiKit.primary_button(left, "Play", _show_play).grab_focus()
	_front_button(left, "Multiplayer", _show_multiplayer)
	_front_button(left, "Settings", _show_settings)
	_front_button(left, "Exit", Game.quit_game)


func _big(parent: Node, text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", 96)
	l.add_theme_color_override("font_color", color)
	# A soft halo of its own colour behind the letters.
	l.add_theme_color_override("font_shadow_color", Color(color, 0.13))
	l.add_theme_constant_override("shadow_outline_size", 22)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	parent.add_child(l)
	return l


func _front_button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := UiKit.button(parent, text.to_upper(), on_press)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 22)
	return b


# ---------------------------------------------------------------------------
# Play: three cards

func _show_play() -> void:
	_page(1000, "Play", "Choose a game")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_frame.body.add_child(row)
	_card(row, "bots", "Vs Bots", "A 1v1, or a free-for-all against up to 4 bots. Easy to Expert.", _show_bot).grab_focus()
	_card(row, "practice", "Practice", "Free roam on your own to learn a map's routes.", _show_practice)
	_card(row, "online", "Multiplayer", "Free-for-all with up to 15 friends.", _show_multiplayer)
	_frame.back_button("Back", _show_main)


## A big button with a drawing, a heading and a line of text.
func _card(parent: Node, kind: String, heading: String, blurb: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 250)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	parent.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 22)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.draw.connect(_draw_card_art.bind(art, kind))
	v.add_child(art)
	var bar := ColorRect.new()
	bar.color = UiKit.ACCENT
	bar.custom_minimum_size = Vector2(28, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var h := UiKit.label(v, heading.to_upper(), false, 28)
	h.add_theme_font_override("font", HudStyle.font(true))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := UiKit.label(v, blurb, true, 15)
	d.custom_minimum_size = Vector2(0, 48)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## The line drawing on a Play card: a robot's head, a target, or linked players.
func _draw_card_art(art: Control, kind: String) -> void:
	var c := Vector2(54.0, art.size.y * 0.5)
	var line := Color(UiKit.CYAN, 0.9)
	var hot := UiKit.ACCENT
	match kind:
		"bots":
			art.draw_rect(Rect2(c + Vector2(-30, -22), Vector2(60, 46)), line, false, 2.0)
			art.draw_rect(Rect2(c + Vector2(-18, -8), Vector2(12, 8)), hot)
			art.draw_rect(Rect2(c + Vector2(6, -8), Vector2(12, 8)), hot)
			art.draw_line(c + Vector2(-12, 12), c + Vector2(12, 12), line, 2.0)
			art.draw_line(c + Vector2(0, -22), c + Vector2(0, -36), line, 2.0)
			art.draw_circle(c + Vector2(0, -38), 3.5, hot)
			art.draw_line(c + Vector2(-30, 0), c + Vector2(-38, 0), line, 2.0)
			art.draw_line(c + Vector2(30, 0), c + Vector2(38, 0), line, 2.0)
		"practice":
			for r in [34.0, 22.0]:
				art.draw_arc(c, r, 0.0, TAU, 48, line, 2.0, true)
			art.draw_circle(c, 5.0, hot)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				art.draw_line(c + d * 28.0, c + d * 42.0, hot, 2.0)
		_:
			var nodes := [c + Vector2(-30, 18), c + Vector2(0, -28), c + Vector2(30, 18)]
			for i in 3:
				art.draw_line(nodes[i], nodes[(i + 1) % 3], Color(line, 0.6), 2.0, true)
			for i in 3:
				art.draw_circle(nodes[i], 9.0, UiKit.PANEL)
				art.draw_arc(nodes[i], 9.0, 0.0, TAU, 24, line if i != 1 else hot, 2.0, true)
				art.draw_circle(nodes[i], 3.5, hot if i == 1 else line)
	# A faint ruler along the right of the drawing.
	for i in 12:
		var x := 120.0 + i * 12.0
		if x < art.size.x:
			art.draw_line(Vector2(x, c.y + 30.0), Vector2(x, c.y + (22.0 if i % 4 == 0 else 26.0)), Color(1, 1, 1, 0.14), 1.0)


func _start_button(on_press: Callable) -> void:
	_frame.main_button("Start", on_press).grab_focus()


## A match page's body: match options on the left, then your robot, then your
## weapon. Returns [the options column, a function to call with the mode ("ffa",
## "dm", "race", "gungame") and the weapons allowed in a shoot-out (see LobbySettings;
## [] for all), so the weapon cards offer only those, or give way to a note when the
## mode doesn't use your pick or there is one gun for everyone].
func _three_columns() -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_frame.body.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(410, 0)
	row.add_child(left)
	_divider(row)
	var pick := CharacterPicker.new(Game.local_character(), Net.PLAYER_COLORS[0], Game.local_weapon())
	row.add_child(pick)
	pick.picked.connect(func(id: String):
		Settings.character = id
		Settings.save_settings())
	_divider(row)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(520, 0)
	row.add_child(right)
	var gun := WeaponPicker.new(Game.local_weapon())
	right.add_child(gun)
	gun.picked.connect(func(id: String):
		Settings.weapon = id
		Settings.save_settings()
		pick.set_weapon(id))
	var none := VBoxContainer.new()
	none.add_theme_constant_override("separation", 8)
	none.visible = false
	right.add_child(none)
	UiKit.section(none, "Weapon")
	var note := UiKit.label(UiKit.inset(none), "", true, 17)
	var moves := MobilityPicker.new(Game.local_mobility())
	pick.add_child(moves)   # under the robot: that column has the room
	moves.picked.connect(func(id: String):
		Settings.mobility = id
		Settings.save_settings())
	var set_mode := func(mode: String, allowed: Array = []):
		var guns := LobbySettings.weapons_from(allowed if mode == "ffa" else [])
		var uses_pick := not NO_WEAPON_NOTES.has(mode) and guns.size() > 1
		gun.set_allowed(guns)
		var shown := Game.local_weapon() if Game.local_weapon() in guns else str(guns[0])
		gun.select(shown)   # your saved pick stays saved; it comes back when it is allowed
		pick.set_weapon(shown)
		gun.visible = uses_pick
		none.visible = not uses_pick
		note.text = NO_WEAPON_NOTES.get(mode, "One gun for everyone: the %s." % WeaponData.name_of(guns[0]))
		moves.visible = mode != "race"   # a race always has the grapple
	return [left, set_mode]


## A thin upright line between two columns.
func _divider(row: Node) -> void:
	var line := ColorRect.new()
	line.color = Color(UiKit.LINE, 0.12)
	line.custom_minimum_size = Vector2(1, 0)
	row.add_child(line)


## A "Map" heading and drop-down with the maps for `game`; `current` is selected.
func _map_picker(parent: Node, current: String, game: String = "ffa") -> OptionButton:
	UiKit.section(parent, "Map")
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0, 46)
	Maps.fill(pick, current, game)
	parent.add_child(pick)
	return pick


## A "Mode" heading and switch: free-for-all (or 1v1) or race, and Gun Game if
## `gun_game`. Returns [mode] (an array, so the callbacks can change it); `on_change`
## gets the new mode: a game id ("ffa", "race") or "gungame".
func _mode_picker(parent: Node, game: String, on_change: Callable, gun_game: bool = false) -> Array:
	UiKit.section(parent, "Mode")
	var mode := [game]
	var modes: Array = GunGame.MODES if gun_game else Maps.GAMES
	UiKit.segmented(parent, GunGame.MODE_LABELS if gun_game else MODE_LABELS, maxi(modes.find(game), 0), func(i: int):
		mode[0] = modes[i]
		on_change.call(mode[0]), 2)
	return mode


func _show_practice() -> void:
	_page(1460, "Practice", "Play  /  on your own")
	var cols := _three_columns()
	var left: VBoxContainer = cols[0]
	var set_mode: Callable = cols[1]
	var note := UiKit.label(left, "", true, 16)
	note.custom_minimum_size = Vector2(0, 44)
	var game := Game.last_practice_game if Maps.fits(Game.last_practice_map, Game.last_practice_game) else Maps.game_of(Game.last_practice_map)
	# The map drop-down is made after the mode switch, but the switch refills it, so
	# the callback reaches it through an array (lambdas copy plain locals when made).
	var map_ref: Array[OptionButton] = [null]
	var explain := func(g: String):
		note.text = "Run a race course on your own against the clock." if g == "race" \
			else ("Weapons float about the map: walk over one to pick it up. Carry two: 1 and 2 to switch." if g == "dm" \
			else "Roam a map on your own to learn its routes. No opponents, no timer.")
		set_mode.call(g)
	explain.call(game)
	var mode := _mode_picker(left, game, func(g: String):
		explain.call(g)
		Maps.fill(map_ref[0], Game.last_map.get(g, Maps.default_id(g)), g))
	var map := _map_picker(left, Game.last_practice_map, mode[0])
	map_ref[0] = map
	_frame.back_button("Back", _show_play)
	_start_button(func(): Game.start_practice(Maps.picked(map), mode[0]))


const RACE_BLURBS := [
	"Takes its time, hesitates at the tricky bits and fumbles a jump now and then.",
	"A steady runner: few mistakes, but no hurry on the straights.",
	"Quick on the straights and clean over the obstacles.",
	"Flat out everywhere, takes every line first time.",
]

const BOT_BLURBS := [
	"Slow to react, wobbly aim, mostly just runs and shoots.",
	"Reacts in about a third of a second, slides while chasing you.",
	"Quick and accurate, strafes hard, grapples, dives and flips.",
	"Near-instant reactions, leads its shots, goes for your head.",
]


func _show_bot() -> void:
	_page(1460, "Vs Bots", "Play  /  against the machines")
	var cols := _three_columns()
	var left: VBoxContainer = cols[0]
	var set_mode: Callable = cols[1]
	# How many bots and kills to win share a row, to keep the page short.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	left.add_child(row)
	var bots_box := VBoxContainer.new()
	bots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bots_box)
	UiKit.section(bots_box, "Bots")
	var count := OptionButton.new()
	for n in range(1, Game.MAX_BOTS + 1):
		count.add_item("", n)
	count.custom_minimum_size = Vector2(0, 46)
	count.select(clampi(int(Game.last_bot.get("bots", 1)), 1, Game.MAX_BOTS) - 1)
	bots_box.add_child(count)
	var kills_box := VBoxContainer.new()
	kills_box.custom_minimum_size = Vector2(150, 0)
	row.add_child(kills_box)
	UiKit.section(kills_box, "Kills to win")
	var kills := SpinBox.new()
	kills.min_value = 1
	kills.max_value = 50
	kills.value = Game.last_bot.kills
	kills.custom_minimum_size = Vector2(0, 46)
	kills_box.add_child(kills)
	UiKit.section(left, "Difficulty (every bot)")
	var level := [Game.last_bot.difficulty]   # in an array so the button callbacks can change it
	var seg := UiKit.segmented(left, BotDifficulty.NAMES, level[0], func(_i: int): pass)
	var blurb := UiKit.label(left, "", true, 15)
	blurb.custom_minimum_size = Vector2(0, 40)
	var game := str(Game.last_bot.get("game", Maps.game_of(Game.last_bot.map)))
	if game == "ffa" and str(Game.last_bot.get("rules", "")) == "gungame":
		game = "gungame"
	var map_ref: Array[OptionButton] = [null]   # filled below; see _show_practice
	var rules_ref: Array[AllowedWeaponsPicker] = [null]   # the weapons allowed; filled below
	# Race or shoot-out: the bot count reads differently, kills to win goes away.
	var show_mode := func(g: String):
		var race := g == "race"
		kills_box.visible = g == "ffa" or g == "dm"
		for n in range(1, Game.MAX_BOTS + 1):
			var t := "%d (1v1)" % n if n == 1 else "%d (free-for-all)" % n
			if race:
				t = "%d bot%s (race)" % [n, "" if n == 1 else "s"]
			count.set_item_text(n - 1, t)
		blurb.text = (RACE_BLURBS if race else BOT_BLURBS)[level[0]]
		if rules_ref[0]:
			rules_ref[0].visible = g == "ffa"   # a shoot-out: you pick the weapons you and the bots may use
		set_mode.call(g, rules_ref[0].value() if rules_ref[0] else [])
	for i in seg.get_child_count():
		(seg.get_child(i) as Button).pressed.connect(func():
			level[0] = i
			blurb.text = (RACE_BLURBS if map_ref[0] and Maps.game_of(Maps.picked(map_ref[0])) == "race" else BOT_BLURBS)[i])
	var mode := _mode_picker(left, game, func(m: String):
		show_mode.call(m)
		var g := GunGame.game_of_mode(m)
		Maps.fill(map_ref[0], Game.last_map.get(g, Maps.default_id(g)), g), true)
	# The mode switch goes first on the page.
	var mode_row_start := left.get_child_count() - 2
	left.move_child(left.get_child(mode_row_start), 0)
	left.move_child(left.get_child(mode_row_start + 1), 1)
	var map := _map_picker(left, Game.last_bot.map, GunGame.game_of_mode(mode[0]))
	map_ref[0] = map
	var rules := AllowedWeaponsPicker.new(Game.last_bot.get("weapons", []))
	rules.preferred = Game.local_weapon()
	left.add_child(rules)
	rules_ref[0] = rules
	rules.changed.connect(func(_ids: Array): show_mode.call(mode[0]))
	show_mode.call(mode[0])
	_frame.back_button("Back", _show_play)
	_start_button(func(): Game.start_bot(level[0], int(kills.value), Maps.picked(map),
			count.get_selected_id(), mode[0] == "gungame", GunGame.game_of_mode(mode[0]), rules.value()))


func _show_multiplayer() -> void:
	_page(900, "Multiplayer", "Play  /  with friends")
	var col := _frame.body
	UiKit.section(col, "Your name")
	_name_edit = UiKit.line_edit(col, "Player", Game.local_name() if Game.local_name() != "Player" else "")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var host := UiKit.inset(row)
	UiKit.section(host, "Host")
	UiKit.label(host, "Start a lobby that friends join by your address. You pick the map and rules.", true, 15)
	UiKit.primary_button(host, "Create lobby", _on_create)
	var join := UiKit.inset(row)
	UiKit.section(join, "Join")
	UiKit.label(join, "Type the host's address (direct IP; Steam invites come next).", true, 15)
	_address_edit = UiKit.line_edit(join, "127.0.0.1", Settings.last_address)   # the last address you joined
	UiKit.button(join, "Join lobby", _on_join)
	_status = UiKit.label(col, "", true, 16)
	_frame.back_button("Back", _show_main)


func _show_settings() -> void:
	_page(900)
	var panel := SettingsPanel.new(_frame)
	panel.closed.connect(_show_main)
	_frame.body.add_child(panel)


func _save_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n != "" and n != Settings.player_name:
		Settings.player_name = n
		Settings.save_settings()


func _on_create() -> void:
	_save_name()
	var err := Game.host_online()
	if err != OK:
		_status.text = "Could not create the lobby (%s). Is another copy already hosting on this PC?" % error_string(err)


func _on_join() -> void:
	_save_name()
	var address := _address_edit.text.strip_edges()
	if address != "" and address != Settings.last_address:
		Settings.last_address = address
		Settings.save_settings()
	var err := Game.join_online(address)
	if err != OK:
		_status.text = "Could not start joining (%s)." % error_string(err)
	else:
		_status.text = "Connecting..."
