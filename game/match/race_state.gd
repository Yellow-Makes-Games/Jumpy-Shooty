extends Node
## The rules of a race, run by the host. Autoload at /root/Race. A match on a race
## map is a race (see Maps): no guns, just the course.
##
## How it goes: a countdown while everyone waits on the start line, then the clock
## runs. Racers pass the checkpoint gates in order; falling off the course, touching
## a hazard or pressing R puts you back at the last gate you passed. The first racer
## through the finish starts a FINISH_GRACE countdown for everyone else; the race
## ends when that runs out, when everyone has finished, or at the time limit.
##
## Each copy of the game watches its own racer (and the host its bots) and tells the
## host when they pass a gate; the host keeps the official times and tells everyone.

signal changed                                    ## progress or standings changed
signal gate_passed(id: int, number: int, time: float, finished: bool)
signal sent_back(id: int, reason: String)         ## a racer of ours went back to their checkpoint

const COUNTDOWN := 3.0
const FINISH_GRACE := 30.0
const END_DELAY := 2.5          ## seconds between everyone finishing and the results
const GATE_DEPTH := 2.0         ## how thick a gate's trigger is along the course
const RESET_KEY_DELAY := 0.4    ## R: seconds before you are put back (a short fade)

## This match is a race.
var active := false
## Seconds since the start (negative during the countdown).
var time := -COUNTDOWN
## Gates in the course (the last is the finish).
var gates := 0
## id -> {"cp": gates passed, "finish": time or -1, "resets": int, "splits": Array}
var progress := {}
## Race time the race ends at (set when the first racer finishes).
var end_at := INF

var _ended := false
var _all_done_at := INF
var _local := {}    # id -> gates passed, as seen here (ahead of the host's word by a moment)
var _starts := {}   # id -> [position, yaw]: where each of our racers started
var _pending := {}  # id -> [seconds left, reason]: a send-back on its way (after the fade)


func _ready() -> void:
	Net.match_started.connect(_on_match_started)
	Net.players_changed.connect(_on_players_changed)


func _on_match_started() -> void:
	active = Maps.game_of(Net.map_id()) == "race"
	time = -COUNTDOWN
	end_at = INF
	_ended = false
	_all_done_at = INF
	progress.clear()
	_local.clear()
	_starts.clear()
	_pending.clear()
	gates = 0
	if active:
		for id in Net.players:
			progress[id] = _fresh()


func _fresh() -> Dictionary:
	return {"cp": 0, "finish": -1.0, "resets": 0, "splits": []}


func _on_players_changed() -> void:
	if not active:
		return
	for id in Net.players:
		if not progress.has(id):
			progress[id] = _fresh()
	for id in progress.keys():
		if not Net.players.has(id):
			progress.erase(id)
	changed.emit()


## Racers cannot move yet (the countdown).
func frozen() -> bool:
	return active and time < 0.0


func finished(id: int) -> bool:
	return progress.has(id) and float(progress[id].finish) >= 0.0


func gates_passed(id: int) -> int:
	return maxi(int(progress[id].cp) if progress.has(id) else 0, int(_local.get(id, 0)))


func finish_time(id: int) -> float:
	return float(progress[id].finish) if progress.has(id) else -1.0


func resets(id: int) -> int:
	return int(progress[id].resets) if progress.has(id) else 0


# ---------------------------------------------------------------------------
# Every frame: the clock, and watching our own racers

func _physics_process(delta: float) -> void:
	if not active or not Match.running:
		return
	time += delta
	if not Net.arena or not is_instance_valid(Net.arena):
		return
	var layout: MapRoot = Net.arena.layout
	gates = layout.checkpoints.size()
	for p in Net.arena.players_root.get_children():
		var racer := p as Player
		if racer.is_local:
			_track(racer, layout, delta)
	if Net.is_host():
		if time >= end_at:
			_host_end()
		elif time >= _all_done_at:
			_host_end()


## Gates and hazards for one of our racers.
func _track(p: Player, layout: MapRoot, delta: float) -> void:
	var id := p.peer_id
	if not _starts.has(id):
		_starts[id] = [p.global_position, p.input.yaw]
	if _pending.has(id):
		_pending[id][0] -= delta
		if _pending[id][0] <= 0.0:
			var reason: String = _pending[id][1]
			_pending.erase(id)
			_send_back(p, reason)
		return
	if time < 0.0 or Cheats.flying():
		return
	var n := int(_local.get(id, 0))
	var mid := p.global_position + Vector3(0, 0.9, 0)
	if n < layout.checkpoints.size():
		var gate: Dictionary = layout.checkpoints[n]
		if MapCheckpoint.contains(gate.xf, gate.opening, mid, GATE_DEPTH):
			_local[id] = n + 1
			if id == Net.my_id():
				Sound.play("ui_confirm")
			_request_gate(id, n + 1)
	if layout.hazard_at(p.global_position + Vector3(0, 0.25, 0), 0.05) or layout.hazard_at(mid, 0.0) \
			or layout.hazard_at(p.global_position + Vector3(0, 1.5, 0), 0.0):
		send_back(p, "hazard")


## Puts one of our racers back at their last gate: "fell", "hazard" or "reset" (R).
func send_back(p: Player, reason: String) -> void:
	if not active or _pending.has(p.peer_id) or frozen():
		return
	_pending[p.peer_id] = [RESET_KEY_DELAY if reason == "reset" else 0.0, reason]
	if DevArgs.sync_log:
		var at := p.global_position
		print("RACE_BACK %d %s %.1f %.1f %.1f gate=%d t=%.2f clock=%.2f" % [p.peer_id, reason, at.x, at.y, at.z, gates_passed(p.peer_id), time, Net.arena.layout.clock])
	sent_back.emit(p.peer_id, reason)
	if reason != "reset":
		_send_back(p, reason)
		_pending.erase(p.peer_id)


