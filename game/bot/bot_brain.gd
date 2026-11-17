class_name BotBrain
extends RefCounted
## The computer player's decisions. Each physics frame it fills in the bot's
## PlayerInput, exactly like the keyboard and mouse do for you, so a bot moves and
## shoots by the same rules as a person: same speeds, same gun, same hit checks.
##
## What it does:
##  - Notices you fairly: it sees you only when you are in front of it and nothing
##    is in the way (no seeing through walls). It hears gunfire, a bullet going past
##    and someone running nearby, and when you shoot it, it knows roughly where from.
##    A sound gives it a rough spot, not your exact position.
##  - Picks who to fight: in a free-for-all with several bots it goes for whoever
##    it knows about that is nearest, favouring someone it can see, whoever just
##    shot it, and whoever it is already fighting (so it does not flick between
##    targets). Bots fight each other as well as you.
##  - Finds you: walks the map's navigation mesh (ramps, decks, tower) to where it
##    last saw or heard you (the better bots guess where you were running), then
##    searches round there. When it gives up, or knows of nobody, it roams the map.
##  - Fights: strafes side to side at a comfortable range, jumps, and turns its aim
##    toward you at a limited speed. It sees you with a delay (its reaction time)
##    and its aim wobbles; it leads moving targets and goes for headshots more on
##    higher difficulties.
##  - Uses the movement set: sprints, slides and bunny-hops while chasing, dives to
##    close distance, flips to dodge when hit, grapples toward high ground.
##  - Kicks anyone right in front of it, hooks you with the grapple to reel you in
##    and finishes with a flying kick, and fires its rocket boots to close in, to
##    dodge when hit and to whip round faster on a grapple swing.
## How good it is at each of these comes from BotDifficulty.

const ENGAGE_RANGE := 45.0
## The distances each gun likes to fight at: [closer than this it backs off a little,
## further than this it closes in, it does not shoot beyond this]. The shotgun rushes
## in, the sniper rifle keeps its distance.
## Melee weapons run straight in and swing once in reach.
const RANGES := {"pistol": [7.0, 18.0, 999.0], "shotgun": [2.5, 7.0, 20.0], "rifle": [8.0, 22.0, 999.0],
	"sniper": [16.0, 36.0, 999.0], "sword": [0.0, 1.6, 3.1], "hammer": [0.0, 1.8, 3.3], "dagger": [0.0, 1.3, 2.6],
	"revolver": [8.0, 20.0, 999.0], "machine_pistol": [3.0, 9.0, 30.0], "break_action": [2.0, 6.0, 16.0],
	"smg": [3.5, 11.0, 40.0], "burst_rifle": [9.0, 24.0, 999.0], "lmg": [8.0, 22.0, 999.0],
	"lever_action": [10.0, 26.0, 999.0], "bolt_action": [14.0, 32.0, 999.0], "railgun": [14.0, 34.0, 999.0],
	"rocket_launcher": [8.0, 18.0, 60.0], "grenade_launcher": [7.0, 15.0, 35.0],
	"brass_knuckles": [0.0, 1.1, 2.1], "spear": [0.0, 2.6, 4.1], "axe": [0.0, 1.7, 3.0], "bat": [0.0, 1.7, 3.0]}
const CHEST := 1.05        ## aim heights above the feet
const HEAD := 1.6
const PRONE_AIM := 0.4     ## aim height at someone belly-sliding (they are lying flat)
const SEARCH_RADIUS := 8.0 ## how far round the spot it lost you it looks
const SOUND_GAP := 0.4     ## seconds between updating where it heard someone (so its goal does not jitter)
const WHIZZ := 4.0         ## a shot ending this close is heard, however far away the shooter is
const LOOK_TIME := 1.2     ## it looks toward a fresh sighting or sound for this long, then where it runs
const GRAPPLE_HEADROOM := 6.0  ## it only swings with this much open air above its head
const LEVEL_GAP := 2.5     ## you are this much higher or lower: it comes to your floor instead of fighting from where it is
const RETARGET := 0.25     ## seconds between choosing who to fight (straight away if the target dies)
const SEEN_BIAS := 0.5     ## someone it can see counts as this much closer...
const KEEP_BIAS := 0.7     ## ...its current target as this much closer...
const REVENGE_BIAS := 0.5  ## ...and whoever shot it in the last REVENGE_TIME seconds as this much closer
const REVENGE_TIME := 2.0

