class_name MeleeSwing
extends RefCounted
## How a melee weapon is held, wound up and swung. Shared by the body everyone sees
## (RobotAnimator) and your own first-person arms (ViewModel).
##
## Every swing comes from the side, and is held in both hands wherever the weapon
## allows (everything but the dagger and the brass knuckles):
##  - ready: the weapon up in front of the chest;
##  - winding up, while the button is held: the whole body coils round to the right
##    and the weapon draws back behind the shoulder, further the longer it is held.
##    This is the only sign of how charged a swing is (there is no meter), so it is
##    big enough to read from across the arena; fully wound, the weapon trembles;
##  - the blow, on letting go: the body unwinds and the weapon sweeps flat across the
##    front, right to left, then follows through past the target (further the more
##    it was wound up) and comes back to ready. The spear thrusts instead.
## A blow that lands freezes the swing for a moment (hit_stop) so the hit has weight.
##
## The weapon is animated, not the arms: each key says where the grip is and which
## way the blade points, in the "hold frame" (the chest's own space: +X right, +Y up,
## -Z forward, from the point midway between the shoulders), and the arms are then
## bent to reach it (hold()). So the hands stay on the weapon whatever the body is
## doing, and every robot (they share a skeleton) swings the same way.

const STRIKE := 0.13     ## seconds from letting go to the end of the blow, times the weapon's pace
const HIT_AT := 0.55     ## how far into the blow it lands
const FOLLOW := 0.12
const RECOVER := 0.3
const MIN_WOUND := 0.4   ## how far a tap draws back, as a part of a full wind-up
const DRAW := 14.0       ## how quickly the pose follows the wind-up (per second)

