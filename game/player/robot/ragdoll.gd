class_name Ragdoll
extends Node3D
## A knocked-out robot falling as a ragdoll (see Remains): a copy of the dead player's
## model, left in the arena (not on the player, whose node comes back at the respawn),
## its main bones turned into physics bodies thrown by the killing blow. It collides
## with the level only (never players, shots or other remains), lies there for
## Remains.LIFETIME seconds from the death whether or not its player is back by then,
## and burns away (Dissolve) over the last Remains.DISSOLVE_TIME of them.
##
## Every character shares one skeleton (see Characters), so the bodies below fit them
## all; each skeleton's measurements are worked out once (see _plan).
##
## A killcam replays the fall from Killcam's recording of it (capture()): a puppet()
## is the same robot with no physics, posed from the recording (pose()) on the replay's
## own clock, so it falls the same way in slow motion and in a saved video.

## The bones that get a body (the hands and feet, the gun and the markers ride on
## theirs): "to" is the bone at its far end ("tip": a set length up the bone instead,
## for the head), "extend" reaches past that bone (a forearm takes in its fist), "r"
## the capsule's radius (m) and "mass" (kg). The joint to the body above it: "cone"
## swings up to "swing" degrees off the bone's line, the middle of that tipped by
## "tilt" (degrees about x, y, z: +x swings a hanging limb forward, +z towards the
## robot's right), and twists "twist" degrees each way; "hinge" bends about the bone's
## x axis only, between "lower" and "upper" degrees (+ is the way +x tilts it: an elbow
## forward, a knee back the other way).
const PARTS := [
	{"bone": "hips", "to": "spine", "r": 0.13, "mass": 10.0},
	{"bone": "spine", "to": "chest", "r": 0.12, "mass": 8.0, "joint": "cone", "swing": 25.0, "twist": 20.0},
	{"bone": "chest", "to": "head", "r": 0.15, "mass": 12.0, "joint": "cone", "swing": 25.0, "twist": 20.0},
	{"bone": "head", "tip": 0.22, "r": 0.12, "mass": 4.0, "joint": "cone", "swing": 40.0, "twist": 45.0},
	{"bone": "upper_arm_l", "to": "forearm_l", "r": 0.06, "mass": 3.0, "joint": "cone", "swing": 75.0, "twist": 40.0, "tilt": Vector3(20, 0, -25)},
	{"bone": "forearm_l", "to": "hand_l", "extend": 0.08, "r": 0.055, "mass": 2.0, "joint": "hinge", "lower": 0.0, "upper": 135.0},
	{"bone": "upper_arm_r", "to": "forearm_r", "r": 0.06, "mass": 3.0, "joint": "cone", "swing": 75.0, "twist": 40.0, "tilt": Vector3(20, 0, 25)},
	{"bone": "forearm_r", "to": "hand_r", "extend": 0.08, "r": 0.055, "mass": 2.0, "joint": "hinge", "lower": 0.0, "upper": 135.0},
	{"bone": "thigh_l", "to": "shin_l", "r": 0.08, "mass": 7.0, "joint": "cone", "swing": 55.0, "twist": 15.0, "tilt": Vector3(35, 0, -10)},
	{"bone": "shin_l", "to": "foot_l", "r": 0.07, "mass": 4.0, "joint": "hinge", "lower": -135.0, "upper": 0.0},
	{"bone": "thigh_r", "to": "shin_r", "r": 0.08, "mass": 7.0, "joint": "cone", "swing": 55.0, "twist": 15.0, "tilt": Vector3(35, 0, 10)},
	{"bone": "shin_r", "to": "foot_r", "r": 0.07, "mass": 4.0, "joint": "hinge", "lower": -135.0, "upper": 0.0},
]

const HIT_THROW := 4.0     ## m/s along a bullet's (or blow's) path, as most guns push nobody
const BLAST_THROW := 9.0   ## m/s away from a blast, for the parts nearest it
const BLAST_REACH := 4.0   ## a part this far from the blast gets none of BLAST_THROW
const MAX_SPEED := 22.0    ## no part starts faster than this, however hard the blow
const GRAVITY := 22.0      ## falls the way players do (MovementTuning.gravity, times WorldGravity)

static var _plans := {}    # RobotRig -> its bodies (see _plan); [] when it lacks a bone

var model: RobotModel
## Who fell, as what, and how the blow fell (Match.death_fx): kept with the recording.
var who := 0
var character := ""
var weapon := ""
var body_color := Color.WHITE
var blow: Dictionary = {}
var _bones: Array[PhysicalBone3D] = []
var _age := 0.0
var _dissolve: Dissolve
var _edge := Color.WHITE
var _gravity := 1.0        # gravity_scale for GRAVITY (the physics' own default is weaker)
var _first: Array = []     # each part's bone in the world at the death (see capture)


