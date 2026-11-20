class_name ResultsStage
extends RobotPreview
## The results page's stage: whoever Podium.lineup says, on the lobby portrait's lit
## stage (PortraitStage), each with the weapon they had out as the match ended and in
## their pose (VictoryPoser), their name and place under them.
##
## The one in the middle stands on the ring, a step forward of the others, who are
## turned in a little toward it. Nothing is on the stage until begin() (the page is
## under the best kills at first); then they build in one after another, like the
## lobby's portrait, and move into their poses.
##
##   var stage := ResultsStage.new()
##   stage.show_podium(Podium.lineup(Match.last_results))
##   stage.begin()

const SIZE := Vector2(460, 480)   ## the picture, on the menus' canvas
const SIDE := 1.1          ## metres either side of the middle the others stand...
const BACK := 0.7          ## ...and behind it
const TURN_IN := 0.3       ## radians they are turned toward the middle
const STAGGER := 0.25      ## seconds between one building in and the next
const ROOM_ABOVE := 2.55   ## metres of height the picture has room for (a weapon held up over a head)...
const ROOM_BELOW := 0.62   ## ...and below their feet (the ring, and their names)
const ROOM_ACROSS := 0.45  ## ...and either side of the outermost one

var who: Array = []        ## who is on it (Podium.lineup's entries)

var _posers: Array = []    # a VictoryPoser each
var _facing: Array = []    # which way each stands (radians)
var _builds: Array = []    # seconds into building in, each (less than 0: not yet; INF: done)
var _holograms: Array = [] # the hologram each builds in from
var _tags: Array = []      # the name and place under each
var _begun := false
var _tallest := 1.8


func _init(stage_size: Vector2 = SIZE) -> void:
	super(stage_size, 1.0, true)
	turn = false


## Put these on the stage (Podium.lineup's entries; an entry without a character, a
## colour or a weapon gets its player's as they are now).
func show_podium(lineup: Array) -> void:
	_drop_robots()
	who = lineup
	_lineup = false
	_stage.rotation.y = 0.0
	_tallest = 1.8
	for i in lineup.size():
		var e: Dictionary = lineup[i]
		var id := int(e.id)
		var looks := Characters.valid(str(e.character)) if str(e.get("character", "")) != "" else Net.player_character(id)
		var tint: Color = e.color if e.get("color") is Color else Net.player_color(id)
		var gun := str(e.get("weapon", ""))
		if gun == "":
			gun = Net.player_weapon(id)
		gun = gun if gun == "none" else WeaponData.valid(gun)
		var spot := int(e.spot)
		var side := 0.0 if spot == Podium.MIDDLE else (-1.0 if spot == Podium.LEFT else 1.0)
		var alone := lineup.size() == 2 and spot != Podium.MIDDLE   # (two side by side: a draw)
		var robot := RobotModel.new().build(looks, tint, false, gun)
		robot.position = Vector3(side * (SIDE * 0.62 if alone else SIDE), 0.0, 0.0 if spot == Podium.MIDDLE or alone else -BACK)
		robot.visible = false
		_stage.add_child(robot)
		_robots.append({"robot": robot})
		var poser := VictoryPoser.new(robot, int(e.pose), _stage)
		poser.wait = BUILD_IN + i * STAGGER
		poser.repeats = spot == Podium.MIDDLE and int(e.pose) < Podium.VICTORIES
		poser.look = -side   # (it faces you: the middle is to its own left when it stands on your left)
		poser.update(0.0)
		_posers.append(poser)
		_facing.append(PI - side * TURN_IN)
		robot.rotation.y = _facing[i]
		_builds.append(-i * STAGGER)
		_holograms.append(null)
		var box := robot.mesh.get_aabb()
		if box.size != Vector3.ZERO:
			_tallest = maxf(_tallest, clampf(box.end.y, 1.2, 2.7))
		_tags.append(_tag(str(e.name), str(e.label), id == Net.my_id()))
		if spot == Podium.MIDDLE or i == 0:
			_set.set_color(RobotModel.trim_color(tint))
			_rim.light_color = RobotModel.trim_color(tint).lerp(Color.WHITE, 0.2)
	_begun = false
	_frame()


## They come onto the stage now (once: again does nothing).
func begin() -> void:
	if _begun or _robots.is_empty():
		return
	_begun = true
	_set.pulse()
	if is_inside_tree():
		Sound.play("ui_materialize")


## The poser of the `i`th on the stage (pictures and tests).
func poser(i: int) -> VictoryPoser:
	return _posers[i] if i >= 0 and i < _posers.size() else null


