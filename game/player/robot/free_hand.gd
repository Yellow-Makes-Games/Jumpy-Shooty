class_name FreeHand
extends RefCounted
## What the hand without the gun does with the things a player picks up and works: it
## reaches for a weapon or a power-up as the body comes up to it and snatches it out of
## the air, presses a terminal, rides a lever over as it is thrown, and works at a bomb
## being planted or defused. Looks only: what is picked up, pressed or planted, and when,
## is decided as it always was (Match, Teams, MapTerminal); this is told about it.
##
## A Player keeps one (Player.hand: it outlives the body's animator, which is made anew
## with every change of weapon), tells it what is going on (reach, grab, touch, hold),
## steps it every frame (update), and hands it to RobotAnimator, which puts the left arm
## where it says (and bends the body at the waist toward something low), and to ViewModel,
## which brings your own left hand into view. A shot, a reload or a swing cuts it short
## (cut), and it is not shown at all while that hand is up the grappling hook's rope.
##
##   reach(at)          every frame a pickup is close ahead: the open hand goes out to it
##   grab(at, color)    it has been taken: the fist shuts on it and pulls it in to the
##                      chest; `color` flashes through the body's lights (pulse)
##   touch(at, s, f)    a press: the hand goes to `at` and is on it for `s` seconds (`f`:
##                      where it has got to, for a thing that moves: a lever's knob)
##   hold(at, ...)      every frame something is being worked at `at`: the hand stays on
##                      it, bent down to it if it is low, moving about as it works

const AHEAD := 2.3            ## a pickup within this of the body's middle (metres): the hand goes out to it...
const LEAD := 0.25            ## ...and this many seconds of the body's speed further (at a run it is on you in no time)
const GRAB_TIME := 0.34       ## a snatch: the fist shuts in GRAB_SHUT, and the rest is the pull in
const GRAB_SHUT := 0.08
const PULL_TO := Vector3(-0.1, 1.12, -0.22)   ## where it is pulled in to, in the body's space (by the chest)
const PACE_IN := 10.0         ## how fast the arm comes off what it was doing (a second), and goes back
const PACE_OUT := 7.0
const FOLLOW := 20.0          ## how closely the hand follows what it is after
const KEEP := 0.14            ## seconds a reach or a hold goes on after it was last asked for
const BLOCK := 0.35           ## seconds after a shot, a reload or a swing that it will not start
const WORK := 0.03            ## metres the hand moves about as it works at something...
const WORK_RATE := 11.0       ## ...this fast (radians a second)
const SPARK_EVERY := 1.0      ## seconds between sparks at a hand that strikes them (defusing)
const PULSE_TIME := 0.5       ## seconds the flash of a pickup's colour lasts
const ARM := Vector3(-0.5, -1.0, 0.3)   ## the way the elbow goes (the body's space): down, out and a little back

var w := 0.0                  ## how much the arm is the hand's (0: doing whatever it was)
var fist := 0.0               ## 0: open, 1: shut
var bow := 0.0                ## bent at the waist toward something low, 0..1
var pulse := 0.0              ## the flash of colour, 1..0
var pulse_color := Color.WHITE
var spark := false            ## the hand has just struck a spark (see take_spark)

var _at := Vector3.ZERO       # where the hand is after now, in the world
var _reach := 0.0             # seconds a reach has left
var _reach_at := Vector3.ZERO
var _hold := 0.0              # ...and a hold
var _hold_at := Vector3.ZERO
var _low := false
var _work := false
var _sparks := false
var _grab := -1.0             # seconds into a snatch (-1: none)
var _grab_at := Vector3.ZERO
var _touch := -1.0            # ...and a press
var _touch_len := 0.0
var _touch_at := Vector3.ZERO
var _touch_to := Callable()
var _blocked := 0.0
var _t := 0.0
var _spark_in := 0.0


## Something to pick up is close ahead, at `at` (the world): call it every frame it is.
func reach(at: Vector3) -> void:
	if _blocked > 0.0:
		return
	_reach_at = at
	_reach = KEEP


## It has been taken (from `at`): the snatch. `color` (alpha above 0): what it was, to
## flash through the body's lights.
func grab(at: Vector3, color: Color = Color(0, 0, 0, 0)) -> void:
	if color.a > 0.0:
		pulse_color = Color(color.r, color.g, color.b)
		pulse = 1.0
	if _blocked > 0.0:
		return
	_grab = 0.0
	_grab_at = at


## A press: the hand goes to `at` and is on it for `seconds`. `follow`: a Callable giving
## where it has got to, for a thing that moves under the hand (a lever).
func touch(at: Vector3, seconds: float, follow: Callable = Callable()) -> void:
	if _blocked > 0.0:
		return
	_touch = 0.0
	_touch_len = seconds
	_touch_at = at
	_touch_to = follow


## Something is being worked at, at `at`: call it every frame it is. low: it is down by
## the feet (the body bends to it); work: the hand moves about on it; sparks: and strikes
## one every SPARK_EVERY.
func hold(at: Vector3, low: bool = false, work: bool = false, sparks: bool = false) -> void:
	if _blocked > 0.0:
		return
	if _hold <= 0.0:
		_spark_in = SPARK_EVERY * 0.5
	_hold_at = at
	_hold = KEEP
	_low = low
	_work = work
	_sparks = sparks