## What a key holds.
enum { GRIP, BLADE, LEAD, TURN, LEAN, LEFT }
## Each key: [where the grip (the right hand) is, which way the blade points, which way
## its edge faces (the way it is travelling), chest turn (+ = to the left; the spine adds
## half as much again), lean (+ = forward), where the left hand holds it (metres along
## the weapon from the right hand: - = toward the pommel)].
## Keys: ready, fully wound up, the moment the blow lands, the end of the follow-through.
const KEYS := {
	# The base two-handed swing: cocked behind the right shoulder like a batter, a flat cut across.
	"sword": [
		[Vector3(0.1, -0.2, -0.3), Vector3(0.32, 0.8, -0.5), Vector3(-0.5, -0.3, -0.8), -0.14, 0.0, -0.14],
		[Vector3(0.11, -0.07, -0.25), Vector3(0.9, 0.35, 0.25), Vector3(0.2, 0.0, -1.0), -0.72, -0.08, -0.14],
		[Vector3(0.0, -0.17, -0.38), Vector3(0.12, 0.04, -0.99), Vector3(-1.0, 0.0, 0.0), 0.12, 0.2, -0.14],
		[Vector3(-0.1, -0.12, -0.3), Vector3(-0.85, 0.1, -0.5), Vector3(-0.5, 0.0, 0.87), 0.62, 0.14, -0.14],
	],
	# The hammer hangs back low and level, and the whole body goes with it.
	"hammer": [
		[Vector3(0.1, -0.2, -0.3), Vector3(0.36, 0.72, -0.58), Vector3(-0.5, -0.3, -0.8), -0.16, 0.0, -0.17],
		[Vector3(0.12, -0.1, -0.24), Vector3(0.88, 0.02, 0.47), Vector3(0.45, 0.0, -0.9), -0.82, -0.14, -0.17],
		[Vector3(0.0, -0.17, -0.38), Vector3(0.12, -0.05, -0.99), Vector3(-1.0, 0.0, 0.0), 0.14, 0.26, -0.17],
		[Vector3(-0.1, -0.14, -0.3), Vector3(-0.85, -0.05, -0.5), Vector3(-0.5, 0.0, 0.87), 0.7, 0.2, -0.17],
	],
	# The axe starts higher and comes across and down.
	"axe": [
		[Vector3(0.1, -0.2, -0.3), Vector3(0.32, 0.8, -0.5), Vector3(-0.5, -0.3, -0.8), -0.14, 0.0, -0.15],
		[Vector3(0.11, -0.03, -0.25), Vector3(0.72, 0.62, 0.3), Vector3(0.3, -0.25, -0.92), -0.74, -0.1, -0.15],
		[Vector3(0.0, -0.17, -0.38), Vector3(0.12, -0.05, -0.99), Vector3(-0.92, -0.38, 0.0), 0.12, 0.24, -0.15],
		[Vector3(-0.1, -0.2, -0.29), Vector3(-0.8, -0.3, -0.52), Vector3(-0.5, -0.2, 0.84), 0.62, 0.2, -0.15],
	],
	# The bat: the widest of all, wound far behind and finished all the way round.
	"bat": [
		[Vector3(0.1, -0.19, -0.3), Vector3(0.4, 0.82, -0.4), Vector3(-0.5, -0.3, -0.8), -0.16, 0.0, -0.12],
		[Vector3(0.11, -0.05, -0.25), Vector3(0.8, 0.5, 0.33), Vector3(0.25, 0.0, -0.97), -0.84, -0.08, -0.12],
		[Vector3(0.0, -0.16, -0.38), Vector3(0.12, 0.04, -0.99), Vector3(-1.0, 0.0, 0.0), 0.14, 0.18, -0.12],
		[Vector3(-0.1, -0.1, -0.29), Vector3(-0.9, 0.2, -0.38), Vector3(-0.4, 0.0, 0.92), 0.8, 0.12, -0.12],
	],
	# The spear is a thrust: level at the hip, drawn back, then driven out through the left hand.
	"spear": [
		[Vector3(0.12, -0.2, -0.1), Vector3(-0.34, 0.06, -0.94), Vector3(0.0, -1.0, 0.0), -0.24, 0.0, 0.27],
		[Vector3(0.2, -0.14, 0.06), Vector3(-0.77, 0.04, -0.64), Vector3(0.0, -1.0, 0.0), -0.62, -0.12, 0.27],
		[Vector3(0.0, -0.14, -0.36), Vector3(0.44, 0.0, -0.9), Vector3(0.0, -1.0, 0.0), 0.3, 0.34, 0.05],
		[Vector3(0.0, -0.15, -0.38), Vector3(0.5, -0.03, -0.86), Vector3(0.0, -1.0, 0.0), 0.36, 0.4, 0.05],
	],
	# One hand: a slash from out wide on the right.
	"dagger": [
		[Vector3(0.2, -0.2, -0.3), Vector3(-0.1, 0.62, -0.78), Vector3(-0.6, -0.2, -0.6), -0.08, 0.0, 0.0],
		[Vector3(0.34, -0.08, -0.1), Vector3(0.62, 0.3, -0.72), Vector3(0.75, 0.0, 0.66), -0.55, -0.05, 0.0],
		[Vector3(0.04, -0.14, -0.42), Vector3(-0.5, 0.1, -0.86), Vector3(-0.86, 0.0, 0.5), 0.2, 0.18, 0.0],
		[Vector3(-0.1, -0.15, -0.3), Vector3(-0.95, 0.0, -0.3), Vector3(-0.3, 0.0, 0.95), 0.5, 0.12, 0.0],
	],
	# Brass knuckles: a hook, the fist swung round from the side.
	"brass_knuckles": [
		[Vector3(0.16, -0.12, -0.3), Vector3(0.0, 1.0, 0.1), Vector3(0.0, 0.0, -1.0), -0.1, 0.0, 0.0],
		[Vector3(0.33, -0.08, -0.06), Vector3(0.0, 1.0, 0.0), Vector3(0.4, 0.0, -0.92), -0.6, -0.05, 0.0],
		[Vector3(0.0, -0.08, -0.42), Vector3(0.0, 1.0, 0.0), Vector3(-0.95, 0.0, -0.3), 0.3, 0.2, 0.0],
		[Vector3(-0.13, -0.1, -0.3), Vector3(0.0, 1.0, 0.0), Vector3(-0.8, 0.0, 0.6), 0.6, 0.14, 0.0],
	],
}
## How long the blow, follow-through and recovery take, against the sword's.
const PACE := {"sword": 1.0, "hammer": 1.3, "dagger": 0.6, "brass_knuckles": 0.55, "spear": 0.85, "axe": 1.15, "bat": 1.1}
## One-handed weapons: where the left fist is held, up in a guard.
const GUARD := Vector3(-0.13, -0.1, -0.3)
## Which way each elbow points (down, out and a little back), in the hold frame.
const ELBOW_R := Vector3(0.55, -0.8, 0.25)
const ELBOW_L := Vector3(-0.55, -0.8, 0.25)

