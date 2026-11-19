extends SceneTree
## Films a robot on the grappling hook's rope, frame by frame, to check how the body hangs
## (RopeSwing) without opening the game: the hook flies out, bites, pulls tight, the
## robot is reeled in and swings, and lets go. Seen from the side and from behind at
## once. The robot is moved by a copy of the rope's pull (Grapple), posed by
## the game's own animator, and the rope is the game's own (HookLine, HookRope). Used
## by tools/robot/rope_preview.sh.
##
##   godot --path . --script tools/robot/rope_preview.gd -- --out=DIR
##       [--scene=swing] (swing: reeled up to a hook ahead, a few shots on the way, let go on
##                        the way up; under: swinging to and fro under a hook, steering;
##                        player: reeled in to a player hooked; turn: aiming off to the side)
##       [--step=0.0166667] (game seconds a frame: 1/120 is half speed at 60 frames a second)
##       [--character=vanguard] [--weapon=pistol] [--color=r,g,b] [--still=SEC,SEC] (only these moments, as PNGs)
##
## Writes DIR/f_0001.png and so on.

const S := MovementController.State

var _out := "."
var _scene := "swing"
var _step := 1.0 / 60.0
var _character := "vanguard"
var _weapon := "pistol"
var _color := Color(0.95, 0.35, 0.25)
var _stills := PackedFloat64Array()

var _robot: RobotModel
var _animator: RobotAnimator
var _inp := RobotAnimInput.new()
var _line := HookLine.new()
var _rope: HookRope
var _tuning := MovementTuning.new()
var _cams: Array = []        # [Camera3D, offset from the robot]
var _focus := Vector3.ZERO

var _t := 0.0
var _frame := 0
var _warm := 6
var _pos := Vector3.ZERO     # the feet
var _vel := Vector3.ZERO
var _yaw := 0.0
var _anchor := Vector3.ZERO
var _fire_at := 0.15
var _bitten := false
var _taut := false
var _taut_at := INF
var _length := 0.0
var _cap := 0.0
var _released := false
var _release_at := INF       # seconds after the rope pulls tight (INF: when rising fast)
var _jump := true            # let go with a jump off the rope
var _shots := PackedFloat32Array()   # seconds after the rope pulls tight
var _steer := Vector3.ZERO   # held while on the rope (world)
var _aim_turn := 0.0         # the aim's yaw, from the way to the hook (degrees)
var _aim_ahead := false      # the aim stays where it was when the hook was fired
var _pump := false           # steering the way the swing is going, to work it up
var _end := 0.0              # seconds after letting go to film
var _target: Node3D          # the player hooked ("player")
var _target_vel := Vector3.ZERO
var _total := 6.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--scene="):
			_scene = arg.substr(8)
		elif arg.begins_with("--step="):
			_step = float(arg.substr(7))
		elif arg.begins_with("--character="):
			_character = arg.substr(12)
		elif arg.begins_with("--weapon="):
			_weapon = arg.substr(9)
		elif arg.begins_with("--color="):
			var c := arg.substr(8).split_floats(",")
			_color = Color(c[0], c[1], c[2])
		elif arg.begins_with("--still="):
			_stills = arg.substr(8).split_floats(",")
	_build_stage()
	match _scene:
		"under":
			_pos = Vector3(0, 5.0, 5.0)
			_vel = Vector3(0, -2.0, -9.0)
			_anchor = Vector3(0, 11.5, -1.0)
			_pump = true
			_aim_ahead = true
			_release_at = 6.0
			_jump = false
			_end = 0.6
		"player":
			_pos = Vector3(0, 0.0, 6.0)
			_vel = Vector3(0, 0.0, -6.0)
			_anchor = Vector3(2.0, 6.2, -12.0)
			_target_vel = Vector3(3.0, 0.0, 0.0)
			_release_at = 0.9
			_jump = false
			_end = 0.7
		"turn":
			_pos = Vector3(0, 3.0, 6.0)
			_vel = Vector3(0, 0.0, -7.0)
			_anchor = Vector3(0, 15.0, -14.0)
			_aim_turn = -75.0
			_shots = PackedFloat32Array([0.7, 0.85, 1.0])
			_end = 0.8
		_:
			_pos = Vector3(0, 3.0, 6.0)
			_vel = Vector3(0, 0.0, -7.0)
			_anchor = Vector3(0, 15.0, -14.0)
			_steer = Vector3(0, 0, -1)
			_shots = PackedFloat32Array([0.55, 0.7, 0.85])
			_end = 1.0
	_robot = RobotModel.new().build(_character, _color, false, _weapon)   # (a robot's id, or a Character Creator id: "custom:l=frog|t=human|back=cape")
	root.add_child(_robot)
	_animator = RobotAnimator.new(_robot)
	_rope = HookRope.new()
	root.add_child(_rope)
	_mark(_anchor, Color(1.0, 0.8, 0.2))
	if _scene == "player":
		var other := RobotModel.new().setup(Characters.body("kestrel"), Color(0.25, 0.5, 0.95), false, "pistol")
		root.add_child(other)
		other.position = _anchor - Vector3(0, RopeSwing.ATTACH, 0)
		_target = other
	_inp.state = S.AIR
	_focus = _pos
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	if _warm > 0:
		_warm -= 1
		_advance(0.0)
		return false
	var wanted := _stills.is_empty()
	for s in _stills:
		if absf(_t - s) < _step * 0.5:
			wanted = true
	if wanted:
		_frame += 1
		root.get_texture().get_image().save_png("%s/f_%04d.png" % [_out, _frame])
	if _t >= _total:
		print("saved %d frames in %s" % [_frame, _out])
		return true
	_advance(_step)
	return false


