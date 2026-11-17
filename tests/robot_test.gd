extends SceneTree
## Headless checks on the robot models (every playable character) and the animator.
## Run: godot --headless --path . --script tests/robot_test.gd
##
## For each character in Characters: the model files hold every bone and clip the game
## asks for, the skeleton matches the others (so animations and the hitbox are shared),
## each movement state plays the right animation, and the poses make sense for the
## hitbox: standing height, crouch height, feet on the floor, gun following the aim.
## Then the body as you see it in first person: no head or arms, kept under and behind
## the camera in every move, and never upside down in front of your eyes.

const S := MovementController.State
const CROUCH_HEIGHT := 1.1   ## CROUCH_HEIGHT (the player script needs the full game to load)
const PRONE_HEIGHT := 0.8    ## Player.PRONE_HEIGHT

const BODY_CLIPS := ["aim", "idle", "run", "sprint", "crouch_idle", "crouch_walk", "slide",
	"air", "air_tuck", "land", "wall_run_l", "wall_run_r", "wall_jump_l", "wall_jump_r",
	"vault", "climb", "grapple", "dive", "roll", "belly_slide", "belly_crawl", "flip_front", "flip_back", "flip_left",
	"flip_right", "reload", "death", "respawn",
	"view_slide", "view_air_tuck", "view_roll", "view_flip_front", "view_flip_back", "view_flip_left", "view_flip_right"]
const ARM_CLIPS := ["fp_idle", "fp_one_hand", "fp_sprint", "fp_slide", "fp_wall_l", "fp_wall_r",
	"fp_dive", "fp_tuck", "fp_mantle", "fp_raise", "fp_reload"]
const BODY_BONES := ["root", "hips", "spine", "chest", "head", "upper_arm_l", "forearm_l", "hand_l",
	"upper_arm_r", "forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r",
	"foot_r", "pistol", "pistol_slide", "pistol_mag", "muzzle", "grapple", "muzzle_shotgun", "muzzle_rifle", "muzzle_sniper"]
const LONG_GUNS := ["shotgun", "rifle", "sniper"]
## Each long gun's own versions of these (e.g. "aim_rifle"); the pump and bolt guns also have "fire".
const GUN_BODY_CLIPS := ["aim", "carry", "reload", "respawn"]
const GUN_ARM_CLIPS := ["fp_idle", "fp_one_hand", "fp_sprint", "fp_slide", "fp_wall_l", "fp_wall_r",
	"fp_dive", "fp_tuck", "fp_mantle", "fp_raise", "fp_reload"]
const ARM_BONES := ["upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
	"pistol", "pistol_slide", "pistol_mag", "muzzle", "grapple"]

var failures := 0
var robot: RobotModel
var animator: RobotAnimator
var _character := ""
var _weapon := "pistol"
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_checks()
	print("ROBOT TEST PASSED" if failures == 0 else "ROBOT TEST FAILED: %d" % failures)
	_drop_robot()
	quit(1 if failures else 0)
	_done = true
	return false


func _checks() -> void:
	print("Robot model files")
	_expect("at least two characters to choose from", Characters.LIST.size() >= 2)
	_expect("an unknown character falls back to the default", Characters.valid("nobody") == Characters.default_id())
	var first := RobotRig.open(Characters.body(Characters.default_id()))
	for id in Characters.ids():
		var body_clips := BODY_CLIPS.duplicate()
		var arm_clips := ARM_CLIPS.duplicate()
		for gun in LONG_GUNS:
			for c in GUN_BODY_CLIPS:
				body_clips.append(c + "_" + gun)
			for c in GUN_ARM_CLIPS:
				arm_clips.append(c + "_" + gun)
			if gun != "rifle":
				body_clips.append("fire_" + gun)
				arm_clips.append("fp_fire_" + gun)
		_check_file(Characters.body(id), BODY_BONES, body_clips)
		_check_file(Characters.arms(id), ARM_BONES, arm_clips)
		var rig := RobotRig.open(Characters.body(id))
		var same := rig.bone_names == first.bone_names
		for i in mini(rig.rest_pos.size(), first.rest_pos.size()):
			same = same and rig.rest_pos[i].distance_to(first.rest_pos[i]) < 0.001
		_expect("%s: same skeleton as %s" % [id, Characters.default_id()], same)

	print("Animation flags survive packing")
	var inp := RobotAnimInput.new()
	inp.flags = RobotAnimInput.make_flags(true, false, true, RobotAnimInput.FLIP_LEFT, 6)
	_expect("wall on the right", inp.wall_right())
	_expect("not vaulting", not inp.vaulting())
	_expect("reloading", inp.reloading())
	_expect("flip direction", inp.flip() == RobotAnimInput.FLIP_LEFT)
	_expect("wall-jump counter wraps", inp.wall_jumps() == 2)
	_expect("fits a snapshot float exactly", int(float(inp.flags)) == inp.flags and inp.flags < 128)

	for id in Characters.ids():
		_character = id
		_drop_robot()
		_check_character()
		for gun in LONG_GUNS:
			_drop_robot()
			_check_gun(gun)
		_drop_robot()


