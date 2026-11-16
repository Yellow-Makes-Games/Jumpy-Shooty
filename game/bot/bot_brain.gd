class_name BotBrain
extends RefCounted
## The computer player's decisions. Each physics frame it fills in the bot's
## PlayerInput, exactly like the keyboard and mouse do for you, so a bot moves and
## shoots by the same rules as a person: same speeds, same gun, same hit checks.
##
## What it does:
##  - Finds you: walks the map's navigation mesh (ramps, decks, tower) to where it
##    last saw you, and after a few seconds it heads for where you really are.
##  - Fights: strafes side to side at a comfortable range, jumps, and turns its aim
##    toward you at a limited speed. It sees you with a delay (its reaction time)
##    and its aim wobbles; it leads moving targets and goes for headshots more on
##    higher difficulties.
##  - Uses the movement set: sprints, slides and bunny-hops while chasing, dives to
##    close distance, flips to dodge when hit, grapples toward high ground.
## How good it is at each of these comes from BotDifficulty.

const ENGAGE_RANGE := 45.0
const NEAR := 7.0          ## closer than this it backs off a little
const FAR := 18.0          ## further than this it closes in
const CHEST := 1.05        ## aim heights above the feet
const HEAD := 1.6
const HUNT_AFTER := 3.0    ## seconds without seeing you before it goes to where you really are

var me: Player
var d: BotDifficulty
var input: PlayerInput

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _target: Player
var _seen: Array = []            # [time, aim point, velocity] of the target, oldest first
var _last_seen_pos := Vector3.ZERO
var _last_seen_time := -99.0
var _path := PackedVector3Array()
var _path_index := 0
var _path_goal := Vector3.INF
var _repath := 0.0
var _strafe_dir := 1.0
var _strafe_timer := 0.0
var _error := Vector3.ZERO       # aim wobble, a slow random walk
var _go_head := false
var _head_timer := 0.0
var _fire_wait := 0.0
var _stuck_time := 0.0
var _escape_dir := Vector3.ZERO
var _escape_time := 0.0
var _slide_time := 0.0
var _hop_time := 0.0
var _trick_wait := 0.0
var _dodge_side := 0.0           # a flip dodge in progress: which way (-1 left, 1 right)
var _dodge_time := 0.0
var _grapple_time := 0.0
var _grapple_start := Vector3.ZERO
var _log_time := 0.0
var _last_state := -1
var _state_seen := {}


