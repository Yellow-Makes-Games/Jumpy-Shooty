class_name ProfilePage
extends VBoxContainer
## The Profile page's body (main menu > Profile): your name, your stats (six to a
## page, paged with arrows), your calling card with your name on it, your level (see
## PlayerLevel), the achievements you track or are closest to finishing, and the one
## you finished last. And, when this build has one (see Account), your online account:
## sign in to keep all of this in the cloud.

const PER_PAGE := 6
const STAT_HEIGHT := 64.0
const SIDE := 380.0   ## the right-hand column's width

## The stats page shown: kept while the game is open.
static var page := 0

var _grid: GridContainer
var _pager: Label
var _card: CallingCardView
var _name_edit: LineEdit
var _account: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	add_child(top)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(SIDE, 0)
	top.add_child(right)

	# Your name (what other players see), and your card with it on.
	UiKit.section(left, "Username")
	var name_edit := UiKit.line_edit(left, "Player", Settings.player_name)
	name_edit.name = "name"
	name_edit.text_changed.connect(_on_name)
	_name_edit = name_edit
	_card = CallingCardView.new(Settings.calling_card, Settings.icon, Vector2(SIDE, 78), Game.local_name())
	_card.name = "card"
	right.add_child(_card)

	# Stats, six at a time.
	UiKit.section(left, "Stats")
	_grid = GridContainer.new()
	_grid.name = "stats"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(_grid)
	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 10)
	left.add_child(pager)
	_arrow(pager, "<", -1)
	_pager = UiKit.label(pager, "", false, 20)
	_pager.name = "page"
	_pager.add_theme_font_override("font", HudStyle.font(true))
	_pager.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pager.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pager.custom_minimum_size.x = 64
	_arrow(pager, ">", 1)
	_show_page()

	# Level.
	UiKit.section(right, "Level")
	_level(right)

	# Your online account (optional).
	if Account.available():
		UiKit.section(right, "Account")
		_account = VBoxContainer.new()
		_account.name = "account"
		_account.add_theme_constant_override("separation", 6)
		right.add_child(_account)
		_show_account()
		Account.changed.connect(_on_account_changed)

	var rule := ColorRect.new()
	rule.color = Color(UiKit.LINE, 0.12)
	rule.custom_minimum_size = Vector2(0, 1)
	add_child(rule)

	# Achievements: the ones you track or are nearest to, and your latest.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 30)
	add_child(bottom)
	var near := VBoxContainer.new()
	near.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	near.add_theme_constant_override("separation", 10)
	bottom.add_child(near)
	UiKit.section(near, "Tracked / closest achievements" if not Achievements.tracked().is_empty() else "Closest achievements")
	var row := HBoxContainer.new()
	row.name = "closest"
	row.add_theme_constant_override("separation", 10)
	near.add_child(row)
	var list := Achievements.closest()
	for a in list:
		row.add_child(AchievementsPanel.make_card(a, true))
	if list.is_empty():
		UiKit.label(row, "Every achievement done. Nothing left to chase!", true, 15)
	var last := VBoxContainer.new()
	last.custom_minimum_size = Vector2(SIDE, 0)
	last.add_theme_constant_override("separation", 10)
	bottom.add_child(last)
	UiKit.section(last, "Most recent achievement")
	var recent := Achievements.most_recent()
	if recent.is_empty():
		UiKit.label(last, "None yet: play a match to earn your first.", true, 15).name = "recent"
	else:
		var c := AchievementsPanel.make_card(recent, true)
		c.name = "recent"
		last.add_child(c)


