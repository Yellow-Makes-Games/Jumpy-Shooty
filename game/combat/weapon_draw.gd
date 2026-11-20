class_name WeaponDraw
extends RefCounted
## Taking a weapon out: looks only. The weapon is in your hands, and fires, from the
## moment you switch to it (a shot or a swing cuts the draw short: see cut); this is what
## the arms, the weapon and its glow do for the third of a second after.
##
## RobotAnimator (the body, for every player) and ViewModel (your own arms) each keep
## one, start it when the weapon is taken out (a Deathmatch switch, Gun Game's next
## weapon, one picked up into your hands, a respawn) and step it every frame.
##
## A draw is two things. Where the weapon comes from is its family's (KINDS, by where it
## is carried: see carried): a sidearm snaps up from the thigh, a long gun comes over the
## shoulder off the back, a launcher is heaved off it and the body dips under the weight.
## On top of that every weapon has a flourish of its own (FLOURISH: a spin round the
## trigger finger, a toss, its own working parts, a clip of the body's), and it powers
## on as it comes up: its glow fills (glow).

## Where a weapon comes from, and how. Third person: `lift` radians both arms swing the
## weapon through to get it to the aim (- from below, + from over the shoulder), `turn`
## radians the chest turns with it. First person: the whole view model starts `pos`
## (metres: right, up, back) and `rot` (radians: muzzle up, aside, roll) away from where
## it is held (never up: a long gun comes in from low on the right, tipped up and canted). `time`: seconds the draw takes; `over`: how far past it goes before it
## settles; `dip`: how hard the weight lands (the body dips, the view drops).
const KINDS := {
	"thigh": {"time": 0.30, "lift": -1.25, "turn": 0.12, "pos": Vector3(0.04, -0.34, 0.03), "rot": Vector3(-0.45, 0.0, 0.2), "over": 1.5, "dip": 0.0},
	"back": {"time": 0.36, "lift": 1.7, "turn": -0.35, "pos": Vector3(0.16, -0.30, 0.0), "rot": Vector3(0.35, 0.2, -0.45), "over": 1.2, "dip": 0.25},
	"heavy": {"time": 0.46, "lift": 1.7, "turn": -0.45, "pos": Vector3(0.18, -0.34, 0.0), "rot": Vector3(0.4, 0.25, -0.55), "over": 0.8, "dip": 1.0},
	"belt": {"time": 0.24, "lift": -0.9, "turn": 0.0, "pos": Vector3(0.0, -0.28, 0.03), "rot": Vector3(-0.35, 0.0, 0.0), "over": 1.6, "dip": 0.0},
	"none": {"time": 0.22, "lift": -0.6, "turn": 0.0, "pos": Vector3(0.0, -0.2, 0.0), "rot": Vector3(-0.3, 0.0, 0.0), "over": 1.2, "dip": 0.0},
}
## The weapons heaved off the back, not swung (everything in Explosives is one as well).
const HEAVY := ["minigun", "lmg", "anti_materiel", "hammer"]
## Melee weapons by where they are carried (the rest of them: across the back).
const ON_THIGH := ["dagger", "machete", "wrench"]
const ON_BELT := ["brass_knuckles", "claws"]
const AKIMBO_GAP := 0.1      ## akimbo: the right gun comes this long after the left
const GLOW_FROM := 0.06      ## the weapon powers on: its glow starts to fill here...
const GLOW_TIME := 0.3       ## ...and is full this long after
const SLAP_LIFT := 0.32      ## radians the off arm lifts to slap down on the weapon
const TRIGGER := Vector3(0.0, 0.006, -0.025)   ## a gun spun round the hand turns about the trigger finger (gun space)
const X := Vector3.RIGHT
const Z := Vector3.BACK

