class_name HitReaction
extends RefCounted
## What being hit does to the body that is hit. Looks only: nothing here moves the player,
## the aim or a shot, and the hips and feet stay where they are (a blow that really does
## push you is the match's: Match._host_shove).
##
## RobotAnimator (the body, for every player) and ViewModel (your own arms, and through
## them the camera) each keep one: they are told of every hit (hit), step it every frame
## (update), then read off it where the body has been thrown.
##
## The upper body goes the way the blow was travelling: shot from the front it rocks
## back, from the left it leans and turns to its right, from behind it lurches forward.
## How far is the damage's (strength): a graze twitches a shoulder, a solid hit rocks the
## chest, a big one staggers the whole upper body and buckles the knees of a body that is
## standing still. A headshot snaps the head away on top of that. A blow from a melee
## weapon or a kick folds the body round it instead, and a heavy one throws the arms
## wide. Hits that come fast add up to a shudder, up to a limit (the MOST_ constants).
## It is all on springs: it goes, comes back a little past rest and settles.
##
## The camera (first person only) is knocked a little the way the blow went and springs
## straight back: camera() is added to the view, never to the aim.

## What a hit was (Match.hit_taken says, of every one).
const SHOT := 0              ## a bullet (or anything else not below)
const BLAST := 1             ## an explosion
const MELEE := 2             ## a melee weapon, a kick
const HEAVY := 3             ## a melee weapon wound all the way up, a flying kick
const CRASH := 4             ## thrown into a wall or the floor
const HEAVY_CHARGE := 0.95   ## a melee blow wound up at least this far is a heavy one

const SMALL := 15.0          ## damage under this is a graze: a shoulder twitch
const BIG := 50.0            ## damage of this and over is a big hit: the whole upper body, and the knees
const LEAN := 0.2            ## radians the upper body is thrown by a hit of strength 1...
const MOST_LEAN := 0.36      ## ...and the most it is ever thrown, however fast the hits come
const TWIST := 0.26          ## radians the chest turns (the shoulder that was hit goes back)
const MOST_TWIST := 0.5
const HEAD := 0.5            ## radians a headshot snaps the head (a body hit: WHIP of it)
const WHIP := 0.3
const MOST_HEAD := 0.75
const FOLD := 0.45           ## a blow from a melee weapon or a kick: radians the upper body folds forward over it...
const FOLD_LEAN := 0.4       ## ...and how much of the usual lean it keeps (it doubles up more than it is thrown)
const WIDE := 0.55           ## a heavy blow: radians the arms are thrown out
const BUCKLE := 0.07         ## metres the hips drop as the knees buckle (a big hit, standing still)
const AIR := 1.5             ## off the ground there is nothing to brace on: the body goes this much further...
const AIR_LEGS := 0.9        ## ...and the legs swing the other way under it, this much of the lean
const LEAN_RATE := 15.0      ## the springs: how quickly the body goes and comes back...
const LEAN_DAMP := 0.45      ## ...and how soon it settles (under 1: it goes a little past rest first)
const HEAD_RATE := 20.0      ## (the head is back in about a quarter of a second)
const HEAD_DAMP := 0.5
const SLOW_RATE := 10.0      ## the arms thrown wide, the knees
const SLOW_DAMP := 0.8
const CAM := 0.006           ## the camera's own knock, radians, for a hit of strength 1 (less than a gun's kick)...
const CAM_ROLL := 0.012      ## ...and how far it tips
const CAM_RATE := 30.0
const CAM_DAMP := 0.75
const CAM_MAX := 0.03
const ARMS := 0.05           ## your own arms in first person: metres they jolt for a lean of 1 radian...
const ARMS_TILT := 0.3       ## ...and radians they tip

var lean := Vector2.ZERO     ## the upper body thrown, radians: x to its right, y back
var twist := 0.0             ## the chest turned, radians (+: to its left)
var head := Vector2.ZERO     ## the head snapped, radians: x turned (+: to its left), y tipped back
var fold := 0.0              ## folded forward over a blow, 0..1 or so
var wide := 0.0              ## the arms thrown out, 0..1 or so
var buckle := 0.0            ## the knees buckling, 0..1 or so

var _lean_v := Vector2.ZERO
var _twist_v := 0.0
var _head_v := Vector2.ZERO
var _fold_v := 0.0
var _wide_v := 0.0
var _buckle_v := 0.0
var _cam := Vector3.ZERO     # pitch (up), yaw, roll
var _cam_v := Vector3.ZERO
var _hits := 0


## How hard a hit of this much damage throws the body: 0.3 for a graze, 1 for a big hit
## (BIG), never much more.
static func strength(damage: float) -> float:
	return clampf(pow(maxf(damage, 0.0) / BIG, 0.6), 0.3, 1.3)