enum { REST, WIND, SWING }

var weapon := "sword"
var two_handed := true
var _keys: Array = KEYS.sword
var _pace := 1.0
var _phase := REST
var _cur: Array = []       # the pose right now (a key)
var _from: Array = []      # where the blow started
var _end: Array = []       # where this blow's follow-through ends
var _t := 0.0              # seconds into the blow
var _charge := 0.0         # how wound up, 0..1
var _wound := false        # wind() was called since the last sample: still holding
var _stop := 0.0           # hit-stop left: the swing is frozen
var _clock := 0.0


func _init(weapon_id: String = "sword") -> void:
	set_weapon(weapon_id)


func set_weapon(weapon_id: String) -> void:
	weapon = weapon_id
	_keys = KEYS.get(weapon_id, KEYS.sword)
	_pace = PACE.get(weapon_id, 1.0)
	two_handed = WeaponData.by_id(weapon_id).two_handed
	stop()


## Still winding up this frame: `charge` 0..1 is how far (see WeaponData.charge_of).
func wind(charge: float) -> void:
	_charge = clampf(charge, 0.0, 1.0)
	_wound = true
	if _phase == REST or (_phase == SWING and _t >= (STRIKE + FOLLOW) * _pace):
		_phase = WIND


## Let go: the blow starts from wherever the wind-up had got to. `power` 0..1 is how
## wound up it was: a harder swing follows through further.
func swing(power: float) -> void:
	_phase = SWING
	_t = 0.0
	_stop = 0.0
	_wound = false
	_from = _cur.duplicate()
	_end = _mix(_keys[2], _keys[3], lerpf(0.45, 1.0, clampf(power, 0.0, 1.0)))


## Winding up or swinging (not just holding the weapon ready).
func active() -> bool:
	return _phase != REST


func winding() -> bool:
	return _phase == WIND


func stop() -> void:
	_phase = REST
	_cur = _keys[0].duplicate()
	_wound = false
	_charge = 0.0


## Seconds from letting go to the blow landing.
static func impact_time(weapon_id: String) -> float:
	return STRIKE * PACE.get(weapon_id, 1.0) * HIT_AT


## The blow landed: hold the swing still for a moment.
func hit_stop(seconds: float = 0.07) -> void:
	if _phase == SWING:
		_stop = seconds


## In the blow or the start of its follow-through: the blade is cutting (draw its trail).
func cutting() -> bool:
	return _phase == SWING and _t < (STRIKE + FOLLOW * 0.7) * _pace


## The longest a blow takes, from letting go to back at ready.
func length() -> float:
	return (STRIKE + FOLLOW + RECOVER) * _pace


## The pose right now (a key, see KEYS); advances the clock by delta.
func sample(delta: float) -> Array:
	_clock += delta
	match _phase:
		WIND:
			if not _wound:   # let go without a swing (the match ended, a flying kick took over)
				_phase = REST
			else:
				var target := _mix(_keys[0], _keys[1], MIN_WOUND + (1.0 - MIN_WOUND) * _ease_out(_charge))
				_cur = _mix(_cur, target, 1.0 - exp(-delta * DRAW))
		SWING:
			var strike := STRIKE * _pace
			var hit := strike * HIT_AT
			var follow := FOLLOW * _pace
			if _t < hit:
				_cur = _mix(_from, _keys[2], _ease_in(_t / hit))
			elif _t < strike + follow:
				_cur = _mix(_keys[2], _end, _ease_out((_t - hit) / (strike + follow - hit)))
			else:
				_cur = _mix(_end, _keys[0], smoothstep(0.0, 1.0, (_t - strike - follow) / (RECOVER * _pace)))
			if _stop > 0.0:
				_stop -= delta
			else:
				_t += delta
			if _t >= length():
				stop()
	if _phase == REST:
		_cur = _mix(_cur, _keys[0], 1.0 - exp(-delta * DRAW))
	_wound = false
	var out := _cur.duplicate()
	if _phase == WIND and _charge >= 1.0:   # fully wound: straining to hold it
		out[BLADE] = (out[BLADE] as Vector3 + Vector3(sin(_clock * 41.0), sin(_clock * 53.0), 0.0) * 0.022).normalized()
	return out


