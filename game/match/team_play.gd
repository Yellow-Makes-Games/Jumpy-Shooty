extends Node
## Team modes, run by the host. Autoload at /root/Teams.
##
## Two teams, Red and Blue, on the arena maps:
##  - Search and Destroy ("snd"): rounds with no respawning. One team attacks, the
##    other defends. An attacker carries the bomb: hold interact on bomb site A or B
##    to plant it, and once it is planted the defenders have FUSE seconds to hold
##    interact on it and defuse it. The attackers win a round by blowing up a site or
##    knocking every defender out; the defenders by defusing, by knocking every
##    attacker out before a plant, or when the round clock runs out. The bomb drops
##    where its carrier dies, for another attacker to pick up. Sides swap after HALF
##    rounds; the first team to ROUNDS_TO_WIN rounds wins.
##  - Capture the Flag ("ctf"): each team has a flag at its base. Walk over the other
##    team's flag to take it, and bring it to your own flag (which must be at home) to
##    score. A carrier who dies drops the flag where they fell; walk over your own
##    dropped flag to send it home (it goes home on its own after FLAG_RETURN seconds).
##    Respawns as usual. First to CAPTURES_TO_WIN captures, or the most when the clock
##    runs out (level is a draw).
##
## Teams: the host deals everyone out when the match starts (alternating, so they are
## even, and offline you are always Red) and puts anyone who joins later on the smaller
## team. The team is kept in Net.players ("team"), so it travels with the player list.
## Teammates can't hurt, shove or hook each other (see Match), and wear their team's
## colour (Net.player_color).
##
## Where things are: every copy works the bases, the spawn points of each side and the
## bomb sites out of the map's spawn points (plan_map), the same way, so a map needs
## nothing extra. Side 0 is around one end of the map's longest stretch between two
## spawn points, side 1 around the other end. In Capture the Flag Red's flag is at
## side 0's end and Blue's at side 1's. In Search and Destroy the attackers always
## start on side 0 and the two sites are on side 1, as far apart as they can be.
##
## Each copy says when its own player (and the host its bots) starts or stops holding
## interact; the host decides everything else and tells everyone (_state, _event).

signal changed                                   ## scores, flags, bomb or round changed
signal event(kind: String, team: int, who: int)  ## something happened (for banners and sounds)

const NAMES := ["Red", "Blue"]
const COLORS := [Color(0.96, 0.33, 0.27), Color(0.27, 0.6, 1.0)]
const MODES := ["snd", "ctf"]
const MODE_NAMES := {"snd": "Search and Destroy", "ctf": "Capture the Flag"}

# Search and Destroy
const ROUNDS_TO_WIN := 4
const HALF := 3                 ## sides swap after this many rounds
const ROUND_TIME := 105.0       ## seconds to plant before the defenders win the round
const FUSE := 35.0              ## seconds from the plant to the blast
const PLANT_TIME := 3.0         ## seconds of holding interact on a site
const DEFUSE_TIME := 5.0        ## seconds of holding interact at the bomb
const ROUND_END_TIME := 5.0     ## seconds between one round's end and the next's start
const SITE_RADIUS := 3.6        ## metres (flat) from a site's middle that count as on it
const SITE_HEIGHT := 2.5        ## ...and up or down
const BOMB_REACH := 2.0         ## metres from the bomb to defuse it
const PICKUP_REACH := 1.6       ## metres to pick up the bomb or a flag
const BLAST_RADIUS := 10.0      ## the bomb takes out everyone this close
# Capture the Flag
const CAPTURES_TO_WIN := 3
const CTF_TIME := 12.0 * 60.0   ## seconds
const FLAG_RETURN := 20.0       ## a dropped flag goes home after this long
const CAPTURE_REACH := 2.2      ## metres from your own flag's stand to score

enum Phase { LIVE, PLANTED, OVER }
enum Flag { HOME, CARRIED, DROPPED }

## The two ends of the map (side 0, side 1), the spawn points on each side and the
## bomb sites (A, B). Worked out from the map by every copy (plan_map).
var bases: Array = [Vector3.ZERO, Vector3.ZERO]
var side_spawns: Array = [[], []]
var base_spawns: Array = [[], []]   # per side: the spawn entry at its end of the map (the team gathers around it)
var _formation: Array = [null, null]   # per side, once worked out: the spots around it (see _formation_for)
var sites: Array = []
var map_ready := false

