class_name ViewModel
extends Node3D
## Your own arms and gun in first person. Lives on the camera, on its own render
## layer, drawn with viewmodel.gdshader so it never clips into walls.
##
## It follows what your body is doing (sprint, slide, wall run, vault, dive, flips,
## grapple, reload) with a small set of arm poses, plus movement you can feel:
## sway when you turn, bob when you run, a dip when you land, recoil when you shoot.

const S := MovementController.State
const EYE := Vector3(0.0, 1.60, 0.0)   ## where the camera sits inside the arms model
const VIEW_FOV := 70.0                 ## must match view_fov in viewmodel.gdshader
const FADE := 0.13

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
var _since_fire := 99.0
var _reload_w := 0.0
var _raise_t := -1.0
var _bob := 0.0
var _bob_w := 0.0
var _dip := 0.0
var _dip_vel := 0.0
var _prev_vy := 0.0
var _was_grounded := true
var _sway := Vector2.ZERO
var _last_yaw := 0.0
var _last_pitch := 0.0
var _grapple_w := 0.0
var _arm_l: PackedInt32Array


func setup(player: Player, color: Color) -> void:
	_player = player
	name = "ViewModel"
	model = RobotModel.new().setup(Characters.arms(Net.player_character(player.peer_id)), color, true)
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
	rig.sample(_pose, "fp_idle", 0.0)
	_pose.apply(model.skeleton)


func fire() -> void:
	_recoil = 1.0
	_since_fire = 0.0


func respawn() -> void:
	visible = true
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
	visible = _player.alive
	if not visible:
		return
	var motor := _player.motor
	var vel := _player.velocity
	var speed := Vector2(vel.x, vel.z).length()
	var grounded := motor.state in [S.GROUND, S.CROUCH, S.SLIDE, S.ROLL]
	var reloading := _player.weapon.is_reloading()
	_since_fire += delta

	# --- Arm pose for what the body is doing
	var key := _pick(motor, speed, reloading)
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
		rig.sample(_tmp, "fp_reload", _player.weapon.reload_progress() * rig.length("fp_reload") if reloading else 0.0)
		_pose.blend(_tmp, _reload_w)
	if _raise_t >= 0.0:
		if _raise_t < rig.length("fp_raise"):
			rig.sample(_tmp, "fp_raise", _raise_t)
			_pose.blend(_tmp, 1.0 - smoothstep(0.6, 1.0, _raise_t / rig.length("fp_raise")))
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

	_recoil *= exp(-delta * 18.0)
	_pose.pos[rig.bones["pistol_slide"]] += Vector3(0.0, 0.04 * _recoil, 0.0)
	_pose.apply(model.skeleton)

	# --- Whole-view movement: sway, bob, landing dip, recoil
	var yaw := _player.input.yaw
	var pitch := _player.input.pitch
	var turn := Vector2(wrapf(yaw - _last_yaw, -PI, PI), pitch - _last_pitch)
	_last_yaw = yaw
	_last_pitch = pitch
	_sway = (_sway + turn * 0.35).limit_length(0.12)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-delta * 9.0))

	_bob_w = move_toward(_bob_w, clampf(speed / 8.0, 0.0, 1.4) if grounded and motor.state != S.SLIDE else 0.0, delta * 6.0)
	_bob += delta * (5.0 + speed * 1.1)
	var bob := Vector3(sin(_bob) * 0.004, -absf(cos(_bob)) * 0.006, 0.0) * _bob_w

	if grounded and not _was_grounded and _prev_vy < -2.0:
		_dip_vel -= clampf(-_prev_vy * 0.05, 0.1, 0.7)
	if not grounded and _was_grounded and vel.y > 3.0:
		_dip_vel -= 0.18   # jumping: the gun lags behind for a moment
	_was_grounded = grounded
	_prev_vy = vel.y
	_dip_vel += (-_dip * 140.0 - _dip_vel * 16.0) * delta   # a damped spring back to rest
	_dip += _dip_vel * delta
	var fall := clampf(-vel.y * 0.0012, -0.012, 0.02) if not grounded else 0.0

	position = bob + Vector3(_sway.x * 0.10, -_sway.y * 0.08 + _dip + fall, _recoil * 0.035)
	rotation = Vector3(-_sway.y * 0.5 + _recoil * 0.07 + _dip * 0.8, _sway.x * 0.6, _sway.x * 0.5)


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
		S.DIVE: return "fp_dive"
		S.ROLL, S.FLIP: return "fp_tuck"
		S.GRAPPLE: return "fp_one_hand"
	return "fp_idle"
