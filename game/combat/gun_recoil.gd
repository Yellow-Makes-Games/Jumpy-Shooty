class_name GunRecoil
extends RefCounted
## What firing a gun does to whoever fires it. Looks only: nothing here moves the aim,
## the shot or the player.
##
## RobotAnimator (the body, for every player) and ViewModel (your own arms, and through
## them the camera) each keep one: they tell it of every shot (fire), step it every frame
## (update), then read off it where the kick has got to.
##
## A shot is two things, a beat apart. The snap is the gun jumping in the hands: there at
## once and gone in a tenth of a second. The rock is the body taking it: it comes up a few
## frames behind the snap, goes a little past rest on its way home and settles. Where the
## rock goes is the gun's family's (WeaponData.GROUPS): a sidearm snaps at the wrist, a
## rifle pushes the shoulder back, a shotgun or a marksman's rifle rocks the chest, and a
## launcher shoves the whole upper body back. How hard is the gun's own WeaponData.kick
## (see strength), so a gun is tuned there and nowhere else.
##
## Holding the trigger builds heat (0..1): the arms shake and creep up, more the longer
## the burst, and settle when it stops. The aim does not creep with them.
##
## The gun's own working parts go with every shot too (PARTS): a slide or a charging
## handle snaps back and home, a hammer falls, a cylinder comes round, vents stand open
## while the gun is hot, the minigun's barrels spin. A pump, a bolt or a lever worked by
## hand after the shot is a clip instead (RobotAnimator, "fire_<gun>").
##
## The camera (first person only) is kicked up a little by each shot and springs straight
## back to where it was: camera() is added to the view, never to the aim.

## The body, per family (in WeaponData.GROUPS' order), in radians for a shot of strength 1:
##   hand:  the wrist flips the gun up (the snap)      arms: both arms lift it (the snap, and half the rock)
##   turn:  the chest turns, gun shoulder back         chest, spine: they rock back
##   back:  the chest is pushed straight back, metres  rate: how quickly the body takes it and gives it back
##   hold:  how much of a burst's heat shows in the arms
const BODY := [
	{"hand": 0.30, "arms": 0.11, "turn": 0.0, "chest": 0.02, "spine": 0.0, "back": 0.006, "rate": 26.0, "hold": 0.6},     # sidearms: at the wrist
	{"hand": 0.04, "arms": 0.075, "turn": 0.07, "chest": 0.07, "spine": 0.03, "back": 0.04, "rate": 15.0, "hold": 0.8},   # shotguns: the chest
	{"hand": 0.03, "arms": 0.075, "turn": 0.10, "chest": 0.04, "spine": 0.0, "back": 0.03, "rate": 22.0, "hold": 1.0},    # rifles: the shoulder
	{"hand": 0.03, "arms": 0.07, "turn": 0.07, "chest": 0.07, "spine": 0.035, "back": 0.04, "rate": 14.0, "hold": 0.6},   # marksman: the chest
	{"hand": 0.0, "arms": 0.06, "turn": 0.03, "chest": 0.06, "spine": 0.09, "back": 0.05, "rate": 10.0, "hold": 0.8},     # explosives: the whole upper body
]
## Your own arms in first person, per family, for a shot of strength 1:
##   back: the gun comes straight back, metres     pitch: its muzzle flips up, radians
##   roll: it twists in the hands, radians         drop: it sags as the body takes the shot, metres
##   hand: a sidearm flips at the wrist as well    cam:  the camera's own kick, radians
const VIEW := [
	{"back": 0.030, "pitch": 0.060, "roll": 0.030, "drop": 0.004, "hand": 0.20, "cam": 0.008},
	{"back": 0.060, "pitch": 0.085, "roll": 0.040, "drop": 0.014, "hand": 0.0, "cam": 0.014},
	{"back": 0.028, "pitch": 0.030, "roll": 0.025, "drop": 0.004, "hand": 0.0, "cam": 0.0045},
	{"back": 0.065, "pitch": 0.075, "roll": 0.030, "drop": 0.012, "hand": 0.0, "cam": 0.014},
	{"back": 0.070, "pitch": 0.050, "roll": 0.050, "drop": 0.022, "hand": 0.0, "cam": 0.016},
]
## A burst: how hard each gun shakes with its heat (left out: 1).
const SHAKE := {"minigun": 2.4, "lmg": 1.5, "machine_pistol": 1.3, "plasma_cannon": 1.3, "laser_rifle": 0.5, "nail_gun": 0.8}
const HEAT_GAP := 0.3        ## shots closer together than this (seconds) are a burst...
const HEAT_BUILD := 1.3      ## ...which is at its full heat after this long...
const HEAT_HOLD := 0.14      ## ...holds it this long after the last shot...
const HEAT_COOL := 2.6       ## ...and loses it at this rate (1/s)
const CLIMB := 0.035         ## radians the arms creep up at full heat
const SHAKE_ARMS := 0.016    ## radians the arms shake at full heat (a gun of SHAKE 1)
const SHAKE_RATE := 58.0
const SNAP_FADE := 18.0      ## the snap dies away at this rate (1/s)
const ROCK_DAMP := 0.55      ## the rock's spring: it goes a little past rest and settles
const CAM_RATE := 34.0       ## the camera's kick: up in a few frames, back in a tenth of a second...
const CAM_DAMP := 0.75
const CAM_MAX := 0.06        ## ...and never more than this, radians, however fast the gun fires
const AIR := 1.6             ## off the ground the body has nothing to brace on: it rocks this much further
const SPIN := 22.0           ## the minigun's barrels at full speed, radians a second...
const SPIN_UP := 0.5         ## ...which they reach in this long, firing...
const SPIN_DOWN := 1.4       ## ...and lose in this long

