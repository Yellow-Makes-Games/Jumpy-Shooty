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
## A target dummy was hit (it also sends player_hit, with the dummy's id as the target).
signal dummy_hit(shooter: int, dummy: int, damage: float, headshot: bool, killed: bool)
signal shot_fired(shooter: int, muzzle: Vector3, ends: PackedVector3Array, hits: Array)  ## one end per pellet
signal match_over(results: Array)
## A melee swing landed: who swung, with what, and where each blow struck (for sounds and sparks).
signal melee_landed(attacker: int, weapon_id: String, points: PackedVector3Array)
## Someone hit a wall hard enough to hurt (for the crash sound everyone hears).
signal slammed(id: int, where: Vector3, speed: float)

const MAX_HEALTH := 100.0
const RESPAWN_DELAY := 3.0
const MAX_REWIND := 0.6           ## seconds; older views are clamped (anti-abuse)
const HIT_FORGIVENESS := 0.08     ## metres added to player radius when checking hits
const HEAD_HEIGHT := 1.45         ## a hit above this height (from the feet) is a headshot
## Slamming into a wall or prop: hitting it faster than this (m/s, straight into it)
## hurts, SLAM_DAMAGE per m/s over, up to SLAM_MAX. Landings on the floor never count.
const SLAM_SPEED := 17.5
const SLAM_DAMAGE := 4.0
const SLAM_MAX := 80.0
## A crash within this many seconds of being shoved counts as the shover's hit (and kill).
const SHOVE_CREDIT := 3.0
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
var _last_slam_time: Dictionary = {}   # host: id -> Net.now() of last crash that hurt
var _last_shove: Dictionary = {}       # host: id -> [who shoved them, Net.now()]
var _last_kick_time: Dictionary = {}   # host: id -> Net.now() of last accepted kick
var _tethers: Dictionary = {}          # host: id -> [the player their hook is on, Net.now()]
## How each player last died: "" (shot or cut down), "fell", or "slam" (hit a wall too hard).
var death_cause: Dictionary = {}
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
		if Maps.game_of(Net.map_id()) == "race":
			kill_target = 0   # a race ends at the finish (see Race), or at its time limit
			time_left = float(s.get("race_minutes", 10)) * 60.0 + Race.COUNTDOWN
			if DevArgs.time_limit > 0.0:
				time_left = DevArgs.time_limit
		if Game.mode == Game.Mode.PRACTICE:
			kill_target = 0
			time_left = INF
		scores.clear()
		health.clear()
		respawn_timers.clear()
		_last_shot_time.clear()
		_last_slam_time.clear()
		_last_shove.clear()
		_last_kick_time.clear()
		_tethers.clear()
		death_cause.clear()
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
	# (In game time: the debug menu can speed the game up offline.)
	if (now - _last_shot_time.get(shooter, -10.0)) * Engine.time_scale < weapon.fire_interval * 0.7:
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
	var bodies := _rewound_bodies(shooter, view_times)   # [id, feet, height, facing yaw]
	var breaks := _breakables()

	var damage := {}   # target id -> total damage of this shot
	var heads := {}    # target id -> a pellet hit the head
	var shove := {}    # target id -> knockback of this shot (each pellet pushes along its path)
	var ends := PackedVector3Array()
	var hit_mask := 0
	var log := []
	for i in directions.size():
		var direction := directions[i].normalized()
		# How far the pellet can travel before hitting the level.
		var end := origin + direction * weapon.max_range
		var world_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 1))  # layer 1: level only
		var wall_cell := -1
		if world_hit:
			end = world_hit.position
			if breaks:
				wall_cell = breaks.cell_at(world_hit.collider, world_hit.position, world_hit.normal)
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
			shove[best_target] = shove.get(best_target, Vector3.ZERO) \
				+ Vector3(direction.x, 0.0, direction.z).normalized() * weapon.knockback + Vector3.UP * weapon.knockback_up
			heads[best_target] = heads.get(best_target, false) or best_head
		elif wall_cell >= 0:
			breaks.damage(wall_cell, weapon.damage_at(origin.distance_to(end)) * weapon.structure_damage)
		ends.append(end)
		if DevArgs.sync_log:
			log.append(("hit %d at %.2f m%s" % [best_target, best_height, " head" if best_head else ""]) if best_target else "miss")
	_shot_effect.rpc(shooter, origin, ends, hit_mask)
	_flush_breaks()
	for id in damage:
		if is_dummy(id):
			_host_dummy_damage(shooter, id, damage[id], heads[id])
		else:
			_host_damage(shooter, id, damage[id], heads[id])
			_host_shove(shooter, id, shove[id])
	if DevArgs.sync_log:
		# One line per shot (the first pellet that hit, if any), then the gun and its pellets.
		var first := "miss"
		for entry in log:
			if entry != "miss":
				first = entry
				break
		print("SHOT %d %s" % [shooter, first])
		print("PELLETS %d %s %d/%d" % [shooter, weapon_id, log.size() - log.count("miss"), log.size()])


