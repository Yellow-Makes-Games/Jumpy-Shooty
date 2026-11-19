class_name CharacterPicker
extends VBoxContainer
## "Robot" chooser for the menus: the robot you have picked stands on a lit stage
## (in its idle pose, turning slowly, in your colour, holding your weapon) with its
## name over it and arrows either side to step through the others; under the stage,
## a button for every robot and a line about the one picked.
##
## Characters made in the Character Creator come after the robots.
##
## Compact (the lobby): the page keeps only the stage and, under it, a button with the
## robot's name; the buttons for every robot and the line about the one picked go in
## `list` instead, which the page shows in a FloatingPanel when the name is pressed
## (list_requested).
##
## Where the screen offers it (offer_colors), a swatch in the corner of the stage
## opens your own colour: the one you wear in a free-for-all.
##
## The picker only reports the choice; the screen using it decides what to do with
## it (save it, tell the lobby).

signal picked(id: String)
signal list_requested   ## compact: the name under the stage was pressed
signal create_requested ## compact: "Make new character" in the list was pressed
signal color_picked(index: int)   ## a colour from the stage's swatch (a number in Net.PLAYER_COLORS)

const STAGE := Vector2(360, 292)
const COLUMNS := 4
const LIST_COLUMNS := 8   ## compact: robots per row in the list
const NAME_SIZE := 14      ## a robot button's font size, when its name fits
const NAME_MIN := 9       ## the smallest a long name (a custom character's) shrinks to

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
var _compact := false
var _name_button: Button   ## compact: the robot's name under the stage; opens the list
var _color_button: Button  ## the swatch in the corner of the stage (see offer_colors)
var _palette: SwatchPalette

## Compact: the buttons for every robot and the line about the one picked (the page
## puts it in a FloatingPanel). Otherwise null: they are in the picker itself.
var list: VBoxContainer


func _init(start: String = "", player_color: Color = Net.PLAYER_COLORS[0], gun: String = "pistol", compact: bool = false) -> void:
	_color = player_color
	_weapon = WeaponData.valid(gun)
	_compact = compact
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(STAGE.x, 0)
	if not compact:
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
	_color_button = Button.new()
	_color_button.name = "color"
	_color_button.theme_type_variation = "Chip"
	_color_button.custom_minimum_size = Vector2(40, 36)
	_color_button.focus_mode = Control.FOCUS_NONE
	_color_button.icon = SwatchPalette.swatch(_color)
	_color_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SwatchPalette.true_colors(_color_button)
	_color_button.tooltip_text = "Your colour in a free-for-all"
	_color_button.set_meta("sfx", "select")
	_color_button.visible = false
	_color_button.pressed.connect(open_colors)
	_stage.add_child(_color_button)
	_color_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_palette = SwatchPalette.new(8)
	add_child(_palette)
	var holder: VBoxContainer = self
	if compact:
		_name_button = Button.new()
		_name_button.theme_type_variation = "Chip"
		_name_button.toggle_mode = true
		_name_button.button_pressed = true   # drawn lit, as the pick
		_name_button.custom_minimum_size = Vector2(150, 38)
		_name_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_name_button.add_theme_font_size_override("font_size", 15)
		_name_button.tooltip_text = "Pick your robot"
		_name_button.pressed.connect(func():
			_name_button.set_pressed_no_signal(true)
			list_requested.emit())
		add_child(_name_button)
		list = VBoxContainer.new()
		list.add_theme_constant_override("separation", 10)
		UiKit.section(list, "Robot")
		holder = list
	# A grid, so the buttons stay compact however many robots there are.
	_grid = GridContainer.new()
	_grid.columns = LIST_COLUMNS if compact else COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	holder.add_child(_grid)
	for id in Characters.ids() + Settings.custom_characters:
		_add_button(id)
	_blurb = UiKit.label(holder, "", true, 15)
	_blurb.custom_minimum_size = Vector2(0, 40)
	if compact:   # the Character Creator, from the list (the page opens it)
		var make := UiKit.button(list, "Make new character", func(): create_requested.emit())
		make.theme_type_variation = "Chip"
		make.custom_minimum_size = Vector2(220, 40)
		make.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		make.set_meta("sfx", "select")
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
	b.custom_minimum_size = Vector2(110 if _compact else 0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", NAME_SIZE)
	b.resized.connect(_fit_name.bind(b))
	if Characters.is_custom(id):
		b.add_theme_color_override("font_color", UiKit.CYAN)
		b.tooltip_text = "%s
%s" % [b.text, Characters.info(id).blurb]
	b.pressed.connect(_on_pressed.bind(id))
	b.set_meta("sfx", "select")
	_grid.add_child(b)
	_buttons[id] = b
	# Characters from the Character Creator come after the 8 robots: each extra row of
	# buttons takes its height off the stage, so the pages it sits on stay the same height.
	if not _compact:   # (compact: the buttons are in the list, not under the stage)
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
	if _name_button:
		_name_button.text = Characters.name_of(id)
	_show_robot()


## Use this colour for the preview's trim and visor.
func set_color(player_color: Color) -> void:
	if player_color != _color:
		_color = player_color
		_color_button.icon = SwatchPalette.swatch(_color)
		_show_robot()


## Show (or hide) the swatch that lets you pick your own colour. The screen hears
## color_picked and shows the result with set_color.
func offer_colors(on: bool) -> void:
	_color_button.visible = on


## The colours to pick from: all of them, less the ones other players have.
func open_colors() -> void:
	var entries := []
	for i in Net.PLAYER_COLORS.size():
		var e := {"id": i, "name": Net.PLAYER_COLOR_NAMES[i], "color": Net.PLAYER_COLORS[i]}
		if Net.color_taken(i):
			e["off"] = "another player has it"
		entries.append(e)
	_palette.open(_color_button, "Your colour", entries, Net.PLAYER_COLORS.find(_color), func(i): color_picked.emit(i))


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


## The characters from the Character Creator changed (one saved, replaced or deleted):
## a button for each saved one, and none for one that is gone (unless it is picked).
func refresh_custom() -> void:
	for id in _buttons.keys():
		if Characters.is_custom(id) and id != current and not id in Settings.custom_characters:
			_buttons[id].queue_free()
			_buttons.erase(id)
			_ids.erase(id)
	for id in Settings.custom_characters:
		_add_button(id)


## A long name (a custom character's can be 16 letters) shrinks its font to fit the
## button rather than being cut short.
func _fit_name(b: Button) -> void:
	var font := b.get_theme_font("font")
	var box := b.get_theme_stylebox("normal")
	var room := b.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
	var fs := NAME_SIZE
	while fs > NAME_MIN and font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	if b.get_theme_font_size("font_size") != fs:
		b.add_theme_font_size_override("font_size", fs)