## Each weapon's own flourish (by the weapon it looks like): beats, in seconds from the
## start of the draw. Axes and pivots are in the weapon's own space (a gun: x right, y up,
## -z forward, from the grip; a melee weapon: the blade up +y, its edge toward -z).
##   ["spin", from, to, turns, axis, pivot]     the weapon goes round in the hand (- : forward)
##   ["unspin", from, to, turns, axis, pivot]   it starts that far round, and comes round into place
##   ["toss", from, to, metres, turns, axis]    it leaves the hand, goes up that far turning, and is caught
##                                              (a seventh entry, true: it starts that far round, and is caught the right way up)
##   ["nod", from, to, radians]                 its end dips (-) or lifts (+) about the grip, and comes back
##   ["part", at, <an entry of GunRecoil.PARTS>]   one of its working parts goes, as for a shot
##   ["shut", from, to, <entry>]                that part starts out as far as it goes, and shuts between the two
##   ["whirl", from, to, bone, turns, up]       that part goes round the barrel's line, `up` above the grip
##   ["whirl", from, to, bone, turns, middle, axis]   ...or round `axis` through its own `middle`
##   ["clip", at]                               the body's own "fire_<gun>" clip plays (a bolt, a lever, a pump)
##   ["jolt", at, amount]                       a knock through the arms and body (-: down)
##   ["slap", from, to]                         the off hand comes up off the weapon and down on it
##   ["hands", from, to, radians]               both fists come together in front of the chest, and part
##   ["spark", at]                              a spark where the hands are (Player)
##   ["grow", from, to, start]                  a melee weapon comes out of the hand: from `start` of its size
##   ["cue", at, sound]                         a sound (SfxList)
## "glow": [from, seconds, steps] in place of the usual fill (steps: it comes on in that many jumps).
## "kind": a draw other than its family's (KINDS).   "time": other than that kind's.
## "view_beats": the beats in your own first-person hands, where they differ.
const FLOURISH := {
	# Sidearms
	"pistol": {"beats": [["part", 0.17, ["slide", "back", 0.04, 0.17]], ["cue", 0.17, "slide_back"], ["cue", 0.27, "slide_fwd"]]},
	"revolver": {"beats": [["spin", 0.05, 0.40, -1.0, X, TRIGGER], ["whirl", 0.22, 0.62, "mag", 2.0, 0.046], ["cue", 0.06, "gun_spin"], ["cue", 0.25, "drum_turn"]]},
	"machine_pistol": {"beats": [["part", 0.15, ["vent", "pop", Vector3(0.0, -0.01, 0.014), 0.22]], ["cue", 0.15, "vent_hiss"]]},
	"akimbo": {"beats": [["unspin", 0.03, 0.27, 0.5, X, TRIGGER], ["cue", 0.04, "gun_spin"], ["cue", 0.14, "gun_spin"]]},
	"derringer": {"beats": [["toss", 0.03, 0.30, 0.09, -1.0, X], ["cue", 0.03, "gun_toss"]]},
	"flare_gun": {"beats": [["toss", 0.05, 0.38, 0.13, -1.0, X], ["cue", 0.05, "gun_toss"]]},
	"plasma_pistol": {"beats": [["part", 0.12, ["vent", "hinge", -46.0, 0.34, Vector2(0.087, -0.01)]], ["cue", 0.12, "vent_hiss"]], "glow": [0.1, 0.4, 1]},
	# Shotguns
	"shotgun": {"beats": [["nod", 0.10, 0.34, -0.5], ["part", 0.12, ["slide", "back", 0.07, 0.2]], ["cue", 0.12, "pump_back"], ["cue", 0.24, "pump_fwd"]]},
	"break_action": {"beats": [["shut", 0.22, 0.30, ["vent", "hinge", -38.0, 1.0, Vector2(0.045, 0.13)]], ["nod", 0.2, 0.36, 0.3], ["cue", 0.27, "break_close"]]},
	"auto_shotgun": {"beats": [["slap", 0.04, 0.16], ["whirl", 0.14, 0.5, "mag", 1.0, Vector3(0.0, -0.06, -0.12), X], ["part", 0.36, ["slide", "back", 0.05, 0.16]], ["cue", 0.14, "drum_turn"], ["cue", 0.36, "charge_back"], ["cue", 0.45, "charge_fwd"]]},
	"slug_shotgun": {"beats": [["part", 0.26, ["slide", "back", 0.07, 0.2]], ["jolt", 0.30, -0.6], ["cue", 0.26, "pump_back"], ["cue", 0.37, "pump_fwd"]]},
	"air_cannon": {"beats": [["part", 0.14, ["mag", "back", 0.035, 0.5]], ["cue", 0.14, "vent_hiss"]], "glow": [0.1, 0.5, 1]},
	# Rifles
	"smg": {"beats": [["spin", 0.03, 0.31, -1.0, X, Vector3(0.0, 0.0, -0.03)], ["cue", 0.04, "gun_spin"]]},
	"rifle": {"beats": [["slap", 0.16, 0.30], ["part", 0.28, ["slide", "back", 0.04, 0.16]], ["jolt", 0.28, -0.3], ["cue", 0.28, "charge_back"], ["cue", 0.37, "charge_fwd"]]},
	"burst_rifle": {"beats": [["cue", 0.10, "power_on"], ["cue", 0.22, "power_on"], ["cue", 0.34, "power_on"]], "glow": [0.1, 0.36, 3]},
	"lmg": {"beats": [["slap", 0.24, 0.40], ["shut", 0.36, 0.40, ["slide", "pop", Vector3(0.0, 0.03, 0.0), 1.0]], ["jolt", 0.40, -0.6], ["cue", 0.39, "cover_close"]]},
	"minigun": {"beats": [["whirl", 0.14, 0.9, "vent", 3.0, 0.05], ["cue", 0.14, "barrel_spin"]]},
	"battle_rifle": {"beats": [["part", 0.26, ["slide", "back", 0.045, 0.22]], ["cue", 0.26, "charge_back"], ["cue", 0.40, "charge_fwd"]]},
	"laser_rifle": {"beats": [["part", 0.12, ["vent", "pop", Vector3(0.0, 0.010, 0.02), 0.5]], ["cue", 0.12, "vent_hiss"]], "glow": [0.12, 0.5, 1]},
	"nail_gun": {"beats": [["part", 0.16, ["vent", "pop", Vector3(0.0, 0.006, 0.0), 0.07]], ["part", 0.24, ["vent", "pop", Vector3(0.0, 0.006, 0.0), 0.07]],
		["part", 0.32, ["vent", "pop", Vector3(0.0, 0.006, 0.0), 0.07]], ["cue", 0.16, "vent_hiss"]]},
	# Marksman
	"lever_action": {"beats": [["spin", 0.05, 0.40, -1.0, X, Vector3(0.0, -0.02, 0.03)], ["cue", 0.06, "gun_spin"]]},
	"bolt_action": {"beats": [["clip", 0.2]]},
	"sniper": {"beats": [["slap", 0.08, 0.22], ["clip", 0.24]], "glow": [0.18, 0.2, 1]},
	"railgun": {"beats": [["clip", 0.16], ["cue", 0.2, "rail_vent"]], "glow": [0.2, 0.3, 1]},
	"crossbow": {"beats": [["part", 0.16, ["vent", "whip", 360.0, 0.3, Vector2(0.04, 0.03)]], ["jolt", 0.2, 0.4]]},
	"anti_materiel": {"beats": [["jolt", 0.16, -1.0], ["clip", 0.2]], "time": 0.55},
	"harpoon_gun": {"beats": [["whirl", 0.12, 0.6, "vent", 2.0, 0.065], ["part", 0.14, ["vent", "back", 0.04, 0.34]], ["cue", 0.12, "drum_turn"]]},
	# Explosives
	"rocket_launcher": {"beats": [["spin", 0.04, 0.44, -1.0, X, Vector3(0.0, 0.05, -0.1)], ["cue", 0.05, "gun_spin"]],
		"view_beats": [["spin", 0.04, 0.40, 1.0, Z, Vector3(0.0, 0.05, 0.0)], ["cue", 0.05, "gun_spin"]]},   # (in your own hands it rolls about its length instead)
	"grenade_launcher": {"beats": [["shut", 0.24, 0.32, ["mag", "swing", 62.0, 1.0, Vector2(-0.06, 0.0)]], ["nod", 0.22, 0.4, 0.35], ["cue", 0.30, "cylinder_close"]]},
	"mortar": {"beats": [["jolt", 0.36, -1.4]]},
	"plasma_cannon": {"beats": [["part", 0.2, ["vent", "pop", Vector3(0.0, 0.01, 0.016), 0.4]], ["cue", 0.2, "vent_hiss"]], "glow": [0.1, 0.5, 4]},
	# Melee
	"sword": {"beats": []},
	"hammer": {"beats": [["jolt", 0.36, -1.5]]},
	"dagger": {"beats": [["toss", 0.04, 0.34, 0.1, -1.0, X], ["cue", 0.04, "gun_toss"]]},
	"brass_knuckles": {"beats": [["hands", 0.12, 0.34, 0.42], ["jolt", 0.23, 0.6], ["spark", 0.23]]},
	"spear": {"beats": [["spin", 0.04, 0.44, 1.0, Z, Vector3(0.0, 0.5, 0.0)], ["cue", 0.05, "gun_spin"]]},
	"axe": {"beats": [["toss", 0.06, 0.40, 0.2, 0.5, X, true], ["cue", 0.06, "gun_toss"]]},
	"bat": {"beats": [["jolt", 0.14, 0.5], ["nod", 0.40, 0.85, 0.7]], "time": 0.4},
	"katana": {"kind": "belt", "time": 0.2, "beats": [], "glow": [0.02, 0.3, 1]},
	"scythe": {"beats": [["spin", 0.03, 0.42, 1.0, Z, Vector3(0.0, 0.6, 0.0)], ["cue", 0.04, "gun_spin"]]},
	"mace": {"beats": [["spin", 0.05, 0.40, -1.0, X, Vector3.ZERO], ["cue", 0.06, "gun_spin"]]},
	"machete": {"beats": [["spin", 0.08, 0.38, -1.0, X, Vector3.ZERO], ["cue", 0.08, "gun_spin"]]},
	"wrench": {"beats": [["toss", 0.04, 0.42, 0.18, -2.0, X], ["cue", 0.04, "gun_toss"]]},
	"energy_sword": {"beats": [["grow", 0.12, 0.3, 0.12], ["cue", 0.12, "power_on"]], "glow": [0.12, 0.25, 1]},
	"claws": {"beats": [["grow", 0.1, 0.18, 0.3], ["jolt", 0.14, 0.5]]},
	"karate": {"beats": [["hands", 0.08, 0.32, 0.5], ["jolt", 0.2, 0.7]]},
}