var me: Player
var d: BotDifficulty
var input: PlayerInput

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _target: Player
var _retarget := 0.0
var _attacker := 0               # peer id of whoever last shot it
var _attacked_time := -99.0
var _seen: Array = []            # [time, aim point, velocity] of the target, oldest first
var _last_seen_time := -99.0
var _known := {}                 # peer id -> [time, position]: where it last saw or heard each player
var _in_view := {}               # peer id -> true for players it can see right now
var _goal := Vector3.INF         # where it is walking when it cannot see its target
var _goal_time := 0.0            # seconds it has been walking to _goal
var _goal_from := -1.0           # the time of the sighting or sound _goal is based on
var _path := PackedVector3Array()
var _path_index := 0
var _path_goal := Vector3.INF
var _repath := 0.0
var _corner_ahead := false       # the path turns sharply within the next few metres
var _strafe_dir := 1.0
var _strafe_timer := 0.0
var _error := Vector3.ZERO       # aim wobble, a slow random walk
var _go_head := false
var _head_timer := 0.0
var _fire_wait := 0.0
var _burst := 0.0                # automatic gun: seconds left of the burst it is firing
var NEAR := 7.0
var FAR := 18.0
var _reach := 999.0
var _lob := Vector3.INF          # rockets and grenades: the point it is really aiming at (led, low, lobbed)
var _melee := false              # carrying a blade or hammer: rush in instead of keeping distance
var _stuck_time := 0.0
var _escape_dir := Vector3.ZERO
var _escape_time := 0.0
var _slide_time := 0.0
var _belly_time := 0.0           # holding dive: lands a dive on its belly and slides
var _hop_time := 0.0
var _trick_wait := 0.0
var _dodge_side := 0.0           # a flip dodge in progress: which way (-1 left, 1 right)
var _dodge_time := 0.0
var _grapple_time := 0.0
var _grapple_start := Vector3.ZERO
var _log_time := 0.0
var _hook_frame := false         # it has just aimed the hook at someone: don't turn away this frame
var _boost_side := 0.0           # it was just hit: boost this way (-1 left, 1 right, 0 no)
var _last_state := -1
var _state_seen := {}


func _init(player: Player, level: int) -> void:
	me = player
	d = BotDifficulty.make(level)
	input = player.input
	weapon_changed()
	_rng.randomize()
	Match.player_hit.connect(_on_hit)
	Match.shot_fired.connect(_on_shot)


## Fight the way the weapon in its hands likes (Gun Game swaps it mid-match; a
## Deathmatch pickup or switch too). Empty hands fight like a blade: run in and kick.
func weapon_changed() -> void:
	var r: Array = RANGES.get(me.weapon.data.id if me.weapon else "dagger", RANGES.pistol)
	NEAR = r[0]
	FAR = r[1]
	_reach = r[2]
	_melee = me.weapon == null or me.weapon.data.is_melee()
	_burst = 0.0


## Deathmatch, empty hands: the nearest weapon lying about (INF if none is there).
func _nearest_pickup() -> Vector3:
	if Net.arena == null:
		return Vector3.INF
	var best := Vector3.INF
	var best_d := INF
	for p in Net.arena.pickups:
		var pickup := p as WeaponPickup
		if pickup.is_taken():
			continue
		var dist := me.global_position.distance_to(pickup.global_position)
		if dist < best_d:
			best_d = dist
			best = pickup.global_position
	return best


## Fill in this frame's input.
func update(delta: float) -> void:
	_time += delta
	input.move = Vector2.ZERO
	input.sprint = false
	input.fire = false
	input.aim_origin = Vector3.ZERO
	input.aim_dir = Vector3.ZERO
	if not me.alive:
		_reset()
		return
	_sense()
	_retarget -= delta
	if not is_instance_valid(_target):
		_target = null
	if _target == null or not _target.alive or not _known.has(_target.peer_id) or _retarget <= 0.0:
		_retarget = RETARGET
		var picked := _pick_target()
		if picked != _target:
			_target = picked
			_seen.clear()   # what it saw of the old target says nothing about this one
			_goal = Vector3.INF
			_goal_from = -1.0
	var visible := _target != null and _in_view.has(_target.peer_id)
	if visible:
		_seen.append([_time, _aim_point(_target), _target.velocity])
		_last_seen_time = _time
	while not _seen.is_empty() and _seen[0][0] < _time - 2.0:
		_seen.pop_front()
	var perceived := _perceived() if visible else []

	var world_dir := _choose_direction(delta, visible)
	_hook_frame = false
	_grapple(delta, visible)
	_dodge(delta)
	_set_move(world_dir)
	if not _hook_frame:
		_aim(delta, perceived, world_dir)
	_fire(delta, perceived)
	_kick(delta, visible)
	_boost(delta, visible)
	if DevArgs.sync_log:
		if me.motor.state != _last_state:
			_last_state = me.motor.state
			if _time - float(_state_seen.get(_last_state, -9.0)) > 0.5 and _last_state in [MovementController.State.DIVE, MovementController.State.FLIP,
					MovementController.State.GRAPPLE, MovementController.State.SLIDE, MovementController.State.BELLY_SLIDE,
					MovementController.State.WALL_RUN, MovementController.State.MANTLE]:
				print("BOT_MOVE %d %s" % [me.peer_id, MovementController.State.keys()[_last_state]])
			_state_seen[_last_state] = _time
		_log_time -= delta
		if _log_time <= 0.0:
			_log_time = 1.0
			var p := me.global_position
			print("BOT %d %.1f %.1f %.1f %s see=%s dist=%.1f path=%d/%d" % [me.peer_id, p.x, p.y, p.z,
				MovementController.State.keys()[me.motor.state], visible,
				p.distance_to(_target.global_position) if _target else -1.0, _path_index, _path.size()])


