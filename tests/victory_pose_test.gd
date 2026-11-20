extends SceneTree
## Who stands on the results page's stage (Podium), how they stand (VictoryPoser) and
## the stage itself (ResultsStage). Looks only.
## Run: godot --headless --fixed-fps 60 --path . --script tests/victory_pose_test.gd
##
## The lineup: a free-for-all's top three with the winner in the middle; a winning
## team's top three, all in victory poses; a draw's two standing easy; a race by
## finishing order, those out of time standing easy; nobody posing when nobody scored;
## the same pose from the same results. The poses: each puts the hands where it says,
## with a gun, a blade, a gun in each hand, fists and nothing; they are moved into after
## the wait, with one flourish, and only the winner's comes again. The stage: empty
## until it begins, then everyone built in, each with a name under it.

const STEP := 1.0 / 60.0

var failures := 0
var robot: RobotModel
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_lineups()
	_poses()
	_stage()
	print("VICTORY POSE TEST PASSED" if failures == 0 else "VICTORY POSE TEST FAILED: %d" % failures)
	_drop()
	quit(1 if failures else 0)
	_done = true
	return false


func _row(id: int, kills: int, more: Dictionary = {}) -> Dictionary:
	var row := {"id": id, "name": "P%d" % id, "kills": kills, "deaths": 10 - kills, "level": 0, "points": 0,
		"character": "needle", "color": "ff8040", "weapon": "rifle"}
	row.merge(more, true)
	return row