var t := 99.0          ## seconds since the weapon was taken out
var weapon := ""

var _kind: Dictionary = KINDS.none
var _time := 0.3
var _beats: Array = []
var _glow: Array = [GLOW_FROM, GLOW_TIME, 1]
var _melee := false
var _akimbo := false
var _end := 0.0        # everything is over by here
var _last := 99.0      # where `t` was a frame ago (for the beats that happen once)
var _cut := false


## Where a weapon is carried when it is not in your hands, and so where it is drawn from:
## "back", "thigh", "belt" or "none" (bare hands).
static func carried(id: String) -> String:
	var look := WeaponData.look_of(id)
	if not WeaponData.has(id) or look == "karate":
		return "none"
	if WeaponData.melee(look):
		return "thigh" if look in ON_THIGH else ("belt" if look in ON_BELT else "back")
	return "thigh" if WeaponData.group_of(look) == 0 else "back"


## The kind of draw (a key of KINDS) a weapon gets.
static func kind_of(id: String) -> String:
	var look := WeaponData.look_of(id)
	var own: Dictionary = FLOURISH.get(look, {})
	if own.has("kind"):
		return own.kind
	var at := carried(id)
	if at == "back" and (look in HEAVY or (not WeaponData.melee(look) and WeaponData.group_of(look) == 4)):
		return "heavy"
	return at