func _init(player: Player, level: int) -> void:
	me = player
	d = BotDifficulty.make(level)
	input = player.input
	_rng.randomize()
	Match.player_hit.connect(_on_hit)


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
	_target = _pick_target()
	var visible := _target != null and _can_see(_target)
	if visible:
		_seen.append([_time, _aim_point(_target), _target.velocity])
		_last_seen_pos = _target.global_position
		_last_seen_time = _time
	while not _seen.is_empty() and _seen[0][0] < _time - 2.0:
		_seen.pop_front()
	var perceived := _perceived() if visible else []

	var world_dir := _choose_direction(delta, visible)
	_grapple(delta, visible)
	_dodge(delta)
	_set_move(world_dir)
	_aim(delta, perceived, world_dir)
	_fire(delta, perceived)
	if DevArgs.sync_log:
		if me.motor.state != _last_state:
			_last_state = me.motor.state
			if _time - float(_state_seen.get(_last_state, -9.0)) > 0.5 and _last_state in [MovementController.State.DIVE, MovementController.State.FLIP,
					MovementController.State.GRAPPLE, MovementController.State.SLIDE,
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
	_path = PackedVector3Array()
	_path_goal = Vector3.INF
	input.grapple = false
	input.crouch = false
	_slide_time = 0.0
	_hop_time = 0.0
	_dodge_time = 0.0
	_grapple_time = 0.0


# ---------------------------------------------------------------------------
# Seeing

func _pick_target() -> Player:
	var best: Player = null
	var best_d := INF
	for p in me.get_parent().get_children():
		var other := p as Player
		if other == me or not other.alive:
			continue
		var dist := me.global_position.distance_to(other.global_position)
		if dist < best_d:
			best_d = dist
			best = other
	return best


func _can_see(p: Player) -> bool:
	var space := me.get_world_3d().direct_space_state
	var eye := me.eye_position()
	for h in [HEAD, CHEST]:
		var q := PhysicsRayQueryParameters3D.create(eye, p.global_position + Vector3(0, h, 0), 1, [me.get_rid()])
		if space.intersect_ray(q).is_empty():
			return true
	return false


## Where it aims on a target: chest, or head when it is going for headshots.
func _aim_point(p: Player) -> Vector3:
	var low: bool = p.motor.crouched if p.motor else Player.pose_crouched(p.pose_at(p.latest_time()))
	var h := (HEAD - 0.6 if low else HEAD) if _go_head else (CHEST - 0.3 if low else CHEST)
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
	if _escape_time > 0.0:
		_escape_time -= delta
		_unstick(delta, _escape_dir)
		return _escape_dir
	if _target == null:
		return Vector3.ZERO
	var dist := pos.distance_to(_target.global_position)
	var dir := Vector3.ZERO
	if visible and dist < ENGAGE_RANGE:
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
		dir = f.cross(Vector3.UP) * _strafe_dir * d.strafe + f * approach
		if _blocked(dir):
			_strafe_dir = -_strafe_dir
			dir = f.cross(Vector3.UP) * _strafe_dir * d.strafe + f * approach
		input.sprint = d.sprint and dist > FAR
		if grounded and _rng.randf() < d.jumpiness * delta * 2.5:
			input.jump_pressed = true
		# At the top of a jump, flip sideways to throw off your aim.
		if not grounded and absf(me.velocity.y) < 2.0 and _dodge_time <= 0.0 \
				and _rng.randf() < d.jumpiness * d.dodge_chance * delta * 6.0:
			_dodge_side = _strafe_dir
			_dodge_time = 0.3
		# Close the gap fast with a dive (it dives where it looks: at you).
		if d.grapples and grounded and dist > FAR + 4.0 and _rng.randf() < delta * 0.5:
			input.dive_pressed = true
	else:
		# Chase: to where it last saw you, or to where you really are after a while.
		var hunting := _time - _last_seen_time > HUNT_AFTER
		var goal := _target.global_position if hunting else _last_seen_pos
		dir = _follow_path(goal, delta)
		input.sprint = d.sprint
		_chase_tricks(delta, dir, grounded, speed)
	if _hop_time > 0.0:
		_hop_time -= delta
		if grounded:
			input.jump_pressed = true   # bunny-hop: jump again the moment it lands
	if _slide_time > 0.0:
		_slide_time -= delta
		input.crouch = true
	_unstick(delta, dir)
	return dir


## Once it is running fast it mixes in movement tricks: slides, bunny-hops, dives.
func _chase_tricks(delta: float, dir: Vector3, grounded: bool, speed: float) -> void:
	_trick_wait -= delta
	if not d.slides or not grounded or speed < 9.0 or _trick_wait > 0.0 or dir.length() < 0.1:
		return
	_trick_wait = _rng.randf_range(0.6, 1.6)
	var facing := Vector3(me.aim_forward().x, 0.0, me.aim_forward().z).normalized()
	var straight := facing.angle_to(dir) < deg_to_rad(15.0) and _straight_ahead(dir) > 8.0
	var roll := _rng.randf()
	if d.grapples and straight and roll < 0.3 and me.motor.state != MovementController.State.SLIDE:
		input.dive_pressed = true   # dives go where it looks, so only when looking where it runs
	elif roll < 0.6:
		_slide_time = 0.8
		input.crouch_pressed = true
	elif d.jumpiness >= 0.15:
		_hop_time = _rng.randf_range(0.8, 2.0)


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
		_path = NavigationServer3D.map_get_path(me.get_world_3d().navigation_map, pos, goal, true)
		_path_index = 1 if _path.size() > 1 else 0
	while _path_index < _path.size() and _flat(pos, _path[_path_index]) < 0.9:
		_path_index += 1
	var next := goal if _path_index >= _path.size() else _path[_path_index]
	var to := next - pos
	to.y = 0.0
	return to.normalized() if to.length() > 0.3 else Vector3.ZERO


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

func _on_hit(_shooter: int, target: int, _damage: float, _head: bool) -> void:
	if target != me.peer_id or not me.alive or _dodge_time > 0.0:
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
	if g.attached:
		_grapple_time += delta
		input.grapple = true
		# Let go once past the anchor and rising, or after a while.
		var passed := _flat(me.global_position, _grapple_start) > _flat(g.anchor, _grapple_start)
		if (passed and me.velocity.y > 0.0) or _grapple_time > 1.6:
			input.grapple = false
		return
	input.grapple = false
	if not d.grapples or _target == null or not g.ready_to_fire():
		return
	var dist := me.global_position.distance_to(_target.global_position)
	var higher := _target.global_position.y - me.global_position.y > 2.5
	if not (higher or (dist > 25.0 and not visible)) or _rng.randf() > delta * 1.5:
		return
	# Aim up and ahead, toward the target, and hook whatever is there.
	var eye := me.eye_position()
	var to := _target.global_position - me.global_position
	to.y = 0.0
	var point := me.global_position + to.normalized() * minf(dist, 18.0) + Vector3(0, 9.0, 0)
	var dir := (point - eye).normalized()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * g.tuning.grapple_range, 1, [me.get_rid()])
	var hit := me.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.position.y < me.global_position.y + 3.0:
		return
	input.yaw = atan2(-dir.x, -dir.z)
	input.pitch = asin(clamp(dir.y, -1.0, 1.0))
	input.grapple = true
	input.grapple_pressed = true
	_grapple_time = 0.0
	_grapple_start = me.global_position


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
		_error += Vector3(_rng.randfn(), _rng.randfn() * 0.6, _rng.randfn()) * delta * 2.0
		_error = _error.limit_length(1.0)
		target = point + _error * dist * tan(deg_to_rad(d.aim_error))
	elif _target != null and _time - _last_seen_time < 1.0:
		target = _last_seen_pos + Vector3(0, CHEST, 0)
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
	if w.ammo == 0 and not w.is_reloading():
		w.start_reload()
	if perceived.is_empty() or _fire_wait > 0.0 or not Match.running:
		return
	# Shoot when the view is close enough to where it wants to aim.
	var eye := me.eye_position()
	var want: Vector3 = (perceived[1] as Vector3) - eye
	var dist := want.length()
	var off := me.aim_forward().angle_to(want)
	var allowed: float = max(atan(0.35 / max(dist, 0.1)), deg_to_rad(1.0))
	if off < allowed + deg_to_rad(d.aim_error) * 0.5:
		input.fire_pressed = true
		input.fire = true
		_fire_wait = d.fire_gap * _rng.randf_range(0.85, 1.25)