func _reset() -> void:
	_seen.clear()
	_in_view.clear()
	_goal = Vector3.INF
	_path = PackedVector3Array()
	_path_goal = Vector3.INF
	input.grapple = false
	input.crouch = false
	_slide_time = 0.0
	_belly_time = 0.0
	input.dive = false
	_hop_time = 0.0
	_dodge_time = 0.0
	_grapple_time = 0.0


# ---------------------------------------------------------------------------
# Seeing

## Look and listen: update what it knows about where everyone is.
func _sense() -> void:
	for other in _others():
		var id := other.peer_id
		if not other.alive:
			_known.erase(id)
			_in_view.erase(id)
			continue
		if _can_see(other):
			_known[id] = [_time, other.global_position]
			_in_view[id] = true
			continue
		if _in_view.has(id):
			# Just lost sight: it saw which way you were going.
			_in_view.erase(id)
			var v := Vector3(other.velocity.x, 0.0, other.velocity.z)
			_known[id] = [_time, other.global_position + v * d.predict]
			continue
		# Footsteps: someone running close by (walking or crouching is quieter).
		var speed := Vector2(other.velocity.x, other.velocity.z).length()
		var dist := me.global_position.distance_to(other.global_position)
		if speed > 2.5 and dist < d.step_range * (1.0 if speed > 6.0 else 0.5):
			_hear(id, other.global_position, false)
	for id in _known.keys():
		if _time - float(_known[id][0]) > d.memory:
			_known.erase(id)


## It heard player `id` at `where`: it knows roughly where, worse from further away.
## A player it can see needs no guessing, and a fresh sound is not replaced by
## another straight away unless `force` (it was shot).
func _hear(id: int, where: Vector3, force: bool) -> void:
	if _in_view.has(id):
		return
	if not force and _known.has(id) and _time - float(_known[id][0]) < SOUND_GAP:
		return
	var off := me.global_position.distance_to(where) * d.sound_error
	var miss := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).limit_length(1.0)
	_known[id] = [_time, where + miss * off]


func _on_shot(shooter: int, muzzle: Vector3, ends: PackedVector3Array, _hits: Array) -> void:
	if shooter == me.peer_id or not me.alive:
		return
	var close := me.eye_position().distance_to(muzzle) <= d.hear_range
	if not close:
		for e in ends:   # a bullet cracking past
			if Geometry3D.get_closest_point_to_segment(me.eye_position(), muzzle, e).distance_to(me.eye_position()) < WHIZZ:
				close = true
				break
	if close:
		_hear(shooter, muzzle, false)


func _others() -> Array[Player]:
	var list: Array[Player] = []
	for p in me.get_parent().get_children():
		var other := p as Player
		if other != null and other != me:
			list.append(other)
	return list


func _pick_target() -> Player:
	var best: Player = null
	var best_score := INF
	var revenge := _time - _attacked_time < REVENGE_TIME
	for other in _others():
		if not other.alive or not _known.has(other.peer_id):
			continue   # it only goes after players it has seen or heard
		var score := me.global_position.distance_to(_known[other.peer_id][1])
		if _in_view.has(other.peer_id):
			score *= SEEN_BIAS
		if other == _target:
			score *= KEEP_BIAS
		if revenge and other.peer_id == _attacker:
			score *= REVENGE_BIAS
		if score < best_score:
			best_score = score
			best = other
	return best


## In front of it (or right next to it) and not behind a wall.
func _can_see(p: Player) -> bool:
	var eye := me.eye_position()
	var to := p.global_position + Vector3(0, CHEST, 0) - eye
	if to.length() > 3.0 and me.aim_forward().angle_to(to) > deg_to_rad(d.view_angle):
		return false
	var space := me.get_world_3d().direct_space_state
	for h in [HEAD, CHEST]:
		var q := PhysicsRayQueryParameters3D.create(eye, p.global_position + Vector3(0, h, 0), 1, [me.get_rid()])
		if space.intersect_ray(q).is_empty():
			return true
	return false


## Where it thinks its target is: where it really is when it can see it, otherwise
## where it last saw or heard it.
func _target_spot() -> Vector3:
	if _target == null:
		return Vector3.INF
	if _in_view.has(_target.peer_id):
		return _target.global_position
	return _known[_target.peer_id][1] if _known.has(_target.peer_id) else Vector3.INF


