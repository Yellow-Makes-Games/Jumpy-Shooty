class_name PlayerSounds
extends RefCounted
## The sounds one player's body and gun make: footsteps, jumps, landings, slides,
## wall runs, the grapple, reload steps and working the pump or bolt.
##
## It reads the same RobotAnimInput the animation does, so it works the same way for
## you, for bots and for other players (whose movement arrives in snapshots): it
## listens for changes (started a slide, landed, the reload began) rather than being
## told. Your own sounds play in your head; everyone else's are placed on their body.

const S := MovementController.State

var player: Player
var own := false          ## your own player: sounds in your head, not placed in the world
var weapon_id := "pistol"

var _started := false
var _state := 0
var _crouched := false
var _grapple := false
var _wall_jumps := 0
var _alive := true
var _fall := 0.0             # fastest downward speed since leaving the ground
var _stride := 0.0           # metres walked since the last footstep
var _reloading := false
var _reload_t := -1.0
var _reload_next := 0
var _fire_t := -1.0
var _fire_next := 0
var _grapple_pending := -1.0   # attach clack, a moment after the hook flies
var _wind: AudioStreamPlayer    # rushing air (your own player only)
var _wind_level := 0.0
var _quiet := 0.0              # seconds of silence left (just spawned: no landing thud)


func _init(p: Player, is_own: bool, gun: String) -> void:
	player = p
	own = is_own
	weapon_id = gun


func _play(sound: String, kind: String = "move", volume_db: float = 0.0, jitter: float = 0.04) -> void:
	if own:
		Sound.play(sound, volume_db, jitter)
	else:
		Sound.play_at(sound, player.global_position + Vector3(0, 0.6, 0), kind, volume_db, jitter)


## Gun handling sounds come from the gun, a little quieter for other players.
func _play_gun(sound: String) -> void:
	if own:
		Sound.play(sound, 0.0, 0.03)
	else:
		Sound.play_at(sound, player.global_position + Vector3(0, 1.3, 0), "gun", 2.0, 0.03)


## This player's gun just fired.
func fired() -> void:
	if SfxList.FIRE_STEPS.has(weapon_id):
		_fire_t = 0.0
		_fire_next = 0


## Came back to life somewhere new: no landing or step sounds from the jump there.
func respawned() -> void:
	_started = false
	_quiet = 0.3
	if own:
		Sound.play("equip_" + weapon_id)


## The player missed with the grapple (nothing in range).
func grapple_missed() -> void:
	_play("grapple_miss")


## Called every frame with what the body is doing. `shown`: false while another
## player is hidden (waiting to reappear after a respawn).
func update(delta: float, a: RobotAnimInput, shown: bool) -> void:
	var alive := a.alive and shown
	if not _started or not alive or not _alive:
		_reset(a)
		_alive = alive
		_started = true
		_update_wind(a, delta)
		return
	_quiet = maxf(_quiet - delta, 0.0)
	var speed := Vector2(a.velocity.x, a.velocity.z).length()
	if _quiet <= 0.0:
		_movement(a, speed, delta)
	_gun(a, delta)
	_update_wind(a, delta)


func _reset(a: RobotAnimInput) -> void:
	_state = a.state
	_crouched = a.crouched
	_grapple = a.grapple_on
	_wall_jumps = a.wall_jumps()
	_fall = 0.0
	_stride = 0.0
	_reloading = a.reloading() and a.alive
	_reload_t = -1.0
	_fire_t = -1.0
	_grapple_pending = -1.0


func _movement(a: RobotAnimInput, speed: float, delta: float) -> void:
	var state: int = a.state
	var grounded_states := [S.GROUND, S.CROUCH, S.SLIDE, S.ROLL, S.BELLY_SLIDE]
	var was_air: bool = not (_state in grounded_states) and _state != S.MANTLE and _state != S.WALL_RUN
	if state in [S.AIR, S.DIVE, S.FLIP, S.GRAPPLE]:
		_fall = minf(_fall, a.velocity.y)

	if state != _state:
		match state:
			S.SLIDE: _play("slide")
			S.BELLY_SLIDE: _play("belly_slide", "move", 0.0 if was_air else -3.0)
			S.ROLL: _play("roll")
			S.DIVE: _play("dive")
			S.FLIP: _play("flip")
			S.WALL_RUN: _play("wall_run")
			S.MANTLE: _play("vault" if a.vaulting() else "ledge_climb")
			S.AIR:
				if _state in grounded_states and a.velocity.y > 2.5:
					_play("jump")
		# Landing (a slide, roll or belly slide out of the air brings its own sound).
		if was_air and state in [S.GROUND, S.CROUCH]:
			_land()
		if state in grounded_states or state == S.WALL_RUN:
			_fall = 0.0
	if a.wall_jumps() != _wall_jumps:
		_play("wall_jump")
	if a.crouched != _crouched and state in [S.GROUND, S.CROUCH]:
		_play("crouch" if a.crouched else "stand")
	if a.grapple_on != _grapple:
		if a.grapple_on:
			_play("grapple_fire")
			_grapple_pending = clampf(player.global_position.distance_to(a.grapple_anchor) / 120.0, 0.03, 0.25)
		else:
			_play("grapple_release")
	if _grapple_pending >= 0.0:
		_grapple_pending -= delta
		if _grapple_pending < 0.0 and a.grapple_on:
			if own:
				Sound.play("grapple_attach", 0.0, 0.05)
			else:
				Sound.play_at("grapple_attach", a.grapple_anchor, "move", 0.0, 0.05)
	_steps(a, state, speed, delta)
	_state = state
	_crouched = a.crouched
	_grapple = a.grapple_on
	_wall_jumps = a.wall_jumps()


