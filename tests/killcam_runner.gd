extends Node
## Killcam checks (started by tests/killcam_test.gd):
##  - kill scores: a plain kill scores the base; headshots, range, the rope, a wall run,
##    a glide, an air shot, kicks, crashes, multikills and a clutch each add their bit,
##    with the right words; the best kills are the highest scores, the earlier kill
##    first on a tie, never more than three;
##  - the numbers sent with a death and with the end of the match turn back into the
##    same kill;
##  - recording: a player's frames blend smoothly between samples, hold at either end,
##    never blend across a death, and old frames are dropped; a clip keeps only its
##    own few seconds, and shows each player as late as the killer saw them;
##  - offline, nobody is seen late (the host runs the bots), so nothing is shifted;
##  - playback: the camera is the killer's eyes, looking where they looked; the victim
##    is drawn where the clip says; the shot plays; the kill moment and the end are
##    announced once; the results screen's slow motion makes the kill last longer;
##  - after a match the three best kills play fullscreen, counting down to the best,
##    from this copy's clips (saying so for one it did not see), then the results page
##    shows; it still fits a 1600 x 900 window without scrolling and has a button to
##    watch each kill again (fullscreen) and one for all three, on Halcyon, whose terminal and events must not mind
##    being built outside a match.

var _fails: Array[String] = []


func run() -> void:
	await get_tree().process_frame
	print("Killcam checks")
	_scores()
	_packing()
	_tracks()
	_clips()
	_offline_timing()
	await _playback()
	await _results_page()
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


const S := MovementController.State


func _scores() -> void:
	print("  kill scores")
	var plain := KillScore.score({"distance": 6.0})
	_expect(plain == [KillScore.BASE, 0], "a plain kill close by on the ground scores the base and no tags (%s)" % [plain])
	var head := KillScore.score({"distance": 6.0, "headshot": true})
	_expect(head[0] == KillScore.BASE + KillScore.HEADSHOT and head[1] & KillScore.T_HEADSHOT, "a headshot adds %d" % KillScore.HEADSHOT)
	var far := KillScore.score({"distance": 40.0})
	_expect(far[0] == KillScore.BASE + 75 and far[1] & KillScore.T_LONG, "40 m adds 3 a metre past 15 m, and the range tag (%d)" % far[0])
	var very_far := KillScore.score({"distance": 300.0})
	_expect(very_far[0] == KillScore.BASE + KillScore.RANGE_MAX, "range points stop at %d" % KillScore.RANGE_MAX)
	var rope := KillScore.score({"killer_state": S.GRAPPLE})
	_expect(rope[0] == KillScore.BASE + KillScore.MID_AIR + KillScore.ON_ROPE and rope[1] & KillScore.T_ROPE and rope[1] & KillScore.T_MID_AIR,
		"on the rope counts as mid-air plus the rope (%d)" % rope[0])
	_expect(KillScore.score({"killer_state": S.WALL_RUN})[1] & KillScore.T_WALL, "off a wall is tagged")
	_expect(KillScore.score({"killer_state": S.GLIDE})[1] & KillScore.T_GLIDE, "gliding is tagged")
	_expect(KillScore.score({"killer_state": S.SLIDE})[0] == KillScore.BASE, "a slide is on the ground: no bonus")
	_expect(KillScore.score({"victim_state": S.AIR})[1] & KillScore.T_AIR_SHOT, "a victim in the air makes an air shot")
	var kick: int = KillScore.score({"cause": "kick"})[0]
	var flying: int = KillScore.score({"cause": "flying_kick"})[0]
	_expect(flying > kick and kick > KillScore.BASE, "a flying kick beats a kick, which beats a plain kill (%d, %d)" % [flying, kick])
	_expect(KillScore.score({"cause": "slam"})[1] & KillScore.T_SMASHED, "a crash into a wall is tagged")
	_expect(KillScore.score({"melee": true})[1] & KillScore.T_MELEE, "a blade kill is tagged")
	_expect(KillScore.score({"melee": true, "cause": "kick"})[1] & KillScore.T_MELEE == 0, "a kick with a blade in hand is a kick, not a cut")
	var triple := KillScore.score({"streak": 2})
	_expect(triple[0] == KillScore.BASE + 2 * KillScore.MULTI, "a third kill in a row adds two multikill bonuses")
	_expect(KillScore.score({"killer_hp": 10.0})[1] & KillScore.T_CLUTCH, "a kill on 10 HP is a clutch")
	var words := KillScore.tag_words(rope[1] | KillScore.T_HEADSHOT | KillScore.T_LONG, 2, 42.4)
	_expect(words == ["TRIPLE KILL", "ON THE ROPE", "HEADSHOT", "42 M"], "the words come most telling first (%s)" % [words])
	var kills := [
		{"seq": 1, "score": 150}, {"seq": 2, "score": 300}, {"seq": 3, "score": 150},
		{"seq": 4, "score": 290}, {"seq": 5, "score": 300}, {"seq": 6, "score": 100}]
	var best := KillScore.best(kills, 3).map(func(k): return k.seq)
	_expect(best == [2, 5, 4], "the best three are the highest scores, the earlier kill first on a tie (%s)" % [best])
	kills.shuffle()
	_expect(KillScore.best(kills, 3).map(func(k): return k.seq) == [2, 5, 4], "whatever order the kills are in")
	_expect(KillScore.best(kills.slice(0, 2), 3).size() == 2, "fewer kills than three: all of them")