## Rounds won (Search and Destroy) or captures (Capture the Flag), Red then Blue.
var score := [0, 0]
# Search and Destroy (every copy, as the host last said)
var round_number := 1
var phase := Phase.LIVE
var round_left := ROUND_TIME
var fuse_left := 0.0
var over_left := 0.0
var bomb_carrier := 0           ## who has the bomb (0: nobody)
var bomb_pos := Vector3.INF     ## where it lies (dropped) or sits (planted); INF while carried
var bomb_site := -1             ## the site it is planted at
var holder := 0                 ## who is planting or defusing right now
var hold_progress := 0.0        ## 0..1
var round_winner := -1
var round_reason := ""          ## "eliminated", "time", "exploded", "defused"
# Capture the Flag: one per team, {"state": Flag, "carrier": id, "pos": Vector3, "left": seconds}
var flags: Array = []

var _holding := {}              # host: id -> true while they hold interact
var _told := {}                 # every copy: our player or bot -> what we last told the host
var _last_pos := {}             # host: id -> where they were last frame (for someone who leaves)
var _sync_wait := 0.0
var _started := false           # host: the first round (or the flags) are under way


func _ready() -> void:
	Net.match_started.connect(_on_match_started)
	Net.players_changed.connect(_on_players_changed)
	_reset()


# ---------------------------------------------------------------------------
# What is set up

## The team mode the lobby is set to ("snd", "ctf"), or "" for none.
func mode() -> String:
	var m := str(Net.match_settings.get("mode", ""))
	return m if m in MODES and Net.game_kind() == "ffa" else ""


## A team mode is set up (or running). Practice is always on your own.
func active() -> bool:
	return mode() != "" and Game.mode != Game.Mode.PRACTICE


func is_snd() -> bool:
	return active() and mode() == "snd"


func is_ctf() -> bool:
	return active() and mode() == "ctf"


## Search and Destroy: nobody comes back until the next round.
func no_respawn() -> bool:
	return is_snd()


## A player's team (0 Red, 1 Blue), or -1 (not a team mode, or not on one yet).
func team_of(id: int) -> int:
	if not active() or not Net.players.has(id):
		return -1
	return int(Net.players[id].get("team", -1))


## Two different players on the same team: they can't hurt each other.
func same_team(a: int, b: int) -> bool:
	if a == b or a == 0 or b == 0:
		return false
	var t := team_of(a)
	return t >= 0 and t == team_of(b)


func members(team: int) -> Array:
	var out := []
	for id in Net.players:
		if team_of(id) == team:
			out.append(id)
	out.sort()
	return out


func team_name(team: int) -> String:
	return NAMES[team] if team >= 0 and team < 2 else "Nobody"


## The colour a player's robot armour is painted in a team mode (alpha 0: not a team mode).
func paint_for(id: int) -> Color:
	var t := team_of(id)
	return team_color(t).darkened(0.12) if t >= 0 else Color(0, 0, 0, 0)


func team_color(team: int) -> Color:
	return COLORS[team] if team >= 0 and team < 2 else Color.WHITE


## The match clock to set (INF: Search and Destroy runs on rounds).
func match_time() -> float:
	if mode() != "ctf":
		return INF   # Search and Destroy: rounds (--time-limit is the round's length)
	return DevArgs.time_limit if DevArgs.time_limit > 0.0 else CTF_TIME


## Search and Destroy: seconds a round has to plant in (--time-limit sets it, for tests).
func round_time() -> float:
	return DevArgs.time_limit if DevArgs.time_limit > 0.0 else ROUND_TIME


## Search and Destroy: the team attacking this round (Red first, then they swap).
func attackers() -> int:
	return 0 if round_number <= HALF else 1


func defenders() -> int:
	return 1 - attackers()


## The side of the map a team starts on: in Search and Destroy the attackers' side is
## 0; in Capture the Flag a team's side is its number.
func side_of(team: int) -> int:
	if team < 0:
		return 0
	if mode() == "snd":
		return 0 if team == attackers() else 1
	return team


## Where a team's flag stands.
func flag_home(team: int) -> Vector3:
	return bases[clampi(team, 0, 1)]


## The team ahead (-1 when level).
func leader() -> int:
	if score[0] == score[1]:
		return -1
	return 0 if score[0] > score[1] else 1


## The points a team needs to win.
func target() -> int:
	return ROUNDS_TO_WIN if mode() == "snd" else CAPTURES_TO_WIN


## A player is carrying a flag (the other team's): which, or -1.
func flag_carried_by(id: int) -> int:
	for t in flags.size():
		if flags[t].state == Flag.CARRIED and int(flags[t].carrier) == id:
			return t
	return -1


## Where the bomb is: on its carrier, on the ground or planted (INF if nowhere yet).
func bomb_position() -> Vector3:
	if bomb_carrier != 0:
		var p := _player(bomb_carrier)
		return p.global_position if p else Vector3.INF
	return bomb_pos


