class_name CharacterPicker
extends VBoxContainer
## "Character" chooser for the menus: one button per robot, with a live preview of
## the one picked (standing in its idle pose, turning slowly, in your colour).
##
## The picker only reports the choice; the screen using it decides what to do with
## it (save it, tell the lobby).

signal picked(id: String)

const PREVIEW_SMALL := Vector2(150, 190)   # beside the buttons (menu pages)
const PREVIEW_TALL := Vector2(230, 280)    # above the buttons (the lobby's side column)

var current := ""

var _color := Color.WHITE
var _buttons := {}                 # character id -> Button
var _blurb: Label
var _stage: Node3D                 # holds the robot inside the preview
var _robot: RobotModel
var _pose: RobotPose
var _time := 0.0


## tall: put the preview above the buttons (for a narrow column) instead of beside them.
func _init(start: String = "", player_color: Color = Net.PLAYER_COLORS[0], tall: bool = false) -> void:
	_color = player_color
	add_theme_constant_override("separation", 6)
	UiKit.label(self, "Character", true, 16)
	var box: BoxContainer = VBoxContainer.new() if tall else HBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if tall else 14)
	add_child(box)
	var preview := _build_preview(PREVIEW_TALL if tall else PREVIEW_SMALL)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(preview)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 8)
	box.add_child(side)
	var buttons: BoxContainer = HBoxContainer.new() if tall else VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	side.add_child(buttons)
	var group := ButtonGroup.new()
	for c in Characters.LIST:
		var b := Button.new()
		b.text = c.name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_pressed.bind(c.id))
		buttons.add_child(b)
		_buttons[c.id] = b
	_blurb = UiKit.label(side, "", true, 15)
	_blurb.custom_minimum_size = Vector2(0, 44)
	select(Characters.valid(start))


## Show `id` as the picked character without reporting it (for example when the
## lobby tells us what the host has on record).
func select(id: String) -> void:
	id = Characters.valid(id)
	if id == current:
		return
	current = id
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(key == id)
	_blurb.text = Characters.info(id).blurb
	_show_robot()


## Use this colour for the preview's trim and visor.
func set_color(player_color: Color) -> void:
	if player_color != _color:
		_color = player_color
		_show_robot()


func _on_pressed(id: String) -> void:
	if id == current:
		_buttons[id].set_pressed_no_signal(true)
		return
	select(id)
	picked.emit(id)


func _process(delta: float) -> void:
	if _robot == null or not is_visible_in_tree():
		return
	_time += delta
	_robot.rig.sample(_pose, "idle", fmod(_time, _robot.rig.length("idle")))
	_pose.apply(_robot.skeleton)
	_stage.rotation.y = deg_to_rad(200.0) + sin(_time * 0.6) * deg_to_rad(24.0)   # 180 = facing you


# A small 3D scene of its own (own world, so the arena never shows through).
func _build_preview(preview_size: Vector2) -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = preview_size
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	frame.add_child(view)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.80, 0.90)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX   # the same film look as the arenas
	var world := WorldEnvironment.new()
	world.environment = env
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.3
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 28.0
	camera.position = Vector3(0, 1.0, 4.6)
	view.add_child(camera)
	_stage = Node3D.new()
	view.add_child(_stage)
	return frame


func _show_robot() -> void:
	_drop_robot()
	_robot = RobotModel.new().setup(Characters.body(current), _color)
	_stage.add_child(_robot)
	_pose = _robot.rig.new_pose()
	_robot.rig.sample(_pose, "idle", 0.0)
	_pose.apply(_robot.skeleton)


func _exit_tree() -> void:
	_drop_robot()


func _drop_robot() -> void:
	if _robot == null or not is_instance_valid(_robot):
		return
	# Let go of the per-player materials first; headless Godot (used by the tests)
	# prints an error when a robot inside the preview's own 3D world is freed with them.
	for i in _robot.mesh.mesh.get_surface_count():
		_robot.mesh.set_surface_override_material(i, null)
	_robot.queue_free()
	_robot = null