func _lineups() -> void:
	print("Who is on the stage")
	_expect("no results: nobody", Podium.lineup([]).is_empty())
	var ffa := [_row(4, 9), _row(2, 7, {"weapon": "sword"}), _row(7, 5), _row(9, 1), _row(3, 0)]
	var who := Podium.lineup(ffa)
	_expect("a free-for-all: the top three", who.size() == 3 and who[0].id == 4 and who[1].id == 2 and who[2].id == 7)
	_expect("...the winner in the middle, second on its left as you look, third on its right",
		who[0].spot == Podium.MIDDLE and who[1].spot == Podium.LEFT and who[2].spot == Podium.RIGHT)
	_expect("...the winner in a victory pose, the others with a nod", who[0].pose < Podium.VICTORIES and who[0].pose == Podium.victory(ffa)
		and who[1].pose == Podium.SPORT and who[2].pose == Podium.SPORT)
	_expect("...named by their places", who[0].label == "1st" and who[1].label == "2nd" and who[2].label == "3rd" and who[0].name == "P4")
	_expect("...with what they looked like and had out as it ended", who[1].weapon == "sword" and who[0].character == "needle"
		and who[0].color is Color and (who[0].color as Color).is_equal_approx(Color.html("ff8040")))
	_expect("the same results give the same pose", Podium.victory(ffa) == Podium.victory(ffa.duplicate(true)))
	var seen := {}
	for i in 60:
		seen[Podium.victory([_row(1, i), _row(2, i / 2), _row(3 + i, 1)])] = true
	_expect("...and other matches the others (all %d turn up)" % Podium.VICTORIES, seen.size() == Podium.VICTORIES, str(seen.keys()))
	_expect("two players: the two of them", Podium.lineup(ffa.slice(0, 2)).size() == 2)
	_expect("a row without looks: left to the player's own", Podium.lineup([{"id": 5, "name": "Old", "kills": 3}])[0].character == ""
		and Podium.lineup([{"id": 5, "name": "Old", "kills": 3}])[0].color == null)
	var nobody := Podium.lineup([_row(1, 0), _row(2, 0)])
	_expect("nobody scored: nobody poses", nobody.size() == 2 and nobody[0].pose == Podium.EASY and nobody[1].pose == Podium.EASY)
	var gun_game := Podium.lineup([_row(1, 0, {"level": 3}), _row(2, 0)])
	_expect("...a level reached or points scored counts as scoring", gun_game[0].pose < Podium.VICTORIES)

	print("Teams")
	var red := {"team": 0, "teams": "snd", "scores": [4, 2], "team_won": true}
	var blue := {"team": 1, "teams": "snd", "scores": [4, 2], "team_won": false}
	var teams := [_row(1, 6, red), _row(2, 4, red), _row(3, 2, red), _row(4, 1, red), _row(5, 9, blue), _row(6, 3, blue)]
	who = Podium.lineup(teams)
	_expect("the winning team's top three (not the other team's best)", who.size() == 3 and who[0].id == 1 and who[1].id == 2 and who[2].id == 3)
	_expect("...all in victory poses, each its own", who[0].pose < Podium.VICTORIES and who[1].pose < Podium.VICTORIES and who[2].pose < Podium.VICTORIES
		and who[0].pose != who[1].pose and who[1].pose != who[2].pose and who[0].pose != who[2].pose)
	_expect("...the top scorer in the middle", who[0].spot == Podium.MIDDLE and who[0].label == "Top scorer" and who[1].label == "Red team")
	var blue_won := [_row(5, 2, blue.merged({"scores": [1, 4]}, true)), _row(1, 6, red.merged({"scores": [1, 4]}, true))]
	who = Podium.lineup(blue_won)
	_expect("the other team winning: theirs, however few", who.size() == 1 and who[0].id == 5)
	var level := [_row(1, 6, red.merged({"scores": [3, 3]}, true)), _row(2, 4, red.merged({"scores": [3, 3]}, true)), _row(5, 9, blue.merged({"scores": [3, 3]}, true))]
	who = Podium.lineup(level)
	_expect("a draw: each team's top scorer, standing easy, side by side", who.size() == 2 and who[0].id == 1 and who[1].id == 5
		and who[0].pose == Podium.EASY and who[1].pose == Podium.EASY and who[0].spot == Podium.LEFT and who[1].spot == Podium.RIGHT
		and who[0].label == "Red team" and who[1].label == "Blue team")

	print("A race")
	var race := [_row(3, 0, {"race": true, "finished": true, "time": 61.2}), _row(1, 0, {"race": true, "finished": true, "time": 70.0}),
		_row(2, 0, {"race": true, "finished": false, "time": -1.0}), _row(4, 0, {"race": true, "finished": false, "time": -1.0})]
	who = Podium.lineup(race)
	_expect("the first three by finishing order", who.size() == 3 and who[0].id == 3 and who[1].id == 1 and who[2].id == 2)
	_expect("...finishers pose, whoever ran out of time stands easy", who[0].pose < Podium.VICTORIES and who[1].pose == Podium.SPORT
		and who[2].pose == Podium.EASY and who[2].label == "Out of time" and who[1].label == "2nd")
	who = Podium.lineup([_row(1, 0, {"race": true, "finished": true, "time": 50.0})])
	_expect("alone: just you, posing if you finished", who.size() == 1 and who[0].pose < Podium.VICTORIES)
	who = Podium.lineup([_row(1, 0, {"race": true, "finished": false, "time": -1.0})])
	_expect("...and standing easy if you did not", who.size() == 1 and who[0].pose == Podium.EASY)


