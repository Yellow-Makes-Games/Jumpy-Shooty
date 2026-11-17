class_name Player
extends CharacterBody3D
## A player in the arena. The same scene is used for:
##  - the local player: reads input, runs movement, fires, sends snapshots;
##  - remote players: shown from snapshots, smoothed by SnapshotBuffer.
##  - bots: simulated on the host like a local player, but input comes from a
##    BotBrain instead of the keyboard, and there is no camera.

const SEND_RATE := 40.0  ## snapshots per second (40 rather than 30 keeps fast grapple swings accurate on lossy networks)
const CAPSULE_RADIUS := 0.4
const CAPSULE_HEIGHT := 1.8
const VIEWMODEL_LAYER := 3   ## render layer for the first-person gun
const CROUCH_HEIGHT := 1.1
const PRONE_HEIGHT := 0.8    ## lying on your front (belly slide)
const TUCK_LIFT := CAPSULE_HEIGHT - CROUCH_HEIGHT

var peer_id := 1
var is_local := false   ## simulated on this machine (you, or a bot when hosting)
var is_bot := false
var brain: RefCounted   ## BotBrain in a fight, RaceBrain in a race (and for --autopilot)
var alive := true
var racing := false     ## this match is a race: no gun, no bumping into each other

var input := PlayerInput.new()
var motor: MovementController
var rig: CameraRig
var visual: Node3D
var buffer := SnapshotBuffer.new()   ## remote: received states; local: own recent states (for the host's rewind)
var weapon: WeaponState
## Time (on this player's clock) at which we are currently drawing them. Sent with shots.
var last_render_time := -1.0

var _send_timer := 0.0
var _scripted_time := 0.0
var _remote_state := 0
var _teleport_count := 0          # local: bumped on every respawn; remote: last seen value
var _awaiting_respawn := false    # remote: hidden until the first post-respawn snapshot
var robot: RobotModel             ## the body everyone sees
var animator: RobotAnimator
var view: ViewModel               ## first-person arms and gun (your own player only)
var sounds: PlayerSounds          ## footsteps, jumps, reloads... (see game/audio/)
var _anim := RobotAnimInput.new()
var _corpse_drop := 0.0           # a body shot in mid-air falls to the ground (visual only)
var _corpse_fall := 0.0
var _corpse_room := 0.0
var _logged_anim := ""            # --sync-log: the last animation we printed
var _fell_reported := false
var _fire_buffer := 0.0           # a click slightly too early still fires when the gun is ready
var _rope: MeshInstance3D         # the grapple line, drawn from the gun to the anchor
var _hook: MeshInstance3D         # the hook at the anchor
var _rope_events: Array = []      # remote: [time, attached, anchor] waiting to be shown
var _rope_on := false             # remote: is the rope shown
var _rope_anchor := Vector3.ZERO  # remote: where it is hooked
var _roll := 0.0                  # local: camera tilt while wall-running
var _shape: CollisionShape3D
var _height := CAPSULE_HEIGHT     # remote: collision shape height for the pose we draw
var _visual_yaw := 0.0
var _flying := false              # local: the debug menu's noclip is on
var _swings := 0                  # local: melee swings so far (travels in snapshots, wrapping at 4)
var _seen_swings := -1            # the swing count last shown (starts the swing animation and sound)
var _strike_left := -1.0          # local: seconds until the current swing's blow lands
var _slam_wait := 0.0             # local: a crash just hurt; the next can't for a moment
var _trail: SwingTrail            # the glowing smear behind a blade mid-blow (melee only)
var _punch := Vector2.ZERO        # own view: a quick jolt of the camera (yaw, pitch) from your own blows
var _punch_roll := 0.0
var _kicks := 0                   # local: kicks so far (travels in snapshots, wrapping at 4)
var _seen_kicks := -1
var _kick_cool := 0.0             # local: seconds until you can kick again
var _kick_strike := -1.0          # local: seconds until the kick lands
var _fly_kick := 0.0              # local: seconds left of a flying kick (0 = not flying)
var _fly_target: Player           # local: who the flying kick is going for
var _seen_flying := false
var _seen_boosts := -1
var _tether_id := 0               # local: the player your hook is on, as told to the host
var _tug_by := 0                  # local: someone has you hooked and is reeling you in
var _tug_left := 0.0
var _tug_fresh := false
var _flame: Node3D                # rocket-boot flames under the feet
var _flame_t := 0.0


func _init() -> void:
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	collision_layer = 1 << 1   # layer 2: players
	collision_mask = 1 | (1 << 1)


func setup(id: int, local: bool, bot: bool = false) -> void:
	peer_id = id
	is_local = local
	is_bot = bot
	name = "Player_%d" % id
	set_multiplayer_authority(id)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position.y = CAPSULE_HEIGHT * 0.5
	add_child(shape)
	_shape = shape

	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var character := Net.player_character(id)
	if DevArgs.sync_log:   # for tests/check_anim.py: which robot each copy shows for each player
		if local:
			print("CHAR SELF %d %s" % [id, character])
		else:
			print("CHAR SEEN %d %d %s" % [Net.my_id(), id, character])
	racing = Race.active
	if racing:
		collision_mask = 1   # racers pass through each other (a tunnel is never blocked)
	var gun := Net.player_weapon(id) if not racing else "none"
	if DevArgs.sync_log:   # which gun each copy shows each player holding
		print("GUN %s %d %d %s" % ["SELF" if local else "SEEN", Net.my_id(), id, gun])
	robot = RobotModel.new().setup(Characters.body(character), Net.player_color(id), false, gun)
	visual.add_child(robot)
	animator = RobotAnimator.new(robot)
	sounds = PlayerSounds.new(self, local and not bot, gun)
	if sounds.own and not racing:
		Sound.play("equip_" + gun)   # bringing your gun up as the match starts

	if is_bot:
		motor = MovementController.new()
		weapon = WeaponState.new(WeaponData.by_id(Net.player_weapon(id)))
		_apply_move_bonus()
		if racing:
			brain = RaceBrain.new(self, Net.players[id].get("difficulty", 1))
		else:
			brain = BotBrain.new(self, Net.players[id].get("difficulty", 1))
	elif is_local:
		motor = MovementController.new()
		weapon = WeaponState.new(WeaponData.by_id(Net.player_weapon(id)))
		_apply_move_bonus()
		if racing and DevArgs.autopilot:
			brain = RaceBrain.new(self, DevArgs.bot_level)
		rig = CameraRig.new()
		add_child(rig)
		rig.setup(self)
		robot.set_layer(CameraRig.BODY_LAYER)
		robot.add_view_mesh(CameraRig.VIEW_BODY_LAYER)
		view = ViewModel.new()
		rig.camera.add_child(view)
		view.setup(self, Net.player_color(id))
		view.visible = not racing   # no gun to hold in a race: you see your body, not arms
	_build_rope()
	_build_flame()
	if motor:
		motor.grapple.hook_players = not racing
	if WeaponData.melee(robot.weapon):
		_trail = SwingTrail.new().setup(RobotModel.trim_color(Net.player_color(id)))
		add_child(_trail)
	Match.melee_landed.connect(_on_melee_landed)