## A ragdoll in place of `p`'s body, thrown by the killing blow (Match.death_fx), added
## to the world. Returns it, or null when there is none (no arena, or a model without
## the bones; the old body shows then).
static func spawn(p: Player, fx: Dictionary) -> Node3D:
	if p == null or p.robot == null or p.robot.skeleton == null or p.robot.rig == null \
			or Net.arena == null or not p.robot.is_inside_tree():
		return null
	var plan := _plan(p.robot.rig)
	if plan.is_empty():
		return null
	var color := Net.player_color(p.peer_id)
	var r := Ragdoll.new()
	r.name = "Ragdoll"
	r._edge = RobotModel.trim_color(color)
	r.who = p.peer_id
	r.character = p.character
	r.weapon = p.robot.weapon
	r.body_color = color
	r.blow = fx.duplicate()
	r.model = RobotModel.new().build(p.character, color, false, p.robot.weapon, false, Teams.paint_for(p.peer_id))
	if r.model.skeleton == null or r.model.rig != p.robot.rig:
		r.model.free()
		r.free()
		return null
	r.add_child(r.model)
	Net.arena.add_child(r, true)
	r.model.global_transform = p.robot.global_transform
	r.model.set_power(0.0)   # powered down, like the body it replaces
	r._build(plan)
	r._pose_from(p.robot.skeleton)
	r._first = r.capture()
	r._throw(p, fx)
	if DevArgs.sync_log:
		print("RAGDOLL %d %d at %s" % [Net.my_id(), p.peer_id, p.global_position])
	return r


## A replay's ragdoll (see KillcamView): the same robot, powered down, with no physics
## of its own, standing in `source`'s pose until pose() moves it. Not yet in the world;
## the replay frees it. Null for a model without the bones. `team_paint`: in team modes,
## the team's paint (Teams.paint_for), as on the body in the match.
static func puppet(as_character: String, paint: Color, gun: String, source: Skeleton3D,
		team_paint: Color = Color(0, 0, 0, 0)) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "ReplayRagdoll"
	r.top_level = true
	r.character = as_character
	r.weapon = gun
	r.body_color = paint
	r.model = RobotModel.new().build(as_character, paint, false, gun, false, team_paint)
	if r.model.skeleton == null or r.model.rig == null or _plan(r.model.rig).is_empty():
		r.model.free()
		r.free()
		return null
	r.add_child(r.model)
	r.model.set_power(0.0)
	if source:
		r._copy_pose(source)
	r.set_process(false)           # the replay decides when it goes
	r.set_physics_process(false)
	return r


## Each part's bone, in PARTS order, where it is in the world now: what Killcam records.
func capture() -> Array:
	var out := []
	for b in _bones:
		out.append(b.global_transform * b.body_offset.affine_inverse())
	return out


## capture() at the moment of the death, before the blow moved anything.
func start_pose() -> Array:
	return _first


## A puppet: puts each part's bone where `bones` (from capture()) says, the hands, feet
## and gun riding along on theirs.
func pose(bones: Array) -> void:
	var skeleton := model.skeleton
	var inside := skeleton.global_transform.affine_inverse()
	for i in mini(PARTS.size(), bones.size()):
		var bone := skeleton.find_bone(PARTS[i].bone)
		var at: Transform3D = inside * (bones[i] as Transform3D)
		at.basis = at.basis.orthonormalized()   # (the bones are not scaled; the model may be)
		skeleton.set_bone_global_pose(bone, at)


## Where the body is: its hips, in the world.
func focus() -> Vector3:
	var skeleton := model.skeleton
	return skeleton.global_transform * skeleton.get_bone_global_pose(maxi(skeleton.find_bone("hips"), 0)).origin


## How long since the death (s).
func age() -> float:
	return _age


## The bodies, in PARTS order (tests).
func bodies() -> Array[PhysicalBone3D]:
	return _bones


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(model) and model.mesh:
		for i in model.mesh.get_surface_override_material_count():   # headless Godot grumbles otherwise
			model.mesh.set_surface_override_material(i, null)


func _physics_process(_delta: float) -> void:
	var g := _gravity * WorldGravity.scale
	for b in _bones:
		if b.gravity_scale != g:
			b.gravity_scale = g


func _process(delta: float) -> void:
	_age += delta
	var burn := _age - (Remains.LIFETIME - Remains.DISSOLVE_TIME)
	if burn > 0.0:
		if _dissolve == null:
			_dissolve = Dissolve.prepare(model, _edge)
		_dissolve.set_progress(burn / Remains.DISSOLVE_TIME)
	if _age >= Remains.LIFETIME:
		queue_free()


## The physics bodies, made while the skeleton still stands in its rest pose: each
## joint's limits count from where it was made, so they count from standing straight.
func _build(plan: Array) -> void:
	var skeleton := model.skeleton
	skeleton.reset_bone_poses()
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Physics"
	skeleton.add_child(sim)
	_gravity = GRAVITY / maxf(float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)), 0.1)
	for part: Dictionary in plan:
		var b := PhysicalBone3D.new()
		b.name = part.bone
		b.bone_name = part.bone
		b.body_offset = part.body_offset
		b.mass = part.mass
		b.friction = 0.8
		b.linear_damp = 0.1
		b.angular_damp = 1.5
		b.collision_layer = Remains.DEBRIS_LAYER
		b.collision_mask = 1   # the level only
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = part.r
		capsule.height = part.height
		shape.shape = capsule
		shape.transform = part.shape_xform
		b.add_child(shape)
		match str(part.get("joint", "")):
			"cone":
				b.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
				b.set("joint_constraints/swing_span", part.swing)
				b.set("joint_constraints/twist_span", part.twist)
			"hinge":
				b.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
				b.set("joint_constraints/angular_limit_enabled", true)
				b.set("joint_constraints/angular_limit_lower", part.lower)
				b.set("joint_constraints/angular_limit_upper", part.upper)
		if b.joint_type != PhysicalBone3D.JOINT_TYPE_NONE:
			b.joint_offset = part.joint_offset
		sim.add_child(b)
		_bones.append(b)
	sim.physical_bones_start_simulation()


