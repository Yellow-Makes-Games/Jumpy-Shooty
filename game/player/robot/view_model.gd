class_name ViewModel
extends Node3D
## Your own arms and gun in first person. Lives on the camera, on its own render
## layer, drawn with viewmodel.gdshader so it never clips into walls.
##
## It follows what your body is doing (sprint, slide, wall run, vault, dive, flips,
## grapple, reload) with a small set of arm poses, plus movement you can feel:
## sway when you turn, bob when you run, a dip when you land, recoil when you shoot.
## Each long gun has its own set of these poses ("fp_idle_rifle"...), and the shotgun
## and sniper rifle work their pump or bolt after every shot ("fp_fire_shotgun").

const S := MovementController.State
const EYE := Vector3(0.0, 1.60, 0.0)   ## where the camera sits inside the arms model
const VIEW_FOV := 70.0                 ## must match view_fov in viewmodel.gdshader
const FADE := 0.13
const CRAWL_PERIOD := 0.9              ## seconds for one crawl cycle at crawling speed (matches belly_crawl)
const LOOK_DOWN_FROM := 35.0            ## degrees of down pitch where the arms start moving out of the way...
const LOOK_DOWN_FULL := 80.0
const LOOK_DOWN_SHIFT := Vector3(0.05, -0.08, 0.0)   ## ...of your own body below you, ending this far over
## A melee weapon (see MeleeSwing): the hands are held this much higher and further out
## than the body holds them, so the weapon is in view, and the shoulders turn with
## this much of the body's wind-up, so a wound-up weapon is still on screen (just).
const MELEE_SHIFT := Vector3(0.05, 0.11, -0.04)
const MELEE_TURN := 0.3
## ...and the whole arms model sits this much further out and lower, so the weapon is
## not right under your nose.
const MELEE_VIEW := Vector3(0.03, -0.03, -0.14)
const MELEE_VIEW_YAW := -0.2   ## and turned a little to the right: the weapon rests right of centre
## A big weapon rests this much lower and further out again, so that at rest it hides no
## more of the view than a plain one would. Only at rest: wound up and swinging it is
## where every weapon is.
const MELEE_REST_VIEW := {
	"sword": Vector3(0.14, -0.04, 0.02),
	"hammer": Vector3(0.14, -0.04, 0.02),
	"axe": Vector3(0.14, -0.04, 0.02),
	"bat": Vector3(0.14, -0.04, 0.02),
	"spear": Vector3(0.04, -0.03, 0.0),
	"dagger": Vector3(0.085, -0.14, -0.09),
	"brass_knuckles": Vector3(0.0, -0.04, 0.0),
}
## A blow is tipped up this much (radians), so it sweeps across the crosshair and not under it.
const MELEE_CUT_TILT := 0.22
## In these the hands are busy (climbing, tucked): the weapon is not held up.
const MELEE_BUSY := ["fp_mantle", "fp_tuck", "fp_dive"]

var model: RobotModel
var rig: RobotRig
var source := ""

var _player: Player
var _pose: RobotPose
var _from: RobotPose
var _base: RobotPose
var _tmp: RobotPose
var _fade := 1.0
var _time := 0.0
var _recoil := 0.0
var _recoil_l := 0.0      # akimbo: the left gun's kick (_recoil is the right's)
var _kick_side := 0.0     # akimbo: which way the last shot rolls the view (+1 right gun, -1 left)
var _since_fire := 99.0
var _reload_w := 0.0
var _raise_t := -1.0
var _bob := 0.0
var _bob_w := 0.0
var _crawl := 0.0
var _crawl_w := 0.0
var _dip := 0.0
var _dip_vel := 0.0
var _prev_vy := 0.0
var _was_grounded := true
var _sway := Vector2.ZERO
var _last_yaw := 0.0
var _last_pitch := 0.0
var _grapple_w := 0.0
var _arm_l: PackedInt32Array
var _weapon := "pistol"
var _data: WeaponData
var _fire_t := -1.0
var _swing := MeleeSwing.new("sword", true)
var _swing_view := Vector2.ZERO   # the swing's chest turn and lean, felt as a turn of the whole view model
var _hold := 1.0                  # how much the arms hold the melee weapon up
var _rest := 1.0                  # how much the blade is in its resting lean (0 while winding up or swinging)
var _cut := 0.0                   # in a blow: the cut is tipped up to cross the middle of the view


