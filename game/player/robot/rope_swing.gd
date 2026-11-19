class_name RopeSwing
extends RefCounted
## How a body hangs on the grappling hook's rope once it has pulled tight (see Grapple):
## loose, following the rope, not held in a pose.
##
##  - The left arm is up the rope and carries the weight. The body hangs from the
##    shoulders: the hips lean toward the line of the rope (LEAN of its angle), the legs
##    trail further along it (TRAIL), and the chest and head stay nearer upright,
##    looking where you aim.
##  - Nothing is rigid. The hips, the legs, the shins and the gun arm each follow where
##    they should hang on a spring of their own, each a beat behind the last, so when
##    the rope changes direction the body goes first and the legs swing after it.
##  - The moment the rope pulls tight the body takes the jolt: the chest is jerked
##    toward the hook, the legs are thrown back and whip through. The more slack the
##    winch took in, the bigger the jolt.
##  - The hips and legs face the way the swing goes; the waist turns to let the chest
##    aim somewhere else.
##  - Steering along the swing works the legs like a child on a playground swing: out
##    in front on the way forward, tucked under on the way back.
##  - Let go on the way up, going fast, and the body rolls forward once (flip()).
##
## It is looks only: nothing here moves the player. Everything is worked out from what
## every copy of the game knows about a player (RobotAnimInput: where they are, how
## fast, where the hook is, when the rope pulled tight), so your own body, another
## player's and a killcam's all hang the same way. RobotAnimator lays it over the
## body, ViewModel over your own arms in first person.

const S := MovementController.State
const ATTACH := 1.2                   ## where the rope meets the body, above the feet (HookLine.ATTACH_HEIGHT)
const PIVOT := Vector3(0.0, 1.32, 0.0)   ## the body hangs from here (the shoulders)

## How far each part leans from hanging straight down, as a share of the rope's own
## angle from straight up, and the most it ever leans (radians).
const LEAN := 0.5
const LEAN_MAX := 0.66
const TRAIL := 0.78
const TRAIL_MAX := 1.05
const ARM_TRAIL := 0.5
const ARM_MAX := 0.7
const BLADE_DROP := -0.85                ## a blade in the hanging hand: the wrist lets its point drop this far (radians)
const DRAG := 0.013                   ## the legs and the gun arm also trail behind your speed: this much a metre per second
## The springs: how fast each part follows (radians a second) and how soon it stops
## swinging (1 = no overshoot at all). The legs settle in about 0.3 s.
const BODY_PACE := 19.0
const BODY_DAMP := 0.62
const LEGS_PACE := 14.5
const LEGS_DAMP := 0.5
const SHIN_PACE := 13.0
const SHIN_DAMP := 0.45
const ARM_PACE := 15.0
const ARM_DAMP := 0.45
## The jolt as the rope pulls tight. A rope with SLACK_SMALL metres of slack or less
## gives JOLT_SMALL of it, one with SLACK_BIG or more all of it.
const SLACK_SMALL := 1.0
const SLACK_BIG := 3.6
const JOLT_SMALL := 0.4
const JOLT_BODY := 7.0                ## the hips are thrown toward the rope's line this fast
const JOLT_LEGS := 13.0               ## the legs back, away from the hook
const JOLT_ARM := 9.0                 ## the gun arm with them
const JOLT_WHIP := 1.5                ## ...and while it is, the legs are left this much further behind (the chest jerked all the way: 1 is 45 degrees)
const JOLT_LUNGE := 3.4               ## the chest toward the hook, metres a second...
const LUNGE_PACE := 24.0              ## ...on a spring that brings it back
const LUNGE_DAMP := 0.42
const LUNGE_MAX := 0.16               ## metres
## Facing: the hips turn to face along the swing this fast, and the waist lets the
## chest aim up to TWIST_MAX away from them.
const FACE_PACE := 5.0
const TWIST_MAX := 1.75
const TURN_ROUND := 2.2               ## aim further than this from the way the hips face, and they come round
## The legs working the swing.
const PUMP_SPEED := 5.0               ## metres per second along the swing for the whole kick
const PUMP_IDLE := 0.3                ## how much of it shows when you are not steering
## Letting go on the way up: rising at least FLIP_RISE and going at least FLIP_SPEED
## (metres per second) rolls the body forward once, in FLIP_TIME seconds.
const FLIP_RISE := 7.5
const FLIP_SPEED := 12.0
const FLIP_TIME := 0.5
const FLIP_HURRY := 3.5               ## cut short (a shot, a swing), the roll finishes this many times faster
const FLIP_WAIT := 0.25               ## seconds after the body last hung that letting go still counts

