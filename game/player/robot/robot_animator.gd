class_name RobotAnimator
extends RefCounted
## Chooses and blends the robot's animation from what the player is doing.
##
## Each frame, in this order:
##  1. Body: one source per movement state ("loco" = idle/run/sprint by speed,
##     "slide", "air", "flip_back", ...), cross-faded when the state changes.
##  2. Short overlays: landing dip, wall-jump kick, respawn boot-up.
##  3. Arms: gun up in the aim pose wherever the robot can shoot; reload on top.
##  4. Aim: spine, chest, arms and head pitch so the gun points where the player aims.
##  5. Legs turn at the waist to face the way the robot is moving (it can strafe
##     and back-pedal while the upper body keeps aiming).
##  6. Recoil, and the left arm reaching for the grapple anchor.
## Gliding has no clip either: the legs are set trailing behind the way you are
## going (see _glide_legs, and the waist turn in update), while everything above
## the waist keeps aiming wherever you look.
## A melee weapon has no clips: MeleeSwing says where the weapon is (ready, wound up,
## mid-blow) and bends the arms to hold it, in both hands where the weapon allows.
## The clips come from the model file; see tools/robot/animations.py. A long gun has its
## own version of the clips where the hands hold the gun ("aim_rifle", "reload_shotgun";
## tools/robot/weapon_anims.py), used instead of the plain (pistol) ones. Long guns also
## turn the chest a little (a bladed stance; the twist is in their aim clip), carry the
## gun across the chest when sprinting, and work a pump or bolt after each shot.

const S := MovementController.State
const RUN_SPEED := 8.0
const SPRINT_SPEED := 11.5
const CROUCH_SPEED := 4.0
const WALL_SPEED := 10.5
const FADE_DEFAULT := 0.12
const RELOAD_CUT_FADE := 0.12   ## seconds a reload that is cut short takes to ease back to the hold
const CRAWL_SPEED := 2.0
const FADES := {"roll": 0.05, "belly_slide": 0.07, "vault": 0.06, "climb": 0.08, "death": 0.08, "loco": 0.14,
	"flip_front": 0.06, "flip_back": 0.06, "flip_left": 0.06, "flip_right": 0.06, "glide": 0.14}
const FLIPS := ["flip_front", "flip_back", "flip_left", "flip_right"]
const VIEW_BACK := -0.02        ## first person: the front of the chest sits this far behind the eyes (just ahead of them)...
const VIEW_BACK_DOWN := 0.32    ## ...and this much further back when looking straight down,
const VIEW_BACK_FROM := 0.7     ## moving back as you look down past this (radians): the collar stays out of sight
## First person: in these the torso keeps the pose's lean. In everything else it is
## stood upright over the hips, which brings the knees forward into view.
const VIEW_KEEP_LEAN := ["crouch", "slide", "dive", "roll", "belly_slide", "death", "tuck"]
const VIEW_UPRIGHT_MAX := 0.6   ## radians of forward lean taken out, at most
const VIEW_SIDE := 0.10         ## the body may shift this far sideways to stay under the eyes
const VIEW_NECK_BELOW := 0.12   ## and its neck is kept at least this far below them
const AIRBORNE := ["air", "tuck", "grapple", "wall_l", "wall_r", "flip_front", "flip_back", "flip_left", "flip_right", "glide"]
const SPIN_PIVOT := Vector3(0.0, 1.0, 0.0)   ## a mid-air melee wind-up spins the body about here (its middle)
## Gliding: the legs trail behind you, further back the faster you go, and the
## hips tip forward a little into the wind.
const GLIDE_TRAIL := 42.0       ## degrees the legs trail back at GLIDE_TRAIL_SPEED and above
const GLIDE_HANG := 8.0         ## ...and when you are hardly moving (hanging in the air)
const GLIDE_TRAIL_SPEED := 14.0 ## m/s
const GLIDE_LEAN := 14.0        ## degrees the hips tip forward at that speed
## [right arm, left arm, torso]: how much each follows the aim in each source.
const AIM_WEIGHTS := {
	"loco": [1.0, 1.0, 1.0], "crouch": [1.0, 1.0, 1.0], "slide": [1.0, 0.0, 1.0],
	"air": [1.0, 1.0, 1.0], "tuck": [1.0, 1.0, 1.0], "grapple": [1.0, 0.0, 0.6],
	"wall_l": [1.0, 0.0, 0.7], "wall_r": [1.0, 0.0, 0.7], "belly_slide": [1.0, 1.0, 0.35],
	"glide": [1.0, 1.0, 1.0],
}

var model: RobotModel
var rig: RobotRig
## The gun in the hands (an id from WeaponData). Set it with set_weapon().
var weapon := "pistol"
## What the body is doing right now, e.g. "loco", "slide", "flip_back". Tests read this.
var source := ""
## Posing your own body for the first-person camera: the torso stays upright under
## the camera instead of leaning with the aim, and the moves that have a "view_"
## clip (slide, tuck, flips, the landing roll) play that instead: made to be seen
## from the eyes, with the legs brought up into view.
var first_person := false:
	set(on):
		_snap_view = _snap_view or on != first_person   # the camera swaps bodies in one frame, so no easing
		first_person = on