## Starts from the dead body's pose, bone by bone.
func _pose_from(source: Skeleton3D) -> void:
	_copy_pose(source)
	var skeleton := model.skeleton
	var at := skeleton.global_transform
	for b in _bones:
		b.global_transform = (at * skeleton.get_bone_global_pose(b.get_bone_id()) * b.body_offset).orthonormalized()
		PhysicsServer3D.body_set_enable_continuous_collision_detection(b.get_rid(), true)   # thin limbs, thrown fast


func _copy_pose(source: Skeleton3D) -> void:
	var skeleton := model.skeleton
	for i in mini(skeleton.get_bone_count(), source.get_bone_count()):
		skeleton.set_bone_pose_position(i, source.get_bone_pose_position(i))
		skeleton.set_bone_pose_rotation(i, source.get_bone_pose_rotation(i))
		skeleton.set_bone_pose_scale(i, source.get_bone_pose_scale(i))


## Each part's starting speed: the way the player was going, the knockback of the
## blow, then a shove along a bullet's path (harder on the part it hit) or away from
## a blast (harder the nearer the part).
func _throw(p: Player, fx: Dictionary) -> void:
	var base := (p.velocity if p.is_local else p.latest_velocity()) + (fx.get("push", Vector3.ZERO) as Vector3)
	var dir := fx.get("dir", Vector3.ZERO) as Vector3
	var blast := fx.has("at")
	var at := fx.get("at", Vector3.ZERO) as Vector3
	var struck := "head" if fx.get("head", false) else "chest"
	for b in _bones:
		var v := base
		if blast:
			var away := b.global_position - at
			var near := clampf(1.0 - away.length() / BLAST_REACH, 0.0, 1.0)
			v += (away.normalized() if away.length_squared() > 0.0001 else Vector3.UP) * BLAST_THROW * (0.4 + 0.6 * near)
		elif dir != Vector3.ZERO:
			v += dir.normalized() * HIT_THROW * (2.0 if b.bone_name == struck else 0.6)
		b.linear_velocity = v.limit_length(MAX_SPEED)


## The bodies for one skeleton (worked out once): each PARTS entry with its bone's
## body_offset (the middle of the bone), the capsule's height and turn, and the joint's
## place and axes in the body's space. [] if the skeleton lacks one of the bones.
static func _plan(rig: RobotRig) -> Array:
	if _plans.has(rig):
		return _plans[rig]
	var out := []
	for part: Dictionary in PARTS:
		if not rig.bones.has(part.bone) or (part.has("to") and not rig.bones.has(part.to)):
			out = []
			break
		# The bone's line, in its own space (the child's rest position is relative to it).
		var line: Vector3 = rig.rest_pos[rig.bones[part.to]] if part.has("to") else Vector3.UP * float(part.tip)
		var length := line.length()
		if length < 0.01:
			out = []
			break
		var dir := line / length
		length += float(part.get("extend", 0.0))
		var mid := dir * length * 0.5
		var plan := part.duplicate()
		plan.body_offset = Transform3D(Basis.IDENTITY, mid)
		plan.height = length + 2.0 * float(part.r)
		plan.shape_xform = Transform3D(Basis(_turn(Vector3.UP, dir)), Vector3.ZERO)   # capsules lie along y
		# The joint sits at the bone's root. A cone twists about its x axis (along the
		# bone, tipped by "tilt"); a hinge turns about its z axis, set along the bone's
		# -x (the physics counts a hinge's angle the other way round to the bone's own).
		var axes := Basis.IDENTITY
		if part.get("joint", "") == "cone":
			var tilt: Vector3 = part.get("tilt", Vector3.ZERO)
			var tip := Basis.from_euler(Vector3(deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z)))
			axes = tip * Basis(_turn(Vector3.RIGHT, dir))
		elif part.get("joint", "") == "hinge":
			axes = Basis(Vector3.UP, -PI * 0.5)   # z -> -x
		plan.joint_offset = Transform3D(axes, -mid)
		out.append(plan)
	_plans[rig] = out
	return out


## The shortest turn taking `from` onto `to` (both length 1).
static func _turn(from: Vector3, to: Vector3) -> Quaternion:
	if from.dot(to) < -0.9999:
		return Quaternion(Vector3.FORWARD if absf(from.z) < 0.9 else Vector3.RIGHT, PI)
	return Quaternion(from, to)