func _check_character() -> void:
	print("%s: each movement state plays its animation" % Characters.name_of(_character))
	var right := RobotAnimInput.make_flags(true, false, false, 0, 0)
	var vault := RobotAnimInput.make_flags(false, true, false, 0, 0)
	var flip_r := RobotAnimInput.make_flags(false, false, false, RobotAnimInput.FLIP_RIGHT, 0)
	var cases := [
		[S.GROUND, false, 0, true, "loco"], [S.CROUCH, true, 0, true, "crouch"],
		[S.SLIDE, true, 0, true, "slide"], [S.AIR, false, 0, true, "air"],
		[S.AIR, true, 0, true, "tuck"], [S.GRAPPLE, false, 0, true, "grapple"],
		[S.WALL_RUN, false, 0, true, "wall_l"], [S.WALL_RUN, false, right, true, "wall_r"],
		[S.MANTLE, false, vault, true, "vault"], [S.MANTLE, false, 0, true, "climb"],
		[S.DIVE, true, 0, true, "dive"], [S.ROLL, true, 0, true, "roll"],
		[S.BELLY_SLIDE, true, 0, true, "belly_slide"],
		[S.FLIP, false, 0, true, "flip_front"], [S.FLIP, false, flip_r, true, "flip_right"],
		[S.FLOAT, false, 0, true, "float"],
		[S.GROUND, false, 0, false, "death"],
	]
	for c in cases:
		_fresh()
		var i := _input(c[0], Vector3.ZERO, 0.0)
		i.crouched = c[1]
		i.flags = c[2]
		i.alive = c[3]
		_run(i, 0.2)
		_expect("%s%s shows \"%s\"" % [S.keys()[c[0]], "" if c[3] else " (dead)", c[4]], animator.source == c[4],
			"got \"%s\"" % animator.source)

	print("%s: poses fit the hitbox" % Characters.name_of(_character))
	_fresh()
	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 1.0)
	_near("standing: top of the head", _top(), 1.76, 0.08)
	_near("standing: lowest foot", _lowest_foot(), 0.10, 0.04)
	var level := robot.marker("muzzle")
	_expect("standing: gun held out in front", level.z < -0.35 and level.y > 1.2, str(level))
	_fresh()
	_run(_input(S.GROUND, Vector3.ZERO, deg_to_rad(40.0)), 1.0)
	var up := robot.marker("muzzle")
	_expect("aiming up 40 degrees raises the gun", up.y > level.y + 0.2, "%.2f vs %.2f" % [up.y, level.y])
	_fresh()
	_run(_input(S.GROUND, Vector3.ZERO, deg_to_rad(-40.0)), 1.0)
	var down := robot.marker("muzzle")
	_expect("aiming down 40 degrees lowers the gun", down.y < level.y - 0.2, "%.2f vs %.2f" % [down.y, level.y])

	_fresh()
	_run(_input(S.GROUND, Vector3(0, 0, -8), 0.0), 1.0)
	_near("running: top of the head", _top(), 1.72, 0.12)
	_expect("running: feet stay on or above the floor", _lowest_foot() > 0.02, "%.2f" % _lowest_foot())

	_fresh()
	var crouch := _input(S.CROUCH, Vector3.ZERO, 0.0)
	crouch.crouched = true
	_run(crouch, 1.0)
	_expect("crouched: head under the crouch height (%.1f m)" % CROUCH_HEIGHT,
		_top() < CROUCH_HEIGHT + 0.12, "%.2f" % _top())

	_fresh()
	var slide := _input(S.SLIDE, Vector3(0, 0, -12), 0.0)
	slide.crouched = true
	_run(slide, 1.0)
	_expect("sliding: head under the crouch height", _top() < CROUCH_HEIGHT + 0.12, "%.2f" % _top())

	for speed in [11.0, 1.5]:
		_fresh()
		var belly := _input(S.BELLY_SLIDE, Vector3(0, 0, -speed), 0.0)
		belly.crouched = true
		_run(belly, 1.0)
		var what := "belly-sliding" if speed > 5.0 else "crawling"
		var high := maxf(_top(), _highest_bone() + 0.1)
		_expect("%s: whole body under the prone height (%.1f m)" % [what, PRONE_HEIGHT], high < PRONE_HEIGHT, "%.2f" % high)
		_expect("%s: no joint sinks into the floor" % what, _lowest_bone() > 0.0, "%.2f" % _lowest_bone())
		var gun := robot.marker("muzzle")
		_expect("%s: gun out in front, off the floor" % what, gun.z < -0.6 and gun.y > 0.1, str(gun))

	_fresh()
	var floating := _input(S.FLOAT, Vector3(0, 0, -12), 0.0)
	_run(floating, 0.5)
	var held := robot.bone_position("muzzle")
	_expect("floating: gun still held out in front", held.z < -0.35 and held.y > 1.2, str(held))
	var seat := robot.bone_position("hips")
	var leg_l := robot.bone_position("foot_l") - seat
	var leg_r := robot.bone_position("foot_r") - seat
	_expect("floating: legs straight out to the sides",
		Vector2(leg_l.x, leg_l.z).length() > 0.65 and Vector2(leg_r.x, leg_r.z).length() > 0.65 and leg_l.dot(leg_r) < 0.0,
		"%s %s" % [leg_l, leg_r])
	_run(floating, 2.5 / 60.0)   # three frames
	var later := robot.bone_position("foot_l") - robot.bone_position("hips")
	var turned := rad_to_deg(absf(Vector2(leg_l.x, leg_l.z).angle_to(Vector2(later.x, later.z))))
	_near("floating: the legs whirl round at the spin speed (degrees in three frames)", turned,
		360.0 * 0.05 / RobotAnimator.FLOAT_SPIN_TIME, 5.0)
	_expect("floating: the gun stays on target while they turn", robot.bone_position("muzzle").distance_to(held) < 0.03,
		"%.3f m" % robot.bone_position("muzzle").distance_to(held))

	_fresh()
	var before := robot.marker("muzzle")
	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 0.5)
	before = robot.marker("muzzle")
	animator.fire()
	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 0.03)
	var kicked := robot.marker("muzzle")
	_expect("firing kicks the gun", kicked.distance_to(before) > 0.01, "%.3f m" % kicked.distance_to(before))
	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 0.6)
	_expect("and it settles back on target", robot.marker("muzzle").distance_to(before) < 0.01)

	_fresh()
	var dead := _input(S.GROUND, Vector3.ZERO, 0.0)
	_run(dead, 0.3)
	dead.alive = false
	_run(dead, 2.0)
	_expect("dead: the body is down on the floor", _top() < 0.75, "%.2f" % _top())
	_expect("dead: nothing sinks through the floor", _lowest_bone() > -0.12, "%.2f" % _lowest_bone())
	_check_first_person()