## Every stat, in the order the pages show them: [name, value, how full its bar is
## (-1: no bar)].
static func stats() -> Array:
	var a := Achievements
	var counts := a.item_counts()
	var kills := a.stat("kills")
	var deaths := a.stat("deaths")
	var matches := a.stat("matches")
	var level := PlayerLevel.of(a.stat("xp"))
	return [
		["Kills", _n(kills), -1.0],
		["Games played", _n(matches), -1.0],
		["Deaths", _n(deaths), -1.0],
		["Time played", time_text(a.stat("seconds_played")), -1.0],
		["Top speed", "%d m/s" % roundi(a.best("top_speed")), -1.0],
		["Total unlocks", "%d / %d   %d%%" % [counts[0], counts[1], _pct(counts[0], counts[1])], float(counts[0]) / maxf(counts[1], 1.0)],
		["K/D ratio", "%.2f" % (float(kills) / maxf(deaths, 1.0)), -1.0],
		["Wins", "%s   (%d%% of games)" % [_n(a.stat("wins")), _pct(a.stat("wins"), matches)], -1.0],
		["Headshots", _n(a.stat("headshots")), -1.0],
		["Experience", "%s XP   (level %d)" % [_n(a.stat("xp")), level.level], -1.0],
		["Trickshots", _n(a.stat("trickshots")), -1.0],
		["Achievements", "%d / %d   %d%%" % [a.done_count(), a.LIST.size(), _pct(a.done_count(), a.LIST.size())], float(a.done_count()) / a.LIST.size()],
		["Air kills", _n(a.stat("air_kills")), -1.0],
		["Grapple kills", _n(a.stat("rope_kills")), -1.0],
		["Wall-run kills", _n(a.stat("wall_kills")), -1.0],
		["Long shots (30 m+)", _n(a.stat("long_shots")), -1.0],
		["Melee kills", _n(a.stat("melee_kills")), -1.0],
		["Kick kills", _n(a.stat("kicks")), -1.0],
		["Races finished", _n(a.stat("races")), -1.0],
		["Race wins", _n(a.stat("race_wins")), -1.0],
		["Gold medals", "%d / %d" % [a.stat("gold_medals"), a.MEDALS.size()], float(a.stat("gold_medals")) / a.MEDALS.size()],
		["Flags captured", _n(a.stat("captures")), -1.0],
		["Bombs planted", _n(a.stat("plants")), -1.0],
		["Bombs defused", _n(a.stat("defuses")), -1.0],
	]


static func pages() -> int:
	return ceili(stats().size() / float(PER_PAGE))


