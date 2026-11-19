extends Node
## Killcams that match the match (started by tests/killcam_sync_test.gd):
##  - the killer's aim: at the moment of each shot the replay looks exactly where the
##    shot was aimed, from where it was fired, though the recording was off; it eases
##    onto a lone shot and off it again, and goes from shot to shot through a burst;
##    after a flick (the shot reaching us a moment before the frames that turn) it is
##    on the shot when it fires and never swings past it as the recording catches up;
##  - a target the killer hit is moved in time to where the hits say they were on the
##    killer's screen; one standing still, or never hit, is left where it was;
##  - a moving part's recording keeps only its changes (and the last look before
##    one), blends between looks, holds at either end, and trims and slices keeping
##    the look before;
##  - the Construction Site: the crane, its load, its rope and the breakable walls are
##    parts of the map a killcam records; a replay draws the crane's load where it
##    was, with the signs riding the jib, and a wall shot through since as it was,
##    while what people stand on (collision) stays as the match has it; the wall
##    breaks again when the replay reaches that moment, and stands again when it starts
##    over; when the replay ends all of
##    it is drawn live again; a copy of the map (the results screen's) finds every
##    part, walls included.

const KILLER := 1
const VICTIM := 9001

var _fails: Array[String] = []


func run() -> void:
	await get_tree().process_frame
	print("Killcam sync checks")
	Net.start_offline("Tester", "needle", "pistol")
	_aim()
	_align()
	_prop_track()
	await _map_parts()
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


func _frame(pos: Vector3, yaw: float = 0.0, pitch: float = 0.0, alive: bool = true) -> Array:
	return [pos, Vector3.ZERO, yaw, pitch, 0, 0, false, Vector3.ZERO, alive, true, 1.6, "pistol"]


static func _dir(yaw: float, pitch: float) -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD


func _clip(seconds: float) -> KillClip:
	var clip := KillClip.new()
	clip.killer = KILLER
	clip.victim = VICTIM
	clip.kill_time = seconds - 0.5
	clip.start = 0.0
	clip.end = seconds
	clip.info = {"seq": 1, "score": 100, "tags": 0, "streak": 0, "distance": 10.0, "weapon": "pistol", "killer": KILLER, "victim": VICTIM}
	return clip


## The view at killer time t (sampled exactly there, not stepped up to it).
func _look(view: KillcamView, t: float) -> Transform3D:
	view.time = t
	view._frame(0.0)
	return view.camera.global_transform


# ---------------------------------------------------------------------------