## The weapon was just taken out. `own_view`: these are your own first-person arms (a
## flourish that would sweep a big weapon across the whole view has a tamer one there).
func start(id: String, own_view: bool = false) -> void:
	weapon = WeaponData.look_of(id)
	var data := WeaponData.by_id(id) if WeaponData.has(id) else null
	_melee = data != null and data.is_melee()
	_akimbo = data != null and data.is_akimbo()
	var own: Dictionary = FLOURISH.get(weapon, {})
	_kind = KINDS[kind_of(id)]
	_time = float(own.get("time", _kind.time))
	_beats = own.get("view_beats", own.get("beats", [])) if own_view else own.get("beats", [])
	_glow = own.get("glow", [GLOW_FROM, GLOW_TIME, 1])
	_end = _time
	for beat in _beats:
		match str(beat[0]):
			"spin", "unspin", "toss", "nod", "shut", "whirl", "grow", "slap", "hands":
				_end = maxf(_end, float(beat[2]))
			"part":
				_end = maxf(_end, float(beat[1]) + _part_time(beat[2]))
			"jolt":
				_end = maxf(_end, float(beat[1]) + 0.3)
	_end = maxf(_end, float(_glow[0]) + float(_glow[1])) + (AKIMBO_GAP if _akimbo else 0.0)
	t = 0.0
	_last = -1.0
	_cut = false