func _send_back(p: Player, _reason: String) -> void:
	var spot := respawn_spot(p.peer_id)
	p.respawn_at(spot[0], spot[1])
	if Net.is_host():
		_host_reset(p.peer_id)
	else:
		_reset_request.rpc_id(1)


## Where racer `id` comes back: just past the last gate they passed, facing on, or
## their place on the start line.
func respawn_spot(id: int) -> Array:
	var n := gates_passed(id)
	var layout: MapRoot = Net.arena.layout if Net.arena else null
	if layout == null or n == 0 or n > layout.checkpoints.size():
		return _starts.get(id, [Vector3.ZERO, 0.0])
	var xf: Transform3D = layout.checkpoints[n - 1].xf
	# Spread racers across the gate a little, so two coming back together are not stacked.
	var ids := Net.players.keys()
	ids.sort()
	var lane := (ids.find(id) % 5 - 2) * 0.8
	var pos := xf * Vector3(lane, 0.2, -2.0)
	var fwd := -xf.basis.z
	return [pos, atan2(-fwd.x, -fwd.z)]


## Where a racer's next gate is (for the HUD arrow and the standings), or INF.
func next_gate_position(id: int) -> Vector3:
	var layout: MapRoot = Net.arena.layout if Net.arena else null
	var n := gates_passed(id)
	if layout == null or n >= layout.checkpoints.size():
		return Vector3.INF
	return (layout.checkpoints[n].xf as Transform3D) * Vector3(0, 1.5, 0)


# ---------------------------------------------------------------------------
# The host keeps the times

func _request_gate(id: int, number: int) -> void:
	if Net.is_host():
		_host_gate(id, number)
	else:
		_gate_request.rpc_id(1, number)


@rpc("any_peer", "call_remote", "reliable")
func _gate_request(number: int) -> void:
	if Net.is_host():
		_host_gate(multiplayer.get_remote_sender_id(), number)


@rpc("any_peer", "call_remote", "reliable")
func _reset_request() -> void:
	if Net.is_host():
		_host_reset(multiplayer.get_remote_sender_id())


func _host_gate(id: int, number: int) -> void:
	if not active or _ended or not progress.has(id) or finished(id):
		return
	var pr: Dictionary = progress[id]
	if number != int(pr.cp) + 1:
		return   # out of order: a gate was skipped
	pr.cp = number
	pr.splits.append(snappedf(time, 0.001))
	var done := number >= gates and gates > 0
	if done:
		pr.finish = snappedf(time, 0.001)
		if end_at == INF:
			end_at = time + FINISH_GRACE
		var everyone := true
		for other in progress:
			if not finished(other):
				everyone = false
		if everyone or Game.mode == Game.Mode.PRACTICE:
			_all_done_at = time + END_DELAY
	_sync.rpc(progress, end_at, time)
	_gate.rpc(id, number, time, done)


func _host_reset(id: int) -> void:
	if progress.has(id) and not _ended:
		progress[id].resets += 1
		_sync.rpc(progress, end_at, time)


@rpc("authority", "call_local", "reliable")
func _sync(new_progress: Dictionary, new_end: float, host_time: float) -> void:
	progress = new_progress
	end_at = new_end
	if not Net.is_host() and absf(host_time - time) > 0.25:
		time = host_time   # keep the clock in step with the host's
	changed.emit()


@rpc("authority", "call_local", "reliable")
func _gate(id: int, number: int, at: float, done: bool) -> void:
	if DevArgs.sync_log:
		print("RACE_GATE %d %d %.2f%s" % [id, number, at, " FINISH" if done else ""])
	if int(_local.get(id, 0)) < number:
		_local[id] = number
	gate_passed.emit(id, number, at, done)


func _host_end() -> void:
	if _ended:
		return
	_ended = true
	Match.host_end_match()


# ---------------------------------------------------------------------------
# Standings

## Everyone, best first: finishers by time, then the rest by gates passed and how
## close they are to their next gate. Rows: {id, name, finished, time, cp, resets,
## kills, deaths} (kills and deaths are 0, for screens that expect them).
func standings() -> Array:
	var rows: Array = []
	for id in progress:
		var dist := 0.0
		var next := next_gate_position(id)
		var p: Player = Net.arena.get_player(id) if Net.arena and is_instance_valid(Net.arena) else null
		if p and next != Vector3.INF:
			dist = p.global_position.distance_to(next)
		rows.append({"id": id, "name": Net.player_name(id), "finished": finished(id), "time": finish_time(id),
			"cp": gates_passed(id), "resets": resets(id), "dist": dist, "kills": 0, "deaths": 0, "race": true})
		rows[-1].merge(Match.looks(id))
	rows.sort_custom(func(a, b):
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.time < b.time
		if a.cp != b.cp:
			return a.cp > b.cp
		return a.dist < b.dist)
	return rows


## Your place right now (1 = leading).
func place(id: int) -> int:
	var rows := standings()
	for i in rows.size():
		if rows[i].id == id:
			return i + 1
	return rows.size()


static func format_time(t: float) -> String:
	if t < 0.0:
		return "--:--.--"
	var m := int(t / 60.0)
	return "%d:%05.2f" % [m, t - m * 60.0]


static func ordinal(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")]