## All of them straight into their poses, built in (pictures and tests).
func settle() -> void:
	begin()
	for i in _posers.size():
		(_posers[i] as VictoryPoser).settle()
		_builds[i] = INF
		_show_hologram(i)
	_step(0.0)


func _step(delta: float) -> void:
	if not _begun:
		return
	for i in _posers.size():
		var robot: RobotModel = _robots[i].robot
		var poser: VictoryPoser = _posers[i]
		if _builds[i] != INF:
			_builds[i] += delta
			_show_hologram(i)
		if not robot.visible:
			continue
		poser.update(delta)
		robot.rotation.y = _facing[i] + poser.spin
	_set.update(delta)
	_place_camera()
	_place_tags()


## Building in: nothing, then a hologram in its player's colour made solid from the
## feet up (as RobotPreview's one character does), then itself.
func _show_hologram(i: int) -> void:
	var robot: RobotModel = _robots[i].robot
	var t: float = _builds[i]
	robot.visible = t >= 0.0
	(_tags[i] as Control).modulate.a = clampf(t / BUILD_IN, 0.0, 1.0) if t != INF else 1.0
	if t < 0.0:
		return
	if t >= BUILD_IN:
		_builds[i] = INF
		_overlay_on(robot, null)
		return
	if _holograms[i] == null:
		var hologram := ShaderMaterial.new()
		hologram.shader = PortraitStage.hologram_shader()
		hologram.set_shader_parameter("tint", RobotModel.trim_color(who[i].color if who[i].get("color") is Color else Net.player_color(int(who[i].id))))
		_holograms[i] = hologram
	(_holograms[i] as ShaderMaterial).set_shader_parameter("line", lerpf(-0.08, _tallest + 0.12, t / BUILD_IN))
	_overlay_on(robot, _holograms[i])


## The camera: a little below their middles, looking up, from far enough back that
## the whole row, a weapon held up over a head and the names under their feet all fit.
func _frame() -> void:
	if size.y < 1.0 or _robots.is_empty():
		return
	_camera.fov = _base_fov
	var half := tan(deg_to_rad(_base_fov * 0.5))
	var top := maxf(ROOM_ABOVE, _tallest + 0.45)
	var tall := top + ROOM_BELOW
	var across := ROOM_ACROSS
	for r in _robots:
		across = maxf(across, absf((r.robot as RobotModel).position.x) + ROOM_ACROSS)
	var dist := maxf(tall * 0.5 / half, across / (half * size.x / size.y))
	var middle := (top - ROOM_BELOW) * 0.5
	_per_metre = size.y * 0.5 / (half * dist)
	_set.set_radius(PortraitStage.RADIUS)
	# (Lower than the middle and tipped up to it: the same row, seen from a hero's angle.)
	_eye = Vector3(0.0, middle - 0.3, dist)
	_look = Vector3(0.0, middle + 0.03, 0.0)
	_place_camera()
	_place_tags()
	framed.emit()


func _tag(player: String, place: String, me: bool) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -2)
	box.modulate.a = 0.0
	for line in [[player, 15, UiKit.ACCENT if me else UiKit.TEXT, true], [place, 12, UiKit.TEXT_DIM, false]]:
		var l := Label.new()
		l.text = line[0]
		l.add_theme_font_override("font", HudStyle.font(line[3]))
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", line[2])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.custom_minimum_size = Vector2(150, 0)
		box.add_child(l)
	add_child(box)
	return box


## Each name under its own feet, wherever the camera has them now.
func _place_tags() -> void:
	if view.size.x < 1 or _tags.size() != _robots.size():
		return
	var scale_ := size / Vector2(view.size)
	for i in _tags.size():
		var robot: RobotModel = _robots[i].robot
		var tag: Control = _tags[i]
		var feet := _camera.unproject_position(robot.global_position) * scale_ if robot.is_inside_tree() and _camera.is_inside_tree() else Vector2.ZERO
		var wide := maxf(tag.size.x, 150.0)
		tag.position = Vector2(clampf(feet.x - wide * 0.5, 0.0, maxf(size.x - wide, 0.0)), minf(feet.y + 8.0, size.y - tag.size.y))


func _drop_robots() -> void:
	super()
	_posers.clear()
	_facing.clear()
	_builds.clear()
	_holograms.clear()
	for tag in _tags:
		(tag as Node).queue_free()
	_tags.clear()
	who = []
	_begun = false