## Everyone `attacker` could hit, each moved back to where `attacker` saw them:
## [id, feet, height, facing yaw]. Target dummies stand still: no rewind needed.
func _rewound_bodies(attacker: int, view_times: Dictionary) -> Array:
	var bodies := []
	for id in Net.players:
		if id == attacker or not is_alive(id):
			continue
		var target: Player = Net.arena.get_player(id)
		if target == null:
			continue
		var when := _clamped_view_time(target, view_times.get(id, -1.0))
		bodies.append([id, target.position_at(when), Player.height_for_pose(target.pose_at(when)), target.yaw_at(when)])  # shorter when crouched
	for d in Net.arena.dummies:
		if not (d as TargetDummy).is_down():
			bodies.append([dummy_id(d.index), d.global_position, Player.CAPSULE_HEIGHT, d.rotation.y])
	return bodies


# ---------------------------------------------------------------------------
# Melee

## Called by the local player when a swing lands (after its wind-up): from the eyes,
## toward where it looks. Like a shot, it says when it was seeing each opponent.
func request_melee(origin: Vector3, direction: Vector3, view_times: Dictionary, attacker: int = 0) -> void:
	if Net.is_host():
		_host_melee(attacker if attacker != 0 else Net.my_id(), origin, direction, view_times)
	else:
		_melee_request.rpc_id(1, origin, direction, view_times)


@rpc("any_peer", "call_remote", "reliable")
func _melee_request(origin: Vector3, direction: Vector3, view_times: Dictionary) -> void:
	if Net.is_host():
		_host_melee(multiplayer.get_remote_sender_id(), origin, direction, view_times)


