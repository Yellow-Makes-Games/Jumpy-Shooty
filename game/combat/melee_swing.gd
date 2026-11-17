class_name MeleeSwing
extends RefCounted
## The swing of a melee weapon, laid over the pose. Shared by the body everyone
## sees (RobotAnimator) and your own first-person arms (ViewModel).
##
## Built to read clearly from across the arena, like an arcade sword fight:
##  - a wind-up that coils the whole body (the weapon's `windup` seconds), then a
##    short hold at the top so you can see what is coming;
##  - a fast blow (STRIKE seconds) where the arm sweeps through a wide arc, the
##    chest turns and the robot leans into it;
##  - a follow-through that carries on past the target, then a slower recovery.
## Swings alternate: a forehand slash, then a backhand. The hammer always comes
## down overhead from high above the head; the dagger jabs. A blow that lands
## freezes the swing for a moment (hit_stop) so the hit has weight.

const HOLD := 0.045
const STRIKE := 0.12
const FOLLOW := 0.1
const RECOVER := 0.26

## Each key: [arm turn (+ = toward the left), arm lift (+ = up), wrist tilt
## (- = blade points forward), chest turn (+ = left), lean (+ = forward)].
## Keys: rest, top of the wind-up, end of the blow, end of the follow-through.
const KEYS := {
	"sword": [[0, 0, 0, 0, 0], [-1.25, 0.55, 0.15, -0.55, -0.08], [0.75, -0.2, -1.35, 0.5, 0.22], [1.15, -0.4, -1.1, 0.65, 0.18]],
	"sword_back": [[0, 0, 0, 0, 0], [0.95, 0.5, 0.1, 0.5, -0.08], [-0.9, -0.15, -1.35, -0.5, 0.22], [-1.3, -0.3, -1.1, -0.65, 0.18]],
	"hammer": [[0, 0, 0, 0, 0], [-0.2, 1.7, 1.2, -0.25, -0.22], [0.05, -0.55, -1.45, 0.1, 0.45], [0.1, -0.85, -1.2, 0.15, 0.5]],
	"dagger": [[0, 0, 0, 0, 0], [-0.35, 0.1, -0.7, -0.3, -0.05], [0.12, -0.05, -1.6, 0.25, 0.2], [0.2, -0.1, -1.55, 0.3, 0.15]],
	"dagger_back": [[0, 0, 0, 0, 0], [0.3, 0.2, -0.7, 0.3, -0.05], [-0.15, -0.1, -1.6, -0.25, 0.2], [-0.25, -0.15, -1.55, -0.3, 0.15]],
	# Brass knuckles: a straight jab, then a hook from the outside.
	"brass_knuckles": [[0, 0, 0, 0, 0], [-0.2, -0.15, 0.35, -0.45, -0.1], [0.08, 0.05, -0.15, 0.5, 0.38], [0.12, 0.02, -0.2, 0.55, 0.32]],
	"brass_knuckles_back": [[0, 0, 0, 0, 0], [-0.8, 0.25, 0.2, -0.6, -0.05], [0.55, 0.1, -0.35, 0.45, 0.3], [0.8, 0.0, -0.3, 0.6, 0.25]],
	# The spear thrusts straight out: the point comes down level and drives forward.
	"spear": [[0, 0, 0, 0, 0], [-0.15, 0.15, -0.9, -0.35, -0.18], [0.02, 0.02, -1.6, 0.18, 0.42], [0.04, 0.0, -1.62, 0.2, 0.46]],
	# The axe chops down across the body from up over the right shoulder.
	"axe": [[0, 0, 0, 0, 0], [-0.75, 1.35, 1.0, -0.45, -0.18], [0.45, -0.5, -1.4, 0.4, 0.4], [0.6, -0.8, -1.2, 0.5, 0.45]],
	"axe_back": [[0, 0, 0, 0, 0], [0.7, 1.3, 0.9, 0.4, -0.18], [-0.45, -0.45, -1.4, -0.4, 0.4], [-0.65, -0.75, -1.2, -0.5, 0.45]],
	# The bat: a big flat swing, wound up far behind, finished all the way round.
	"bat": [[0, 0, 0, 0, 0], [-1.55, 0.6, 0.35, -0.75, -0.12], [0.95, -0.1, -1.35, 0.65, 0.2], [1.45, -0.3, -1.0, 0.85, 0.15]],
}
const REST := [0.0, 0.0, 0.0, 0.0, 0.0]
## How long the blow, follow-through and recovery take, against the sword's.
const PACE := {"sword": 1.0, "hammer": 1.3, "dagger": 0.6, "brass_knuckles": 0.55, "spear": 0.85, "axe": 1.2, "bat": 1.15}

