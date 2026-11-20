extends SceneTree
## Headless checks on how blasts look (BlastFx).
## Run: godot --headless --fixed-fps 60 --path . --script tests/blast_fx_test.gd
##
## Every explosive weapon has a style of its own. A blast on the floor is thrown up off
## it, with a ring and dust; one against a wall is thrown out from the wall; one in the
## air is round, with no ring (but plasma's). Each is a handful of particle bursts and
## one light, sharing a few materials made once, and is gone LIFE seconds later.

var failures := 0


func _init() -> void:
	_start.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _start() -> void:
	BlastFx.headless_too = true
	var world := Node3D.new()
	root.add_child(world)
	# A floor, and a wall facing +X.
	for box: Array in [[Vector3(40, 1, 40), Vector3(0, -0.5, 0)], [Vector3(1, 6, 10), Vector3(-10.5, 3, 0)]]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = box[0]
		body.add_child(shape)
		world.add_child(body)
		body.global_position = box[1]
	await physics_frame
	await physics_frame

	for id in ["rocket_launcher", "grenade_launcher", "mortar", "flare_gun", "plasma_cannon"]:
		var w := WeaponData.by_id(id)
		_check(w.explosive and BlastFx.STYLES.has(w.look()), "%s blows up in a style of its own (%s)" % [id, w.look()])

	# On the floor.
	ShotFx.explosion(world, Vector3(0, 0.05, 0), 4.5, "rocket")
	var blast := _last_blast(world)
	_check(blast != null, "a rocket on the floor makes a blast")
	if blast:
		_check(blast.global_transform.basis.y.dot(Vector3.UP) > 0.99, "  thrown up off the floor")
		var bursts := blast.find_children("*", "CPUParticles3D", false, false)
		_check(bursts.size() >= 4 and bursts.size() <= 6, "  a handful of particle bursts (%d)" % bursts.size())
		var total := 0
		for p: CPUParticles3D in bursts:
			total += p.amount
			_check(p.one_shot and p.emitting and p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "  a burst of %d: one shot, no shadow" % p.amount)
		_check(total <= 120, "  at most 120 particles in all (%d)" % total)
		var lights := blast.find_children("*", "OmniLight3D", false, false)
		_check(lights.size() == 1 and not (lights[0] as OmniLight3D).shadow_enabled, "  one light, without shadows")
		_check(blast.find_children("*", "MeshInstance3D", false, false).size() == 2, "  a flash and a ring")

	# Against the wall: thrown out from it (+X).
	ShotFx.explosion(world, Vector3(-9.95, 2.0, 0), 3.6, "grenade")
	blast = _last_blast(world)
	_check(blast != null and blast.global_transform.basis.y.dot(Vector3.RIGHT) > 0.99, "a grenade on a wall is thrown out from it")

	# In the air: round, no ring; plasma keeps its ring.
	ShotFx.explosion(world, Vector3(0, 5, 0), 4.5, "rocket")
	blast = _last_blast(world)
	_check(blast != null and blast.find_children("*", "MeshInstance3D", false, false).size() == 1, "a rocket in the air: a flash, no ring")
	ShotFx.explosion(world, Vector3(3, 5, 0), 3.0, "orb")
	blast = _last_blast(world)
	_check(blast != null and blast.find_children("*", "MeshInstance3D", false, false).size() == 2, "plasma in the air keeps its ring")
	_check(blast != null and blast.find_children("*", "CPUParticles3D", false, false).size() == 2, "  and has no smoke (fire and sparks only)")

	# Shared, not made per blast.
	var a: Array = _last_blasts(world, 2)
	var mats := {}
	for b: Node in a:
		for p: CPUParticles3D in b.find_children("*", "CPUParticles3D", false, false):
			mats[p.material_override] = true
	_check(mats.size() <= 3, "blasts share their particle materials (%d between two)" % mats.size())

	# Cheap to make once warm.
	var stage := Node3D.new()
	world.add_child(stage)
	BlastFx.warm(stage)
	var t := Time.get_ticks_usec()
	for i in 20:
		ShotFx.explosion(world, Vector3(i, 0.05, 5), 4.5, ["rocket", "grenade", "shell", "flare", "orb"][i % 5])
	var each := (Time.get_ticks_usec() - t) / 20.0
	_check(each < 3000.0, "a blast takes %.2f ms to make (under 3)" % (each / 1000.0))

	# Gone in LIFE seconds.
	var before := _blasts(world).size()
	var waited := 0.0
	while waited < BlastFx.LIFE + 0.3:
		await process_frame
		waited += 1.0 / 60.0
	_check(before > 0 and _blasts(world).size() == 0, "every blast is gone %.1f s later (%d were there)" % [BlastFx.LIFE, before])

	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures else 0)


func _blasts(world: Node) -> Array:
	return world.find_children("Blast*", "Node3D", true, false)


func _last_blast(world: Node) -> Node3D:
	var all := _blasts(world)
	return all[-1] if not all.is_empty() else null


func _last_blasts(world: Node, n: int) -> Array:
	var all := _blasts(world)
	return all.slice(maxi(all.size() - n, 0))
