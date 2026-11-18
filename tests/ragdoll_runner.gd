extends Node
## Ragdoll checks (started by tests/ragdoll_test.gd, run with --fixed-fps 60):
##  - every character (each robot, a custom one with a kit's torso and one with
##    accessories) makes a ragdoll on the normal render layer, starting in the dead
##    body's pose; thrown along the shot over a floor, after 2 s nothing is NaN, every
##    bone is above the floor, it has come to rest, and its elbows and knees bend the
##    right way; a blast throws it away from where it went off;
##  - one lasts Remains.LIFETIME from the death, dissolving at the end, whether or not
##    its player has respawned (dying again leaves a second one), and after its player
##    has left; at most Remains.MAX_BODIES at once; a map change takes them all;
##  - none with gore off, without an arena, or for a model without the bones.

const FLOOR_Y := 0.0
const FPS := 60
## The body's bones (not the gun's or the markers): none may end up under the floor.
const BODY_BONES := ["hips", "spine", "chest", "head", "upper_arm_l", "forearm_l", "hand_l",
	"upper_arm_r", "forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]

var _fails: Array[String] = []
var _arena: Node3D
var _frame := 0


func run() -> void:
	await get_tree().process_frame
	print("Ragdoll checks")
	Net.start_offline("Tester", "needle", "pistol")
	Settings.gore = "full"
	_make_arena()
	await _every_character()
	await _blast()
	await _melee()
	await _lifetime()
	await _cap()
	await _refusals()
	_arena.queue_free()
	await get_tree().process_frame
	_expect(Remains.count() == 0, "a map change takes the remains with it")
	Net.arena = null
	Net.leave()
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _process(_delta: float) -> void:
	_frame += 1


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## An arena with a wide floor whose top is at FLOOR_Y.
func _make_arena() -> void:
	_arena = Node3D.new()
	_arena.name = "TestArena"
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = FLOOR_Y - 0.5
	_arena.add_child(ground)
	get_tree().root.add_child(_arena)
	Net.arena = _arena


## A dead body to make remains of: a player's model only (no movement, input or
## network), posed mid-run.
func _player(id: int, character: String, at: Vector3, yaw: float = 0.0, gun: String = "rifle") -> Player:
	var p := Player.new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.peer_id = id
	p.character = character
	p.visual = Node3D.new()
	p.add_child(p.visual)
	p.robot = RobotModel.new().build(character, Net.player_color(id), false, gun)
	p.visual.add_child(p.robot)
	_arena.add_child(p)
	p.global_position = at
	p.visual.rotation.y = yaw
	var pose := p.robot.rig.new_pose()
	p.robot.rig.sample(pose, "run", 0.3)
	pose.apply(p.robot.skeleton)
	return p


## A test body gone (its player left).
func _drop(p: Player) -> void:
	for i in p.robot.mesh.get_surface_override_material_count():   # headless Godot grumbles otherwise
		p.robot.mesh.set_surface_override_material(i, null)
	p.queue_free()


func _ragdolls() -> Array:
	return _arena.get_children().filter(func(n): return n is Ragdoll and not n.is_queued_for_deletion())


func _every_character() -> void:
	print("  every character")
	var characters: Array = Characters.ids() + ["custom:n=Kit|l=frog|t=human|h=goblin",
		"custom:n=Mix|l=bulwark|t=templar|h=orbit|hat=top_hat|back=cape"]
	var made := []   # [character, player, ragdoll, start]
	var x := 0.0
	for c in characters:
		var p := _player(1, c, Vector3(x, FLOOR_Y + 0.3, 0.0), 0.6)
		p.velocity = Vector3(0, 0, -3)
		var r := Ragdoll.spawn(p, {"push": Vector3.ZERO, "dir": Vector3(1, 0, 0), "head": true}) as Ragdoll
		_expect(r != null, "%s: makes a ragdoll" % c)
		if r == null:
			continue
		var off := 0.0
		for b in r.bodies():
			var want: Transform3D = p.robot.skeleton.global_transform * p.robot.skeleton.get_bone_global_pose(b.get_bone_id()) * b.body_offset
			off = maxf(off, b.global_position.distance_to(want.origin))
		_expect(r.bodies().size() == Ragdoll.PARTS.size() and off < 0.01,
			"%s: %d bodies, each starting where the dead body's bone was (%.3f m off)" % [c, r.bodies().size(), off])
		_expect(r.model.mesh.layers == 1 and r.get_parent() == _arena, "%s: in the arena, on the normal render layer" % c)
		made.append([c, p, r, r.bodies()[0].global_position])
		x += 4.0
	await _frames(2 * FPS)
	for m in made:
		var c: String = m[0]
		var r: Ragdoll = m[2]
		var sk := r.model.skeleton
		var drawn: Array = await _drawn_bones(sk)
		var finite := drawn.size() == sk.get_bone_count()
		var lowest := INF
		var fastest := 0.0
		for i in drawn.size():
			var g: Transform3D = drawn[i]
			if not (g.origin.is_finite() and g.basis.x.is_finite() and g.basis.y.is_finite()):
				finite = false
			if sk.get_bone_name(i) in BODY_BONES:
				lowest = minf(lowest, g.origin.y)
		var follows := 0.0   # how far the drawn bones are from their bodies
		for b in r.bodies():
			fastest = maxf(fastest, b.linear_velocity.length())
			if drawn.size() > b.get_bone_id():
				follows = maxf(follows, (drawn[b.get_bone_id()] as Transform3D).origin.distance_to((b.global_transform * b.body_offset.affine_inverse()).origin))
		_expect(finite, "%s: no NaN in any bone after 2 s" % c)
		_expect(follows < 0.02, "%s: the model is drawn where its bodies are (%.3f m off)" % [c, follows])
		_expect(lowest > FLOOR_Y - 0.02, "%s: every bone above the floor (lowest %.3f m)" % [c, lowest])
		_expect(fastest < 0.3, "%s: come to rest (fastest part %.2f m/s)" % [c, fastest])
		var hips: Vector3 = r.bodies()[0].global_position
		_expect(hips.x - (m[3] as Vector3).x > 0.3, "%s: thrown along the shot (%.2f m)" % [c, hips.x - (m[3] as Vector3).x])
		_expect(_bends(r), "%s: elbows and knees bend the right way (%s)" % [c, _bend_text(r)])
		_drop(m[1])
		r.queue_free()
	await get_tree().process_frame


## Every bone's place in the world as drawn: the physics' pose, which a skeleton
## holds only while it updates (its modifiers' work is undone after each frame).
func _drawn_bones(sk: Skeleton3D) -> Array:
	var out := []
	var grab := func():
		if out.is_empty():
			for i in sk.get_bone_count():
				out.append(sk.global_transform * sk.get_bone_global_pose(i))
	sk.skeleton_updated.connect(grab)
	await _frames(2)
	sk.skeleton_updated.disconnect(grab)
	return out


## Degrees each elbow and knee is bent about its bone's x axis (+ forward).
func _bend_angles(r: Ragdoll) -> Dictionary:
	var by := {}
	for b in r.bodies():
		by[b.bone_name] = b
	var out := {}
	for pair in [["upper_arm_l", "forearm_l"], ["upper_arm_r", "forearm_r"], ["thigh_l", "shin_l"], ["thigh_r", "shin_r"]]:
		var rel := Quaternion((by[pair[0]] as PhysicalBone3D).global_basis.orthonormalized().inverse() * (by[pair[1]] as PhysicalBone3D).global_basis.orthonormalized())
		out[pair[1]] = rad_to_deg(2.0 * atan2(rel.x, rel.w))
	return out


func _bends(r: Ragdoll) -> bool:
	var a := _bend_angles(r)
	return a.forearm_l > -10.0 and a.forearm_r > -10.0 and a.forearm_l < 145.0 and a.forearm_r < 145.0 \
		and a.shin_l < 10.0 and a.shin_r < 10.0 and a.shin_l > -145.0 and a.shin_r > -145.0


func _bend_text(r: Ragdoll) -> String:
	var a := _bend_angles(r)
	return "elbows %.0f %.0f, knees %.0f %.0f" % [a.forearm_l, a.forearm_r, a.shin_l, a.shin_r]


func _blast() -> void:
	print("  a blast")
	var p := _player(1, "rivet", Vector3(0, FLOOR_Y + 0.05, 20.0))
	var at := p.global_position + Vector3(0, 0.6, -1.2)
	var r := Ragdoll.spawn(p, {"push": Vector3.ZERO, "dir": Vector3(0, 0, 1), "at": at}) as Ragdoll
	var start: Vector3 = r.bodies()[2].global_position
	await _frames(FPS / 2)
	var moved: Vector3 = r.bodies()[2].global_position - start
	_expect(moved.z > 0.5, "thrown away from the blast (%.2f m)" % moved.z)
	_drop(p)
	r.queue_free()
	await get_tree().process_frame


func _melee() -> void:
	print("  a blade")
	var p := _player(1, "templar", Vector3(0, FLOOR_Y + 0.05, 30.0), 0.0, "sword")
	var r := Ragdoll.spawn(p, {"dir": Vector3(1, 0, 0)}) as Ragdoll
	_expect(r.model.melee != null, "the ragdoll holds the dead body's sword")
	await _frames(FPS)
	var drawn: Array = await _drawn_bones(r.model.skeleton)
	var grip: Vector3 = (drawn[r.model.skeleton.find_bone("pistol")] as Transform3D).origin
	var off := r.model.melee.global_position.distance_to(grip)
	_expect(off < 0.02, "...still in its fist as it falls (%.3f m off)" % off)
	_drop(p)
	r.queue_free()
	await get_tree().process_frame


func _lifetime() -> void:
	print("  lifetime")
	var p := _player(2, "vanguard", Vector3(0, FLOOR_Y, -20.0))
	var before := _ragdolls().size()
	_expect(Remains.spawn(p, {"dir": Vector3(0, 0, -1)}), "Remains makes a ragdoll for a death")
	var first: Ragdoll = _ragdolls()[-1]
	_expect(_ragdolls().size() == before + 1, "...one")
	var born := _frame
	await _frames(4 * FPS)
	# Back in the game (what respawn_at does to the body), then knocked out again.
	p.visual.visible = true
	p.global_position = Vector3(6, FLOOR_Y, -20.0)
	await _frames(2 * FPS)
	_expect(is_instance_valid(first), "it stays after its player has respawned")
	_expect(Remains.spawn(p, {}), "dying again makes another")
	var second: Ragdoll = _ragdolls()[-1]
	_expect(second != first and _ragdolls().size() == before + 2, "...so there are two")
	while is_instance_valid(first) and first.age() < Remains.LIFETIME - Remains.DISSOLVE_TIME * 0.5:
		await get_tree().process_frame
	var mat := first.model.mesh.get_surface_override_material(0)
	_expect(mat is ShaderMaterial and (mat as ShaderMaterial).shader == Dissolve.SHADER, "it is dissolving near the end")
	var progress: float = (mat as ShaderMaterial).get_shader_parameter("progress") if mat is ShaderMaterial else 0.0
	_expect(absf(progress - 0.5) < 0.05, "...halfway through, half gone (%.2f)" % progress)
	while is_instance_valid(first):
		await get_tree().process_frame
	var lasted := float(_frame - born) / FPS
	_expect(absf(lasted - Remains.LIFETIME) <= 2.5 / FPS, "it lasted %.0f s from the death (%.3f s)" % [Remains.LIFETIME, lasted])
	_expect(is_instance_valid(second), "the second is still there")
	_drop(p)   # its player leaves
	await _frames(FPS)
	_expect(is_instance_valid(second), "it stays after its player has left")
	while is_instance_valid(second):
		await get_tree().process_frame
	_expect(true, "...and goes in its own time")


func _cap() -> void:
	print("  at most %d" % Remains.MAX_BODIES)
	var players := []
	for i in Remains.MAX_BODIES + 3:
		var p := _player(10 + i, Characters.ids()[i % Characters.ids().size()], Vector3(i * 2.0, FLOOR_Y, 40.0))
		players.append(p)
		Remains.spawn(p, {})
		await get_tree().process_frame
	_expect(Remains.count() == Remains.MAX_BODIES and _ragdolls().size() == Remains.MAX_BODIES,
		"%d deaths leave %d ragdolls (%d)" % [Remains.MAX_BODIES + 3, Remains.MAX_BODIES, _ragdolls().size()])
	for p in players:
		_drop(p)


func _refusals() -> void:
	print("  none")
	var p := _player(30, "orbit", Vector3(0, FLOOR_Y, 60.0))
	var before := Remains.count()
	Settings.gore = "off"
	_expect(not Remains.spawn(p, {}) and Remains.count() == before, "with Settings.gore off")
	Settings.gore = "ragdolls"
	_expect(Remains.spawn(p, {"gib": true}), "gore set to ragdolls only: a ragdoll even for a body blown apart")
	Settings.gore = "full"
	Match.death_cause[30] = "fell"
	_expect(not Remains.spawn(p, {}), "for a fall out of the arena")
	Match.death_cause.erase(30)
	Net.arena = null
	_expect(Ragdoll.spawn(p, {}) == null, "without an arena")
	Net.arena = _arena
	var bare := RobotRig.new()
	_expect(Ragdoll._plan(bare).is_empty(), "for a skeleton without the bones")
	var robot := p.robot
	p.robot = null
	_expect(Ragdoll.spawn(p, {}) == null, "for a player without a model")
	p.robot = robot
	_drop(p)
	await get_tree().process_frame
