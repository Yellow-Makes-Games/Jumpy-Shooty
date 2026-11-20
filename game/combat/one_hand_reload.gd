class_name OneHandReload
extends RefCounted
## Reloading a gun with one hand, for when the other is busy: on the grappling hook's
## rope (the left arm is up it) and on a wall run. Looks only: the reload takes as long
## as it always does and loads what it always loads.
##
## The gun arm does it all: it cocks the gun up and flicks it to throw the empty out,
## brings it down and slams it onto a fresh one at the belt, and snaps it back up to the
## hold with its slide or charging handle going home. A gun fed a round at a time dips to
## the belt and back for each round; one that overheats is held out to the side to cool.
##
## One reload per family of gun (WeaponData.GROUPS: sidearms, shotguns, rifles, marksman,
## explosives), not one per gun: KINDS has each family's arm poses. What makes it each
## gun's own is its timing, taken from the gun's own reload (ReloadFx.GUNS: when the
## spent cell leaves and when the new one is home), so the cell flies off, the gun goes
## dark and it surges back at the moments it always did, and its own working part
## (GunRecoil.PARTS).
##
## RobotAnimator lays it over the gun arm (lay) in place of the reload clip, ViewModel
## moves your own arms by it in first person (view), and both leave the gun without its
## cell from the flick to the slam (cell_out).