func _aim() -> void:
	print("  the killer's aim")
	# The killer turns slowly right; the recording runs 0.1 rad (about 6 degrees) behind
	# what they aimed, as smoothing over the network leaves it after a flick.
	var clip := _clip(3.0)
	var killer := KillClip.Track.new()
	killer.color = Color.WHITE
	for i in 91:
		var t := i / 30.0
		killer.push(t, _frame(Vector3(t, 0, 0), 0.2 * t, 0.05))
	clip.tracks = {KILLER: killer}
	var shots := [[1.0, 0.1], [2.0, -0.08], [2.1, -0.09], [2.2, -0.1]]   # [when, how far off]
	for s in shots:
		var t: float = s[0]
		var aim := _dir(0.2 * t + float(s[1]), 0.05 + 0.02)
		clip.events.append({"t": t, "who": KILLER, "kind": "aim", "eye": Vector3(t, 1.6, 0) + Vector3(0.3, 0, 0), "aim": aim})
	var world := Node3D.new()
	add_child(world)
	var view := KillcamView.new().setup(clip, false)
	view.world_sound = false
	world.add_child(view)
	view.set_process(false)
	for s in shots:
		var t: float = s[0]
		var cam := _look(view, t)
		var want := _dir(0.2 * t + float(s[1]), 0.07)
		var off := rad_to_deg((-cam.basis.z).angle_to(want))
		_expect(off < 0.05, "at the shot at %.1f s the replay looks exactly where it was aimed (%.3f degrees off; the recording was %.1f)" % [t, off, rad_to_deg(absf(float(s[1])))])
		_expect(cam.origin.distance_to(Vector3(t + 0.3, 1.6, 0)) < 0.01, "...from where it was fired (%s)" % [cam.origin])
	var early := _look(view, 0.7)
	_expect(rad_to_deg((-early.basis.z).angle_to(_dir(0.14, 0.05))) < 0.05, "well before a shot it looks where the recording says")
	var easing := _look(view, 0.95)
	var a := rad_to_deg((-easing.basis.z).angle_to(_dir(0.19, 0.05)))
	_expect(a > 0.3 and a < 5.7, "just before it, it is easing onto the shot (%.2f of 5.7 degrees)" % a)
	var after := _look(view, 1.2)
	_expect(rad_to_deg((-after.basis.z).angle_to(_dir(0.24, 0.05))) < 0.05, "...and well after it, back to the recording")
	var burst := _look(view, 2.05)
	var mid := _dir(0.2 * 2.05 - 0.085, 0.07)
	_expect(rad_to_deg((-burst.basis.z).angle_to(mid)) < 0.1, "between shots of a burst it goes from one aim to the next")
	view.queue_free()
	# A flick: the recording jumps 90 degrees just after the shot that the flick was for
	# (the shot reached us a moment before the frames did). The replay swings onto the
	# shot, and once the recording has caught up it does not swing past it.
	var flick := _clip(2.0)
	var snap := KillClip.Track.new()
	for i in 61:
		var t := i / 30.0
		snap.push(t, _frame(Vector3.ZERO, 0.0 if t < 1.05 else PI / 2.0, 0.0))
	flick.tracks = {KILLER: snap}
	flick.events.append({"t": 1.0, "who": KILLER, "kind": "aim", "eye": Vector3(0, 1.6, 0), "aim": _dir(PI / 2.0, 0.0)})
	var fv := KillcamView.new().setup(flick, false)
	fv.world_sound = false
	world.add_child(fv)
	fv.set_process(false)
	var at_shot := rad_to_deg((-_look(fv, 1.0).basis.z).angle_to(_dir(PI / 2.0, 0.0)))
	var past := 0.0     # the most it turned beyond the shot's aim
	var settled := 0.0  # the most it was off once the recording had caught up
	for i in 40:
		var t := 1.0 + i * 0.01
		var yaw := KillClip.yaw_pitch(-_look(fv, t).basis.z).x
		past = maxf(past, rad_to_deg(yaw - PI / 2.0))
		if t >= 1.07:
			settled = maxf(settled, rad_to_deg(absf(yaw - PI / 2.0)))
	_expect(at_shot < 0.05 and past < 0.05 and settled < 0.05,
		"a flick: on the shot when it fires (%.2f degrees off), never swinging past it (%.2f), on it once the recording catches up (%.2f)" % [at_shot, past, settled])
	_expect(fv.aim_report() == "1 90.0", "the logs say how far the recording was off (%s)" % fv.aim_report())
	fv.queue_free()
	world.queue_free()


