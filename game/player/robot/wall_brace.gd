class_name WallBrace
extends RefCounted
## A body on the grappling hook's rope, up against a wall: it puts its feet on the wall and
## braces there, knees bent, hips out, in place of dangling into it (see RopeSwing for how
## it hangs otherwise). Looks only: nothing here moves the player.
##
##  - It needs a tight rope and a wall (not a ceiling, not the underside of something)
##    within REACH of the body's middle, and a body that is not going fast along it:
##    swinging past a wall at speed, the legs trail as they always have.
##  - Arriving: the legs come up ahead of the body (LEAD seconds before it gets there),
##    the feet meet the wall first and the knees take it up, deeper the faster it came.
##  - Each foot is planted on the wall, in the world, and stays where it is while the
##    body moves: once it is left STEP behind it takes a step, one foot at a time. So the
##    feet walk along the wall as you work your way across it or are reeled up it.
##  - The hips face the wall and the waist turns to let the chest aim somewhere else. Aim
##    further round than TURN and the body goes side-on instead: one foot and that hip
##    against the wall, the other leg hanging.
##  - Jump off the rope and the legs shove off: they straighten against the wall until
##    the body is out of reach.
##
## Like RopeSwing it is worked out from what every copy of the game knows about a player,
## and from the wall as each copy finds it for the bodies it draws (find_wall, into
## RobotAnimInput.wall_at and wall_normal): your own body, another player's and a
## killcam's all brace the same way. RobotAnimator lays it over the legs after RopeSwing.

const S := MovementController.State
const HIPS := 0.95           ## the hips, above the feet
const REACH := 0.9           ## a wall within this of the body's middle is near enough to stand on (about 3 ft)
const LEAD := 0.3            ## coming in, the legs come up this many seconds before the body gets there...
const LOOK := 2.4            ## ...from no further off than this (how far find_wall looks)
const STEEP := 0.5           ## a wall leans no more than this (its normal's y): the rest is floor, ceiling, slope
const SLOW := 5.0            ## metres a second along the wall: slower, the feet go on it...
const FAST := 7.5            ## ...and faster than this they come off again
const LEG := 0.78            ## the hips within this of the wall: the feet are on it
const DROP := 0.22           ## the feet go this far below the hips...
const SPREAD := 0.2          ## ...and this far to each side
const ANKLE := 0.08          ## the ankle is this far off the wall when the sole is on it
const STEP := 0.3            ## a foot left this far from where it should be takes a step...
const STEP_TIME := 0.16      ## ...of this long...
const STEP_LIFT := 0.1       ## ...lifted this far off the wall on the way
const OUT := 0.2             ## braced, the hips ease out from the wall this far
const COIL := 0.02           ## landing on it, the knees take up this many metres for each metre a second...
const COIL_MAX := 0.16       ## ...at most this
const COIL_PACE := 15.0      ## ...and spring back
const COIL_DAMP := 0.55
const TURN := 1.75           ## the hips face the wall while the aim is within this of it (radians: RopeSwing.TWIST_MAX)...
const TURN_BACK := 1.45      ## ...and come back to facing it when the aim is within this
const PUSH_TIME := 0.2       ## jumping off: the feet stay on the wall this long (or until out of reach) as the legs straighten
const PUSH_KICK := 2.0       ## ...a jump off the rope being a let-go that throws you up at least this much (metres a second)

var w := 0.0                 ## how much the body is braced, 0..1
var landed := 0.0            ## the feet have just met the wall: how hard, 0..1 (see take_landed)
var stepped := false         ## a foot has just taken a step along the wall (see take_stepped)