func _land() -> void:
	var v := -_fall
	if v > 15.0:
		_play("land_hard", "body")
	elif v > 4.0:
		_play("land", "move", lerpf(-6.0, 0.0, clampf((v - 4.0) / 8.0, 0.0, 1.0)))
	_stride = 0.0


## Robot footsteps: one per stride, longer strides at speed. Quieter crouched,
## lighter and quicker on a wall, a drag of metal when crawling.
func _steps(a: RobotAnimInput, state: int, speed: float, delta: float) -> void:
	var stride := 0.0
	var sound := "step"
	var vol := 0.0
	match state:
		S.GROUND:
			if speed > 1.0:
				stride = 1.25 + speed * 0.1
				vol = lerpf(-5.0, 1.5, clampf((speed - 1.0) / 10.0, 0.0, 1.0))
		S.CROUCH:
			if speed > 0.8:
				stride = 1.0
				vol = -8.0
		S.WALL_RUN:
			stride = 1.9
			vol = -2.0
		S.BELLY_SLIDE:
			if speed > 0.4 and speed < 2.6:   # crawling
				stride = 0.75
				sound = "crawl"
	if stride <= 0.0:
		_stride = 0.9   # standing still: the first step comes soon after you set off
		return
	_stride += speed * delta
	if _stride >= stride:
		_stride = 0.0
		if own:
			Sound.play(sound, vol, 0.07)
		else:
			Sound.play_at(sound, player.global_position, "step", vol, 0.07)


func _gun(a: RobotAnimInput, delta: float) -> void:
	var reloading := a.reloading()
	if reloading and not _reloading:
		_reload_t = 0.0
		_reload_next = 0
		_fire_t = -1.0   # the reload takes over from the pump or bolt
	elif not reloading:
		_reload_t = -1.0
	_reloading = reloading
	if _reload_t >= 0.0:
		var steps: Array = SfxList.RELOAD_STEPS.get(weapon_id, [])
		_reload_t += delta
		while _reload_next < steps.size() and _reload_t >= steps[_reload_next][0]:
			_play_gun(steps[_reload_next][1])
			_reload_next += 1
		if weapon_id == "shotgun" and _reload_next >= steps.size():
			var shell := WeaponData.by_id("shotgun").reload_time
			if _reload_t >= shell:   # next shell
				_reload_t -= shell
				_reload_next = 0
	if _fire_t >= 0.0:
		var steps: Array = SfxList.FIRE_STEPS.get(weapon_id, [])
		_fire_t += delta
		while _fire_next < steps.size() and _fire_t >= steps[_fire_next][0]:
			_play_gun(steps[_fire_next][1])
			_fire_next += 1
		if _fire_next >= steps.size():
			_fire_t = -1.0


## Your own player only: rushing air at high speed (falls, swings, dives).
func _update_wind(a: RobotAnimInput, delta: float) -> void:
	if not own:
		return
	var speed := a.velocity.length() if a.alive else 0.0
	var target := clampf((speed - 12.0) / 16.0, 0.0, 1.0)
	_wind_level = move_toward(_wind_level, target, delta * 2.5)
	if _wind == null:
		if _wind_level <= 0.0 or not Sound.has_sound("wind_loop"):
			return
		_wind = AudioStreamPlayer.new()
		_wind.stream = Sound.stream("wind_loop")
		_wind.bus = Sound.BUS_SFX
		player.add_child(_wind)
	if _wind_level <= 0.0:
		if _wind.playing:
			_wind.stop()
		return
	if not _wind.playing:
		_wind.play(randf() * 2.0)
	var level := _wind_level
	_wind.volume_db = SfxList.VOLUME["wind_loop"] + linear_to_db(maxf(level, 0.001))
	_wind.pitch_scale = 0.9 + level * 0.25


func stop() -> void:
	if _wind:
		_wind.stop()
