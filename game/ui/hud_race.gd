class_name HudRace
extends RefCounted
## The race overlay: the clock, your place and gates up top, the 3-2-1-GO
## countdown, a popup for each checkpoint (with your split), a flash when you are
## sent back, the finish banner, the "race ends in" warning once someone has
## finished, and a short standings list down the left. Hud owns one and draws it
## in place of the score bar and kill feed.

const SPLIT_TIME := 2.2
const BACK_TIME := 1.4

var _split := {}      # {number, time, finished, place, age}
var _back := {}       # {reason, age}
var _go := 0.0        # counts up after GO! shows


func _init() -> void:
	Race.gate_passed.connect(_on_gate)
	Race.sent_back.connect(_on_back)


func _on_gate(id: int, number: int, at: float, done: bool) -> void:
	if id != Net.my_id():
		return
	_split = {"number": number, "time": at, "finished": done, "place": Race.place(id), "age": 0.0}


func _on_back(id: int, reason: String) -> void:
	if id == Net.my_id():
		_back = {"reason": reason, "age": 0.0}


func age(delta: float) -> void:
	if not _split.is_empty():
		_split.age += delta
		if _split.age > SPLIT_TIME and not _split.finished:
			_split = {}
	if not _back.is_empty():
		_back.age += delta
		if _back.age > BACK_TIME:
			_back = {}
	if not Race.frozen():
		_go += delta


## The white-out while you are put back (also covers the jump to the gate).
func flash() -> float:
	if _back.is_empty():
		return 0.0
	var t: float = _back.age
	return clampf(1.0 - absf(t - 0.35) / 0.35, 0.0, 1.0) * 0.55 if t < 0.7 else 0.0


func draw(ci: CanvasItem, size: Vector2, hud: Hud) -> void:
	var me := Net.my_id()
	var cx := size.x * 0.5
	var y := 38.0
	var done := Race.finished(me)
	var shown := Race.finish_time(me) if done else maxf(Race.time, 0.0)
	var clock_w := hud.pill(ci, Vector2(cx, y), Race.format_time(shown), 28, HudStyle.ORANGE if done else HudStyle.WHITE)
	var gap := clock_w * 0.5 + 10.0
	var racers := Race.progress.size()
	var place_s := "%s / %d" % [Race.ordinal(Race.place(me)), racers] if racers > 1 else "SOLO"
	hud.pill(ci, Vector2(cx - gap - (HudStyle.text_width(place_s, 22) + 28.0) * 0.5, y), place_s, 22, HudStyle.ORANGE)
	var gates_s := "GATE %d / %d" % [mini(Race.gates_passed(me), Race.gates), Race.gates]
	hud.pill(ci, Vector2(cx + gap + (HudStyle.text_width(gates_s, 22) + 28.0) * 0.5, y), gates_s, 22, HudStyle.WHITE)
	HudStyle.text(ci, Vector2(cx, y + 32.0), Maps.name_of(Net.map_id()).to_upper() + "  ·  RACE", 12, Color(1, 1, 1, 0.75),
		HORIZONTAL_ALIGNMENT_CENTER, false)
	if Race.end_at < INF and not done:
		var left := maxi(int(ceil(Race.end_at - Race.time)), 0)
		var pulse := 0.75 + 0.25 * sin(Race.time * 6.0)
		HudStyle.text(ci, Vector2(cx, y + 58.0), "RACE ENDS IN %d" % left, 20, Color(HudStyle.RED, pulse), HORIZONTAL_ALIGNMENT_CENTER)

	_draw_standings(ci, size)
	_draw_countdown(ci, size)
	_draw_split(ci, size)
	_draw_back(ci, size)
	if not done and not Race.frozen():
		HudStyle.text(ci, Vector2(cx, size.y - 22.0), "R  BACK TO CHECKPOINT", 12, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, false)


