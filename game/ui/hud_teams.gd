class_name HudTeams
extends RefCounted
## The team modes' overlay (see Teams). Hud owns one and draws it in place of the
## free-for-all score bar:
##  - up top, Red's score and Blue's either side of the clock (the round clock, or the
##    bomb's fuse in red once it is planted; the match clock in Capture the Flag), and
##    a line under it saying what your team is doing;
##  - markers over the objectives, wherever they are on screen: the bomb sites, the
##    bomb, both flags (with how far away they are);
##  - a bar while you plant or defuse, and "hold G to plant" when you could;
##  - a banner when something happens: a plant, a defuse, a round won, a flag taken,
##    dropped, returned or captured.

const BANNER_TIME := 2.6

var _banner := {}    # {text, sub, color, age}


func _init() -> void:
	Teams.event.connect(_on_event)


func _on_event(kind: String, team: int, who: int) -> void:
	var me := Net.my_id()
	var mine := Teams.team_of(me)
	var name := Net.player_name(who) if who != 0 else ""
	var you := who == me
	var text := ""
	var sub := ""
	var col := Teams.team_color(team)
	match kind:
		"bomb_planted":
			text = "BOMB PLANTED"
			sub = "SITE %s  ·  %d SECONDS" % [Teams.site_letter(Teams.bomb_site), int(Teams.FUSE)]
			Sound.play("lever_down", 4.0)
		"bomb_defused":
			text = "BOMB DEFUSED"
			sub = "BY YOU" if you else "BY %s" % name.to_upper()
			Sound.play("lever_up", 4.0)
		"bomb_dropped":
			if mine == team:
				text = "BOMB DROPPED"
				sub = "PICK IT UP"
		"bomb_taken":
			if you:
				text = "YOU HAVE THE BOMB"
				sub = "HOLD %s ON SITE A OR B TO PLANT" % Settings.action_text("interact").to_upper()
				Sound.play("ui_confirm")
		"round_won":
			text = "%s WINS THE ROUND" % Teams.team_name(team).to_upper()
			sub = {"eliminated": "ELIMINATED THE OTHER TEAM", "time": "TIME RAN OUT", "exploded": "THE BOMB WENT OFF",
				"defused": "THE BOMB WAS DEFUSED"}.get(Teams.round_reason, "")
			sub += "  ·  %d - %d" % [Teams.score[0], Teams.score[1]]
			Sound.play("match_end" if team == mine else "ui_back", 0.0)
		"round_start":
			text = "ROUND %d" % Teams.round_number
			sub = "ATTACK: PLANT THE BOMB" if mine == Teams.attackers() else "DEFEND SITES A AND B"
			if Teams.round_number == Teams.HALF + 1:
				sub = "SIDES SWAPPED  ·  " + sub
			col = HudStyle.WHITE
			Sound.play("match_start")
		"flag_taken":
			text = "YOU HAVE THE FLAG" if you else ("OUR FLAG IS TAKEN" if team == mine else "%s HAS THEIR FLAG" % name.to_upper())
			sub = "BRING IT TO YOUR FLAG" if you else ""
			col = Teams.team_color(Teams.team_of(who))
			Sound.play("ui_confirm" if Teams.team_of(who) == mine else "ui_back")
		"flag_dropped":
			text = "%s FLAG DROPPED" % Teams.team_name(team).to_upper()
			sub = "RETURN IT" if team == mine else "PICK IT UP"
		"flag_returned":
			text = "%s FLAG RETURNED" % Teams.team_name(team).to_upper()
		"flag_captured":
			text = "%s SCORES" % Teams.team_name(team).to_upper()
			sub = "%s CAPTURED THE FLAG  ·  %d - %d" % ["YOU" if you else name.to_upper(), Teams.score[0], Teams.score[1]]
			Sound.play("kill_head" if team == mine else "ui_back", 2.0)
	if text != "":
		_banner = {"text": text, "sub": sub, "color": col, "age": 0.0}


func age(delta: float) -> void:
	if not _banner.is_empty():
		_banner.age += delta
		if _banner.age > BANNER_TIME:
			_banner = {}