## "3 hours 21 minutes", "21 minutes", "40 seconds".
static func time_text(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	if h > 0:
		return "%d hour%s %d minute%s" % [h, "" if h == 1 else "s", m, "" if m == 1 else "s"]
	if m > 0:
		return "%d minute%s" % [m, "" if m == 1 else "s"]
	return "%d second%s" % [seconds, "" if seconds == 1 else "s"]


static func _n(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out


static func _pct(part: int, whole: int) -> int:
	return floori(100.0 * part / whole) if whole > 0 else 0


func _arrow(parent: Node, text: String, step: int) -> Button:
	var b := UiKit.button(parent, text, func(): turn(step))
	b.name = "prev" if step < 0 else "next"
	b.custom_minimum_size = Vector2(48, 40)
	b.set_meta("sfx", "select")
	return b


## Show the next (1) or previous (-1) page of stats; it wraps round.
func turn(step: int) -> void:
	page = posmod(page + step, pages())
	_show_page()


func _show_page() -> void:
	page = clampi(page, 0, pages() - 1)
	UiKit.clear(_grid)
	var all := stats()
	for i in PER_PAGE:
		var at := page * PER_PAGE + i
		if at < all.size():
			_grid.add_child(_stat(all[at]))
		else:
			var gap := Control.new()   # keeps the grid the same height on a short last page
			gap.custom_minimum_size = Vector2(0, STAT_HEIGHT)
			_grid.add_child(gap)
	_pager.text = "%d/%d" % [page + 1, pages()]


## One stat's chip: its name, its value and, for a share of something, a bar.
func _stat(s: Array) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = str(s[0])
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size = Vector2(0, STAT_HEIGHT)
	chip.add_theme_stylebox_override("panel", _chip_box())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	chip.add_child(col)
	var title := UiKit.label(col, str(s[0]), false, 18)
	title.add_theme_font_override("font", HudStyle.font(true))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	if float(s[2]) >= 0.0:
		col.add_child(_bar(float(s[2])))
	var value := UiKit.label(col, str(s[1]), true, 16)
	value.name = "value"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	return chip


func _chip_box() -> StyleBoxFlat:
	var box := UiKit.cut_box(Color(1, 1, 1, 0.035), 8, 14, 8)
	box.border_width_left = 3
	box.border_color = Color(UiKit.LINE, 0.5)
	return box


## Your level, a bar to the next, and the experience in numbers.
func _level(parent: Node) -> void:
	var lv := PlayerLevel.of(Achievements.stat("xp"))
	var chip := PanelContainer.new()
	chip.name = "level"
	chip.add_theme_stylebox_override("panel", _chip_box())
	parent.add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	chip.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var big := UiKit.label(top, str(lv.level), false, 34)
	big.name = "number"
	big.add_theme_font_override("font", HudStyle.font(true))
	big.add_theme_color_override("font_color", UiKit.ACCENT)
	big.autowrap_mode = TextServer.AUTOWRAP_OFF
	var hint := UiKit.label(top, "Kills earn their killcam score as XP", true, 13)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_bar(float(lv.into) / float(lv.need)))
	var nums := UiKit.label(col, "%s / %s XP   %d%%" % [_n(lv.into), _n(lv.need), _pct(lv.into, lv.need)], true, 14)
	nums.name = "xp"
	nums.add_theme_color_override("font_color", Color(UiKit.CYAN, 0.8))


func _bar(fraction: float) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(1, 1, 1, 0.08)
	bar.custom_minimum_size = Vector2(0, 4)
	var fill := ColorRect.new()
	fill.color = UiKit.ACCENT
	fill.anchor_right = clampf(fraction, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	bar.add_child(fill)
	return bar


func _on_name(text: String) -> void:
	Settings.player_name = text.strip_edges()
	Settings.save_settings()
	_card.show_card(Settings.calling_card, Settings.icon, Game.local_name())


func _on_account_changed() -> void:
	if not is_inside_tree():
		return
	_show_account()
	# A sync may have brought a profile from another computer.
	if _name_edit and not _name_edit.has_focus() and _name_edit.text != Settings.player_name:
		_name_edit.text = Settings.player_name
	_card.show_card(Settings.calling_card, Settings.icon, Game.local_name())


## Signed out: a button for each sign-in provider. Signed in: who as, the sync's
## state, and Sign out.
func _show_account() -> void:
	UiKit.clear(_account)
	var line := ""
	if Account.busy == "signing_in":
		line = Account.status
		UiKit.label(_account, line, true, 14).name = "status"
		UiKit.button(_account, "Cancel", Account.cancel_sign_in).name = "cancel"
		return
	if Account.signed_in():
		var who := Account.email if Account.email != "" else "your %s account" % str(Account.PROVIDER_NAMES.get(Account.provider, Account.provider))
		var l := UiKit.label(_account, "Signed in as " + who, false, 15)
		l.name = "who"
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		var state := "Syncing..." if Account.busy == "syncing" else Account.status
		if state != "":
			UiKit.label(_account, state, true, 13).name = "status"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_account.add_child(row)
		var sync := UiKit.button(row, "Sync now", Account.sync_now)
		sync.name = "sync"
		sync.disabled = Account.busy != ""
		UiKit.button(row, "Sign out", Account.sign_out).name = "sign_out"
		return
	UiKit.label(_account, "Optional: sign in to keep your profile and progress in the cloud.", true, 13)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_account.add_child(buttons)
	for p in Account.providers():
		var b := UiKit.button(buttons, str(p[1]), Account.sign_in.bind(str(p[0])))
		b.name = "sign_in_" + str(p[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Account.status != "":
		UiKit.label(_account, Account.status, true, 13).name = "status"