var _on := false
var _normal := Vector3.ZERO  # the wall: out of it, toward the body
var _at := Vector3.ZERO      # ...and a point on it
var _foot: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]    # where each foot is planted, in the world (left, right)
var _from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]    # a step: from, to, how far through (-1: none)
var _to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _step: Array[float] = [-1.0, -1.0]
var _held: Array[float] = [0.0, 0.0]   # how much each leg is on the wall
var _last := 1               # the foot that stepped last
var _touching := false
var _settled := 0.0          # how far the hips have eased out, 0..1
var _coil := 0.0             # the knees taking up a landing, metres toward the wall
var _coil_v := 0.0
var _face := 0.0             # the way the hips face (a yaw, in the world)
var _flank := 0              # 0: facing the wall; -1: side-on, the wall at its left; 1: at its right
var _front := 1.0            # how much it faces the wall (0: side-on)
var _push := 0.0             # shoving off: seconds left
var _was_hanging := false
var _prev_vy := 0.0
var _flat: Array[Quaternion] = []   # each foot flat on the floor, in the body's space (from the rig's own standing pose)
var _flat_rig: RobotRig


## The wall a body on the rope could put its feet on: [a point on it, its normal (out of
## the wall)], or [] for none within LOOK. `feet`: where the body stands; it looks the way
## the rope goes, the way the body is going, and all round, from the hips, and takes the
## nearest wall that is also there at the height the feet would go.
static func find_wall(space: PhysicsDirectSpaceState3D, feet: Vector3, anchor: Vector3, velocity: Vector3, exclude: Array[RID] = []) -> Array:
	if space == null:
		return []
	var from := feet + Vector3(0.0, HIPS, 0.0)
	var ways: Array[Vector3] = []
	for dir in [anchor - from, velocity]:
		var flat := Vector3(dir.x, 0.0, dir.z)
		if flat.length() > 0.5:
			ways.append(flat.normalized())
	for i in 8:
		ways.append(Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0))
	var best := []
	var nearest := LOOK
	for way in ways:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * LOOK, 1, exclude))
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		if absf(n.y) > STEEP:
			continue
		var off := (from - (hit.position as Vector3)).dot(n)
		if off < 0.0 or off >= nearest:
			continue
		# The same wall where the feet would go? (Not the lip of a ledge, a window, a gap.)
		var low := from - Vector3(0.0, DROP, 0.0)
		var under := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low - n * (off + 0.35), 1, exclude))
		if under.is_empty() or (under.normal as Vector3).dot(n) < 0.8 or absf((low - (under.position as Vector3)).dot(n) - off) > 0.25:
			continue
		nearest = off
		best = [hit.position, n]
	return best