# ---------------------------------------------------------------------------
# Per-frame

func _physics_process(delta: float) -> void:
	if not is_local:
		return
	if is_bot:
		if Cheats.bots_frozen():
			_hold_still()
		else:
			brain.update(delta)
	elif brain:
		brain.update(delta)   # --autopilot
	elif DevArgs.scripted_input:
		_scripted_input(delta)
	else:
		read_local_input()
	if racing and Race.frozen():
		_hold_still()   # on the start line: you can look round, not move
		input.clear_edges()
	if alive:
		_set_crosshair_ray()
		var was_on := motor.grapple.attached
		var hooking := input.grapple_pressed and motor.grapple.ready_to_fire()
		var fly := Cheats.flying() and not is_bot
		if fly != _flying:
			_flying = fly
			motor.reset()
			velocity = Vector3.ZERO
		if fly:
			_fly(delta)
		else:
			_update_tug(delta)
			_steer_flying_kick(delta)
			var boosts := motor.boosts
			motor.step(self, input, delta)
			if hooking and not motor.grapple.attached:
				sounds.grapple_missed()   # nothing in range to hook
			if motor.boosts != boosts and DevArgs.sync_log:
				print("BOOST %d" % peer_id)
			_check_slam(delta)
		_report_tether()
		if Cheats.cooldowns_off() and not is_bot:
			motor.clear_cooldowns()
		if DevArgs.sync_log and motor.grapple.attached != was_on:
			print("ROPE SELF %d %s" % [peer_id, "on" if motor.grapple.attached else "off"])
		_visual_yaw = input.yaw
		if not racing:
			_update_weapon(delta)
			_update_kick(delta)
	else:
		velocity = Vector3.ZERO
		_report_tether()
	input.clear_edges()
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer += 1.0 / SEND_RATE
		var now := Net.now()
		if not is_bot:
			Net.send_snapshot(now, make_snapshot())
		buffer.push(now, now, _sent_position(), velocity, input.yaw, input.pitch, _my_pose(), _my_anim_flags())
	if DevArgs.sync_log:
		var sp := _sent_position()  # without the leg tuck, which is a pose, not movement
		print("SYNC SELF %d %.4f %.4f %.4f %.4f %d %.2f %.2f %.2f" % [peer_id, Net.now(), sp.x, sp.y, sp.z, _my_pose(), velocity.x, velocity.y, velocity.z])


