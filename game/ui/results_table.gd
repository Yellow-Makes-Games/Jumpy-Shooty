class_name ResultsTable
## Rankings for the results screen: one card per player, best first, with their
## colour, robot, kills and deaths. Your row is tinted orange; the winner's number is gold.

const GOLD := Color(1.0, 0.82, 0.3)


static func build(parent: Control, rows: Array) -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	parent.add_child(list)
	var head := _row(list, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	for h in [["", 34], ["PLAYER", 0], ["KILLS", 70], ["DEATHS", 70]]:
		var l := _cell(head, h[0], 12, UiKit.TEXT_DIM, false, h[1])
		if h[0] == "PLAYER":
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rank := 0
	for row in rows:
		rank += 1
		var me: bool = row.id == Net.my_id()
		var card := _row(list, Color(UiKit.ACCENT, 0.14) if me else Color(1, 1, 1, 0.05), Net.player_color(row.id))
		_cell(card, str(rank), 22, GOLD if rank == 1 else UiKit.TEXT_DIM, true, 34)
		var who := VBoxContainer.new()
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_theme_constant_override("separation", -2)
		card.add_child(who)
		_cell(who, row.name + ("  (you)" if me else ""), 20, Color.WHITE, true)
		_cell(who, Characters.name_of(Net.player_character(row.id)), 13, UiKit.TEXT_DIM, false)
		_cell(card, str(row.kills), 26, GOLD if rank == 1 else Color.WHITE, true, 70)
		_cell(card, str(row.deaths), 20, UiKit.TEXT_DIM, false, 70)


static func _row(list: Node, bg: Color, stripe: Color) -> HBoxContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(6)
	s.border_width_left = 5
	s.border_color = stripe
	s.content_margin_left = 14
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	list.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	return h


static func _cell(parent: Node, text: String, size: int, color: Color, bold: bool, width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", HudStyle.font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if width >= 70.0 else HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(l)
	return l
