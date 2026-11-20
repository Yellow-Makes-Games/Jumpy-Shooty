class_name VictoryPoser
extends PortraitPoser
## How a character on the results page's stage (ResultsStage) stands: one of Podium's
## poses, laid over the game's own body standing still (a RobotAnimator, as a
## PortraitPoser's is: the stance, the breathing and each torso's idle habit are a
## match's), with whatever it holds: a gun, a gun in each hand, a blade, a hammer,
## fists, nothing.
##
##   RAISE    the weapon thrust up over its head, the other fist clenched at its side
##   PUMP     the weapon lying back over its shoulder, the other fist pumped
##   HIP      the weapon down at its side (a blade point down like a cane, a big one on
##            its shoulder), the other fist on its hip, chin up
##   PRESENT  turns once right round and ends with its arms out wide, the weapon held
##            out for all to see, in a small bow
##   SPORT    second and third: the weapon lowered, and a nod toward the winner
##   EASY     nobody won, or they never finished: the weapon lowered, that is all
##
## It moves into its pose over IN seconds (after `wait`: while it is still building
## in), with a flourish as it gets there (the weapon pumped in the air, the fist pumped,
## a nod, a deeper bow); the winner (`repeats`) does that again every several seconds.
##
##   var poser := VictoryPoser.new(robot, Podium.RAISE)
##   poser.repeats = true
##   poser.update(delta)            # every frame
##   robot.rotation.y = facing + poser.spin

const IN := 1.0             ## seconds to move into the pose
const FLOURISH := 1.1       ## seconds a flourish takes
const FLOURISH_AT := 0.7    ## the first comes this far into moving in (a share of IN)
const BEAT_MIN := 5.0       ## the winner's comes again after this long at least...
const BEAT_MAX := 7.5       ## ...and this long at most
const SPIN_TIME := 0.85     ## PRESENT: seconds its turn right round takes

## The right hand, as PortraitPoser's keys: [grip, where the barrel or blade points,
## where the gun's top (or the blade's edge) faces], in the chest's frame at shoulder
## height (x right, y up, -z forward).
const RAISE_GUN := [Vector3(0.30, 0.46, -0.10), Vector3(0.25, 0.93, -0.15), Vector3(0.0, 0.2, 1.0)]
const RAISE_BLADE := [Vector3(0.30, 0.46, -0.10), Vector3(0.25, 0.93, -0.15), Vector3(0.0, 0.1, -1.0)]
const PRESENT_GUN := [Vector3(0.58, 0.02, -0.25), Vector3(0.5, 0.85, -0.15), Vector3(-0.2, 0.2, 1.0)]
const PRESENT_BLADE := [Vector3(0.58, 0.02, -0.25), Vector3(0.5, 0.85, -0.15), Vector3(0.3, -0.2, -1.0)]
const SHOULDER_GUN := [Vector3(0.24, -0.16, -0.20), Vector3(0.05, 0.62, 0.78), Vector3(0.0, 0.78, -0.62)]     ## PUMP: lying back over the shoulder, the hand in front of it
const SHOULDER_BLADE := [Vector3(0.24, -0.16, -0.20), Vector3(0.05, 0.62, 0.78), Vector3(0.0, 0.78, -0.62)]   ## ...a blade on its back, the edge up
const PLANT_BLADE := [Vector3(0.36, -0.36, -0.12), Vector3(0.12, -0.98, -0.12), Vector3(0.0, 0.0, -1.0)]      ## HIP: a blade point down beside it, like a cane
const PLANT_LEAN := Vector3(0.75, 0.0, -0.66)     ## ...a long one leans this way (out and forward) to keep its point on the floor...
const PLANT_CLEAR := 0.04                         ## ...this far (metres) off it
const FIST_SIDE := [Vector3(0.30, -0.41, -0.07), Vector3(0.1, 0.35, -0.93), Vector3(0.0, -1.0, -0.3)]   ## a bare fist (or one with claws on) clenched at the side
const RAISE_PUMP := 0.13                          ## RAISE's flourish: the weapon comes down this far (metres) and goes up again, twice
const ELBOW_OUT := Vector3(1.0, 0.0, 0.25)        ## which way the right elbow points with the weapon overhead...
const ELBOW_LOW := Vector3(0.25, -1.0, 0.35)      ## ...and held out to the side

