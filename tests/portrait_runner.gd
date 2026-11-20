extends Node
## The checks for tests/portrait_test.gd (a Node, so it can use the autoloads).

var _fails: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


func run() -> void:
	var saved := Settings.graphics()
	await _sharpness()
	await _framing()
	await _holds()
	await _turning()
	await _entrance()
	Settings.set_graphics(saved)
	if _fails.is_empty():
		print("PASS: every check passed")
	else:
		print("FAIL:\n  " + "\n  ".join(_fails))
	get_tree().quit(1 if not _fails.is_empty() else 0)


## The picture has as many pixels as the screen shows it at, twice over with the High
## preset's MSAA, and takes its anti-aliasing from the graphics picks. The results
## screen's killcam fills the window's own pixels too, at the game's render scale.
func _sharpness() -> void:
	print("  sharpness")
	var holder := SubViewportContainer.new()   # a window stretched to 1.5 times the menus' canvas
	holder.stretch = true
	holder.size = Vector2(2400, 1350)
	add_child(holder)
	var window := SubViewport.new()
	window.size_2d_override = Vector2i(1600, 900)
	window.size_2d_override_stretch = true
	holder.add_child(window)
	await get_tree().process_frame
	Settings.set_quality("low")
	var view := RobotPreview.new(Vector2(150, 190), 1.15)
	window.add_child(view)
	view.show_robot("needle", Net.PLAYER_COLORS[0])
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(view.view.size == Vector2i(225, 285), "Low: one pixel of 3D for each pixel on screen (%s, not 225x285)" % view.view.size)
	_expect(view.view.msaa_3d == Viewport.MSAA_DISABLED and view.view.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA,
		"Low: FXAA and no MSAA on the picture")
	Settings.set_quality("high")
	Settings.changed.emit()
	await get_tree().process_frame
	_expect(view.view.size == Vector2i(450, 570), "High: drawn at twice the size (%s, not 450x570)" % view.view.size)
	_expect(view.view.msaa_3d == Viewport.MSAA_4X and view.view.screen_space_aa == Viewport.SCREEN_SPACE_AA_SMAA,
		"High: 4x MSAA and SMAA on the picture")
	_expect((view.picture.size * view.picture.scale).is_equal_approx(view.size), "...and shown at the size it was given (%s)" % (view.picture.size * view.picture.scale))
	Settings.render_scale = 0.5
	Settings.changed.emit()
	await get_tree().process_frame
	_expect(view.view.size == Vector2i(450, 570) and is_equal_approx(view.view.scaling_3d_scale, 1.0), "the render scale never shrinks it")
	Settings.render_scale = 1.0
	var big := PortraitView.new()   # the size of the main menu's showcase
	big.size = Vector2(900, 800)
	window.add_child(big)
	await get_tree().process_frame
	_expect(big.view.size == Vector2i(1350, 1200), "a big picture is sharp enough at the screen's own size (%s, not 1350x1200)" % big.view.size)
	big.queue_free()
	var killcam := KillcamScreen.new()   # the results screen's best kills: drawn like the game
	window.add_child(killcam)
	await get_tree().process_frame
	await get_tree().process_frame
	var kv: SubViewport = killcam._view
	_expect(kv.size == Vector2i(2400, 1350), "the killcam replay fills the window's own pixels (%s, not 2400x1350)" % kv.size)
	Settings.render_scale = 0.5
	Settings.changed.emit()
	_expect(kv.size == Vector2i(2400, 1350) and is_equal_approx(kv.scaling_3d_scale, 0.5), "...and follows the render scale, like the game (%.2f)" % kv.scaling_3d_scale)
	Settings.render_scale = 1.0
	Settings.changed.emit()
	_expect(is_equal_approx(kv.scaling_3d_scale, 1.0) and kv.msaa_3d == Viewport.MSAA_4X, "...and your anti-aliasing picks")
	killcam.queue_free()
	window.size_2d_override = Vector2i(2400, 1350)   # the window at the canvas's own size
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(view.view.size == Vector2i(300, 380), "it follows the window's size (%s, not 300x380)" % view.view.size)
	var env: Environment = (view.view.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	_expect(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "the arenas' film look (Filmic)")
	holder.queue_free()
	await get_tree().process_frame


## Every character's head and the front of its ring are inside the frame, whatever the
## frame's shape, and the name is written to end short of the head.
func _framing() -> void:
	print("  framing")
	var tall := "custom:n=Sir Longname the Third|l=frog|t=bulwark|h=wizard|hat=wizard"
	for shape in [Vector2(360, 292), Vector2(360, 440), Vector2(360, 208)]:
		var frame := PortraitFrame.new(shape)
		add_child(frame)
		frame.size = shape
		for id in ["needle", "bulwark", tall]:
			frame.title = Characters.name_of(id).to_upper()
			frame.preview.show_robot(id, Net.PLAYER_COLORS[3], "rifle")
			await get_tree().process_frame
			var camera: Camera3D = frame.preview._camera
			var px := Vector2(frame.preview.view.size)
			var head: Vector2 = camera.unproject_position(Vector3(0, frame.preview.height(), 0)) / px * shape
			var front: Vector2 = camera.unproject_position(Vector3(0, 0, frame.preview._set.radius() * PortraitStage.OUTSIDE)) / px * shape
			_expect(head.y > PortraitFrame.HEAD_ROOM - 8.0 and head.y < shape.y * 0.5, "%s in %s: its head is under the top (%.0f)" % [id.left(12), shape, head.y])
			_expect(front.y < shape.y - 4.0 and front.y > shape.y * 0.6, "%s in %s: the ring is above the bottom (%.0f)" % [id.left(12), shape, front.y])
			var side: Vector2 = camera.unproject_position(Vector3(frame.preview._set.radius() * PortraitStage.OUTSIDE, 0, 0)) / px * shape
			_expect(side.x < shape.x - 2.0, "%s in %s: the ring fits across (%.0f)" % [id.left(12), shape, side.x])
			var room := frame.title_room()
			var size := PortraitFrame._fit_size(frame.title, PortraitFrame.TITLE_SIZE, PortraitFrame.TITLE_MIN, room, false)
			var wide := HudStyle.text_width(frame.title, size)
			_expect(wide <= room or size == PortraitFrame.TITLE_MIN, "%s in %s: the name fits its room (%.0f in %.0f)" % [id.left(12), shape, wide, room])
			_expect(16.0 + room < shape.x * 0.5, "%s in %s: ...which ends before the head" % [id.left(12), shape])
		frame.queue_free()
	await get_tree().process_frame


## Every weapon: the three holds are three different poses, each reached without an
## error, and the flourish runs and ends.
func _holds() -> void:
	print("  holds")
	var view := RobotPreview.new(Vector2(360, 292), 1.0, true)
	add_child(view)
	for id in WeaponData.IDS + ["none"]:
		view.show_robot("needle", Net.PLAYER_COLORS[1], id)
		var poser: PortraitPoser = view._poser
		var robot: RobotModel = poser.robot
		var hand := {}
		for hold in [PortraitPoser.FRONT, PortraitPoser.LOW, PortraitPoser.SIDE]:
			poser.snap(hold)
			poser.update(0.016)
			hand[hold] = robot.skeleton.get_bone_global_pose(robot.rig.bones["hand_r"]).origin
			_expect(is_finite(hand[hold].x) and is_finite(hand[hold].y), "%s: hold %d is a real pose" % [id, hold])
		var fists: bool = id in MeleeModel.BOTH_FISTS
		if id != "none":
			_expect(hand[PortraitPoser.SIDE].distance_to(hand[PortraitPoser.FRONT]) > 0.1, "%s: at its side is not in front" % id)
			if not fists:
				_expect(hand[PortraitPoser.LOW].distance_to(hand[PortraitPoser.FRONT]) > 0.05, "%s: low is not in front" % id)
				_expect(hand[PortraitPoser.LOW].distance_to(hand[PortraitPoser.SIDE]) > 0.05, "%s: low is not at its side" % id)
		var big: bool = WeaponData.look_of(id) in PortraitPoser.SHOULDER_GUNS + PortraitPoser.SHOULDER_MELEE if id != "none" else false
		if id != "none" and not fists and not big:
			_expect(hand[PortraitPoser.SIDE].y < 1.0, "%s: at its side the hand hangs low (%.2f)" % [id, hand[PortraitPoser.SIDE].y])
		poser.snap(poser._home())
		if poser.flourish_now():
			var t := 0.0
			while poser._flourish >= 0.0 and t < 12.0:
				poser.update(0.05)
				t += 0.05
			_expect(t < 12.0, "%s: its flourish ends" % id)
	# Left to itself it changes hold, never staying longer than HOLD_MAX (plus a flourish).
	view.show_robot("needle", Net.PLAYER_COLORS[1], "rifle")
	var seen := {}
	var last := -1
	var since := 0.0
	var longest := 0.0
	for i in 1200:   # two minutes
		view._poser.update(0.1)
		seen[view._poser.hold] = true
		since += 0.1
		if view._poser.hold != last:
			longest = maxf(longest, since) if last >= 0 else 0.0
			since = 0.0
			last = view._poser.hold
	_expect(seen.size() == 3, "left alone it goes through all three holds (%d)" % seen.size())
	_expect(longest < PortraitPoser.HOLD_MAX + 9.0, "it never stays in one long (%.1f s)" % longest)
	view.queue_free()
	await get_tree().process_frame


## Dragging turns it; it turns back a couple of seconds after you let go.
func _turning() -> void:
	print("  turning")
	var frame := PortraitFrame.new(Vector2(360, 292))
	add_child(frame)
	frame.size = Vector2(360, 292)
	frame.preview.show_robot("kestrel", Net.PLAYER_COLORS[2], "pistol")
	await get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	frame._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(120, 0)
	frame._gui_input(move)
	_expect(frame.preview.held and frame.preview.drag > 1.0, "a drag turns it (%.2f)" % frame.preview.drag)
	var turned: float = frame.preview._stage.rotation.y
	frame.preview._process(0.1)
	_expect(not is_equal_approx(frame.preview._stage.rotation.y, turned), "...on its stage")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	frame._gui_input(release)
	frame._process(PortraitFrame.BACK_AFTER * 0.5)
	_expect(frame.preview.drag > 1.0, "let go, it waits")
	for i in 80:
		frame._process(0.05)
	_expect(frame.preview.drag == 0.0, "then turns back to face you (%.3f)" % frame.preview.drag)
	frame.preview.drag = TAU * 2.0 + 0.4   # spun round twice and a bit
	frame._idle = PortraitFrame.BACK_AFTER
	frame._process(0.01)
	_expect(absf(frame.preview.drag) < 0.5, "...by the short way round (%.2f)" % frame.preview.drag)
	frame.queue_free()
	await get_tree().process_frame


## Another character taking the stage builds in; a new gun or colour does not.
func _entrance() -> void:
	print("  entrance")
	var picker := CharacterPicker.new("needle", Net.PLAYER_COLORS[0], "pistol", true)
	add_child(picker)
	await get_tree().process_frame
	var view: RobotPreview = picker._preview
	_expect(view.staged and view._build < 0.0, "the picker's robot is on a stage, already built")
	_expect(picker._stage.title == "NEEDLE" and picker._stage.kicker.begins_with("UNIT 1 /"), "its name and place are over it (%s, %s)" % [picker._stage.title, picker._stage.kicker])
	picker.set_weapon("rifle")
	picker.set_color(Net.PLAYER_COLORS[4])
	_expect(view._build < 0.0 and view.weapon == "rifle", "a new gun or colour just changes")
	picker._on_pressed("kestrel")
	_expect(view._build >= 0.0 and view._robots[0].robot.mesh.material_overlay != null, "another robot builds in")
	_expect(picker._stage.title == "KESTREL", "...under its own name")
	for i in 30:
		view._process(0.05)
	_expect(view._build < 0.0 and view._robots[0].robot.mesh.material_overlay == null, "and is solid within half a second or so")
	picker.peek("bulwark", Net.PLAYER_COLORS[7], "lmg", "Sam")
	_expect(view.character == "bulwark" and picker._stage.kicker == "SAM" and view._build >= 0.0, "someone else's robot builds in too, under their name")
	picker.unpeek()
	_expect(view.character == "kestrel" and picker._stage.title == "KESTREL", "and yours comes back")
	picker.queue_free()
	var creator := CharacterCreator.new("needle")
	add_child(creator)
	await get_tree().process_frame
	_expect(creator._preview.staged and creator._preview.weapon == Game.local_weapon(), "the Character Creator's stands on a stage with your weapon (%s)" % creator._preview.weapon)
	_expect(creator._stage.title == creator.current.name.to_upper(), "under its name")
	creator.step_part("hat", 1)
	_expect(creator._preview._build < 0.0, "trying a hat on changes it at once")
	creator.randomize_parts()
	_expect(creator._preview._build >= 0.0, "a whole new character builds in")
	creator.queue_free()
	await get_tree().process_frame
