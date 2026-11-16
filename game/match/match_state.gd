extends Node
## The rules of a match, run by the host. Autoload at /root/Match.
##
## The host is the referee: it decides hits, damage, deaths, respawns, scores and
## when the match ends, then tells everyone. Other players only *ask* (for example
## "I fired from here, in this direction, and this is what I could see").
##
## Hits are decided by the host *with rewind*: the shooter tells the host at what
## moment it was seeing each opponent, the host moves each opponent back to where
## they were at that moment, and checks the shot against those positions. So you
## hit what you aimed at on your screen, but the host has the final say.

signal state_changed               ## scores, health or timer changed
signal player_hit(shooter: int, target: int, damage: float, headshot: bool)
signal player_died(victim: int, killer: int)
signal player_respawned(id: int, spawn_index: int)
signal shot_fired(shooter: int, muzzle: Vector3, ends: PackedVector3Array, hits: Array)  ## one end per pellet
signal match_over(results: Array)

const MAX_HEALTH := 100.0
const RESPAWN_DELAY := 3.0
const MAX_REWIND := 0.6           ## seconds; older views are clamped (anti-abuse)
const HIT_FORGIVENESS := 0.08     ## metres added to player radius when checking hits
const HEAD_HEIGHT := 1.45         ## a hit above this height (from the feet) is a headshot
## kill_target 0 means "no kill target" (time-limit matches).
var kill_target := 15
var time_left := 480.0
var running := false
## id -> {"kills": int, "deaths": int}
var scores: Dictionary = {}
## id -> float
var health: Dictionary = {}
## id -> seconds until respawn (only for dead players)
var respawn_timers: Dictionary = {}
## Results of the last finished match, for the results screen.
var last_results: Array = []

var _last_shot_time: Dictionary = {}   # host: id -> Net.now() of last accepted shot
var _respawn_counter := 0


func _ready() -> void:
	Net.match_started.connect(_on_match_started)
	Net.players_changed.connect(_on_players_changed)


func is_alive(id: int) -> bool:
	return health.get(id, MAX_HEALTH) > 0.0


func kills(id: int) -> int:
	return scores[id].kills if scores.has(id) else 0


func deaths(id: int) -> int:
	return scores[id].deaths if scores.has(id) else 0


# ---------------------------------------------------------------------------
# Starting

func _on_match_started() -> void:
	running = true
	last_results = []
	if Net.is_host():
		# The host's lobby settings decide the win condition (dev options override them).
		var s: Dictionary = Net.match_settings
		if s.mode == "time":
			kill_target = 0
			time_left = float(s.minutes) * 60.0
		else:
			kill_target = int(s.kills)
			time_left = INF
		if DevArgs.kill_target > 0:
			kill_target = DevArgs.kill_target
		if DevArgs.time_limit > 0.0:
			time_left = DevArgs.time_limit
		if Game.mode == Game.Mode.PRACTICE:
			kill_target = 0
			time_left = INF
		scores.clear()
		health.clear()
		respawn_timers.clear()
		_last_shot_time.clear()
		for id in Net.players:
			scores[id] = {"kills": 0, "deaths": 0}
			health[id] = MAX_HEALTH
		_broadcast_state()


func _on_players_changed() -> void:
	if not Net.is_host() or not running:
		return
	var changed := false
	for id in Net.players:
		if not scores.has(id):  # someone joined mid-match
			scores[id] = {"kills": 0, "deaths": 0}
			health[id] = MAX_HEALTH
			changed = true
	for id in scores.keys():
		if not Net.players.has(id):
			scores.erase(id)
			health.erase(id)
			respawn_timers.erase(id)
			changed = true
	if changed:
		_broadcast_state()


func _broadcast_state() -> void:
	_sync_state.rpc(kill_target, time_left, scores, health)


@rpc("authority", "call_local", "reliable")
func _sync_state(target: int, remaining: float, new_scores: Dictionary, new_health: Dictionary) -> void:
	kill_target = target
	time_left = remaining
	scores = new_scores
	health = new_health
	running = true
	state_changed.emit()


# ---------------------------------------------------------------------------
# Clock

func _process(delta: float) -> void:
	if not running:
		return
	time_left = max(time_left - delta, 0.0)
	if not Net.is_host():
		return
	for id in respawn_timers.keys():
		respawn_timers[id] -= delta
		if respawn_timers[id] <= 0.0:
			respawn_timers.erase(id)
			_host_respawn(id)
	if time_left <= 0.0:
		host_end_match()