## The left hand (the wrist), in the same frame: clenched at the side, up in a pumped
## fist (drawn back, then punched up), on the hip, held out wide.
const LEFT_SIDE := Vector3(-0.29, -0.40, -0.08)
const LEFT_PUMP := Vector3(-0.30, 0.22, -0.20)
const LEFT_PUMP_BACK := Vector3(-0.27, -0.02, -0.25)
const LEFT_PUMP_UP := Vector3(-0.30, 0.45, -0.12)
const LEFT_HIP := Vector3(-0.22, -0.39, 0.03)
const LEFT_OUT := Vector3(-0.56, -0.10, -0.22)
const L_ELBOW_BACK := Vector3(-0.3, 0.0, 1.0)     ## which way the left elbow points: behind...
const L_ELBOW_DOWN := Vector3(-0.5, -0.8, 0.25)   ## ...down and out...
const L_ELBOW_WIDE := Vector3(-1.0, 0.0, 0.45)    ## ...out to the side (a hand on the hip)
const NOD := 0.3                                  ## radians a nod tips the head
const LOOK := 0.45                                ## SPORT: radians its head turns toward the winner

var kind := Podium.EASY
var wait := 0.0          ## seconds before it starts moving into its pose (it is still building in)
var repeats := false     ## does its flourish again every several seconds (the winner)
var look := 0.0          ## SPORT: where the winner is: 1 to its own left, -1 to its right
var spin := 0.0          ## PRESENT: how far it still has to turn (radians): add it to its facing

var _t := 0.0            # seconds into moving into the pose
var _f := -1.0           # seconds into a flourish, or -1
var _first := false      # the flourish as it gets there has been started
var _beat := 0.0         # seconds until the winner's next
var _blade := -1.0       # how long its blade is from the grip to the point (metres), once measured


func _init(model: RobotModel, pose_kind: int = Podium.EASY, fx: Node = null) -> void:
	super(model, fx)
	kind = pose_kind
	_beat = _rng.randf_range(BEAT_MIN, BEAT_MAX)


## How far into its pose it is, 0..1.
func settled() -> float:
	return clampf(_t / IN, 0.0, 1.0)


## How far through a flourish it is, 0..1, or -1.
func flourishing() -> float:
	return _f / FLOURISH if _f >= 0.0 else -1.0


## Straight into its pose (for pictures and tests).
func settle() -> void:
	wait = 0.0
	_t = IN
	_first = true
	_f = -1.0
	spin = 0.0


## Its flourish now (for pictures and tests).
func flourish_now() -> bool:
	settle()
	_f = 0.0
	return true


func update(delta: float) -> void:
	if wait > 0.0:
		wait -= delta
	else:
		_t += delta
	if _f >= 0.0:
		_f += delta
		if _f >= FLOURISH:
			_f = -1.0
	elif kind != Podium.EASY and not _first and _t >= IN * FLOURISH_AT:
		_first = true
		_f = 0.0
	elif repeats and _first and _t >= IN:
		_beat -= delta
		if _beat <= 0.0:
			_beat = _rng.randf_range(BEAT_MIN, BEAT_MAX)
			_f = 0.0
	spin = 0.0
	if kind == Podium.PRESENT and wait <= 0.0 and _t < SPIN_TIME:
		var u := 1.0 - _t / SPIN_TIME
		spin = -TAU * u * u * u   # (fast at first, easing to a stop facing you)
	_inp.flags = RobotAnimInput.make_flags(false, false, false, 0, 0)
	animator.update(delta, _inp, robot.global_transform if robot.is_inside_tree() else Transform3D.IDENTITY)
	var pose: RobotPose = animator._pose
	if _empty:   # nothing to hold: the arms hang, under whatever the pose does with them
		_hang(pose, 1.0, true, true)
		_hang(pose, 1.0, false, true)
	var w := smoothstep(0.0, 1.0, settled())
	var f := flourishing()
	match kind:
		Podium.RAISE:
			_raise(pose, w, f)
		Podium.PUMP:
			_pump(pose, w, f)
		Podium.HIP:
			_hip(pose, w, f)
		Podium.PRESENT:
			_present(pose, w, f)
		_:
			_stand_down(pose, w, f)
	pose.apply(robot.skeleton)
	robot.settle_sway()