## Where it aims on a target: chest, or head when it is going for headshots.
func _aim_point(p: Player) -> Vector3:
	var pose := p.pose_at(p.latest_time()) if not p.motor else 0
	var low: bool = p.motor.crouched if p.motor else Player.pose_crouched(pose)
	var prone: bool = p.motor.prone if p.motor else Player.pose_state(pose) == MovementController.State.BELLY_SLIDE
	var h := (HEAD - 0.6 if low else HEAD) if _go_head else (CHEST - 0.3 if low else CHEST)
	if prone:
		h = PRONE_AIM
	return p.global_position + Vector3(0, h, 0)


## What the bot "knows" right now: where the target was one reaction time ago.
## Empty until it has been watching that long (it has only just spotted you).
func _perceived() -> Array:
	var when := _time - d.reaction_time
	var best: Array = []
	for s in _seen:
		if s[0] <= when:
			best = s
	return best


# ---------------------------------------------------------------------------
# Moving

func _choose_direction(delta: float, visible: bool) -> Vector3:
	var pos := me.global_position
	var grounded := me.is_on_floor()
	var speed := Vector2(me.velocity.x, me.velocity.z).length()
	input.crouch = false
	_belly_time = maxf(_belly_time - delta, 0.0)
	input.dive = _belly_time > 0.0
	if _escape_time > 0.0:
		_escape_time -= delta
		_unstick(delta, _escape_dir)
		return _escape_dir
	var dist := pos.distance_to(_target.global_position) if visible else INF
	var dir := Vector3.ZERO
	var pickup := _nearest_pickup() if me.weapon == null else Vector3.INF
	if pickup != Vector3.INF and dist > 4.0:
		# Deathmatch with empty hands: arm up first (kicking anyone who gets close).
		dir = _follow_path(pickup, delta)
		if _flat(pos, pickup) < 2.5:
			dir = Vector3(pickup.x - pos.x, 0.0, pickup.z - pos.z).normalized()   # the last step, straight over it
		input.sprint = d.sprint and not _corner_ahead
		_chase_tricks(delta, dir, grounded, speed)
	elif visible and dist < maxf(ENGAGE_RANGE, FAR + 10.0):
		# Fight: strafe side to side, keeping a comfortable distance.
		var to := _target.global_position - pos
		to.y = 0.0
		var f := to.normalized()
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = _rng.randf_range(0.35, 1.3)
			if _rng.randf() < 0.75:
				_strafe_dir = -_strafe_dir
		var approach := 1.0 if dist > FAR else (-0.6 if dist < NEAR else 0.0)
		if _melee and dist > FAR:
			approach = 2.5   # straight at you, weaving a little
		dir = f.cross(Vector3.UP) * _strafe_dir * d.strafe + f * approach
		if _blocked(dir) or not _ground_ahead(dir, 1.5):
			_strafe_dir = -_strafe_dir
			dir = f.cross(Vector3.UP) * _strafe_dir * d.strafe + f * approach
			if not _ground_ahead(dir, 1.5):
				# A drop on both sides (it is on stairs or a walkway): keep to the path
				dir = _follow_path(_target.global_position, delta)
		# You are on another floor: no strafing about underneath, take the stairs to
		# your level (still shooting on the way).
		if absf(_target.global_position.y - pos.y) > LEVEL_GAP:
			var route := _follow_path(_target.global_position, delta)
			if route != Vector3.ZERO:
				dir = route
		input.sprint = d.sprint and dist > FAR and not _corner_ahead
		if grounded and _rng.randf() < d.jumpiness * delta * 2.5:
			input.jump_pressed = true
		# At the top of a jump, flip sideways to throw off your aim.
		if not grounded and absf(me.velocity.y) < 2.0 and _dodge_time <= 0.0 \
				and _rng.randf() < d.jumpiness * d.dodge_chance * delta * 6.0:
			_dodge_side = _strafe_dir
			_dodge_time = 0.3
		# Close the gap fast with a dive (it dives where it looks: at you).
		if d.grapples and grounded and dist > FAR + 4.0 and _rng.randf() < delta * 0.5 and _ground_ahead(f, 8.0):
			_dive(f)
		elif _melee and grounded and dist > 5.0 and dist < 12.0 and _rng.randf() < delta * 1.2 and _ground_ahead(f, 8.0):
			_dive(f)   # a blade has to get close: dive in
	else:
		# Chase to where it last saw or heard you and search round there, or roam.
		dir = _follow_path(_hunt_goal(delta), delta)
		input.sprint = d.sprint and not _corner_ahead   # sprinting round a sharp corner overshoots it
		_chase_tricks(delta, dir, grounded, speed)
	if _hop_time > 0.0:
		_hop_time -= delta
		if not _ground_ahead(dir, 6.0):
			_hop_time = 0.0             # a drop is coming up: stop hopping
		elif grounded:
			input.jump_pressed = true   # bunny-hop: jump again the moment it lands
	if _slide_time > 0.0:
		_slide_time -= delta
		input.crouch = true
	_unstick(delta, dir)
	return dir