## Every frame. feet: where the body stands, in the world.
func update(delta: float, inp: RobotAnimInput, feet: Vector3) -> void:
	var hanging := inp.alive and inp.state == S.GRAPPLE and inp.hook_taut >= 0.0 and not inp.zipping()
	var hips := feet + Vector3(0.0, HIPS, 0.0)
	var want := false
	var toward := 0.0
	if hanging and inp.wall_normal.length_squared() > 0.5:
		var n := inp.wall_normal.normalized()
		var off := (hips - inp.wall_at).dot(n)
		toward = -inp.velocity.dot(n)
		var along := (inp.velocity + n * toward).length()
		var near := off <= REACH or (toward > 1.0 and off - REACH <= toward * LEAD)
		want = near and off > -0.2 and along < (FAST if _on else SLOW)
		if want:
			_normal = n
			_at = inp.wall_at
	_on = want
	# Jumped off the rope (let go, and thrown up): the legs shove off.
	if _was_hanging and not hanging and w > 0.5 and _touching and inp.alive and inp.velocity.y - _prev_vy >= PUSH_KICK:
		_push = PUSH_TIME
	_was_hanging = hanging
	_prev_vy = inp.velocity.y
	if not inp.alive or inp.state not in [S.GRAPPLE, S.AIR, S.FLIP, S.DIVE, S.GLIDE]:
		_push = 0.0
	var fresh := w <= 0.0
	var dist := (hips - _at).dot(_normal)
	if _push > 0.0:
		_push -= delta
		if dist > LEG + 0.3:
			_push = 0.0   # out of reach
	else:
		w = move_toward(w, 1.0 if want else 0.0, delta * (9.0 if want else 7.0))
	if w <= 0.0:
		_touching = false
		_settled = 0.0
		_coil = 0.0
		_coil_v = 0.0
		_step = [-1.0, -1.0]
		_held = [0.0, 0.0]
		return
	if _push > 0.0:
		return   # (the feet stay where they are, the hips where they face)

	# Which way the hips face: the wall, or along it (side-on) when the aim is too far round.
	var into := atan2(_normal.x, _normal.z)
	var round_by := wrapf(into - inp.yaw, -PI, PI)
	if absf(round_by) < TURN_BACK or (_flank == 0 and absf(round_by) <= TURN):
		_flank = 0
	elif _flank == 0 or absf(round_by) < PI - 0.35:
		_flank = -1 if round_by > 0.0 else 1   # (aimed straight out from the wall, it stays on the side it has)
	var face_to := wrapf(into + _flank * PI * 0.5, -PI, PI)
	_face = face_to if fresh else lerp_angle(_face, face_to, 1.0 - exp(-delta * 9.0))
	_front = (1.0 if _flank == 0 else 0.0) if fresh else move_toward(_front, 1.0 if _flank == 0 else 0.0, delta * 5.0)

	# Where each foot should be: under the hips on the wall, apart; side-on, the one by the wall alone.
	var up_wall := (Vector3.UP - _normal * _normal.y).normalized()
	var right := up_wall.cross(_normal)   # (the body's right, facing the wall)
	var base := hips - _normal * dist
	var ahead := right * float(-_flank)
	var ideal: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	for i in 2:
		var facing := base - up_wall * DROP + right * SPREAD * (-1.0 if i == 0 else 1.0)
		var side_on := base - up_wall * (DROP + 0.12) + ahead * 0.12
		ideal[i] = side_on.lerp(facing, _front)
		var by_wall := _flank == 0 or (_flank < 0) == (i == 0)
		_held[i] = (1.0 if by_wall else 0.0) if fresh else move_toward(_held[i], 1.0 if by_wall else 0.0, delta * 6.0)

	var touching := dist <= LEG
	if touching and not _touching:
		landed = clampf(toward / 9.0, 0.12, 1.0)
		_coil_v += maxf(toward, 0.0) * COIL * COIL_PACE * 1.6
	_touching = touching
	_settled = move_toward(_settled, 1.0 if touching else 0.0, delta * 4.0)
	var slide := inp.velocity - _normal * inp.velocity.dot(_normal)
	for i in 2:
		if fresh or not touching:
			_foot[i] = ideal[i]   # (reaching for the wall: not on it yet)
			_step[i] = -1.0
		elif _step[i] >= 0.0:
			_step[i] += delta / STEP_TIME
			_to[i] = ideal[i] + slide * STEP_TIME * 0.6
			if _step[i] >= 1.0:
				_foot[i] = _to[i]
				_step[i] = -1.0
				stepped = true
		else:
			var far := _foot[i].distance_to(ideal[i])
			var off_wall := absf((_foot[i] - _at).dot(_normal)) > 0.06
			if far > STEP * 3.0:
				_foot[i] = ideal[i]   # (left far behind: another wall altogether)
			elif (far > STEP or off_wall) and _step[1 - i] < 0.0 and (i != _last or far > STEP * 1.5 or _held[1 - i] < 0.5):
				_step[i] = 0.0
				_from[i] = _foot[i]
				_to[i] = ideal[i] + slide * STEP_TIME
				_last = i

	var left := delta
	while left > 0.0:
		var dt := minf(left, 1.0 / 120.0)
		left -= dt
		_coil_v += (-_coil * COIL_PACE * COIL_PACE - _coil_v * 2.0 * COIL_DAMP * COIL_PACE) * dt
		_coil = clampf(_coil + _coil_v * dt, -0.04, COIL_MAX)