## Where a flag is right now.
func flag_position(team: int) -> Vector3:
	if team < 0 or team >= flags.size():
		return Vector3.INF
	var f: Dictionary = flags[team]
	match int(f.state):
		Flag.CARRIED:
			var p := _player(int(f.carrier))
			return p.global_position if p else f.pos
		Flag.DROPPED:
			return f.pos
	return flag_home(team)


## The site a spot is on (0 A, 1 B), or -1.
func site_at(pos: Vector3) -> int:
	for i in sites.size():
		var s: Vector3 = sites[i]
		if Vector2(pos.x - s.x, pos.z - s.z).length() <= SITE_RADIUS and absf(pos.y - s.y) <= SITE_HEIGHT:
			return i
	return -1


static func site_letter(i: int) -> String:
	return "A" if i == 0 else "B"


# ---------------------------------------------------------------------------
# The map: bases, sides and sites from its spawn points (the same on every copy)

## {bases: [Vector3, Vector3], sides: [[spawn], [spawn]], sites: [Vector3, Vector3]}.
## `spawns` is MapRoot.spawns ([position, yaw, ...]).
static func plan_map(spawns: Array) -> Dictionary:
	if spawns.is_empty():
		return {"bases": [Vector3(-10, 0, 0), Vector3(10, 0, 0)], "sides": [[], []], "sites": [Vector3(8, 0, -4), Vector3(8, 0, 4)]}
	var best := [0, 0]
	var far := -1.0
	for i in spawns.size():
		for j in range(i + 1, spawns.size()):
			var d := _flat_dist(spawns[i][0], spawns[j][0])
			if d > far + 0.01:
				far = d
				best = [i, j]
	var a: Vector3 = spawns[best[0]][0]
	var b: Vector3 = spawns[best[1]][0]
	var axis := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var half := maxf(axis.length() * 0.5, 0.01)
	axis = axis.normalized() if axis.length() > 0.01 else Vector3.RIGHT
	var mid := (a + b) * 0.5
	var sides := [[], []]
	var along := []   # each spawn's place between the ends: -1 at side 0's, 1 at side 1's
	for s in spawns:
		var t := Vector3(s[0].x - mid.x, 0.0, s[0].z - mid.z).dot(axis) / half
		along.append(t)
		if t < -0.15:
			sides[0].append(s)
		elif t > 0.15:
			sides[1].append(s)
	if sides[0].is_empty() or sides[1].is_empty():
		sides = [[], []]
		for i in spawns.size():
			sides[0 if along[i] < 0.0 else 1].append(spawns[i])
	if sides[0].is_empty():
		sides[0].append(spawns[best[0]])
	if sides[1].is_empty():
		sides[1].append(spawns[best[1]])
	# The sites: two spots well over on side 1, as far from each other as they can be.
	var picks := []
	for i in spawns.size():
		if along[i] > 0.25:
			picks.append(spawns[i][0])
	if picks.size() < 2:
		picks = sides[1].map(func(s): return s[0])
	var sites := []
	if picks.size() >= 2:
		var pair := [0, 1]
		var apart := -1.0
		for i in picks.size():
			for j in range(i + 1, picks.size()):
				var d := _flat_dist(picks[i], picks[j]) + absf(picks[i].y - picks[j].y) * 0.25
				if d > apart + 0.01:
					apart = d
					pair = [i, j]
		sites = [picks[pair[0]], picks[pair[1]]]
		# A is the one on the left as the attackers look across the map.
		var left := axis.cross(Vector3.UP)
		if (sites[0] - mid).dot(left) < (sites[1] - mid).dot(left):
			sites = [sites[1], sites[0]]
	else:
		var side := axis.cross(Vector3.UP) * 6.0
		sites = [b + side, b - side]
	return {"bases": [a, b], "sides": sides, "sites": sites, "base_spawns": [spawns[best[0]], spawns[best[1]]]}