## Where to walk when it cannot see its target: the spot it last saw or heard it,
## then other places close to that spot. With nobody to go after, anywhere on the map.
func _hunt_goal(delta: float) -> Vector3:
	var nav := me.get_world_3d().navigation_map
	_goal_time += delta
	var info: Array = _known[_target.peer_id] if _target != null and _known.has(_target.peer_id) else []
	if not info.is_empty() and float(info[0]) != _goal_from:
		_goal_from = info[0]   # a new sighting or sound: go there
		_goal = info[1]
		_goal_time = 0.0
	var pos := me.global_position
	var arrived := _goal != Vector3.INF and _flat(pos, _goal) < 1.5 and absf(_goal.y - pos.y) < 2.5
	if _goal == Vector3.INF or arrived or _goal_time > 12.0:
		_goal_time = 0.0
		if not info.is_empty():
			var spot: Vector3 = info[1]
			var off := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized() * _rng.randf_range(3.0, SEARCH_RADIUS)
			_goal = NavigationServer3D.map_get_closest_point(nav, spot + off)
		else:
			_goal_from = -1.0
			_goal = NavigationServer3D.map_get_random_point(nav, 1, true)
	return _goal


## Once it is running fast it mixes in movement tricks: slides, bunny-hops, dives.
func _chase_tricks(delta: float, dir: Vector3, grounded: bool, speed: float) -> void:
	_trick_wait -= delta
	if not d.slides or not grounded or speed < 9.0 or _trick_wait > 0.0 or dir.length() < 0.1:
		return
	_trick_wait = _rng.randf_range(0.6, 1.6)
	if not _ground_ahead(dir, 9.0):
		return   # up on a floor or a stair with an edge ahead: no tricks that carry it over
	var facing := Vector3(me.aim_forward().x, 0.0, me.aim_forward().z).normalized()
	var straight := facing.angle_to(dir) < deg_to_rad(15.0) and _straight_ahead(dir) > 8.0
	var roll := _rng.randf()
	if d.grapples and straight and roll < 0.3 and me.motor.state != MovementController.State.SLIDE:
		_dive(dir)   # dives go where it looks, so only when looking where it runs
	elif roll < 0.6:
		_slide_time = 0.8
		input.crouch_pressed = true
	elif d.jumpiness >= 0.15:
		_hop_time = _rng.randf_range(0.8, 2.0)


## Dive, and the better bots usually keep the button held to land in a belly slide
## (a smaller target, and it keeps shooting) when there is room ahead to slide.
func _dive(dir: Vector3) -> void:
	input.dive_pressed = true
	if d.belly_slides and _rng.randf() < 0.7 and _straight_ahead(dir) > 8.0:
		_belly_time = _rng.randf_range(0.9, 1.6)
		input.dive = true


## How far it can run in this direction before hitting something (up to 12 m).
func _straight_ahead(dir: Vector3) -> float:
	var from := me.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * 12.0, 1, [me.get_rid()])
	var hit := me.get_world_3d().direct_space_state.intersect_ray(q)
	return 12.0 if hit.is_empty() else from.distance_to(hit.position)


func _follow_path(goal: Vector3, delta: float) -> Vector3:
	var pos := me.global_position
	_repath -= delta
	if _repath <= 0.0 or _path_goal.distance_to(goal) > 2.5 or _path_index >= _path.size():
		_repath = 0.6
		_path_goal = goal
		var found := NavigationServer3D.map_get_path(me.get_world_3d().navigation_map, pos, goal, true)
		_path = PackedVector3Array()
		for point in found:   # the server repeats points where the path changes height
			if _path.is_empty() or _path[_path.size() - 1].distance_to(point) > 0.05:
				_path.append(point)
		_path_index = 1 if _path.size() > 1 else 0
	while _path_index < _path.size() and _reached(pos, _path_index):
		_path_index += 1
	var next := goal if _path_index >= _path.size() else _path[_path_index]
	_corner_ahead = _path_index < _path.size() and _flat(pos, next) < 4.0 and _is_corner(_path_index)
	var to := next - pos
	to.y = 0.0
	return to.normalized() if to.length() > 0.3 else Vector3.ZERO


## Has it got to this point of the path? Close is enough on a straight stretch, but
## it has to go right round a sharp corner (the foot of a staircase, a doorway)
## or it cuts the corner and runs into what the path was going around. A point on
## the floor above or below does not count.
func _reached(pos: Vector3, index: int) -> bool:
	var point := _path[index]
	if absf(point.y - pos.y) > 1.5:
		return false
	var away := _flat(pos, point)
	if not _is_corner(index):
		return away < 0.9
	# Right on it, or level with it and past it (so a fast runner does not circle it)
	var along := point - _path[index - 1]
	var past := pos - point
	along.y = 0.0
	past.y = 0.0
	return away < 0.35 or (away < 1.2 and past.dot(along) > 0.0)