## A gun's own working parts (by the weapon it looks like), each [bone, what it does, ...]:
##   "back", metres, seconds:           snaps back along the barrel and comes home
##   "pop", Vector3, seconds:           the same, any way (gun space: x right, y up, -z forward)
##   "turn", degrees, seconds, up:      comes round about the barrel's line, `up` above the grip (a
##                                      six-sided cylinder or drum: it starts one chamber short)
##   "hinge", degrees, seconds, pivot:  swings about a sideways line through (up, forward) of the grip, and back
##   "whip", degrees, seconds, pivot:   goes right round it, once (a crank let go)
##   "open", Vector3:                   stands this far open while the gun is hot
##   "lift", degrees, pivot:            hinged open while the gun is hot
##   "spin", up:                        the minigun's barrels, about the line `up` above the grip
const PARTS := {
	"pistol": [["slide", "back", 0.04, 0.10]],
	"machine_pistol": [["slide", "back", 0.03, 0.055], ["vent", "open", Vector3(0.0, -0.005, 0.007)]],
	"akimbo": [["slide", "back", 0.04, 0.10]],
	"revolver": [["mag", "turn", 60.0, 0.13, 0.046], ["slide", "hinge", -32.0, 0.20, Vector2(0.066, -0.02)]],
	"derringer": [["slide", "hinge", -30.0, 0.18, Vector2(0.06, -0.008)]],
	"flare_gun": [["slide", "hinge", -32.0, 0.22, Vector2(0.066, -0.026)]],
	"plasma_pistol": [["vent", "hinge", -24.0, 0.13, Vector2(0.087, -0.01)], ["vent", "lift", -34.0, Vector2(0.087, -0.01)]],
	"auto_shotgun": [["slide", "back", 0.05, 0.12]],
	"air_cannon": [["mag", "back", 0.03, 0.4]],
	"smg": [["slide", "back", 0.035, 0.06]],
	"rifle": [["slide", "back", 0.04, 0.075]],
	"burst_rifle": [["slide", "back", 0.035, 0.055]],
	"battle_rifle": [["slide", "back", 0.045, 0.11]],
	"lmg": [["slide", "pop", Vector3(0.0, 0.005, 0.0), 0.06]],
	"minigun": [["vent", "spin", 0.05], ["slide", "pop", Vector3(0.0, 0.004, 0.0), 0.04]],
	"laser_rifle": [["vent", "open", Vector3(0.0, 0.008, 0.016)]],
	"nail_gun": [["vent", "pop", Vector3(0.0, 0.004, 0.0), 0.06], ["vent", "open", Vector3(0.0, 0.005, 0.0)]],
	"crossbow": [["vent", "whip", 360.0, 0.28, Vector2(0.04, 0.03)]],
	"harpoon_gun": [["vent", "back", 0.035, 0.3]],
	"rocket_launcher": [["vent", "back", 0.035, 0.45]],
	"grenade_launcher": [["mag", "turn", 60.0, 0.16, 0.07], ["slide", "hinge", -28.0, 0.2, Vector2(0.068, -0.03)]],
	"mortar": [["vent", "back", 0.035, 0.5]],
	"plasma_cannon": [["vent", "pop", Vector3(0.0, 0.008, 0.012), 0.28]],
}
const REST := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   ## gun space to a gun bone's (ReloadFx.GUN_REST)

