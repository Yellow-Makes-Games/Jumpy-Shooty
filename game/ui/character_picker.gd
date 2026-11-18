class_name CharacterPicker
extends VBoxContainer
## "Robot" chooser for the menus: the robot you have picked stands on a lit stage
## (in its idle pose, turning slowly, in your colour, holding your weapon) with its
## name over it and arrows either side to step through the others; under the stage,
## a button for every robot and a line about the one picked.
##
## Characters made in the Character Creator come after the robots.
##
## The picker only reports the choice; the screen using it decides what to do with
## it (save it, tell the lobby).

signal picked(id: String)

const STAGE := Vector2(360, 292)
const COLUMNS := 4

var current := ""

var _color := Color.WHITE
var _weapon := "pistol"
var _buttons := {}                 # character id -> Button
var _ids: Array = []               # every character offered, in order
var _grid: GridContainer
var _group := ButtonGroup.new()
var _blurb: Label
var _stage: Control
var _preview: RobotPreview
var _time := 0.0


func _init(start: String = "", player_color: Color = Net.PLAYER_COLORS[0], gun: String = "pistol") -> void:
	_color = player_color
	_weapon = WeaponData.valid(gun)
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(STAGE.x, 0)
	UiKit.section(self, "Robot")
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE
	_stage.clip_contents = true
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	_preview = RobotPreview.new(STAGE)
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_preview)
	_arrow("<", Control.PRESET_CENTER_LEFT, -1)
	_arrow(">", Control.PRESET_CENTER_RIGHT, 1)
	# A grid, so the buttons stay compact however many robots there are.
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	for id in Characters.ids() + Settings.custom_characters:
		_add_button(id)
	_blurb = UiKit.label(self, "", true, 15)
	_blurb.custom_minimum_size = Vector2(0, 40)
	select(Characters.valid(start))


func _add_button(id: String) -> void:
	id = Characters.valid(id)
	if _buttons.has(id):
		return
	var b := Button.new()
	b.text = Characters.name_of(id)
	b.toggle_mode = true
	b.button_group = _group
	b.theme_type_variation = "Chip"
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	if Characters.is_custom(id):
		b.add_theme_color_override("font_color", UiKit.CYAN)
		b.tooltip_text = Characters.info(id).blurb
	b.pressed.connect(_on_pressed.bind(id))
	b.set_meta("sfx", "select")
	_grid.add_child(b)
	_buttons[id] = b
	# Characters from the Character Creator come after the 8 robots: each extra row of
	# buttons takes its height off the stage, so the pages it sits on stay the same height.
	var rows := ceili(_buttons.size() / float(COLUMNS))
	_stage.custom_minimum_size.y = STAGE.y - maxi(rows - 2, 0) * 42.0
	_ids.append(id)


## An arrow at the side of the stage that steps to the next or the last robot.
func _arrow(text: String, side: Control.LayoutPreset, step: int) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "Chip"
	b.custom_minimum_size = Vector2(36, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Next robot" if step > 0 else "Previous robot"
	b.set_meta("sfx", "select")
	b.pressed.connect(func():
		_on_pressed(_ids[posmod(_ids.find(current) + step, _ids.size())]))
	_stage.add_child(b)
	b.set_anchors_and_offsets_preset(side, Control.PRESET_MODE_MINSIZE, 8)


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		_stage.queue_redraw()


## The stage behind the robot: a dark plate, a cone of light in your colour, rings
## on the floor under its feet, and its name in the corner.
func _draw_stage() -> void:
	var s := _stage.size
	var r := Rect2(Vector2.ZERO, s)
	HudStyle.framed_plate(_stage, r.grow(-1.0), 18.0, Color(0.02, 0.03, 0.05, 0.75), Color(UiKit.LINE, 0.22))
	var glow := _color.lerp(Color.WHITE, 0.15)
	var floor_c := Vector2(s.x * 0.5, s.y * 0.86)
	# A cone of light down onto the floor.
	_stage.draw_polygon(PackedVector2Array([Vector2(s.x * 0.5 - 30, 0), Vector2(s.x * 0.5 + 30, 0),
			floor_c + Vector2(120, 0), floor_c - Vector2(120, 0)]),
		PackedColorArray([Color(glow, 0.0), Color(glow, 0.0), Color(glow, 0.13), Color(glow, 0.13)]))
	# Rings on the floor: flat circles, the outer one turning slowly.
	_stage.draw_set_transform(floor_c, 0.0, Vector2(1.0, 0.26))
	_stage.draw_circle(Vector2.ZERO, 112.0, Color(glow, 0.10))
	_stage.draw_arc(Vector2.ZERO, 112.0, 0.0, TAU, 64, Color(glow, 0.75), 2.0, true)
	_stage.draw_arc(Vector2.ZERO, 84.0, 0.0, TAU, 48, Color(glow, 0.3), 1.5, true)
	for i in 6:
		var a := _time * 0.5 + i * TAU / 6.0
		_stage.draw_arc(Vector2.ZERO, 132.0, a, a + 0.5, 12, Color(UiKit.CYAN, 0.55), 3.0, true)
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Its name and where it is in the list.
	HudStyle.label(_stage, Vector2(16, 20), ("CUSTOM %d / %d" if Characters.is_custom(current) else "UNIT %d / %d") % [_ids.find(current) + 1, _ids.size()], 11, Color(UiKit.CYAN, 0.9))
	HudStyle.text(_stage, Vector2(16, 44), Characters.name_of(current).to_upper(), 28, Color.WHITE)
	HudStyle.brackets(_stage, r.grow(-8.0), 12.0, Color(1, 1, 1, 0.25), 1.5)


## Show `id` as the picked character without reporting it (for example when the
## lobby tells us what the host has on record).
func select(id: String) -> void:
	id = Characters.valid(id)
	if id == current:
		return
	_add_button(id)   # someone's custom character this copy hasn't saved
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


## Put this gun in the preview robot's hands.
func set_weapon(id: String) -> void:
	if WeaponData.valid(id) != _weapon:
		_weapon = WeaponData.valid(id)
		_show_robot()


func _show_robot() -> void:
	_preview.show_robot(current, _color, _weapon)
