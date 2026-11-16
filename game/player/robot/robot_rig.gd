class_name RobotRig
extends RefCounted
## A robot model file (.glb) opened once and shared by every robot that uses it:
## the bone list and the animation clips, indexed so poses can be sampled quickly.
##
## The model files are made by tools/robot/build.py. A replacement model made in
## Blender works too, as long as it keeps the same bone and clip names.

class Clip:
	var anim: Animation
	var length := 0.0
	var rot := PackedInt32Array()   ## track index per bone, or -1
	var pos := PackedInt32Array()

static var _cache := {}

var scene: PackedScene
var bone_names: PackedStringArray
var bones := {}                     ## bone name -> index
var rest_pos: Array[Vector3] = []
var rest_rot: Array[Quaternion] = []
var clips := {}                     ## clip name -> Clip


static func open(path: String) -> RobotRig:
	if not _cache.has(path):
		var rig := RobotRig.new()
		rig._load(path)
		_cache[path] = rig
	return _cache[path]


func _load(path: String) -> void:
	scene = load(path)
	var node := scene.instantiate()
	var skeleton: Skeleton3D = node.find_child("Skeleton3D", true, false)
	for i in skeleton.get_bone_count():
		bone_names.append(skeleton.get_bone_name(i))
		bones[skeleton.get_bone_name(i)] = i
		var rest := skeleton.get_bone_rest(i)
		rest_pos.append(rest.origin)
		rest_rot.append(rest.basis.get_rotation_quaternion())
	var player: AnimationPlayer = node.find_child("AnimationPlayer", true, false)
	if player:
		for clip_name in player.get_animation_list():
			var anim := player.get_animation(clip_name)
			var clip := Clip.new()
			clip.anim = anim
			clip.length = anim.length
			clip.rot.resize(bone_names.size())
			clip.rot.fill(-1)
			clip.pos.resize(bone_names.size())
			clip.pos.fill(-1)
			for t in anim.get_track_count():
				var bone_path := anim.track_get_path(t)
				if bone_path.get_subname_count() == 0:
					continue
				var index: int = bones.get(String(bone_path.get_subname(0)), -1)
				if index < 0:
					continue
				match anim.track_get_type(t):
					Animation.TYPE_ROTATION_3D: clip.rot[index] = t
					Animation.TYPE_POSITION_3D: clip.pos[index] = t
			clips[clip_name] = clip
	node.free()


func has_clip(clip_name: String) -> bool:
	return clips.has(clip_name)


func length(clip_name: String) -> float:
	return (clips[clip_name] as Clip).length


## Fills `pose` with the clip at time t (seconds, clamped to the clip).
func sample(pose: RobotPose, clip_name: String, t: float) -> void:
	var clip: Clip = clips[clip_name]
	var anim := clip.anim
	t = clampf(t, 0.0, clip.length)
	for i in bone_names.size():
		var rt := clip.rot[i]
		pose.rot[i] = anim.rotation_track_interpolate(rt, t) if rt >= 0 else rest_rot[i]
		var pt := clip.pos[i]
		pose.pos[i] = anim.position_track_interpolate(pt, t) if pt >= 0 else rest_pos[i]


func new_pose() -> RobotPose:
	var pose := RobotPose.new()
	pose.rot = rest_rot.duplicate()
	pose.pos = rest_pos.duplicate()
	return pose
