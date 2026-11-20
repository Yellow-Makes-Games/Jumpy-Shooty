class_name Emote
extends RefCounted
## An emote: a gesture a player makes standing still, laid over the body's own pose
## (RobotAnimator lays it, after everything else and before a hit's flinch). Looks only:
## there is no lock-in and no protection, and Player cuts it short the moment its body
## moves off, leaves the ground, shoots, swings, reloads, swaps weapons or is hit.
##
## The weapon stays in the right hand, lowered at the side, and the free hand and the
## body do the gesture (the dance uses all of it, weapon and all):
##
##   wave       the free hand up, waving
##   salute     the flat of the hand to the brow, and down
##   thumbs_up  a fist held out, the thumb up
##   point      the arm straight out where the crosshair was (`aim`), and held there
##   shrug      both arms out a little, palm up, the head to one side
##   beckon     the hand out palm up, the fingers curling: come at me
##   laugh      leaning back, shaking, a hand on its middle
##   dance      bouncing on its knees, swaying, the arms pumping in turn; it goes on
##              until something stops it (LOOPS)
##
##   emote.play("wave", aim_dir)   # the world direction it looks, for "point"
##   emote.update(delta)           # every frame
##   emote.lay(pose, rig, model_xform, BodyPose.grip_of(weapon))
##   emote.stop()

const LIST := ["wave", "salute", "thumbs_up", "point", "shrug", "beckon", "laugh", "dance"]
const NAMES := {"wave": "Wave", "salute": "Salute", "thumbs_up": "Thumbs up", "point": "Point", "shrug": "Shrug",
	"beckon": "Come at me", "laugh": "Laugh", "dance": "Dance"}
## Seconds each takes (the dance: one bar of it).
const LENGTH := {"wave": 1.8, "salute": 1.7, "thumbs_up": 1.6, "point": 2.0, "shrug": 1.7, "beckon": 2.0, "laugh": 2.2, "dance": 1.92}
const LOOPS := ["dance"]
const SLOTS := 6             ## the wheel holds this many
const DEFAULT_WHEEL := ["wave", "thumbs_up", "point", "beckon", "laugh", "dance"]
const IN := 0.18             ## seconds to ease into one...
const OUT := 0.24            ## ...and out of it
const STILL := 1.2           ## m/s: moving faster than this over the ground cuts one short (and stops one starting)

## The weapon lowered at the right side: a gun pointing at the floor ahead, a blade
## low and forward, a bare fist (BodyPose's keys).
const GUN_LOW := [Vector3(0.27, -0.50, -0.02), Vector3(0.05, -0.80, -0.60), Vector3(0.0, 0.60, -0.80)]
const BLADE_LOW := [Vector3(0.30, -0.45, -0.06), Vector3(0.22, -0.42, -0.88), Vector3(0.0, -0.88, 0.42)]
const FIST_LOW := [Vector3(0.30, -0.41, -0.07), Vector3(0.1, 0.35, -0.93), Vector3(0.0, -1.0, -0.3)]
const ELBOW_R := Vector3(0.35, -0.5, 0.8)

## The left hand (its wrist), in the chest's frame at shoulder height.
const AT_SIDE := Vector3(-0.29, -0.40, -0.08)
const WAVE := Vector3(-0.36, 0.40, -0.10)
const BROW := Vector3(-0.16, 0.27, -0.17)
const THUMB := Vector3(-0.20, -0.04, -0.40)
const SHRUG := Vector3(-0.44, -0.15, -0.18)
const BECKON := Vector3(-0.22, -0.04, -0.42)
const BELLY := Vector3(-0.07, -0.33, -0.17)
const PUMP_LOW := Vector3(-0.30, -0.02, -0.22)
const PUMP_HIGH := Vector3(-0.32, 0.30, -0.20)
const ELBOW_DOWN := Vector3(-0.5, -0.8, 0.25)
const ELBOW_OUT := Vector3(-1.0, 0.1, 0.15)
const ELBOW_BACK := Vector3(-0.3, 0.0, 1.0)
const POINT_REACH := 0.5     ## metres from the shoulder to the wrist, pointing
const POINT_TURN := 1.9      ## radians either side of straight ahead the arm will point
const BEAT := 0.48           ## the dance: seconds a beat