# --- The poses

## The weapon thrust up over its head; pumped in the air twice.
func _raise(pose: RobotPose, w: float, f: float) -> void:
	var up := sin(TAU * f) if f >= 0.0 else 0.0
	_body(pose, w, 0.10 - 0.05 * up * up, 0.0, 0.18)
	var key: Array = RAISE_BLADE if _melee or _empty else RAISE_GUN
	_place_right(pose, w, key[0] - Vector3(0.0, RAISE_PUMP * up * up, 0.0), key[1], key[2], ELBOW_OUT)
	_place_left(pose, w, LEFT_SIDE, L_ELBOW_BACK, "fist")


## The weapon against its shoulder; the other fist pumped.
func _pump(pose: RobotPose, w: float, f: float) -> void:
	var at := LEFT_PUMP
	var lift := 0.0
	if f >= 0.0:
		# Drawn back, punched up, and back to where it was.
		var back := smoothstep(0.0, 0.25, f) * (1.0 - smoothstep(0.25, 0.42, f))
		var up := smoothstep(0.25, 0.42, f) * (1.0 - smoothstep(0.62, 1.0, f))
		at = LEFT_PUMP.lerp(LEFT_PUMP_BACK, back).lerp(LEFT_PUMP_UP, up)
		lift = up
	_body(pose, w, 0.05 + 0.06 * lift, -0.10, 0.10 + 0.08 * lift)
	if _fists or _empty:
		_place_right(pose, w, FIST_SIDE[0], FIST_SIDE[1], FIST_SIDE[2], ELBOW_DOWN)
	else:
		var key: Array = SHOULDER_BLADE if _melee else SHOULDER_GUN
		_place_right(pose, w, key[0], key[1], key[2], ELBOW_LOW)
	_place_left(pose, w, at, L_ELBOW_DOWN, "fist")


## The weapon down at its side (a big one against its shoulder), the other fist on
## its hip, chin up; a nod.
func _hip(pose: RobotPose, w: float, f: float) -> void:
	var nod := _bell(f)
	_body(pose, w, 0.04, -0.12, 0.12 - NOD * nod, 0.22)
	if _fists or _empty:
		# Both fists on its hips.
		_place_right(pose, w, Vector3(-LEFT_HIP.x, LEFT_HIP.y, LEFT_HIP.z), FIST_SIDE[1], FIST_SIDE[2], Vector3(1.0, 0.0, 0.45))
	elif _melee:
		var key: Array = SHOULDER_BLADE if _shoulder else PLANT_BLADE
		_place_right(pose, w, key[0], key[1] if _shoulder else _planted(pose, key), key[2], ELBOW_LOW)
	else:
		var key: Array = SHOULDER_GUN if _shoulder else GUN_SIDE
		_place_right(pose, w, key[0], key[1], key[2], ELBOW_LOW if _shoulder else ELBOW_DOWN)
	if _akimbo:   # a gun in that hand too: it hangs at the other side
		_hang(pose, w, true, false)
	else:
		_place_left(pose, w, LEFT_HIP, L_ELBOW_WIDE, "fist")