func stop() -> void:
	w = 0.0
	_on = false
	_push = 0.0
	_touching = false
	_settled = 0.0
	_coil = 0.0
	_coil_v = 0.0
	_step = [-1.0, -1.0]
	_held = [0.0, 0.0]
	_was_hanging = false
	landed = 0.0
	stepped = false


## The feet have met the wall since this was last asked: how hard, 0..1 (0: they have not).
func take_landed() -> float:
	var hard := landed
	landed = 0.0
	return hard


## A foot has taken a step along the wall since this was last asked.
func take_stepped() -> bool:
	var did := stepped
	stepped = false
	return did


## Where the feet are on the wall (between them), and the wall's normal, in the world.
func footing() -> Vector3:
	return (foot(0) + foot(1)) * 0.5


func normal() -> Vector3:
	return _normal


## The feet are on the wall (not reaching for it, not shoving off it).
func standing() -> bool:
	return w > 0.0 and _touching and _push <= 0.0


## Shoving off the wall (a jump off the rope).
func pushing() -> bool:
	return _push > 0.0


## Side-on to the wall: -1 with it at the body's left, 1 at its right, 0 facing it.
func flank() -> int:
	return _flank


## Where a foot is now, in the world (0: the left, 1: the right): planted, or part of the way through a step.
func foot(i: int) -> Vector3:
	if _step[i] < 0.0:
		return _foot[i]
	var s := smoothstep(0.0, 1.0, _step[i])
	return _from[i].lerp(_to[i], s) + _normal * sin(PI * s) * STEP_LIFT


## How far the hips are turned from the way the body faces (`yaw`), to face the wall (or
## along it, side-on): the waist lets the chest keep the aim.
func twist(yaw: float) -> float:
	return clampf(wrapf(_face - yaw, -PI, PI), -TURN, TURN)


## The legs, onto the wall (after RopeSwing.lay_legs, and after the animator has turned
## the hips). `model`: where the body is drawn, in the world.
func lay(pose: RobotPose, b: Dictionary, rig: RobotRig, model: Transform3D) -> void:
	if w <= 0.0:
		return
	if _flat_rig != rig:
		_measure(rig, b)
	var k := smoothstep(0.0, 1.0, w)
	var inv := model.affine_inverse()
	var n := (inv.basis * _normal).normalized()
	var up_wall := (inv.basis * (Vector3.UP - _normal * _normal.y)).normalized()
	var right := up_wall.cross(n)
	var ahead := right * float(-_flank)
	var root: int = b["root"]
	var hips: int = b["hips"]
	# The hips eased out from the wall; a landing drives them in at it and they spring back.
	pose.pos[root] += n * (OUT * smoothstep(0.0, 1.0, _settled) - _coil) * k
	var root_at := Transform3D(Basis(pose.rot[root]), pose.pos[root])
	var hips_at := root_at * Transform3D(Basis(pose.rot[hips]), pose.pos[hips])
	for i in 2:
		var held := k * smoothstep(0.0, 1.0, _held[i])
		if held <= 0.001:
			continue
		var out := right * (-1.0 if i == 0 else 1.0)
		# The knee goes out to its side and up, like a climber's (facing the wall), or forward and up (side-on).
		var knee := (out * 0.8 + up_wall * 0.6).lerp(ahead * 0.8 + up_wall * 0.5 + n * 0.2, 1.0 - _front)
		# The sole on the wall, toes up it (side-on: along it, the way the hips face).
		var toes := (up_wall + out * 0.25).lerp(ahead + up_wall * 0.3, 1.0 - _front)
		toes = (toes - n * toes.dot(n)).normalized()
		var sole := Basis(toes.cross(n), n, -toes).get_rotation_quaternion() * _flat[i]
		_reach(pose, b, hips_at, "l" if i == 0 else "r", inv * (foot(i) + _normal * ANKLE), knee, sole, held)