func _host_melee(attacker: int, origin: Vector3, direction: Vector3, view_times: Dictionary) -> void:
	if not running or not is_alive(attacker) or not Net.arena or Race.active:
		return
	var weapon := WeaponData.by_id(Net.player_weapon(attacker))
	if not weapon.is_melee() or direction.length_squared() < 0.0001:
		return
	var now := Net.now()
	if (now - _last_shot_time.get(attacker, -10.0)) * Engine.time_scale < weapon.fire_interval * 0.7:
		return
	_last_shot_time[attacker] = now
	var who: Player = Net.arena.get_player(attacker)
	if who == null or origin.distance_to(who.latest_position() + Vector3(0, CameraRig.EYE_HEIGHT, 0)) > 3.0:
		return
	direction = direction.normalized()
	var space := (Net.arena as Node3D).get_world_3d().direct_space_state
	var points := PackedVector3Array()
	var hits := []   # [id, damage, shove]
	for b in _rewound_bodies(attacker, view_times):
		var feet: Vector3 = b[1]
		var height: float = b[2]
		var a := feet + Vector3(0, Player.CAPSULE_RADIUS, 0)
		var top := feet + Vector3(0, height - Player.CAPSULE_RADIUS, 0)
		var near := Geometry3D.get_closest_point_to_segment(origin, a, top)
		var to := near - origin
		var reach := maxf(to.length() - Player.CAPSULE_RADIUS, 0.0)
		if reach > weapon.max_range:
			continue
		# In front: within the arc of where you look (anyone touching you counts too).
		if to.length() > Player.CAPSULE_RADIUS * 2.0 and rad_to_deg(direction.angle_to(to)) > weapon.arc_degrees:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, near, 1)).is_empty():
			continue   # a wall in the way
		var dmg := weapon.damage
		var flat := Vector3(to.x, 0.0, to.z)
		flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3(direction.x, 0.0, direction.z).normalized()
		# From behind: the blow goes the same way they face.
		var facing := Vector3.FORWARD.rotated(Vector3.UP, b[3])
		if weapon.backstab_multiplier > 1.0 and facing.dot(flat) > 0.5:
			dmg *= weapon.backstab_multiplier
		hits.append([b[0], dmg, flat * weapon.knockback + Vector3.UP * weapon.knockback_up])
		points.append(near.lerp(origin, Player.CAPSULE_RADIUS / maxf(to.length(), 0.01)))
	if DevArgs.sync_log:
		print("MELEE %d %s %d" % [attacker, weapon.id, hits.size()])
		# Also a SHOT line like a gun's, so the tests count blows as shots and hits.
		print("SHOT %d %s" % [attacker, ("hit %d at melee" % hits[0][0]) if not hits.is_empty() else "miss"])
	_melee_effect.rpc(attacker, weapon.id, points)
	# The blow also lands on a breakable wall or floor right in front.
	var breaks := _breakables()
	if breaks:
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * (weapon.max_range + 0.5), 1))
		if wall:
			breaks.damage(breaks.cell_at(wall.collider, wall.position, wall.normal), weapon.damage * weapon.structure_damage)
			_flush_breaks()
	for h in hits:
		if is_dummy(h[0]):
			_host_dummy_damage(attacker, h[0], h[1], false)
		else:
			_host_damage(attacker, h[0], h[1], false)
			_host_shove(attacker, h[0], h[2])


# ---------------------------------------------------------------------------
# Kicks (see Kick): everyone has one, whatever they carry

## Called by the local player (or a bot) when a kick lands: from the eyes, toward
## where it looks (a flying kick: toward who it is flying at).
func request_kick(origin: Vector3, direction: Vector3, view_times: Dictionary, flying: bool, attacker: int = 0) -> void:
	if Net.is_host():
		_host_kick(attacker if attacker != 0 else Net.my_id(), origin, direction, view_times, flying)
	else:
		_kick_request.rpc_id(1, origin, direction, view_times, flying)


@rpc("any_peer", "call_remote", "reliable")
func _kick_request(origin: Vector3, direction: Vector3, view_times: Dictionary, flying: bool) -> void:
	if Net.is_host():
		_host_kick(multiplayer.get_remote_sender_id(), origin, direction, view_times, flying)


