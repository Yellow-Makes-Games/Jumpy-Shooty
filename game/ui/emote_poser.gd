class_name EmotePoser
extends PortraitPoser
## The character on a portrait's stage (RobotPreview, staged) trying things on for the
## Emotes page: an emote (Emote), played over and over with a pause between; a victory
## pose (VictoryPoser's), struck again from the top; or nothing, just standing as the
## game stands it.
##
##   var poser := EmotePoser.new(robot, fx)
##   preview.set_poser(poser)
##   poser.show_emote("wave")      # or show_pose(Podium.RAISE), or show_nothing()
##   robot.rotation.y = poser.spin()   # (a victory pose can turn it right round)

const GAP := 0.7             ## seconds between one playing of an emote and the next
const AIM := Vector3(0.45, 0.12, -1.0)   ## where "point" points, in the character's own space

var emote := Emote.new()
var showing := ""            ## the emote it is playing over and over, or ""

var _pose: VictoryPoser      # a victory pose being struck, or null
var _gap := 0.0


func show_emote(id: String) -> void:
	_pose = null
	if id == showing:
		return
	showing = id if Emote.valid(id) else ""
	emote.stop()
	_gap = 0.15


func show_pose(kind: int) -> void:
	showing = ""
	emote.stop()
	if _pose != null and _pose.kind == kind:
		return
	_pose = VictoryPoser.new(robot, kind)
	_pose.repeats = true


func show_nothing() -> void:
	showing = ""
	_pose = null
	emote.stop()


## How far a victory pose has it turned from the way it faces (radians).
func spin() -> float:
	return _pose.spin if _pose != null else 0.0


func update(delta: float) -> void:
	if _pose != null:
		_pose.update(delta)
		return
	if showing != "" and not emote.active() and emote.w <= 0.0:
		_gap -= delta
		if _gap <= 0.0:
			_gap = GAP
			emote.play(showing, (robot.global_transform.basis if robot.is_inside_tree() else Basis.IDENTITY) * AIM)
	elif showing == "" or emote.id != showing:
		emote.stop()
	emote.update(delta)
	animator.emote = emote
	_inp.flags = RobotAnimInput.make_flags(false, false, false, 0, 0)
	animator.update(delta, _inp, robot.global_transform if robot.is_inside_tree() else Transform3D.IDENTITY)
	if _empty:   # nothing to hold: the arms hang, but for what an emote does with them
		var bare: RobotPose = animator._pose
		var w := 1.0 - smoothstep(0.0, 1.0, emote.w)
		BodyPose.hang(bare, animator.rig, w, true, true)
		BodyPose.hang(bare, animator.rig, w, false, true)
		bare.apply(robot.skeleton)
		robot.settle_sway()