func _align() -> void:
	print("  where the killer saw whoever they hit")
	var clip := _clip(3.0)
	var killer := KillClip.Track.new()
	var runner := KillClip.Track.new()
	var still := KillClip.Track.new()
	for i in 91:
		var t := i / 30.0
		killer.push(t, _frame(Vector3.ZERO))
		runner.push(t, _frame(Vector3(6.0 * t, 0, -10)))   # running across at 6 m/s
		still.push(t, _frame(Vector3(-5, 0, -12)))
	clip.tracks = {KILLER: killer, VICTIM: runner, 77: still}
	clip.offsets = {KILLER: 0.0, VICTIM: -0.05, 77: -0.05}
	clip.event_offsets = {KILLER: 0.0, VICTIM: 0.05, 77: 0.05}
	# On the killer's screen the runner was 0.1 s further on than the estimate says: the
	# hits went through them there (at killer time 1.0 and 1.5).
	for t in [1.0, 1.5]:
		var at := Vector3(6.0 * (t + 0.05), 1.2, -10)
		clip.events.append({"t": t, "who": KILLER, "kind": "shot", "muzzle": Vector3(0, 1.6, 0),
			"ends": PackedVector3Array([at]), "hits": [true], "weapon": "pistol"})
	clip.events.append({"t": 1.2, "who": KILLER, "kind": "shot", "muzzle": Vector3(0, 1.6, 0),
		"ends": PackedVector3Array([Vector3(-5, 1.4, -12)]), "hits": [true], "weapon": "pistol"})   # the one standing still
	clip.events.append({"t": 1.3, "who": KILLER, "kind": "shot", "muzzle": Vector3(0, 1.6, 0),
		"ends": PackedVector3Array([Vector3(20, 1.0, -10)]), "hits": [false], "weapon": "pistol"})   # a miss far ahead of the runner
	clip.align_to_hits()
	var moved := float(clip.offsets[VICTIM])
	_expect(absf(moved - 0.05) < 0.012, "the runner is moved to where the hits say (offset %.3f s, about +0.05)" % moved)
	_expect(absf(float(clip.event_offsets[VICTIM]) + moved) < 0.0001, "...and so are their own shots and blows")
	var f := runner.sample(clip.time_for(VICTIM, 1.0))
	_expect(absf((f[0] as Vector3).x - 6.3) < 0.1, "...so the killing shot goes through them in the replay (x %.2f, hit at 6.30)" % (f[0] as Vector3).x)
	_expect(absf(float(clip.offsets[77]) + 0.05) < 0.0001, "one standing still is left where they were (%.3f)" % float(clip.offsets[77]))
	_expect(clip.offsets[KILLER] == 0.0, "the killer is never moved")


func _prop_track() -> void:
	print("  a moving part's recording")
	var t := KillClip.PropTrack.new()
	for i in 10:
		t.look(i * 0.1, 1.0)   # standing still for a second
	for i in range(10, 15):
		t.look(i * 0.1, 1.0 + (i - 9))   # then moving
	for i in range(15, 30):
		t.look(i * 0.1, 6.0)   # then still again
	_expect(t.times.size() == 7, "only changes are kept, and the last look before each (%d looks: %s)" % [t.times.size(), t.times])
	var hold: Array = t.at(0.5)
	_expect(hold[0] == 1.0 and hold[1] == 1.0, "standing still, it does not drift toward the move to come (%s)" % [hold])
	var moving: Array = t.at(1.05)
	_expect(moving[0] == 2.0 and moving[1] == 3.0 and absf(float(moving[2]) - 0.5) < 0.01, "on the move it blends between looks (%s)" % [moving])
	_expect(t.at(-1.0)[0] == 1.0 and t.at(9.0)[0] == 6.0 and t.at(9.0)[1] == null, "it holds the first and last looks")
	var part := t.slice(0.6, 1.2)
	_expect(part.at(0.6)[0] == 1.0 and part.at(1.21)[0] == 4.0, "a slice keeps the look before it, and what happens in it (%s)" % [part.states])
	t.trim(2.0)
	_expect(t.times.size() == 1 and t.at(2.5)[0] == 6.0, "trimming keeps what it looked like then (%s)" % [t.states])


