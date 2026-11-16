class_name HudArcs
extends RefCounted
## "Twin arcs" HUD layout: everything about you sits around the crosshair, so you
## never look away from the middle of the screen while moving fast.
## Left arc: health (fills from the bottom; a red chunk shows what you just lost).
## Right arc: one tick per round in the magazine (fills orange while reloading).
## Under the crosshair: four short arcs for grapple, dive, flip and slide boost,
## then your speed and what you are doing.

const R := 92.0           ## radius of the health and ammo arcs
const SPAN := 70.0        ## degrees each of them covers
const MOVES_R := 50.0


static func draw(ci: CanvasItem, c: Vector2, v: Hud.View) -> void:
	# Health, left: from 145 deg (lower left) up to 215 deg (upper left).
	var lo := 180.0 - SPAN * 0.5
	var hp_col := HudStyle.health_color(v.hp)
	HudStyle.edged_arc(ci, c, R, lo, lo + SPAN, HudStyle.DIM, 7.0)
	var hp_a := SPAN * clampf(v.hp / Match.MAX_HEALTH, 0.0, 1.0)
	var trail_a := SPAN * clampf(v.hp_trail / Match.MAX_HEALTH, 0.0, 1.0)
	if trail_a > hp_a:
		HudStyle.arc(ci, c, R, lo + hp_a, lo + trail_a, Color(HudStyle.RED, 0.85), 7.0)
	HudStyle.arc(ci, c, R, lo, lo + hp_a, hp_col, 7.0)
	HudStyle.text(ci, c + Vector2(-R - 16.0, 0), str(ceili(v.hp)), 22, hp_col, HORIZONTAL_ALIGNMENT_RIGHT)

	# Ammo, right: rounds from 35 deg (lower right) up to -35 deg (upper right).
	var n := clampi(v.magazine, 1, 30)
	var step := SPAN / n
	var bottom := SPAN * 0.5
	for i in n:
		var a0 := bottom - i * step - 0.8
		var a1 := a0 - step + 1.6
		var on := i < v.ammo and not v.reloading
		HudStyle.edged_arc(ci, c, R, a1, a0, HudStyle.WHITE if on else HudStyle.DIM, 7.0)
	if v.reloading:
		HudStyle.arc(ci, c, R, bottom - SPAN * v.reload, bottom, HudStyle.ORANGE, 7.0)
		HudStyle.text(ci, c + Vector2(R + 16.0, 0), "RELOAD", 14, HudStyle.ORANGE)
	else:
		var w := HudStyle.text(ci, c + Vector2(R + 16.0, 0), str(v.ammo), 22, HudStyle.WHITE)
		HudStyle.text(ci, c + Vector2(R + 18.0 + w, 3), "/%d" % v.magazine, 13, Color(1, 1, 1, 0.65))

	# Moves, under the crosshair: grapple, dive, flip, slide (left to right).
	for i in v.moves.size():
		var m: Array = v.moves[i]
		var ready: float = m[2]
		var a0 := 122.0 - i * 16.0      # angles grow clockwise, so go right to left
		var a1 := a0 - 13.0
		HudStyle.edged_arc(ci, c, MOVES_R, a1, a0, HudStyle.DIM, 4.0)
		var col := HudStyle.WHITE
		if m[3]:
			col = HudStyle.ORANGE
		elif i == 0 and ready >= 1.0:
			col = HudStyle.CYAN
		elif ready < 1.0:
			col = Color(1, 1, 1, 0.55)
		HudStyle.arc(ci, c, MOVES_R, a0 - 13.0 * ready, a0, col, 4.0)

	var speed := "%.1f m/s  ·  %s" % [v.speed, v.move_state]
	HudStyle.text(ci, c + Vector2(0, 74), speed, 14, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