## How far round the body is wound right now: -1 fully wound up, +1 at the end of a
## full follow-through. The first-person view turns a little with it.
func coil() -> float:
	var turn: float = _cur[TURN] - _keys[0][TURN]
	return clampf(turn / maxf(absf(_keys[1][TURN] - _keys[0][TURN]), 0.01), -1.0, 1.0) if turn < 0.0 \
		else clampf(turn / maxf(absf(_keys[3][TURN] - _keys[0][TURN]), 0.01), -1.0, 1.0)


## The ready pose of a weapon.
static func ready(weapon_id: String) -> Array:
	return (KEYS.get(weapon_id, KEYS.sword)[0] as Array).duplicate()


static func _mix(a: Array, b: Array, u: float) -> Array:
	var ba: Vector3 = (a[BLADE] as Vector3).normalized()
	var bb: Vector3 = (b[BLADE] as Vector3).normalized()
	var la: Vector3 = (a[LEAD] as Vector3).normalized()
	var lb: Vector3 = (b[LEAD] as Vector3).normalized()
	return [(a[GRIP] as Vector3).lerp(b[GRIP], u), _turn(ba, bb, u), _turn(la, lb, u),
		lerpf(a[TURN], b[TURN], u), lerpf(a[LEAN], b[LEAN], u), lerpf(a[LEFT], b[LEFT], u)]


## From one direction to another along the arc between them.
static func _turn(a: Vector3, b: Vector3, u: float) -> Vector3:
	if a.dot(b) > 0.9995 or a.dot(b) < -0.999:
		return a.lerp(b, u).normalized() if a.dot(b) > 0.0 else a
	return a.slerp(b, u)


# ---------------------------------------------------------------------------
# Laying a key over a pose

## Turns and leans the upper body with the swing (`weight` 0..1). Call before hold(),
## and before anything that reads where the chest is.
static func turn_body(pose: RobotPose, bones: Dictionary, k: Array, weight: float = 1.0) -> void:
	if weight <= 0.0:
		return
	var turn: float = k[TURN] * weight
	var lean: float = k[LEAN] * weight
	if bones.has("chest"):
		var c: int = bones["chest"]
		pose.rot[c] = Quaternion(Vector3.UP, turn) * pose.rot[c]
	if bones.has("spine"):
		var sp: int = bones["spine"]
		pose.rot[sp] = Quaternion(Vector3.UP, turn * 0.5) * Quaternion(Vector3.RIGHT, -lean) * pose.rot[sp]
	if bones.has("head"):   # the head keeps looking ahead
		var h: int = bones["head"]
		pose.rot[h] = Quaternion(Vector3.UP, -turn * 1.35) * pose.rot[h]


