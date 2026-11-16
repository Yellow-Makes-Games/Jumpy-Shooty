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
var _weapon := "pistol"
var _buttons := {}                 # character id -> Button
var _blurb: Label
var _preview: RobotPreview


## tall: put the preview above the buttons (for a narrow column) instead of beside them.
func _init(start: String = "", player_color: Color = Net.PLAYER_COLORS[0], tall: bool = false, gun: String = "pistol") -> void:
	_color = player_color
	_weapon = WeaponData.valid(gun)
	add_theme_constant_override("separation", 6)
	UiKit.section(self, "Robot")
	var box: BoxContainer = VBoxContainer.new() if tall else HBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if tall else 14)
	add_child(box)
	_preview = RobotPreview.new(PREVIEW_TALL if tall else PREVIEW_SMALL)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_preview)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 8)
	box.add_child(side)
	# A grid, so the buttons stay compact however many robots there are.
	var buttons := GridContainer.new()
	buttons.columns = 3 if tall else 2
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	side.add_child(buttons)
	var group := ButtonGroup.new()
	for c in Characters.LIST:
		var b := Button.new()
		b.text = c.name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_pressed.bind(c.id))
		buttons.add_child(b)
		_buttons[c.id] = b
	_blurb = UiKit.label(side, "", true, 16)
	_blurb.custom_minimum_size = Vector2(0, 40)
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


## Put this gun in the preview robot's hands.
func set_weapon(id: String) -> void:
	if WeaponData.valid(id) != _weapon:
		_weapon = WeaponData.valid(id)
		_show_robot()


func _show_robot() -> void:
	_preview.show_robot(current, _color, _weapon)