## An arm's pose: [the way the upper arm points, in the chest's space (x right, y up, -z
## forward); how far the elbow is bent (radians); the wrist, Vector3(bent up, rolled out,
## turned out) in radians; how far down at the belt this is, 0..1].
##   cock: the gun brought up and rolled, ready to throw the empty out
##   flick: ...and thrown
##   belt: down at the belt, over the fresh one       slam: driven onto it
##   feed: a round at a time: where the gun waits between rounds
##   vent: overheated: held out to the side to cool
const KINDS := [
	{   # Sidearms: quick, all in the wrist
		"cock": [Vector3(0.30, -0.62, -0.72), 1.5, Vector3(0.2, -0.7, 0.0), 0.0],
		"flick": [Vector3(0.42, -0.70, -0.58), 1.15, Vector3(-0.5, 0.9, 0.0), 0.0],
		"belt": [Vector3(0.10, -0.97, 0.22), 0.95, Vector3(0.6, 0.1, 0.0), 1.0],
		"slam": [Vector3(0.10, -0.98, 0.18), 0.75, Vector3(0.6, 0.1, 0.0), 1.0],
		"feed": [Vector3(0.24, -0.90, 0.05), 1.45, Vector3(0.15, 0.5, 0.0), 0.7],
		"vent": [Vector3(0.50, -0.82, -0.25), 0.8, Vector3(-0.3, 0.9, 0.0), 0.5],
	},
	{   # Shotguns: the gun rolled onto its side, low
		"cock": [Vector3(0.28, -0.80, -0.52), 1.3, Vector3(0.25, -0.5, 0.0), 0.0],
		"flick": [Vector3(0.40, -0.80, -0.44), 1.05, Vector3(-0.35, 0.7, 0.0), 0.0],
		"belt": [Vector3(0.13, -0.95, 0.28), 0.95, Vector3(0.6, 0.25, 0.0), 1.0],
		"slam": [Vector3(0.13, -0.97, 0.22), 0.75, Vector3(0.6, 0.25, 0.0), 1.0],
		"feed": [Vector3(0.26, -0.90, 0.12), 1.4, Vector3(0.2, 0.7, 0.0), 0.7],
		"vent": [Vector3(0.48, -0.84, -0.2), 0.8, Vector3(-0.2, 0.8, 0.0), 0.5],
	},
	{   # Rifles: the stock clamped under the arm
		"cock": [Vector3(0.26, -0.80, -0.54), 1.35, Vector3(0.3, -0.55, 0.0), 0.0],
		"flick": [Vector3(0.38, -0.82, -0.42), 1.1, Vector3(-0.3, 0.75, 0.0), 0.0],
		"belt": [Vector3(0.13, -0.95, 0.28), 0.95, Vector3(0.6, 0.2, 0.0), 1.0],
		"slam": [Vector3(0.13, -0.97, 0.22), 0.75, Vector3(0.6, 0.2, 0.0), 1.0],
		"feed": [Vector3(0.26, -0.90, 0.12), 1.4, Vector3(0.2, 0.6, 0.0), 0.7],
		"vent": [Vector3(0.48, -0.84, -0.2), 0.8, Vector3(-0.2, 0.8, 0.0), 0.5],
	},
	{   # Marksman: long and slow, the muzzle swung high
		"cock": [Vector3(0.24, -0.84, -0.48), 1.55, Vector3(0.35, -0.45, 0.0), 0.0],
		"flick": [Vector3(0.36, -0.84, -0.40), 1.25, Vector3(-0.2, 0.6, 0.0), 0.0],
		"belt": [Vector3(0.13, -0.95, 0.28), 1.0, Vector3(0.75, 0.2, 0.0), 1.0],
		"slam": [Vector3(0.13, -0.97, 0.22), 0.8, Vector3(0.75, 0.2, 0.0), 1.0],
		"feed": [Vector3(0.26, -0.90, 0.12), 1.5, Vector3(0.3, 0.6, 0.0), 0.7],
		"vent": [Vector3(0.48, -0.84, -0.2), 0.9, Vector3(-0.1, 0.8, 0.0), 0.5],
	},
	{   # Explosives: tipped to empty it, then stood on the hip, muzzle up
		"cock": [Vector3(0.30, -0.82, -0.48), 0.9, Vector3(-0.3, -0.3, 0.0), 0.0],
		"flick": [Vector3(0.36, -0.84, -0.40), 0.7, Vector3(-0.7, 0.3, 0.0), 0.0],
		"belt": [Vector3(0.26, -0.92, 0.28), 1.75, Vector3(0.45, 0.1, 0.0), 1.0],
		"slam": [Vector3(0.26, -0.95, 0.20), 1.6, Vector3(0.35, 0.1, 0.0), 1.0],
		"feed": [Vector3(0.28, -0.90, 0.10), 1.6, Vector3(0.4, 0.3, 0.0), 0.7],
		"vent": [Vector3(0.48, -0.84, -0.2), 0.8, Vector3(-0.2, 0.6, 0.0), 0.5],
	},
]
const RACK := 0.12           ## the slide (or charging handle) goes this long after the slam...
const LONG := 0.6            ## ...or, in a reload with this long still to go after the slam, once the gun is back up
const CATCH_UP := 0.5        ## an akimbo left gun that waited: its own quick trip to the belt takes this long
## Your own arms in first person: how far the whole view goes down to the belt (metres),
## tips its muzzle up there, rolls for the flick, and drops again on the slam.
const VIEW_DOWN := 0.3
const VIEW_TIP := 0.35
const VIEW_ROLL := 0.3
const VIEW_SLAM := 0.035


## A gun's family (an index into KINDS).
static func kind_of(weapon: String) -> Dictionary:
	return KINDS[clampi(WeaponData.group_of(weapon), 0, KINDS.size() - 1)]


## When the gun's spent cell leaves and when the new one is home, in a reload `length`
## seconds long: [eject (-1: nothing leaves it), seat, overheated (no reload at all),
## when its slide or charging handle is worked, when the gun is back up (LONG or more
## after the slam: it is brought up early and held ready until then; else -1)].
static func beats(weapon: String, length: float, per_round: bool) -> Array:
	var g: Dictionary = ReloadFx.GUNS.get(weapon, {})
	var seat := clampf(float(g.get("seat", length * 0.6)), 0.1, maxf(length - 0.06, 0.11))
	if g.has("heat"):
		return [-1.0, seat, true, -1.0, -1.0]
	if per_round:
		return [-1.0, seat, false, -1.0, -1.0]
	var from: float = float(g.eject) if g.has("eject") else (float((g.hide as Array)[0]) if g.has("hide") else seat * 0.3)
	var left := length - seat - 0.07
	if left < LONG:
		return [clampf(from, 0.08, maxf(seat - 0.2, 0.09)), seat, false, seat + RACK, -1.0]
	var up := seat + 0.07 + minf(left * 0.4, 0.42)
	return [clampf(from, 0.08, maxf(seat - 0.2, 0.09)), seat, false, lerpf(up, length - 0.28, 0.4), up]


