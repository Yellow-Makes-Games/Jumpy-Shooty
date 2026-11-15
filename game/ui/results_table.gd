class_name ResultsTable
## Rankings table used by the Tab scoreboard and the results screen.


static func build(parent: Control, rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for h in ["#", "Player", "Kills", "Deaths"]:
		var l := UiKit.label(grid, h, true, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var rank := 0
	for row in rows:
		rank += 1
		var me: bool = row.id == Net.my_id()
		var cells := [str(rank), row.name, str(row.kills), str(row.deaths)]
		for i in cells.size():
			var l := UiKit.label(grid, cells[i], false, 22 if rank == 1 else 20)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			if i == 1:
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if me:
				l.add_theme_color_override("font_color", UiKit.ACCENT)