var t := -1.0         ## seconds into the swing, or -1 between swings
var keys: Array = []
var windup := 0.1
var _stop := 0.0      # hit-stop left: the swing is frozen
var _pace := 1.0
var _from: Array = REST.duplicate()   # where the wind-up starts (a swing can start before the last one has settled)
var _last: Array = REST.duplicate()


func start(weapon_id: String, count: int) -> void:
	var name := weapon_id
	if count % 2 == 0 and KEYS.has(weapon_id + "_back"):   # the first swing is a forehand
		name += "_back"
	keys = KEYS.get(name, KEYS.sword)
	windup = maxf(WeaponData.by_id(weapon_id).windup, 0.05)
	_pace = PACE.get(weapon_id, 1.0)
	_from = _last.duplicate() if t >= 0.0 else REST.duplicate()
	t = 0.0
	_stop = 0.0


func active() -> bool:
	return t >= 0.0


func stop() -> void:
	t = -1.0
	_last = REST.duplicate()


## Seconds from the click to the middle of the blow: when it should hit.
static func impact_time(weapon_id: String) -> float:
	return maxf(WeaponData.by_id(weapon_id).windup, 0.05) + HOLD + STRIKE * PACE.get(weapon_id, 1.0) * 0.5


## The blow landed: hold the swing still for a moment.
func hit_stop(seconds: float = 0.07) -> void:
	if t >= 0.0:
		_stop = seconds


## In the blow or its follow-through: the blade is cutting (draw its trail).
func cutting() -> bool:
	var s := windup + HOLD
	return t >= s - 0.01 and t < s + (STRIKE + FOLLOW) * _pace


func length() -> float:
	return windup + HOLD + (STRIKE + FOLLOW + RECOVER) * _pace


## [turn, lift, tilt, chest turn, lean] right now; advances the clock by delta.
func sample(delta: float) -> Array:
	if t < 0.0:
		return REST.duplicate()
	var a: Array
	var b: Array
	var u: float
	var strike_at := windup + HOLD
	var strike := STRIKE * _pace
	var follow := FOLLOW * _pace
	if t < windup:
		a = _from
		b = keys[1]
		u = _ease_out(t / windup)
	elif t < strike_at:
		a = keys[1]
		b = keys[1]
		u = 0.0
	elif t < strike_at + strike:
		a = keys[1]
		b = keys[2]
		u = _ease_in((t - strike_at) / strike)
	elif t < strike_at + strike + follow:
		a = keys[2]
		b = keys[3]
		u = _ease_out((t - strike_at - strike) / follow)
	else:
		a = keys[3]
		b = keys[0]
		u = smoothstep(0.0, 1.0, (t - strike_at - strike - follow) / (RECOVER * _pace))
	var out := []
	for i in 5:
		out.append(lerpf(a[i], b[i], u))
	if _stop > 0.0:
		_stop -= delta
	else:
		t += delta
	if t >= length():
		t = -1.0
		out = REST.duplicate()
	_last = out
	return out


## Lays the swing over a pose: turns and lifts the right arm at the shoulder,
## tilts the weapon in the fist, and turns and leans the upper body with the blow.
static func apply(pose: RobotPose, bones: Dictionary, s: Array, weight: float = 1.0, body: float = 1.0) -> void:
	if weight <= 0.0:
		return
	var up_r: int = bones["upper_arm_r"]
	pose.rot[up_r] = Quaternion(Vector3.UP, s[0] * weight) * Quaternion(Vector3.RIGHT, s[1] * weight) * pose.rot[up_r]
	if bones.has("pistol"):
		var g: int = bones["pistol"]
		pose.rot[g] = pose.rot[g] * Quaternion(Vector3.RIGHT, s[2] * weight)
	if body <= 0.0:
		return
	if bones.has("chest"):
		var c: int = bones["chest"]
		pose.rot[c] = Quaternion(Vector3.UP, s[3] * weight * body) * pose.rot[c]
	if bones.has("spine"):
		var sp: int = bones["spine"]
		pose.rot[sp] = Quaternion(Vector3.UP, s[3] * 0.5 * weight * body) * Quaternion(Vector3.RIGHT, -s[4] * weight * body) * pose.rot[sp]
	if bones.has("head"):   # the head keeps looking ahead
		var h: int = bones["head"]
		pose.rot[h] = Quaternion(Vector3.UP, -s[3] * 0.9 * weight * body) * pose.rot[h]


static func _ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


## Slow to start, then fast: a blow that whips through.
static func _ease_in(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (2.0 - u) * 0.5 + u * u * 0.5
