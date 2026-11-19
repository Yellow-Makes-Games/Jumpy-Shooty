class_name AchievementsPanel
extends GridContainer
## The Achievements page's body (main menu > Achievements): a card for every
## achievement with what to do, how far along you are, and what it unlocks (in the
## Character Creator, or a calling card or an icon). The ones you have done are lit.
## The page (MenuFrame) scrolls. Over the cards the page puts medals(): your best
## time on every race course, and the times to beat; and tabs(): the kind of
## achievement shown (All, Combat, Movement, Matches, Races, Misc).
##
## Click a card, or point at it and press T, to track it (up to
## Achievements.MAX_TRACKED): the Profile page shows the ones you track first.

const COLUMNS := 3
const DONE := Color(0.45, 0.95, 0.5)
const MEDAL_COLORS := [Color(0.80, 0.52, 0.30), Color(0.80, 0.84, 0.90), Color(1.0, 0.80, 0.25)]   ## bronze, silver, gold

## The kind picked ("all", or an id from Achievements.GROUPS): kept while the game is open.
static var category := "all"

const TRACK_KEY := KEY_T
const TRACK_TIP := "Click, or point and press T, to track this on your Profile (up to %d)."

var _hover := ""   # the achievement under the mouse


## A calling card or an icon an achievement unlocks, small, on its card.
class Thumb extends Control:
	var key := ""

	func _init(item: String, done: bool) -> void:
		key = item
		custom_minimum_size = Vector2(54, 24) if key.begins_with("card:") else Vector2(24, 24)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		modulate.a = 1.0 if done else 0.55
		tooltip_text = Achievements.item_name(key)
		mouse_filter = Control.MOUSE_FILTER_PASS   # (a click on it is a click on its card)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if key.begins_with("card:"):
			CallingCard.draw_card(self, r, key.get_slice(":", 1))
		else:
			CallingCard.draw_icon(self, r, key.get_slice(":", 1))


func _init() -> void:
	columns = COLUMNS
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill()


## Show one kind of achievement ("all", or an id from Achievements.GROUPS).
func set_category(kind: String) -> void:
	category = kind
	_fill()


func _fill() -> void:
	UiKit.clear(self)
	_hover = ""
	for a in shown(category):
		add_child(_trackable(make_card(a)))


## The achievements of a kind, in the list's order; "all": every one, kind by kind.
static func shown(kind: String = category) -> Array:
	var out := []
	for group in Achievements.GROUPS:
		if kind == "all" or kind == group[0]:
			out.append_array(Achievements.LIST.filter(func(a): return a.group == group[0]))
	return out


## The row of tabs that picks which kind `panel` shows: All, then one for each kind,
## each with how many of its achievements are done.
static func tabs(panel: AchievementsPanel) -> Container:
	var kinds := ["all"]
	var names := []
	for group in Achievements.GROUPS:
		kinds.append(group[0])
	for kind in kinds:
		var list := shown(kind)
		var title: String = "All" if kind == "all" else Achievements.GROUPS[kinds.find(kind) - 1][1]
		names.append("%s  %d / %d" % [title, list.filter(func(a): return Achievements.done(a.id)).size(), list.size()])
	var holder := HBoxContainer.new()
	var row := UiKit.segmented(holder, names, maxi(kinds.find(category), 0), func(i: int): panel.set_category(kinds[i]))
	holder.remove_child(row)
	holder.free()
	row.name = "tabs"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in row.get_children():
		b.custom_minimum_size.y = 38
		b.add_theme_font_size_override("font_size", 16)
		b.set_meta("sfx", "select")
	return row


## Clicking the card, or T while the mouse is on it, tracks it (or stops tracking it).
func _trackable(c: PanelContainer) -> PanelContainer:
	var id := str(c.name)
	if Achievements.done(id):
		return c
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.tooltip_text = TRACK_TIP % Achievements.MAX_TRACKED
	c.mouse_entered.connect(func(): _hover = id)
	c.mouse_exited.connect(func():
		if _hover == id:
			_hover = "")
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseMotion:
			_hover = id
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			toggle_track(id))
	return c


func _input(e: InputEvent) -> void:
	if _hover != "" and is_visible_in_tree() and e is InputEventKey and e.pressed and not e.echo 			and (e as InputEventKey).keycode == TRACK_KEY:
		toggle_track(_hover)
		get_viewport().set_input_as_handled()


## Track an achievement or stop tracking it, and redraw the cards (tracking a fourth
## lets the oldest go, so another card may change too).
func toggle_track(id: String) -> void:
	Achievements.toggle_tracked(id)
	if Sound.has_sound("ui_select"):
		Sound.play("ui_select")
	for c in get_children():
		if Achievements.by_id(str(c.name)).is_empty():
			continue
		var marked: bool = c.has_meta("tracked")
		if marked != Achievements.is_tracked(str(c.name)):
			var at := c.get_index()
			var fresh := _trackable(make_card(Achievements.by_id(str(c.name))))
			remove_child(c)
			c.queue_free()
			add_child(fresh)
			move_child(fresh, at)
	_hover = id   # (the new card is under the mouse)