func _packing() -> void:
	print("  what travels with a death")
	var info := {"seq": 7, "score": 345, "tags": KillScore.T_ROPE | KillScore.T_MID_AIR, "streak": 1,
		"distance": 23.4, "weapon": "sniper", "killer": 2, "victim": 9001}
	var packed := Match.pack_kill(info)
	_expect(packed.size() == 8 and packed.all(func(v): return v is int or v is String), "a kill travels as eight plain numbers and a word (%s)" % [packed])
	_expect(Match.kill_info(packed) == info, "...and turns back into the same kill")
	_expect(Match.kill_info(packed.slice(0, 6), 2, 9001) == info, "the death message carries the killer and victim already")
	var bytes := var_to_bytes(packed).size()
	_expect(bytes <= 80, "about %d bytes a kill" % bytes)


func _frame(pos: Vector3, yaw: float = 0.0, pitch: float = 0.0, alive: bool = true, weapon: String = "pistol") -> Array:
	return [pos, Vector3.ZERO, yaw, pitch, 0, 0, false, Vector3.ZERO, alive, true, 1.6, weapon]


func _tracks() -> void:
	print("  recording a player")
	var t := KillClip.Track.new()
	for i in 31:
		t.push(i / 30.0, _frame(Vector3(i / 3.0, 0, 0), i * 0.01))
	var mid := t.sample(0.55)
	_expect(absf((mid[0] as Vector3).x - 5.5) < 0.01, "between frames the position blends (%.3f)" % (mid[0] as Vector3).x)
	_expect(absf(float(mid[2]) - 0.165) < 0.001, "...and so does the aim")
	_expect(t.sample(-1.0)[0] == Vector3.ZERO and t.sample(9.0)[0] == Vector3(10, 0, 0), "before and after the track it holds the first and last frames")
	t.push(1.0, _frame(Vector3(10, 0, 0)))
	_expect(t.times[-1] > t.times[-2], "a frame stamped no later than the last still goes after it")
	var d := KillClip.Track.new()
	d.push(0.0, _frame(Vector3.ZERO, 0.0, 0.0, true))
	d.push(0.1, _frame(Vector3(1, 0, 0), 0.0, 0.0, false))
	_expect(d.sample(0.04)[8] == true and d.sample(0.04)[0] == Vector3.ZERO, "no blending across a death")
	var part := t.slice(0.4, 0.6)
	_expect(part.first_time() <= 0.4 and part.last_time() >= 0.6 and part.times.size() <= 9, "a slice keeps its stretch and a frame either side (%d frames)" % part.times.size())
	t.trim(0.5)
	_expect(t.first_time() >= 0.49 and t.first_time() <= 0.5, "old frames are dropped (%.3f)" % t.first_time())


func _clips() -> void:
	print("  clips")
	var clip := KillClip.new()
	clip.killer = 1
	clip.victim = 2
	clip.kill_time = 5.0
	clip.start = 3.0
	clip.end = 5.5
	clip.offsets = {1: 0.0, 2: -0.2}
	clip.event_offsets = {1: 0.0, 2: 0.2}
	for id in [1, 2]:
		var t := KillClip.Track.new()
		for i in 300:
			t.push(i / 30.0, _frame(Vector3(id, 0, i)))
		clip.tracks[id] = t
	clip.events = [{"t": 1.0, "who": 1}, {"t": 4.9, "who": 1}, {"t": 5.4, "who": 2}, {"t": 6.5, "who": 1}]
	_expect(is_equal_approx(clip.time_for(2, 4.0), 3.8), "the victim is sampled as late as the killer saw them")
	_expect(is_equal_approx(clip.event_time(clip.events[2]), 5.6), "...and so are the victim's shots")
	_expect(clip.has_killer(1.0), "the killer's track covers the kill")
	var early := KillClip.new()
	early.killer = 1
	early.kill_time = 0.5
	early.start = -2.0
	early.end = 1.0
	early.tracks = {1: clip.tracks[1]}
	_expect(not early.has_killer(1.0), "a kill less than a second into the recording has no killcam")
	early.kill_time = 1.5
	_expect(early.has_killer(1.0) and early.start == 0.0, "...and a short one starts at the killer's first frame")
	var cut := clip.cut(0.5)
	_expect(cut.events.size() == 2, "a kept clip keeps only the events in its stretch (%d)" % cut.events.size())
	var tk: KillClip.Track = cut.tracks[1]
	_expect(tk.first_time() <= 2.5 and tk.last_time() >= 6.0 and tk.times.size() < 120, "...and only the frames it needs (%d)" % tk.times.size())
	var tv: KillClip.Track = cut.tracks[2]
	_expect(tv.first_time() <= 2.3, "the victim's frames start earlier, by how late the killer saw them")