# ---------------------------------------------------------------------------
# Shooting

## Called by the local player when it fires. `directions` holds one direction per
## pellet (one for most guns, ten for the shotgun). view_times maps each opponent's
## peer id to the moment (on that opponent's clock) this player was seeing them.
## Bots (simulated on the host) pass their own id as `shooter`.
func request_shot(origin: Vector3, directions: PackedVector3Array, view_times: Dictionary, weapon_id: String, shooter: int = 0) -> void:
	if Net.is_host():
		_host_shot(shooter if shooter != 0 else Net.my_id(), origin, directions, view_times, weapon_id)
	else:
		_shot_request.rpc_id(1, origin, directions, view_times, weapon_id)


@rpc("any_peer", "call_remote", "reliable")
func _shot_request(origin: Vector3, directions: PackedVector3Array, view_times: Dictionary, weapon_id: String) -> void:
	if Net.is_host():
		_host_shot(multiplayer.get_remote_sender_id(), origin, directions, view_times, weapon_id)


func _host_shot(shooter: int, origin: Vector3, directions: PackedVector3Array, view_times: Dictionary, weapon_id: String) -> void:
	if not running or not is_alive(shooter) or not Net.arena:
		return
	# The gun is the one the shooter took into the match, whatever the message says.
	weapon_id = Net.player_weapon(shooter)
	var weapon := WeaponData.by_id(weapon_id)
	var now := Net.now()
	# Fire rate check (a little slack for network timing).
	if now - _last_shot_time.get(shooter, -10.0) < weapon.fire_interval * 0.7:
		return
	_last_shot_time[shooter] = now
	var shooter_node: Player = Net.arena.get_player(shooter)
	if shooter_node == null or directions.is_empty():
		return
	# The shot must start near where the host believes the shooter is.
	if origin.distance_to(shooter_node.latest_position() + Vector3(0, CameraRig.EYE_HEIGHT, 0)) > 3.0:
		return
	if directions.size() > weapon.pellets:
		directions = directions.slice(0, weapon.pellets)

	# Rewind each opponent once to what the shooter saw.
	var space := (Net.arena as Node3D).get_world_3d().direct_space_state
	var bodies := []   # [id, feet, height]
	for id in Net.players:
		if id == shooter or not is_alive(id):
			continue
		var target: Player = Net.arena.get_player(id)
		if target == null:
			continue
		var when := _clamped_view_time(target, view_times.get(id, -1.0))
		bodies.append([id, target.position_at(when), Player.height_for_pose(target.pose_at(when))])  # shorter when crouched

	var damage := {}   # target id -> total damage of this shot
	var heads := {}    # target id -> a pellet hit the head
	var ends := PackedVector3Array()
	var hit_mask := 0
	var log := []
	for i in directions.size():
		var direction := directions[i].normalized()
		# How far the pellet can travel before hitting the level.
		var end := origin + direction * weapon.max_range
		var world_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 1))  # layer 1: level only
		if world_hit:
			end = world_hit.position
		# The nearest opponent the pellet passes through.
		var best_target := 0
		var best_dist := INF
		var best_point := end
		var best_head := false
		var best_height := 0.0
		for b in bodies:
			var feet: Vector3 = b[1]
			var height: float = b[2]
			var r := Player.CAPSULE_RADIUS + HIT_FORGIVENESS
			var a := feet + Vector3(0, Player.CAPSULE_RADIUS, 0)
			var top := feet + Vector3(0, height - Player.CAPSULE_RADIUS, 0)
			var pts := Geometry3D.get_closest_points_between_segments(origin, end, a, top)
			if pts[0].distance_to(pts[1]) <= r:
				var d := origin.distance_to(pts[0])
				if d < best_dist:
					best_dist = d
					best_target = b[0]
					best_point = pts[0]
					best_height = pts[0].y - feet.y
					best_head = best_height >= height - (Player.CAPSULE_HEIGHT - HEAD_HEIGHT)
		if best_target != 0:
			end = best_point
			hit_mask |= 1 << i
			var dmg := weapon.damage_at(best_dist) * (weapon.headshot_multiplier if best_head else 1.0)
			damage[best_target] = damage.get(best_target, 0.0) + dmg
			heads[best_target] = heads.get(best_target, false) or best_head
		ends.append(end)
		if DevArgs.sync_log:
			log.append(("hit %d at %.2f m%s" % [best_target, best_height, " head" if best_head else ""]) if best_target else "miss")
	_shot_effect.rpc(shooter, origin, ends, hit_mask)
	for id in damage:
		_host_damage(shooter, id, damage[id], heads[id])
	if DevArgs.sync_log:
		# One line per shot (the first pellet that hit, if any), then the gun and its pellets.
		var first := "miss"
		for entry in log:
			if entry != "miss":
				first = entry
				break
		print("SHOT %d %s" % [shooter, first])
		print("PELLETS %d %s %d/%d" % [shooter, weapon_id, log.size() - log.count("miss"), log.size()])