func _process(delta: float) -> void:
	if is_local:
		if rig:
			_roll = lerp(_roll, _target_roll(), min(delta * 8.0, 1.0))
			_punch = _punch.lerp(Vector2.ZERO, 1.0 - exp(-delta * 14.0))
			_punch_roll = lerpf(_punch_roll, 0.0, 1.0 - exp(-delta * 12.0))
			rig.set_view(input.yaw + _punch.x, clampf(input.pitch + _punch.y, deg_to_rad(-89.0), deg_to_rad(89.0)),
				motor.eye_height, _roll + _punch_roll)
		var g := motor.grapple
		_anim.state = motor.state
		_anim.crouched = motor.crouched
		_anim.velocity = velocity
		_anim.pitch = input.pitch
		_anim.flags = _my_anim_flags()
		_anim.grapple_on = g.attached
		_anim.grapple_anchor = g.anchor
		_watch_swings()
		_watch_kicks()
		_animate(delta)
		sounds.update(delta, _anim, true)
		if view:
			view.update(delta)
		_draw_rope(g.attached and alive, g.anchor)
		_update_trail(delta)
		_update_flame(delta)
		return
	if not buffer.has_data():
		return
	var rt := buffer.render_time(Net.now(), delta)
	last_render_time = rt
	var s := buffer.sample(rt)
	global_position = s[0] + Vector3(0, tuck_offset(s[4]), 0)
	velocity = s[1]
	if alive:
		_visual_yaw = s[2]
	_remote_state = s[4]
	_update_pose(height_for_pose(_remote_state))
	_anim.state = pose_state(_remote_state)
	_anim.crouched = pose_crouched(_remote_state)
	_anim.velocity = velocity
	_anim.pitch = s[3]
	_anim.flags = s[5]
	_anim.grapple_on = _rope_on
	_anim.grapple_anchor = _rope_anchor
	_watch_swings()
	_watch_kicks()
	_animate(delta)
	sounds.update(delta, _anim, visual.visible)
	while not _rope_events.is_empty() and _rope_events[0][0] <= rt:
		var ev: Array = _rope_events.pop_front()
		_rope_on = ev[1]
		_rope_anchor = ev[2]
		if DevArgs.sync_log:
			print("ROPE SEEN %d %d %s" % [Net.my_id(), peer_id, "on" if _rope_on else "off"])
	_draw_rope(_rope_on and alive and not _awaiting_respawn, _rope_anchor)
	_update_trail(delta)
	_update_flame(delta)
	if DevArgs.sync_log and alive and not _awaiting_respawn:
		var sp: Vector3 = s[0]
		print("SYNC SEEN %d %d %.4f %.4f %.4f %.4f %.4f" % [Net.my_id(), peer_id, rt, sp.x, sp.y, sp.z, delta])


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or is_bot or DevArgs.scripted_input:
		return  # only your own player listens to the keyboard and mouse (a bot is local too)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := deg_to_rad(Settings.mouse_sensitivity)
		input.yaw -= event.relative.x * sens
		var dy: float = event.relative.y * sens * (-1.0 if Settings.invert_y else 1.0)
		input.pitch = clamp(input.pitch - dy, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("toggle_camera"):
		Settings.set_third_person(not Settings.third_person)
	elif event.is_action_pressed("reload") and racing:
		Race.send_back(self, "reset")   # stuck? back to your last checkpoint
	elif event.is_action_pressed("reload") and weapon:
		weapon.start_reload()
	elif not alive and not racing:
		_pick_on_death(event)


## Waiting to respawn: 1-7 (or the mouse wheel) picks the weapon you come back with.
func _pick_on_death(event: InputEvent) -> void:
	var ids := WeaponData.IDS
	var current := ids.find(Net.player_weapon(peer_id))
	var pick := -1
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode - KEY_1
		if k >= 0 and k < ids.size():
			pick = k
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pick = (current + 1) % ids.size()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			pick = (current - 1 + ids.size()) % ids.size()
	if pick < 0 or pick == current or alive:
		return
	if DevArgs.sync_log:
		print("SWAP %d %s" % [peer_id, ids[pick]])
	if not DevArgs.swap_on_death:
		Settings.weapon = ids[pick]
		Settings.save_settings()
	Sound.play("equip_" + ids[pick])
	Net.set_my_weapon(ids[pick])


## Reads keyboard and mouse into `input`. Mouse look arrives in _unhandled_input.
func read_local_input() -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DevArgs.drives_keys
	if not captured:
		input.move = Vector2.ZERO
		input.sprint = false
		input.jump_held = false
		input.fire = false
		input.grapple = false
		input.dive = false
		return
	if Input.is_action_just_pressed("kick"):
		input.kick_pressed = true
	if Input.is_action_just_pressed("boost"):
		input.boost_pressed = true
	input.move = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"))
	input.sprint = Input.is_action_pressed("sprint")
	input.crouch = Input.is_action_pressed("crouch")
	if Input.is_action_just_pressed("crouch"):
		input.crouch_pressed = true
	input.jump_held = Input.is_action_pressed("jump")
	input.fire = Input.is_action_pressed("fire")
	if Input.is_action_just_pressed("fire"):
		input.fire_pressed = true
	if Input.is_action_just_pressed("jump"):
		input.jump_pressed = true
	input.dive = Input.is_action_pressed("dive")
	if Input.is_action_just_pressed("dive"):
		input.dive_pressed = true
	input.grapple = Input.is_action_pressed("grapple")
	if Input.is_action_just_pressed("grapple"):
		input.grapple_pressed = true


## In third person, the grapple aims along the crosshair from the camera.
func _set_crosshair_ray() -> void:
	if rig and rig.is_third_person():
		var cam := rig.camera.global_transform
		input.aim_origin = cam.origin
		input.aim_dir = -cam.basis.z
	else:
		input.aim_origin = Vector3.ZERO
		input.aim_dir = Vector3.ZERO


# ---------------------------------------------------------------------------
# Shooting

func _update_weapon(delta: float) -> void:
	weapon.update(delta)
	if Cheats.ammo() and not is_bot:
		weapon.ammo = weapon.data.magazine
	if input.fire_pressed:
		_fire_buffer = 0.1
	else:
		_fire_buffer = max(_fire_buffer - delta, 0.0)
	if weapon.data.is_melee():
		_update_melee(delta)
		return
	var wants: bool = input.fire if weapon.data.automatic else _fire_buffer > 0.0
	if not wants or not Match.running:
		return
	if not weapon.fire():
		if input.fire_pressed and weapon.ammo <= 0 and sounds.own:
			Sound.play("dry_click", 0.0, 0.03)   # empty: the gun clicks while it reloads
		return
	_fire_buffer = 0.0
	Sound.gun_fire(weapon.data.id, muzzle_position(), sounds.own)
	sounds.fired()
	animator.fire()
	if DevArgs.sync_log:
		print("ANIM FIRE %d" % peer_id)
	if view:
		view.fire()
	var eye := eye_position()
	var dirs := shot_directions(_aim_direction(eye), weapon.data)
	# Show the shot straight away; the host decides whether it hit.
	var ends := PackedVector3Array()
	var hits := []
	var space := get_world_3d().direct_space_state
	for dir in dirs:
		var end := eye + dir * weapon.data.max_range
		var ray := PhysicsRayQueryParameters3D.create(eye, end, 1 | (1 << 1), [get_rid()])
		var hit := space.intersect_ray(ray)
		if hit:
			end = hit.position
		ends.append(end)
		hits.append(hit and (hit.collider is Player or hit.collider is TargetDummy))
	ShotFx.spawn(get_parent().get_parent(), muzzle_position(), ends, hits, weapon.data.id)  # into the arena, not among the players
	Sound.shot_landed(muzzle_position(), ends, hits, sounds.own)
	var view_times := {}
	for p in get_parent().get_children():
		if p != self and p is Player and p.last_render_time >= 0.0:
			view_times[p.peer_id] = p.last_render_time
	Match.request_shot(eye, dirs, view_times, weapon.data.id, peer_id)


# ---------------------------------------------------------------------------
# Melee

## Swinging a blade or hammer: the click starts the swing (and a small lunge), and
## the blow lands after the weapon's wind-up. The host decides what it hit.
func _update_melee(delta: float) -> void:
	var data := weapon.data
	if _strike_left >= 0.0:
		_strike_left -= delta
		if _strike_left < 0.0:
			_strike()
	if motor.grapple.hooked_player() or _fly_kick > 0.0:
		return   # a player on your hook: the swing button is a flying kick (see _update_kick)
	var wants := input.fire or _fire_buffer > 0.0
	if not wants or not Match.running or _strike_left >= 0.0 or not weapon.fire():
		return
	_fire_buffer = 0.0
	_swings += 1
	_strike_left = MeleeSwing.impact_time(data.id)   # when the blade is mid-blow on screen
	# Lunge toward where you look (never past a sprinting dive's speed).
	var ahead := Vector3.FORWARD.rotated(Vector3.UP, input.yaw)
	var along := velocity.dot(ahead)
	if data.lunge > 0.0 and along < 14.0:
		motor.knock(ahead * minf(data.lunge, 14.0 - along))
	if DevArgs.sync_log:
		print("ANIM SWING %d" % peer_id)


func _strike() -> void:
	if not alive:
		return
	if rig:   # your own blow: the view jolts the way the blade travels
		var side := 0.0 if robot.weapon == "hammer" else (1.0 if _swings % 2 == 1 else -1.0)
		_punch += Vector2(side * 0.035, -0.03 if robot.weapon == "hammer" else -0.012)
		_punch_roll += side * 0.03
	var eye := eye_position()
	var view_times := {}
	for p in get_parent().get_children():
		if p != self and p is Player and p.last_render_time >= 0.0:
			view_times[p.peer_id] = p.last_render_time
	Match.request_melee(eye, aim_forward(), view_times, peer_id)


## A new swing (yours, or one seen in someone's snapshots): animation and whoosh.
func _watch_swings() -> void:
	var count := _swings & 3 if is_local else RobotAnimInput.swings_of(_anim.flags)
	if _seen_swings < 0:
		_seen_swings = count   # just appeared: no swing to replay
		return
	if count == _seen_swings:
		return
	_seen_swings = count
	if not alive or robot.weapon == "none" or not WeaponData.melee(robot.weapon):
		return
	animator.swing(count)
	if view:
		view.swing(count)
	if sounds.own:
		Sound.play("swing_" + robot.weapon, 0.0, 0.05)
	elif visual.visible:
		Sound.play_at("swing_" + robot.weapon, global_position + Vector3(0, 1.3, 0), "move", 0.0, 0.05)


## A blow landed somewhere. Ours: the swing freezes for a moment (hit-stop) and the view jolts harder.
func _on_melee_landed(attacker: int, weapon_id: String, points: PackedVector3Array) -> void:
	if attacker != peer_id or points.is_empty():
		return
	if weapon_id == "kick" or weapon_id == "flying_kick":
		if rig:
			_punch += Vector2(randf_range(-0.02, 0.02), -0.05 if weapon_id == "flying_kick" else -0.025)
			_punch_roll += randf_range(-0.03, 0.03)
		return
	animator.hit_stop()
	if view:
		view.hit_stop()
	if rig:
		_punch += Vector2(randf_range(-0.012, 0.012), -0.02)


# ---------------------------------------------------------------------------
# Kick, flying kick (see Kick) and being reeled in by someone's hook

## F: a quick front kick, whatever you carry. With a player on your hook it is a
## flying kick instead (so is a melee weapon's swing).
func _update_kick(delta: float) -> void:
	_kick_cool = maxf(_kick_cool - delta, 0.0)
	if _kick_strike >= 0.0:
		_kick_strike -= delta
		if _kick_strike < 0.0:
			_kick_strike = -1.0
			if alive:
				_send_kick(aim_forward(), false)
	if not Match.running:
		return
	var g := motor.grapple
	var swing_kick := weapon != null and weapon.data.is_melee() and input.fire_pressed
	if g.hooked_player() and (input.kick_pressed or swing_kick) and _fly_kick <= 0.0:
		_start_flying_kick(g.target as Player)
		return
	if not input.kick_pressed or _kick_cool > 0.0 or _kick_strike >= 0.0 or _fly_kick > 0.0:
		return
	_kick_cool = Kick.COOLDOWN
	_kick_strike = Kick.WINDUP
	_kicks += 1
	var ahead := Vector3.FORWARD.rotated(Vector3.UP, input.yaw)
	if velocity.dot(ahead) < 10.0:
		motor.knock(ahead * Kick.LUNGE)
	if DevArgs.sync_log:
		print("ANIM KICK %d" % peer_id)


func kick_readiness() -> float:
	return 1.0 - _kick_cool / Kick.COOLDOWN


## Let go of the rope and fly at them feet first.
func _start_flying_kick(target: Player) -> void:
	motor.grapple.release()
	motor.grapple.cooldown_left = 0.0   # the kick is the payoff: the hook is ready again after it
	_fly_target = target
	_fly_kick = Kick.FLYING_TIME
	_kicks += 1
	_kick_cool = Kick.COOLDOWN
	var to := Grapple.target_point(target) - (global_position + Vector3(0, 1.1, 0))
	velocity = to.normalized() * maxf(velocity.length(), Kick.FLYING_SPEED)
	if DevArgs.sync_log:
		print("FLYING_KICK %d %d" % [peer_id, target.peer_id])


## While flying: bend toward them, and land the kick when close enough.
func _steer_flying_kick(delta: float) -> void:
	if _fly_kick <= 0.0:
		return
	_fly_kick -= delta
	var t := _fly_target
	if t == null or not is_instance_valid(t) or not t.alive or not t.visible_in_world():
		_fly_kick = 0.0
		return
	var to := Grapple.target_point(t) - (global_position + Vector3(0, 1.1, 0))
	if to.length() <= Kick.FLYING_REACH - 0.6:
		_fly_kick = 0.0
		_send_kick(to.normalized(), true)
		return
	var speed := maxf(velocity.length(), Kick.FLYING_SPEED)
	velocity = velocity.lerp(to.normalized() * speed, minf(Kick.FLYING_STEER * delta, 1.0))
	if _fly_kick <= 0.0:
		_send_kick(to.normalized(), true)   # ran out of time: one last try (the host checks the reach)


func flying_kick() -> bool:
	return _fly_kick > 0.0


func _send_kick(dir: Vector3, flying: bool) -> void:
	if rig:
		_punch += Vector2(0.0, -0.03)
	var view_times := {}
	for p in get_parent().get_children():
		if p != self and p is Player and p.last_render_time >= 0.0:
			view_times[p.peer_id] = p.last_render_time
	Match.request_kick(eye_position(), dir, view_times, flying, peer_id)


## Tell the host when the hook catches a player or lets go (they get reeled in too).
func _report_tether() -> void:
	var g := motor.grapple
	var now := (g.target as Player).peer_id if alive and g.hooked_player() and g.target is Player else 0
	if now == _tether_id:
		return
	if _tether_id != 0:
		Match.request_tether(_tether_id, false, peer_id)
	_tether_id = now
	if now != 0:
		Match.request_tether(now, true, peer_id)
		if DevArgs.sync_log:
			print("TETHER %d %d" % [peer_id, now])


## Someone hooked you (the host says so): you are dragged toward them.
func tug(by: int, on: bool) -> void:
	if not on:
		if by == _tug_by:
			_tug_by = 0
		return
	if not alive or _flying or motor == null:
		return
	_tug_by = by
	_tug_left = motor.tuning.tether_time + 0.3
	_tug_fresh = true
	if DevArgs.sync_log:
		print("TUGGED %d by %d" % [peer_id, by])


func _update_tug(delta: float) -> void:
	if _tug_by == 0:
		return
	_tug_left -= delta
	var other: Player = Net.arena.get_player(_tug_by) if Net.arena else null
	if _tug_left <= 0.0 or other == null or not other.alive:
		_tug_by = 0
		return
	var to := other.global_position - global_position
	var dist := to.length()
	var t := motor.tuning
	if dist < t.tether_meet:
		_tug_by = 0
		return
	var dir := to / dist
	var push := Vector3.ZERO
	var room := t.tug_speed - velocity.dot(dir)
	if room > 0.0:
		push = dir * minf(t.tug_accel * delta, room)
	if _tug_fresh:
		_tug_fresh = false
		push.y = maxf(push.y, t.tug_lift)   # yanked off your feet
	if push != Vector3.ZERO:
		motor.knock(push)


func being_tugged() -> bool:
	return _tug_by != 0


## Alive and drawn: something a hook or a kick can find.
func visible_in_world() -> bool:
	return alive and visual.visible and collision_layer != 0


## A new kick or rocket burst (yours, or one seen in someone's snapshots): the leg
## swings and whooshes; the boots flare.
func _watch_kicks() -> void:
	var count := _kicks & 3 if is_local else RobotAnimInput.kicks_of(_anim.flags)
	var flying := flying_kick() if is_local else RobotAnimInput.flying_of(_anim.flags)
	var boosts := (motor.boosts & 3) if is_local else RobotAnimInput.boosts_of(_anim.flags)
	if _seen_kicks < 0:
		_seen_kicks = count
		_seen_boosts = boosts
		_seen_flying = flying
		return
	if boosts != _seen_boosts:
		_seen_boosts = boosts
		if DevArgs.sync_log and not is_local:
			print("BOOST SEEN %d %d" % [Net.my_id(), peer_id])
		if alive and visual.visible:
			_flame_t = 0.45
			if sounds.own:
				Sound.play("rocket_boost", 0.0, 0.05)
			else:
				Sound.play_at("rocket_boost", global_position + Vector3(0, 0.3, 0), "move", 0.0, 0.05)
	if flying != _seen_flying:
		_seen_flying = flying
		animator.set_flying_kick(flying and alive)
	if count == _seen_kicks:
		return
	_seen_kicks = count
	if not alive:
		return
	animator.kick(flying)
	if DevArgs.sync_log and not is_local:
		print("KICK SEEN %d %d%s" % [Net.my_id(), peer_id, " flying" if flying else ""])
	var sound := "kick" if not flying else "flying_kick"
	if sounds.own:
		Sound.play(sound, 0.0, 0.05)
	elif visual.visible:
		Sound.play_at(sound, global_position + Vector3(0, 1.0, 0), "move", 0.0, 0.05)


## The glowing trail behind the blade while it cuts: on your first-person arms
## when you are looking through them, otherwise on the body.
func _update_trail(delta: float) -> void:
	if _trail == null:
		return
	var own_view := view != null and rig != null and not rig.is_third_person()
	if own_view and view.visible and view.cutting():
		var e := view.edge()
		_trail.add(e[0], e[1])
	elif not own_view and alive and visual.visible and animator.cutting() and robot.melee:
		var e := MeleeModel.edge(robot.melee)
		_trail.add(e[0], e[1])
	_trail.tick(delta)


## A hit or shove from the host: knocked along, and off your feet if it lifts you.
func knock(push: Vector3) -> void:
	if motor and alive and not _flying:
		motor.knock(push)
		if DevArgs.sync_log:
			print("KNOCK %d %.1f" % [peer_id, push.length()])


## Hit a wall or prop too fast? The host decides how much it hurts.
func _check_slam(delta: float) -> void:
	_slam_wait = maxf(_slam_wait - delta, 0.0)
	if racing or _slam_wait > 0.0 or motor.impact_speed < Match.SLAM_SPEED or not Match.running:
		return
	if (motor.since_boost < 0.4 or _fly_kick > 0.0) and not being_tugged():
		return   # your own rocket burst or flying kick into a wall doesn't hurt you
	_slam_wait = 0.5
	Match.request_slam(motor.impact_speed, motor.impact_point, peer_id)


## A light blade lets you run a little faster.
func _apply_move_bonus() -> void:
	var bonus := weapon.data.move_bonus if not racing else 1.0
	if bonus != 1.0:
		motor.tuning.run_speed *= bonus
		motor.tuning.sprint_speed *= bonus
		motor.tuning.air_speed *= bonus


## The directions of one shot's pellets (one for most guns), spread at random
## around `aim` by the gun's spread. A shotgun's pellets fill its cone evenly.
static func shot_directions(aim: Vector3, data: WeaponData) -> PackedVector3Array:
	var out := PackedVector3Array()
	var spread := deg_to_rad(data.spread_degrees)
	var side := aim.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	var up := side.cross(aim).normalized()
	for i in data.pellets:
		if data.pellets == 1:
			var d := aim.rotated(side, randf_range(-spread, spread))
			out.append(d.rotated(Vector3.UP, randf_range(-spread, spread)).normalized())
			continue
		# Pellets spread over a disc: one in the middle, the rest in rings, each nudged at random.
		var angle := TAU * (float(i) / data.pellets) + randf_range(-0.3, 0.3)
		var r := spread * (0.0 if i == 0 else sqrt(randf_range(0.25, 1.0)))
		var off := (side * cos(angle) + up * sin(angle)) * tan(r)
		out.append((aim + off).normalized())
	return out


func eye_position() -> Vector3:
	return global_position + Vector3(0, motor.eye_height if motor else CameraRig.EYE_HEIGHT, 0)


func aim_forward() -> Vector3:
	return Basis.from_euler(Vector3(input.pitch, input.yaw, 0.0)) * Vector3.FORWARD


## In third person the camera sits behind the shoulder, so we find what the crosshair
## points at from the camera, then shoot at that point from the eyes.
func _aim_direction(eye: Vector3) -> Vector3:
	var forward := aim_forward()
	if rig == null or not rig.is_third_person():
		return forward
	var cam := rig.camera.global_transform
	var from := cam.origin
	var to := from - cam.basis.z * weapon.data.max_range
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1 | (1 << 1), [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var target: Vector3 = hit.position if hit else to
	var dir := (target - eye).normalized()
	return dir if dir.dot(forward) > 0.2 else forward


func muzzle_position() -> Vector3:
	if view and not rig.is_third_person():
		return view.marker(WeaponData.by_id(robot.weapon).muzzle_bone)
	return robot.muzzle()


## Where the grapple rope leaves the robot: the launcher on its left wrist.
func rope_origin() -> Vector3:
	if view and not rig.is_third_person():
		return view.marker("grapple")
	return robot.marker("grapple")


## Another player's shot, as told by the host: kick their gun.
func show_shot() -> void:
	animator.fire()
	Sound.gun_fire(robot.weapon, muzzle_position(), false)
	sounds.fired()
	if DevArgs.sync_log:
		print("ANIM SHOT %d %d" % [Net.my_id(), peer_id])


# ---------------------------------------------------------------------------
# Life and death

## --swap-on-death (tests): just died, so press the next weapon's number key.
func dev_swap_after_death() -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1 + (WeaponData.IDS.find(Net.player_weapon(peer_id)) + 1) % WeaponData.IDS.size()
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_pick_on_death(key))


func set_dead() -> void:
	alive = false
	_fly_kick = 0.0
	_tug_by = 0
	_flame_t = 0.0
	if motor:
		motor.reset()
	_rope_on = false
	collision_layer = 0
	# The body stays where it fell and powers down. Shot in mid-air, it drops to the ground.
	_corpse_drop = 0.0
	_corpse_fall = 0.0
	var below := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, -80.0, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(below) if is_inside_tree() else {}
	_corpse_room = maxf(global_position.y - hit.position.y, 0.0) if hit else 200.0
	if not is_local and not buffer.has_data():
		visual.visible = false   # joined while they were dead: nothing to show yet


## Local player: come back at a spawn point.
func respawn_at(pos: Vector3, yaw: float) -> void:
	teleport(pos, yaw)
	_teleport_count += 1
	_fell_reported = false
	alive = true
	visual.visible = true
	collision_layer = 1 << 1
	animator.respawn()
	sounds.respawned()
	if view:
		view.respawn()
	if weapon:
		weapon.reset()
	_strike_left = -1.0
	_kick_strike = -1.0
	_kick_cool = 0.0
	_fly_kick = 0.0
	_tug_by = 0
	_send_timer = 0.0  # tell everyone at once


func respawn_count() -> int:
	return _teleport_count


func set_respawn_count(n: int) -> void:
	_teleport_count = n


## Remote player rebuilt while dead (they swapped weapons): hidden until they respawn.
func expect_dead() -> void:
	visual.visible = false


## Remote player: alive again, but stay hidden until their new position arrives.
func expect_respawn() -> void:
	alive = true
	_awaiting_respawn = true
	visual.visible = false
	sounds.respawned()


func report_fell_once() -> void:
	if racing:
		Race.send_back(self, "fell")
		return
	if not _fell_reported and alive:
		_fell_reported = true
		Match.request_fell(peer_id)


# ---------------------------------------------------------------------------
# Network state

## Snapshot layout: position (3), velocity (3), yaw, pitch, movement state,
## respawn count, grapple attached (0/1), grapple anchor (3), animation flags
## (see RobotAnimInput.make_flags).
func make_snapshot() -> PackedFloat32Array:
	var p := _sent_position()
	var v := velocity
	var g := motor.grapple
	var a := g.anchor
	return PackedFloat32Array([p.x, p.y, p.z, v.x, v.y, v.z, input.yaw, input.pitch,
		float(_my_pose()), float(_teleport_count), 1.0 if g.attached else 0.0, a.x, a.y, a.z,
		float(_my_anim_flags())])


func apply_snapshot(remote_time: float, data: PackedFloat32Array) -> void:
	if data.size() < 10:
		return
	var count := int(data[9])
	if count != _teleport_count:
		_teleport_count = count
		buffer.clear_history()  # never blend across a respawn
		if _awaiting_respawn:
			_awaiting_respawn = false
			if alive:
				visual.visible = true
				collision_layer = 1 << 1
				animator.respawn()
	buffer.push(remote_time, Net.now(),
		Vector3(data[0], data[1], data[2]), Vector3(data[3], data[4], data[5]),
		data[6], data[7], int(data[8]), int(data[14]) if data.size() >= 15 else 0)
	if data.size() >= 14:
		var on := data[10] > 0.5
		var anchor := Vector3(data[11], data[12], data[13])
		var last_on: bool = _rope_events[-1][1] if not _rope_events.is_empty() else _rope_on
		var last_anchor: Vector3 = _rope_events[-1][2] if not _rope_events.is_empty() else _rope_anchor
		if on != last_on or (on and anchor.distance_squared_to(last_anchor) > 0.01):
			_rope_events.append([remote_time, on, anchor])


func latest_position() -> Vector3:
	if not buffer.has_data():
		return global_position
	var last = buffer.snaps[-1]
	return last.pos + Vector3(0, tuck_offset(last.state), 0)


## Newest known velocity: from snapshots, or the body's own for a player with none.
func latest_velocity() -> Vector3:
	if not buffer.has_data():
		return velocity
	return buffer.snaps[-1].vel


func latest_time() -> float:
	return buffer.snaps[-1].t if buffer.has_data() else Net.now()


## Movement state, crouch and leg tuck packed into one number for snapshots:
## state + 100 if crouched + 1000 x the tuck in centimetres.
static func make_pose(state: int, crouched: bool, tuck: float = 0.0) -> int:
	return state + (100 if crouched else 0) + 1000 * int(round(tuck * 100.0))


static func pose_state(pose: int) -> int:
	return pose % 100


static func pose_crouched(pose: int) -> bool:
	return (pose / 100) % 10 == 1


## Tucking the legs in the air lifts the feet without moving the head. Snapshots
## carry the feet as if not tucked (so the position never jumps) plus this offset.
static func tuck_offset(pose: int) -> float:
	return (pose / 1000) / 100.0


func _my_pose() -> int:
	return make_pose(motor.state, motor.crouched, motor.tuck)


func _sent_position() -> Vector3:
	return global_position - Vector3(0, motor.tuck, 0)


## Body height for a pose (shorter when crouched, shortest on your belly): used for the hitbox.
static func height_for_pose(pose: int) -> float:
	if pose_state(pose) == MovementController.State.BELLY_SLIDE:
		return PRONE_HEIGHT
	return CROUCH_HEIGHT if pose_crouched(pose) else CAPSULE_HEIGHT


## Which way this player faced at time t (on this player's clock): for stabs in the back.
func yaw_at(t: float) -> float:
	return buffer.sample(t)[2] if buffer.has_data() else input.yaw


## Was this player crouched at time t (on this player's clock)?
func pose_at(t: float) -> int:
	return buffer.sample(t)[4] if buffer.has_data() else (_my_pose() if motor else 0)


## Remote players: shrink the collision shape when they crouch or lie down. (Your
## own shape is handled by the movement code.) The drawn body follows through its animation.
func _update_pose(h: float) -> void:
	if is_equal_approx(h, _height):
		return
	_height = h
	(_shape.shape as CapsuleShape3D).height = h
	_shape.position.y = h * 0.5


## The small animation facts that travel in snapshots (see RobotAnimInput.make_flags).
func _my_anim_flags() -> int:
	var right := Vector3.RIGHT.rotated(Vector3.UP, input.yaw)
	var wall := motor.wall_normal if motor.state == MovementController.State.WALL_RUN else motor.kick_wall
	var flip := RobotAnimInput.FLIP_BACK
	var f := motor.flip_dir
	if absf(f.x) > absf(f.y):
		flip = RobotAnimInput.FLIP_RIGHT if f.x > 0.0 else RobotAnimInput.FLIP_LEFT
	elif f.y > 0.0:
		flip = RobotAnimInput.FLIP_FRONT
	return RobotAnimInput.make_flags(wall.dot(right) < 0.0, motor.is_vaulting(),
		weapon != null and weapon.is_reloading(), flip, motor.wall_jumps, _swings,
		_kicks, _fly_kick > 0.0, motor.boosts)


## Turns the body to face its yaw and plays its animation.
func _animate(delta: float) -> void:
	if not alive and _corpse_drop < _corpse_room:
		_corpse_fall += 22.0 * delta
		_corpse_drop = minf(_corpse_drop + _corpse_fall * delta, _corpse_room)
	elif alive:
		_corpse_drop = 0.0
	visual.transform = Transform3D(Basis(Vector3.UP, _visual_yaw), Vector3(0, -_corpse_drop, 0))
	_anim.alive = alive
	_anim.yaw = _visual_yaw
	var first_person := rig.first_person_amount() if rig and alive else 0.0
	animator.first_person = first_person > 0.0
	animator.update(delta, _anim, visual.global_transform)
	if rig:
		animator.place_for_view(first_person, motor.eye_height, input.pitch)
	if DevArgs.sync_log:
		_log_animation()


## For tests/check_anim.py: prints the animation this body shows whenever it changes.
## Your own player and the bot print what they are doing (SELF); every other player
## prints what this copy of the game draws for them (SEEN).
func _log_animation() -> void:
	var shown := animator.source + ("+reload" if alive and _anim.reloading() else "")
	if shown == _logged_anim or not visual.visible:
		return
	_logged_anim = shown
	_print_animation(shown)


func _print_animation(shown: String) -> void:
	if is_local:
		print("ANIM SELF %d %.4f %s" % [peer_id, Net.now(), shown])
	elif buffer.has_data():
		print("ANIM SEEN %d %d %.4f %s" % [Net.my_id(), peer_id, last_render_time, shown])


func _exit_tree() -> void:
	if DevArgs.sync_log and _logged_anim != "":
		_print_animation("-")  # this body is gone (match over, or the player left)


## Lean the camera away from the wall while wall-running.
func _target_roll() -> float:
	if motor.state != MovementController.State.WALL_RUN:
		return 0.0
	var right := Vector3.RIGHT.rotated(Vector3.UP, input.yaw)
	return -motor.wall_normal.dot(right) * deg_to_rad(7.0)


## Where this player's feet were at time t (on this player's clock).
func position_at(t: float) -> Vector3:
	if not buffer.has_data():
		return global_position
	var s := buffer.sample(t)
	return s[0] + Vector3(0, tuck_offset(s[4]), 0)


func teleport(pos: Vector3, yaw: float) -> void:
	_fly_kick = 0.0
	_tug_by = 0
	if motor:
		motor.reset()
	global_position = pos
	velocity = Vector3.ZERO
	input.yaw = yaw
	input.pitch = 0.0


# ---------------------------------------------------------------------------
# Debug menu cheats (offline only, see Cheats)

## Noclip: fly through everything. WASD moves along the view, Space up, Ctrl / C down, Shift faster.
func _fly(delta: float) -> void:
	var look := Basis.from_euler(Vector3(input.pitch, input.yaw, 0.0))
	var dir := look * Vector3(input.move.x, 0.0, -input.move.y)
	if input.jump_held:
		dir += Vector3.UP
	if input.crouch:
		dir += Vector3.DOWN
	velocity = dir.limit_length(1.0) * (32.0 if input.sprint else 12.0)
	global_position += velocity * delta
	motor.state = MovementController.State.AIR


## A frozen bot: stands where it is and holds fire (it still falls and can be shot).
func _hold_still() -> void:
	input.move = Vector2.ZERO
	input.sprint = false
	input.jump_held = false
	input.crouch = false
	input.dive = false
	input.grapple = false
	input.fire = false
	input.kick_pressed = false
	input.boost_pressed = false


# ---------------------------------------------------------------------------
# Scripted input for automated tests

func _scripted_input(delta: float) -> void:
	_scripted_time += delta
	var t := _scripted_time
	input.move = Vector2(0.0, 1.0)
	input.yaw = sin(t * 0.7) * 2.2 + t * 0.6
	input.sprint = fmod(t, 4.0) < 2.0
	if fmod(t, 1.7) < delta:
		input.jump_pressed = true
	if fmod(t + 1.3, 3.4) < delta:
		input.jump_pressed = true   # mid-air: flip
	if fmod(t + 2.5, 5.3) < delta:
		input.dive_pressed = true
	input.dive = fmod(t + 7.8, 10.6) < 1.4   # every other dive: keep holding it, to land in a belly slide
	# Crouch (or slide, when fast) for a moment every 7 s.
	var was_crouching := input.crouch
	input.crouch = fmod(t, 7.0) > 5.8
	input.crouch_pressed = input.crouch and not was_crouching
	input.fire = false
	# Every 5 s, swing from a high point in the middle for a moment (tests the grapple online).
	var swing_phase := fmod(t + float(peer_id % 7), 5.0)
	input.grapple = swing_phase < 1.3
	if swing_phase < delta:
		var to_tower: Vector3 = Net.arena.layout.swing_point - eye_position()
		input.yaw = atan2(-to_tower.x, -to_tower.z)
		input.pitch = atan2(to_tower.y, Vector2(to_tower.x, to_tower.z).length())
		input.grapple_pressed = true
	if DevArgs.scripted_fire:
		var target := _nearest_visible_opponent()
		if target:
			var aim_height := 1.65 if fmod(t, 4.0) < 2.0 else 1.0  # alternate head and body
			var to: Vector3 = target.global_position + Vector3(0, aim_height, 0) - eye_position()
			input.yaw = atan2(-to.x, -to.z)
			input.pitch = atan2(to.y, Vector2(to.x, to.z).length())
			input.move = Vector2(1.0 if fmod(t, 3.0) < 1.5 else -1.0, 0.3)  # strafe while shooting
			if weapon and weapon.data.is_melee():
				input.move = Vector2(0.0, 1.0)   # a blade: run straight at them
			input.fire = true
			if fmod(t, 0.2) < delta:
				input.fire_pressed = true  # click about 5 times a second
		if fmod(t, 6.0) < delta and weapon:
			weapon.start_reload()  # top up now and then (tests the reload animation online)
	if DevArgs.scripted_kicks:
		_scripted_kicks(t, delta)


func _scripted_kicks(t: float, delta: float) -> void:
	if fmod(t + 0.7, 3.1) < delta:
		input.boost_pressed = true   # rocket boots, toward wherever the script is running
	var g := motor.grapple
	if g.hooked_player():
		input.grapple = true
		input.jump_pressed = false   # a jump would let go of the rope
		if global_position.distance_to(g.target.global_position) < 9.0:
			input.kick_pressed = true   # flying kick
		return
	var target := _nearest_visible_opponent()
	if target == null:
		return
	var d := global_position.distance_to(target.global_position)
	if d < 2.6:
		var to := target.global_position + Vector3(0, 1.0, 0) - eye_position()
		input.yaw = atan2(-to.x, -to.z)
		input.kick_pressed = true
	elif d > 7.0 and d < 35.0 and g.ready_to_fire() and fmod(t + 2.0, 4.3) < 1.5:
		var to := Grapple.target_point(target) - eye_position()
		input.yaw = atan2(-to.x, -to.z)
		input.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		input.grapple = true
		input.grapple_pressed = true


func _nearest_visible_opponent() -> Player:
	var best: Player = null
	var best_d := INF
	var space := get_world_3d().direct_space_state
	for p in get_parent().get_children():
		if p == self or not p is Player or not p.alive or not p.visual.visible:
			continue
		var target: Vector3 = p.global_position + Vector3(0, 1.0, 0)
		var ray := PhysicsRayQueryParameters3D.create(eye_position(), target, 1)
		if space.intersect_ray(ray):
			continue  # behind a wall
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# ---------------------------------------------------------------------------
# Grapple rope

func _build_rope() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.13)
	mat.metallic = 0.6
	mat.roughness = 0.4
	_rope = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.material = mat
	_rope.mesh = cyl
	_rope.top_level = true
	_rope.visible = false
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	_hook = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, 0.14)
	var hook_mat := StandardMaterial3D.new()
	hook_mat.albedo_color = Color(0.95, 0.7, 0.15)
	box.material = hook_mat
	_hook.mesh = box
	_hook.top_level = true
	_hook.visible = false
	add_child(_hook)