## Which of SHOT, BLAST, MELEE, HEAVY, CRASH a hit was, from what the host knows of it:
## its `cause` ("", "kick", "slam") and `blow` ({with, blast, heavy}: see Match._host_damage).
static func kind_of(cause: String, blow: Dictionary) -> int:
	var with := str(blow.get("with", ""))
	if cause == "slam":
		return CRASH
	if bool(blow.get("heavy", false)) or with == "flying_kick":
		return HEAVY
	if cause == "kick" or with == "kick" or WeaponData.melee(with):
		return MELEE
	return BLAST if float(blow.get("blast", 0.0)) > 0.0 else SHOT


## A hit. `way`: which way the blow was travelling, seen from the body (x: to its right,
## y: up, z: to its back; any length, zero for one from no side at all, a fall). `blunt`:
## from a melee weapon or a kick; `heavy`: a full-charged one, or a flying kick.
## `braced`: the body is on its feet and all but still (its knees can buckle).
func hit(way: Vector3, damage: float, headshot: bool = false, blunt: bool = false, heavy: bool = false, braced: bool = false) -> void:
	_hits += 1
	var s := strength(damage) * (1.3 if blunt else 1.0)
	var flat := Vector2(way.x, way.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector2.ZERO
	# A blow is never dead centre: it catches one shoulder or the other, turn about.
	var side := 1.0 if _hits % 2 == 0 else -1.0
	var graze := damage < SMALL and not blunt
	# The lean: little of it for a graze (that is all in the shoulder), all of it otherwise.
	_lean_v += flat * s * LEAN * (0.35 if graze else 1.0) * (FOLD_LEAN if blunt else 1.0) * _kick(LEAN_RATE, LEAN_DAMP)
	# The turn: the blow catches the shoulder on the side it came from (+1: the left one),
	# and drives it back, or forward if it came from behind.
	var shoulder := signf(flat.x) if absf(flat.x) > 0.35 else side
	var driven := flat.y if absf(flat.y) > 0.25 else (0.4 if flat != Vector2.ZERO else 0.0)
	_twist_v += shoulder * driven * s * TWIST * (1.0 if graze else 0.7) * _kick(LEAN_RATE, LEAN_DAMP)
	# The head: whipped a little by any hit, snapped by one to the head.
	var snap := HEAD if headshot else HEAD * WHIP
	_head_v += Vector2(-flat.x + side * 0.4, flat.y) * s * snap * _kick(HEAD_RATE, HEAD_DAMP)
	if blunt:
		_fold_v += s * _kick(LEAN_RATE, LEAN_DAMP)
		if heavy:
			_wide_v += _kick(SLOW_RATE, SLOW_DAMP)
	elif damage >= BIG:
		_wide_v += 0.35 * _kick(SLOW_RATE, SLOW_DAMP)
	if braced and (damage >= BIG or flat == Vector2.ZERO):
		_buckle_v += minf(s, 1.0) * _kick(SLOW_RATE, SLOW_DAMP)
	var cam := s * _kick(CAM_RATE, CAM_DAMP)
	_cam_v += Vector3(flat.y * CAM + (CAM * 0.5 if flat == Vector2.ZERO else 0.0), -flat.x * CAM * 0.6, (flat.x + side * 0.3) * CAM_ROLL) * cam


# The speed to give a spring (of this rate and damping) for it to swing out to about 1.
static func _kick(rate: float, damp: float) -> float:
	var root := sqrt(maxf(1.0 - damp * damp, 0.0001))
	return rate / exp(-damp * atan2(root, damp) / root)


## Nothing left of any hit (a respawn, a death).
func stop() -> void:
	lean = Vector2.ZERO
	twist = 0.0
	head = Vector2.ZERO
	fold = 0.0
	wide = 0.0
	buckle = 0.0
	_lean_v = Vector2.ZERO
	_twist_v = 0.0
	_head_v = Vector2.ZERO
	_fold_v = 0.0
	_wide_v = 0.0
	_buckle_v = 0.0
	_cam = Vector3.ZERO
	_cam_v = Vector3.ZERO


func update(delta: float) -> void:
	# The springs, in steps short enough to stay steady at any frame rate.
	var steps := maxi(ceili(delta / 0.004), 1)
	var dt := delta / steps
	for i in steps:
		_lean_v += (-LEAN_RATE * LEAN_RATE * lean - 2.0 * LEAN_DAMP * LEAN_RATE * _lean_v) * dt
		lean += _lean_v * dt
		_twist_v += (-LEAN_RATE * LEAN_RATE * twist - 2.0 * LEAN_DAMP * LEAN_RATE * _twist_v) * dt
		twist += _twist_v * dt
		_fold_v += (-LEAN_RATE * LEAN_RATE * fold - 2.0 * LEAN_DAMP * LEAN_RATE * _fold_v) * dt
		fold += _fold_v * dt
		_head_v += (-HEAD_RATE * HEAD_RATE * head - 2.0 * HEAD_DAMP * HEAD_RATE * _head_v) * dt
		head += _head_v * dt
		_wide_v += (-SLOW_RATE * SLOW_RATE * wide - 2.0 * SLOW_DAMP * SLOW_RATE * _wide_v) * dt
		wide += _wide_v * dt
		_buckle_v += (-SLOW_RATE * SLOW_RATE * buckle - 2.0 * SLOW_DAMP * SLOW_RATE * _buckle_v) * dt
		buckle += _buckle_v * dt
		_cam_v += (-CAM_RATE * CAM_RATE * _cam - 2.0 * CAM_DAMP * CAM_RATE * _cam_v) * dt
		_cam += _cam_v * dt
	# However fast the hits come, the body is only thrown so far: past that it shudders in place.
	if lean.length() > MOST_LEAN:
		lean = lean.normalized() * MOST_LEAN
		_lean_v *= 0.5
	twist = clampf(twist, -MOST_TWIST, MOST_TWIST)
	head = head.limit_length(MOST_HEAD)
	fold = clampf(fold, -0.5, 1.4)
	wide = clampf(wide, -0.3, 1.3)
	buckle = clampf(buckle, -0.2, 1.2)


## Still showing (the body has not settled yet).
func busy() -> bool:
	return lean.length_squared() > 0.000004 or absf(twist) > 0.002 or head.length_squared() > 0.000004 \
		or absf(fold) > 0.002 or absf(wide) > 0.002 or absf(buckle) > 0.002 \
		or _lean_v.length_squared() > 0.0004 or _head_v.length_squared() > 0.0004 or absf(_wide_v) > 0.02 or absf(_buckle_v) > 0.02


# ---------------------------------------------------------------------------
# The body (RobotAnimator)

## Throws the upper body in `pose`: the spine, chest and head, and the arms if they are
## thrown wide. `bones`: the rig's, by name. `amount`: how much of it shows (0 for your
## own body in first person); `air`: off the ground (it goes further, and the legs swing
## the other way under it).
func pose_body(pose: RobotPose, bones: Dictionary, amount: float, air: bool) -> void:
	if amount <= 0.0:
		return
	var k := amount * (AIR if air else 1.0)
	var spine: int = bones["spine"]
	var chest: int = bones["chest"]
	var neck: int = bones["head"]
	var back := lean.y * k          # (+: rocked back)
	var aside := lean.x * k         # (+: to its right)
	var over := maxf(fold, 0.0) * FOLD * k
	# The spine and the chest share the lean, and the fold: doubled up over a blow.
	pose.rot[spine] = _thrown(back * 0.5 - over * 0.4, aside * 0.5, 0.0) * pose.rot[spine]
	pose.rot[chest] = _thrown(back * 0.5 - over * 0.6, aside * 0.5, twist * k) * pose.rot[chest]
	# The head rides what the body did, gives a little of it back, and adds its own snap.
	pose.rot[neck] = _thrown(head.y * k - back * 0.3 + over * 0.35, -aside * 0.3, head.x * k - twist * k * 0.5) * pose.rot[neck]
	if absf(wide) > 0.002:
		var out := wide * WIDE * amount
		var right: int = bones["upper_arm_r"]
		var left: int = bones["upper_arm_l"]
		pose.rot[right] = Quaternion(Vector3.UP, -out) * Quaternion(Vector3.BACK, out * 0.5) * pose.rot[right]
		pose.rot[left] = Quaternion(Vector3.UP, out) * Quaternion(Vector3.BACK, -out * 0.5) * pose.rot[left]
	if air:
		# Nothing to stand on: the legs swing out the other way under it (and come up under a fold).
		var under := Quaternion(Vector3.RIGHT, (back + over) * AIR_LEGS) * Quaternion(Vector3.BACK, aside * AIR_LEGS)
		for name in ["thigh_l", "thigh_r"]:
			var thigh: int = bones[name]
			pose.rot[thigh] = under * pose.rot[thigh]


# A bone thrown back (about its right), to its right (about its back) and turned (about its up).
static func _thrown(back: float, aside: float, turn: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, back) * Quaternion(Vector3.BACK, -aside) * Quaternion(Vector3.UP, turn)


## Metres the hips drop as the knees buckle.
func drop() -> float:
	return maxf(buckle, 0.0) * BUCKLE


# ---------------------------------------------------------------------------
# Your own arms, and the camera (ViewModel)

## Where the whole view model goes: [metres (right, up, back), radians (muzzle up, aside, roll)].
func view() -> Array:
	return [Vector3(lean.x * ARMS, -lean.length() * ARMS * 0.6 - drop() * 0.3, lean.y * ARMS),
		Vector3(lean.y * ARMS_TILT * 0.5, -twist * 0.25, -lean.x * ARMS_TILT)]


## The camera's own knock: radians of [pitch (up), yaw, roll], to add to the view (never
## to the aim). It is back at nothing a moment after the last hit.
func camera() -> Vector3:
	return _cam.limit_length(CAM_MAX)
