class_name MeleeSwing
extends RefCounted
## The swing of a melee weapon, laid over the arms' pose. Shared by the body
## everyone sees (RobotAnimator) and your own first-person arms (ViewModel).
##
## A swing has three parts: the wind-up (the weapon's `windup` seconds), the blow
## (STRIKE seconds: the blade sweeps across, or the hammer comes down) and the
## recovery back to the ready stance. Swings alternate: a forehand slash, then a
## backhand. The hammer always comes down overhead; the dagger jabs.

const STRIKE := 0.14
const RECOVER := 0.22

## [arm turn (radians, + = toward the left), arm lift (+ = up), wrist tilt (- = point forward)]
## at the start of the swing, end of the wind-up, end of the blow.
const KEYS := {
	"sword": [[0.0, 0.0, 0.0], [-1.0, 0.35, -0.3], [0.9, -0.25, -1.25]],
	"sword_back": [[0.0, 0.0, 0.0], [0.75, 0.3, -0.3], [-1.0, -0.15, -1.25]],
	"hammer": [[0.0, 0.0, 0.0], [-0.15, 1.25, 0.9], [0.05, -0.55, -1.35]],
	"dagger": [[0.0, 0.0, 0.0], [-0.25, 0.05, -0.9], [0.1, -0.05, -1.55]],
	"dagger_back": [[0.0, 0.0, 0.0], [0.2, 0.15, -0.9], [-0.1, -0.1, -1.55]],
}

var t := -1.0         ## seconds into the swing, or -1 between swings
var keys: Array = []
var windup := 0.1


func start(weapon_id: String, count: int) -> void:
	var name := weapon_id
	if count % 2 == 0 and KEYS.has(weapon_id + "_back"):   # the first swing is a forehand
		name += "_back"
	keys = KEYS.get(name, KEYS.sword)
	windup = maxf(WeaponData.by_id(weapon_id).windup, 0.05)
	t = 0.0


func active() -> bool:
	return t >= 0.0


func stop() -> void:
	t = -1.0


## [turn, lift, tilt, chest turn] right now; advances the clock by delta.
func sample(delta: float) -> Array:
	if t < 0.0:
		return [0.0, 0.0, 0.0, 0.0]
	var a: Array
	var b: Array
	var u: float
	if t < windup:
		a = keys[0]
		b = keys[1]
		u = _ease_out(t / windup)
	elif t < windup + STRIKE:
		a = keys[1]
		b = keys[2]
		u = _ease_in_out((t - windup) / STRIKE)
	else:
		a = keys[2]
		b = keys[0]
		u = smoothstep(0.0, 1.0, (t - windup - STRIKE) / RECOVER)
	var out := []
	for i in 3:
		out.append(lerpf(a[i], b[i], u))
	out.append(out[0] * 0.35)
	t += delta
	if t >= windup + STRIKE + RECOVER:
		t = -1.0
	return out


## Lays the swing over a pose: turns and lifts the right arm at the shoulder, tilts
## the weapon in the fist, and turns the chest a little with the blow.
static func apply(pose: RobotPose, bones: Dictionary, s: Array, weight: float = 1.0) -> void:
	if weight <= 0.0 or (s[0] == 0.0 and s[1] == 0.0 and s[2] == 0.0):
		return
	var up_r: int = bones["upper_arm_r"]
	pose.rot[up_r] = Quaternion(Vector3.UP, s[0] * weight) * Quaternion(Vector3.RIGHT, s[1] * weight) * pose.rot[up_r]
	if bones.has("pistol"):
		var g: int = bones["pistol"]
		pose.rot[g] = pose.rot[g] * Quaternion(Vector3.RIGHT, s[2] * weight)
	if bones.has("chest"):
		var c: int = bones["chest"]
		pose.rot[c] = Quaternion(Vector3.UP, s[3] * weight) * pose.rot[c]


static func _ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


static func _ease_in_out(u: float) -> float:
	return smoothstep(0.0, 1.0, clampf(u, 0.0, 1.0))