func _advance(dt: float) -> void:
	_t += dt
	var chest := _pos + Vector3(0, RopeSwing.ATTACH, 0)
	var eye := _pos + Vector3(0, MovementTuning.EYE_HEIGHT, 0)
	if _target:
		_target.position += _target_vel * dt
		_anchor = _target.position + Vector3(0, RopeSwing.ATTACH, 0)
		if _bitten:
			_line.anchor = _anchor
	var to_hook := _anchor - chest
	# The aim: at the hook as it is fired, then wherever the scene looks.
	if not _bitten:
		_yaw = atan2(-to_hook.x, -to_hook.z)
	else:
		_yaw = lerp_angle(_yaw, atan2(-to_hook.x, -to_hook.z) + deg_to_rad(_aim_turn) if not _released and not _aim_ahead else _yaw, minf(dt * 6.0, 1.0))
	# The hook: out, bite, slack in, tight.
	if _line.seq == 0 and _t >= _fire_at:
		_line.launch(1, _t, eye, (_anchor - eye).normalized() * HookLine.SPEED)
	if _line.seq != 0 and not _bitten and _line.travel(_t) >= eye.distance_to(_anchor) - 0.01:
		_bitten = true
		var when := _line.t_launch + eye.distance_to(_anchor) / HookLine.SPEED
		_line.bite(when, _anchor, chest.distance_to(_anchor) + HookLine.flight_slack(eye.distance_to(_anchor)), 7 if _target else 0)
	var yanked := false
	if _bitten and not _taut and not _released and _line.rope - HookLine.reeled(_t - _line.t_stop) <= chest.distance_to(_anchor):
		_taut = true
		_taut_at = _t
		_length = maxf(chest.distance_to(_anchor), _tuning.grapple_min_length)
		_line.pull_taut(_t)
		yanked = true
		_total = _t + (_release_at if _release_at != INF else 4.0) + _end
	# The body: gravity, and on the rope its pull (as Grapple does it).
	var on := _taut and not _released
	_vel.y -= _tuning.gravity * dt
	if on:
		if yanked:
			_cap = maxf(_vel.length(), _tuning.grapple_pull_speed)
			_vel = _toward(chest, _vel, _tuning.grapple_yank)
			if _target == null and _anchor.y > chest.y and _vel.y < _tuning.grapple_lift_max:
				_vel.y = minf(_vel.y + _tuning.grapple_yank_lift, _tuning.grapple_lift_max)
		if _target:
			var dir := to_hook.normalized()
			var room := _tuning.tether_pull_speed - _vel.dot(dir)
			if room > 0.0:
				_vel += dir * minf(_tuning.tether_pull_accel * dt, room)
			_vel.y += _tuning.gravity * 0.6 * dt
		else:
			_vel = _toward(chest, _vel, _tuning.grapple_pull_accel * dt)
			if to_hook.y > 0.0 and _vel.y < _tuning.grapple_lift_max:
				var fade := clampf((to_hook.length() - _tuning.grapple_min_length) / (_tuning.grapple_pull_stop - _tuning.grapple_min_length), 0.0, 1.0)
				_vel.y = minf(_vel.y + _tuning.grapple_pull_lift * fade * dt, _tuning.grapple_lift_max)
			if _pump:
				_steer = Vector3(0, 0, -1.0 if _vel.z <= 0.0 else 1.0)
			var push := _steer
			if push != Vector3.ZERO:
				var add := _tuning.air_speed - _vel.dot(push)
				if add > 0.0:
					_vel += push * minf(_tuning.grapple_air_accel * _tuning.air_speed * dt, add)
			_length = clampf(minf(_length, to_hook.length()), _tuning.grapple_min_length, _length)
			var out := (chest + _vel * dt) - _anchor
			if out.length() > _length and _vel.dot(out.normalized()) > 0.0:
				_vel -= out.normalized() * _vel.dot(out.normalized())
		var since := _t - _taut_at
		for s in _shots:
			if since >= s and since - dt < s:
				_animator.fire()
		var let_go := since >= _release_at if _release_at != INF else (since > 0.5 and (_vel.y >= 9.5 or to_hook.length() < 3.0 or since > 4.0) and _vel.y > 0.0)
		if _target and to_hook.length() < 1.6:
			let_go = true
		if let_go:
			_released = true
			if _jump:
				_vel.y = maxf(_vel.y, 0.0) + _tuning.grapple_jump_boost
			_line.let_go(_t, HookLine.back_time_for(to_hook.length()), HookLine.LIMP * to_hook.length())
			_total = _t + _end
			print("let go at %.2f s: rising %.1f, speed %.1f m/s" % [_t, _vel.y, _vel.length()])
	_pos += _vel * dt
	if on and _target == null:
		var off := _pos + Vector3(0, RopeSwing.ATTACH, 0) - _anchor
		if off.length() > _length:
			_pos -= off.normalized() * (off.length() - _length)
	if _pos.y < 0.0:
		_pos.y = 0.0
		_vel.y = 0.0
	# What the animator is told (as Player tells it).
	chest = _pos + Vector3(0, RopeSwing.ATTACH, 0)
	_robot.position = _pos
	_robot.rotation.y = _yaw
	var look := _line.look(_t, chest, chest)
	_inp.state = S.GRAPPLE if on else (S.GROUND if _pos.y <= 0.0 else S.AIR)
	_inp.velocity = _vel
	_inp.yaw = _yaw
	_inp.pitch = clampf(asin(clampf(to_hook.normalized().y, -1.0, 1.0)), -1.2, 1.2) * (0.6 if not _released and not (_aim_ahead and _taut) else 0.0)
	_inp.flags = RobotAnimInput.make_flags(false, false, false, 0, 0, 0, 0, false, 0, false, false, 0, on and _steer != Vector3.ZERO)
	_inp.grapple_on = not look.is_empty()
	if not look.is_empty():
		_inp.grapple_anchor = look[1]
	_inp.set_hook(look)
	var rolling := _animator.rope.flip() >= 0.0
	_animator.update(dt, _inp, _robot.global_transform)
	if _animator.rope.flip() >= 0.0 and not rolling:
		print("roll at %.2f s" % _t)
	if _taut and absf(_t - _taut_at) < 1e-6:
		print("tight at %.2f s: jolt %.2f" % [_t, _animator.rope.jolted])
	_rope.show_look(_robot.marker("grapple"), _line.look(_t, _robot.marker("grapple"), chest))
	if look.is_empty():
		_rope.hide_line()
	# The cameras follow, a little behind the body, so its own movement shows.
	_focus = _focus.lerp(_pos, 1.0 - exp(-dt * 20.0)) if dt > 0.0 else _pos
	for c in _cams:
		var cam: Camera3D = c[0]
		cam.look_at_from_position(_focus + Vector3(0, 1.1, 0) + (c[1] as Vector3), _focus + Vector3(0, 1.1, 0))