## A shot or a swing: the weapon is where it is held, at once, and the flourish is dropped.
func cut() -> void:
	if active():
		_cut = true
		t = _end


## Nothing of a draw showing (a death).
func stop() -> void:
	t = 99.0
	_last = 99.0


func update(delta: float) -> void:
	_last = t
	t += delta


func active() -> bool:
	return t < _end


## Cut short by a shot (the body's clip, if it had started one, is dropped with it).
func was_cut() -> bool:
	return _cut


## The sounds due this frame.
func cues() -> Array:
	var out := []
	if not active() and _last >= _end:
		return out
	var own_hum := false
	for beat in _beats:
		if str(beat[0]) == "cue":
			own_hum = own_hum or str(beat[2]) == "power_on"
			if _crossed(float(beat[1])):
				out.append(str(beat[2]))
	# Every weapon with lights hums as they come on, and a heavy one lands with a clack.
	if not own_hum and weapon != "karate" and weapon != "" and _crossed(float(_glow[0])):
		out.append("power_on")
	if float(_kind.dip) >= 1.0 and _crossed(_time * 0.9):
		out.append("heavy_clack")
	return out


## The body's own "fire_<gun>" clip is due to start this frame.
func clip_due() -> bool:
	for beat in _beats:
		if str(beat[0]) == "clip" and _crossed(float(beat[1])) and active():
			return true
	return false


func _crossed(at: float) -> bool:
	return _last < at and t >= at


## How far the weapon still is from where it is held: 1 as it is taken out, 0 once it
## is there (a little under on the way: it goes past and settles). `late`: seconds
## behind (the second hand of a pair).
func come(late: float = 0.0) -> float:
	var u := clampf((t - late) / _time, 0.0, 1.0)
	if not active():
		u = 1.0
	var over: float = _kind.over
	var k := u - 1.0
	return -((over + 1.0) * k * k * k + over * k * k)


## A knock through the arms and body right now (-: down), from the weight landing and the
## flourish's own jolts.
func jolt() -> float:
	if not active():
		return 0.0
	var out := _knock(t - _time * 0.9, -float(_kind.dip))
	for beat in _beats:
		if str(beat[0]) == "jolt":
			out += _knock(t - float(beat[1]), float(beat[2]))
	return out


static func _knock(a: float, amount: float) -> float:
	return amount * (a / 0.06) * exp(1.0 - a / 0.06) if a > 0.0 else 0.0


## How brightly the weapon's lit parts shine, of their usual: it powers on as it comes up.
func glow() -> float:
	if not active():
		return 1.0
	var u := clampf((t - float(_glow[0])) / float(_glow[1]), 0.0, 1.0)
	var steps := int(_glow[2])
	if steps > 1:
		return ceilf(u * steps - 0.001) / steps if u > 0.0 else 0.0
	# (It flares a little past full as it catches.)
	return u * u * (1.0 + 0.5 * sin(u * PI))


## How much of its size a melee weapon that comes out of the hand has (1: all of it).
func grown() -> float:
	if not active():
		return 1.0
	for beat in _beats:
		if str(beat[0]) == "grow":
			var u := clampf((t - float(beat[1])) / (float(beat[2]) - float(beat[1])), 0.0, 1.0)
			var out := lerpf(float(beat[3]), 1.0, u)
			return out + 0.12 * sin(u * PI) * u   # (it snaps a little past, and back)
	return 1.0


# ---------------------------------------------------------------------------
# The body (RobotAnimator)

## Radians the arms swing the weapon away from the aim (the left arm's when `left`:
## akimbo's left gun comes first, a sidearm's off hand comes to it a beat late).
func lift(left: bool = false) -> float:
	if _akimbo:
		return float(_kind.lift) * come(0.0 if left else AKIMBO_GAP)
	return float(_kind.lift) * come(_time * 0.3 if left and _kind == KINDS.thigh else 0.0)


