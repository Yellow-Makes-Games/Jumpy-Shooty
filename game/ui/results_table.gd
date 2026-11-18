class_name ResultsTable
## Rankings for the results screen: one card per player, best first, with their
## colour, robot, kills and deaths. Your row is tinted orange; the winner's number is gold.

const GOLD := Color(1.0, 0.82, 0.3)


static func build(parent: Control, rows: Array) -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	parent.add_child(list)
	if not rows.is_empty() and rows[0].get("race", false):
		_build_race(list, rows)
		return
	var killcam: bool = rows[0].get("killcam", false) if not rows.is_empty() else false   # (from the results: the lobby may have moved on)
	var head := _row(list, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	for h in [["", 34], ["PLAYER", 0], ["WEAPON #" if GunGame.active() else ("POINTS" if killcam else "KILLS"), 120 if killcam else 70], ["DEATHS", 70]]:
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
		var about := Characters.name_of(Net.player_character(row.id))
		var bonus := int(row.get("bonus", 0))
		if killcam:
			about += "  ·  %d kill%s" % [row.kills, "" if row.kills == 1 else "s"]
			if bonus > 0:
				about += "  ·  #1 killcam +%s" % KillcamMode.format(bonus)
		_cell(who, about, 13, GOLD if bonus > 0 else UiKit.TEXT_DIM, false)
		var score := ("%d/%d" % [mini(int(row.get("level", 0)) + 1, GunGame.steps()), GunGame.steps()]) \
			if GunGame.active() else (KillcamMode.format(int(row.get("points", 0))) if killcam else str(row.kills))
		_cell(card, score, 26, GOLD if rank == 1 else Color.WHITE, true, 120 if killcam else 70)
		_cell(card, str(row.deaths), 20, UiKit.TEXT_DIM, false, 70)


## A race: place, racer, time (or DNF and how many gates), resets.
static func _build_race(list: VBoxContainer, rows: Array) -> void:
	var head := _row(list, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	for h in [["", 34], ["RACER", 0], ["TIME", 110], ["RESETS", 70]]:
		var l := _cell(head, h[0], 12, UiKit.TEXT_DIM, false, h[1])
		if h[0] == "RACER":
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rank := 0
	var best := -1.0
	for row in rows:
		rank += 1
		var me: bool = row.id == Net.my_id()
		var card := _row(list, Color(UiKit.ACCENT, 0.14) if me else Color(1, 1, 1, 0.05), Net.player_color(row.id))
		_cell(card, str(rank) if row.finished else "–", 22, GOLD if rank == 1 and row.finished else UiKit.TEXT_DIM, true, 34)
		var who := VBoxContainer.new()
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_theme_constant_override("separation", -2)
		card.add_child(who)
		_cell(who, row.name + ("  (you)" if me else ""), 20, Color.WHITE, true)
		var gates: String = "all %d gates" % Race.gates if row.finished else "%d of %d gates" % [row.cp, Race.gates]
		_cell(who, "%s  ·  %s" % [Characters.name_of(Net.player_character(row.id)), gates], 13, UiKit.TEXT_DIM, false)
		var time_s := "DNF"
		if row.finished:
			time_s = Race.format_time(row.time)
			if best < 0.0:
				best = row.time
			elif row.time > best:
				time_s = "+%.2f" % (row.time - best)
		_cell(card, time_s, 24 if row.finished else 18, (GOLD if rank == 1 else Color.WHITE) if row.finished else UiKit.TEXT_DIM, true, 110)
		_cell(card, str(row.resets), 20, UiKit.TEXT_DIM, false, 70)


static func _row(list: Node, bg: Color, stripe: Color) -> HBoxContainer:
	var p := PanelContainer.new()
	var s := UiKit.cut_box(bg, 9, 16, 7)
	s.border_width_left = 5
	s.border_color = stripe
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