func _poses() -> void:
	print("The poses")
	for gun in ["rifle", "sword", "akimbo", "claws", "none", "rocket_launcher", "spear"]:
		for kind in [Podium.RAISE, Podium.PUMP, Podium.HIP, Podium.PRESENT, Podium.SPORT, Podium.EASY]:
			var p := _fresh(gun, kind)
			p.settle()
			p.update(STEP)
			var head := _at("head").y
			var right := _at("hand_r")
			var left := _at("hand_l")
			var shoulder := _at("upper_arm_r").y
			var ok := true
			var why := "right %.2f %.2f %.2f, left %.2f %.2f %.2f, head %.2f" % [right.x, right.y, right.z, left.x, left.y, left.z, head]
			match kind:
				Podium.RAISE:
					ok = right.y > head + 0.15 and left.y < shoulder - 0.25
				Podium.PUMP:
					ok = left.y > shoulder and left.y < head + 0.35 and right.y < head
				Podium.HIP:
					ok = (left.y < shoulder - 0.25 and left.y > shoulder - 0.6 and absf(left.x) < 0.4) or gun == "akimbo"
				Podium.PRESENT:
					ok = absf(right.x - left.x) > 0.95
				_:
					ok = right.y < shoulder + 0.05
			if not ok or kind == Podium.RAISE:
				_expect("%s with %s" % [Podium.NAMES[kind], gun], ok, why)
	_expect("(every pose with every kind of weapon)", true)
	for blade in ["dagger", "katana", "sword"]:
		var planted := _fresh(blade, Podium.HIP)
		planted.settle()
		for i in 3:
			planted.update(STEP)
		# (Where its point is with the bones as they are now: what hangs on a bone is only moved at the end of a frame.)
		var hook: Node = robot.melee
		while hook != null and not hook is BoneAttachment3D:
			hook = hook.get_parent()
		var on_bone: Vector3 = (hook as BoneAttachment3D).global_transform.affine_inverse() * (MeleeModel.edge(robot.melee)[1] as Vector3)
		var point: Vector3 = robot.skeleton.get_bone_global_pose(robot.skeleton.find_bone((hook as BoneAttachment3D).bone_name)) * on_bone
		_expect("a %s planted beside it: its point is not under the floor (%.2f m up)" % [blade, point.y], point.y > -0.04 and point.y < _at("hand_r").y)

	print("Getting into one")
	var p := _fresh("rifle", Podium.RAISE)
	p.wait = 0.5
	for i in 24:
		p.update(STEP)
	_expect("it waits (still building in)", p.settled() == 0.0 and _at("hand_r").y < _at("head").y)
	var flourishes := 0
	var was := -1.0
	for i in 110:
		p.update(STEP)
		if p.flourishing() >= 0.0 and was < 0.0:
			flourishes += 1
		was = p.flourishing()
	_expect("then moves into it over a second", p.settled() == 1.0 and _at("hand_r").y > _at("head").y + 0.15)
	_expect("...with one flourish as it gets there", flourishes == 1, str(flourishes))
	for i in int((VictoryPoser.BEAT_MAX + 2.0) / STEP):
		p.update(STEP)
		if p.flourishing() >= 0.0 and was < 0.0:
			flourishes += 1
		was = p.flourishing()
	_expect("...and no more of them (it is not the winner)", flourishes == 1, str(flourishes))
	p = _fresh("rifle", Podium.RAISE)
	p.repeats = true
	flourishes = 0
	was = -1.0
	var top := 0.0
	var low := 9.0
	for i in int((1.0 + VictoryPoser.FLOURISH + VictoryPoser.BEAT_MAX + 2.0) / STEP):
		p.update(STEP)
		if p.flourishing() >= 0.0 and was < 0.0:
			flourishes += 1
		was = p.flourishing()
		if p.settled() == 1.0:
			top = maxf(top, _at("hand_r").y)
			low = minf(low, _at("hand_r").y)
	_expect("the winner's comes again every several seconds", flourishes >= 2, str(flourishes))
	_expect("...the weapon pumped in the air (%.2f m)" % (top - low), top - low > 0.08)
	p = _fresh("sword", Podium.PRESENT)
	p.update(STEP)
	_expect("presenting: it starts turned right round", absf(p.spin) > 5.0, "%.2f" % p.spin)
	for i in 70:
		p.update(STEP)
	_expect("...and ends facing you", p.spin == 0.0)
	p = _fresh("pistol", Podium.EASY)
	flourishes = 0
	for i in 200:
		p.update(STEP)
		if p.flourishing() >= 0.0:
			flourishes += 1
	_expect("standing easy: no flourish", flourishes == 0)
	p = _fresh("pistol", Podium.SPORT)
	p.look = 1.0
	p.settle()
	p.update(STEP)
	var to_left := _facing("head").x
	p = _fresh("pistol", Podium.SPORT)
	p.look = -1.0
	p.settle()
	p.update(STEP)
	_expect("a good sport looks toward the winner, whichever side that is", to_left * _facing("head").x < 0.0 and absf(to_left) > 0.2,
		"%.2f %.2f" % [to_left, _facing("head").x])