## Radians the chest turns with it (+ : to the left).
func turn() -> float:
	return float(_kind.turn) * come()


# ---------------------------------------------------------------------------
# Your own arms (ViewModel)

## Where the whole view model is from where it is held: [metres (right, up, back),
## radians (muzzle up, aside, roll)].
func view() -> Array:
	# (The arms never ride up past where they are held: their shoulders are just out of
	# sight below the view. Going past the hold shows in the weapon's tilt alone.)
	var c := come()
	var j := jolt()
	return [(_kind.pos as Vector3) * maxf(c, 0.0) - Vector3(0.0, 0.035 * absf(j), 0.0),
		(_kind.rot as Vector3) * (c if c > 0.0 else c * 0.35) + Vector3(0.06 * j, 0.0, 0.0)]


# ---------------------------------------------------------------------------
# The weapon in the hand, and its own parts (both)

## Moves the weapon's bones in `pose` for its flourish (after everything else has had its
## say over them). `bones`: the rig's, by name.
## `skeleton`: the body's or the arms' own, as it was posed last frame: a tossed weapon
## goes up, whichever way the hand is turned (without it: along the weapon's own length).
func pose_weapon(pose: RobotPose, bones: Dictionary, skeleton: Skeleton3D = null) -> void:
	if not active():
		return
	_pose_one(pose, bones, "pistol", t - (AKIMBO_GAP if _akimbo else 0.0), _up_in_hand(skeleton, bones, "hand_r"))
	if _akimbo:
		_pose_one(pose, bones, "pistol_l", t, _up_in_hand(skeleton, bones, "hand_l"))


## Which way is up, seen from a hand (the space its weapon's bone is posed in).
static func _up_in_hand(skeleton: Skeleton3D, bones: Dictionary, hand: String) -> Vector3:
	if skeleton == null or not bones.has(hand):
		return Vector3.ZERO
	return skeleton.get_bone_global_pose(bones[hand]).basis.orthonormalized().inverse() * Vector3.UP


func _pose_one(pose: RobotPose, bones: Dictionary, grip: String, at: float, up: Vector3) -> void:
	var b: int = bones.get(grip, -1)
	if b < 0:
		return
	var to_bone := MeleeModel.HOLD if _melee else GunRecoil.REST
	for beat in _beats:
		match str(beat[0]):
			"spin":
				var u := _through(at, beat[1], beat[2])
				if u > 0.0 and u < 1.0:
					_turn(pose, b, Basis(beat[4] as Vector3, TAU * float(beat[3]) * u), beat[5], Vector3.ZERO, to_bone)
			"unspin":
				var u := _through(at, beat[1], beat[2])
				if u < 1.0:
					_turn(pose, b, Basis(beat[4] as Vector3, TAU * float(beat[3]) * (1.0 - u)), beat[5], Vector3.ZERO, to_bone)
			"toss":
				var u := clampf((at - float(beat[1])) / (float(beat[2]) - float(beat[1])), 0.0, 1.0)
				var into: bool = beat.size() > 6 and bool(beat[6])
				if u < 1.0 and (u > 0.0 or into):
					var round := smoothstep(0.0, 1.0, u)
					var high := float(beat[3]) * 4.0 * u * (1.0 - u)
					_turn(pose, b, Basis(beat[5] as Vector3, TAU * float(beat[4]) * ((1.0 - round) if into else round)), _middle(),
						Vector3(0.0, high, 0.0) if up == Vector3.ZERO else Vector3.ZERO, to_bone)
					pose.pos[b] += up * high
			"nod":
				var u := clampf((at - float(beat[1])) / (float(beat[2]) - float(beat[1])), 0.0, 1.0)
				if u > 0.0 and u < 1.0:
					_turn(pose, b, Basis(X, float(beat[3]) * sin(u * PI)), Vector3.ZERO, Vector3.ZERO, to_bone)
			"part":
				GunRecoil.pose_part(pose, bones, grip + "_", beat[2], at - float(beat[1]))
			"shut":
				# (The part's own "out and home" is at its furthest a quarter of the way through.)
				var held: Array = (beat[3] as Array).duplicate()
				var left := 1.0 - _through(at, beat[1], beat[2])
				held[3] = 1.0
				GunRecoil.pose_part(pose, bones, grip + "_", held, 0.25 + 0.75 * (1.0 - _eased_back(left)))
			"whirl":
				var u := _through(at, beat[1], beat[2])
				if u > 0.0 and u < 1.0:
					if beat[5] is Vector3:   # about its own middle, round `axis` (a drum set across the gun)
						var part: int = bones.get(grip + "_" + str(beat[3]), -1)
						if part >= 0:
							GunRecoil._turn(pose, part, Basis(beat[6] as Vector3, TAU * float(beat[4]) * u), beat[5])
					else:
						GunRecoil.pose_part(pose, bones, grip + "_", [beat[3], "spin", beat[5]], 0.0, 0.0, TAU * float(beat[4]) * u)