func _toward(chest: Vector3, vel: Vector3, amount: float) -> Vector3:
	var to := _anchor - chest
	var dist := to.length()
	if dist < 0.01 or amount <= 0.0:
		return vel
	var dir := to / dist
	var fade := clampf((dist - _tuning.grapple_min_length) / maxf(_tuning.grapple_pull_stop - _tuning.grapple_min_length, 0.01), 0.0, 1.0)
	var room := _tuning.grapple_pull_speed * fade - vel.dot(dir)
	if room <= 0.0:
		return vel
	var out := vel + dir * minf(amount, room)
	var top := maxf(_cap, vel.length())
	if out.length() > top:
		out = out.normalized() * top
	return out


func _mark(at: Vector3, color: Color) -> void:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	sphere.material = mat
	ball.mesh = sphere
	ball.position = at
	root.add_child(ball)


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.39, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.90)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -150, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.37)
	mat.roughness = 0.9
	plane.material = mat
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	# Posts every few metres, so the body's own movement can be seen against something.
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.42, 0.45, 0.52)
	for i in range(-12, 13):
		for x in [-6.0, 6.0]:
			var post := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 24.0, 0.3)
			box.material = post_mat
			post.mesh = box
			post.position = Vector3(x, 12.0, i * 4.0)
			root.add_child(post)
	# Two views side by side: from the side, and from behind and above the shoulder.
	var size := Vector2(DisplayServer.window_get_size())
	for view in [[Vector3(4.6, 0.3, 0.0), 0], [Vector3(1.5, 1.0, 3.8), 1]]:
		var box := SubViewportContainer.new()
		box.stretch = true
		box.position = Vector2(size.x / 2.0 * int(view[1]), 0)
		box.size = Vector2(size.x / 2.0, size.y)
		root.add_child(box)
		var port := SubViewport.new()
		port.world_3d = root.world_3d
		port.msaa_3d = Viewport.MSAA_4X
		box.add_child(port)
		var cam := Camera3D.new()
		cam.fov = 52.0
		port.add_child(cam)
		cam.make_current()
		_cams.append([cam, view[0]])
