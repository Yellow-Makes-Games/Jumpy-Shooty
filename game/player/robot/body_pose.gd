class_name BodyPose
extends RefCounted
## Putting a standing body's arms, chest and head where a pose wants them, over
## whatever pose it has: what an emote (Emote) and a victory pose (VictoryPoser) are
## made of.
##
## Places are given in the chest's frame at shoulder height (x right, y up, -z
## forward; the shoulders are about 0.2 m either side of the middle, and an arm reaches
## about half a metre). The right hand is placed by what it holds: [grip, where the
## barrel or blade points, where the gun's top (or the blade's edge) faces], as
## PortraitPoser's holds are. The left hand by where its wrist goes.

## How a weapon is held, for these: {melee, fists, empty, akimbo, shoulder, two_handed}
## (fists: a weapon on each fist, or bare hands; shoulder: too big to dangle from one hand).
static func grip_of(weapon_id: String) -> Dictionary:
	var empty := weapon_id == "none" or weapon_id == "" or not WeaponData.has(weapon_id)
	if empty:
		return {"melee": false, "fists": false, "empty": true, "akimbo": false, "shoulder": false, "two_handed": false}
	var data := WeaponData.by_id(weapon_id)
	var melee := data.is_melee()
	return {"melee": melee, "fists": melee and weapon_id in MeleeModel.BOTH_FISTS, "empty": false, "akimbo": data.is_akimbo(),
		"shoulder": WeaponData.look_of(weapon_id) in (PortraitPoser.SHOULDER_MELEE if melee else PortraitPoser.SHOULDER_GUNS),
		"two_handed": data.two_handed}


## The chest in the model's space: [its rotation, where it is].
static func chest(pose: RobotPose, b: Dictionary) -> Array:
	var rot := pose.rot[b["root"]]
	var at := pose.pos[b["root"]]
	for bone in ["hips", "spine", "chest"]:
		var i: int = b[bone]
		at += rot * pose.pos[i]
		rot = rot * pose.rot[i]
	return [rot, at]


## The body under a pose, `w` of the way: the chest squared up (whichever way a
## weapon's own stance turns it from the way the body faces, back), the spine tipped
## back by `lean` (radians; less than 0 forward), the chest turned `turn` to its left,
## the head tipped back by `chin` and turned `face` to its left.
static func body(pose: RobotPose, b: Dictionary, w: float, lean: float, turn: float, chin: float, face: float = 0.0) -> void:
	if w <= 0.0:
		return
	var chest_bone: int = b["chest"]
	var head: int = b["head"]
	var spine: int = b["spine"]
	var facing: Quaternion = chest(pose, b)[0]
	var ahead := facing * Vector3.FORWARD
	var back := Quaternion(Vector3.UP, -atan2(-ahead.x, -ahead.z) * w)
	var squared := pose.rot[chest_bone] * (facing.inverse() * back * facing)
	pose.rot[head] = (pose.rot[chest_bone].inverse() * squared).inverse() * pose.rot[head]
	pose.rot[chest_bone] = squared
	pose.rot[spine] = Quaternion(Vector3.RIGHT, lean * w) * pose.rot[spine]
	pose.rot[chest_bone] = Quaternion(Vector3.UP, turn * w) * pose.rot[chest_bone]
	pose.rot[head] = Quaternion(Vector3.UP, (face - turn) * w) * Quaternion(Vector3.RIGHT, (chin - lean) * w) * pose.rot[head]