var snap := 0.0          ## the gun's jump in the hands, in shots' strengths (the right hand's, akimbo)
var snap_l := 0.0        ## akimbo: the left gun's
var rock := 0.0          ## the body taking it
var heat := 0.0          ## how long the trigger has been held, 0..1
var side := 0.0          ## which way the last shot twisted, -1..1
## The minigun, in the hands of someone whose trigger we know (your own): how spun up it
## is, 0..1 (WeaponState.spin). -1: not known, so the barrels go by its shots.
var spun := -1.0

var _look := "pistol"
var _family := 0
var _strength := 0.0
var _akimbo := false
var _shake := 1.0
var _parts: Array = []
var _rock_v := 0.0
var _cam := Vector3.ZERO      # pitch (up), yaw, roll
var _cam_v := Vector3.ZERO
var _since := 99.0
var _part_t := 99.0           # seconds since the gun's last shot (the right hand's, akimbo)
var _part_t_l := 99.0
var _shots := 0
var _noise := 0.0
var _spin_rate := 0.0
var _spin := 0.0


func _init(data: WeaponData = null) -> void:
	if data:
		set_weapon(data)


## How hard a gun of this WeaponData.kick kicks here: a light gun's shot still shows, and
## the heaviest are not twice as far again as the merely heavy (the anti-materiel rifle
## is 2, a shotgun 1.3, a pistol 0.8, a rifle 0.55).
static func strength(kick: float) -> float:
	return 0.8 * pow(maxf(kick, 0.0), 0.65)


func set_weapon(data: WeaponData) -> void:
	_look = WeaponData.look_of(data.id)
	_family = clampi(WeaponData.group_of(_look), 0, BODY.size() - 1)
	_strength = 0.0 if data.is_melee() else strength(data.kick)
	_akimbo = data.is_akimbo()
	_shake = SHAKE.get(_look, 1.0)
	_parts = PARTS.get(_look, [])
	stop()


## Nothing left of the last shot (a respawn, a new gun).
func stop() -> void:
	snap = 0.0
	snap_l = 0.0
	rock = 0.0
	heat = 0.0
	_rock_v = 0.0
	_cam = Vector3.ZERO
	_cam_v = Vector3.ZERO
	_since = 99.0
	_part_t = 99.0
	_part_t_l = 99.0
	_spin_rate = 0.0


## A shot (akimbo: from the left gun when `left`).
func fire(left: bool = false) -> void:
	_shots += 1
	if _akimbo and left:
		snap_l = _strength
		_part_t_l = 0.0
	else:
		snap = _strength
		_part_t = 0.0
	# Which way it twists: side to side, shot about, never quite the same twice.
	var r := absf(fposmod(sin(float(_shots) * 12.9898) * 43758.5453, 1.0))
	side = (1.0 if _shots % 2 == 0 else -1.0) * lerpf(0.4, 1.0, r)
	if _akimbo:
		side = -absf(side) if left else absf(side)
	_rock_v += _strength * _rate() / 0.52   # (a kick of this speed carries the rock to about `_strength`)
	var cam: float = VIEW[_family].cam * _strength * CAM_RATE / 0.44
	_cam_v += Vector3(cam, cam * 0.3 * side, cam * 0.35 * side)
	if _since < HEAT_GAP:
		heat = minf(heat + maxf(_since, 0.03) / HEAT_BUILD, 1.0)
	_since = 0.0


