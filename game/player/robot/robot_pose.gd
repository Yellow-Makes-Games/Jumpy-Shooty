class_name RobotPose
extends RefCounted
## One pose of the robot's skeleton: a rotation and a position for every bone
## (relative to its parent). Poses are blended together by RobotAnimator.

var rot: Array[Quaternion] = []
var pos: Array[Vector3] = []


func copy(from: RobotPose) -> void:
	for i in rot.size():
		rot[i] = from.rot[i]
		pos[i] = from.pos[i]


## Move every bone a fraction w of the way toward `other`.
func blend(other: RobotPose, w: float) -> void:
	if w <= 0.0:
		return
	if w >= 1.0:
		copy(other)
		return
	for i in rot.size():
		rot[i] = rot[i].slerp(other.rot[i], w)
		pos[i] = pos[i].lerp(other.pos[i], w)


## The same, for some of the bones only.
func blend_bones(other: RobotPose, w: float, which: PackedInt32Array) -> void:
	if w <= 0.0:
		return
	for i in which:
		rot[i] = rot[i].slerp(other.rot[i], w)
		pos[i] = pos[i].lerp(other.pos[i], w)


func apply(skeleton: Skeleton3D) -> void:
	for i in rot.size():
		skeleton.set_bone_pose_rotation(i, rot[i])
		skeleton.set_bone_pose_position(i, pos[i])