func _map_parts() -> void:
	print("  the Construction Site's crane and walls")
	var map := Maps.make("construction_site")
	map.name = "Level"
	map.destructible = true
	add_child(map)
	map.build()
	await get_tree().process_frame
	var parts := MapReplay.parts(map)
	var keys := parts.map(func(p): return p[0])
	var crane := map.get_node_or_null("Crane/CraneEvent") as CraneEvent
	_expect(keys.has(".") and keys.has(MapReplay.DESTRUCTION_KEY) and crane != null and keys.has("Crane/CraneEvent"),
		"the movers, the walls and the crane's rope are recorded (%s)" % [keys])
	var hook := crane.get_node(crane.hook) as MapIsland
	var jib := crane.get_node(crane.jib) as MapIsland
	var hi := -1
	var ji := -1
	for i in map.movers.size():
		if map.movers[i].node == hook:
			hi = i
		elif map.movers[i].node == jib:
			ji = i
	_expect(hi >= 0 and ji >= 0, "the crane's jib and load are movers")
	if hi < 0 or ji < 0:
		map.queue_free()
		return
	var breaks := map.destruction
	var cell := -1
	for c in breaks.cells.size():
		if not breaks.cells[c].protected and breaks.panels[breaks.cells[c].panel].frame == null and not breaks.panels[breaks.cells[c].panel].whole:
			cell = c
			break
	_expect(cell >= 0, "there is a wall to break")
	# Record a second: the load goes up 6 m; halfway through the wall is shot through.
	var props := {}
	var load_at := []
	for i in 31:
		var t := i / 30.0
		hook.pose_a = Vector3(0.0, 6.0 * t, 0.0)
		hook.pose_b = hook.pose_a
		map.update_movers(0.0)
		if i == 15:
			breaks.apply(PackedInt32Array([cell]), PackedByteArray([MapDestruction.BROKEN]))
		load_at.append((map.movers[hi].body as Node3D).transform)
		for p in MapReplay.parts(map):
			if not props.has(p[0]):
				props[p[0]] = KillClip.PropTrack.new()
			(props[p[0]] as KillClip.PropTrack).look(t, p[1].call("replay_capture"))
	var live_load: Transform3D = (map.movers[hi].body as Node3D).transform
	var panel: Dictionary = breaks.panels[breaks.cells[cell].panel]
	var live_shapes := (panel.body as Node).get_child_count()
	var clip := _clip(1.0)
	var killer := KillClip.Track.new()
	for i in 31:
		killer.push(i / 30.0, _frame(Vector3(0, 30, 40)))
	clip.tracks = {KILLER: killer}
	clip.props = props
	var view := KillcamView.new().setup(clip, false)
	view.world_sound = false
	view.map = map
	add_child(view)
	view.set_process(false)
	_look(view, 0.2)
	var shown = map._replay_poses[hi]
	_expect(shown is Transform3D and (shown as Transform3D).origin.distance_to((load_at[6] as Transform3D).origin) < 0.01,
		"the replay draws the load where it was then (%.2f m up, now %.2f)" % [(shown as Transform3D).origin.y - (load_at[0] as Transform3D).origin.y if shown is Transform3D else -1.0, live_load.origin.y - (load_at[0] as Transform3D).origin.y])
	_expect((map.movers[hi].body as Node3D).transform.is_equal_approx(live_load), "...while the load people stand on stays where the match has it")
	var drawn: Array = map._replay_drawn[ji] if ji < map._replay_drawn.size() else []
	_expect(drawn.any(func(v): return v is MeshInstance3D) and drawn.any(func(v): return v is Label3D),
		"the jib's meshes and the signs riding it are drawn with it (%d things)" % drawn.size())
	var rope: Array = crane._replay_rope
	var want_rope: Array = (props["Crane/CraneEvent"] as KillClip.PropTrack).at(0.2)[0]
	_expect(rope.size() == 2 and (rope[1] as Vector3).distance_to(want_rope[1]) < 0.01, "the hoist rope hangs where it did then")
	_expect(breaks._shown(cell) == 0 and breaks.is_broken(cell), "the wall shot through since is drawn whole as it was")
	_expect(panel.body.get_child_count() == live_shapes, "...but you can still go through the hole (its collision is the match's)")
	_look(view, 0.8)
	_expect(breaks._shown(cell) == MapDestruction.BROKEN, "the wall breaks when the replay reaches the shot that broke it")
	view.restart()
	_expect(breaks._shown(cell) == 0 and (map._replay_poses[hi] as Transform3D).origin.distance_to((load_at[0] as Transform3D).origin) < 0.01,
		"starting over puts the wall and the load back as they were at the start")
	view.free()
	_expect(map._replay_poses.is_empty() and crane._replay_rope.is_empty() and breaks._shown(cell) == MapDestruction.BROKEN,
		"when the replay ends the crane, the rope and the wall are drawn live again")
	# The results screen plays the best kills in a copy of the map.
	var copy := Maps.make("construction_site")
	copy.destructible = MapReplay.wants_destruction([clip])
	add_child(copy)
	copy.build()
	await get_tree().process_frame
	_expect(copy.destructible and props.keys().all(func(k): return MapReplay.find(copy, k) != null),
		"a copy of the map has every part the recording names, walls included")
	copy.queue_free()
	map.queue_free()
	await get_tree().process_frame
