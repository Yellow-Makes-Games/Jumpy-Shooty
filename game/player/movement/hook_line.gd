class_name HookLine
extends RefCounted
## One shot of Grappling Hook 2 (see HookShot), written down as the moments things
## happened: when it was fired, from where and how fast; when the hook stopped and
## whether it caught; when the rope pulled tight; when it was let go.
##
## Everything drawn comes from this record and a time (look): where the hook is, how
## much slack the rope has, how far its ripples have run. Nothing is animated frame
## by frame, so two copies of the game holding the same record draw the same hook
## and rope for the same moment, whatever their frame rates and however late the
## news reached them. That is how the rope lines up for everyone:
##  - the player who fired fills the record in as it happens (HookShot), on the
##    clock their movement runs on;
##  - every snapshot they send while a shot is live carries the whole record, with
##    each moment as "this long ago" (pack). One snapshot is enough to rebuild the
##    shot, so a lost packet costs nothing;
##  - everyone else rebuilds it on that player's clock (absorb) and draws it at the
##    same moment they draw that player's body (Player), so the rope and the body
##    never drift apart;
##  - the killcam records what was drawn (Player.shown_state) and draws it again.

enum { OFF, FLYING, BITING, TAUT, RETRACT }

const SPEED := 85.0            ## metres per second the hook flies
## Rope paid out behind the hook, beyond the straight line to it: this much, plus
## this much for every metre flown. It is the slack the winch takes in once the hook bites.
const SLACK_MIN := 1.0
const SLACK_PER_M := 0.08
## The winch taking the slack in: it starts at REEL metres per second and spins up
## by REEL_ACCEL every second, so a long shot's slack is gone in under 0.2 s.
const REEL := 10.0
const REEL_ACCEL := 160.0
const RETRACT_TIME := 0.2      ## seconds the hook takes to whip back when let go
const LIMP := 0.04             ## let go, the rope goes limp: this much slack per metre of rope
const BLEND := 6.0             ## the hook leaves the wrist and is on the line of aim after this many metres
## Where the hook leaves from, as everyone else sees it: the launcher on the left
## wrist, with the arm thrown out along the aim. From the eyes: the shoulder (metres
## to the right, up and back) and the arm's length along the aim. (Measured on the
## robot. Worked out from the shot, not read off the arm as it is drawn, because the
## arm is still on its way up when the hook leaves and no two copies of the game draw
## it at quite the same point of that: see muzzle.)
const SHOULDER := Vector3(-0.28, -0.19, 0.1)
const ARM := 0.48
const ATTACH_HEIGHT := 1.2     ## where the rope meets the body, above the feet (MovementTuning.grapple_attach_height)
const EYE_ABOVE_CHEST := 0.4   ## the eyes above that (MovementTuning.EYE_HEIGHT - ATTACH_HEIGHT)
const FAR := 200.0             ## no hook flies further than this, whatever the news
const KEEP_SENDING := 0.6      ## seconds after a shot is over that snapshots still carry it
const PACKED := 18             ## floats a shot takes in a snapshot (see pack)

var seq := 0                   ## which shot this is (0: none); goes up with every shot
var t_launch := 0.0
var origin := Vector3.ZERO     ## where it was fired from (the eyes)
var vel := Vector3.ZERO        ## the hook's velocity in flight
var t_stop := INF              ## the flight ended (it caught, ran out of rope or was called back)
var caught := false            ## ...by catching something
var anchor := Vector3.ZERO     ## where it bit (it moves, hooked on a player or something that moves)
var rope := 0.0                ## rope out when it bit: the distance to it plus the flight's slack
var t_taut := INF              ## the slack was gone and the pull began
var t_release := INF           ## let go (or it missed): the hook comes back
var dropped := false           ## gone at once, with no whip back (the player died or was moved)
var target_id := 0             ## the player it is hooked on (0: a surface)
## Someone else's shot only: the flight is held at this many metres until the news of
## where it stopped arrives (see Player._guard_hook), so a late packet never shows the
## hook flying on through a wall.
var hold := INF

var _anchor_t := PackedFloat64Array()   # someone else's shot: where the anchor was, when
var _anchor_p := PackedVector3Array()


## Slack behind a hook that has flown `travel` metres.
static func flight_slack(travel: float) -> float:
	return SLACK_MIN + SLACK_PER_M * travel


## Rope the winch has taken in `seconds` after the hook bit.
static func reeled(seconds: float) -> float:
	var s := maxf(seconds, 0.0)
	return REEL * s + 0.5 * REEL_ACCEL * s * s


# ---------------------------------------------------------------------------
# Filling it in (the player whose hook it is)