var w := 0.0                 ## how much the body hangs on the rope, 0..1
var jolted := 0.0            ## the last jolt's strength, 0..1 (tests)

var _up := Vector3.UP        # the hips' own "up", in the world
var _up_v := Vector3.ZERO
var _legs := Vector3.DOWN    # the way the thighs hang
var _legs_v := Vector3.ZERO
var _shin := Vector3.DOWN    # ...and the shins, a beat behind them
var _shin_v := Vector3.ZERO
var _arm := Vector3.DOWN     # the gun arm
var _arm_v := Vector3.ZERO
var _lunge := 0.0            # the chest jerked toward the hook, metres
var _lunge_v := 0.0
var _rope := Vector3.UP      # toward the hook, from where the rope meets the body
var _face := 0.0             # the way the hips face (a yaw, in the world)
var _pump := 0.0             # the legs' kick: +1 out in front, -1 tucked under
var _slack := 0.0            # the most slack this shot's rope has had
var _was_taut := false
var _let_go := -1.0          # seconds since the body last hung on the rope (-1: long ago, or dealt with)
var _flip := -1.0            # how far through the roll, 0..1 (-1: none)
var _flip_hurry := false


## Every frame. feet: where the body stands, in the world.
func update(delta: float, inp: RobotAnimInput, feet: Vector3) -> void:
	var taut := inp.hook_taut >= 0.0 and inp.alive
	var hanging := taut and inp.state == S.GRAPPLE
	if not inp.grapple_on:
		_slack = 0.0
	elif not taut:
		_slack = maxf(_slack, inp.hook_slack)
	var chest := feet + Vector3(0.0, ATTACH, 0.0)
	if taut and inp.grapple_anchor.distance_squared_to(chest) > 0.01:
		_rope = (inp.grapple_anchor - chest).normalized()
	var flat := Vector3(_rope.x, 0.0, _rope.z)
	var side := clampf(flat.length() / 0.25, 0.0, 1.0)   # (a rope straight up or down has no side to lean to)
	var toward := flat.normalized() if flat.length_squared() > 1e-6 else Vector3.ZERO
	var angle := acos(clampf(_rope.y, -1.0, 1.0))

	if taut and not _was_taut:
		if w <= 0.0:
			# From whatever it was doing: standing in the air, everything hanging straight.
			_up = Vector3.UP
			_legs = Vector3.DOWN
			_shin = Vector3.DOWN
			_arm = Vector3.DOWN
			_up_v = Vector3.ZERO
			_legs_v = Vector3.ZERO
			_shin_v = Vector3.ZERO
			_arm_v = Vector3.ZERO
			_face = _yaw_of(toward) if side >= 1.0 else inp.yaw
			if absf(wrapf(_face - inp.yaw, -PI, PI)) > TURN_ROUND:
				_face = wrapf(_face + PI, -PI, PI)
		_jolt(clampf(inverse_lerp(SLACK_SMALL, SLACK_BIG, _slack), 0.0, 1.0) * (1.0 - JOLT_SMALL) + JOLT_SMALL)
		_slack = 0.0
	_was_taut = taut

	# Let go on the way up: the roll. (The news that the rope was let go and the news
	# that the body is falling free can reach another copy of the game a frame or two
	# apart, either first: so it is looked for a moment after the body last hung.)
	if hanging:
		_let_go = 0.0
	elif _let_go >= 0.0:
		_let_go += delta
		if _let_go > FLIP_WAIT or not inp.alive:
			_let_go = -1.0
		elif not taut and inp.state == S.AIR:
			if inp.velocity.y >= FLIP_RISE and inp.velocity.length() >= FLIP_SPEED:
				_flip = 0.0
				_flip_hurry = false
			_let_go = -1.0
	if _flip >= 0.0:
		if not inp.alive or inp.state != S.AIR or inp.crouched:
			_flip = -1.0   # (landed, or into a move with a body of its own)
		else:
			_flip += delta / FLIP_TIME * (FLIP_HURRY if _flip_hurry else 1.0)
			if _flip >= 1.0:
				_flip = -1.0

	w = move_toward(w, 1.0 if hanging else 0.0, delta * (11.0 if hanging else 6.0))
	if w <= 0.0 and not hanging:
		return

	# Where each part should hang.
	var lean := minf(angle * LEAN, LEAN_MAX) * side
	var up_to := Vector3.UP * cos(lean) + toward * sin(lean)
	var trail := minf(angle * TRAIL, TRAIL_MAX) * side
	var legs_to := Vector3.DOWN * cos(trail) - toward * sin(trail) - inp.velocity * DRAG
	var hang := minf(angle * ARM_TRAIL, ARM_MAX) * side
	var arm_to := Vector3.DOWN * cos(hang) - toward * sin(hang) - inp.velocity * DRAG
	# While the jolt has the chest jerked toward the hook, what hangs from it is left
	# behind, then swings through as the chest comes back: the whip.
	var whip := (_rope - Vector3.DOWN * _rope.dot(Vector3.DOWN)) * lunged() * JOLT_WHIP
	legs_to = (legs_to - whip).normalized()
	arm_to = (arm_to - whip * 0.7).normalized()

	# The way the swing goes, for the hips to face: along the rope's own heading and
	# your speed's, each taken the way round that is nearer to how the hips face now
	# (so they do not turn about each time you pass under the hook, or at the top of a
	# swing). Aim right round behind them and they come round to you.
	var ahead := _dir_of(_face)
	if absf(wrapf(_face - inp.yaw, -PI, PI)) > TURN_ROUND:
		ahead = -ahead
	var along := Vector3.ZERO
	if side > 0.0:
		along += toward * side * (1.0 if toward.dot(ahead) >= 0.0 else -1.0)
	var run := Vector3(inp.velocity.x, 0.0, inp.velocity.z)
	if run.length() > 1.5:
		along += run.normalized() * minf(run.length() / 12.0, 1.0) * 0.8 * (1.0 if run.dot(ahead) >= 0.0 else -1.0)
	var face_to := _yaw_of(along) if along.length() > 0.2 else _yaw_of(ahead)
	var kick_to := clampf(run.dot(_dir_of(_face)) / PUMP_SPEED, -1.0, 1.0) * (1.0 if inp.pumping() else PUMP_IDLE)

	var left := delta
	while left > 0.0:
		var dt := minf(left, 1.0 / 120.0)
		left -= dt
		_up_v += ((up_to - _up) * BODY_PACE * BODY_PACE - _up_v * 2.0 * BODY_DAMP * BODY_PACE) * dt
		_up += _up_v * dt
		_legs_v += ((legs_to - _legs) * LEGS_PACE * LEGS_PACE - _legs_v * 2.0 * LEGS_DAMP * LEGS_PACE) * dt
		_legs += _legs_v * dt
		_shin_v += ((_legs - _shin) * SHIN_PACE * SHIN_PACE - _shin_v * 2.0 * SHIN_DAMP * SHIN_PACE) * dt
		_shin += _shin_v * dt
		_arm_v += ((arm_to - _arm) * ARM_PACE * ARM_PACE - _arm_v * 2.0 * ARM_DAMP * ARM_PACE) * dt
		_arm += _arm_v * dt
		_lunge_v += (-_lunge * LUNGE_PACE * LUNGE_PACE - _lunge_v * 2.0 * LUNGE_DAMP * LUNGE_PACE) * dt
		_lunge = clampf(_lunge + _lunge_v * dt, -LUNGE_MAX, LUNGE_MAX)
	_face = lerp_angle(_face, face_to, 1.0 - exp(-delta * FACE_PACE))
	_pump = lerpf(_pump, kick_to, 1.0 - exp(-delta * 7.0))


