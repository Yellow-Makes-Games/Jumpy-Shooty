extends SceneTree
## Headless checks on what a hit does to the body that takes it (HitReaction): looks only.
## Run: godot --headless --path . --script tests/hit_reaction_test.gd
##
## The upper body goes the way the blow was travelling (back from the front, to its right
## from the left, forward from behind); a bigger hit throws it further; a headshot snaps
## the head further than a body hit does; a melee blow folds the body and a heavy one
## throws the arms wide; only a big hit on a body standing still buckles the knees; fast
## hits never throw it past its limits; the camera's knock is small, never past its
## limit; a second later nothing is left of any of it; and the pose it makes moves the
## spine, chest and head and never the hips or the root.

const DT := 1.0 / 60.0
const FRONT := Vector3(0, 0, 1)    # travelling to the body's back: shot from the front
const LEFT := Vector3(1, 0, 0)     # travelling to its right: shot from its left
const BEHIND := Vector3(0, 0, -1)

var _ok := true


func _init() -> void:
	# Which way it goes.
	var front := _peak(FRONT, 30.0)
	_check(front.lean.y > 0.05 and absf(front.lean.x) < 0.01, "shot from the front: rocked back (%.3f)" % front.lean.y)
	var left := _peak(LEFT, 30.0)
	_check(left.lean.x > 0.05 and absf(left.lean.y) < 0.01, "shot from the left: thrown to its right (%.3f)" % left.lean.x)
	var behind := _peak(BEHIND, 30.0)
	_check(behind.lean.y < -0.05, "shot from behind: lurches forward (%.3f)" % behind.lean.y)
	# How far: by the damage.
	var small := _peak(FRONT, 8.0)
	var big := _peak(FRONT, 80.0)
	_check(small.lean.y > 0.0 and small.lean.y < front.lean.y and front.lean.y < big.lean.y,
		"a bigger hit throws the body further (%.3f, %.3f, %.3f)" % [small.lean.y, front.lean.y, big.lean.y])
	_check(absf(small.twist) > 0.02, "a graze still twitches a shoulder (%.3f)" % small.twist)
	_check(HitReaction.strength(1000.0) <= 1.3 and HitReaction.strength(0.0) > 0.0, "strength has a floor and a ceiling")
	# The head.
	var head := _peak(FRONT, 30.0, true)
	_check(head.head.y > front.head.y * 2.0, "a headshot snaps the head back (%.3f, a body hit %.3f)" % [head.head.y, front.head.y])
	var r := HitReaction.new()
	r.hit(FRONT, 30.0, true)
	_step(r, 0.3)
	_check(r.head.length() < HitReaction.HEAD * 0.2, "...and it is back in about a quarter of a second (%.3f left)" % r.head.length())
	# Melee.
	var blow := _peak(FRONT, 40.0, false, true)
	_check(blow.fold > 0.5 and front.fold == 0.0, "a melee blow folds the body round it (%.2f)" % blow.fold)
	_check(blow.wide < 0.05, "...without throwing the arms out")
	var heavy := _peak(FRONT, 80.0, false, true, true)
	_check(heavy.wide > 0.6, "a heavy one throws the arms wide (%.2f)" % heavy.wide)
	# The knees.
	_check(_peak(FRONT, 80.0, false, false, false, true).buckle > 0.5, "a big hit buckles the knees of a body standing still")
	_check(_peak(FRONT, 30.0, false, false, false, true).buckle == 0.0, "a middling one does not")
	_check(_peak(FRONT, 80.0).buckle == 0.0, "nor a big one on a body that is moving or in the air")
	# A stream of hits: a shudder, within limits.
	r = HitReaction.new()
	var most := 0.0
	var cam := 0.0
	for i in 60:
		r.hit(FRONT.rotated(Vector3.UP, i * 0.3), 100.0, i % 3 == 0, i % 2 == 0, true, true)
		_step(r, 0.03)
		most = maxf(most, r.lean.length())
		cam = maxf(cam, r.camera().length())
		_check(absf(r.twist) <= HitReaction.MOST_TWIST + 0.001 and r.head.length() <= HitReaction.MOST_HEAD + 0.001, "hit %d: the turn and the head within limits" % i, true)
	_check(most > 0.1 and most <= HitReaction.MOST_LEAN + 0.001, "sixty big hits in two seconds: thrown no further than the limit (%.3f)" % most)
	_check(cam > 0.0 and cam <= HitReaction.CAM_MAX + 0.00001, "...and the camera's knock no further than its own (%.4f)" % cam)
	_step(r, 1.5)
	_check(not r.busy() and r.camera().length() < 0.0002 and r.drop() < 0.0005, "a second and a half after the last, nothing is left of it")
	# The camera: a little, the way the blow went, and less than a gun's kick.
	r = HitReaction.new()
	r.hit(FRONT, 30.0)
	var knock := 0.0
	for i in 10:
		_step(r, DT)
		knock = maxf(knock, r.camera().x)
	_check(knock > 0.001 and knock < GunRecoil.CAM_MAX * 0.5, "the camera is knocked up a little by a hit from the front (%.4f)" % knock)
	_step(r, 0.6)
	_check(r.camera().length() < 0.0002, "...and is back where it was")
	# The pose: the upper body alone.
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	var pose := rig.new_pose()
	rig.sample(pose, "idle", 0.0)
	var was := rig.new_pose()
	was.copy(pose)
	r = HitReaction.new()
	r.hit(FRONT + LEFT, 80.0, true, true, true, true)
	_step(r, 0.08)
	r.pose_body(pose, rig.bones, 1.0, true)
	for moved in ["spine", "chest", "head", "upper_arm_l", "upper_arm_r", "thigh_l", "thigh_r"]:
		_check(not pose.rot[rig.bones[moved]].is_equal_approx(was.rot[rig.bones[moved]]), "the %s is thrown" % moved)
	for kept in ["root", "hips"]:
		_check(pose.rot[rig.bones[kept]].is_equal_approx(was.rot[rig.bones[kept]]) and pose.pos[rig.bones[kept]].is_equal_approx(was.pos[rig.bones[kept]]),
			"the %s stays where it is" % kept)
	pose.copy(was)
	r.pose_body(pose, rig.bones, 0.0, false)
	_check(pose.rot[rig.bones["chest"]].is_equal_approx(was.rot[rig.bones["chest"]]), "none of it shows on your own body in first person")
	# What kind of blow the host says a hit was.
	_check(HitReaction.kind_of("", {"with": "pistol"}) == HitReaction.SHOT, "a bullet is a shot")
	_check(HitReaction.kind_of("", {"with": "rocket_launcher", "blast": 0.5}) == HitReaction.BLAST, "an explosion is a blast")
	_check(HitReaction.kind_of("kick", {"with": "kick"}) == HitReaction.MELEE, "a kick is a blow")
	_check(HitReaction.kind_of("kick", {"with": "flying_kick"}) == HitReaction.HEAVY, "a flying kick is a heavy one")
	_check(HitReaction.kind_of("", {"with": WeaponData.MELEE[0]}) == HitReaction.MELEE, "a melee weapon's is a blow")
	_check(HitReaction.kind_of("", {"with": WeaponData.MELEE[0], "heavy": true}) == HitReaction.HEAVY, "...a heavy one wound all the way up")
	_check(HitReaction.kind_of("slam", {"with": ""}) == HitReaction.CRASH, "a wall is a crash")
	print("hit_reaction_test: %s" % ("OK" if _ok else "FAILED"))
	quit(0 if _ok else 1)


# The furthest everything gets in the half second after one hit.
func _peak(way: Vector3, damage: float, headshot: bool = false, blunt: bool = false, heavy: bool = false, braced: bool = false) -> Dictionary:
	var r := HitReaction.new()
	r.hit(way, damage, headshot, blunt, heavy, braced)
	var out := {"lean": Vector2.ZERO, "twist": 0.0, "head": Vector2.ZERO, "fold": 0.0, "wide": 0.0, "buckle": 0.0}
	for i in 30:
		_step(r, DT)
		if r.lean.length() > (out.lean as Vector2).length():
			out.lean = r.lean
		if r.head.length() > (out.head as Vector2).length():
			out.head = r.head
		if absf(r.twist) > absf(out.twist):
			out.twist = r.twist
		out.fold = maxf(out.fold, r.fold)
		out.wide = maxf(out.wide, r.wide)
		out.buckle = maxf(out.buckle, r.buckle)
	return out


func _step(r: HitReaction, seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		r.update(minf(DT, left))
		left -= DT


func _check(ok: bool, what: String, quiet: bool = false) -> void:
	if not ok:
		_ok = false
		print("FAIL  ", what)
	elif not quiet:
		print("ok    ", what)