func launch(shot: int, t: float, from: Vector3, velocity: Vector3) -> void:
	seq = shot
	t_launch = t
	origin = from
	vel = velocity
	t_stop = INF
	caught = false
	anchor = from
	rope = 0.0
	t_taut = INF
	t_release = INF
	dropped = false
	target_id = 0
	hold = INF
	_anchor_t.clear()
	_anchor_p.clear()


## The hook bit at `at`, with `rope_out` metres of rope behind it.
func bite(t: float, at: Vector3, rope_out: float, on_player: int = 0) -> void:
	t_stop = t
	caught = true
	anchor = at
	rope = rope_out
	target_id = on_player


func pull_taut(t: float) -> void:
	t_taut = t


## Let go, or the flight ended with nothing caught: the hook whips back.
func let_go(t: float) -> void:
	if t_release != INF:
		return
	t_release = t
	t_stop = minf(t_stop, t)


## Gone at once (death, a respawn, a portal).
func drop(t: float) -> void:
	if live(t):
		let_go(t)
		dropped = true


# ---------------------------------------------------------------------------
# Reading it

## Is there anything of this shot to draw (or still to come) at time t?
func live(t: float) -> bool:
	return seq != 0 and (t_release == INF or (not dropped and t < t_release + RETRACT_TIME))


## Which of the shot's moments have happened (as far as this record knows): bit 0
## fired, 1 the flight stopped, 2 pulled tight, 3 let go.
func moments() -> int:
	if seq == 0:
		return 0
	return 1 | (2 if t_stop != INF else 0) | (4 if t_taut != INF else 0) | (8 if t_release != INF else 0)


func stage(t: float) -> int:
	if seq == 0 or t < t_launch:
		return OFF
	if t >= t_release:
		return OFF if dropped or t >= t_release + RETRACT_TIME else RETRACT
	if t < t_stop or not caught:
		return FLYING
	return BITING if t < t_taut else TAUT


## Metres the hook has flown at time t.
func travel(t: float) -> float:
	return minf(vel.length() * maxf(minf(t, t_stop) - t_launch, 0.0), minf(hold, FAR))


## Where the hook is on its line of flight at time t (the line from the eyes; drawn,
## it starts at the wrist: see look).
func flight_pos(t: float) -> Vector3:
	var speed := vel.length()
	return origin + (vel / speed * travel(t) if speed > 0.0 else Vector3.ZERO)


## The wrist the hook leaves from, measured from where it was fired (the eyes): see
## SHOULDER. The same for every copy of the game, because it comes from the shot alone.
func muzzle() -> Vector3:
	var speed := vel.length()
	if speed <= 0.0:
		return Vector3.ZERO
	var aim := vel / speed
	var right := aim.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT   # (straight up or down)
	right = right.normalized()
	var back := right.cross(Vector3.UP)
	return right * SHOULDER.x + Vector3.UP * SHOULDER.y + back * SHOULDER.z + aim * ARM


## What to draw at time t: [stage, where the hook is, metres of slack in the rope,
## seconds since the shot (the rope's ripples run on it), seconds since the rope
## pulled tight (-1 before; it twangs)]. Empty when there is nothing to draw.
## hand: where the rope leaves the wrist. chest: where it meets the body for the
## rope's length (Grapple.rope_origin). anchor_now: where the anchor is drawn, if
## the caller knows better than the record (a hooked player, drawn where this copy
## draws them). own_arm: draw the hook leaving `hand` itself, not the shot's muzzle:
## for your own first-person arm, which only your screen has.
func look(t: float, hand: Vector3, chest: Vector3, anchor_now: Vector3 = Vector3.INF, own_arm: bool = false) -> Array:
	var st := stage(t)
	if st == OFF:
		return []
	var age := t - t_launch
	var at := anchor_now if anchor_now != Vector3.INF else anchor_at(t)
	var wrist := hand - (chest + Vector3(0.0, EYE_ABOVE_CHEST, 0.0)) if own_arm else muzzle()
	match st:
		FLYING:
			return [st, _flying_hook(t, wrist), flight_slack(travel(t)), age, -1.0]
		BITING:
			return [st, at, _slack_in(t, chest, at), age, -1.0]
		TAUT:
			return [st, at, 0.0, age, t - t_taut]
	# Let go: back to the wrist, faster and faster, the rope limp behind it.
	var from := at if caught else _flying_hook(t_stop, wrist)
	var loose := 0.0
	if not caught:
		loose = flight_slack(travel(t_stop))
	elif t_release < t_taut:
		loose = _slack_in(t_release, chest, at)
	var u := clampf((t - t_release) / RETRACT_TIME, 0.0, 1.0)
	return [st, from.lerp(hand, u * u), (loose + LIMP * from.distance_to(hand)) * (1.0 - u), age, -1.0]