## A robot holding a long gun: it shows only that gun, holds it in both hands, aims
## it, works its pump or bolt, carries it when sprinting and reloads it.
func _check_gun(gun: String) -> void:
	print("%s with the %s" % [Characters.name_of(_character), WeaponData.name_of(gun)])
	_weapon = gun
	_fresh()
	var own := 0
	var others := []
	for i in robot.mesh.mesh.get_surface_count():
		var mname := robot.mesh.mesh.surface_get_material(i).resource_name
		if mname.begins_with(gun + "."):
			own += 1
		elif "." in mname:
			others.append(mname)
	_expect("shows its own gun and no other", own >= 3 and others.is_empty(), "%d surfaces; others %s" % [own, others])
	_expect("the animator holds the same gun", animator.weapon == gun)

	_run(_input(S.GROUND, Vector3.ZERO, 0.0), 1.0)
	var level := robot.muzzle()
	var grip := robot.marker("pistol")
	_expect("standing: barrel out in front at chest height", level.z < -0.55 and level.y > 1.2 and level.y < 1.7, str(level))
	_expect("standing: barrel points forward", (level - grip).normalized().dot(Vector3.FORWARD) > 0.9, str((level - grip).normalized()))
	var hands := robot.marker("hand_l").distance_to(robot.marker("hand_r"))
	_expect("standing: both hands on the gun", hands > 0.12 and hands < 0.45, "%.2f m apart" % hands)
	var head_fwd: Vector3 = robot.skeleton.get_bone_global_pose(robot.rig.bones["head"]).basis * Vector3.FORWARD
	_expect("standing: the chest turns but the head looks ahead", head_fwd.dot(Vector3.FORWARD) > 0.95, str(head_fwd))
	_fresh()
	_run(_input(S.GROUND, Vector3.ZERO, deg_to_rad(40.0)), 1.0)
	_expect("aiming up 40 degrees raises the barrel", robot.muzzle().y > level.y + 0.2, "%.2f" % robot.muzzle().y)
	var up_dir := (robot.muzzle() - robot.marker("pistol")).normalized()
	_expect("and points it up", up_dir.y > 0.45, str(up_dir))

	if gun != "rifle":
		_fresh()
		_run(_input(S.GROUND, Vector3.ZERO, 0.0), 0.5)
		var rest := robot.marker("pistol_slide").distance_to(robot.marker("pistol"))
		animator.fire()
		var moved := 0.0
		for i in 40:
			_run(_input(S.GROUND, Vector3.ZERO, 0.0), 1.0 / 60.0)
			moved = maxf(moved, absf(robot.marker("pistol_slide").distance_to(robot.marker("pistol")) - rest))
		_expect("firing works the %s" % ("pump" if gun == "shotgun" else "bolt"), moved > 0.05, "%.3f m" % moved)

	_fresh()
	_run(_input(S.GROUND, Vector3(0, 0, -11.5), 0.0), 1.0)
	var carried := (robot.muzzle() - robot.marker("pistol")).normalized()
	_expect("sprinting: carried across the chest, muzzle up", carried.y > 0.2 and animator._carry > 0.9, str(carried))

	_fresh()
	var reloading := _input(S.GROUND, Vector3.ZERO, 0.0)
	reloading.flags = RobotAnimInput.make_flags(false, false, true, 0, 0)
	_run(reloading, 1.0)
	var mid_reload := robot.marker("hand_l").distance_to(robot.marker("hand_r"))
	_run(reloading, 1.0)
	if gun == "shotgun":
		_expect("reloading: loads shell after shell while the reload lasts", animator._reload_t >= 0.0)
	_expect("reloading: the left hand leaves its hold", absf(mid_reload - hands) > 0.03 or gun == "shotgun", "%.2f vs %.2f" % [mid_reload, hands])
	_weapon = "pistol"