## Which way a blade held at PLANT_BLADE's grip points to stand on its point: straight
## down if it is short enough to clear the floor, and leaning out and forward by as
## much as it takes if it is longer.
func _planted(pose: RobotPose, key: Array) -> Vector3:
	if _blade < 0.0 and robot.melee != null and robot.melee.is_inside_tree() and robot.melee.get_child_count() > 0 \
			and robot.melee.get_child(0).has_node("EdgeTip"):
		_blade = robot.melee.global_position.distance_to(MeleeModel.edge(robot.melee)[1])
	var b := animator.rig.bones
	var c := _chest(pose, b)
	var drop: float = ((c[1] as Vector3) + (c[0] as Quaternion) * Vector3(0.0, pose.pos[b["upper_arm_r"]].y + (key[0] as Vector3).y, 0.0)).y - PLANT_CLEAR
	if _blade <= drop or drop <= 0.0:
		return key[1]
	# (Worked out upright, whichever way the chest is tipped, and given in the chest's frame.)
	var down := drop / _blade
	var lean := (c[0] as Quaternion) * PLANT_LEAN
	lean = Vector3(lean.x, 0.0, lean.z).normalized()
	return (c[0] as Quaternion).inverse() * (Vector3(0.0, -down, 0.0) + lean * sqrt(1.0 - down * down))


## Arms out wide after its turn, the weapon held out for all to see, in a small bow;
## a deeper one.
func _present(pose: RobotPose, w: float, f: float) -> void:
	var bow := _bell(f)
	# (The arms come out as the turn ends.)
	var out := smoothstep(0.0, 1.0, clampf((_t - SPIN_TIME * 0.45) / (IN - SPIN_TIME * 0.45), 0.0, 1.0)) if _t < IN else 1.0
	_body(pose, w, -0.10 - 0.20 * bow, 0.0, 0.10 - 0.12 * bow)
	var key: Array = PRESENT_BLADE if _melee or _empty else PRESENT_GUN
	var low := Vector3(0.0, -0.08 * bow, 0.0)
	_place_right(pose, out, key[0] + low, key[1], key[2], ELBOW_LOW)
	_place_left(pose, out, LEFT_OUT + low, Vector3(-0.25, -1.0, 0.35), "open")


## SPORT and EASY: the weapon lowered; SPORT turns its head to the winner and nods.
func _stand_down(pose: RobotPose, w: float, f: float) -> void:
	if kind == Podium.SPORT:
		_body(pose, w, 0.0, look * 0.10, -NOD * _bell(f), look * LOOK)
	if _empty:
		return
	if _fists:
		_drop_arms(pose, w)
	elif not _melee:
		_lower_gun(pose, w)


# --- What they are made of

## 0 at either end of a flourish, 1 in the middle of it.
static func _bell(f: float) -> float:
	return sin(PI * f) * sin(PI * f) if f >= 0.0 else 0.0


## The body under a pose, `w` of the way: the spine tipped back by `lean` (radians; less
## than 0 forward), the chest turned `turn` to its left, the head tipped back by `chin`
## and turned `face` to its left. A weapon's own stance (the chest turned to shoulder a
## gun, or behind a blade) is squared up first: these poses are held facing you.
func _body(pose: RobotPose, w: float, lean: float, turn: float, chin: float, face: float = 0.0) -> void:
	if w <= 0.0:
		return
	var b := animator.rig.bones
	var chest: int = b["chest"]
	var head: int = b["head"]
	var spine: int = b["spine"]
	# Squared up: whichever way the chest is turned from the way the body faces, back.
	var facing: Quaternion = _chest(pose, b)[0]
	var ahead := facing * Vector3.FORWARD
	var back := Quaternion(Vector3.UP, -atan2(-ahead.x, -ahead.z) * w)
	var squared := pose.rot[chest] * (facing.inverse() * back * facing)
	pose.rot[head] = (pose.rot[chest].inverse() * squared).inverse() * pose.rot[head]
	pose.rot[chest] = squared
	pose.rot[spine] = Quaternion(Vector3.RIGHT, lean * w) * pose.rot[spine]
	pose.rot[chest] = Quaternion(Vector3.UP, turn * w) * pose.rot[chest]
	pose.rot[head] = Quaternion(Vector3.UP, (face - turn) * w) * Quaternion(Vector3.RIGHT, (chin - lean) * w) * pose.rot[head]