static func _flat_dist(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


## Called by the arena on every copy once the map is built.
func setup_map(layout: MapRoot) -> void:
	var plan := plan_map(layout.spawns)
	bases = plan.bases
	side_spawns = plan.sides
	base_spawns = plan.get("base_spawns", [[], []])
	_formation = [null, null]
	sites = plan.sites
	map_ready = true
	_flags_home()
	if DevArgs.sync_log and active():
		print("TEAM_MAP %s bases=%s sites=%s sides=%d/%d" % [mode(), bases, sites, side_spawns[0].size(), side_spawns[1].size()])
	if Net.is_host() and active() and Match.running and not _started:
		_started = true
		if is_snd():
			_host_give_bomb()
		_host_sync()


## The spawn point for player `p` (a MapRoot.spawns entry): on their team's side. In
## Search and Destroy everyone has their own (by their place in the team), so a team
## starting a round together does not stack up; in Capture the Flag the one on their
## side furthest from the other team.
func spawn_for(p: Node3D, peer_id: int, others: Array) -> Array:
	var team := team_of(peer_id)
	var list: Array = side_spawns[side_of(team)] if team >= 0 else []
	if list.is_empty():
		return []
	var spots := _formation_for(side_of(team), p)
	if mode() == "snd":
		var k: int = max(members(team).find(peer_id), 0)
		if k < spots.size():
			return spots[k]   # the whole team together, each in their own spot
		var spot: Array = list[k % list.size()].duplicate()
		if k >= list.size():   # more players than spawn points: beside the one they share
			spot[0] = spot[0] + Vector3(1.3, 0, 0).rotated(Vector3.UP, float(k / list.size()) * 2.1)
		return spot
	if spots.size() >= 4:   # CTF: back at your base with your team, on a spot nobody is standing on
		var free := []
		for s in spots:
			var taken := false
			for o in others:
				var other := o as Player
				if other and other != p and other.alive and (s[0] as Vector3).distance_to(other.global_position) < 1.3:
					taken = true
					break
			if not taken:
				free.append(s)
			if free.size() >= 3:
				break
		if not free.is_empty():
			return free[randi() % free.size()]
	var best: Array = list[randi() % list.size()]
	var best_score := -INF
	for s in list:
		var nearest := 999.0
		var crowded := false
		for o in others:
			var other := o as Player
			if other == null or other == p or not other.alive:
				continue
			var d := (s[0] as Vector3).distance_to(other.global_position)
			crowded = crowded or d < 2.0   # someone is standing on it
			if not same_team(peer_id, other.peer_id):
				nearest = minf(nearest, d)
		var sc := nearest + randf() * 4.0 - (500.0 if crowded else 0.0)   # a little luck, so it is not always the same one
		if sc > best_score:
			best_score = sc
			best = s
	return best


const FORMATION_RINGS := [[1.7, 6], [3.3, 10], [4.9, 14]]   # [radius, spots]


## The spots a side's team gathers on: its base spawn, then rings around it, each one
## checked against the map (a floor under it near the same height, no wall between it
## and the base). Worked out once per map, when the first player spawns.
func _formation_for(side: int, p: Node3D) -> Array:
	if _formation[side] != null:
		return _formation[side]
	var base: Array = base_spawns[side] if side < base_spawns.size() else []
	if base.is_empty() or p == null or not p.is_inside_tree():
		return []
	var space := p.get_world_3d().direct_space_state
	var origin: Vector3 = base[0]
	var yaw: float = base[1] if base.size() > 1 else 0.0
	var out := [base]
	var found_floor := false
	for ring in FORMATION_RINGS:
		var n: int = ring[1]
		for i in n:
			# Alternate either side of straight behind the base, so the first spots are nearest the back.
			var step := (i + 1) / 2 * (1 if i % 2 == 1 else -1)
			var ang := yaw + PI + float(step) * TAU / float(n)
			var at := origin + Vector3(sin(ang), 0.0, cos(ang)) * float(ring[0])
			var spot := _spot_ok(space, origin, at)
			if spot != Vector3.INF:
				found_floor = true
				var s: Array = base.duplicate()
				s[0] = spot
				out.append(s)
	if found_floor:   # (no floor anywhere: the map's collision is not up yet, so try again next time)
		_formation[side] = out
	return out if found_floor else []


static func _spot_ok(space: PhysicsDirectSpaceState3D, origin: Vector3, at: Vector3) -> Vector3:
	var up := Vector3(0, 1.0, 0)
	var wall := PhysicsRayQueryParameters3D.create(origin + up, at + up, 1)
	if not space.intersect_ray(wall).is_empty():
		return Vector3.INF
	var down := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.6, 0), at - Vector3(0, 2.0, 0), 1)
	var hit := space.intersect_ray(down)
	if hit.is_empty() or absf(hit.position.y - origin.y) > 0.9 or (hit.normal as Vector3).y < 0.7:
		return Vector3.INF
	# Room to stand: nothing over the spot up to head height.
	var head := PhysicsRayQueryParameters3D.create(hit.position + Vector3(0, 0.1, 0), hit.position + Vector3(0, 2.0, 0), 1)
	if not space.intersect_ray(head).is_empty():
		return Vector3.INF
	return Vector3(at.x, maxf(hit.position.y, origin.y), at.z)


# ---------------------------------------------------------------------------
# Starting

