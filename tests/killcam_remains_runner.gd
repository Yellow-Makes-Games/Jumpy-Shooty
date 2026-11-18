extends Node
## Remains in killcams (started by tests/killcam_remains_test.gd, run with --fixed-fps 60):
##  - a dead body hidden by its remains still counts as drawn in the recording;
##  - Killcam records a ragdoll's and giblets' fall (KillClip.Wreck) from the moment of
##    the death, with how the blow fell, for WRECK_FOR seconds; a clip keeps the ones
##    lying about during it; after the match it keeps recording a fall until it is done;
##  - a replay shows the victim until the kill, then the replay's own ragdoll (or
##    giblets) in the body's place, posed from the recording on the replay's clock (in
##    slow motion, and stepped by hand as for a video, too), turning the third-person
##    camera towards it; the live remains and Remains' count are left alone; the
##    replay's remains go when it starts over and when it ends;
##  - gore off: no remains in the replay, the body stays (playing its death); "ragdolls
##    only": no giblets either.

const FLOOR_Y := 0.0
const VICTIM := 9001
const AT := Vector3(0, 0, -10)   ## where the victim stands, 10 m in front of the killer
const STEP := 1.0 / 60.0

var _fails: Array[String] = []
var _arena: Node3D
var _now := 100.0   # Killcam's clock, for recording by hand


func run() -> void:
	await get_tree().process_frame
	print("Killcam remains checks")
	Net.start_offline("Tester", "needle", "pistol")
	Settings.gore = "full"
	_make_arena()
	_drawn()
	var rag := await _record({"push": Vector3.ZERO, "dir": Vector3(0, 0, -1), "head": true})
	var gib := await _record({"push": Vector3(0, 2, -6), "dir": Vector3(0, 0, -1), "gib": true})
	if rag.is_empty() or gib.is_empty():
		_expect(false, "recordings to play")
	else:
		_clips(rag[0])
		await _replay_ragdoll(rag[0], rag[1])
		await _replay_gibs(gib[0], gib[1])
		await _gore(rag[0], gib[0])
	await _after_match()
	Killcam._wrecks.clear()
	Killcam._wreck_of.clear()
	Settings.gore = "full"
	_arena.queue_free()
	await get_tree().process_frame
	Net.arena = null
	Net.leave()
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _expect(ok: bool, what: String) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


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


## A dead body to make remains of: a player's model only, facing the killer (+z).
func _player(id: int, at: Vector3) -> Player:
	var p := Player.new()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.peer_id = id
	p.character = "needle"
	p.visual = Node3D.new()
	p.add_child(p.visual)
	p.robot = RobotModel.new().build("needle", Net.player_color(id), false, "pistol")
	p.visual.add_child(p.robot)
	_arena.add_child(p)
	p.global_position = at
	p.visual.rotation.y = PI
	return p


func _drop(p: Player) -> void:
	for i in p.robot.mesh.get_surface_override_material_count():   # headless Godot grumbles otherwise
		p.robot.mesh.set_surface_override_material(i, null)
	p.queue_free()


func _drawn() -> void:
	print("  the recording")
	var p := _player(VICTIM, AT)
	p.alive = false
	p.hide_for_remains()
	_expect(not p.visual.visible and bool(p.shown_state()[9]), "a body hidden by its remains still counts as drawn for the killcam")
	p.alive = true
	_expect(not bool(p.shown_state()[9]), "...but not once it is back (hidden until its respawn shows)")
	_drop(p)