# One leg bent to put its ankle at `target` (in the body's space) with the knee toward
# `hint` and the foot turned to `sole`, `held` of the way from how the pose has it.
func _reach(pose: RobotPose, b: Dictionary, hips_at: Transform3D, side: String, target: Vector3, hint: Vector3, sole: Quaternion, held: float) -> void:
	var th: int = b["thigh_" + side]
	var sh: int = b["shin_" + side]
	var ft: int = b["foot_" + side]
	var hip := hips_at * pose.pos[th]
	var upper := pose.pos[sh].length()
	var lower := pose.pos[ft].length()
	var to := target - hip
	if to.length_squared() < 0.000001:
		return
	var dist := clampf(to.length(), absf(upper - lower) + 0.01, (upper + lower) * 0.999)
	var dir := to.normalized()
	var along := (upper * upper - lower * lower + dist * dist) / (2.0 * dist)
	var bent := sqrt(maxf(upper * upper - along * along, 0.0))
	var side_dir := hint - dir * hint.dot(dir)
	if side_dir.length_squared() < 0.000001:
		side_dir = Vector3.UP - dir * dir.y
	side_dir = side_dir.normalized()
	var knee := hip + dir * along + side_dir * bent
	var ankle := hip + dir * dist
	var hinge := dir.cross(side_dir).normalized()   # the knee's axis: both bones' own +X (as RobotAnimator._reach_foot)
	var thigh_y := (hip - knee).normalized()
	var shin_y := (knee - ankle).normalized()
	var thigh_rot := Basis(hinge, thigh_y, hinge.cross(thigh_y)).get_rotation_quaternion()
	var shin_rot := Basis(hinge, shin_y, hinge.cross(shin_y)).get_rotation_quaternion()
	pose.rot[th] = pose.rot[th].slerp(hips_at.basis.get_rotation_quaternion().inverse() * thigh_rot, held)
	pose.rot[sh] = pose.rot[sh].slerp(thigh_rot.inverse() * shin_rot, held)
	pose.rot[ft] = pose.rot[ft].slerp(shin_rot.inverse() * sole, held)


# How each foot lies when it is flat on the floor: from the rig's own standing pose.
func _measure(rig: RobotRig, b: Dictionary) -> void:
	_flat_rig = rig
	_flat = [Quaternion.IDENTITY, Quaternion.IDENTITY]
	if rig == null or not rig.has_clip("idle"):
		return
	var stand := rig.new_pose()
	rig.sample(stand, "idle", 0.0)
	for i in 2:
		var side := "l" if i == 0 else "r"
		_flat[i] = (stand.rot[b["root"]] * stand.rot[b["hips"]] * stand.rot[b["thigh_" + side]] * stand.rot[b["shin_" + side]] * stand.rot[b["foot_" + side]]).normalized()


## A little dust knocked off the wall where the feet land, `strength` 0..1 of it.
static func dust(parent: Node, at: Vector3, normal_: Vector3, strength: float) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.72, 0.72, 0.74, 0.4)
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var along := normal_.cross(Vector3.UP).normalized() if absf(normal_.y) < 0.95 else Vector3.RIGHT
	for i in int(lerpf(3.0, 7.0, strength)):
		var cloud := MeshInstance3D.new()
		cloud.mesh = puff
		cloud.material_override = grey
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(cloud)
		var way := (along * randf_range(-1.0, 1.0) + Vector3.UP * randf_range(-0.7, 0.4) + normal_ * randf_range(0.3, 0.8)).normalized()
		cloud.global_position = at + normal_ * 0.05 + way * 0.08
		cloud.scale = Vector3.ONE * 0.1
		var life := randf_range(0.3, 0.5)
		var tween := cloud.create_tween().set_parallel()
		tween.tween_property(cloud, "global_position", at + way * lerpf(0.2, 0.5, strength) * randf_range(0.6, 1.0), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(cloud, "scale", Vector3.ONE * randf_range(0.22, 0.4) * lerpf(0.7, 1.2, strength), life).set_ease(Tween.EASE_OUT)
		tween.tween_property(cloud, "transparency", 1.0, life).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(cloud.queue_free)