func setup(player: Player, color: Color) -> void:
	_player = player
	name = "ViewModel"
	_data = player.weapon.data if player.weapon else WeaponData.pistol()
	_weapon = _data.id if player.weapon else "none"   # Deathmatch, nothing picked up yet: empty hands
	model = RobotModel.new().setup(Characters.arms(Net.player_character(player.peer_id)), color, true, _weapon)
	model.position = -EYE
	model.set_layer(Player.VIEWMODEL_LAYER)
	add_child(model)
	rig = model.rig
	_pose = rig.new_pose()
	_from = rig.new_pose()
	_base = rig.new_pose()
	_tmp = rig.new_pose()
	for n in ["upper_arm_l", "forearm_l", "hand_l"]:
		_arm_l.append(rig.bones[n])
	_last_yaw = player.input.yaw
	_last_pitch = player.input.pitch
	if _data.is_melee():
		_swing.set_weapon(_weapon)
	rig.sample(_pose, clip("fp_idle"), 0.0)
	_pose.apply(model.skeleton)


## The gun's own version of a pose if it has one ("fp_idle" -> "fp_idle_rifle").
func clip(base: String) -> String:
	var own := base + "_" + _weapon
	return own if rig.has_clip(own) else base


func fire(left: bool = false) -> void:
	if _data.is_akimbo():
		if left:
			_recoil_l = _data.kick
		else:
			_recoil = _data.kick
		_kick_side = -1.0 if left else 1.0
	else:
		_recoil = _data.kick
	_since_fire = 0.0
	if rig.has_clip("fp_fire_" + _weapon):
		_fire_t = 0.0


## Winding a melee swing up, this frame: `charge` 0..1 is how far.
func wind(charge: float, side: int = 0) -> void:
	if _data.is_melee():
		_swing.wind(charge, side)
		_since_fire = 0.0


## The swing was let go, `power` 0..1 wound up.
func swing(power: float, side: int = 0) -> void:
	if _data.is_melee():
		_swing.swing(power, side)
		_since_fire = 0.0


## The blow landed: freeze the swing for a moment so the hit has weight.
func hit_stop(seconds: float = 0.07) -> void:
	_swing.hit_stop(seconds)


## In the middle of a blow (the swing trail is drawn).
func cutting() -> bool:
	return _swing.active() and _swing.cutting()


## The blade's edge, base and tip, as world positions that line up on screen.
func edge() -> Array:
	var e := MeleeModel.edge(model.melee_left if _swing.left_fist() and model.melee_left else model.melee)
	return [_on_screen(e[0]), _on_screen(e[1])]


func _on_screen(world: Vector3) -> Vector3:
	var cam := get_parent() as Camera3D
	var p := cam.global_transform.affine_inverse() * world
	var r := tan(deg_to_rad(cam.fov) * 0.5) / tan(deg_to_rad(VIEW_FOV) * 0.5)
	return cam.global_transform * Vector3(p.x * r, p.y * r, p.z)


func respawn() -> void:
	visible = not _player.racing
	_raise_t = 0.0
	_dip = 0.0
	_dip_vel = 0.0
	_sway = Vector2.ZERO
	_last_yaw = _player.input.yaw
	_last_pitch = _player.input.pitch


## A marker bone ("muzzle", "grapple") as a world position that lines up on screen
## with where the arms are drawn (they use their own field of view).
func marker(bone: String) -> Vector3:
	var cam := get_parent() as Camera3D
	var p := cam.global_transform.affine_inverse() * model.marker(bone)
	var r := tan(deg_to_rad(cam.fov) * 0.5) / tan(deg_to_rad(VIEW_FOV) * 0.5)
	return cam.global_transform * Vector3(p.x * r, p.y * r, p.z)