func _reset() -> void:
	score = [0, 0]
	round_number = 1
	phase = Phase.LIVE
	round_left = round_time()
	fuse_left = 0.0
	over_left = 0.0
	bomb_carrier = 0
	bomb_pos = Vector3.INF
	bomb_site = -1
	holder = 0
	hold_progress = 0.0
	round_winner = -1
	round_reason = ""
	_holding.clear()
	_told.clear()
	_last_pos.clear()
	_started = false
	_flags_home()


func _flags_home() -> void:
	flags = []
	for t in 2:
		flags.append({"state": Flag.HOME, "carrier": 0, "pos": bases[t], "left": 0.0})


func _on_match_started() -> void:
	map_ready = false
	_reset()
	changed.emit()


## Host, as the match starts: deal everyone onto a team, alternating in id order (so
## offline, you are Red and the bots alternate Blue, Red, Blue...).
func host_assign() -> void:
	if not active():
		for id in Net.players:
			Net.players[id].erase("team")
		return
	var ids := Net.players.keys()
	ids.sort()
	for i in ids.size():
		Net.players[ids[i]]["team"] = i % 2


## The team with fewer players (Red when level), for someone joining mid-match.
func smaller_team() -> int:
	var count := [0, 0]
	for id in Net.players:
		var t := int(Net.players[id].get("team", -1))
		if t >= 0 and t < 2:
			count[t] += 1
	return 1 if count[1] < count[0] else 0


func _on_players_changed() -> void:
	if Net.is_host() and active() and Match.running and map_ready:
		_host_sync()   # someone joined (they need the state) or left


# ---------------------------------------------------------------------------
# Every frame

func _process(delta: float) -> void:
	if not active() or not Match.running or not map_ready:
		return
	_tell_holds()
	if not Net.is_host():
		_predict(delta)   # between the host's updates
		return
	_host_step(delta)
	_sync_wait -= delta
	if _sync_wait <= 0.0:
		_host_sync()


## Clocks run on between the host's updates.
func _predict(delta: float) -> void:
	if mode() == "snd":
		match phase:
			Phase.LIVE:
				round_left = maxf(round_left - delta, 0.0)
			Phase.PLANTED:
				fuse_left = maxf(fuse_left - delta, 0.0)
			Phase.OVER:
				over_left = maxf(over_left - delta, 0.0)
		if holder != 0:
			hold_progress = minf(hold_progress + delta / (DEFUSE_TIME if phase == Phase.PLANTED else PLANT_TIME), 0.999)
	else:
		for f in flags:
			if f.state == Flag.DROPPED:
				f.left = maxf(float(f.left) - delta, 0.0)


## Our own player and (host) our bots: tell the host when interact goes down or up.
func _tell_holds() -> void:
	if Net.arena == null or Net.arena.players_root == null:
		return
	for c in Net.arena.players_root.get_children():
		var p := c as Player
		if p == null or not p.is_local:
			continue
		var want: bool = p.alive and p.input.interact
		if want != _told.get(p.peer_id, false):
			_told[p.peer_id] = want
			if Net.is_host():
				_host_hold(p.peer_id, want)
			else:
				_hold_request.rpc_id(1, want)


@rpc("any_peer", "call_remote", "reliable")
func _hold_request(on: bool) -> void:
	if Net.is_host():
		_host_hold(multiplayer.get_remote_sender_id(), on)


func _host_hold(id: int, on: bool) -> void:
	if on:
		_holding[id] = true
	else:
		_holding.erase(id)


# ---------------------------------------------------------------------------
# Host: the rules

func _player(id: int) -> Player:
	return Net.arena.get_player(id) if Net.arena else null


## Alive here and to the host: where their feet are, or null.
func _alive_at(id: int) -> Variant:
	if not Match.is_alive(id):
		return null
	var p := _player(id)
	return p.global_position if p and p.alive else null


func _alive_count(team: int) -> int:
	var n := 0
	for id in members(team):
		if Match.is_alive(id):
			n += 1
	return n


func _host_step(delta: float) -> void:
	for id in Net.players:
		var at: Variant = _alive_at(id)
		if at != null:
			_last_pos[id] = at
	if mode() == "snd":
		_host_snd(delta)
	else:
		_host_ctf(delta)