## The rope has pulled tight, `strength` 0..1 hard.
func _jolt(strength: float) -> void:
	jolted = strength
	var across := func(v: Vector3, from: Vector3) -> Vector3:   # (the part of v that turns `from`)
		return v - from * v.dot(from)
	_up_v += across.call(_rope, _up.normalized()) * JOLT_BODY * strength
	_legs_v -= across.call(_rope, _legs.normalized()) * JOLT_LEGS * strength
	_shin_v -= across.call(_rope, _shin.normalized()) * JOLT_LEGS * 0.6 * strength
	_arm_v -= across.call(_rope, _arm.normalized()) * JOLT_ARM * strength
	_lunge_v += JOLT_LUNGE * strength


## The roll after letting go: how far through it, 0..1 (-1: not rolling).
func flip() -> float:
	return _flip


## A shot or a swing cuts the roll short: it finishes at once (FLIP_HURRY).
func hurry_flip() -> void:
	if _flip >= 0.0:
		_flip_hurry = true


## The roll was cut short: the arms are free again already.
func flip_hurried() -> bool:
	return _flip >= 0.0 and _flip_hurry


func stop() -> void:
	w = 0.0
	_flip = -1.0
	_was_taut = false
	_let_go = -1.0
	_slack = 0.0
	_lunge = 0.0
	_lunge_v = 0.0