## Kills a body at AT with `fx`, recording its remains (by hand, at Killcam's rate) for
## 1.5 s. Returns [the Wreck, the live remains], or [] if none were made.
func _record(fx: Dictionary) -> Array:
	var kind := "giblets" if fx.get("gib", false) else "a ragdoll"
	print("  recording %s" % kind)
	var had := Killcam._wrecks.size()
	var p := _player(VICTIM, AT)
	var before := Remains.count()
	if not Remains.spawn(p, fx):
		_drop(p)
		return []
	var live: Node3D = Remains.bodies()[-1]
	var first: Array = live.call("start_pose")
	var frame := 0
	while frame < 90:
		if frame % 2 == 0:
			Killcam._record_wrecks(_now)
		await get_tree().process_frame
		_now += STEP
		frame += 1
	_drop(p)
	_expect(Killcam._wrecks.size() == had + 1, "%s is recorded once (%d)" % [kind, Killcam._wrecks.size() - had])
	if Killcam._wrecks.size() != had + 1:
		return []
	var w: KillClip.Wreck = Killcam._wrecks[-1]
	_expect(w.who == VICTIM and w.kind == ("gibs" if fx.get("gib", false) else "ragdoll"), "...as %s's %s" % [w.who, w.kind])
	_expect(w.fx == fx, "...with how the blow fell (%s)" % [w.fx])
	_expect(w.times.size() >= 44 and w.times.size() <= 47, "...about 30 times a second (%d frames in 1.5 s)" % w.times.size())
	_expect(w.frames[0] == first and (w.frames[0] as Array).size() == (live.call("capture") as Array).size(),
		"...from the moment of the death, every body")
	var moved := ((w.frames[-1] as Array)[0] as Transform3D).origin.distance_to(((w.frames[0] as Array)[0] as Transform3D).origin)
	_expect(moved > 0.2, "...as it fell (%.2f m)" % moved)
	_expect(Remains.count() == before + 1, "it is one set of remains")
	return [w, live]


## The killer at the origin looking north at the victim at AT, who is knocked out at the
## start of `w` (and lies there after).
func _clip(w: KillClip.Wreck, kick: bool = false) -> KillClip:
	var clip := KillClip.new()
	clip.killer = 1
	clip.victim = VICTIM
	clip.kill_time = w.first_time()
	clip.start = clip.kill_time - 1.0
	clip.end = clip.kill_time + 1.2
	clip.info = {"seq": 1, "score": 100, "tags": KillScore.T_KICK if kick else 0, "streak": 0, "distance": 10.0,
		"weapon": "kick" if kick else "pistol", "killer": 1, "victim": VICTIM}
	var killer := KillClip.Track.new()
	var victim := KillClip.Track.new()
	killer.name = "Tester"
	victim.name = "Gizmo"
	victim.character = "needle"
	victim.color = Net.player_color(VICTIM)
	var t := clip.start - 0.5
	while t < clip.end + 0.5:
		var alive := t < clip.kill_time
		var feet := AT + Vector3(0, 0, 7) if kick else Vector3.ZERO   # a kick: right behind them
		killer.push(t, [feet, Vector3.ZERO, 0.0, 0.0, 0, 0, false, Vector3.ZERO, true, true, 1.6, "pistol"])
		victim.push(t, [AT, Vector3.ZERO, PI, 0.0, 0, 0, false, Vector3.ZERO, alive, true, 1.6, "pistol"])
		t += 1.0 / 30.0
	clip.tracks = {1: killer, VICTIM: victim}
	clip.wrecks = [w]
	return clip


func _clips(w: KillClip.Wreck) -> void:
	print("  clips")
	var clip := _clip(w)
	var cut := clip.cut()
	_expect(cut.wrecks.size() == 1 and cut.wrecks[0] == w, "a kept clip keeps the remains of its kill (shared, so a fall still being recorded goes on filling in)")
	clip.start = w.first_time() + Remains.LIFETIME + 2.0
	clip.end = clip.start + 2.0
	clip.kill_time = clip.start + 1.0
	_expect(clip.cut().wrecks.is_empty(), "...but not remains long gone before it starts")


func _view(clip: KillClip, slow: bool = false, manual: bool = false) -> KillcamView:
	var view := KillcamView.new().setup(clip, slow)
	view.world_sound = false
	view.manual = manual
	_arena.add_child(view)
	view.set_process(false)   # stepped by hand
	return view


func _go(view: KillcamView, until: float, step: float = STEP) -> void:
	var n := 0
	while view.time < until and not view.done and n < 100000:
		if view.manual:
			view.step(step)
		else:
			view._process(step)
		n += 1


func _replay_bodies(view: KillcamView, type: String) -> Array:
	return view.find_children("*", type, true, false).filter(func(n): return not n.is_queued_for_deletion())