func _stage() -> void:
	print("The stage")
	_drop()
	var stage: Control = load("res://game/ui/results_stage.gd").new()
	root.add_child(stage)
	var who := Podium.lineup([_row(4, 9), _row(2, 7, {"weapon": "sword"}), _row(7, 5, {"weapon": "none"}), _row(9, 1)])
	stage.show_podium(who)
	var robots: Array = stage._robots
	_expect("three robots, none to be seen yet", robots.size() == 3 and not robots[0].robot.visible and not robots[2].robot.visible)
	_expect("...each with what it had out", robots[0].robot.weapon == "rifle" and robots[1].robot.weapon == "sword" and robots[2].robot.weapon == "none")
	_expect("...the winner in the middle and in front", is_zero_approx(robots[0].robot.position.x) and robots[1].robot.position.x < -0.5
		and robots[2].robot.position.x > 0.5 and robots[1].robot.position.z < robots[0].robot.position.z)
	_expect("...and only the winner's flourish comes again", stage.poser(0).repeats and not stage.poser(1).repeats)
	stage._step(1.0)
	_expect("nothing happens until it begins", not robots[0].robot.visible and stage.poser(0).settled() == 0.0)
	stage.begin()
	stage._step(STEP)
	_expect("then the winner builds in first", robots[0].robot.visible and robots[0].robot.mesh.material_overlay != null and not robots[2].robot.visible)
	for i in 150:
		stage._step(STEP)
	_expect("...then the others, and they are all there", robots[1].robot.visible and robots[2].robot.visible and robots[0].robot.mesh.material_overlay == null
		and robots[2].robot.mesh.material_overlay == null)
	_expect("...in their poses", stage.poser(0).settled() == 1.0 and stage.poser(2).settled() == 1.0)
	_expect("a name under each", stage._tags.size() == 3 and (stage._tags[1].get_child(0) as Label).text == "P2" and (stage._tags[1].get_child(1) as Label).text == "2nd"
		and is_equal_approx(stage._tags[1].modulate.a, 1.0))
	stage.show_podium(Podium.lineup([_row(1, 0, {"race": true, "finished": true, "time": 50.0})]))
	_expect("shown again with someone else: just them", stage._robots.size() == 1 and stage._tags.size() == 1)
	stage.settle()
	_expect("...straight into the pose when told", stage._robots[0].robot.visible and stage.poser(0).settled() == 1.0)
	stage.queue_free()


# --- Helpers

func _fresh(gun: String, kind: int) -> VictoryPoser:
	_drop()
	robot = RobotModel.new().build("needle", Color(1.0, 0.4, 0.2), false, gun)
	root.add_child(robot)
	var p := VictoryPoser.new(robot, kind)
	p.update(0.0)
	return p


## Where a bone is, in the robot's own space.
func _at(bone: String) -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.skeleton.find_bone(bone)).origin


## Which way a bone faces (its own -Z), in the robot's own space.
func _facing(bone: String) -> Vector3:
	return robot.skeleton.get_bone_global_pose(robot.skeleton.find_bone(bone)).basis * Vector3.FORWARD


func _drop() -> void:
	if robot == null:
		return
	for i in robot.mesh.mesh.get_surface_count():   # headless Godot grumbles otherwise
		robot.mesh.set_surface_override_material(i, null)
	robot.queue_free()
	robot = null


func _expect(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok or detail == "" else "  [" + detail + "]"])
	if not ok:
		failures += 1
