extends Node
## The body of tools/robot/rope_film.gd (a separate file: it uses the game's autoloads).
## Plays the grappling hook in a real Practice match on the Testing Grounds' grapple lane,
## with the keys worked by this script, so the game can be filmed doing it.

const S := MovementController.State
const EAST := -PI / 2.0
const LANE_Z := -30.0
const START := Vector3(51, 6.05, LANE_Z)
const BEAMS := [62.0, 74.0, 86.0]   # x of each beam of the grapple lane (tests/course_test.gd)
const BEAM_Y := 14.0

var _me: Player
var _down := {}


func run(scene: String, third: bool) -> void:
	Settings.mobility = Mobility.GRAPPLE   # (not saved: nothing here calls save_settings)
	Settings.third_person = third
	Game.start_practice("testing_grounds")
	await _frames(40)
	_me = Net.arena.local_player
	DevArgs.drives_keys = true
	_me.teleport(START, EAST)
	_me.input.pitch = 0.0
	await _frames(30)
	print("FILM START %d" % Engine.get_process_frames())
	match scene:
		"pump": await _pump()
		"player": await _player()
		_: await _swing()
	_release_all()
	print("FILM END %d" % Engine.get_process_frames())
	await _frames(4)
	get_tree().quit()


## Off the platform and onto a long rope, to the far beam: the jolt, reeled up to it with
## the legs working, a few shots on the way, let go on the way up (the roll).
func _swing() -> void:
	await _physics(60)
	_key("move_forward", true)
	_key("sprint", true)
	while _me.global_position.x < 54.2:
		await _physics(1)
	await _tap("jump")
	var hook := _me.motor.grapple
	var beam := Vector3(BEAMS[2], BEAM_Y, LANE_Z)
	await _physics(10)
	_look(beam)
	_key("grapple", true)
	var on := 0
	var shots := 0
	for i in 1200:
		await _physics(1)
		if not hook.attached:
			if i > 60 and not hook.busy():
				break   # (it missed)
			continue
		if on == 0:
			beam = hook.anchor   # (an aim magnet may have picked a nearer beam)
		on += 1
		_look(beam + Vector3(10.0, -7.0, 0.0), 0.04)   # the aim comes off the hook, ahead and down
		if on > 70 and shots < 4 and on % 18 == 0:
			shots += 1
			_tap("fire")
		var p := _me.global_position
		if p.x > beam.x + 1.0 or (on > 90 and _me.velocity.y > 9.5 and p.x > beam.x - 7.0):
			break
	print("FILM hooked %.0f m off, let go: rising %.1f, speed %.1f, after %.2f s on the rope, %d shots" % [
		beam.distance_to(START), _me.velocity.y, _me.velocity.length(), on / 120.0, shots])
	_key("grapple", false)
	for i in 400:
		await _physics(1)
		_look(Vector3(120.0, 6.0, LANE_Z), 0.04)
		if _me.is_on_floor() and i > 60:
			break
	await _physics(60)


## Hanging under the first beam and working the swing to and fro.
func _pump() -> void:
	await _physics(60)
	_key("move_forward", true)
	_key("sprint", true)
	while _me.global_position.x < 54.2:
		await _physics(1)
	await _tap("jump")
	await _physics(10)
	var beam := Vector3(BEAMS[0], BEAM_Y, LANE_Z)
	_look(beam)
	_key("grapple", true)
	_key("sprint", false)
	var hook := _me.motor.grapple
	var on := 0
	while on < 720:
		await _physics(1)
		if not hook.attached:
			continue
		on += 1
		_look(Vector3(100.0, 9.0, LANE_Z), 0.08)   # looking along the lane, level
		# Push the way the swing is going (what a player does to work it up).
		var forward := _me.velocity.x >= 0.0
		_key("move_forward", forward)
		_key("move_back", not forward)
	print("FILM let go: rising %.1f, speed %.1f" % [_me.velocity.y, _me.velocity.length()])
	_key("grapple", false)
	_key("move_back", false)
	_key("move_forward", true)
	await _physics(140)


## Hooking a player (a bot standing still, up on a beam) from the start platform: reeled in to them.
func _player() -> void:
	Cheats.freeze_bots = true
	Net.arena.ensure_navigation()
	Net.add_bot(0, "pistol", Mobility.GRAPPLE)
	await _frames(20)
	var bot: Player = null
	for p in _me.get_parent().get_children():
		if p is Player and p != _me:
			bot = p
	if bot == null:
		print("FILM no bot")
		return
	# They stand up on the second beam; you are on the start platform.
	var theirs := Vector3(BEAMS[1], BEAM_Y + 0.6, LANE_Z)
	var way := theirs - START
	bot.teleport(theirs, atan2(way.x, way.z))
	await _physics(120)
	var hook := _me.motor.grapple
	_look(bot.global_position + Vector3(0, 1.2, 0))
	await _physics(40)
	_key("grapple", true)
	var on := 0
	var fired := false
	for i in 600:
		await _physics(1)
		fired = fired or hook.flying or hook.biting or hook.attached
		if hook.attached or hook.busy():
			on += 1
			_look(bot.global_position + Vector3(0, 1.2, 0), 0.3)
		elif fired:
			break
	print("FILM hooked a player %.0f m off for %.2f s (on a player: %s)" % [way.length(), on / 120.0, hook.line.target_id != 0])
	_key("grapple", false)
	await _physics(110)


# ---------------------------------------------------------------------------

## Turns the view toward a point (`share` of the way: 1 at once).
func _look(at: Vector3, share: float = 1.0) -> void:
	var dir := (at - _me.eye_position()).normalized()
	_me.input.yaw = lerp_angle(_me.input.yaw, atan2(-dir.x, -dir.z), share)
	_me.input.pitch = lerpf(_me.input.pitch, asin(clampf(dir.y, -1.0, 1.0)), share)


func _key(action: String, down: bool) -> void:
	if _down.get(action, false) == down:
		return
	_down[action] = down
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _tap(action: String) -> void:
	_key(action, true)
	await _physics(3)
	_key(action, false)


func _release_all() -> void:
	for action in _down.keys():
		_key(action, false)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