func _host_kick(attacker: int, origin: Vector3, direction: Vector3, view_times: Dictionary, flying: bool) -> void:
	if not running or not is_alive(attacker) or not Net.arena or Race.active or direction.length_squared() < 0.0001:
		return
	var now := Net.now()
	if (now - _last_kick_time.get(attacker, -10.0)) * Engine.time_scale < Kick.COOLDOWN * 0.7:
		return
	if flying:
		# Only straight after hooking someone.
		var tether: Array = _tethers.get(attacker, [])
		if tether.is_empty() or now - float(tether[1]) > Kick.FLYING_WINDOW:
			flying = false
		else:
			_tethers.erase(attacker)
	_last_kick_time[attacker] = now
	var who: Player = Net.arena.get_player(attacker)
	if who == null or origin.distance_to(who.latest_position() + Vector3(0, CameraRig.EYE_HEIGHT, 0)) > (6.0 if flying else 3.0):
		return
	direction = direction.normalized()
	var reach := Kick.FLYING_REACH if flying else Kick.REACH
	var arc := Kick.FLYING_ARC if flying else Kick.ARC
	var space := (Net.arena as Node3D).get_world_3d().direct_space_state
	var points := PackedVector3Array()
	var hits := []   # [id, damage, shove]
	for b in _rewound_bodies(attacker, view_times):
		var feet: Vector3 = b[1]
		var height: float = b[2]
		var near := Geometry3D.get_closest_point_to_segment(origin,
			feet + Vector3(0, Player.CAPSULE_RADIUS, 0), feet + Vector3(0, height - Player.CAPSULE_RADIUS, 0))
		var to := near - origin
		if maxf(to.length() - Player.CAPSULE_RADIUS, 0.0) > reach:
			continue
		if to.length() > Player.CAPSULE_RADIUS * 2.0 and rad_to_deg(direction.angle_to(to)) > arc:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, near, 1)).is_empty():
			continue   # a wall in the way
		var flat := Vector3(direction.x, 0.0, direction.z) if flying else Vector3(to.x, 0.0, to.z)
		flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3(direction.x, 0.0, direction.z).normalized()
		# Faster into them than they are moving away = a harder shove.
		var victim: Player = Net.arena.get_player(b[0])
		var their_vel := victim.latest_velocity() if victim else Vector3.ZERO
		var closing := maxf((who.latest_velocity() - their_vel).dot(flat), 0.0)
		var boost := minf(1.0 + closing * Kick.SPEED_KNOCKBACK, Kick.SPEED_MAX)
		var shove := flat * (Kick.FLYING_KNOCKBACK if flying else Kick.KNOCKBACK) * boost \
			+ Vector3.UP * (Kick.FLYING_KNOCKBACK_UP if flying else Kick.KNOCKBACK_UP)
		hits.append([b[0], Kick.FLYING_DAMAGE if flying else Kick.DAMAGE, shove])
		points.append(near.lerp(origin, Player.CAPSULE_RADIUS / maxf(to.length(), 0.01)))
	if DevArgs.sync_log:
		print("KICK %d %s %d" % [attacker, "flying" if flying else "front", hits.size()])
	var kind := "flying_kick" if flying else "kick"
	_melee_effect.rpc(attacker, kind, points)
	var breaks := _breakables()
	if breaks:
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * (reach + 0.5), 1))
		if wall:
			var dmg := (Kick.FLYING_DAMAGE if flying else Kick.DAMAGE) * Kick.STRUCTURE
			breaks.damage(breaks.cell_at(wall.collider, wall.position, wall.normal), dmg)
			_flush_breaks()
	for h in hits:
		if is_dummy(h[0]):
			_host_dummy_damage(attacker, h[0], h[1], false)
		else:
			_host_damage(attacker, h[0], h[1], false)
			_host_shove(attacker, h[0], h[2])


# ---------------------------------------------------------------------------
# Hooking another player: the rope reels you both together

## Called by the local player (or a bot) when its hook catches player `target`
## (on = true) or lets go of them (on = false).
func request_tether(target: int, on: bool, by: int = 0) -> void:
	if Net.is_host():
		_host_tether(by if by != 0 else Net.my_id(), target, on)
	else:
		_tether_request.rpc_id(1, target, on)


@rpc("any_peer", "call_remote", "reliable")
func _tether_request(target: int, on: bool) -> void:
	if Net.is_host():
		_host_tether(multiplayer.get_remote_sender_id(), target, on)


func _host_tether(by: int, target: int, on: bool) -> void:
	if not Net.players.has(target) or target == by or not Net.arena:
		return
	if on:
		if not running or Race.active or not is_alive(by) or not is_alive(target):
			return
		var a: Player = Net.arena.get_player(by)
		var b: Player = Net.arena.get_player(target)
		if a == null or b == null or a.latest_position().distance_to(b.latest_position()) > 60.0:
			return
		_tethers[by] = [target, Net.now()]
		_last_shove[target] = [by, Net.now()]   # reeled into a wall: that's their doing
	if DevArgs.sync_log:
		print("TUG %d %d %s" % [by, target, "on" if on else "off"])
	if target == Net.my_id() or Net.is_bot(target):
		_apply_tug(target, by, on)
	else:
		_tug.rpc_id(target, target, by, on)