## The right hand with what it holds, where a key says, the elbow toward `elbow`: a gun
## by its grip, a blade or a hammer by its handle, a fist (`grip`: see grip_of).
static func right(pose: RobotPose, rig: RobotRig, grip: Dictionary, w: float, at_grip: Vector3, along: Vector3, face: Vector3, elbow: Vector3) -> void:
	if w <= 0.0:
		return
	var b := rig.bones
	var c := chest(pose, b)
	var rot: Quaternion = c[0]
	var at: Vector3 = c[1]
	var frame := Basis(rot)
	var origin := at + rot * Vector3(0.0, pose.pos[b["upper_arm_r"]].y, 0.0)
	var grip_bone: int = b["pistol"]
	if grip.melee or grip.empty:
		# As MeleeSwing holds one: the handle along +Y, the edge leading.
		var held := MeleeSwing._weapon_basis([at_grip, along, face])
		var hand_rot := (frame * held * MeleeModel.HOLD.inverse()).get_rotation_quaternion()
		var palm: Vector3 = rig.rest_pos[grip_bone]
		MeleeSwing._reach(pose, rig, rot, at, "r", origin + frame * at_grip - hand_rot * palm, hand_rot, frame * elbow, w)
		pose.rot[grip_bone] = pose.rot[grip_bone].slerp(Quaternion.IDENTITY, w)
		Hands.set_hand(pose, rig, "fist" if grip.fists or grip.empty else "handle", w, false)
		return
	# A gun (as PortraitPoser lays one): -z down the barrel, +y its top.
	var barrel := along.normalized()
	var top := (face - barrel * face.dot(barrel)).normalized()
	var gun := frame * Basis(top.cross(-barrel), top, -barrel)
	var hand_rot := (gun * ReloadFx.GUN_REST.inverse()).get_rotation_quaternion() * pose.rot[grip_bone].inverse()
	var want: Vector3 = origin + frame * at_grip - hand_rot * pose.pos[grip_bone]
	MeleeSwing._reach(pose, rig, rot, at, "r", want, hand_rot, frame * elbow, w)


## The left hand (its wrist) at `where`, the elbow toward `elbow`, the hand in line with
## the forearm (turned `roll` radians about it) and held `shape` (unless it has a gun,
## or a weapon on its fist, of its own).
static func left(pose: RobotPose, rig: RobotRig, grip: Dictionary, w: float, where: Vector3, elbow: Vector3, shape: String, roll: float = 0.0) -> void:
	if w <= 0.0:
		return
	var b := rig.bones
	var c := chest(pose, b)
	var rot: Quaternion = c[0]
	var at: Vector3 = c[1]
	var frame := Basis(rot)
	var want := at + rot * Vector3(0.0, pose.pos[b["upper_arm_l"]].y, 0.0) + frame * where
	var hand: int = b["hand_l"]
	var before := pose.rot[hand]
	var to := want - (at + rot * pose.pos[b["upper_arm_l"]])
	var straight := Quaternion(Vector3.UP, -to.normalized()) if to.length_squared() > 0.0001 and to.normalized().dot(Vector3.UP) < 0.999 else Quaternion.IDENTITY
	MeleeSwing._reach(pose, rig, rot, at, "l", want, straight, frame * elbow, w)
	pose.rot[hand] = before.slerp(Quaternion(Vector3.UP, roll), w)
	if not grip.akimbo and not grip.fists:
		Hands.set_hand(pose, rig, shape, w, true)
	elif grip.fists and b.has("pistol_l"):
		pose.rot[b["pistol_l"]] = pose.rot[b["pistol_l"]].slerp(Quaternion.IDENTITY, w)


## One arm hanging at its side: straight down from the shoulder whichever way the chest
## leans, a little out from the body, the elbow easy. relax: the hand lets go as well.
static func hang(pose: RobotPose, rig: RobotRig, w: float, left_arm: bool, relax: bool) -> void:
	if w <= 0.0:
		return
	var b := rig.bones
	var side := "l" if left_arm else "r"
	var out := -1.0 if left_arm else 1.0
	var chest_rot: Quaternion = chest(pose, b)[0]
	var down := chest_rot.inverse() * Vector3.DOWN
	var hung := Quaternion(Vector3.DOWN, down) if down.dot(Vector3.DOWN) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	var up: int = b["upper_arm_" + side]
	var fore: int = b["forearm_" + side]
	var hand: int = b["hand_" + side]
	pose.rot[up] = pose.rot[up].slerp(hung * Quaternion(Vector3.BACK, 0.13 * out) * Quaternion(Vector3.RIGHT, -0.06), w)
	pose.rot[fore] = pose.rot[fore].slerp(Quaternion(Vector3.RIGHT, 0.3), w)
	pose.rot[hand] = pose.rot[hand].slerp(Quaternion(Vector3.RIGHT, 0.12) * Quaternion(Vector3.UP, 0.25 * out), w)
	if relax:
		Hands.set_hand(pose, rig, "relaxed", w, left_arm)