## The reload as a row of poses to pass through: [[seconds in, a pose of KINDS ("": the hold)], ...].
static func keys(weapon: String, length: float, per_round: bool) -> Array:
	var at := beats(weapon, length, per_round)
	var eject: float = at[0]
	var seat: float = at[1]
	if at[2]:
		var hot: float = float(ReloadFx.GUNS[weapon].heat)
		return [[0.0, ""], [hot + 0.14, "vent"], [maxf(seat - 0.12, hot + 0.2), "vent"], [minf(seat + 0.16, maxf(length, seat + 0.05)), ""]]
	if per_round:
		return [[0.0, "feed"], [maxf(seat - 0.08, 0.03), "belt"], [seat, "slam"], [seat + 0.07, "belt"], [maxf(length, seat + 0.15), "feed"]]
	var row := [[0.0, ""], [maxf(eject - 0.07, 0.03), "cock"], [eject + 0.03, "flick"], [maxf(seat - 0.09, eject + 0.12), "belt"], [seat, "slam"],
		[seat + 0.07, "belt"]]
	if float(at[4]) < 0.0:
		return row + [[maxf(minf(seat + 0.34, length - 0.02), seat + 0.16), ""]]
	# A long reload: up again, held ready while its handle is worked, and back to the hold at the end.
	return row + [[float(at[4]), "cock"], [length - 0.28, "cock"], [length - 0.04, ""]]


## Where the gun arm is `t` seconds into the reload: {dir, elbow, wrist (as KINDS has
## them), w: how much of it shows (0: at the hold), low: how far down at the belt, 0..1}.
static func at(weapon: String, t: float, length: float, per_round: bool) -> Dictionary:
	return _along(keys(weapon, length, per_round), kind_of(weapon), t)


static func _along(row: Array, kind: Dictionary, t: float) -> Dictionary:
	var i := 0
	while i < row.size() - 2 and t >= float(row[i + 1][0]):
		i += 1
	var from: Array = row[i]
	var to: Array = row[i + 1]
	var u := smoothstep(0.0, 1.0, clampf((t - float(from[0])) / maxf(float(to[0]) - float(from[0]), 0.001), 0.0, 1.0))
	var a: Array = kind.get(str(from[1]), [])
	var b: Array = kind.get(str(to[1]), [])
	if a.is_empty() and b.is_empty():
		return {"dir": Vector3.DOWN, "elbow": 0.0, "wrist": Vector3.ZERO, "w": 0.0, "low": 0.0}
	if a.is_empty():
		return {"dir": b[0], "elbow": b[1], "wrist": b[2], "w": u, "low": float(b[3]) * u}
	if b.is_empty():
		return {"dir": a[0], "elbow": a[1], "wrist": a[2], "w": 1.0 - u, "low": float(a[3]) * (1.0 - u)}
	return {"dir": (a[0] as Vector3).lerp(b[0], u), "elbow": lerpf(a[1], b[1], u), "wrist": (a[2] as Vector3).lerp(b[2], u),
		"w": 1.0, "low": lerpf(a[3], b[3], u)}


## How far down at the belt the gun is, 0..1 (the animator stops lifting the arm to the aim by this much).
static func low(weapon: String, t: float, length: float, per_round: bool) -> float:
	return float(at(weapon, t, length, per_round).low)


## The gun's own cell is out of it: from the flick until the slam.
static func cell_out(weapon: String, t: float, length: float, per_round: bool) -> bool:
	var b := beats(weapon, length, per_round)
	return float(b[0]) >= 0.0 and t >= float(b[0]) and t < float(b[1])