@rpc("authority", "call_remote", "reliable")
func _tug(target: int, by: int, on: bool) -> void:
	_apply_tug(target, by, on)


func _apply_tug(target: int, by: int, on: bool) -> void:
	var p: Player = Net.arena.get_player(target) if Net.arena else null
	if p and p.is_local:
		if on and target == Net.my_id() and Cheats.god_mode():
			return
		p.tug(by, on)


@rpc("authority", "call_local", "unreliable")
func _melee_effect(attacker: int, weapon_id: String, points: PackedVector3Array) -> void:
	melee_landed.emit(attacker, weapon_id, points)


# ---------------------------------------------------------------------------
# Breakable walls and floors (see MapDestruction). The host damages them; everyone
# is told which pieces cracked or broke.

func _breakables() -> MapDestruction:
	if Net.arena == null or Race.active:
		return null
	var layout: MapRoot = Net.arena.get("layout")
	return layout.destruction if layout else null


func _flush_breaks() -> void:
	var d := _breakables()
	if d == null:
		return
	var changed := d.flush()
	if changed.is_empty():
		return
	_breaks.rpc(changed[0], changed[1])
	if DevArgs.sync_log:
		var broke := 0
		for s in (changed[1] as PackedByteArray):
			if s >= MapDestruction.BROKEN:
				broke += 1
		print("BREAK %d cells changed, %d broken" % [(changed[0] as PackedInt32Array).size(), broke])


@rpc("authority", "call_local", "reliable")
func _breaks(cells: PackedInt32Array, stages: PackedByteArray) -> void:
	var d := _breakables()
	if d:
		d.apply(cells, stages)
		if DevArgs.sync_log:
			print("BROKEN_STATE %s" % d.state_key())


## A copy that has just built the arena asks the host what is already broken.
func request_breaks() -> void:
	if not Net.is_host():
		_breaks_request.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _breaks_request() -> void:
	var d := _breakables()
	if Net.is_host() and d:
		var all := d.snapshot()
		_breaks.rpc_id(multiplayer.get_remote_sender_id(), all[0], all[1])


# ---------------------------------------------------------------------------
# Knockback and crashing into walls

## Push `target` (a player, not a dummy). Movement is run by whoever plays that
## player, so the push goes to them: you, a friend, or one of the host's bots.
func _host_shove(attacker: int, target: int, push: Vector3) -> void:
	if push.length_squared() < 0.01 or not is_alive(target) or not Net.players.has(target):
		return
	if target == Net.my_id() and Cheats.god_mode():
		return
	_last_shove[target] = [attacker, Net.now()]
	if target == Net.my_id() or Net.is_bot(target):
		_apply_shove(target, push)
	else:
		_shove.rpc_id(target, target, push)


@rpc("authority", "call_remote", "reliable")
func _shove(target: int, push: Vector3) -> void:
	_apply_shove(target, push)


func _apply_shove(target: int, push: Vector3) -> void:
	var p: Player = Net.arena.get_player(target) if Net.arena else null
	if p and p.is_local and p.alive:
		p.knock(push)


## The local player (or a bot) hit a wall at `speed` m/s.
func request_slam(speed: float, where: Vector3, id: int = 0) -> void:
	if Net.is_host():
		_host_slam(id if id != 0 else Net.my_id(), speed, where)
	else:
		_slam_request.rpc_id(1, speed, where)


@rpc("any_peer", "call_remote", "reliable")
func _slam_request(speed: float, where: Vector3) -> void:
	if Net.is_host():
		_host_slam(multiplayer.get_remote_sender_id(), speed, where)


