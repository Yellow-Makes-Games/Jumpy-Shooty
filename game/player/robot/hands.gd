class_name Hands
extends RefCounted
## The robots' fingers and thumbs. Every clip already holds them (the right hand round a
## gun's grip, the left under a long gun or relaxed: tools/robot/rig.py, HANDS); this is
## for what the clips cannot know: a blade's handle in the fist, a fist with nothing in it.
## Each hand pose is also in the model files as a clip one frame long ("hand_handle",
## "hand_fist"...: tools/robot/animations.py), and set() blends a hand to one.

const LEFT := ["index_l", "index_l2", "fingers_l", "fingers_l2", "thumb_l", "thumb_l2"]
const RIGHT := ["index_r", "index_r2", "fingers_r", "fingers_r2", "thumb_r", "thumb_r2"]

static var _poses := {}   # [rig, pose name] -> RobotPose
static var _bones := {}   # [rig, left?] -> the hand's bones


## Holds one hand of `pose` the way `how` says ("open", "flat", "relaxed", "fist", "gun",
## "trigger", "handle", "support", "pinch"), `w` of the way from how it is held now.
static func set_hand(pose: RobotPose, rig: RobotRig, how: String, w: float, left: bool) -> void:
	if w <= 0.0 or not rig.has_clip("hand_" + how):
		return
	var key := [rig, how]
	if not _poses.has(key):
		var p := rig.new_pose()
		rig.sample(p, "hand_" + how, 0.0)
		_poses[key] = p
	var side := [rig, left]
	if not _bones.has(side):
		var which := PackedInt32Array()
		for n in (LEFT if left else RIGHT):
			if rig.bones.has(n):
				which.append(rig.bones[n])
		_bones[side] = which
	pose.blend_bones(_poses[key], w, _bones[side])