func _offline_timing() -> void:
	print("  timing offline")
	Net.start_offline("Tester", "needle", "pistol")
	var bot := Net.add_bot(1, "rifle")
	_expect(Killcam._seen_late(1, bot) == 0.0 and Killcam._seen_late(bot, 1) == 0.0, "the host runs the bots: nobody is seen late")
	_expect(Killcam._delay(bot) == 0.0, "and nothing reaches us late")


## A clip of the killer at (0, 0, 0) turning to face the victim 10 m north (-z),
## who drops when the shot lands at 2.0 s.
func _test_clip() -> KillClip:
	var clip := KillClip.new()
	clip.killer = 1
	clip.victim = 9001
	clip.kill_time = 2.0
	clip.start = 0.0
	clip.end = 2.5
	clip.info = {"seq": 1, "score": 160, "tags": KillScore.T_HEADSHOT, "streak": 0, "distance": 10.0, "weapon": "pistol", "killer": 1, "victim": 9001}
	var killer := KillClip.Track.new()
	var victim := KillClip.Track.new()
	killer.name = "Tester"
	victim.name = "Gizmo"
	for i in 91:
		var t := i / 30.0
		killer.push(t, _frame(Vector3(0, 0, 0), lerpf(1.2, 0.0, minf(t / 1.5, 1.0)), 0.0))
		victim.push(t, _frame(Vector3(0, 0, -10), PI, 0.0, t < 2.05))
	clip.tracks = {1: killer, 9001: victim}
	clip.events = [{"t": 1.95, "who": 1, "kind": "shot", "muzzle": Vector3(0, 1.5, 0),
		"ends": PackedVector3Array([Vector3(0, 1.6, -10)]), "hits": [true], "weapon": "pistol"}]
	return clip