var id := ""                 ## the one playing, or easing out
var t := 0.0                 ## seconds into it
var w := 0.0                 ## how much of it shows, 0..1
var aim := Vector3.FORWARD   ## "point": where, in the world
var hips := Vector3.ZERO     ## where the hips go with it, in the body's space (the dance's bounce and sway): RobotAnimator keeps the feet where they are
var twist := 0.0             ## ...and how far they turn (radians)

var _on := false


static func valid(emote: String) -> bool:
	return emote in LIST


static func name_of(emote: String) -> String:
	return str(NAMES.get(emote, ""))


## A wheel of SLOTS emotes from what was saved: anything not an emote, or there
## twice, is made up from the defaults and then the rest.
static func wheel(saved: Variant) -> Array:
	var out: Array = []
	if saved is Array:
		for e in saved:
			if out.size() < SLOTS and valid(str(e)) and not str(e) in out:
				out.append(str(e))
	for e in DEFAULT_WHEEL + LIST:
		if out.size() < SLOTS and not e in out:
			out.append(e)
	return out


## Whether a body like this may start one: alive, on its feet on the ground, and still.
static func may_start(alive: bool, grounded: bool, speed: float) -> bool:
	return alive and grounded and speed <= STILL


## Start one (from the top, whatever was playing). aim_dir: where its player looks.
func play(emote: String, aim_dir: Vector3 = Vector3.FORWARD) -> void:
	if not valid(emote):
		return
	id = emote
	t = 0.0
	_on = true
	if aim_dir.length_squared() > 0.0001:
		aim = aim_dir.normalized()


## Over, or cut short: it eases out from wherever it had got to.
func stop() -> void:
	_on = false


## One is playing (not just easing out).
func active() -> bool:
	return _on


func update(delta: float) -> void:
	if _on:
		t += delta
		if not id in LOOPS and t >= float(LENGTH[id]):
			_on = false
	elif w > 0.0:
		t += delta
	w = move_toward(w, 1.0 if _on else 0.0, delta / (IN if _on else OUT))
	if w <= 0.0:
		hips = Vector3.ZERO
		twist = 0.0