func _host_snd(delta: float) -> void:
	if bomb_carrier != 0 and not Net.players.has(bomb_carrier):
		_host_drop_bomb(_last_pos.get(bomb_carrier, bases[0]), bomb_carrier)   # they left
	match phase:
		Phase.LIVE:
			round_left = maxf(round_left - delta, 0.0)
			if bomb_carrier == 0 and bomb_pos != Vector3.INF:
				for id in members(attackers()):
					var at: Variant = _alive_at(id)
					if at != null and (at as Vector3).distance_to(bomb_pos) <= PICKUP_REACH + 0.6:
						_host_take_bomb(id)
						break
			var c := bomb_carrier
			var at: Variant = _alive_at(c) if c != 0 else null
			var site := site_at(at) if at != null else -1
			if c != 0 and _holding.has(c) and site >= 0:
				if holder != c:
					holder = c
					hold_progress = 0.0
					_host_sync()
				hold_progress += delta / PLANT_TIME
				if hold_progress >= 1.0:
					_host_plant(site, at)
					return
			elif holder != 0:
				holder = 0
				hold_progress = 0.0
				_host_sync()
			if not _host_eliminations():
				if round_left <= 0.0:
					_host_round_over(defenders(), "time")
		Phase.PLANTED:
			fuse_left = maxf(fuse_left - delta, 0.0)
			# Defusing: a defender holding interact at the bomb (the one already at it keeps it).
			var who := 0
			if holder != 0 and _holding.has(holder) and _near_bomb(holder):
				who = holder
			else:
				for id in members(defenders()):
					if _holding.has(id) and _near_bomb(id):
						who = id
						break
			if who != holder:
				holder = who
				hold_progress = 0.0
				_host_sync()
			if who != 0:
				hold_progress += delta / DEFUSE_TIME
				if hold_progress >= 1.0:
					_host_event("bomb_defused", defenders(), who)
					_host_round_over(defenders(), "defused")
					return
			if fuse_left <= 0.0:
				_host_explode()
				return
			if members(defenders()).size() > 0 and _alive_count(defenders()) == 0:
				_host_round_over(attackers(), "eliminated")
		Phase.OVER:
			over_left = maxf(over_left - delta, 0.0)
			if over_left <= 0.0:
				if round_winner >= 0 and score[round_winner] >= ROUNDS_TO_WIN:
					Match.host_end_match()
				else:
					_host_next_round()


func _near_bomb(id: int) -> bool:
	var at: Variant = _alive_at(id)
	return at != null and bomb_pos != Vector3.INF and (at as Vector3).distance_to(bomb_pos) <= BOMB_REACH + 0.6


## A whole team knocked out ends the round (only teams with anyone on them count).
## Returns whether it did.
func _host_eliminations() -> bool:
	var att := attackers()
	var def := defenders()
	if members(def).size() > 0 and _alive_count(def) == 0:
		_host_round_over(att, "eliminated")
		return true
	if members(att).size() > 0 and _alive_count(att) == 0:
		_host_round_over(def, "eliminated")
		return true
	return false


func _host_give_bomb() -> void:
	var alive := members(attackers()).filter(func(id): return Match.is_alive(id))
	if alive.is_empty():
		bomb_carrier = 0
		bomb_pos = bases[0]
		return
	_host_take_bomb(alive[randi() % alive.size()])


func _host_take_bomb(id: int) -> void:
	bomb_carrier = id
	bomb_pos = Vector3.INF
	_host_event("bomb_taken", attackers(), id)


func _host_drop_bomb(at: Vector3, who: int) -> void:
	bomb_carrier = 0
	bomb_pos = at
	if holder == who:
		holder = 0
		hold_progress = 0.0
	_host_event("bomb_dropped", attackers(), who)


func _host_plant(site: int, at: Vector3) -> void:
	var who := bomb_carrier
	phase = Phase.PLANTED
	bomb_site = site
	bomb_pos = at
	bomb_carrier = 0
	fuse_left = FUSE
	holder = 0
	hold_progress = 0.0
	_host_event("bomb_planted", attackers(), who)


func _host_explode() -> void:
	var at := bomb_pos
	_host_round_over(attackers(), "exploded")
	_host_event("bomb_exploded", attackers(), 0)
	for id in Net.players.keys():
		var where: Variant = _alive_at(id)
		if where != null and (where as Vector3).distance_to(at) <= BLAST_RADIUS:
			Match.host_team_kill(id, "bomb")


func _host_round_over(winner: int, reason: String) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	round_winner = winner
	round_reason = reason
	over_left = ROUND_END_TIME
	holder = 0
	hold_progress = 0.0
	score[winner] += 1
	if DevArgs.sync_log:
		print("ROUND_OVER %d %s %s score=%d-%d" % [round_number, team_name(winner), reason, score[0], score[1]])
	_host_event("round_won", winner, 0)


func _host_next_round() -> void:
	round_number += 1
	phase = Phase.LIVE
	round_left = round_time()
	fuse_left = 0.0
	bomb_carrier = 0
	bomb_pos = Vector3.INF
	bomb_site = -1
	holder = 0
	hold_progress = 0.0
	round_winner = -1
	round_reason = ""
	Match.host_new_round()   # everyone back, at full health, on their side
	_host_give_bomb()
	if DevArgs.sync_log:
		print("ROUND_START %d attackers=%s" % [round_number, team_name(attackers())])
	_host_event("round_start", attackers(), 0)