## The right hand with what it holds, where a key says (see RAISE_GUN), the elbow
## toward `elbow`: a gun by its grip, a blade or a hammer by its handle, a fist.
func _place_right(pose: RobotPose, w: float, grip: Vector3, along: Vector3, face: Vector3, elbow: Vector3) -> void:
	if w <= 0.0:
		return
	var rig := animator.rig
	var b := rig.bones
	var c := _chest(pose, b)
	var rot: Quaternion = c[0]
	var at: Vector3 = c[1]
	var frame := Basis(rot)
	var origin := at + rot * Vector3(0.0, pose.pos[b["upper_arm_r"]].y, 0.0)
	var grip_bone: int = b["pistol"]
	if _melee or _empty:
		# As MeleeSwing holds one: the handle along +Y, the edge leading.
		var held := MeleeSwing._weapon_basis([grip, along, face])
		var hand_rot := (frame * held * MeleeModel.HOLD.inverse()).get_rotation_quaternion()
		var palm: Vector3 = rig.rest_pos[grip_bone]
		MeleeSwing._reach(pose, rig, rot, at, "r", origin + frame * grip - hand_rot * palm, hand_rot, frame * elbow, w)
		pose.rot[grip_bone] = pose.rot[grip_bone].slerp(Quaternion.IDENTITY, w)
		Hands.set_hand(pose, rig, "fist" if _fists or _empty else "handle", w, false)
		return
	# A gun (as PortraitPoser lays one): -z down the barrel, +y its top.
	var barrel := along.normalized()
	var top := (face - barrel * face.dot(barrel)).normalized()
	var gun := frame * Basis(top.cross(-barrel), top, -barrel)
	var hand_rot := (gun * ReloadFx.GUN_REST.inverse()).get_rotation_quaternion() * pose.rot[grip_bone].inverse()
	var want: Vector3 = origin + frame * grip - hand_rot * pose.pos[grip_bone]
	MeleeSwing._reach(pose, rig, rot, at, "r", want, hand_rot, frame * elbow, w)


## The left hand (its wrist) at `where` in the chest's frame, the elbow toward `elbow`,
## the hand in line with the forearm and held `shape` (unless it has a gun of its own).
func _place_left(pose: RobotPose, w: float, where: Vector3, elbow: Vector3, shape: String) -> void:
	if w <= 0.0:
		return
	var rig := animator.rig
	var b := rig.bones
	var c := _chest(pose, b)
	var rot: Quaternion = c[0]
	var at: Vector3 = c[1]
	var frame := Basis(rot)
	var want := at + rot * Vector3(0.0, pose.pos[b["upper_arm_l"]].y, 0.0) + frame * where
	var hand: int = b["hand_l"]
	var before := pose.rot[hand]
	var to := want - (at + rot * pose.pos[b["upper_arm_l"]])
	var straight := Quaternion(Vector3.UP, -to.normalized()) if to.length_squared() > 0.0001 and to.normalized().dot(Vector3.UP) < 0.999 else Quaternion.IDENTITY
	MeleeSwing._reach(pose, rig, rot, at, "l", want, straight, frame * elbow, w)
	pose.rot[hand] = before.slerp(Quaternion.IDENTITY, w)
	if not _akimbo and not _fists:
		Hands.set_hand(pose, rig, shape, w, true)
	elif _fists and b.has("pistol_l"):
		pose.rot[b["pistol_l"]] = pose.rot[b["pistol_l"]].slerp(Quaternion.IDENTITY, w)
