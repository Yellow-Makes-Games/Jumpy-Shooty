class_name AchievementsPanel
extends GridContainer
## The Achievements page's body (main menu > Achievements): a card for every
## achievement with what to do, how far along you are, and what it unlocks in the
## Character Creator. The ones you have done are lit. The page (MenuFrame) scrolls.

const COLUMNS := 3
const DONE := Color(0.45, 0.95, 0.5)


func _init() -> void:
	columns = COLUMNS
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("v_separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for a in Achievements.LIST:
		add_child(_card(a))


func _card(a: Dictionary) -> PanelContainer:
	var done := Achievements.done(a.id)
	var card := PanelContainer.new()
	card.name = a.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiKit.cut_box(Color(DONE, 0.07) if done else Color(1, 1, 1, 0.04), 8, 14, 9)
	box.border_width_left = 3
	box.border_color = DONE if done else Color(UiKit.LINE, 0.5)
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var title := _line(top, str(a.name), 17, Color.WHITE if done else UiKit.TEXT)
	title.add_theme_font_override("font", HudStyle.font(true))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line(top, "DONE" if done else Achievements.progress_text(a), 13, DONE if done else UiKit.TEXT_DIM, false).name = "progress"
	_line(col, str(a.what), 14, UiKit.TEXT_DIM)
	# How far along: a thin bar.
	var bar := ColorRect.new()
	bar.color = Color(1, 1, 1, 0.08)
	bar.custom_minimum_size = Vector2(0, 4)
	col.add_child(bar)
	var fill := ColorRect.new()
	fill.color = DONE if done else UiKit.ACCENT
	fill.anchor_right = clampf(float(Achievements.stat(a.stat)) / float(a.goal), 0.0, 1.0)
	fill.anchor_bottom = 1.0
	bar.add_child(fill)
	_line(col, "%s %s" % ["Unlocked:" if done else "Unlocks:", ", ".join(a.rewards.map(Achievements.item_name))], 14,
		UiKit.CYAN if done else Color(UiKit.CYAN, 0.6)).name = "rewards"
	return card


## One line of text that is cut short, not wrapped, if the card is narrow.
func _line(parent: Node, text: String, size: int, color: Color, clip: bool = true) -> Label:
	var l := UiKit.label(parent, text, false, size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = clip
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if clip else TextServer.OVERRUN_NO_TRIMMING
	l.tooltip_text = text
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l