## Capture the Flag.
func _host_ctf(delta: float) -> void:
	for t in 2:
		var f: Dictionary = flags[t]
		match int(f.state):
			Flag.CARRIED:
				var c := int(f.carrier)
				if not Net.players.has(c):
					_host_drop_flag(t, _last_pos.get(c, flag_home(t)), c)   # they left
					continue
				var at: Variant = _alive_at(c)
				if at == null:
					continue   # (a death drops it: see host_on_death)
				f.pos = at
				var own := team_of(c)
				if own >= 0 and flags[own].state == Flag.HOME and (at as Vector3).distance_to(flag_home(own)) <= CAPTURE_REACH:
					_host_capture(t, c)
					return
			Flag.DROPPED:
				f.left = float(f.left) - delta
				if float(f.left) <= 0.0:
					_host_return_flag(t, 0)
					continue
				var who := _toucher(f.pos, -1)
				if who != 0:
					if team_of(who) == t:
						_host_return_flag(t, who)
					elif flag_carried_by(who) < 0:
						_host_take_flag(t, who)
			Flag.HOME:
				var who := _toucher(flag_home(t), 1 - t)
				if who != 0 and flag_carried_by(who) < 0:
					_host_take_flag(t, who)


## Someone alive (on `team`, or anyone for -1) close enough to `at` to pick it up.
func _toucher(at: Vector3, team: int) -> int:
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		if team >= 0 and team_of(id) != team:
			continue
		if team_of(id) < 0:
			continue
		var where: Variant = _alive_at(id)
		if where != null and ((where as Vector3) + Vector3(0, 0.9, 0)).distance_to(at + Vector3(0, 0.9, 0)) <= PICKUP_REACH + 0.6:
			return id
	return 0


func _host_take_flag(team: int, who: int) -> void:
	flags[team] = {"state": Flag.CARRIED, "carrier": who, "pos": flag_position(team), "left": 0.0}
	_host_event("flag_taken", team, who)


func _host_drop_flag(team: int, at: Vector3, who: int) -> void:
	flags[team] = {"state": Flag.DROPPED, "carrier": 0, "pos": at, "left": FLAG_RETURN}
	_host_event("flag_dropped", team, who)


func _host_return_flag(team: int, who: int) -> void:
	flags[team] = {"state": Flag.HOME, "carrier": 0, "pos": flag_home(team), "left": 0.0}
	_host_event("flag_returned", team, who)


func _host_capture(team: int, who: int) -> void:
	var by := team_of(who)
	flags[team] = {"state": Flag.HOME, "carrier": 0, "pos": flag_home(team), "left": 0.0}
	score[by] += 1
	if DevArgs.sync_log:
		print("CAPTURE %d %s score=%d-%d" % [who, team_name(by), score[0], score[1]])
	_host_event("flag_captured", by, who)
	if score[by] >= CAPTURES_TO_WIN:
		Match.host_end_match()


## Host (from Match): `victim` died. They drop whatever they carried, where they fell
## (or, if they fell off the map, the bomb goes back to the attackers' end and a flag home).
func host_on_death(victim: int, cause: String) -> void:
	if not active() or not Net.is_host():
		return
	var p := _player(victim)
	var at: Vector3 = p.global_position if p else _last_pos.get(victim, bases[0])
	var lost := cause == "fell" or not map_ready
	if mode() == "snd":
		if victim == bomb_carrier:
			_host_drop_bomb(bases[0] if lost else at, victim)
		if victim == holder:
			holder = 0
			hold_progress = 0.0
			_host_sync()
	else:
		var t := flag_carried_by(victim)
		if t >= 0:
			if lost:
				_host_return_flag(t, 0)
			else:
				_host_drop_flag(t, at, victim)


## The winning team at the end (-1: a draw).
func winner() -> int:
	return leader()


# ---------------------------------------------------------------------------
# Telling everyone

func _pack() -> Dictionary:
	return {"s": score, "r": round_number, "p": phase, "rl": round_left, "fl": fuse_left, "ol": over_left,
		"bc": bomb_carrier, "bp": bomb_pos, "bs": bomb_site, "h": holder, "hp": hold_progress,
		"rw": round_winner, "rr": round_reason, "f": flags}


func _host_sync() -> void:
	_sync_wait = 0.5
	_state.rpc(_pack())


func _host_event(kind: String, team: int, who: int) -> void:
	_state.rpc(_pack())
	_sync_wait = 0.5
	_event.rpc(kind, team, who)