func _ghost(view: KillcamView) -> Node3D:
	return view.get_node_or_null("Ghost_%d" % VICTIM) as Node3D


## How far the replay's ragdoll is from where the recording has it at the replay's time.
func _off(view: KillcamView, w: KillClip.Wreck, r: Ragdoll) -> float:
	var want: Transform3D = w.pose_at(view.clip.time_for(VICTIM, view.time))[0]   # the hips
	return r.focus().distance_to(want.origin)


func _replay_ragdoll(w: KillClip.Wreck, live: Node3D) -> void:
	print("  a replay of a ragdoll kill")
	var count := Remains.count()
	var live_at: Array = live.call("capture")
	var view := _view(_clip(w))
	_go(view, w.first_time() - 0.1)
	_expect(_ghost(view) != null and _ghost(view).visible and _replay_bodies(view, "Ragdoll").is_empty(), "before the kill: the victim's body, no ragdoll")
	_go(view, w.first_time() + 0.1)
	var made := _replay_bodies(view, "Ragdoll")
	_expect(made.size() == 1, "just after it: a ragdoll of the replay's own (%d)" % made.size())
	_expect(not _ghost(view).visible, "...in place of the body, which is out of sight")
	if made.size() == 1:
		var r := made[0] as Ragdoll
		_expect(not Remains.bodies().has(r) and Remains.count() == count, "...not counted as remains (%d)" % Remains.count())
		_expect(_off(view, w, r) < 0.02, "...posed where the recording has it (%.3f m off)" % _off(view, w, r))
		var start: Transform3D = w.frames[0][0]
		_go(view, w.first_time() + 1.0)
		_expect(_off(view, w, r) < 0.02 and r.focus().distance_to(start.origin) > 0.2,
			"...and falls the way it did (a second on: %.3f m off the recording, %.2f m from the start)" % [_off(view, w, r), r.focus().distance_to(start.origin)])
		_expect(is_instance_valid(live) and live.visible and live.call("capture") == live_at, "the live ragdoll is left alone")
		view.restart()
		await get_tree().process_frame
		_expect(not is_instance_valid(r) and _replay_bodies(view, "Ragdoll").is_empty() and _ghost(view).visible,
			"starting over: the replay's ragdoll goes, the body is back")
		_go(view, w.first_time() + 0.5)
		var again := _replay_bodies(view, "Ragdoll")
		_expect(again.size() == 1, "...and falls again at the kill")
		view.queue_free()
		await get_tree().process_frame
		_expect(again.size() == 1 and not is_instance_valid(again[0]), "when the replay ends its ragdoll goes with it")
	print("  ...in slow motion, and stepped by hand (a video)")
	var slow := _view(_clip(w), true)
	_go(slow, w.first_time())
	var steps := 0
	while slow.time < w.first_time() + 0.3 and steps < 1000:
		slow._process(STEP)
		steps += 1
	var rs := _replay_bodies(slow, "Ragdoll")
	_expect(rs.size() == 1 and steps * STEP > 0.6, "slow motion: %.2f s to play 0.3 s of the fall" % (steps * STEP))
	if rs.size() == 1:
		_expect(_off(slow, w, rs[0]) < 0.02, "...and the ragdoll is where the recording has it at the replay's time (%.3f m off)" % _off(slow, w, rs[0]))
	slow.queue_free()
	var video := _view(_clip(w), true, true)
	_go(video, w.first_time() + 0.4, 1.0 / KillcamExport.FPS)
	var rv := _replay_bodies(video, "Ragdoll")
	_expect(rv.size() == 1 and _off(video, w, rv[0]) < 0.02, "stepped by hand: the same (%s)" % ("%.3f m off" % _off(video, w, rv[0]) if rv.size() == 1 else "none"))
	video.queue_free()
	print("  ...in third person (a blow)")
	var third := _view(_clip(w, true))
	_go(third, w.first_time() + 0.6)
	var rt := _replay_bodies(third, "Ragdoll")
	if rt.size() == 1:
		var to := ((rt[0] as Ragdoll).focus() - third.camera.global_position).normalized()
		_expect((-third.camera.global_transform.basis.z).dot(to) > 0.9, "the camera stays turned towards the fallen body")
	else:
		_expect(false, "a ragdoll in third person too")
	third.queue_free()
	await get_tree().process_frame
	_expect(Remains.count() == count and is_instance_valid(live), "after the replays the live remains are as they were (%d)" % Remains.count())