## Your own body in first person (Player does this for the local player only).
func _check_first_person() -> void:
	print("%s: the body you see in first person" % Characters.name_of(_character))
	_fresh()
	robot.add_view_mesh(4)
	var full := _triangles(robot.mesh.mesh)
	var seen := _triangles(robot.view_mesh.mesh)
	_expect("leaves out the head and arms", seen > 0 and seen < full * 0.8, "%d of %d triangles" % [seen, full])
	_expect("follows the same skeleton", robot.view_mesh.get_node_or_null(robot.view_mesh.skeleton) == robot.skeleton)
	_expect("casts no shadow of its own", robot.view_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	# In every move, wherever you look: the neck stays behind the eyes (which are at
	# x = z = 0, eye height) and below them, so you never look into your own chest.
	var flip_b := RobotAnimInput.make_flags(false, false, false, RobotAnimInput.FLIP_BACK, 0)
	var flip_l := RobotAnimInput.make_flags(false, false, false, RobotAnimInput.FLIP_LEFT, 0)
	var flip_r := RobotAnimInput.make_flags(false, false, false, RobotAnimInput.FLIP_RIGHT, 0)
	var moves := [   # [name, state, crouched, flags, velocity, eye height, seconds]
		["standing", S.GROUND, false, 0, Vector3.ZERO, 1.6, 0.6], ["sprinting", S.GROUND, false, 0, Vector3(0, 0, -11.5), 1.6, 0.6],
		["strafing", S.GROUND, false, 0, Vector3(8, 0, 0), 1.6, 0.6], ["crouched", S.CROUCH, true, 0, Vector3.ZERO, 1.0, 0.6],
		["sliding", S.SLIDE, true, 0, Vector3(0, 0, -12), 1.0, 0.6], ["jumping", S.AIR, false, 0, Vector3(0, 6, -8), 1.6, 0.6],
		["tucked", S.AIR, true, 0, Vector3(0, 0, -8), 1.0, 0.6], ["on the rope", S.GRAPPLE, false, 0, Vector3(0, 0, -12), 1.6, 0.6],
		["wall-running", S.WALL_RUN, false, 0, Vector3(0, 0, -10), 1.6, 0.6], ["climbing", S.MANTLE, false, 0, Vector3.ZERO, 1.6, 0.3],
		["diving", S.DIVE, true, 0, Vector3(0, 0, -14), 1.0, 0.6], ["rolling", S.ROLL, true, 0, Vector3(0, 0, -10), 1.0, 0.2],
		["belly-sliding", S.BELLY_SLIDE, true, 0, Vector3(0, 0, -9), 0.55, 0.6],
		["front flip", S.FLIP, false, 0, Vector3(0, 2, -9), 1.6, 0.22], ["backflip", S.FLIP, false, flip_b, Vector3(0, 2, -9), 1.6, 0.22],
		["left flip", S.FLIP, false, flip_l, Vector3(0, 2, -9), 1.6, 0.22], ["right flip", S.FLIP, false, flip_r, Vector3(0, 2, -9), 1.6, 0.22],
	]
	for m in moves:
		var worst_back := INF
		var worst_up := -INF
		for pitch in [0.0, -45.0, -88.0]:
			_fresh()
			animator.first_person = true
			var inp := _input(m[1], m[4], deg_to_rad(pitch))
			inp.crouched = m[2]
			inp.flags = m[3]
			_run_view(inp, m[6], m[5])
			var neck := robot.marker("head")
			worst_back = minf(worst_back, neck.z)
			worst_up = maxf(worst_up, neck.y - m[5])
		_expect("%s: neck behind the eyes (%.2f m) and below them (%.2f m)" % [m[0], worst_back, -worst_up],
			worst_back > robot.chest_front - 0.05 and worst_up < -0.11)

	# Flips and the landing roll: the same animation name as everyone else sees, but
	# the body never turns upside down in front of the camera (which stays level).
	for flip in [[0, "flip_front"], [flip_b, "flip_back"]]:
		for view in [false, true]:
			_fresh()
			animator.first_person = view
			var inp := _input(S.FLIP, Vector3(0, 2, -9), 0.0)
			inp.flags = flip[0]
			_run_view(inp, 0.22, 1.6, view)
			var upright := robot.marker("head").y > robot.marker("hips").y
			if view:
				_expect("%s in first person: still called %s, and the body stays upright" % [flip[1], flip[1]],
					animator.source == flip[1] and upright)
			else:
				_expect("%s in third person: the body is upside down halfway" % flip[1], not upright)
	_fresh()
	animator.first_person = true
	_run_view(_input(S.SLIDE, Vector3(0, 0, -12), 0.0), 0.6, 1.0)
	var toes := minf(robot.marker("foot_l").z, robot.marker("foot_r").z)
	var feet_up := maxf(robot.marker("foot_l").y, robot.marker("foot_r").y)
	_expect("sliding: the legs are out in front, in view at eye level", toes < -0.7 and feet_up > 1.0 - 1.09 * -toes,
		"toes %.2f m ahead, %.2f m up" % [-toes, feet_up])

	# The torso stays upright under the camera instead of leaning with the aim.
	for view in [false, true]:
		_fresh()
		animator.first_person = view
		_run_view(_input(S.GROUND, Vector3.ZERO, deg_to_rad(-60.0)), 0.8, 1.6, view)
		var lean := absf(robot.marker("head").z - robot.marker("spine").z)
		if view:
			_expect("looking down in first person: the torso stays upright", lean < 0.05, "%.2f m" % lean)
		else:
			_expect("looking down in third person: the torso leans with the aim", lean > 0.1, "%.2f m" % lean)

	# Back to third person: the body returns to where everyone else sees it.
	animator.place_for_view(0.0, 1.6, 0.0)
	_expect("third person: the body is back in place and the first-person copy hidden",
		robot.position == Vector3.ZERO and not robot.view_mesh.visible)


func _triangles(mesh: Mesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		n += mesh.surface_get_array_index_len(i) / 3
	return n


## Like _run, also placing the body for the first-person camera each frame.
func _run_view(inp: RobotAnimInput, seconds: float, eye: float, view: bool = true) -> void:
	var t := 0.0
	while t < seconds:
		animator.update(1.0 / 60.0, inp, robot.global_transform)
		animator.place_for_view(1.0 if view else 0.0, eye, inp.pitch)
		t += 1.0 / 60.0



func _check_file(path: String, bones: Array, clips: Array) -> void:
	var rig := RobotRig.open(path)
	var missing_bones := bones.filter(func(b): return not rig.bones.has(b))
	var missing_clips := clips.filter(func(c): return not rig.has_clip(c))
	_expect("%s: all %d bones" % [path.get_file(), bones.size()], missing_bones.is_empty(), str(missing_bones))
	_expect("%s: all %d clips" % [path.get_file(), clips.size()], missing_clips.is_empty(), str(missing_clips))
	var empty := clips.filter(func(c): return rig.has_clip(c) and rig.length(c) <= 0.0)
	_expect("%s: no empty clips" % path.get_file(), empty.is_empty(), str(empty))


## A robot back in its starting state (one model, a new animator each time).
func _fresh() -> void:
	if robot == null:
		robot = RobotModel.new().setup(Characters.body(_character), Color(1, 0.3, 0.2), false, _weapon)
		root.add_child(robot)
	robot.position = Vector3.ZERO
	animator = RobotAnimator.new(robot)


func _drop_robot() -> void:
	if robot == null:
		return
	for i in robot.mesh.mesh.get_surface_count():   # headless Godot grumbles otherwise
		robot.mesh.set_surface_override_material(i, null)
	if robot.view_mesh:
		for i in robot.view_mesh.mesh.get_surface_count():
			robot.view_mesh.set_surface_override_material(i, null)
	robot.queue_free()
	robot = null


func _input(state: int, velocity: Vector3, pitch: float) -> RobotAnimInput:
	var inp := RobotAnimInput.new()
	inp.state = state
	inp.velocity = velocity
	inp.pitch = pitch
	return inp


func _run(inp: RobotAnimInput, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		animator.update(1.0 / 60.0, inp, robot.global_transform)
		t += 1.0 / 60.0


func _bone_y(bone: String) -> float:
	return robot.skeleton.get_bone_global_pose(robot.rig.bones[bone]).origin.y


## The head bone sits at the neck; the top of the head is about 0.26 m above it.
func _top() -> float:
	var pose := robot.skeleton.get_bone_global_pose(robot.rig.bones["head"])
	return (pose * Vector3(0, 0.26, 0)).y


func _lowest_foot() -> float:
	return minf(_bone_y("foot_l"), _bone_y("foot_r"))


func _highest_bone() -> float:
	var high := -INF
	for b in BODY_BONES:
		if b not in ["root", "muzzle", "grapple"]:
			high = maxf(high, _bone_y(b))
	return high


func _lowest_bone() -> float:
	var low := INF
	for b in BODY_BONES:
		if b not in ["root", "muzzle", "grapple"]:
			low = minf(low, _bone_y(b))
	return low


func _near(what: String, value: float, expected: float, tolerance: float) -> void:
	_expect("%s = %.2f (expected %.2f ± %.2f)" % [what, value, expected, tolerance], absf(value - expected) <= tolerance)


func _expect(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok or detail == "" else "  [" + detail + "]"])
	if not ok:
		failures += 1