## Does the path turn sharply at this point?
func _is_corner(index: int) -> bool:
	if index < 1 or index + 1 >= _path.size():
		return false
	var before := _path[index] - _path[index - 1]
	var after := _path[index + 1] - _path[index]
	before.y = 0.0
	after.y = 0.0
	return before.length() > 0.05 and after.length() > 0.05 and before.angle_to(after) > deg_to_rad(50.0)


## Is there floor to run on for the next `reach` metres this way: no drop, and not a
## staircase either (tricks and stairs do not mix)?
func _ground_ahead(dir: Vector3, reach: float) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.1:
		return true
	flat = flat.normalized()
	var space := me.get_world_3d().direct_space_state
	var step := 1.0
	while step <= reach:
		var from := me.global_position + flat * step + Vector3(0, 0.6, 0)
		var drop := minf(1.0 + 0.45 * step, 3.6)   # a slope down is fine, the floor below is not
		var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 0.6 + drop, 0), 1, [me.get_rid()])
		if space.intersect_ray(q).is_empty():
			return false
		step += 1.0
	return true


## Is there a wall right in the way in this direction?
func _blocked(dir: Vector3) -> bool:
	if dir.length() < 0.1:
		return false
	var from := me.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * 1.4, 1, [me.get_rid()])
	return not me.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Not getting anywhere? Jump (vaults handle low stuff), then try another way.
func _unstick(delta: float, dir: Vector3) -> void:
	var speed := Vector2(me.velocity.x, me.velocity.z).length()
	if dir.length() > 0.1 and speed < 1.0 and me.motor.state != MovementController.State.MANTLE:
		_stuck_time += delta
	else:
		_stuck_time = max(_stuck_time - delta, 0.0)
	if _stuck_time > 0.5 and me.is_on_floor():
		input.jump_pressed = true
	if _stuck_time > 1.2:
		_stuck_time = 0.0
		_escape_dir = Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
		_escape_time = 0.7
		_repath = 0.0


func _set_move(world_dir: Vector3) -> void:
	if _dodge_time > 0.0:
		input.move = Vector2(_dodge_side, 0.0)
		return
	var local := world_dir.rotated(Vector3.UP, -input.yaw)
	input.move = Vector2(local.x, -local.z).limit_length(1.0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------------------
# Movement tricks

func _on_hit(shooter: int, target: int, _damage: float, _head: bool) -> void:
	if target != me.peer_id or not me.alive:
		return
	if shooter != me.peer_id:
		_attacker = shooter
		_attacked_time = _time
		_retarget = 0.0   # think again about who to fight
		for other in _others():
			if other.peer_id == shooter:
				_hear(shooter, other.global_position, true)   # it knows roughly where that came from
	if _dodge_time > 0.0:
		return
	if _rng.randf() < d.dodge_chance * 0.5 and me.motor.boost_readiness() >= 1.0:
		_boost_side = 1.0 if _rng.randf() < 0.5 else -1.0   # a sideways rocket burst
		return
	if _rng.randf() < d.dodge_chance:
		# Flip dodge: jump, then jump again in the air toward a side.
		_dodge_side = 1.0 if _rng.randf() < 0.5 else -1.0
		_dodge_time = 0.45
		if me.is_on_floor():
			input.jump_pressed = true


func _dodge(delta: float) -> void:
	if _dodge_time <= 0.0:
		return
	_dodge_time -= delta
	if not me.is_on_floor() and me.motor.state == MovementController.State.AIR and me.velocity.y < 4.0:
		input.jump_pressed = true   # mid-air jump = flip toward _dodge_side
		_dodge_time = min(_dodge_time, 0.1)


## Grapple toward high ground or a far-away target (Hard and Expert).
func _grapple(delta: float, visible: bool) -> void:
	var g := me.motor.grapple
	if g.hooked_player():
		# Reeling someone in: hold on, and flying-kick them once close.
		_grapple_time += delta
		input.grapple = true
		input.jump_pressed = false   # a jump would let go of the rope
		var t := g.target as Player
		if t and me.global_position.distance_to(t.global_position) < 9.0 and _rng.randf() < delta * 12.0:
			input.kick_pressed = true
		return
	if g.attached:
		_grapple_time += delta
		input.grapple = true
		# Let go once past the anchor and rising, once reeled in close (so the pull's
		# speed flings it on instead of pinning it to the wall), or after a while.
		var passed := _flat(me.global_position, _grapple_start) > _flat(g.anchor, _grapple_start)
		var close := g.rope_origin(me).distance_to(g.anchor) < g.tuning.grapple_pull_stop + 1.0
		if (passed and me.velocity.y > 0.0) or close or _grapple_time > 1.6:
			input.grapple = false
		return
	input.grapple = false
	if visible and _hook_player(delta):
		return
	# Toward its target when it can see it, otherwise toward where it is walking.
	var spot := _target_spot() if visible or _goal == Vector3.INF else _goal
	if not d.grapples or spot == Vector3.INF or not g.ready_to_fire():
		return
	var dist := me.global_position.distance_to(spot)
	var higher := spot.y - me.global_position.y > 2.5
	if not (higher or (dist > 25.0 and not visible)) or _rng.randf() > delta * 1.5:
		return
	# Aim up and ahead, toward the target, and hook whatever is there. Not indoors,
	# though: under a ceiling a swing only throws it off the stairs it is climbing.
	var eye := me.eye_position()
	var space := me.get_world_3d().direct_space_state
	var up := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, GRAPPLE_HEADROOM, 0), 1, [me.get_rid()])
	if not space.intersect_ray(up).is_empty():
		return
	var to := spot - me.global_position
	to.y = 0.0
	var point := me.global_position + to.normalized() * minf(dist, 18.0) + Vector3(0, 9.0, 0)
	var dir := (point - eye).normalized()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * g.tuning.grapple_range, 1, [me.get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty() or hit.position.y < me.global_position.y + 3.0:
		return
	input.yaw = atan2(-dir.x, -dir.z)
	input.pitch = asin(clamp(dir.y, -1.0, 1.0))
	input.grapple = true
	input.grapple_pressed = true
	_grapple_time = 0.0
	_grapple_start = me.global_position


## Hook the target it is fighting, now and then, to reel them in for a flying kick.
func _hook_player(delta: float) -> bool:
	var g := me.motor.grapple
	if _target == null or not g.ready_to_fire() or not g.hook_players or not Match.running or me.kick_readiness() < 1.0:
		return false
	var dist := me.global_position.distance_to(_target.global_position)
	if dist < 7.0 or dist > minf(32.0, g.tuning.grapple_range - 4.0):
		return false
	if _rng.randf() > delta * (0.45 if d.grapples else 0.15):
		return false
	var eye := me.eye_position()
	var point := Grapple.target_point(_target) + _target.velocity * 0.08
	point += Vector3(_rng.randfn(), _rng.randfn() * 0.5, _rng.randfn()) * dist * tan(deg_to_rad(d.aim_error)) * 0.5
	var dir := (point - eye).normalized()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * g.tuning.grapple_range, 1 | (1 << 1), [me.get_rid()])
	var hit := me.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.collider != _target:
		return false   # it would miss, or hit a wall: not worth it
	input.yaw = atan2(-dir.x, -dir.z)
	input.pitch = asin(clamp(dir.y, -1.0, 1.0))
	input.grapple = true
	input.grapple_pressed = true
	_grapple_time = 0.0
	_grapple_start = me.global_position
	_hook_frame = true
	return true