func update(delta: float) -> void:
	_since += delta
	_part_t += delta
	_part_t_l += delta
	_noise += delta * SHAKE_RATE
	snap *= exp(-delta * SNAP_FADE)
	snap_l *= exp(-delta * SNAP_FADE)
	if _since > HEAT_HOLD:
		heat = maxf(heat - delta * HEAT_COOL, 0.0)
	# The springs, in steps short enough to stay steady at any frame rate.
	var steps := maxi(ceili(delta / 0.004), 1)
	var dt := delta / steps
	var rate := _rate()
	for i in steps:
		_rock_v += (-rate * rate * rock - 2.0 * ROCK_DAMP * rate * _rock_v) * dt
		rock += _rock_v * dt
		_cam_v += (-CAM_RATE * CAM_RATE * _cam - 2.0 * CAM_DAMP * CAM_RATE * _cam_v) * dt
		_cam += _cam_v * dt
	rock = clampf(rock, -1.5, 2.6)
	# The minigun's barrels: up to speed while it fires (or, where we know, while the trigger is held).
	var turning := spun if spun >= 0.0 else (1.0 if _since < 0.15 else 0.0)
	_spin_rate = move_toward(_spin_rate, turning * SPIN, delta * SPIN / (SPIN_UP if turning * SPIN > _spin_rate else SPIN_DOWN))
	_spin = fposmod(_spin + _spin_rate * delta, TAU)


func _rate() -> float:
	return BODY[_family].rate


## Still showing (the arms have not settled yet).
func busy() -> bool:
	return maxf(snap, snap_l) > 0.01 or absf(rock) > 0.01 or heat > 0.0


# ---------------------------------------------------------------------------
# The body (RobotAnimator)

## The burst's shake, about -1..1 each way (x: side to side, y: up and down), scaled by its heat.
func shake() -> Vector2:
	if heat <= 0.0:
		return Vector2.ZERO
	var n := Vector2(sin(_noise) + sin(_noise * 2.3 + 1.3), sin(_noise * 1.7 + 0.5) + sin(_noise * 2.9 + 2.1)) * 0.5
	return n * heat * _shake * float(BODY[_family].hold)


## Radians the arms lift the gun (akimbo: the left arm's own when `left`).
func arm_lift(left: bool = false) -> float:
	var f: Dictionary = BODY[_family]
	if _akimbo:   # each arm takes its own gun's shots, and only those
		return f.arms * 1.4 * (snap_l if left else snap) + (CLIMB * heat + SHAKE_ARMS * shake().y) * float(f.hold)
	return f.arms * (snap + 0.5 * rock) + (CLIMB * heat + SHAKE_ARMS * shake().y) * float(f.hold)


## Radians the wrist flips it up.
func hand_snap(left: bool = false) -> float:
	return BODY[_family].hand * (snap_l if left and _akimbo else snap)


## Radians the chest turns, gun shoulder back.
func chest_turn() -> float:
	return BODY[_family].turn * rock + SHAKE_ARMS * 0.6 * shake().x


## Radians the chest, and the spine under it, rock back.
func chest_rock() -> float:
	return BODY[_family].chest * rock


func spine_rock() -> float:
	return BODY[_family].spine * rock


## Metres the chest is pushed straight back.
func shove() -> float:
	return BODY[_family].back * maxf(rock, 0.0)


# ---------------------------------------------------------------------------
# Your own arms, and the camera (ViewModel)

