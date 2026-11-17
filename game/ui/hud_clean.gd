class_name HudClean
extends RefCounted
## "Clean" HUD layout: the classic corners, kept small.
## Bottom left: your moves (grapple, dive, flip, slide boost, rocket boots, kick) above your health.
## Bottom right: ammo with one tick per round. Under the crosshair: speed and
## what you are doing, small and faint.

const MARGIN := 28.0


static func draw(ci: CanvasItem, c: Vector2, v: Hud.View) -> void:
	var size := c * 2.0
	var bottom := size.y - MARGIN

	if v.race:   # a race has no health or ammo: just the moves, a little lower
		bottom += 60.0
	# Health: big number, robot name, ten segments.
	var hp_col := HudStyle.health_color(v.hp)
	if not v.race:
		_draw_health(ci, v, bottom, hp_col)
	_draw_rest(ci, c, v, size, bottom)


static func _draw_health(ci: CanvasItem, v: Hud.View, bottom: float, hp_col: Color) -> void:
	var w := HudStyle.text(ci, Vector2(MARGIN, bottom - 46.0), str(ceili(v.hp)), 52, hp_col)
	HudStyle.text(ci, Vector2(MARGIN + w + 10.0, bottom - 36.0), v.character.to_upper(), 12, Color(1, 1, 1, 0.75))
	for i in 10:
		var seg_hp := (i + 1) * Match.MAX_HEALTH / 10.0
		var col := HudStyle.DIM
		if v.hp >= seg_hp - 5.0:
			col = hp_col
		elif v.hp_trail >= seg_hp - 5.0:
			col = HudStyle.RED
		HudStyle.edged_rect(ci, Rect2(MARGIN + i * 30.0, bottom - 8.0, 27.0, 8.0), col)


static func _draw_rest(ci: CanvasItem, c: Vector2, v: Hud.View, size: Vector2, bottom: float) -> void:
	# Moves: a chip each, with a ring that refills as the move recharges.
	var x := MARGIN - 4.0
	var y := bottom - 100.0
	for i in v.moves.size():
		var m: Array = v.moves[i]
		var ready: float = m[2]
		var label: String = m[0]
		var cw := 34.0 + HudStyle.text_width(label, 11)
		HudStyle.plate(ci, Rect2(x, y - 15.0, cw, 30.0), 3.0)
		var ring_c := Vector2(x + 15.0, y)
		var col := HudStyle.WHITE
		if m[3]:
			col = HudStyle.ORANGE
		elif i == 0 and ready >= 1.0:
			col = HudStyle.CYAN
		HudStyle.arc(ci, ring_c, 10.0, 0, 360, Color(1, 1, 1, 0.18), 3.0)
		HudStyle.arc(ci, ring_c, 10.0, -90, -90 + 360.0 * ready, col, 3.0)
		var text_col := Color(1, 1, 1, 0.95 if ready >= 1.0 else 0.5)
		HudStyle.text(ci, Vector2(x + 30.0, y), label, 11, text_col)
		x += cw + 6.0

	if v.race:
		HudStyle.text(ci, c + Vector2(0, 40), "%s  ·  %.1f m/s" % [v.move_state, v.speed], 13, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		return
	# Ammo: count, magazine, a tick per round, weapon. Melee: the weapon and a swing bar.
	var right := size.x - MARGIN
	if v.melee:
		HudStyle.text(ci, Vector2(right, bottom - 50.0), v.weapon.to_upper(), 40, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		var bar := Rect2(right - 150.0, bottom - 32.0, 150.0, 8.0)
		HudStyle.edged_rect(ci, bar, HudStyle.DIM)
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(v.swing, 0.0, 1.0), bar.size.y)), HudStyle.WHITE if v.swing >= 1.0 else HudStyle.ORANGE)
		HudStyle.text(ci, Vector2(right, bottom - 6.0), "F  KICK" if v.gun == "none" else "LMB  SWING", 12, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_draw_ammo(ci, v, right, bottom)
	var speed := "%s  ·  %.1f m/s" % [v.move_state, v.speed]
	HudStyle.text(ci, c + Vector2(0, 40), speed, 13, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)


static func _draw_ammo(ci: CanvasItem, v: Hud.View, right: float, bottom: float) -> void:
	var ticks := clampi(v.magazine, 1, 30)
	for i in ticks:
		var col := HudStyle.WHITE if i < v.ammo and not v.reloading else HudStyle.DIM
		if v.reloading and i < int(ticks * v.reload):
			col = HudStyle.ORANGE
		var pitch := 9.0 if ticks <= 15 else 6.0   # a 30-round magazine packs its ticks closer
		HudStyle.edged_rect(ci, Rect2(right - (ticks - i) * pitch + 3.0, bottom - 36.0, pitch - 3.0, 16.0), col)
	if v.reloading:
		HudStyle.text(ci, Vector2(right, bottom - 66.0), "RELOADING", 24, HudStyle.ORANGE, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		var mw := HudStyle.text(ci, Vector2(right, bottom - 62.0), "/ %d" % v.magazine, 22, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
		HudStyle.text(ci, Vector2(right - mw - 8.0, bottom - 70.0), str(v.ammo), 52, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	HudStyle.text(ci, Vector2(right, bottom - 6.0), v.weapon.to_upper() + "  ·  R RELOAD", 12, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
