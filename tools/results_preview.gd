extends SceneTree
## Renders the results page (or just its stage of winners in their victory poses) with
## the game's real renderer, from made-up results, to look at it without playing a
## match. Used by tools/results_preview.sh.
##
##   godot --rendering-driver vulkan --path . --script tools/results_preview.gd -- \
##       --out=DIR [--tag=shot] [--size=1600x900] [--mode=ffa|team|draw|race|late|practice|nobody]
##       [--players=4] [--weapons=rifle,sword,pistol] [--characters=needle,bulwark]
##       [--pose=raise|pump|hip|present] [--stage=900x700] [--kills=3] [--settle]
##       [--flourish] [--at=2.0,4.0] [--frames=N]
##
## --mode: a free-for-all, a team win, a team draw, a race, a race two of them never
## finished (late), a race alone (practice), a match nobody scored in.
## --weapons, --characters: what each has, in the order of the rankings (they go round).
## --pose: the winner's victory pose (otherwise the one Podium picks for these results).
## --stage: only the stage, this big, instead of the whole page.
## --kills: this many best kills listed beside the rankings (the page's widest layout).
## --settle: everyone straight into their poses; --flourish: and into their flourish.
## --at: when to take each picture (seconds); --frames: instead, N pictures in a row
## (frame_0000.png...), for a clip.
##
## (The game's own scripts are loaded by path once the game is up: a tool script is
## compiled before the autoloads they use exist.)

var _out := "."
var _tag := "shot"
var _times: Array = [2.0]
var _frames := 0
var _clock := 0.0
var _shot := 0
var _warm := 6
var _stage: Control      # the stage alone, or null
var _page: Control       # the whole page, or null
var _settle := false
var _flourish := false
var _set_up := false
var _begun := false
var _size := Vector2i(1600, 900)
var _mode := "ffa"
var _players := 4
var _weapons := ["rifle", "sword", "pistol", "shotgun"]
var _characters := ["needle", "bulwark", "kestrel", "templar"]
var _pose := ""
var _stage_size := Vector2.ZERO
var _kills := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--out="): _out = v
		elif arg.begins_with("--tag="): _tag = v
		elif arg.begins_with("--size="): _size = Vector2i(int(v.get_slice("x", 0)), int(v.get_slice("x", 1)))
		elif arg.begins_with("--mode="): _mode = v
		elif arg.begins_with("--players="): _players = int(v)
		elif arg.begins_with("--weapons="): _weapons = Array(v.split(","))
		elif arg.begins_with("--characters="): _characters = Array(arg.substr(13).split(","))
		elif arg.begins_with("--pose="): _pose = v
		elif arg.begins_with("--stage="): _stage_size = Vector2(float(v.get_slice("x", 0)), float(v.get_slice("x", 1)))
		elif arg.begins_with("--kills="): _kills = int(v)
		elif arg == "--settle": _settle = true
		elif arg == "--flourish": _flourish = true
		elif arg.begins_with("--at="): _times = Array(v.split(",")).map(func(s): return float(s))
		elif arg.begins_with("--frames="): _frames = int(v)


## Once the game is up: the made-up match, and the page or the stage.
func _build() -> void:
	root.size = _size
	DisplayServer.window_set_size(_size)
	root.content_scale_size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var back := ColorRect.new()
	back.color = Color(0.035, 0.05, 0.075)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var net: Node = root.get_node("Net")
	var match_state: Node = root.get_node("Match")
	var podium: Script = load("res://game/match/podium.gd")
	if _mode == "practice":
		_players = 1
	net.start_offline("Tester", _characters[0])
	for i in _players - 1:
		net.add_bot(1)
	var ids: Array = net.players.keys()
	var colors: Array = net.PLAYER_COLORS
	var rows: Array = []
	for i in ids.size():
		var id: int = ids[i]
		var row := {"id": id, "name": net.player_name(id), "kills": maxi(12 - i * 3, 0), "deaths": 3 + i * 2, "level": 0, "points": 0,
			"bonus": 0, "killcam": false, "character": _characters[i % _characters.size()],
			"color": (colors[int(net.players[id].color) % colors.size()] as Color).to_html(false), "weapon": _weapons[i % _weapons.size()]}
		match _mode:
			"nobody":
				row.kills = 0
			"team", "draw":
				var team := 0 if i < (ids.size() + 1) / 2 else 1
				var score := [3, 3] if _mode == "draw" else [4, 2]
				row.merge({"team": team, "team_score": score[team], "team_won": _mode == "team" and team == 0, "teams": "snd", "scores": score,
					"color": (Color(0.95, 0.25, 0.2) if team == 0 else Color(0.25, 0.5, 1.0)).to_html(false)}, true)
			"race", "late", "practice":
				var done := _mode != "late" or i == 0
				row.merge({"race": true, "finished": done, "time": 61.25 + i * 4.5 if done else -1.0, "cp": 9 if done else 6 - i, "resets": i, "dist": 12.0 * i})
		rows.append(row)
	match_state.last_results = rows
	match_state.highlights.clear()
	for i in mini(_kills, 3):
		match_state.highlights.append({"killer": ids[i % ids.size()], "victim": ids[(i + 1) % ids.size()], "seq": i, "score": 300 - i * 40})
	var lineup: Array = podium.lineup(rows)
	if _pose != "" and not lineup.is_empty() and int(lineup[0].pose) < int(podium.VICTORIES):
		lineup[0].pose = (podium.NAMES as Array).find(_pose)
	if _stage_size != Vector2.ZERO:
		_stage = load("res://game/ui/results_stage.gd").new(_stage_size)
		_stage.position = Vector2(40, 40)
		_stage.size = _stage_size
		root.add_child(_stage)
		_stage.show_podium(lineup)
	else:
		_page = load("res://game/ui/results_menu.tscn").instantiate()
		root.add_child(_page)
		if _pose != "" and _page._stage:
			_page._stage.show_podium(lineup)


func _process(delta: float) -> bool:
	if _warm > 0:
		_warm -= 1
		return false
	if not _set_up:
		_set_up = true
		_build()
		return false
	if not _begun:
		_begun = true
		var stage = _stage if _stage else _page._stage
		if _page and _page._show:   # (no kills to play here: straight to the page)
			_page._show.done.emit()
		stage.begin()
		if _settle or _flourish:
			stage.settle()
		if _flourish:
			for i in stage.who.size():
				stage.poser(i).flourish_now()
	_clock += delta
	if _frames > 0:
		_save("%s/frame_%04d.png" % [_out, _shot])
		_shot += 1
		return _shot >= _frames
	if _shot < _times.size() and _clock >= _times[_shot]:
		_save("%s/%s_%d.png" % [_out, _tag, _shot])
		_shot += 1
	return _shot >= _times.size()


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	if _stage:
		var k := float(root.size.x) / 1600.0
		image = image.get_region(Rect2i(Vector2i((_stage.position - Vector2(12, 12)) * k), Vector2i((_stage.size + Vector2(24, 24)) * k)))
	image.save_png(path)
	print("saved ", path)