## The hook in flight, as drawn: it leaves the wrist (`wrist`: from the eyes) and is
## on the line of aim (which starts at the eyes) BLEND metres out.
func _flying_hook(t: float, wrist: Vector3) -> Vector3:
	return flight_pos(t) + wrist * (1.0 - smoothstep(0.0, BLEND, travel(t)))


## Slack left at time t, between the bite and the rope pulling tight.
func _slack_in(t: float, chest: Vector3, at: Vector3) -> float:
	return maxf(rope - reeled(t - t_stop) - chest.distance_to(at), 0.0)


## Where the anchor was at time t. The record of the player who fired holds only where
## it is now; a copy rebuilt from snapshots keeps the last second of it.
func anchor_at(t: float) -> Vector3:
	var n := _anchor_t.size()
	if n == 0:
		return anchor
	if t <= _anchor_t[0]:
		return _anchor_p[0]
	if t >= _anchor_t[n - 1]:
		return _anchor_p[n - 1]
	var i := n - 2
	while i > 0 and _anchor_t[i] > t:
		i -= 1
	var span := maxf(_anchor_t[i + 1] - _anchor_t[i], 0.0001)
	return _anchor_p[i].lerp(_anchor_p[i + 1], clampf((t - _anchor_t[i]) / span, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Over the network

## Should snapshots carry this shot at time t? While it is live, and a little after,
## so the news that it is over gets through a few lost packets.
func sending(t: float) -> bool:
	return seq != 0 and (t_release == INF or t < t_release + KEEP_SENDING)


## The shot as PACKED floats for a snapshot sent at time t (the sender's clock):
## seq, seconds since the launch, origin (3), velocity (3), seconds from the launch
## to the flight stopping (-1: still flying), flags (1 caught, 2 dropped), anchor (3),
## rope out at the bite, seconds from the launch to the rope pulling tight (-1: not
## yet), seconds from the launch to letting go (-1: not yet), the hooked player's id
## (low 16 bits, then the rest; 0: a surface).
## Only the launch is placed on the sender's clock ("this long ago", which stays exact
## in a 32-bit float). Every later moment travels as how long after the launch it
## came, counted in the sender's movement steps, so the flight another copy draws is
## exactly as long as the flight that happened: its hook stops on the wall, not a
## step short of it or past it, whatever the timing of the packet that brought the news.
func pack(t: float) -> PackedFloat32Array:
	return PackedFloat32Array([float(seq), t - t_launch, origin.x, origin.y, origin.z, vel.x, vel.y, vel.z,
		t_stop - t_launch if t_stop != INF else -1.0, (1.0 if caught else 0.0) + (2.0 if dropped else 0.0),
		anchor.x, anchor.y, anchor.z, rope,
		t_taut - t_launch if t_taut != INF else -1.0, t_release - t_launch if t_release != INF else -1.0,
		float(target_id & 0xFFFF), float((target_id >> 16) & 0xFFFF)])


## The shot number in a packed shot starting at d[o].
static func packed_seq(d: PackedFloat32Array, o: int) -> int:
	return int(d[o])


## Takes in a packed shot from a snapshot stamped `stamp` (the sender's clock). A new
## shot starts the record over; more news of the same shot fills in what has happened
## since. The launch is placed from the first snapshot that tells of the shot and
## kept, so the shot does not wander with every packet's timing.
func absorb(stamp: float, d: PackedFloat32Array, o: int) -> void:
	var shot := int(d[o])
	if shot != seq:
		launch(shot, stamp - d[o + 1], Vector3(d[o + 2], d[o + 3], d[o + 4]), Vector3(d[o + 5], d[o + 6], d[o + 7]))
	var flags := int(d[o + 9])
	caught = flags & 1 != 0
	dropped = flags & 2 != 0
	rope = d[o + 13]
	target_id = int(d[o + 16]) | (int(d[o + 17]) << 16)
	if t_stop == INF and d[o + 8] >= 0.0:
		t_stop = t_launch + d[o + 8]
		hold = INF
	if t_taut == INF and d[o + 14] >= 0.0:
		t_taut = t_launch + d[o + 14]
	if t_release == INF and d[o + 15] >= 0.0:
		t_release = t_launch + d[o + 15]
		t_stop = minf(t_stop, t_release)
		hold = INF
	anchor = Vector3(d[o + 10], d[o + 11], d[o + 12])
	if caught and t_release == INF:
		_anchor_t.append(maxf(stamp, t_stop))
		_anchor_p.append(anchor)
		if _anchor_t.size() == 1 and stamp > t_stop:
			_anchor_t.insert(0, t_stop)   # it has been there since it bit
			_anchor_p.insert(0, anchor)
		while _anchor_t.size() > 2 and _anchor_t[1] < stamp - 1.0:
			_anchor_t.remove_at(0)
			_anchor_p.remove_at(0)