## Keeps the rewind within limits so a slow or dishonest client cannot shoot far into the past.
func _clamped_view_time(target: Player, t: float) -> float:
	var newest := target.latest_time()
	if t < 0.0:
		return newest
	return clamp(t, newest - MAX_REWIND, newest)


@rpc("authority", "call_local", "unreliable")
func _shot_effect(shooter: int, muzzle: Vector3, ends: PackedVector3Array, hit_mask: int) -> void:
	var hits := []
	for i in ends.size():
		hits.append(hit_mask & (1 << i) != 0)
	shot_fired.emit(shooter, muzzle, ends, hits)


# ---------------------------------------------------------------------------
# Damage, death, respawn (host decides, everyone is told)

func _host_damage(shooter: int, target: int, amount: float, headshot: bool = false) -> void:
	if not is_alive(target):
		return
	health[target] = max(health[target] - amount, 0.0)
	_hit.rpc(shooter, target, amount, health[target], headshot)
	if health[target] <= 0.0:
		_host_kill(target, shooter)


@rpc("authority", "call_local", "reliable")
func _hit(shooter: int, target: int, amount: float, new_health: float, headshot: bool) -> void:
	health[target] = new_health
	player_hit.emit(shooter, target, amount, headshot)
	state_changed.emit()


## The local player fell out of the arena.
func request_fell(id: int = 0) -> void:
	if Net.is_host():
		_host_fell(id if id != 0 else Net.my_id())
	else:
		_fell_request.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _fell_request() -> void:
	if Net.is_host():
		_host_fell(multiplayer.get_remote_sender_id())


func _host_fell(id: int) -> void:
	if running and is_alive(id):
		health[id] = 0.0
		_host_kill(id, 0)


func _host_kill(victim: int, killer: int) -> void:
	if scores.has(victim):
		scores[victim].deaths += 1
	if killer != 0 and killer != victim and scores.has(killer):
		scores[killer].kills += 1
	respawn_timers[victim] = RESPAWN_DELAY
	_died.rpc(victim, killer, scores)
	if killer != 0 and kill_target > 0 and kills(killer) >= kill_target:
		host_end_match()


@rpc("authority", "call_local", "reliable")
func _died(victim: int, killer: int, new_scores: Dictionary) -> void:
	health[victim] = 0.0
	scores = new_scores
	player_died.emit(victim, killer)
	state_changed.emit()


func _host_respawn(id: int) -> void:
	if not running or not Net.players.has(id):
		return
	health[id] = MAX_HEALTH
	_respawn_counter += 1
	_respawned.rpc(id, _respawn_counter)


@rpc("authority", "call_local", "reliable")
func _respawned(id: int, spawn_index: int) -> void:
	health[id] = MAX_HEALTH
	player_respawned.emit(id, spawn_index)
	state_changed.emit()


# ---------------------------------------------------------------------------
# Ending

func host_end_match() -> void:
	if not Net.is_host() or not running:
		return
	_match_over.rpc(build_results())


## Rankings: most kills first, then fewest deaths.
func build_results() -> Array:
	var rows: Array = []
	for id in scores:
		rows.append({"id": id, "name": Net.player_name(id), "kills": scores[id].kills, "deaths": scores[id].deaths})
	rows.sort_custom(func(a, b):
		if a.kills != b.kills:
			return a.kills > b.kills
		return a.deaths < b.deaths)
	return rows


@rpc("authority", "call_local", "reliable")
func _match_over(results: Array) -> void:
	running = false
	last_results = results
	respawn_timers.clear()
	if DevArgs.sync_log:
		print("MATCH_OVER %s" % JSON.stringify(results))
	match_over.emit(results)