# ---------------------------------------------------------------------------
# Reading it, in the body's own space (x right, y up, -z the way it faces: `yaw`)

## The turn that tips the hips over to hang on the rope.
func tilt(yaw: float) -> Quaternion:
	var up := _local(_up, yaw)
	if up.dot(Vector3.UP) > 0.99999:
		return Quaternion.IDENTITY
	return Quaternion(Vector3.UP, up) if up.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)


## The way the thighs hang, the shins, and the gun arm.
func legs(yaw: float) -> Vector3:
	return _local(_legs, yaw)


func shins(yaw: float) -> Vector3:
	return _local(_shin, yaw)


func arm(yaw: float) -> Vector3:
	return _local(_arm, yaw)


## Toward the hook.
func rope(yaw: float) -> Vector3:
	return _rope.rotated(Vector3.UP, -yaw)


## The chest jerked toward the hook by the jolt (metres), and that as a share of the most it goes.
func lunge(yaw: float) -> Vector3:
	return rope(yaw) * _lunge


func lunged() -> float:
	return _lunge / LUNGE_MAX


## How far the hips are turned from the way the body faces, to face along the swing.
func twist(yaw: float) -> float:
	return clampf(wrapf(_face - yaw, -PI, PI), -TWIST_MAX, TWIST_MAX)


## The legs' kick: +1 out in front, -1 tucked under.
func pump() -> float:
	return _pump


## The way everything loose streams: behind the legs and behind your speed (a cape, a tail).
func stream(yaw: float, velocity: Vector3) -> Vector3:
	var back := _legs.normalized() * 0.6 - velocity * 0.05
	return back.rotated(Vector3.UP, -yaw).limit_length(1.0)


static func _local(v: Vector3, yaw: float) -> Vector3:
	return v.rotated(Vector3.UP, -yaw).normalized() if v.length_squared() > 1e-6 else Vector3.DOWN


static func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func _dir_of(yaw: float) -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, yaw)


# ---------------------------------------------------------------------------
# Laying it over a pose (RobotAnimator calls these, in this order, among its own steps)

## 1. The body: tipped over about the shoulders, the chest brought `upright` of the
## way back (1: bolt upright, for a gun to be aimed from; less: it hangs with the hips).
## scale: how much of the lean to show (your own body in first person shows less).
func lay_body(pose: RobotPose, b: Dictionary, yaw: float, upright: float, scale: float = 1.0) -> void:
	if w <= 0.0:
		return
	var root: int = b["root"]
	var q := Quaternion.IDENTITY.slerp(tilt(yaw), w * scale)
	pose.rot[root] = q * pose.rot[root]
	pose.pos[root] = PIVOT + q * (pose.pos[root] - PIVOT) + lunge(yaw) * w * scale
	var lower: Quaternion = pose.rot[root] * pose.rot[b["hips"]]
	var back := Quaternion.IDENTITY.slerp(q, upright).inverse()
	pose.rot[b["spine"]] = lower.inverse() * back * lower * pose.rot[b["spine"]]
	# The head makes up most of what the chest still leans.
	var rest := Quaternion.IDENTITY.slerp(q, (1.0 - upright) * 0.7).inverse()
	var chest: Quaternion = lower * pose.rot[b["spine"]] * pose.rot[b["chest"]]
	pose.rot[b["head"]] = chest.inverse() * rest * chest * pose.rot[b["head"]]