## The score bar and what your team is doing (also while you are dead or watching).
func draw_bar(ci: CanvasItem, size: Vector2, hud: Hud) -> void:
	var cx := size.x * 0.5
	var y := 38.0
	var me := Net.my_id()
	var mine := Teams.team_of(me)
	var snd := Teams.is_snd()
	var clock := ""
	var clock_col := HudStyle.WHITE
	if snd:
		var t := Teams.round_left
		if Teams.phase == Teams.Phase.PLANTED:
			t = Teams.fuse_left
			clock_col = HudStyle.RED
		elif Teams.phase == Teams.Phase.OVER:
			t = Teams.over_left
		clock = "%d:%02d" % [int(ceil(t)) / 60, int(ceil(t)) % 60]
	else:
		var t := int(ceil(Match.time_left)) if Match.time_left < 1e8 else 0
		clock = "%d:%02d" % [t / 60, t % 60]
	var mid_w := hud.pill(ci, Vector2(cx, y), clock, 28, clock_col)
	var gap := mid_w * 0.5 + 10.0
	for t in 2:
		var s := "%s %d" % [Teams.NAMES[t].to_upper(), Teams.score[t]] if t == 0 else "%d %s" % [Teams.score[t], Teams.NAMES[t].to_upper()]
		var w := HudStyle.text_width(s, 22) + 32.0
		var at := Vector2(cx - gap - w * 0.5, y) if t == 0 else Vector2(cx + gap + w * 0.5, y)
		hud.pill(ci, at, s, 22, Teams.team_color(t))
		if t == mine:
			HudStyle.label(ci, at + Vector2(0, -26), "YOUR TEAM", 9, Color(Teams.team_color(t), 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	var sub := ""
	if snd:
		sub = "ROUND %d  ·  FIRST TO %d" % [Teams.round_number, Teams.ROUNDS_TO_WIN]
		if mine >= 0:
			sub += "  ·  " + ("ATTACKING" if mine == Teams.attackers() else "DEFENDING")
		if Teams.phase == Teams.Phase.PLANTED:
			sub = "BOMB PLANTED AT %s  ·  " % Teams.site_letter(Teams.bomb_site) + ("DEFUSE IT" if mine == Teams.defenders() else "PROTECT IT")
		var alive := [0, 0]
		for t in 2:
			for id in Teams.members(t):
				if Match.is_alive(id):
					alive[t] += 1
		sub += "  ·  %d V %d ALIVE" % [alive[0], alive[1]]
	else:
		sub = "CAPTURE THE FLAG  ·  FIRST TO %d" % Teams.CAPTURES_TO_WIN
		if mine >= 0:
			var theirs: Dictionary = Teams.flags[1 - mine] if Teams.flags.size() == 2 else {}
			var ours: Dictionary = Teams.flags[mine] if Teams.flags.size() == 2 else {}
			if Teams.flag_carried_by(me) >= 0:
				sub = "YOU HAVE THE FLAG  ·  BRING IT HOME" + ("" if int(ours.get("state", 0)) == Teams.Flag.HOME else "  ·  YOUR FLAG MUST BE HOME TO SCORE")
			elif int(ours.get("state", 0)) == Teams.Flag.CARRIED:
				sub = "YOUR FLAG IS TAKEN  ·  STOP %s" % Net.player_name(int(ours.carrier)).to_upper()
			elif int(ours.get("state", 0)) == Teams.Flag.DROPPED:
				sub = "YOUR FLAG IS DROPPED  ·  WALK OVER IT TO RETURN IT  ·  %d S" % ceili(float(ours.left))
			elif int(theirs.get("state", 0)) == Teams.Flag.CARRIED:
				sub = "%s HAS THEIR FLAG  ·  COVER THEM" % Net.player_name(int(theirs.carrier)).to_upper()
			else:
				sub += "  ·  TAKE THE %s FLAG" % Teams.NAMES[1 - mine].to_upper()
	HudStyle.label(ci, Vector2(cx, y + 34.0), sub, 10, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)


## Markers, the plant / defuse bar, prompts and banners (not while dead).
func draw_play(ci: CanvasItem, size: Vector2) -> void:
	var me := Net.my_id()
	var mine := Teams.team_of(me)
	var cam := ci.get_viewport().get_camera_3d()
	if cam:
		if Teams.is_snd():
			for i in Teams.sites.size():
				var planted := Teams.phase == Teams.Phase.PLANTED and Teams.bomb_site == i
				_marker(ci, cam, size, Teams.sites[i] + Vector3(0, 2.2, 0), Teams.site_letter(i),
					HudStyle.RED if planted else Color(1.0, 0.78, 0.3), planted)
			var bomb := Teams.bomb_position()
			if bomb != Vector3.INF and Teams.bomb_carrier != me and Teams.phase != Teams.Phase.OVER:
				if Teams.phase == Teams.Phase.PLANTED or mine == Teams.attackers():
					# Attackers always see it: on the floor, planted, or over the teammate carrying it.
					var at := bomb + Vector3(0, 0.8, 0)
					if Teams.bomb_carrier != 0:
						at = bomb + Vector3(0, 2.5, 0)
					_marker(ci, cam, size, at, "BOMB", HudStyle.RED, Teams.phase == Teams.Phase.PLANTED)
		else:
			for t in 2:
				if Teams.flag_carried_by(me) == t:
					continue
				var at := Teams.flag_position(t)
				if at == Vector3.INF:
					continue
				var state := int(Teams.flags[t].state) if t < Teams.flags.size() else 0
				var word := "FLAG" if state == Teams.Flag.HOME else ("TAKEN" if state == Teams.Flag.CARRIED else "DROPPED")
				_marker(ci, cam, size, at + Vector3(0, 2.8, 0), word, Teams.team_color(t), state != Teams.Flag.HOME)
			if mine >= 0 and Teams.flag_carried_by(me) >= 0:
				_marker(ci, cam, size, Teams.flag_home(mine) + Vector3(0, 2.8, 0), "HOME", Teams.team_color(mine), true)
	var c := size * 0.5
	if Teams.holder == me and Teams.holder != 0:
		var w := 300.0
		var r := Rect2(c.x - w * 0.5, c.y + 96.0, w, 10.0)
		HudStyle.label(ci, Vector2(c.x, r.position.y - 14.0), "DEFUSING" if Teams.phase == Teams.Phase.PLANTED else "PLANTING", 12,
			HudStyle.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		ci.draw_rect(r, Color(0, 0, 0, 0.5))
		ci.draw_rect(Rect2(r.position, Vector2(w * clampf(Teams.hold_progress, 0.0, 1.0), r.size.y)), HudStyle.ORANGE)
	elif Teams.is_snd() and Match.is_alive(me):
		var key := Settings.action_text("interact").to_upper()
		var p: Player = Net.arena.get_player(me) if Net.arena else null
		if p and Teams.phase == Teams.Phase.LIVE and Teams.bomb_carrier == me and Teams.site_at(p.global_position) >= 0:
			HudStyle.label(ci, Vector2(c.x, c.y + 100.0), "HOLD %s TO PLANT" % key, 13, HudStyle.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
		elif p and Teams.phase == Teams.Phase.PLANTED and mine == Teams.defenders() and p.global_position.distance_to(Teams.bomb_pos) <= Teams.BOMB_REACH + 0.5:
			HudStyle.label(ci, Vector2(c.x, c.y + 100.0), "HOLD %s TO DEFUSE" % key, 13, HudStyle.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
		elif Teams.bomb_carrier == me and Teams.phase == Teams.Phase.LIVE:
			HudStyle.label(ci, Vector2(c.x, size.y - 128.0), "YOU HAVE THE BOMB", 11,
				Color(HudStyle.RED, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	draw_banner(ci, size)


func draw_banner(ci: CanvasItem, size: Vector2) -> void:
	if _banner.is_empty():
		return
	var t: float = _banner.age
	var a := clampf((BANNER_TIME - t) / 0.4, 0.0, 1.0) * clampf(t / 0.1, 0.0, 1.0)
	var y := size.y * 0.27
	var col: Color = _banner.color
	HudStyle.text(ci, Vector2(size.x * 0.5, y), _banner.text, 34, Color(col.lightened(0.2), a), HORIZONTAL_ALIGNMENT_CENTER)
	if _banner.sub != "":
		HudStyle.label(ci, Vector2(size.x * 0.5, y + 32.0), _banner.sub, 12, Color(1, 1, 1, 0.85 * a), HORIZONTAL_ALIGNMENT_CENTER)


## A diamond over a spot in the world with a word and the distance; kept on screen at
## the edges when the spot is off to the side or behind you.
func _marker(ci: CanvasItem, cam: Camera3D, size: Vector2, at: Vector3, word: String, col: Color, pulse: bool) -> void:
	var local := cam.global_transform.affine_inverse() * at
	var p := size * 0.5
	if local.z < -0.1:
		p = cam.unproject_position(at)
	else:   # behind you (or level with the lens): at the bottom edge, on the side it is on
		p = Vector2(size.x * 0.5 + signf(local.x) * size.x, size.y - 60.0)
	var margin := 40.0
	p = Vector2(clampf(p.x, margin, size.x - margin), clampf(p.y, 90.0, size.y - margin))
	var alpha := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008) if pulse else 0.9
	var r := 9.0
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	ci.draw_colored_polygon(pts, Color(col, 0.35 * alpha))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(col, alpha), 2.0)
	HudStyle.label(ci, p + Vector2(0, -20), word, 11, Color(col.lightened(0.3), alpha), HORIZONTAL_ALIGNMENT_CENTER)
	var d := cam.global_position.distance_to(at)
	HudStyle.label(ci, p + Vector2(0, 20), "%d M" % roundi(d), 9, Color(1, 1, 1, 0.7 * alpha), HORIZONTAL_ALIGNMENT_CENTER)