## Bends the arms so the weapon is where key `k` says: the right hand on the grip,
## and the left on the handle too (`two_handed`) or up in a guard.
## pitch: the hold frame tips up or down by this much (aiming), about the shoulders.
## right, left: how much each arm takes the pose, 0..1 (the left lets go to grapple).
## shift: moves the whole hold (first person: up into view).
static func hold(pose: RobotPose, rig: RobotRig, k: Array, two_handed: bool, pitch: float = 0.0,
		right: float = 1.0, left: float = 1.0, shift: Vector3 = Vector3.ZERO) -> void:
	if right <= 0.0 and left <= 0.0:
		return
	var b := rig.bones
	# Where the chest is, in the model's space.
	var rot := pose.rot[b["root"]]
	var at := pose.pos[b["root"]]
	for bone in ["hips", "spine", "chest"]:
		var i: int = b[bone]
		at += rot * pose.pos[i]
		rot = rot * pose.rot[i]
	var up_r: int = b["upper_arm_r"]
	var up_l: int = b["upper_arm_l"]
	var frame := Basis(rot * Quaternion(Vector3.RIGHT, pitch))
	var origin := at + rot * Vector3(0.0, pose.pos[up_r].y, 0.0)
	# The weapon: grip, blade (+Y), edge (-Z).
	var grip: Vector3 = origin + frame * (k[GRIP] as Vector3 + shift)
	var blade: Vector3 = (frame * (k[BLADE] as Vector3)).normalized()
	var lead: Vector3 = frame * (k[LEAD] as Vector3)
	lead = (lead - blade * lead.dot(blade)).normalized()
	var weapon_basis := Basis(blade.cross(-lead), blade, -lead)
	var hand_rot := (weapon_basis * MeleeModel.HOLD.inverse()).get_rotation_quaternion()
	var palm: Vector3 = rig.rest_pos[b["pistol"]]   # from the hand bone to the grip
	# Right arm
	var solved := _reach(pose, rig, rot, at, "r", grip - hand_rot * palm, hand_rot, frame * ELBOW_R, right)
	if b.has("pistol"):
		pose.rot[b["pistol"]] = pose.rot[b["pistol"]].slerp(Quaternion.IDENTITY, right)
	if left <= 0.0:
		return
	# Left arm: on the handle, coming at it from the left shoulder's side; or a guard.
	var hand_l := hand_rot
	var want: Vector3
	if two_handed:
		var on_handle: Vector3 = solved + hand_rot * palm + blade * float(k[LEFT])
		var to_shoulder := at + rot * pose.pos[up_l] - on_handle
		to_shoulder = to_shoulder - blade * to_shoulder.dot(blade)
		var wrist := hand_rot * -palm
		wrist = wrist - blade * wrist.dot(blade)
		if to_shoulder.length_squared() > 0.0001 and wrist.length_squared() > 0.000001:
			hand_l = Quaternion(blade, wrist.normalized().signed_angle_to(to_shoulder.normalized(), blade)) * hand_rot
		want = on_handle - hand_l * palm
	else:
		hand_l = Quaternion(frame) * Quaternion(Vector3.RIGHT, 2.2)   # the forearm up, the fist by the chin
		want = origin + frame * (GUARD + shift)
	_reach(pose, rig, rot, at, "l", want, hand_l, frame * ELBOW_L, left)


## Two-bone reach: bends one arm so its hand bone is at `want` (as near as it can
## get), turned to `hand_rot`, with the elbow toward `elbow`. All in the model's
## space. Returns where the hand bone ended up.
static func _reach(pose: RobotPose, rig: RobotRig, chest_rot: Quaternion, chest_at: Vector3, side: String,
		want: Vector3, hand_rot: Quaternion, elbow: Vector3, weight: float) -> Vector3:
	var b := rig.bones
	var up: int = b["upper_arm_" + side]
	var fore: int = b["forearm_" + side]
	var hand: int = b["hand_" + side]
	var shoulder := chest_at + chest_rot * pose.pos[up]
	var upper_len := pose.pos[fore].length()
	var fore_len := pose.pos[hand].length()
	var to := want - shoulder
	var dist := clampf(to.length(), absf(upper_len - fore_len) + 0.01, (upper_len + fore_len) * 0.999)
	var dir := to.normalized() if to.length_squared() > 0.000001 else chest_rot * Vector3.FORWARD
	var along := (upper_len * upper_len - fore_len * fore_len + dist * dist) / (2.0 * dist)
	var out := sqrt(maxf(upper_len * upper_len - along * along, 0.0))
	var side_dir := elbow - dir * elbow.dot(dir)
	side_dir = side_dir.normalized() if side_dir.length_squared() > 0.000001 else dir.cross(chest_rot * Vector3.RIGHT).normalized()
	var elbow_at := shoulder + dir * along + side_dir * out
	var hand_at := shoulder + dir * dist
	var hinge := side_dir.cross(dir).normalized()   # the elbow's axis: both bones' own +X
	var up_y := (shoulder - elbow_at).normalized()
	var fore_y := (elbow_at - hand_at).normalized()
	var up_rot := Basis(hinge, up_y, hinge.cross(up_y)).get_rotation_quaternion()
	var fore_rot := Basis(hinge, fore_y, hinge.cross(fore_y)).get_rotation_quaternion()
	var w := clampf(weight, 0.0, 1.0)
	pose.rot[up] = pose.rot[up].slerp(chest_rot.inverse() * up_rot, w)
	pose.rot[fore] = pose.rot[fore].slerp(up_rot.inverse() * fore_rot, w)
	pose.rot[hand] = pose.rot[hand].slerp(fore_rot.inverse() * hand_rot, w)
	return hand_at


static func _ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


## Slow to start, then fast: a blow that whips through.
static func _ease_in(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (2.0 - u) * 0.5 + u * u * 0.5