func _host_slam(id: int, speed: float, where: Vector3) -> void:
	if not running or not is_alive(id) or Race.active or speed < SLAM_SPEED:
		return
	var now := Net.now()
	if now - _last_slam_time.get(id, -10.0) < 0.5:
		return
	_last_slam_time[id] = now
	var amount := minf((minf(speed, 90.0) - SLAM_SPEED) * SLAM_DAMAGE, SLAM_MAX)
	# Shoved into it? Then whoever shoved you gets the hit (and the kill).
	var by := id
	var shove: Array = _last_shove.get(id, [])
	if not shove.is_empty() and now - float(shove[1]) <= SHOVE_CREDIT and Net.players.has(shove[0]):
		by = shove[0]
	_slam_effect.rpc(id, where, speed)
	if DevArgs.sync_log:
		print("SLAM %d %.1f m/s %.0f damage by %d" % [id, speed, amount, by])
	if amount >= 1.0:
		_host_damage(by, id, amount, false, "slam")


@rpc("authority", "call_local", "unreliable")
func _slam_effect(id: int, where: Vector3, speed: float) -> void:
	slammed.emit(id, where, speed)


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

func _host_damage(shooter: int, target: int, amount: float, headshot: bool = false, cause: String = "") -> void:
	if not is_alive(target):
		return
	if target == Net.my_id() and Cheats.god_mode():
		return
	health[target] = max(health[target] - amount, 0.0)
	_hit.rpc(shooter, target, amount, health[target], headshot)
	if health[target] <= 0.0:
		_host_kill(target, shooter, cause)


@rpc("authority", "call_local", "reliable")
func _hit(shooter: int, target: int, amount: float, new_health: float, headshot: bool) -> void:
	health[target] = new_health
	player_hit.emit(shooter, target, amount, headshot)
	state_changed.emit()


# ---------------------------------------------------------------------------
# Target dummies (see TargetDummy). They take part in hits under negative ids,
# -1 for the first, so they never clash with a player's id.

static func dummy_id(index: int) -> int:
	return -1 - index


static func is_dummy(id: int) -> bool:
	return id < 0


func _host_dummy_damage(shooter: int, id: int, amount: float, headshot: bool) -> void:
	var index := -1 - id
	if not Net.arena or index >= Net.arena.dummies.size():
		return
	var dummy: TargetDummy = Net.arena.dummies[index]
	if dummy.is_down():
		return
	_dummy_hit.rpc(shooter, index, amount, maxf(dummy.health - amount, 0.0), headshot)


@rpc("authority", "call_local", "reliable")
func _dummy_hit(shooter: int, index: int, amount: float, new_health: float, headshot: bool) -> void:
	if not Net.arena or index >= Net.arena.dummies.size():
		return
	var dummy: TargetDummy = Net.arena.dummies[index]
	var who: Player = Net.arena.get_player(shooter)
	var distance := who.global_position.distance_to(dummy.global_position) if who else -1.0
	dummy.show_hit(amount, headshot, new_health, distance)
	player_hit.emit(shooter, dummy_id(index), amount, headshot)
	dummy_hit.emit(shooter, index, amount, headshot, new_health <= 0.0)


## Practice and offline only (the debug menu): back to full health now.
func host_heal(id: int) -> void:
	if Net.is_host() and running and is_alive(id):
		health[id] = MAX_HEALTH
		_broadcast_state()


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
	if Race.active:
		return   # in a race you go back to your checkpoint instead (see Race)
	if running and is_alive(id):
		health[id] = 0.0
		_host_kill(id, 0, "fell")


func _host_kill(victim: int, killer: int, cause: String = "") -> void:
	if scores.has(victim):
		scores[victim].deaths += 1
	if killer != 0 and killer != victim and scores.has(killer):
		scores[killer].kills += 1
	respawn_timers[victim] = RESPAWN_DELAY
	_last_shove.erase(victim)
	_died.rpc(victim, killer, scores, cause)
	if killer != 0 and kill_target > 0 and kills(killer) >= kill_target:
		host_end_match()


@rpc("authority", "call_local", "reliable")
func _died(victim: int, killer: int, new_scores: Dictionary, cause: String) -> void:
	health[victim] = 0.0
	death_cause[victim] = cause
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


## Rankings: most kills first, then fewest deaths. In a race: the race standings.
func build_results() -> Array:
	if Race.active:
		return Race.standings()
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