func update(delta: float) -> void:
	visible = _player.alive and not _player.racing   # a race: no gun to hold
	if not visible:
		return
	var motor := _player.motor
	var vel := _player.velocity
	var speed := Vector2(vel.x, vel.z).length()
	var grounded := motor.state in [S.GROUND, S.CROUCH, S.SLIDE, S.ROLL, S.BELLY_SLIDE]
	var reloading := _player.weapon != null and _player.weapon.is_reloading()
	_since_fire += delta

	# --- Arm pose for what the body is doing
	var key := clip(_pick(motor, speed, reloading))
	if key != source:
		_from.copy(_base)
		_fade = 0.0 if source != "" else 1.0
		_time = 0.0
		source = key
	_time += delta
	_fade = minf(_fade + delta / FADE, 1.0)
	rig.sample(_pose, key, minf(_time, rig.length(key)))
	if _fade < 1.0:
		_tmp.copy(_from)
		_tmp.blend(_pose, smoothstep(0.0, 1.0, _fade))
		_pose.copy(_tmp)
	_base.copy(_pose)

	# --- Reload and respawn play over the top
	_reload_w = move_toward(_reload_w, 1.0 if reloading else 0.0, delta * 9.0)
	if _reload_w > 0.0:
		var rclip := clip("fp_reload")
		rig.sample(_tmp, rclip, _player.weapon.round_progress() * rig.length(rclip) if reloading else 0.0)
		_pose.blend(_tmp, _reload_w)
	# Working the pump or the bolt after a shot
	if _fire_t >= 0.0:
		var fclip := "fp_fire_" + _weapon
		var flen := rig.length(fclip)
		if _fire_t >= flen or reloading:
			_fire_t = -1.0
		else:
			rig.sample(_tmp, fclip, _fire_t)
			_pose.blend(_tmp, clampf(minf(_fire_t / 0.05, (flen - _fire_t) / 0.12), 0.0, 1.0) * (1.0 - _grapple_w))
			_fire_t += delta
	if _raise_t >= 0.0:
		var raise := clip("fp_raise")
		if _raise_t < rig.length(raise):
			rig.sample(_tmp, raise, _raise_t)
			_pose.blend(_tmp, 1.0 - smoothstep(0.6, 1.0, _raise_t / rig.length(raise)))
			_raise_t += delta
		else:
			_raise_t = -1.0

	# --- The left arm points its launcher at the grapple anchor
	_grapple_w = move_toward(_grapple_w, 1.0 if motor.grapple.attached else 0.0, delta * 10.0)
	if _grapple_w > 0.0:
		var up_l: int = rig.bones["upper_arm_l"]
		var shoulder := model.global_transform * (rig.rest_pos[rig.bones["hips"]] + rig.rest_pos[rig.bones["spine"]] \
			+ rig.rest_pos[rig.bones["chest"]] + rig.rest_pos[up_l])
		var dir := model.global_transform.basis.inverse() * (motor.grapple.anchor - shoulder).normalized()
		# Keep the arm in view: mostly forward, a little toward where the rope goes.
		dir = (Vector3(-0.25, -0.1, -1.0).normalized() * 1.2 + dir).normalized()
		_pose.rot[up_l] = _pose.rot[up_l].slerp(Quaternion(Vector3.DOWN, dir), _grapple_w)
		_pose.rot[rig.bones["forearm_l"]] = _pose.rot[rig.bones["forearm_l"]].slerp(Quaternion(Vector3.RIGHT, 0.1), _grapple_w)
		_pose.rot[rig.bones["hand_l"]] = _pose.rot[rig.bones["hand_l"]].slerp(Quaternion.IDENTITY, _grapple_w)

	if _data.is_melee():
		# The same hold and swing as the body's, with the shoulders turning less so the
		# weapon stays on screen: winding up draws it back to the right edge of the
		# view, and the blow sweeps it across.
		var k := _swing.sample(delta)
		var shift := MELEE_SHIFT
		_rest = move_toward(_rest, 0.0 if _swing.active() else 1.0, delta * (12.0 if _swing.active() else 5.0))
		_hold = move_toward(_hold, 0.0 if key in MELEE_BUSY and not _swing.active() else 1.0, delta * 9.0)
		var chest: int = rig.bones["chest"]
		_pose.rot[chest] = Quaternion(Vector3.UP, k[MeleeSwing.TURN] * MELEE_TURN * _hold) * _pose.rot[chest]
		_cut = move_toward(_cut, 1.0 if _swing.active() and not _swing.winding() else 0.0, delta * 14.0)
		MeleeSwing.hold(_pose, rig, k, _swing.two_handed, MELEE_CUT_TILT * _cut, _hold, _hold * (1.0 - _grapple_w), shift,
			_swing.other_fist(), _swing.left_fist())
		_swing_view = Vector2(k[MeleeSwing.TURN] * 0.4, k[MeleeSwing.LEAN]) * _hold
		if model.melee:
			MeleeModel.set_glow(model.melee, _swing.glow())
		if model.melee_left:
			MeleeModel.set_glow(model.melee_left, _swing.glow())

	_recoil *= exp(-delta * 18.0)
	_recoil_l *= exp(-delta * 18.0)
	if _weapon == "pistol" or _data.is_akimbo():
		_pose.pos[rig.bones["pistol_slide"]] += Vector3(0.0, 0.04 * _recoil, 0.0)
	if _data.is_akimbo():
		# Each gun flips up in its own hand, and its slide snaps back.
		_pose.pos[rig.bones["pistol_l_slide"]] += Vector3(0.0, 0.04 * _recoil_l, 0.0)
		for side in [["upper_arm_r", _recoil], ["upper_arm_l", _recoil_l]]:
			var b: int = rig.bones[side[0]]
			_pose.rot[b] = Quaternion(Vector3.RIGHT, minf(side[1], 1.6) * 0.13) * _pose.rot[b]
		for side in [["hand_r", _recoil], ["hand_l", _recoil_l]]:
			var b: int = rig.bones[side[0]]
			_pose.rot[b] = Quaternion(Vector3.RIGHT, minf(side[1], 1.6) * 0.25) * _pose.rot[b]
	_pose.apply(model.skeleton)

	# --- Whole-view movement: sway, bob, landing dip, recoil
	var yaw := _player.input.yaw
	var pitch := _player.input.pitch
	var turn := Vector2(wrapf(yaw - _last_yaw, -PI, PI), pitch - _last_pitch)
	_last_yaw = yaw
	_last_pitch = pitch
	_sway = (_sway + turn * 0.35).limit_length(0.12)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-delta * 9.0))

	_bob_w = move_toward(_bob_w, clampf(speed / 8.0, 0.0, 1.4) if grounded and motor.state not in [S.SLIDE, S.BELLY_SLIDE] else 0.0, delta * 6.0)
	_bob += delta * (5.0 + speed * 1.1)
	var bob := Vector3(sin(_bob) * 0.004, -absf(cos(_bob)) * 0.006, 0.0) * _bob_w
	# Crawling on your front (a belly slide that has run out of speed): the shoulders work from side to side.
	var crawling := motor.state == S.BELLY_SLIDE and speed < RobotAnimator.CRAWL_SPEED + 0.6 and speed > 0.3
	_crawl_w = move_toward(_crawl_w, 1.0 if crawling else 0.0, delta * 5.0)
	_crawl += delta * TAU * clampf(speed / RobotAnimator.CRAWL_SPEED, 0.4, 1.4) / CRAWL_PERIOD
	var crawl := sin(_crawl) * _crawl_w
	bob += Vector3(crawl * 0.018, -absf(crawl) * 0.008, 0.0)

	if grounded and not _was_grounded and _prev_vy < -2.0:
		_dip_vel -= clampf(-_prev_vy * 0.05, 0.1, 0.7)
	if not grounded and _was_grounded and vel.y > 3.0:
		_dip_vel -= 0.18   # jumping: the gun lags behind for a moment
	_was_grounded = grounded
	_prev_vy = vel.y
	_dip_vel += (-_dip * 140.0 - _dip_vel * 16.0) * delta   # a damped spring back to rest
	_dip += _dip_vel * delta
	var fall := clampf(-vel.y * 0.0012, -0.012, 0.02) if not grounded else 0.0

	var kick := minf(maxf(_recoil, _recoil_l), 1.6)
	if _data.is_akimbo():
		kick *= 0.5   # the arms take most of it (above); the view only nudges, toward the gun that fired
	position = bob + Vector3(_sway.x * 0.10, -_sway.y * 0.08 + _dip + fall, kick * 0.035)
	if _data.is_melee():
		position += MELEE_VIEW + (MELEE_REST_VIEW.get(_weapon, Vector3.ZERO) as Vector3) * smoothstep(0.0, 1.0, _rest)
	position += LOOK_DOWN_SHIFT * smoothstep(deg_to_rad(LOOK_DOWN_FROM), deg_to_rad(LOOK_DOWN_FULL), -pitch)
	rotation = Vector3(-_sway.y * 0.5 + kick * 0.07 + _dip * 0.8 - _swing_view.y * 0.25,
		_sway.x * 0.6 + crawl * 0.03 + _swing_view.x * 0.3, _sway.x * 0.5 - crawl * 0.05 - _swing_view.x * 0.2)
	if _data.is_akimbo():
		rotation.z -= _kick_side * kick * 0.02
	if _data.is_melee():
		rotation.y += MELEE_VIEW_YAW


func _pick(motor: MovementController, speed: float, reloading: bool) -> String:
	match motor.state:
		S.GROUND:
			if speed > 9.0 and _since_fire > 0.7 and not reloading and _player.input.sprint:
				return "fp_sprint"
		S.SLIDE: return "fp_slide"
		S.WALL_RUN:
			var right := Vector3.RIGHT.rotated(Vector3.UP, _player.input.yaw)
			return "fp_wall_r" if motor.wall_normal.dot(right) < 0.0 else "fp_wall_l"
		S.MANTLE: return "fp_mantle"
		S.DIVE, S.BELLY_SLIDE: return "fp_dive"
		S.ROLL, S.FLIP: return "fp_tuck"
		S.GRAPPLE: return "fp_one_hand"
	return "fp_idle"