## Someone right in front of it: kick them.
func _kick(delta: float, visible: bool) -> void:
	if not visible or _target == null or me.kick_readiness() < 1.0 or me.motor.grapple.hooked_player() or not Match.running:
		return
	var to := _target.global_position + Vector3(0, CHEST, 0) - me.eye_position()
	if to.length() > Kick.REACH + Player.CAPSULE_RADIUS - 0.1:
		return
	if me.aim_forward().angle_to(to) > deg_to_rad(Kick.ARC * 0.7):
		return
	if _rng.randf() < delta * (5.0 if not _melee else 2.0):
		input.kick_pressed = true


## Rocket boots: to dodge when hit, to close in on someone far off, and mid-swing to
## whip round the hook faster. Easier bots use them less.
func _boost(delta: float, visible: bool) -> void:
	var m := me.motor
	if m.boost_readiness() < 1.0:
		_boost_side = 0.0
		return
	var keen := 1.0 if d.grapples else 0.4
	var right := Vector3.RIGHT.rotated(Vector3.UP, input.yaw)
	if _boost_side != 0.0:
		input.boost_pressed = true
		input.boost_dir = right * _boost_side + Vector3.UP * 0.35
		_boost_side = 0.0
		return
	var g := m.grapple
	var speed := me.velocity.length()
	if g.attached and not g.hooked_player() and _grapple_time > 0.3 and _grapple_time < 1.0 and speed > 8.0 \
			and _rng.randf() < delta * 2.5 * keen:
		input.boost_pressed = true   # along the swing: faster round the hook
		input.boost_dir = me.velocity.normalized()
		return
	if visible and _target != null and not g.attached:
		var to := _target.global_position - me.global_position
		var far := 6.0 if _melee else FAR + 6.0
		if to.length() > far and to.length() < 40.0 and _rng.randf() < delta * 0.35 * keen and _ground_ahead(to, 6.0):
			input.boost_pressed = true   # close in
			input.boost_dir = Vector3(to.x, 0.0, to.z).normalized() + Vector3.UP * 0.25


# ---------------------------------------------------------------------------
# Aiming and shooting

