class_name SnapshotBuffer
extends RefCounted
## Smooths another player's movement on your screen.
##
## Their game sends us snapshots ~30 times a second. We show them a little in the
## past so there are almost always two snapshots to blend between. How far in the
## past adapts to the connection: steady connections get ~70 ms, jittery ones more,
## and we blend along a curve that uses their velocity, so fast arcs (grapple
## swings, wall-runs) stay round instead of turning into straight-line zigzags.
## If packets are late we briefly extrapolate from the last known velocity.

const MIN_DELAY := 0.07         ## seconds behind the newest data we render, at best
const MAX_DELAY := 0.3          ## ...and at worst (very jittery connection)
const MAX_EXTRAPOLATE := 0.2    ## never guess further ahead than this
const KEEP := 48

class Snap:
	var t: float
	var pos: Vector3
	var vel: Vector3
	var yaw: float
	var pitch: float
	var state: int
	var flags: int

var snaps: Array[Snap] = []
## Estimated (our clock - their clock). Taken from the fastest packets seen, and
## allowed to drift slowly so it follows clock drift and route changes.
var _offset := INF
## How late packets typically arrive compared with the fastest ones (seconds).
var _jitter := 0.0
var _delay := 0.1


func push(remote_time: float, local_time: float, pos: Vector3, vel: Vector3, yaw: float, pitch: float, state: int, flags: int = 0) -> void:
	if not snaps.is_empty() and remote_time <= snaps[-1].t:
		return  # stale or duplicate (unreliable packets can arrive out of order)
	var sample := local_time - remote_time
	if _offset == INF or sample < _offset:
		_offset = sample
	else:
		_offset = lerp(_offset, sample, 0.02)
	# Track lateness with a fast rise and slow fall, so a burst of lag is covered quickly
	# and the extra delay is only given back once the connection has settled.
	var late := sample - _offset
	_jitter = lerp(_jitter, late, 0.25 if late > _jitter else 0.01)
	var s := Snap.new()
	s.t = remote_time
	s.pos = pos
	s.vel = vel
	s.yaw = yaw
	s.pitch = pitch
	s.state = state
	s.flags = flags
	snaps.append(s)
	if snaps.size() > KEEP:
		snaps.pop_front()


## Forget past positions (after a respawn) but keep the clock estimate.
func clear_history() -> void:
	snaps.clear()


func has_data() -> bool:
	return not snaps.is_empty()


## How far behind the newest data we are drawing (seconds), not counting the trip
## the data took to get here.
func delay() -> float:
	return _delay


## How fast they were going in the newest state (m/s).
func speed() -> float:
	return snaps[-1].vel.length() if not snaps.is_empty() else 0.0


## How far their aim swung (degrees, every turn added up) in the last `window`
## seconds of states: a flick, or the aim tracking someone.
func aim_travel(window: float) -> float:
	if snaps.is_empty():
		return 0.0
	var from := snaps[-1].t - window
	var total := 0.0
	var last := Vector3.ZERO
	for s in snaps:
		if s.t < from:
			continue
		var aim := Basis.from_euler(Vector3(s.pitch, s.yaw, 0.0)) * Vector3.FORWARD
		if last != Vector3.ZERO:
			total += last.angle_to(aim)
		last = aim
	return rad_to_deg(total)


## The time, on the sender's clock, that we should be showing right now.
## Call once per frame. The delay eases toward its target so time never jumps.
func render_time(local_time: float, delta: float = 0.016) -> float:
	var target: float = clamp(1.0 / 30.0 * 1.5 + _jitter * 1.6, MIN_DELAY, MAX_DELAY)
	_delay = move_toward(_delay, target, delta * 0.1)  # at most 0.1 s of change per second
	return local_time - _offset - _delay


## Returns [position, velocity, yaw, pitch, state, animation flags] at the given sender-clock time.
func sample(rt: float) -> Array:
	var n := snaps.size()
	if n == 0:
		return [Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 0, 0]
	if rt <= snaps[0].t:
		var f := snaps[0]
		return [f.pos, f.vel, f.yaw, f.pitch, f.state, f.flags]
	var last := snaps[n - 1]
	if rt >= last.t:
		var ahead: float = min(rt - last.t, MAX_EXTRAPOLATE)
		return [last.pos + last.vel * ahead, last.vel, last.yaw, last.pitch, last.state, last.flags]
	var i := n - 2
	while i > 0 and snaps[i].t > rt:
		i -= 1
	var a := snaps[i]
	var b := snaps[i + 1]
	var span: float = max(b.t - a.t, 0.0001)
	var u: float = clamp((rt - a.t) / span, 0.0, 1.0)
	var pos := _hermite(a.pos, a.vel * span, b.pos, b.vel * span, u)
	var vel := a.vel.lerp(b.vel, u)
	var yaw := lerp_angle(a.yaw, b.yaw, u)
	var pitch: float = lerp(a.pitch, b.pitch, u)
	var near := b if u > 0.5 else a
	return [pos, vel, yaw, pitch, near.state, near.flags]


static func _hermite(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, u: float) -> Vector3:
	var u2 := u * u
	var u3 := u2 * u
	return p0 * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * (u3 - 2.0 * u2 + u) + p1 * (-2.0 * u3 + 3.0 * u2) + m1 * (u3 - u2)