## Where the whole view model goes: [metres back, metres down, radians the muzzle flips
## up, radians it turns aside, radians it rolls].
func view() -> Array:
	var f: Dictionary = VIEW[_family]
	var s := maxf(snap, snap_l)
	if _akimbo:
		s *= 0.5   # each arm takes most of its own gun's kick (see hand_view)
	var jig := shake()
	return [f.back * s + 0.006 * heat,
		f.drop * rock - 0.004 * heat - 0.0025 * jig.y,
		f.pitch * s + 0.4 * f.pitch * rock + CLIMB * 0.6 * heat + SHAKE_ARMS * 0.5 * jig.y,
		f.roll * 0.4 * side * s + SHAKE_ARMS * 0.5 * jig.x,
		f.roll * side * s]


## Radians a sidearm flips up at the wrist, in your own hands.
func hand_view(left: bool = false) -> float:
	return VIEW[_family].hand * (snap_l if left and _akimbo else snap)


## The camera's own kick: radians of [pitch (up), yaw, roll], to add to the view (never to
## the aim). It is back at nothing a moment after the last shot.
func camera() -> Vector3:
	var jig := shake() * 0.0016
	return (_cam + Vector3(jig.y, jig.x, 0.0)).limit_length(CAM_MAX)


# ---------------------------------------------------------------------------
# The gun's own working parts

## Moves them in `pose` (after everything else has had its say over the gun's bones).
func pose_parts(pose: RobotPose, bones: Dictionary) -> void:
	if _parts.is_empty():
		return
	_pose_gun(pose, bones, "pistol_", _part_t)
	if _akimbo:
		_pose_gun(pose, bones, "pistol_l_", _part_t_l)


func _pose_gun(pose: RobotPose, bones: Dictionary, prefix: String, t: float) -> void:
	for part in _parts:
		var b: int = bones.get(prefix + str(part[0]), -1)
		if b < 0:
			continue
		match str(part[1]):
			"back":
				pose.pos[b] += REST * Vector3(0.0, 0.0, float(part[2]) * _out_and_home(t / float(part[3])))
			"pop":
				pose.pos[b] += REST * ((part[2] as Vector3) * _out_and_home(t / float(part[3])))
			"turn":
				var short := 1.0 - smoothstep(0.0, 1.0, clampf(t / float(part[3]), 0.0, 1.0))
				if short > 0.0:
					_turn(pose, b, Basis(Vector3.BACK, deg_to_rad(-float(part[2]) * short)), Vector3(0.0, float(part[4]), 0.0))
			"hinge":
				var swung := _out_and_home(t / float(part[3]))
				if swung > 0.0:
					_turn(pose, b, Basis(Vector3.RIGHT, deg_to_rad(float(part[2]) * swung)), _pivot(part[4]))
			"whip":
				var u := clampf(t / float(part[3]), 0.0, 1.0)
				if u < 1.0:
					_turn(pose, b, Basis(Vector3.RIGHT, deg_to_rad(float(part[2])) * (1.0 - pow(1.0 - u, 2.0))), _pivot(part[4]))
			"open":
				pose.pos[b] += REST * ((part[2] as Vector3) * smoothstep(0.0, 1.0, heat))
			"lift":
				if heat > 0.0:
					_turn(pose, b, Basis(Vector3.RIGHT, deg_to_rad(float(part[2])) * smoothstep(0.0, 1.0, heat)), _pivot(part[3]))
			"spin":
				if _spin != 0.0:
					_turn(pose, b, Basis(Vector3.BACK, _spin), Vector3(0.0, float(part[2]), 0.0))


## 0..1..0 over u = 0..1: out in the first quarter, home over the rest.
static func _out_and_home(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return u / 0.25 if u < 0.25 else 1.0 - smoothstep(0.0, 1.0, (u - 0.25) / 0.75)


static func _pivot(up_forward: Vector2) -> Vector3:
	return Vector3(0.0, up_forward.x, -up_forward.y)


## Turns a gun bone by `turn` (gun space) about the point `pivot` (gun space, from the grip).
static func _turn(pose: RobotPose, b: int, turn: Basis, pivot: Vector3) -> void:
	var round := (REST * turn * REST.inverse()).orthonormalized()
	pose.rot[b] = Quaternion(round) * pose.rot[b]
	pose.pos[b] = round * pose.pos[b] + REST * (pivot - turn * pivot)