func _aim(delta: float, perceived: Array, move_dir: Vector3) -> void:
	if me.motor.grapple.attached and _grapple_time < 0.05:
		return   # just hooked: keep looking at the hook point this frame
	var eye := me.eye_position()
	var target := Vector3.INF
	if not perceived.is_empty():
		_head_timer -= delta
		if _head_timer <= 0.0:
			_head_timer = _rng.randf_range(0.8, 2.0)
			_go_head = _rng.randf() < d.head_chance
		var point: Vector3 = perceived[1]
		var vel: Vector3 = perceived[2]
		point += vel * d.reaction_time * d.lead   # guess where you are now
		var dist := eye.distance_to(point)
		var w: WeaponData = me.weapon.data if me.weapon else null
		if w and w.is_projectile():
			# Rockets and grenades: lead by the flight time, aim low (the blast does the rest), and lob grenades.
			var flight := dist / w.projectile_speed
			point += vel * flight * d.lead
			point.y -= 0.7 if point.y - 0.7 > me.global_position.y - 1.0 else 0.0
			if w.projectile_gravity > 0.0:
				var s2 := w.projectile_speed * w.projectile_speed
				var flat := Vector2(point.x - eye.x, point.z - eye.z).length()
				var k := clampf(w.projectile_gravity * flat / s2, 0.0, 0.99)
				point.y += flat * tan(0.5 * asin(k))
			dist = eye.distance_to(point)
			_lob = point
		_error += Vector3(_rng.randfn(), _rng.randfn() * 0.6, _rng.randfn()) * delta * 2.0
		_error = _error.limit_length(1.0)
		target = point + _error * dist * tan(deg_to_rad(d.aim_error))
	elif _target != null and _known.has(_target.peer_id) and _time - float(_known[_target.peer_id][0]) < LOOK_TIME:
		target = _known[_target.peer_id][1] + Vector3(0, CHEST, 0)   # look toward what it just saw or heard
	elif move_dir.length() > 0.1:
		target = eye + move_dir * 10.0
	if target == Vector3.INF:
		return
	var to := target - eye
	var want_yaw := atan2(-to.x, -to.z)
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var step := deg_to_rad(d.turn_speed) * delta
	input.yaw += clamp(wrapf(want_yaw - input.yaw, -PI, PI), -step, step)
	input.pitch = clamp(input.pitch + clamp(want_pitch - input.pitch, -step, step), deg_to_rad(-89.0), deg_to_rad(89.0))


func _fire(delta: float, perceived: Array) -> void:
	_fire_wait -= delta
	var w := me.weapon
	if w == null:
		_burst = 0.0
		return   # Deathmatch, empty hands: it can only kick (see _kick)
	if w.ammo == 0 and not w.is_reloading():
		w.start_reload()
	# Top up a half-empty gun when nobody is in sight.
	if perceived.is_empty() and not w.is_reloading() and w.ammo < w.data.magazine / 2 and _rng.randf() < delta:
		w.start_reload()
	if perceived.is_empty() or not Match.running:
		_burst = 0.0
		return
	# Shoot when the view is close enough to where it wants to aim.
	var eye := me.eye_position()
	var want: Vector3 = (perceived[1] as Vector3) - eye
	var dist := want.length()
	if dist > _reach:
		return   # a shotgun does not waste shells at long range
	if w.data.is_projectile() and dist < w.data.splash_radius * 0.9:
		return   # too close: it would blow itself up
	if w.data.is_projectile() and _lob != Vector3.INF:
		want = _lob - eye   # it aims off you on purpose: judge the aim against that point
	var off := me.aim_forward().angle_to(want)
	if w.data.is_melee():
		# In reach and roughly facing you: swing.
		if off < deg_to_rad(w.data.arc_degrees * 0.7) and w.can_fire() and _fire_wait <= 0.0:
			input.fire_pressed = true
			input.fire = true
			_fire_wait = d.fire_gap * _rng.randf_range(0.3, 0.7)
		return
	var allowed: float = max(atan(0.35 / max(dist, 0.1)), deg_to_rad(1.0))
	if w.data.id in ["sniper", "bolt_action", "railgun"]:
		allowed *= 0.6   # waits for a clean shot
	var on_target := off < allowed + deg_to_rad(d.aim_error) * 0.5
	if w.data.automatic:
		# Bursts: hold the trigger for a moment, then pause (longer on easier levels).
		if _burst > 0.0:
			_burst -= delta
			input.fire = on_target or _burst > 0.1
			if _burst <= 0.0:
				_fire_wait = d.fire_gap * _rng.randf_range(1.5, 2.6)
			return
		if on_target and _fire_wait <= 0.0:
			_burst = _rng.randf_range(0.35, 0.9)
			input.fire_pressed = true
			input.fire = true
		return
	if _fire_wait > 0.0:
		return
	if on_target:
		input.fire_pressed = true
		input.fire = true
		_fire_wait = maxf(d.fire_gap, w.data.fire_interval) * _rng.randf_range(0.85, 1.25)