## The arms' own part in the flourish (after everything else has posed them): the off
## hand slapping down on the weapon, the fists knocked together.
func pose_arms(pose: RobotPose, bones: Dictionary) -> void:
	if not active():
		return
	for beat in _beats:
		match str(beat[0]):
			"slap":
				var u := clampf((t - float(beat[1])) / (float(beat[2]) - float(beat[1])), 0.0, 1.0)
				if u > 0.0 and u < 1.0:
					# (Up over the first two thirds, down hard in the last.)
					var up := sin(minf(u / 0.66, 1.0) * PI * 0.5) if u < 0.66 else 1.0 - smoothstep(0.0, 1.0, (u - 0.66) / 0.34)
					var arm: int = bones["upper_arm_l"]
					pose.rot[arm] = Quaternion(Vector3.RIGHT, SLAP_LIFT * up) * pose.rot[arm]
			"hands":
				var u := clampf((t - float(beat[1])) / (float(beat[2]) - float(beat[1])), 0.0, 1.0)
				if u > 0.0 and u < 1.0:
					var meet := float(beat[3]) * sin(u * PI)
					var right: int = bones["upper_arm_r"]
					var left: int = bones["upper_arm_l"]
					pose.rot[right] = Quaternion(Vector3.UP, meet) * pose.rot[right]
					pose.rot[left] = Quaternion(Vector3.UP, -meet) * pose.rot[left]


## A spark where the hands are is due this frame (fists knocked together).
func spark_due() -> bool:
	for beat in _beats:
		if str(beat[0]) == "spark" and _crossed(float(beat[1])) and active():
			return true
	return false


## 0..1 between two times, eased in and out.
static func _through(at: float, from: Variant, to: Variant) -> float:
	return smoothstep(0.0, 1.0, clampf((at - float(from)) / (float(to) - float(from)), 0.0, 1.0))


# GunRecoil's "out and home" falls from 1 at a quarter through to 0 at the end along a
# smoothstep: which way through it shows `left` of the part still out.
static func _eased_back(left: float) -> float:
	# smoothstep(u) = 1 - left  ->  u (near enough: three steps of Newton's method)
	var want := 1.0 - clampf(left, 0.0, 1.0)
	var u := want
	for i in 3:
		var f := u * u * (3.0 - 2.0 * u) - want
		var d := 6.0 * u * (1.0 - u)
		if absf(d) < 0.0001:
			break
		u = clampf(u - f / d, 0.0, 1.0)
	return 1.0 - u


## The middle of the weapon, near enough, in its own space: what a tossed one turns about.
func _middle() -> Vector3:
	if _melee:
		var edge: Array = MeleeModel.EDGES.get(weapon, [0.0, 0.3])
		return Vector3(0.0, float(edge[1]) * 0.4, 0.0)
	return Vector3(0.0, 0.03, -0.04)


## Turns the weapon's own bone by `turn` about `pivot` and moves it by `shift` (all in
## the weapon's space; `to_bone` takes that to the bone's).
static func _turn(pose: RobotPose, b: int, turn: Basis, pivot: Vector3, shift: Vector3, to_bone: Basis) -> void:
	var local := (to_bone * turn * to_bone.inverse()).orthonormalized()
	pose.pos[b] += Basis(pose.rot[b]) * (to_bone * (shift + pivot - turn * pivot))
	pose.rot[b] = pose.rot[b] * Quaternion(local)


static func _part_time(part: Array) -> float:
	match str(part[1]):
		"back", "pop", "turn", "hinge", "whip":
			return float(part[3])
	return 0.0