## Stretches the rope from the wrist launcher to the anchor.
func _draw_rope(on: bool, anchor: Vector3) -> void:
	_rope.visible = on
	_hook.visible = on
	if not on:
		return
	var from := rope_origin()
	var span := anchor - from
	var dist := span.length()
	if dist < 0.05:
		_rope.visible = false
		return
	var y := span / dist
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	_rope.global_transform = Transform3D(Basis(x, y * dist, z), from + span * 0.5)
	_hook.global_position = anchor



# ---------------------------------------------------------------------------
# Rocket boots: a burst of flame from both feet

func _build_flame() -> void:
	_flame = Node3D.new()
	_flame.visible = false
	visual.add_child(_flame)
	var outer := StandardMaterial3D.new()
	outer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer.albedo_color = Color(1.0, 0.55, 0.15, 0.8)
	outer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = Color(1.0, 0.95, 0.7, 0.9)
	core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for side in [-1.0, 1.0]:
		for layer in 2:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.11 if layer == 0 else 0.06
			cone.bottom_radius = 0.0
			cone.height = 0.75 if layer == 0 else 0.45
			cone.radial_segments = 8
			cone.rings = 1
			cone.material = outer if layer == 0 else core
			var m := MeshInstance3D.new()
			m.mesh = cone
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.position = Vector3(side * 0.14, -cone.height * 0.5, 0.0)
			_flame.add_child(m)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 4.0
	light.light_energy = 2.0
	light.position = Vector3(0, -0.2, 0)
	_flame.add_child(light)
	_flame.position = Vector3(0, 0.08, 0)


func _update_flame(delta: float) -> void:
	if _flame == null:
		return
	_flame_t = maxf(_flame_t - delta, 0.0)
	_flame.visible = _flame_t > 0.0 and alive and visual.visible
	if not _flame.visible:
		return
	var u := _flame_t / 0.45
	var length := maxf(u * (0.85 + 0.3 * randf()), 0.05)
	# Point the flames back the way the burst pushes you (away from where you are going).
	var aim := Vector3.DOWN
	if velocity.length() > 1.0:
		aim = visual.global_transform.basis.inverse() * -velocity.normalized()
	var turn := Quaternion(Vector3.DOWN, aim.normalized()) if aim.normalized().dot(Vector3.UP) < 0.999 else Quaternion(Vector3.RIGHT, PI)
	_flame.basis = Basis(turn) * Basis.from_scale(Vector3(1.0, length, 1.0))