## The gun arm, `t` seconds into a reload `length` long, `w` of the way from how `pose`
## has it. left: an akimbo left gun (mirrored). The gun's working part goes after the slam.
static func lay(pose: RobotPose, b: Dictionary, weapon: String, t: float, length: float, per_round: bool, w: float, left: bool = false) -> void:
	_lay(pose, b, weapon, at(weapon, t, length, per_round), w, left)
	work_part(pose, b, weapon, t, length, per_round, left)


## The gun's slide or charging handle alone, worked after the slam (your own arms in first
## person, which move as a whole: see view).
static func work_part(pose: RobotPose, b: Dictionary, weapon: String, t: float, length: float, per_round: bool, left: bool = false) -> void:
	var rack := float(beats(weapon, length, per_round)[3])
	if rack >= 0.0:
		_rack(pose, b, weapon, t - rack, left)


## An akimbo left gun that waited (its hand was on the rope): its own quick trip to the
## belt, `t` seconds in (CATCH_UP long).
static func lay_catch_up(pose: RobotPose, b: Dictionary, weapon: String, t: float, w: float) -> void:
	var row := [[0.0, ""], [0.17, "belt"], [0.24, "slam"], [0.31, "belt"], [CATCH_UP, ""]]
	_lay(pose, b, weapon, _along(row, kind_of(weapon), t), w, true)
	_rack(pose, b, weapon, t - 0.24 - RACK * 0.5, true)


static func _lay(pose: RobotPose, b: Dictionary, weapon: String, p: Dictionary, w: float, left: bool) -> void:
	var k := w * float(p.w)
	if k <= 0.0:
		return
	var side := "_l" if left else "_r"
	var s := -1.0 if left else 1.0
	var dir: Vector3 = p.dir
	dir.x *= s
	dir = dir.normalized()
	var up: int = b["upper_arm" + side]
	var hung := Quaternion(Vector3.DOWN, dir) if dir.dot(Vector3.DOWN) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	pose.rot[up] = pose.rot[up].slerp(hung, k)
	var fore: int = b["forearm" + side]
	pose.rot[fore] = pose.rot[fore].slerp(Quaternion(Vector3.RIGHT, float(p.elbow)), k)
	var wrist: Vector3 = p.wrist
	var hand: int = b["hand" + side]
	pose.rot[hand] = pose.rot[hand].slerp(Quaternion(Vector3.RIGHT, wrist.x) * Quaternion(Vector3.UP, wrist.y * s) * Quaternion(Vector3.BACK, wrist.z * s), k)


# The gun's slide or charging handle, `t` seconds after it starts back (a gun that has one).
static func _rack(pose: RobotPose, b: Dictionary, weapon: String, t: float, left: bool) -> void:
	if t < 0.0:
		return
	for part in GunRecoil.PARTS.get(weapon, []):
		if str(part[1]) == "back":
			var slow: Array = (part as Array).duplicate()
			slow[3] = maxf(float(part[3]), 0.16)   # (worked by hand: slower than a shot throws it)
			GunRecoil.pose_part(pose, b, "pistol_l_" if left else "pistol_", slow, t)
			return


## Your own arms in first person: where the whole view model goes, [metres (right, up,
## back), radians (muzzle up, aside, roll)]. Down to the belt (out of sight at the bottom
## of the view) and back, never up.
static func view(weapon: String, t: float, length: float, per_round: bool) -> Array:
	var p := at(weapon, t, length, per_round)
	var b := beats(weapon, length, per_round)
	var down := float(p.low) * smoothstep(0.0, 1.0, float(p.w)) if float(p.w) < 1.0 else float(p.low)
	var roll := float((p.wrist as Vector3).y) * float(p.w) * (1.0 - float(p.low))
	var since := t - float(b[1])
	var slam := sin(clampf(since / 0.14, 0.0, 1.0) * PI) if since >= 0.0 else 0.0
	return [Vector3(0.0, -VIEW_DOWN * down - VIEW_SLAM * slam, 0.03 * down),
		Vector3(VIEW_TIP * down, 0.0, -VIEW_ROLL * clampf(roll, -1.0, 1.0))]
