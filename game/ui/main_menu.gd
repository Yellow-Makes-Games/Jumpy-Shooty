extends Control
## Main menu. The front page has the title and big buttons on the left and your
## robot on the right; every other page (Play, Practice, Vs Bots, Multiplayer,
## Settings) is one centred panel. Built in code.

var _front: Control             # the front page
var _robot: RobotPreview
var _center: CenterContainer    # holds the panel for the other pages
var _panel: PanelContainer
var _col: VBoxContainer
var _name_edit: LineEdit
var _address_edit: LineEdit
var _status: Label


func _ready() -> void:
	theme = UiKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	_build_front()
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_panel = PanelContainer.new()
	_center.add_child(_panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	_panel.add_child(_col)
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
	add_child(_front)
	_robot = RobotPreview.new(Vector2(820, 720), 0.92)
	_robot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 60)
	_robot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_robot.grow_vertical = Control.GROW_DIRECTION_BOTH
	_front.add_child(_robot)
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 120)
	left.grow_vertical = Control.GROW_DIRECTION_BOTH
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 12)
	left.name = "Column"
	_front.add_child(left)
	var notice := Label.new()
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	notice.text = "Milestone 1 · work in progress"
	notice.add_theme_font_size_override("font_size", 14)
	notice.add_theme_color_override("font_color", Color(UiKit.TEXT_DIM, 0.6))
	_front.add_child(notice)


func _page(width: float) -> void:
	_front.visible = false
	_center.visible = true
	_panel.custom_minimum_size = Vector2(width, 0)
	_panel.reset_size()
	UiKit.clear(_col)


func _show_main() -> void:
	_front.visible = true
	_center.visible = false
	_robot.show_lineup(Characters.ids(), Net.PLAYER_COLORS)   # every robot, newest on the left
	var left: VBoxContainer = _front.get_node("Column")
	UiKit.clear(left)
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
	UiKit.spacer(left, 18)
	UiKit.primary_button(left, "Play", _show_play).grab_focus()
	_front_button(left, "Multiplayer", _show_multiplayer)
	_front_button(left, "Settings", _show_settings)
	_front_button(left, "Exit", Game.quit_game)


func _big(parent: Node, text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", 92)
	l.add_theme_color_override("font_color", color)
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
	_page(900)
	UiKit.title(_col, "Play", 36)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_col.add_child(row)
	_card(row, "Vs Bots", "A 1v1, or a free-for-all against up to 4 bots. Easy to Expert.", _show_bot).grab_focus()
	_card(row, "Practice", "Free roam on your own to learn a map's routes.", _show_practice)
	_card(row, "Multiplayer", "Free-for-all with up to 4 friends.", _show_multiplayer)
	UiKit.spacer(_col, 4)
	_back_row(_show_main)


## A big button with a heading and a line of text.
func _card(parent: Node, heading: String, blurb: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 180)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	parent.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 20)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	var bar := ColorRect.new()
	bar.color = UiKit.ACCENT
	bar.custom_minimum_size = Vector2(28, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var h := UiKit.label(v, heading.to_upper(), false, 26)
	h.add_theme_font_override("font", HudStyle.font(true))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := UiKit.label(v, blurb, true, 15)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Back on the left; returns the row so a page can add its main action on the right.
func _back_row(back: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_col.add_child(row)
	var b := UiKit.button(row, "Back", back)
	b.custom_minimum_size = Vector2(160, 56)
	return row


func _start_button(row: HBoxContainer, on_press: Callable) -> void:
	var s := UiKit.primary_button(row, "Start", on_press)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.grab_focus()


## Two columns: match options on the left, your robot on the right. Returns the left one.
func _two_columns() -> VBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	_col.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	row.add_child(right)
	var pick := CharacterPicker.new(Game.local_character())
	right.add_child(pick)
	pick.picked.connect(func(id: String):
		Settings.character = id
		Settings.save_settings())
	return left


## A "Map" heading and drop-down with every map; `current` is selected.
func _map_picker(parent: Node, current: String) -> OptionButton:
	UiKit.section(parent, "Map")
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(0, 46)
	Maps.fill(pick, current)
	parent.add_child(pick)
	return pick


func _show_practice() -> void:
	_page(820)
	UiKit.title(_col, "Practice", 36)
	UiKit.label(_col, "Roam a map on your own to learn its routes. No opponents, no timer.", true, 16)
	var left := _two_columns()
	var map := _map_picker(left, Game.last_practice_map)
	var row := _back_row(_show_play)
	_start_button(row, func(): Game.start_practice(Maps.LIST[map.selected].id))


const BOT_BLURBS := [
	"Slow to react, wobbly aim, mostly just runs and shoots.",
	"Reacts in about a third of a second, slides while chasing you.",
	"Quick and accurate, strafes hard, grapples, dives and flips.",
	"Near-instant reactions, leads its shots, goes for your head.",
]


func _show_bot() -> void:
	_page(820)
	UiKit.title(_col, "Vs Bots", 36)
	var left := _two_columns()
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
		count.add_item("1 (1v1)" if n == 1 else "%d (free-for-all)" % n, n)
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
	var blurb := UiKit.label(left, BOT_BLURBS[level[0]], true, 15)
	blurb.custom_minimum_size = Vector2(0, 40)
	for i in seg.get_child_count():
		(seg.get_child(i) as Button).pressed.connect(func():
			level[0] = i
			blurb.text = BOT_BLURBS[i])
	var map := _map_picker(left, Game.last_bot.map)
	var buttons := _back_row(_show_play)
	_start_button(buttons, func(): Game.start_bot(level[0], int(kills.value), Maps.LIST[map.selected].id,
			count.get_selected_id()))


func _show_multiplayer() -> void:
	_page(820)
	UiKit.title(_col, "Multiplayer", 36)
	UiKit.section(_col, "Your name")
	_name_edit = UiKit.line_edit(_col, "Player", Game.local_name() if Game.local_name() != "Player" else "")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_col.add_child(row)
	var host := _box(row)
	UiKit.section(host, "Host")
	UiKit.label(host, "Start a lobby that friends join by your address. You pick the map and rules.", true, 15)
	UiKit.primary_button(host, "Create lobby", _on_create)
	var join := _box(row)
	UiKit.section(join, "Join")
	UiKit.label(join, "Type the host's address (direct IP; Steam invites come next).", true, 15)
	_address_edit = UiKit.line_edit(join, "127.0.0.1", "")
	UiKit.button(join, "Join lobby", _on_join)
	_status = UiKit.label(_col, "", true, 16)
	_back_row(_show_main)


## A darker inset box in a page.
func _box(parent: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.035)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v


func _show_settings() -> void:
	_page(660)
	var panel := SettingsPanel.new()
	panel.closed.connect(_show_main)
	_col.add_child(panel)


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
	var err := Game.join_online(_address_edit.text.strip_edges())
	if err != OK:
		_status.text = "Could not start joining (%s)." % error_string(err)
	else:
		_status.text = "Connecting..."
