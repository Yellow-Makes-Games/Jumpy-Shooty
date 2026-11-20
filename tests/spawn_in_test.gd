extends SceneTree
## A body arriving (SpawnIn), and the boot-up kneel under it (RobotAnimator). Looks only.
## Run: godot --headless --fixed-fps 60 --path . --script tests/spawn_in_test.gd
##
## From its first frame every mesh of the body has the layer of light on, all light; the
## line climbs for SpawnIn.TIME and follows the feet; a mesh that turns up part of the
## way through is taken in; one that has a layer of its own is left alone; when it is
## over (or cut short) every layer is off again. The kneel plays for a body that stands
## where it arrives, and is dropped at once by one that moves off, jumps or shoots.

const S := MovementController.State
const STEP := 1.0 / 60.0

var failures := 0
var robot: RobotModel
var animator: RobotAnimator
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_checks()
	print("SPAWN IN TEST PASSED" if failures == 0 else "SPAWN IN TEST FAILED: %d" % failures)
	_drop()
	quit(1 if failures else 0)
	_done = true
	return false


func _checks() -> void:
	print("The light")
	_fresh()
	var meshes := robot.find_children("*", "MeshInstance3D", true, false)
	var own := MeshInstance3D.new()   # something with a layer of its own
	var mine := StandardMaterial3D.new()
	own.material_overlay = mine
	robot.add_child(own)
	var s := SpawnIn.start(Color(1.0, 0.4, 0.2))
	_expect("it starts all light", s.progress() == 0.0)
	_expect("...on every mesh of the body from the first frame (%d of %d)" % [s.covered() if s.update(0.0, robot, 3.0) else -1, meshes.size()],
		s.covered() == meshes.size() and meshes.size() >= 1)
	var layer := (meshes[0] as MeshInstance3D).material_overlay as ShaderMaterial
	_expect("...a layer over its own materials, which stay as they are", layer != null and layer.shader == SpawnIn.SHADER
		and (meshes[0] as MeshInstance3D).get_surface_override_material(0) == null and (meshes[0] as MeshInstance3D).material_override == null)
	_expect("...and not over a mesh that has a layer of its own", own.material_overlay == mine)
	_expect("the line starts at the feet", is_equal_approx(float(layer.get_shader_parameter("feet")), 3.0) and float(layer.get_shader_parameter("progress")) == 0.0)
	var going := true
	for i in 12:
		going = s.update(STEP, robot, 3.5)
	_expect("half way: the line half way up, following the feet", going and absf(s.progress() - 0.5) < 0.05
		and absf(float(layer.get_shader_parameter("progress")) - 0.5) < 0.05 and is_equal_approx(float(layer.get_shader_parameter("feet")), 3.5), "%.2f" % s.progress())
	var late := MeshInstance3D.new()   # a weapon handed over as it arrives
	late.mesh = BoxMesh.new()
	robot.add_child(late)
	s.update(STEP, robot, 3.5)
	_expect("a mesh that turns up part of the way through is taken in", late.material_overlay == layer)
	var steps := 0
	while s.update(STEP, robot, 3.5) and steps < 200:
		steps += 1
	_expect("it is over in %.1f s" % SpawnIn.TIME, absf((steps + 14) * STEP - SpawnIn.TIME) < 0.05, "%.2f s" % ((steps + 14) * STEP))
	var left := 0
	for m in meshes + [late]:
		if (m as MeshInstance3D).material_overlay != null:
			left += 1
	_expect("...and every layer is off again", left == 0 and s.covered() == 0, "%d left" % left)
	_expect("...but not the one that was not its own", own.material_overlay == mine)
	s = SpawnIn.start(Color.WHITE)
	s.update(0.1, robot, 0.0)
	s.stop()
	_expect("cut short (a death): off at once", (meshes[0] as MeshInstance3D).material_overlay == null and not s.update(STEP, robot, 0.0))
	var arms := SpawnIn.start(Color.WHITE)
	var view := MeshInstance3D.new()
	view.mesh = BoxMesh.new()
	root.add_child(view)
	arms.update(0.0, robot, 0.0, view)
	var arm_layer := view.material_overlay as ShaderMaterial
	_expect("your own arms get a layer of their own, drawn as they are drawn", arm_layer != null and arm_layer != (meshes[0] as MeshInstance3D).material_overlay
		and bool(arm_layer.get_shader_parameter("view_model")) and is_equal_approx(float(arm_layer.get_shader_parameter("view_fov")), SpawnIn.VIEW_FOV))
	arms.stop()
	view.queue_free()
	own.queue_free()
	late.queue_free()

	print("The kneel")
	_fresh()
	var stand := _input(S.GROUND, Vector3.ZERO)
	_run(stand, 0.6)
	var up := _at("hips").y
	animator.respawn()
	_run(stand, 0.1)
	_expect("standing where it arrives: it kneels, head down", _at("hips").y < up - 0.15 and animator._respawn_t >= 0.0, "%.2f against %.2f" % [_at("hips").y, up])
	_run(stand, 0.8)
	_expect("...and is up again", absf(_at("hips").y - up) < 0.03 and animator._respawn_t < 0.0, "%.2f" % _at("hips").y)
	for how in ["running off", "jumping", "shooting"]:
		_fresh()
		_run(stand, 0.3)
		animator.respawn()
		_run(stand, 0.05)
		var inp := stand
		if how == "running off":
			inp = _input(S.GROUND, Vector3(0, 0, -7))
		elif how == "jumping":
			inp = _input(S.AIR, Vector3(0, 6, 0))
		else:
			animator.fire()
		_run(inp, 0.12)
		_expect("%s: the kneel is dropped at once" % how, animator._respawn_w == 0.0 and animator._respawn_cut, "%.2f" % animator._respawn_w)
		_run(stand, 0.3)
		_expect("...and does not come back", animator._respawn_t < 0.0 and absf(_at("hips").y - up) < 0.06, "%.2f against %.2f" % [_at("hips").y, up])


func _at(bone: String) -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.rig.bones[bone]).origin


func _fresh() -> void:
	if robot == null:
		robot = RobotModel.new().setup(Characters.body(Characters.default_id()), Color(1, 0.3, 0.2), false, "rifle")
		root.add_child(robot)
	robot.position = Vector3.ZERO
	robot.rotation = Vector3.ZERO
	animator = RobotAnimator.new(robot)


func _drop() -> void:
	if robot == null:
		return
	for i in robot.mesh.mesh.get_surface_count():   # headless Godot grumbles otherwise
		robot.mesh.set_surface_override_material(i, null)
	robot.queue_free()
	robot = null


func _input(state: int, velocity: Vector3) -> RobotAnimInput:
	var inp := RobotAnimInput.new()
	inp.state = state
	inp.velocity = velocity
	return inp


func _run(inp: RobotAnimInput, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		animator.update(STEP, inp, robot.global_transform)
		t += STEP


func _expect(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok or detail == "" else "  [" + detail + "]"])
	if not ok:
		failures += 1