var _pose: RobotPose
var _from: RobotPose
var _base: RobotPose
var _tmp: RobotPose
var _aim: RobotPose
var _fade := 1.0
var _fade_time := FADE_DEFAULT
var _time := 0.0          # seconds in the current source
var _phase := 0.0         # stride phase, 0..1
var _idle_time := 0.0
var _twist := 0.0
var _reverse := false
var _air_t := 0.5
var _land := 0.0
var _aim_r := 1.0
var _aim_l := 1.0
var _torso := 1.0
var _recoil := 0.0
var _recoil_l := 0.0      # akimbo: the left gun's own kick (_recoil is the right's)
var _akimbo := false      # a pistol in each hand: each arm kicks on its own shots
var _since_fire := 99.0
var _reload_t := -1.0
var _reload_w := 0.0
var _was_reloading := false
var _reload_from := 0.0   # a reload cut short: where in the clip it stopped...
var _reload_out := 0.0    # ...and how much of that pose is still held (it eases back to the hold)
var _reload_out_clip := ""   # ...and which clip it was
var _end_t := -1.0        # a shell-at-a-time reload's last flourish ("reload_end"), once the gun is full
var _reload_chest := Quaternion.IDENTITY   # the reload clip's chest and spine as it starts: what it
var _reload_spine := Quaternion.IDENTITY   # turns them by from there is added to the body's own
var _fx_t := -1.0         # how far into the reload the gun's effects were last frame (ReloadFx)
## Where a reload's spent cell is put (the arena). Null: none is thrown.
var fx_parent: Node = null
var _respawn_t := -1.0
var _kick_t := -1.0
var _kick_right := false
var _wall_jumps := -1
var _grapple_w := 0.0
var _prev_vy := 0.0
var _dead_time := -1.0
var _power := 1.0
var _lean := 1.0          # how much the torso leans with the aim (0 in first person)
var _upright := 0.0       # first person: how much of the torso's forward lean is taken out
var _view_clip := false   # first person: the body is playing a "view_" clip this frame...
var _pin := 0.0           # ...so its neck is pinned to the camera (eases in and out)
var _snap_view := false   # first person was just switched on or off
var _stance := Quaternion.IDENTITY   # the chest's turn for the gun's stance (from its aim clip)
var _carry := 0.0         # sprinting with a long gun: arms holding it across the chest
var _carry_pose: RobotPose
var _fire_t := -1.0       # time into the gun's fire clip (pump, bolt), or -1
var _kick := 1.0
var _loop_reload := false
var _melee := false       # a melee weapon: held and swung by MeleeSwing, not by clips
var _swing := MeleeSwing.new()
var _hold := 1.0          # how much the arms hold the weapon up (0 in a flip, a roll, a climb)
var _swing_key: Array = []   # the swing's pose this frame
var _sink := 0.0             # how far the body has sunk into its knees with the swing, 0..1
var _airborne := false       # off the ground in a plain fall, flip or glide: a melee wind-up takes its mid-air form
var _was_slam := false       # in a ground slam last frame
var _tuck := 0.0             # how far the legs are drawn up by a mid-air wind-up or a slam, 0..1
var _leg_t := -1.0        # time into a kick, or -1
var _flying_kick := false # in a flying kick: feet first
var _fly_w := 0.0

var _b := {}                      # bone name -> index
var _arm_r: PackedInt32Array
var _arm_l: PackedInt32Array
var _not_arms: PackedInt32Array
var _legs_core: PackedInt32Array