## Over `pose` (the body standing as the game has it). model: the body in the world;
## grip: how its weapon is held (BodyPose.grip_of).
func lay(pose: RobotPose, rig: RobotRig, model: Transform3D, grip: Dictionary) -> void:
	hips = Vector3.ZERO
	twist = 0.0
	if w <= 0.0 or id == "":
		return
	var b := rig.bones
	var k := smoothstep(0.0, 1.0, w)
	var length := float(LENGTH[id])
	# (0 at either end of a one-shot and 1 through its middle: the gesture comes and goes inside it.)
	var here := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(length - 0.3, length, t)) if not id in LOOPS else 1.0
	match id:
		"wave":
			BodyPose.body(pose, b, k, 0.03, 0.0, 0.06, 0.12 * here)
			_lower(pose, rig, grip, k)
			BodyPose.left(pose, rig, grip, k, AT_SIDE.lerp(WAVE + Vector3(0.11 * sin(TAU * 2.3 * t), 0.0, 0.0), here), ELBOW_DOWN, "open")
		"salute":
			BodyPose.body(pose, b, k, 0.04, 0.0, 0.06 * here)
			_lower(pose, rig, grip, k)
			BodyPose.left(pose, rig, grip, k, AT_SIDE.lerp(BROW, here), ELBOW_OUT, "flat")
		"thumbs_up":
			var bounce := sin(TAU * 1.6 * t) * sin(TAU * 1.6 * t) * here
			BodyPose.body(pose, b, k, 0.02, 0.0, 0.05)
			_lower(pose, rig, grip, k)
			BodyPose.left(pose, rig, grip, k, AT_SIDE.lerp(THUMB + Vector3(0.0, 0.03 * bounce, -0.05 * bounce), here), ELBOW_DOWN, "fist", 0.35 * here)
			if not grip.akimbo and not grip.fists:
				Hands.set_part(pose, rig, "open", k * here, true, "thumb")
		"point":
			# The arm straight out where it was looking, as far round as an arm goes; the head follows.
			var to: Vector3 = model.basis.orthonormalized().inverse() * aim
			var round := clampf(atan2(-to.x, -to.z), -POINT_TURN, POINT_TURN)
			var flat := Vector2(to.x, to.z).length()
			to = Vector3(-sin(round) * flat, to.y, -cos(round) * flat).normalized()
			var jab := 1.0 + 0.06 * sin(PI * clampf(t / 0.35, 0.0, 1.0))
			BodyPose.body(pose, b, k, 0.0, round * 0.25 * here, 0.0, clampf(round, -0.9, 0.9) * here)
			_lower(pose, rig, grip, k)
			to = (BodyPose.chest(pose, b)[0] as Quaternion).inverse() * to   # (in the chest's frame, as it is turned now)
			BodyPose.left(pose, rig, grip, k, AT_SIDE.lerp(Vector3(pose.pos[b["upper_arm_l"]].x, 0.0, 0.0) + to * POINT_REACH * jab, here), ELBOW_DOWN, "fist")
			if not grip.akimbo and not grip.fists:
				Hands.set_part(pose, rig, "flat", k * here, true, "index")
		"shrug":
			BodyPose.body(pose, b, k, 0.05 * here, 0.0, 0.04 * here, 0.28 * here)
			_lower(pose, rig, grip, k, Vector3(0.12, 0.07, -0.06) * here)
			BodyPose.left(pose, rig, grip, k, AT_SIDE.lerp(SHRUG + Vector3(0.0, 0.05 * sin(PI * clampf(t / 0.5, 0.0, 1.0)), 0.0), here), Vector3(-0.2, -1.0, 0.3), "open", 1.9 * here)
		"beckon":
			var curl := sin(TAU * 1.5 * t) * sin(TAU * 1.5 * t) if t < length - 0.4 else 0.0
			BodyPose.body(pose, b, k, 0.06 * here, 0.0, 0.14 * here)
			_lower(pose, rig, grip, k)
			BodyPose.left(pose, rig, grip, k, AT_SIDE.lerp(BECKON + Vector3(0.0, 0.07 * curl, 0.06 * curl), here), ELBOW_DOWN, "open", 1.9 * here)
			if not grip.akimbo and not grip.fists:
				Hands.set_hand(pose, rig, "fist", k * here * curl * 0.85, true)
		"laugh":
			var shake := sin(TAU * 5.0 * t) * here
			BodyPose.body(pose, b, k, 0.15 * here + 0.035 * shake, 0.0, 0.34 * here + 0.03 * shake)
			_lower(pose, rig, grip, k, Vector3(0.03, 0.025 * shake, 0.0))
			BodyPose.left(pose, rig, grip, k, AT_SIDE.lerp(BELLY, here), Vector3(-1.0, -0.2, 0.3), "open")
			hips = Vector3(0.0, -0.012 * absf(shake) * k, 0.0)
		"dance":
			# A bounce on every beat, a sway and a turn of the hips every two, the arms up in turn.
			var beat := t / BEAT
			var bounce := absf(sin(PI * beat))
			var sway := sin(PI * beat * 0.5 + PI * 0.25)
			var side := sin(PI * beat * 0.5)
			hips = Vector3(0.07 * sway, -0.03 - 0.07 * bounce, 0.0) * k
			twist = 0.3 * sway * k
			BodyPose.body(pose, b, k, 0.03 - 0.05 * bounce, -0.25 * sway, 0.06 * (1.0 - 2.0 * bounce), 0.0)
			pose.rot[b["spine"]] = Quaternion(Vector3.BACK, 0.10 * sway * k) * pose.rot[b["spine"]]
			_lower(pose, rig, grip, k, Vector3(0.04, 0.34 * maxf(-side, 0.0) + 0.05 * bounce, -0.14 * maxf(-side, 0.0)))
			if grip.akimbo:
				BodyPose.left(pose, rig, grip, k, PUMP_LOW.lerp(PUMP_HIGH, maxf(side, 0.0)), ELBOW_DOWN, "fist")
			else:
				BodyPose.left(pose, rig, grip, k, PUMP_LOW.lerp(PUMP_HIGH, maxf(side, 0.0)) + Vector3(0.0, 0.04 * bounce, 0.0), ELBOW_DOWN, "fist")


## The weapon lowered at the right side, moved `shift` from there (in the chest's frame).
func _lower(pose: RobotPose, rig: RobotRig, grip: Dictionary, k: float, shift: Vector3 = Vector3.ZERO) -> void:
	var key: Array = FIST_LOW if grip.fists or grip.empty else (BLADE_LOW if grip.melee else GUN_LOW)
	BodyPose.right(pose, rig, grip, k, (key[0] as Vector3) + shift, key[1], key[2], ELBOW_R)