## An achievement's card: its name, how far along it is, what to do and what it
## unlocks. small: the Profile page's smaller card.
static func make_card(a: Dictionary, small: bool = false) -> PanelContainer:
	var done := Achievements.done(a.id)
	var tracked := not done and Achievements.is_tracked(a.id)
	var k := 0.8 if small else 1.0   # text size
	var card := PanelContainer.new()
	card.name = a.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.cut_box(Color(DONE, 0.07) if done else (Color(UiKit.ACCENT, 0.07) if tracked else Color(1, 1, 1, 0.04)), 8, 14, 9)
	box.border_width_left = 3
	box.border_color = DONE if done else (UiKit.ACCENT if tracked else Color(UiKit.LINE, 0.5))
	card.add_theme_stylebox_override("panel", box)
	if tracked:
		card.set_meta("tracked", true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(top)
	var title := _line(top, str(a.name), roundi(17 * k), Color.WHITE if done else UiKit.TEXT)
	title.add_theme_font_override("font", HudStyle.font(true))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tracked:
		UiKit.tag(top, "TRACKED", UiKit.ACCENT).mouse_filter = Control.MOUSE_FILTER_PASS
	_line(top, "DONE" if done else Achievements.progress_text(a), roundi(13 * k), DONE if done else UiKit.TEXT_DIM, false).name = "progress"
	_line(col, str(a.what), roundi(14 * k), UiKit.TEXT_DIM)
	# How far along: a thin bar.
	var bar := ColorRect.new()
	bar.color = Color(1, 1, 1, 0.08)
	bar.custom_minimum_size = Vector2(0, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(bar)
	var fill := ColorRect.new()
	fill.color = DONE if done else UiKit.ACCENT
	fill.mouse_filter = Control.MOUSE_FILTER_PASS
	fill.anchor_right = Achievements.fraction(a)
	fill.anchor_bottom = 1.0
	bar.add_child(fill)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bottom.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(bottom)
	var rewards := _line(bottom, "%s %s" % ["Unlocked:" if done else "Unlocks:", ", ".join(a.rewards.map(Achievements.item_name))], roundi(14 * k),
		UiKit.CYAN if done else Color(UiKit.CYAN, 0.6))
	rewards.name = "rewards"
	rewards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in a.rewards:   # the cards and icons it unlocks, drawn
		if str(item).begins_with("card:") or str(item).begins_with("icon:"):
			bottom.add_child(Thumb.new(item, done))
	return card


## Race medals: a card for every course with your best time, the medal it earned,
## and the bronze, silver and gold times.
static func medals() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "medals"
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for course in Achievements.MEDALS:
		var best := Achievements.best_time(course)
		var tier := Achievements.medal(course, best)
		var card := PanelContainer.new()
		card.name = course
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := UiKit.cut_box(Color(1, 1, 1, 0.04), 8, 14, 9)
		box.border_width_left = 3
		box.border_color = MEDAL_COLORS[tier] if tier >= 0 else Color(UiKit.LINE, 0.5)
		card.add_theme_stylebox_override("panel", box)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		card.add_child(col)
		var top := HBoxContainer.new()
		col.add_child(top)
		var title := UiKit.label(top, Maps.name_of(course), false, 17)
		title.add_theme_font_override("font", HudStyle.font(true))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mine := UiKit.label(top, "%s  %s" % [Achievements.MEDAL_NAMES[tier].to_upper(), Race.format_time(best)] if tier >= 0
			else (Race.format_time(best) if best > 0.0 else "NO TIME YET"), false, 13)
		mine.name = "best"
		mine.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.clip_text = true
		mine.add_theme_color_override("font_color", MEDAL_COLORS[tier] if tier >= 0 else UiKit.TEXT_DIM)
		var times := HBoxContainer.new()
		times.add_theme_constant_override("separation", 14)
		col.add_child(times)
		for i in 3:
			var t := UiKit.label(times, "%s %s" % [Achievements.MEDAL_NAMES[i].capitalize(), Race.format_time(Achievements.MEDALS[course][i])], false, 14)
			t.autowrap_mode = TextServer.AUTOWRAP_OFF
			t.add_theme_color_override("font_color", MEDAL_COLORS[i] if tier >= i else Color(MEDAL_COLORS[i], 0.55))
		row.add_child(card)
	return row


## One line of text that is cut short, not wrapped, if the card is narrow.
static func _line(parent: Node, text: String, size: int, color: Color, clip: bool = true) -> Label:
	var l := UiKit.label(parent, text, false, size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = clip
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if clip else TextServer.OVERRUN_NO_TRIMMING
	l.tooltip_text = text
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l