## A shot, a reload, a swing: the hand is wanted. Whatever it was at is dropped at once.
func cut() -> void:
	_reach = 0.0
	_hold = 0.0
	_grab = -1.0
	_touch = -1.0
	_blocked = BLOCK


## Nothing left of any of it (a respawn, a death).
func stop() -> void:
	cut()
	_blocked = 0.0
	w = 0.0
	fist = 0.0
	bow = 0.0
	pulse = 0.0
	spark = false


## Every frame. body: where the body is drawn, in the world.
func update(delta: float, body: Transform3D) -> void:
	_t += delta
	_blocked = maxf(_blocked - delta, 0.0)
	pulse = move_toward(pulse, 0.0, delta / PULSE_TIME)
	var want := false
	var shut := 0.0
	var low := 0.0
	var to := _at
	if _grab >= 0.0:
		_grab += delta
		if _grab >= GRAB_TIME:
			_grab = -1.0
		else:
			want = true
			shut = clampf(_grab / GRAB_SHUT, 0.0, 1.0)
			to = _grab_at.lerp(body * PULL_TO, smoothstep(GRAB_SHUT, GRAB_TIME, _grab))
	elif _touch >= 0.0:
		_touch += delta
		if _touch >= _touch_len:
			_touch = -1.0
		else:
			want = true
			to = _touch_to.call() if _touch_to.is_valid() else _touch_at
	elif _hold > 0.0:
		want = true
		to = _hold_at
		low = 1.0 if _low else 0.0
		if _work:
			to += body.basis * Vector3(cos(_t * WORK_RATE), 0.6 * sin(_t * WORK_RATE * 1.7), sin(_t * WORK_RATE)) * WORK
		if _sparks:
			_spark_in -= delta
			if _spark_in <= 0.0:
				_spark_in = SPARK_EVERY
				spark = true
	elif _reach > 0.0:
		want = true
		to = _reach_at
	_hold = maxf(_hold - delta, 0.0)
	_reach = maxf(_reach - delta, 0.0)
	_at = to if w <= 0.0 else _at.lerp(to, 1.0 - exp(-delta * FOLLOW))
	w = move_toward(w, 1.0 if want else 0.0, delta * (PACE_IN if want else (PACE_OUT if _blocked <= 0.0 else PACE_OUT * 3.0)))
	fist = move_toward(fist, shut, delta * 14.0)
	bow = move_toward(bow, low, delta * 5.0)


## Where the hand is after, in the world.
func target() -> Vector3:
	return _at


func active() -> bool:
	return w > 0.0


## The hand has struck a spark since this was last asked.
func take_spark() -> bool:
	var did := spark
	spark = false
	return did


## The left arm of `pose`, onto the hand's target: `amount` of the way (the animator's
## say: 0 while that arm is up the rope), bent at the elbow to reach it, or straight out
## at it if it is further than the arm is long. `model`: where the body is drawn.
func lay(pose: RobotPose, b: Dictionary, model: Transform3D, amount: float = 1.0) -> void:
	var k := smoothstep(0.0, 1.0, w) * amount
	if k <= 0.0:
		return
	var up: int = b["upper_arm_l"]
	var fore: int = b["forearm_l"]
	var hand: int = b["hand_l"]
	var chest_at := Transform3D(Basis(pose.rot[b["root"]]), pose.pos[b["root"]])
	for bone in ["hips", "spine", "chest"]:
		chest_at = chest_at * Transform3D(Basis(pose.rot[b[bone]]), pose.pos[b[bone]])
	var shoulder := chest_at * pose.pos[up]
	var to := model.affine_inverse() * _at - shoulder
	if to.length_squared() < 0.0001:
		return
	var upper := pose.pos[fore].length()
	var lower := pose.pos[hand].length()
	var dist := clampf(to.length(), absf(upper - lower) + 0.01, (upper + lower) * 0.999)
	var dir := to.normalized()
	var along := (upper * upper - lower * lower + dist * dist) / (2.0 * dist)
	var bent := sqrt(maxf(upper * upper - along * along, 0.0))
	var side := ARM - dir * ARM.dot(dir)
	if side.length_squared() < 0.0001:
		side = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	side = side.normalized()
	var elbow := shoulder + dir * along + side * bent
	var wrist := shoulder + dir * dist
	var hinge := side.cross(dir).normalized()   # the elbow's axis: both bones' own +X (it bends the other way from a knee)
	var upper_y := (shoulder - elbow).normalized()
	var lower_y := (elbow - wrist).normalized()
	var upper_rot := Basis(hinge, upper_y, hinge.cross(upper_y)).get_rotation_quaternion()
	var lower_rot := Basis(hinge, lower_y, hinge.cross(lower_y)).get_rotation_quaternion()
	pose.rot[up] = pose.rot[up].slerp(chest_at.basis.get_rotation_quaternion().inverse() * upper_rot, k)
	pose.rot[fore] = pose.rot[fore].slerp(upper_rot.inverse() * lower_rot, k)
	pose.rot[hand] = pose.rot[hand].slerp(Quaternion.IDENTITY, k)