func _replay_gibs(w: KillClip.Wreck, live: Node3D) -> void:
	print("  a replay of a gib kill")
	var count := Remains.count()
	var view := _view(_clip(w))
	_go(view, w.first_time() - 0.1)
	_expect(_ghost(view).visible and _replay_bodies(view, "Gibs").is_empty(), "before the kill: the body, no giblets")
	_go(view, w.first_time() + 0.5)
	var made := _replay_bodies(view, "Gibs")
	_expect(made.size() == 1 and not _ghost(view).visible, "after it: giblets of the replay's own in the body's place")
	if made.size() == 1:
		var g := made[0] as Gibs
		var bodies := g.get_children().filter(func(c): return c is RigidBody3D)
		var pose := w.pose_at(view.clip.time_for(VICTIM, view.time))
		_expect(bodies.size() == pose.size(), "...as many pieces and bits of scrap as fell (%d, %d)" % [bodies.size(), pose.size()])
		_expect(bodies.all(func(b): return (b as RigidBody3D).freeze and (b as RigidBody3D).collision_layer == 0),
			"...held still, in no physics layer (the recording moves them)")
		var worst := 0.0
		for i in mini(bodies.size(), pose.size()):
			worst = maxf(worst, (bodies[i] as Node3D).global_position.distance_to((pose[i] as Transform3D).origin))
		_expect(worst < 0.02, "...each where the recording has it (%.3f m off at most)" % worst)
		_expect(not Remains.bodies().has(g) and Remains.count() == count and is_instance_valid(live), "...not counted as remains; the live giblets left alone")
		view.queue_free()
		await get_tree().process_frame
		_expect(not is_instance_valid(g), "when the replay ends its giblets go with it")
	else:
		view.queue_free()


func _gore(rag: KillClip.Wreck, gib: KillClip.Wreck) -> void:
	print("  gore settings")
	Settings.gore = "off"
	var view := _view(_clip(rag))
	_go(view, rag.first_time() + 0.5)
	_expect(_replay_bodies(view, "Ragdoll").is_empty() and _ghost(view).visible, "gore off: no ragdoll, the body stays where it fell")
	var ghost: KillcamView.Ghost = view._ghosts[VICTIM]
	_expect(not ghost.anim.alive, "...playing its death")
	view.queue_free()
	Settings.gore = "ragdolls"
	var only := _view(_clip(gib))
	_go(only, gib.first_time() + 0.5)
	_expect(_replay_bodies(only, "Gibs").is_empty() and _ghost(only).visible, "ragdolls only: no giblets either (the body stays)")
	only.queue_free()
	var rag_view := _view(_clip(rag))
	_go(rag_view, rag.first_time() + 0.5)
	_expect(_replay_bodies(rag_view, "Ragdoll").size() == 1, "...but ragdolls")
	rag_view.queue_free()
	Settings.gore = "full"
	await get_tree().process_frame


func _after_match() -> void:
	print("  after the match")
	Killcam._over = true
	var p := _player(VICTIM, AT)
	Remains.spawn(p, {"dir": Vector3(0, 0, -1)})
	_expect(Killcam._settling(), "a body that fell as the match ended is still recorded")
	Killcam._record_wrecks(_now)
	var w: KillClip.Wreck = Killcam._wrecks[-1] if not Killcam._wrecks.is_empty() else null
	_expect(w != null and w.who == VICTIM and Killcam._settling(), "...from its death on")
	for entry: Array in Killcam._wreck_of.values():   # (as if WRECK_FOR had gone by)
		var each: KillClip.Wreck = entry[0]
		each.push(each.first_time() + Killcam.WRECK_FOR, each.frames[-1])
	_expect(not Killcam._settling(), "...until its fall has been recorded")
	Killcam._over = false
	_drop(p)
	await get_tree().process_frame