## 2. The gun arm, hanging loose at the side (before the animator lifts it to aim).
## blade: it holds a melee weapon, which is let down to trail, point low (`rig`: for its grip).
func lay_arm(pose: RobotPose, b: Dictionary, yaw: float, weight: float = 1.0, rig: RobotRig = null, blade: bool = false) -> void:
	var amount := w * weight
	if amount <= 0.0:
		return
	var chest: Quaternion = pose.rot[b["root"]] * pose.rot[b["hips"]] * pose.rot[b["spine"]] * pose.rot[b["chest"]]
	var dir := chest.inverse() * arm(yaw)
	var hung := Quaternion(Vector3.DOWN, dir) if dir.dot(Vector3.DOWN) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	# A little out from the body, the elbow easy, the wrist rolled in (a blade's point dropped).
	pose.rot[b["upper_arm_r"]] = pose.rot[b["upper_arm_r"]].slerp(hung * Quaternion(Vector3.BACK, 0.2) * Quaternion(Vector3.RIGHT, -0.12), amount)
	pose.rot[b["forearm_r"]] = pose.rot[b["forearm_r"]].slerp(Quaternion(Vector3.RIGHT, 0.3 if blade else 0.5), amount)
	var wrist := Quaternion(Vector3.RIGHT, BLADE_DROP) * Quaternion(Vector3.UP, 0.2) if blade else Quaternion(Vector3.RIGHT, 0.25) * Quaternion(Vector3.UP, 0.35)
	pose.rot[b["hand_r"]] = pose.rot[b["hand_r"]].slerp(wrist, amount)
	if blade and rig != null:
		if b.has("pistol"):
			pose.rot[b["pistol"]] = pose.rot[b["pistol"]].slerp(Quaternion.IDENTITY, amount)
		Hands.set_hand(pose, rig, "handle", amount, false)


## 3. The legs, trailing (after the animator has turned the hips to face the swing).
func lay_legs(pose: RobotPose, b: Dictionary, yaw: float) -> void:
	if w <= 0.0:
		return
	var hips: Quaternion = pose.rot[b["root"]] * pose.rot[b["hips"]]
	var thigh := hips.inverse() * legs(yaw)
	var shin := hips.inverse() * shins(yaw)
	var hung := Quaternion(Vector3.DOWN, thigh) if thigh.dot(Vector3.DOWN) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	# The shins trail behind the thighs: that bends the knees (which only bend one way).
	var flat_t := Vector2(-thigh.z, -thigh.y)   # (forward, down)
	var flat_s := Vector2(-shin.z, -shin.y)
	var behind := clampf(flat_t.angle_to(flat_s), -0.3, 1.1) if flat_t.length() > 0.01 and flat_s.length() > 0.01 else 0.0
	# Working the swing: out in front (knees straighter), or tucked under.
	var out := maxf(_pump, 0.0)
	var under := maxf(-_pump, 0.0)
	var lift := 0.62 * out - 0.16 * under
	var knees := 1.0 - 0.75 * out
	var tuck := 1.15 * under
	# One knee up a little, the other leg long: hanging, not standing.
	_leg(pose, b, "r", hung * Quaternion(Vector3.RIGHT, 0.34 + lift) * Quaternion(Vector3.BACK, 0.05), (0.85 + behind) * knees + tuck, 0.55)
	_leg(pose, b, "l", hung * Quaternion(Vector3.RIGHT, -0.06 + lift * 0.85) * Quaternion(Vector3.BACK, -0.05), (0.3 + behind) * knees + tuck * 0.9, 0.62)


func _leg(pose: RobotPose, b: Dictionary, side: String, thigh: Quaternion, bend: float, toes: float) -> void:
	var t: int = b["thigh_" + side]
	var s: int = b["shin_" + side]
	var f: int = b["foot_" + side]
	pose.rot[t] = pose.rot[t].slerp(thigh, w)
	pose.rot[s] = pose.rot[s].slerp(Quaternion(Vector3.RIGHT, -maxf(bend, 0.0)), w)
	pose.rot[f] = pose.rot[f].slerp(Quaternion(Vector3.RIGHT, -toes), w)