func _init(robot: RobotModel) -> void:
	model = robot
	rig = robot.rig
	_pose = rig.new_pose()
	_from = rig.new_pose()
	_base = rig.new_pose()
	_tmp = rig.new_pose()
	_aim = rig.new_pose()
	_b = rig.bones
	_arm_r = _bones(["upper_arm_r", "forearm_r", "hand_r", "pistol", "pistol_slide", "pistol_mag", "pistol_vent"] + Hands.RIGHT)
	_arm_l = _bones(["upper_arm_l", "forearm_l", "hand_l", "pistol_l", "pistol_l_slide", "pistol_l_mag", "pistol_l_vent"] + Hands.LEFT)
	_legs_core = _bones(["hips", "spine", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"])
	for i in rig.bone_names.size():
		if not (i in _arm_r or i in _arm_l):
			_not_arms.append(i)
	_carry_pose = rig.new_pose()
	set_weapon(robot.weapon if robot.weapon != "" else "pistol")


## Hold this gun: its stance, reload and fire animations.
func set_weapon(id: String) -> void:
	var data := WeaponData.by_id(WeaponData.valid(id))
	weapon = WeaponData.look_of(data.id)   # (clips go by the weapon it looks like: the Golden Gun is the revolver)
	_kick = data.kick
	_loop_reload = data.reload_per_round
	_melee = data.is_melee()
	_akimbo = data.is_akimbo()
	if _melee:
		_swing.set_weapon(weapon)
	if rig.has_clip(clip("aim")):
		rig.sample(_aim, clip("aim"), 0.0)
	if rig.has_clip(clip("reload")):
		rig.sample(_tmp, clip("reload"), 0.0)
		_reload_chest = _tmp.rot[_b["chest"]].normalized()
		_reload_spine = _tmp.rot[_b["spine"]].normalized()
	_reload_t = -1.0
	_reload_out = 0.0
	_end_t = -1.0
	_stance = _aim.rot[_b["chest"]].normalized()
	if rig.has_clip("carry_" + weapon):
		rig.sample(_carry_pose, "carry_" + weapon, 0.0)


## Lays the reload clip at time t over the arms, `w` of it, and adds what it turns the
## chest and spine by to the body's own (the shoulders go with a reload's flourish).
func _lay_reload(rclip: String, t: float, w: float) -> void:
	rig.sample(_tmp, rclip, t)
	_pose.blend_bones(_tmp, w, _arm_r)
	_pose.blend_bones(_tmp, w, _arm_l)
	if first_person or w <= 0.0:
		return
	for part in [["chest", _reload_chest], ["spine", _reload_spine]]:
		var b: int = _b[part[0]]
		var by: Quaternion = (part[1] as Quaternion).inverse() * _tmp.rot[b]
		_pose.rot[b] = _pose.rot[b] * Quaternion.IDENTITY.slerp(by.normalized(), w)


## The gun's own version of a clip if it has one ("reload" -> "reload_rifle"), otherwise the clip.
func clip(base: String) -> String:
	var own := base + "_" + weapon
	return own if rig.has_clip(own) else base


func _bones(names: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in names:
		if _b.has(n):
			out.append(_b[n])
	return out


## A shot was fired: kick the gun (akimbo: the one in the left hand when `left`).
func fire(left: bool = false) -> void:
	if _akimbo and left:
		_recoil_l = _kick
	else:
		_recoil = _kick
	_since_fire = 0.0
	if _end_t >= 0.0:   # a shot cuts the last flourish short: it eases back to the hold
		_reload_from = _end_t
		_reload_out_clip = clip("reload_end")
		_reload_out = 1.0
		_end_t = -1.0
	if rig.has_clip("fire_" + weapon):
		_fire_t = 0.0


## Winding a melee swing up, this frame: `charge` 0..1 is how far (the body coils with
## it), `side` which tap is coming (see MeleeSwing).
func wind(charge: float, side: int = 0) -> void:
	if _melee:
		_swing.wind(charge, side, _airborne)


## The swing was let go, `power` 0..1 wound up.
func swing(power: float, side: int = 0) -> void:
	if _melee:
		_swing.swing(power, side, _airborne)
		_since_fire = 0.0


## A kick (see Kick): the right leg snaps out in front.
func kick(flying: bool = false) -> void:
	_leg_t = 0.0 if not flying else -1.0
	if flying:
		_flying_kick = true


## A flying kick starts or ends: both legs out, leaning back, for as long as it lasts.
func set_flying_kick(on: bool) -> void:
	_flying_kick = on


## Front kick, over the pose: [thigh lift, knee bend, lean back] at time t.
const KICK_KEYS := [[0.0, 0.0, 0.0, 0.0], [0.07, 1.5, 1.9, 0.15], [0.15, 1.65, 0.05, 0.35], [0.26, 1.55, 0.1, 0.3], [0.45, 0.0, 0.0, 0.0]]


func _kick_sample(t: float) -> Array:
	for i in range(1, KICK_KEYS.size()):
		var b: Array = KICK_KEYS[i]
		if t <= b[0]:
			var a: Array = KICK_KEYS[i - 1]
			var u := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
			return [lerpf(a[1], b[1], u), lerpf(a[2], b[2], u), lerpf(a[3], b[3], u)]
	return [0.0, 0.0, 0.0]


func _apply_kick(delta: float, alive: bool) -> void:
	_fly_w = move_toward(_fly_w, 1.0 if (_flying_kick and alive) else 0.0, delta * 9.0)
	var lift := 0.0
	var bend := 0.0
	var lean := 0.0
	var w := 0.0
	if _leg_t >= 0.0:
		var k := _kick_sample(_leg_t)
		lift = k[0]
		bend = k[1]
		lean = k[2]
		w = 1.0
		_leg_t += delta
		if _leg_t >= KICK_KEYS[-1][0] or not alive:
			_leg_t = -1.0
	if _fly_w > 0.0:
		lift = lerpf(lift, 1.45, _fly_w)
		bend = lerpf(bend, 0.0, _fly_w)
		lean = lerpf(lean, 0.75, _fly_w)
		w = maxf(w, _fly_w)
	if w <= 0.0:
		return
	var t_r: int = _b["thigh_r"]
	var s_r: int = _b["shin_r"]
	_pose.rot[t_r] = _pose.rot[t_r].slerp(Quaternion(Vector3.RIGHT, lift), w)
	_pose.rot[s_r] = _pose.rot[s_r].slerp(Quaternion(Vector3.RIGHT, -bend), w)
	if _fly_w > 0.0:   # the other leg tucked up under you
		var t_l: int = _b["thigh_l"]
		var s_l: int = _b["shin_l"]
		_pose.rot[t_l] = _pose.rot[t_l].slerp(Quaternion(Vector3.RIGHT, 0.9), _fly_w)
		_pose.rot[s_l] = _pose.rot[s_l].slerp(Quaternion(Vector3.RIGHT, -1.9), _fly_w)
	var sp: int = _b["spine"]
	_pose.rot[sp] = Quaternion(Vector3.RIGHT, lean * w) * _pose.rot[sp]


## The blow landed: freeze the swing for a moment so the hit has weight.
func hit_stop(seconds: float = 0.07) -> void:
	_swing.hit_stop(seconds)


## How far a melee swing has turned the chest from where it rests, radians (+ = to the left).
func melee_turn() -> float:
	if not _melee or _swing_key.is_empty():
		return 0.0
	return (float(_swing_key[MeleeSwing.TURN]) - _swing.rest_turn()) * _hold


## The swing itself (its glow, its power, whether it is the heavy blow).
func melee_swing() -> MeleeSwing:
	return _swing


## In the middle of a blow (the swing trail is drawn).
func cutting() -> bool:
	return _swing.active() and _swing.cutting()


## Back to life: play the boot-up over whatever the body is doing.
func respawn() -> void:
	_respawn_t = 0.0
	_swing.stop()
	_dead_time = -1.0
	_reload_t = -1.0
	_land = 0.0
	_kick_t = -1.0
	_leg_t = -1.0
	_flying_kick = false
	_fade = 1.0


func update(delta: float, inp: RobotAnimInput, model_xform: Transform3D) -> void:
	var local_vel := inp.velocity.rotated(Vector3.UP, -inp.yaw)   # x right, -z forward
	var speed := Vector2(local_vel.x, local_vel.z).length()

	# --- 1. Body
	var key := _pick(inp)
	if key != source:
		_switch(key, inp)
	_time += delta
	_fade = minf(_fade + delta / _fade_time, 1.0)
	_sample_body(key, inp, local_vel, speed, delta)
	if _fade < 1.0:
		_tmp.copy(_from)
		_tmp.blend(_pose, smoothstep(0.0, 1.0, _fade))
		_pose.copy(_tmp)
	_base.copy(_pose)
	_prev_vy = inp.velocity.y

	# --- 2. Overlays
	if _land > 0.0 and rig.has_clip("land"):
		rig.sample(_tmp, "land", 0.0)
		_pose.blend_bones(_tmp, _land, _not_arms)
		_land = maxf(_land - delta / 0.3, 0.0)
	var jumps := inp.wall_jumps()
	if _wall_jumps >= 0 and jumps != _wall_jumps and inp.alive:
		_kick_t = 0.0
		_kick_right = inp.wall_right()
	_wall_jumps = jumps
	if _kick_t >= 0.0:
		var kick_clip := "wall_jump_r" if _kick_right else "wall_jump_l"
		if rig.has_clip(kick_clip) and _kick_t < rig.length(kick_clip) and key in ["air", "tuck"]:
			var len := rig.length(kick_clip)
			rig.sample(_tmp, kick_clip, _kick_t)
			_pose.blend_bones(_tmp, clampf((len - _kick_t) / (len * 0.5), 0.0, 1.0), _not_arms)
			_kick_t += delta
		else:
			_kick_t = -1.0
	if _respawn_t >= 0.0:
		var rclip := clip("respawn")
		if rig.has_clip(rclip) and _respawn_t < rig.length(rclip) and inp.alive:
			rig.sample(_tmp, rclip, _respawn_t)
			_pose.blend(_tmp, 1.0 - smoothstep(0.3, 1.0, _respawn_t / rig.length(rclip)))
			_respawn_t += delta
		else:
			_respawn_t = -1.0

	# --- First person: stand the torso up over the hips
	var ease := 1000.0 if _snap_view else delta
	_snap_view = false
	_pin = move_toward(_pin, 1.0 if _view_clip else 0.0, ease / 0.1)
	_upright = move_toward(_upright, 1.0 if first_person and not _view_clip and key not in VIEW_KEEP_LEAN else 0.0, ease * 6.0)
	if _upright > 0.0:
		var lower: Quaternion = _pose.rot[_b["root"]] * _pose.rot[_b["hips"]]
		var up := lower * _pose.rot[_b["spine"]] * _pose.rot[_b["chest"]] * Vector3.UP
		var forward_lean := clampf(atan2(-up.z, up.y), 0.0, VIEW_UPRIGHT_MAX)
		_pose.rot[_b["spine"]] = lower.inverse() * Quaternion(Vector3.RIGHT, forward_lean * _upright) * lower * _pose.rot[_b["spine"]]

	# --- 3. Arms
	_since_fire += delta
	var want: Array = AIM_WEIGHTS.get(key, [0.0, 0.0, 0.0])
	var want_r: float = want[0]
	var want_l: float = want[1] if not _melee else 0.0   # a melee weapon is held in one hand
	var sprinting := key == "loco" and speed > RUN_SPEED + 1.0 and _since_fire > 0.7 and _reload_t < 0.0 and _end_t < 0.0
	if sprinting:
		want_r = 0.0   # sprinting: arms pump (a long gun is carried across the chest), until you shoot
		want_l = 0.0
	var has_carry := weapon != "pistol" and rig.has_clip("carry_" + weapon)
	_carry = move_toward(_carry, 1.0 if sprinting and has_carry and inp.alive else 0.0, delta * 7.0)
	if _respawn_t >= 0.0:
		want_r = 0.0
		want_l = 0.0
	_aim_r = move_toward(_aim_r, want_r, delta * 9.0)
	_aim_l = move_toward(_aim_l, want_l, delta * 9.0)
	_torso = move_toward(_torso, want[2], delta * 8.0)
	if _carry > 0.0:
		_pose.blend_bones(_carry_pose, _carry, _arm_r)
		_pose.blend_bones(_carry_pose, _carry, _arm_l)
	_pose.blend_bones(_aim, _aim_r, _arm_r)
	_pose.blend_bones(_aim, _aim_l, _arm_l)

	var reloading := inp.reloading() and inp.alive
	var rclip := clip("reload")
	if reloading and not _was_reloading and rig.has_clip(rclip):
		_reload_t = 0.0
	_was_reloading = reloading
	_reload_w = 0.0
	if _reload_t >= 0.0:
		var rlen := rig.length(rclip)
		if _loop_reload and reloading and _reload_t >= rlen:
			_reload_t = fmod(_reload_t, rlen)   # a shell at a time: round and round until full
		if _reload_t >= rlen or not inp.alive or (not reloading and (_loop_reload or _reload_t < rlen - 0.3)):
			if _loop_reload and not reloading and inp.alive and _since_fire > 0.2 and rig.has_clip(clip("reload_end")):
				_end_t = 0.0   # full, and not stopped by a shot: the last flourish
			elif _reload_t < rlen and inp.alive:
				# Cut short (the gun was swapped, or fired between shells): the arms ease
				# back to the hold from where they were, not in one frame.
				_reload_from = _reload_t
				_reload_out_clip = rclip
				_reload_out = 1.0
			_reload_t = -1.0
		else:
			_reload_w = 1.0 if _loop_reload else clampf(minf(_reload_t / 0.1, (rlen - _reload_t) / 0.15), 0.0, 1.0)
			if want[2] <= 0.0:
				_reload_w = 0.0   # mid-flip, mid-roll: the hands are busy
			_lay_reload(rclip, _reload_t, _reload_w)
			_reload_t += delta
	if _end_t >= 0.0:
		var eclip := clip("reload_end")
		var elen := rig.length(eclip)
		if _end_t >= elen or not inp.alive or reloading or want[2] <= 0.0:
			_end_t = -1.0
		else:
			_reload_w = clampf((elen - _end_t) / 0.12, 0.0, 1.0)
			_lay_reload(eclip, _end_t, _reload_w)
			_end_t += delta
	if _reload_t < 0.0 and _end_t < 0.0 and _reload_out > 0.0:
		_reload_out = move_toward(_reload_out, 0.0, delta / RELOAD_CUT_FADE) if rig.has_clip(_reload_out_clip) and want[2] > 0.0 else 0.0
		if _reload_out > 0.0:
			_lay_reload(_reload_out_clip, _reload_from, smoothstep(0.0, 1.0, _reload_out))

	# The pump or the bolt, after a shot (the left hand only where it is on the gun)
	if _fire_t >= 0.0:
		var fclip := "fire_" + weapon
		var flen := rig.length(fclip)
		if _fire_t >= flen or not inp.alive or _reload_w > 0.0:
			_fire_t = -1.0
		else:
			var fw := clampf(minf(_fire_t / 0.06, (flen - _fire_t) / 0.12), 0.0, 1.0)
			rig.sample(_tmp, fclip, _fire_t)
			_pose.blend_bones(_tmp, fw * _aim_r, _arm_r)
			_pose.blend_bones(_tmp, fw * minf(_aim_l, _aim_r), _arm_l)
			_fire_t += delta

	# A melee weapon: the body turns and leans with the wind-up and the blow (the arms
	# are bent to hold the weapon once the chest is where it will be, below).
	if _melee:
		if not inp.alive:
			_swing.stop()
		# A ground slam: the weapon overhead on the way down, driven into the floor on landing.
		_airborne = inp.state in [S.AIR, S.FLIP, S.GLIDE]
		var slam := inp.state == S.SLAM and inp.alive
		if slam:
			_swing.slam_fall()
		elif _was_slam and inp.alive:
			_swing.slam_land(1.0)
		_was_slam = slam
		_swing_key = _swing.sample(delta)
		var busy := _swing.active() and inp.alive
		_hold = move_toward(_hold, 1.0 if busy or (want[0] > 0.0 and inp.alive and _respawn_t < 0.0) else 0.0, delta * 9.0)
		# On its feet the body sinks into its knees as it coils (less on the run), then turns.
		var low := MeleeSwing.sink(_swing_key) * _hold * (1.0 - 0.6 * clampf(speed / 6.0, 0.0, 1.0)) if key == "loco" else 0.0
		low = maxf(low, _swing.landed())   # a slam lands in a deep crouch
		_sink = move_toward(_sink, low, delta * (20.0 if _swing.landed() > 0.0 else 8.0))
		# Off the ground, a wind-up of the weapon's own (and a slam) draws the legs up.
		_tuck = move_toward(_tuck, (0.75 if slam else 0.6 * _swing.air()) if inp.alive else 0.0, delta * 7.0)
		if maxf(_sink, _tuck) > 0.0:
			rig.sample(_tmp, "crouch_idle", 0.0)
			_pose.blend_bones(_tmp, maxf(_sink, _tuck), _legs_core)
		# A mid-air move with legs of its own (the superman punch: knee up, then kicked back).
		# A kick (a blow with legs of its own, on the ground) shows in first person too: your own leg comes up into view.
		var legs := _swing.legs()
		if not legs.is_empty() and (not first_person or _swing.legs_kick()) and inp.alive:
			var w: float = legs[4]
			for leg in [["thigh_r", "shin_r", 0, 5, 1.0], ["thigh_l", "shin_l", 2, 6, -1.0]]:
				var thigh: int = _b[leg[0]]
				var shin: int = _b[leg[1]]
				var out := Quaternion(Vector3.BACK, float(legs[leg[3]]) * float(leg[4]))   # lifted out to its own side
				_pose.rot[thigh] = _pose.rot[thigh].slerp(Quaternion(Vector3.RIGHT, legs[leg[2]]) * out, w)
				_pose.rot[shin] = _pose.rot[shin].slerp(Quaternion(Vector3.RIGHT, -legs[leg[2] + 1]), w)
			# A leg lifted out to the side tips the hips up after it (the body leans away), so a kick goes high.
			var tilt := (float(legs[5]) - float(legs[6])) * 0.4 * w
			if tilt != 0.0:
				_pose.rot[_b["hips"]] = Quaternion(Vector3.BACK, tilt) * _pose.rot[_b["hips"]]
				_pose.rot[_b["spine"]] = Quaternion(Vector3.BACK, -tilt * 0.6) * _pose.rot[_b["spine"]]
		MeleeSwing.turn_body(_pose, _b, _swing_key, _hold)
		# A mid-air wind-up spins the whole body about its middle (not the body you see from
		# inside it: your own view stays level, and the arms go round it instead).
		if _swing.spin() != 0.0 and not first_person and inp.alive:
			var round := Quaternion(_swing.spin_axis(), _swing.spin())
			var root: int = _b["root"]
			_pose.rot[root] = round * _pose.rot[root]
			_pose.pos[root] = SPIN_PIVOT + round * (_pose.pos[root] - SPIN_PIVOT)
		if model.melee:
			MeleeModel.set_glow(model.melee, _swing.glow() if inp.alive else 0.0)
		if model.melee_left:
			MeleeModel.set_glow(model.melee_left, _swing.glow() if inp.alive else 0.0)
	_apply_kick(delta, inp.alive)

	# A long gun's stance: the chest turns a little to bring the left shoulder forward
	var stance := maxf(_aim_r, _reload_w)
	var twist := Quaternion.IDENTITY.slerp(_stance, stance)
	_pose.rot[_b["chest"]] = _pose.rot[_b["chest"]] * twist
	_pose.rot[_b["head"]] = twist.inverse() * _pose.rot[_b["head"]]   # the head keeps looking where you aim

	# --- 4. Aim pitch through the spine, then the arms make up the difference
	var hips: int = _b["hips"]
	var spine: int = _b["spine"]
	var chest: int = _b["chest"]
	var head: int = _b["head"]
	_lean = move_toward(_lean, 0.0 if first_person else 1.0, ease * 8.0)
	var p := inp.pitch * _torso * _lean
	_pose.rot[spine] = Quaternion(Vector3.RIGHT, p * 0.25) * _pose.rot[spine]
	_pose.rot[chest] = Quaternion(Vector3.RIGHT, p * 0.25) * _pose.rot[chest]
	_pose.rot[head] = Quaternion(Vector3.RIGHT, p * 0.2) * _pose.rot[head]
	var chest_rot: Quaternion = _pose.rot[_b["root"]] * _pose.rot[hips] * _pose.rot[spine] * _pose.rot[chest]
	var chest_fwd := chest_rot * Vector3.FORWARD
	var chest_pitch := asin(clampf(chest_fwd.y, -1.0, 1.0))
	_recoil = _recoil * exp(-delta * 16.0)
	_recoil_l = _recoil_l * exp(-delta * 16.0)
	var aim_lift := clampf(inp.pitch - chest_pitch, -1.7, 1.7)
	var lift := aim_lift + minf(_recoil, 1.5) * 0.2
	var lift_l := aim_lift + minf(_recoil_l if _akimbo else _recoil, 1.5) * 0.2
	var up_r: int = _b["upper_arm_r"]
	var up_l: int = _b["upper_arm_l"]
	var w_r := maxf(_aim_r, _reload_w)
	var w_l := maxf(_aim_l, _reload_w)
	var across := twist.inverse() * Vector3.RIGHT   # the body's left-right axis, seen from the turned chest
	_pose.rot[up_r] = Quaternion(across, lift * w_r) * _pose.rot[up_r]
	_pose.rot[up_l] = Quaternion(across, lift_l * w_l) * _pose.rot[up_l]
	if _b.has("pistol_slide") and (weapon == "pistol" or _akimbo):
		_pose.pos[_b["pistol_slide"]] += Vector3(0.0, 0.035 * _recoil, 0.0)
	if _akimbo and _b.has("pistol_l_slide"):
		_pose.pos[_b["pistol_l_slide"]] += Vector3(0.0, 0.035 * _recoil_l, 0.0)
	if _melee and _hold > 0.0:
		# The weapon follows the aim up and down about the shoulders, a little less than a gun does.
		# (The swing's own lean is taken out in full, so a thrust stays level as the body leans into it.)
		MeleeSwing.hold(_pose, rig, _swing_key, _swing.two_handed,
			clampf(inp.pitch - chest_pitch, -1.2, 1.2) * 0.8 + float(_swing_key[MeleeSwing.LEAN]) * _hold * 0.2, _hold, _hold,
			Vector3.ZERO, _swing.other_fist(), _swing.left_fist())

	# --- 6 (before the waist turn, which must not move the chest). Grapple arm
	_grapple_w = move_toward(_grapple_w, 1.0 if (inp.grapple_on and inp.alive) else 0.0, delta * 10.0)
	if _grapple_w > 0.0:
		var chest_pos: Vector3 = _pose.pos[hips] + _pose.rot[hips] * (_pose.pos[spine] + _pose.rot[spine] * _pose.pos[chest])
		var shoulder := chest_pos + chest_rot * _pose.pos[up_l]
		var to_anchor := model_xform.affine_inverse() * inp.grapple_anchor - shoulder
		if to_anchor.length_squared() > 0.01:
			var dir := chest_rot.inverse() * to_anchor.normalized()
			var reach := Quaternion(Vector3.DOWN, dir) if dir.dot(Vector3.DOWN) > -0.999 else Quaternion(Vector3.RIGHT, PI)
			_pose.rot[up_l] = _pose.rot[up_l].slerp(reach, _grapple_w)
			_pose.rot[_b["forearm_l"]] = _pose.rot[_b["forearm_l"]].slerp(Quaternion(Vector3.RIGHT, 0.12), _grapple_w)
			_pose.rot[_b["hand_l"]] = _pose.rot[_b["hand_l"]].slerp(Quaternion.IDENTITY, _grapple_w)

	# --- 5. Legs face the way we are moving
	var twist_target := 0.0
	if key in ["loco", "crouch"] and speed > 1.5:
		var angle := atan2(local_vel.x, -local_vel.z)   # 0 forward, positive to the right
		if _reverse and absf(angle) < deg_to_rad(95.0):
			_reverse = false
		elif not _reverse and absf(angle) > deg_to_rad(115.0):
			_reverse = true
		if _reverse:
			angle -= signf(angle) * PI
		twist_target = -angle
	elif key == "glide":
		_reverse = false
		if speed > 1.0:
			twist_target = -atan2(local_vel.x, -local_vel.z)   # the legs trail behind wherever you are going, however far round that is
	else:
		_reverse = false
	_twist = lerp_angle(_twist, twist_target, 1.0 - exp(-delta * 12.0))
	if absf(_twist) > 0.002:
		var h: Quaternion = _pose.rot[hips]
		var turned := Quaternion(Vector3.UP, _twist) * h
		_pose.rot[hips] = turned
		_pose.rot[spine] = turned.inverse() * h * _pose.rot[spine]

	# --- Power (visor glow): off when dead, back on at respawn
	var power_target := 1.0
	if _dead_time >= 0.0:
		_dead_time += delta
		power_target = 0.0 if _dead_time > 0.25 else (1.0 if fmod(_dead_time, 0.1) < 0.05 else 0.2)
	_power = move_toward(_power, power_target, delta * (12.0 if power_target < _power else 2.5))
	model.set_power(_power)

	if _akimbo:
		Hands.set_hand(_pose, rig, "gun", 1.0 - _reload_w, true)   # the left hand has a gun of its own, whatever the arm is doing (a reload poses it itself)
	_pose.apply(model.skeleton)
	model.settle_sway()   # a custom character's cape and tail
	# The reload's own effects: the gun's glow, the spent cell thrown clear. (In first
	# person the arms you see are ViewModel's, and it throws the cell.)
	var fx_t := _reload_t if _reload_w > 0.0 and _reload_t >= 0.0 else -1.0
	ReloadFx.update(model, weapon, _fx_t, fx_t, null if first_person else fx_parent, inp.velocity)
	_fx_t = fx_t


## Your own body in first person: you see your legs and torso (not the head or the
## arms; ViewModel draws those). Call after update(). The body is kept under and a
## little behind the camera whatever it is doing, so you never look into your own
## chest: its neck stays behind the eyes (by the depth of this robot's chest),
## further back the more you look down.
## amount: 1 in first person, 0 in third person (CameraRig.first_person_amount).
func place_for_view(amount: float, eye_height: float, pitch: float) -> void:
	if model.view_mesh:
		model.view_mesh.visible = amount > 0.0
	if amount <= 0.0:
		model.position = Vector3.ZERO
		return
	var neck := model.bone_position("head")
	var back := model.chest_front + VIEW_BACK \
		+ VIEW_BACK_DOWN * clampf((-pitch - VIEW_BACK_FROM) / (deg_to_rad(89.0) - VIEW_BACK_FROM), 0.0, 1.0)
	var height := eye_height - VIEW_NECK_BELOW - neck.y
	var offset := Vector3(clampf(-neck.x, -VIEW_SIDE, VIEW_SIDE), minf(height, 0.0), back - neck.z)
	# A "view_" clip is made for the camera: its neck goes exactly where the camera expects it.
	offset = offset.lerp(Vector3(-neck.x, height, back - neck.z), _pin)
	model.position = offset * amount


func _pick(inp: RobotAnimInput) -> String:
	if not inp.alive:
		return "death"
	match inp.state:
		S.GROUND: return "loco"
		S.CROUCH: return "crouch"
		S.SLIDE: return "slide"
		S.AIR: return "tuck" if inp.crouched else "air"
		S.GRAPPLE: return "grapple"
		S.WALL_RUN, S.WALL_SIT: return "wall_r" if inp.wall_right() else "wall_l"   # (a wall sit leans on the wall-run pose for now)
		S.MANTLE: return "vault" if inp.vaulting() else "climb"
		S.DIVE: return "dive"
		S.ROLL: return "roll"
		S.BELLY_SLIDE: return "belly_slide"
		S.FLIP: return FLIPS[inp.flip()]
		S.GLIDE: return "glide"
	return "air"


func _switch(key: String, inp: RobotAnimInput) -> void:
	# Landing: dip in proportion to how hard we came down.
	if source in AIRBORNE and key in ["loco", "crouch"] and _prev_vy < -3.0:
		_land = clampf(-_prev_vy / 13.0, 0.3, 1.0)
	if key == "air":
		_air_t = _air_target(inp.velocity.y)
	if key == "death":
		_dead_time = 0.0
	_from.copy(_base)
	_fade = 0.0 if source != "" else 1.0
	_fade_time = FADES.get(key, FADE_DEFAULT)
	_time = 0.0
	source = key


func _air_target(vy: float) -> float:
	return clampf(remap(vy, 7.0, -12.0, 0.0, 1.0), 0.0, 1.0)


## The clip to play for `clip`: in first person, its "view_" version if there is one.
func _seen(clip: String) -> String:
	if first_person and rig.has_clip("view_" + clip):
		_view_clip = true
		return "view_" + clip
	return clip


func _sample_body(key: String, inp: RobotAnimInput, local_vel: Vector3, speed: float, delta: float) -> void:
	var direction := -1.0 if _reverse else 1.0
	_view_clip = false
	match key:
		"loco":
			var wr := clampf(speed / RUN_SPEED, 0.0, 1.0)
			var ws := clampf((speed - RUN_SPEED) / (SPRINT_SPEED - RUN_SPEED), 0.0, 1.0)
			var run_len := rig.length("run")
			var sprint_len := rig.length("sprint")
			var rate := clampf(speed / lerpf(RUN_SPEED, SPRINT_SPEED, ws), 0.6, 1.5) / lerpf(run_len, sprint_len, ws)
			_phase = fposmod(_phase + rate * delta * direction, 1.0)
			_idle_time = fmod(_idle_time + delta, rig.length("idle"))
			rig.sample(_pose, "idle", _idle_time)
			if wr > 0.01:
				rig.sample(_tmp, "run", _phase * run_len)
				_pose.blend(_tmp, smoothstep(0.0, 1.0, wr))
			if ws > 0.01:
				rig.sample(_tmp, "sprint", _phase * sprint_len)
				_pose.blend(_tmp, ws)
		"crouch":
			var wc := clampf(speed / (CROUCH_SPEED * 0.6), 0.0, 1.0)
			var walk_len := rig.length("crouch_walk")
			_phase = fposmod(_phase + clampf(speed / CROUCH_SPEED, 0.5, 1.6) / walk_len * delta * direction, 1.0)
			_idle_time = fmod(_idle_time + delta, rig.length("crouch_idle"))
			rig.sample(_pose, "crouch_idle", _idle_time)
			if wc > 0.01:
				rig.sample(_tmp, "crouch_walk", _phase * walk_len)
				_pose.blend(_tmp, smoothstep(0.0, 1.0, wc))
		"air":
			_air_t = lerpf(_air_t, _air_target(inp.velocity.y), 1.0 - exp(-delta * 14.0))
			rig.sample(_pose, "air", _air_t * rig.length("air"))
		"tuck":
			_loop("air_tuck")
		"glide":
			rig.sample(_pose, "air", 0.5 * rig.length("air"))
			_glide_legs(Vector2(inp.velocity.x, inp.velocity.z).length())
		"belly_slide":
			# Sliding: a still pose. Slowed to a crawl: the knees work, at crawling pace.
			_loop("belly_slide")
			var wc := clampf((CRAWL_SPEED + 0.6 - speed) / 0.6, 0.0, 1.0) * clampf(speed / 0.5, 0.0, 1.0)
			if wc > 0.01 and rig.has_clip("belly_crawl"):
				var crawl_len := rig.length("belly_crawl")
				_phase = fposmod(_phase + clampf(speed / CRAWL_SPEED, 0.4, 1.4) / crawl_len * delta, 1.0)
				rig.sample(_tmp, "belly_crawl", _phase * crawl_len)
				_pose.blend(_tmp, smoothstep(0.0, 1.0, wc))
		"slide", "grapple", "dive":
			_loop(key)
		"wall_l", "wall_r":
			var clip := "wall_run_l" if key == "wall_l" else "wall_run_r"
			if rig.has_clip(clip):
				var wlen := rig.length(clip)
				_phase = fposmod(_phase + clampf(speed / WALL_SPEED, 0.6, 1.4) / wlen * delta, 1.0)
				rig.sample(_pose, clip, _phase * wlen)
			else:
				_loop("air")
		_:   # one-shots: vault, climb, roll, flips, death
			var clip := _seen(key)
			if rig.has_clip(clip):
				rig.sample(_pose, clip, minf(_time, rig.length(clip)))
			else:
				rig.sample(_pose, "air", 0.5 * rig.length("air"))


## Gliding: both legs together, trailing back (the waist turn in update points
## "back" away from where you are going), the back one a little straighter than
## the front, toes pointed, drifting gently. The hips tip forward with speed.
func _glide_legs(speed: float) -> void:
	var fast := clampf(speed / GLIDE_TRAIL_SPEED, 0.0, 1.0)
	var trail := deg_to_rad(lerpf(GLIDE_HANG, GLIDE_TRAIL, fast))
	var lean := deg_to_rad(GLIDE_LEAN) * fast
	var drift := sin(_time * TAU / 1.6) * deg_to_rad(3.0)
	_pose.rot[_b["hips"]] = Quaternion(Vector3.RIGHT, -lean)
	# (thigh angles are from the tipped hips: the lean is already in them)
	_pose.rot[_b["thigh_l"]] = Quaternion(Vector3.RIGHT, -(trail - lean) - drift) * Quaternion(Vector3.BACK, -0.05)
	_pose.rot[_b["thigh_r"]] = Quaternion(Vector3.RIGHT, -(trail - lean) * 0.55 + drift) * Quaternion(Vector3.BACK, 0.05)
	_pose.rot[_b["shin_l"]] = Quaternion(Vector3.RIGHT, -deg_to_rad(14.0))
	_pose.rot[_b["shin_r"]] = Quaternion(Vector3.RIGHT, -deg_to_rad(lerpf(22.0, 48.0, fast)))
	_pose.rot[_b["foot_l"]] = Quaternion(Vector3.RIGHT, -deg_to_rad(35.0))
	_pose.rot[_b["foot_r"]] = Quaternion(Vector3.RIGHT, -deg_to_rad(35.0))
	_pose.pos[_b["hips"]] += Vector3(0.0, 0.015 * sin(_time * TAU / 1.6), 0.0)


func _loop(clip: String) -> void:
	clip = _seen(clip)
	if not rig.has_clip(clip):
		rig.sample(_pose, "air", 0.5 * rig.length("air"))
		return
	rig.sample(_pose, clip, fmod(_time, rig.length(clip)))