## Left edge: everyone in order, you highlighted; finishers show their time.
func _draw_standings(ci: CanvasItem, size: Vector2) -> void:
	var rows := Race.standings()
	if rows.size() < 2:
		return
	var x := 22.0
	var y := size.y * 0.32
	var me := Net.my_id()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var mine: bool = row.id == me
		var right: String = Race.format_time(row.time) if row.finished else "%d/%d" % [row.cp, Race.gates]
		var name_s: String = "YOU" if mine else String(row.name).get_slice(" (", 0).to_upper()   # bots: drop the "(Hard)"
		var w := 196.0
		HudStyle.plate(ci, Rect2(x, y - 13.0, w, 26.0), 3.0, Color(HudStyle.ORANGE, 0.28) if mine else HudStyle.PANEL)
		ci.draw_rect(Rect2(x, y - 13.0, 3.0, 26.0), Net.player_color(row.id))
		HudStyle.text(ci, Vector2(x + 12.0, y), str(i + 1), 14, Color(1, 1, 1, 0.6))
		HudStyle.text(ci, Vector2(x + 32.0, y), name_s.left(12), 14, HudStyle.ORANGE if mine else HudStyle.WHITE)
		HudStyle.text(ci, Vector2(x + w - 10.0, y), right, 13, HudStyle.YELLOW if row.finished else Color(1, 1, 1, 0.75),
			HORIZONTAL_ALIGNMENT_RIGHT)
		y += 30.0


func _draw_countdown(ci: CanvasItem, size: Vector2) -> void:
	var c := size * 0.5 + Vector2(0, -90)
	if Race.frozen():
		var left: float = -Race.time   # 3..0
		var n := int(ceil(left))
		var frac: float = left - floor(left)
		var scale: float = 1.0 + 0.35 * frac
		var col := HudStyle.YELLOW if n > 1 else HudStyle.ORANGE
		HudStyle.text(ci, c, str(maxi(n, 1)), int(96 * scale), Color(col, 0.4 + 0.6 * frac), HORIZONTAL_ALIGNMENT_CENTER)
		HudStyle.text(ci, c + Vector2(0, 70), "GET READY", 16, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, false)
	elif _go < 0.9 and Race.time < 1.5:
		var a := clampf(1.0 - (_go - 0.5) / 0.4, 0.0, 1.0)
		HudStyle.text(ci, c, "GO!", int(110 + 30 * _go), Color(HudStyle.CYAN, a), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_split(ci: CanvasItem, size: Vector2) -> void:
	if _split.is_empty():
		return
	var c := Vector2(size.x * 0.5, size.y * 0.5 - 150.0)
	if _split.finished:
		var w := 520.0
		var card := Rect2(c.x - w * 0.5, c.y - 54.0, w, 108.0)
		HudStyle.plate(ci, card, 8.0, Color(0.05, 0.06, 0.08, 0.85))
		ci.draw_rect(Rect2(card.position, Vector2(w, 4)), HudStyle.YELLOW)
		HudStyle.text(ci, c + Vector2(0, -22), "FINISHED  ·  %s PLACE" % Race.ordinal(_split.place).to_upper(), 16, HudStyle.YELLOW,
			HORIZONTAL_ALIGNMENT_CENTER)
		HudStyle.text(ci, c + Vector2(0, 18), Race.format_time(_split.time), 44, HudStyle.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var a := clampf((SPLIT_TIME - _split.age) / 0.4, 0.0, 1.0)
	var label := "CHECKPOINT %d / %d" % [_split.number, Race.gates]
	HudStyle.text(ci, c, label, 22, Color(HudStyle.CYAN, a), HORIZONTAL_ALIGNMENT_CENTER)
	HudStyle.text(ci, c + Vector2(0, 30), Race.format_time(_split.time) + "   ·   " + Race.ordinal(_split.place).to_upper(), 18,
		Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_back(ci: CanvasItem, size: Vector2) -> void:
	if _back.is_empty():
		return
	var why: String = {"fell": "YOU FELL", "hazard": "HAZARD!", "reset": "RESET"}.get(_back.reason, "")
	var a := clampf((BACK_TIME - _back.age) / 0.4, 0.0, 1.0)
	var c := Vector2(size.x * 0.5, size.y * 0.5 + 110.0)
	HudStyle.text(ci, c, why, 26, Color(HudStyle.RED if _back.reason != "reset" else HudStyle.WHITE, a), HORIZONTAL_ALIGNMENT_CENTER)
	HudStyle.text(ci, c + Vector2(0, 28), "BACK TO YOUR LAST CHECKPOINT", 13, Color(1, 1, 1, 0.8 * a), HORIZONTAL_ALIGNMENT_CENTER, false)