func _playback() -> void:
	print("  playback")
	var world := Node3D.new()
	add_child(world)
	var view := KillcamView.new().setup(_test_clip(), false)
	view.world_sound = false
	world.add_child(view)
	view.set_process(false)   # stepped by hand, so the test does not depend on the frame rate
	var moments := [0]
	var ends := [0]
	view.kill_moment.connect(func(): moments[0] += 1)
	view.finished.connect(func(): ends[0] += 1)
	var step := 1.0 / 60.0
	var steps := 0
	while view.time < 1.8:
		view._process(step)
		steps += 1
	var cam := view.camera.global_transform
	_expect(cam.origin.distance_to(Vector3(0, 1.6, 0)) < 0.01, "the camera is at the killer's eyes (%s)" % [cam.origin])
	var ahead := -cam.basis.z
	_expect(ahead.dot(Vector3(0, 0, -1)) > 0.99, "...looking where they looked: at the victim (%s)" % [ahead])
	var ghost := view.get_node_or_null("Ghost_9001") as Node3D
	_expect(ghost != null and ghost.visible and ghost.global_position.distance_to(Vector3(0, 0, -10)) < 0.01, "the victim is drawn where the clip says")
	_expect(view.get_node_or_null("Ghost_1") == null, "the killer has no body of their own in the way, only arms")
	_expect(view.camera.get_child_count() > 0 and view.camera.get_child(0) is ViewModel, "the killer's first-person arms are on the camera")
	_expect(moments[0] == 0, "no kill before the kill")
	while not view.done and steps < 10000:
		view._process(step)
		steps += 1
	_expect(view._next == 1, "the killing shot played")
	_expect(moments[0] == 1 and ends[0] == 1, "the kill moment and the end are announced once each (%d, %d)" % [moments[0], ends[0]])
	_expect(absf(steps * step - 2.5) < 0.05, "at normal speed the clip lasts as long as it is (%.2f s)" % (steps * step))
	view._process(step)
	_expect(ends[0] == 1 and view.time == 2.5, "then it holds the last frame")
	view.queue_free()
	var slow := KillcamView.new().setup(_test_clip(), true)
	slow.world_sound = false
	world.add_child(slow)
	slow.set_process(false)
	var slow_steps := 0
	while not slow.done and slow_steps < 10000:
		slow._process(step)
		slow_steps += 1
	var expect := 2.5 + (KillcamView.SLOW_FROM + KillcamView.SLOW_UNTIL) * (1.0 / KillcamView.SLOW - 1.0)
	_expect(absf(slow_steps * step - expect) < 0.1, "slow motion round the kill makes it last longer (%.2f s, about %.2f)" % [slow_steps * step, expect])
	slow.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _results_page() -> void:
	print("  results page")
	Net.start_offline("Tester", "needle", "pistol")
	var bot := Net.add_bot(1, "rifle")
	Net.match_settings["map"] = "halcyon"   # the busiest map: terminals, events, low gravity
	Match.last_results = [
		{"id": 1, "name": "Tester", "kills": 3, "deaths": 1, "level": 0},
		{"id": bot, "name": Net.player_name(bot), "kills": 1, "deaths": 3, "level": 0}]
	Match.highlights = [
		{"seq": 4, "score": 345, "tags": KillScore.T_ROPE | KillScore.T_MID_AIR | KillScore.T_HEADSHOT, "streak": 1, "distance": 31.0, "weapon": "pistol", "killer": 1, "victim": bot},
		{"seq": 2, "score": 160, "tags": KillScore.T_HEADSHOT, "streak": 0, "distance": 8.0, "weapon": "rifle", "killer": bot, "victim": 1},
		{"seq": 1, "score": 100, "tags": 0, "streak": 0, "distance": 4.0, "weapon": "pistol", "killer": 1, "victim": bot}]
	Killcam.clips.clear()
	var clip := _test_clip()
	clip.info = Match.highlights[0]
	Killcam.clips[4] = clip
	var holder := SubViewportContainer.new()
	add_child(holder)
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	holder.add_child(vp)
	var page: Control = load("res://game/ui/results_menu.tscn").instantiate()
	vp.add_child(page)
	for i in 8:
		await get_tree().process_frame
	var frame := page.find_children("*", "MenuFrame", true, false)[0] as MenuFrame
	_expect(not frame.scrolling(), "with the best kills on it the page still fits 1600 x 900 without scrolling")
	var screens := page.find_children("*", "KillcamScreen", true, false)
	_expect(screens.size() == 1, "the best kills play first, over the page")
	var whole := Rect2(Vector2.ZERO, Vector2(vp.size))
	if screens.size() == 1:
		var ks := screens[0] as KillcamScreen
		_expect(ks.get_global_rect().is_equal_approx(whole), "...fullscreen (%s)" % [ks.get_global_rect()])
		_expect(ks.index == 2 and ks.find_children("*", "KillcamView", true, false).is_empty(),
			"counting down from #3, which this copy did not see: no replay, it says so (#%d)" % (ks.index + 1))
		ks.next()
		_expect(ks.index == 1, "next: #2")
		ks.next()
		await get_tree().process_frame
		_expect(ks.index == 0 and ks.find_children("*", "KillcamView", true, false).size() == 1, "and last the best, from this copy's clip")
		ks.next()
		await get_tree().process_frame
		_expect(not is_instance_valid(ks) or ks.is_queued_for_deletion(), "after the best the page shows")
	var buttons := page.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.begins_with("#"))
	_expect(buttons.size() == 3, "the page lists the best kills, a button each (%d)" % buttons.size())
	var all := page.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.begins_with("Watch"))
	var screen := whole.grow(0.5)
	_expect(all.size() == 1 and (buttons + all).all(func(b): return screen.encloses((b as Control).get_global_rect())),
		"...and one to watch them all, all on the screen")
	if buttons.size() == 3:
		(buttons[0] as Button).pressed.emit()
		await get_tree().process_frame
		var again := page.find_children("*", "KillcamScreen", true, false)
		_expect(again.size() == 1 and (again[0] as KillcamScreen).index == 0 and (again[0] as KillcamScreen).order.is_empty(),
			"a button plays its kill again, fullscreen, on its own")
		if again.size() == 1:
			(again[0] as KillcamScreen).skip_all()
			await get_tree().process_frame
			_expect(page.find_children("*", "KillcamScreen", true, false).all(func(n): return n.is_queued_for_deletion()), "Esc closes it")
	holder.queue_free()
	Match.highlights = []
	Match.last_results = []
	Killcam.clips.clear()
	await get_tree().process_frame