@rpc("authority", "call_local", "reliable")
func _state(s: Dictionary) -> void:
	score = s.s
	round_number = int(s.r)
	phase = int(s.p) as Phase
	round_left = float(s.rl)
	fuse_left = float(s.fl)
	over_left = float(s.ol)
	bomb_carrier = int(s.bc)
	bomb_pos = s.bp
	bomb_site = int(s.bs)
	holder = int(s.h)
	hold_progress = float(s.hp)
	round_winner = int(s.rw)
	round_reason = str(s.rr)
	flags = s.f
	changed.emit()


@rpc("authority", "call_local", "reliable")
func _event(kind: String, team: int, who: int) -> void:
	if DevArgs.sync_log:
		print("TEAM_EVENT %s %d %d" % [kind, team, who])
	event.emit(kind, team, who)


# ---------------------------------------------------------------------------
# Bots: where to go for the objective (see BotBrain)

## What a bot on a team should be doing about the objective: {} for nothing (fight and
## roam as usual), or {"spot": where to go, "urgent": go even with someone in sight,
## "hold": hold interact once there (plant, defuse), "radius": close enough (it fights
## and roams as usual inside it)}.
func bot_goal(id: int, at: Vector3) -> Dictionary:
	var team := team_of(id)
	if team < 0 or not map_ready or not Match.is_alive(id):
		return {}
	var rank: int = max(members(team).filter(func(m): return Net.is_bot(m)).find(id), 0)
	if mode() == "snd":
		return _bot_snd(id, team, rank, at)
	return _bot_ctf(id, team, rank, at)


func _bot_snd(id: int, team: int, rank: int, at: Vector3) -> Dictionary:
	if phase == Phase.OVER:
		return {}
	if team == attackers():
		if phase == Phase.PLANTED:
			return {"spot": bomb_pos, "urgent": false, "hold": false, "radius": 9.0}   # guard it
		var plan := (round_number * 7 + int(score[0]) + int(score[1])) % 2   # the site this round's attack goes for
		var site: Vector3 = sites[plan] if plan < sites.size() else bases[1]
		if bomb_carrier == id:
			var on := site_at(at) >= 0
			return {"spot": site, "urgent": on or at.distance_to(site) < 20.0, "hold": on, "radius": 0.0}
		if bomb_carrier == 0 and bomb_pos != Vector3.INF:
			return {"spot": bomb_pos, "urgent": at.distance_to(bomb_pos) < 15.0, "hold": false, "radius": 0.0}   # pick it up
		var carrier := _player(bomb_carrier)
		if carrier and rank % 2 == 0:
			return {"spot": carrier.global_position, "urgent": false, "hold": false, "radius": 7.0}   # cover the carrier
		return {"spot": site, "urgent": false, "hold": false, "radius": 8.0}
	# Defending.
	if phase == Phase.PLANTED:
		var near := at.distance_to(bomb_pos) <= BOMB_REACH
		return {"spot": bomb_pos, "urgent": near or at.distance_to(bomb_pos) < 18.0, "hold": near, "radius": 0.0}
	var guard: Vector3 = sites[rank % sites.size()] if not sites.is_empty() else bases[1]
	return {"spot": guard, "urgent": false, "hold": false, "radius": 7.0}


func _bot_ctf(id: int, team: int, rank: int, at: Vector3) -> Dictionary:
	var enemy := 1 - team
	if flag_carried_by(id) >= 0:
		return {"spot": flag_home(team), "urgent": true, "hold": false, "radius": 0.0}   # run it home
	var ours: Dictionary = flags[team]
	if int(ours.state) == Flag.DROPPED:
		var p: Vector3 = ours.pos
		if at.distance_to(p) < 30.0 or rank % 3 == 2:
			return {"spot": p, "urgent": at.distance_to(p) < 12.0, "hold": false, "radius": 0.0}   # send it home
	var defender := rank % 3 == 2   # one bot in three stays back
	if defender:
		if int(ours.state) == Flag.CARRIED:
			var thief := _player(int(ours.carrier))
			if thief:
				return {"spot": thief.global_position, "urgent": false, "hold": false, "radius": 3.0}
		return {"spot": flag_home(team), "urgent": false, "hold": false, "radius": 9.0}
	var theirs: Dictionary = flags[enemy]
	if int(theirs.state) == Flag.CARRIED:
		var mate := _player(int(theirs.carrier))
		if mate:
			return {"spot": mate.global_position, "urgent": false, "hold": false, "radius": 6.0}   # cover the carrier
	return {"spot": flag_position(enemy), "urgent": at.distance_to(flag_position(enemy)) < 10.0, "hold": false, "radius": 0.0}
