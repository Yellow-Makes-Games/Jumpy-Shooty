class_name CharacterCreator
extends HBoxContainer
## The Character Creator (main menu > Character Creator): build your own
## character from any head, torso and legs (the robots' and the creatures': a
## person, a goblin, a frog...), give it a coat of paint, a skin tone and things
## to wear (a hat, glasses, something round its neck, on its shoulder, on its
## back, round its waist, a tail), name it and save it. Saved characters are
## picked like any robot (in the menus, the lobby and the pause menu's Loadout)
## and everyone in an online match sees them.
##
## The page's buttons (Back, Save, Save and play) are the main menu's; this is
## the body: the character on a turning stage on the left, the parts on the right.
## Each part is a row: < its name >. The arrows step through the choices; a click
## on the name lists them all.

signal changed

const STAGE := Vector2(360, 440)
const ROW_LABEL := 100.0
const BODY_PARTS := ["head", "torso", "legs"]
const WHOLE := "whole"       ## the row that changes head, torso and legs together
const SWATCH_COLUMNS := 9

var current := CustomCharacter.new()   ## what is on the stage now
var status: Label                      ## a line under the parts ("Saved.")

var _preview: RobotPreview
var _stage: Control
var _name: LineEdit
var _rows := {}         # part key -> Button (the part's name between the arrows)
var _paints: Array = [] # paint buttons, in CustomCharacter.PAINTS order
var _skins: Array = []  # skin tone buttons, in CustomCharacter.SKINS order
var _saved: GridContainer
var _paint_name: Label
var _skin_name: Label
var _list: PopupMenu    # every choice of the row whose name was clicked
var _list_key := ""
var _turn := 0.0        # extra turn of the stage: 0 front, PI back
var _time := 0.0


func _init(start: String = "") -> void:
	add_theme_constant_override("separation", 26)
	if Characters.is_custom(start):
		current = CustomCharacter.parse(start)
	elif start != "":
		current.head = Characters.valid(start)
		current.torso = current.head
		current.legs = current.head
	_build_stage()
	var line := ColorRect.new()
	line.color = Color(UiKit.LINE, 0.12)
	line.custom_minimum_size = Vector2(1, 0)
	add_child(line)
	_build_parts()
	_refresh()


func _build_stage() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	UiKit.section(col, "Preview")
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE
	_stage.clip_contents = true
	_stage.draw.connect(_draw_stage)
	col.add_child(_stage)
	_preview = RobotPreview.new(STAGE, 0.95)
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_preview)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var spin := UiKit.button(row, "Turn around", func():
		_turn = PI - _turn
		_preview.facing = _turn)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.set_meta("sfx", "select")
	var dice := UiKit.button(row, "Randomize", randomize_parts)
	dice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice.set_meta("sfx", "select")


func _build_parts() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(560, 0)
	add_child(col)
	UiKit.section(col, "Name")
	_name = UiKit.line_edit(col, "Name your character", current.name)
	_name.max_length = CustomCharacter.MAX_NAME
	_name.text_changed.connect(func(t: String):
		current.name = CustomCharacter.clean_name(t)
		_refresh_saved())
	# The body and the things it wears side by side, to keep the page short.
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 22)
	col.add_child(halves)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	halves.add_child(body)
	UiKit.section(body, "Body")
	_stepper(body, WHOLE, "Whole body")
	_stepper(body, "head", "Head")
	_stepper(body, "torso", "Torso")
	_stepper(body, "legs", "Legs")
	_paint_name = UiKit.label(body, "", true, 13)
	_paints = _swatches(body, "paint", CustomCharacter.PAINTS, func(id: String): current.paint = id)
	_skin_name = UiKit.label(body, "", true, 13)
	_skins = _swatches(body, "skin", CustomCharacter.SKINS, func(id: String): current.skin = id)
	var extras := VBoxContainer.new()
	extras.add_theme_constant_override("separation", 6)
	extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	halves.add_child(extras)
	UiKit.section(extras, "Accessories")
	for slot in CustomCharacter.SLOTS:
		_stepper(extras, slot, CustomCharacter.SLOT_NAMES[slot])
	_list = PopupMenu.new()
	_list.add_theme_font_size_override("font_size", 15)
	_list.index_pressed.connect(func(i: int): set_part(_list_key, _choices(_list_key)[i].id))
	add_child(_list)
	UiKit.section(col, "Your characters")
	_saved = GridContainer.new()
	_saved.columns = 6
	_saved.add_theme_constant_override("h_separation", 6)
	_saved.add_theme_constant_override("v_separation", 6)
	col.add_child(_saved)
	status = UiKit.label(col, "", true, 15)
	status.custom_minimum_size = Vector2(0, 22)
	_refresh_saved()


## A grid of colours to pick one from (`list`: PAINTS or SKINS). Returns its buttons.
func _swatches(parent: Node, key: String, list: Array, pick: Callable) -> Array:
	var grid := GridContainer.new()
	grid.columns = SWATCH_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	var group := ButtonGroup.new()
	var buttons := []
	for p in list:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "Chip"
		b.tooltip_text = p.name
		b.custom_minimum_size = Vector2(0, 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = _swatch(p.color, p.id == "")
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for state in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(state, Color.WHITE)   # the colour as it is, lit or not
		b.name = "%s_%s" % [key, p.id if p.id != "" else "none"]
		b.set_meta("sfx", "select")
		b.pressed.connect(func():
			pick.call(p.id)
			_refresh())
		grid.add_child(b)
		buttons.append(b)
	return buttons


## A row: what it is, then < the part's name >. The name lists every choice when clicked.
func _stepper(parent: Node, key: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := UiKit.label(row, title, true, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(ROW_LABEL, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arrow(row, "<", key, -1)
	var shown := Button.new()
	shown.flat = true
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shown.custom_minimum_size = Vector2(0, 38)
	shown.add_theme_font_override("font", HudStyle.font(true))
	shown.add_theme_font_size_override("font_size", 15)
	shown.clip_text = true
	shown.tooltip_text = "Click to see every choice"
	shown.name = "%s_list" % key
	shown.set_meta("sfx", "select")
	shown.pressed.connect(open_list.bind(key))
	row.add_child(shown)
	_arrow(row, ">", key, 1)
	_rows[key] = shown


func _arrow(row: Node, text: String, key: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "Chip"
	b.custom_minimum_size = Vector2(40, 38)
	b.set_meta("sfx", "select")
	b.name = "%s_%s" % [key, "next" if step > 0 else "prev"]
	b.pressed.connect(step_part.bind(key, step))
	row.add_child(b)
	return b


## Every choice of a row, in order: [{id, name}]. The body rows offer every robot
## and every creature; an accessory row its slot's pieces (the first is "None").
func _choices(key: String) -> Array:
	if key == WHOLE or key in BODY_PARTS:
		var out := []
		for id in Characters.part_ids():
			out.append({"id": id, "name": Characters.part_name(id)})
		return out
	return CustomCharacter.ACCESSORIES[key]


## What a row is set to now ("" on the whole-body row when the parts are mixed).
func _chosen(key: String) -> String:
	if key == WHOLE:
		return current.head if current.head == current.torso and current.torso == current.legs else ""
	if key in BODY_PARTS:
		return current.part(key)
	return current.accessories.get(key, "")


## Set a row ("whole", "head", "torso", "legs", or an accessory slot) to a choice.
func set_part(key: String, id: String) -> void:
	match key:
		WHOLE:
			current.head = id
			current.torso = id
			current.legs = id
		"head": current.head = id
		"torso": current.torso = id
		"legs": current.legs = id
		_: current.accessories[key] = id
	_refresh()


## Step a row to the next or the previous choice. A mixed body steps from its torso.
func step_part(key: String, step: int) -> void:
	var list := _choices(key)
	var now := _chosen(key) if not (key == WHOLE and _chosen(key) == "") else current.torso
	var at := 0
	for i in list.size():
		if list[i].id == now:
			at = i
	set_part(key, list[posmod(at + step, list.size())].id)


## List every choice of a row under its name, to pick one straight away.
func open_list(key: String) -> void:
	_list_key = key
	_list.clear()
	var now := _chosen(key)
	for choice in _choices(key):
		_list.add_radio_check_item(choice.name)
		_list.set_item_checked(_list.item_count - 1, choice.id == now)
	# Under the name, as wide as it; no taller than most of the window (it scrolls).
	var from: Button = _rows[key]
	var scale := from.get_screen_transform().get_scale()
	var window := get_window()
	_list.max_size = Vector2i(16384, int(window.size.y * 0.62) if window else 520)
	_list.position = Vector2i(from.get_screen_position() + Vector2(0, from.size.y * scale.y))
	_list.size = Vector2i(int(from.size.x * scale.x), 0)
	_list.popup()


func randomize_parts() -> void:
	var keep := current.name
	current = CustomCharacter.random()
	current.name = keep
	_refresh()


## Put a saved (or any) character on the stage to edit.
func load_character(id: String) -> void:
	current = CustomCharacter.parse(Characters.valid(id))
	_name.text = current.name
	_refresh()


func _refresh() -> void:
	_rows[WHOLE].text = Characters.part_name(_chosen(WHOLE)).to_upper() if _chosen(WHOLE) != "" else "MIX"
	for key in BODY_PARTS:
		_rows[key].text = Characters.part_name(current.part(key)).to_upper()
	for slot in CustomCharacter.SLOTS:
		_rows[slot].text = CustomCharacter.accessory_name(slot, current.accessories.get(slot, "")).to_upper()
	for i in _paints.size():
		_paints[i].set_pressed_no_signal(CustomCharacter.PAINTS[i].id == current.paint)
	for i in _skins.size():
		_skins[i].set_pressed_no_signal(CustomCharacter.SKINS[i].id == current.skin)
	_paint_name.text = "PAINT  ·  %s" % CustomCharacter.paint_name(current.paint)
	_skin_name.text = "SKIN  ·  %s" % (CustomCharacter.skin_name(current.skin) if RobotModel.shows_skin(current) else "no bare skin on these parts")
	_preview.show_robot(current.to_id(), Net.PLAYER_COLORS[0], "none")
	if status:
		status.text = ""
	_refresh_saved()
	changed.emit()


## The saved characters, as buttons that load them; the one with this name is lit.
func _refresh_saved() -> void:
	if _saved == null:
		return
	UiKit.clear(_saved)
	if Settings.custom_characters.is_empty():
		var none := UiKit.label(_saved, "None yet: Save keeps this one.", true, 14)
		none.autowrap_mode = TextServer.AUTOWRAP_OFF
		return
	for id in Settings.custom_characters:
		var c := CustomCharacter.parse(id)
		var b := Button.new()
		b.text = c.name
		b.theme_type_variation = "Chip"
		b.toggle_mode = true
		b.button_pressed = c.name == current.name
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.tooltip_text = c.blurb()
		b.set_meta("sfx", "select")
		b.pressed.connect(load_character.bind(id))
		_saved.add_child(b)


## Keep it (under its name: saving again with the same name replaces it). Returns its id.
func save() -> String:
	current.name = CustomCharacter.clean_name(_name.text)
	_name.text = current.name
	var replacing := Settings.custom_index(current.name) >= 0
	var id := Settings.save_custom(current)
	_refresh_saved()
	status.text = ("Updated %s." if replacing else "Saved %s. Pick it from Robot before a match.") % current.name
	return id


## Throw away the saved character with this one's name, if there is one.
func delete_saved() -> void:
	var at := Settings.custom_index(current.name)
	if at < 0:
		status.text = "%s isn't saved." % current.name
		return
	Settings.delete_custom(Settings.custom_characters[at])
	_refresh_saved()
	status.text = "Deleted %s." % current.name


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		_stage.queue_redraw()


func _draw_stage() -> void:
	var s := _stage.size
	var r := Rect2(Vector2.ZERO, s)
	HudStyle.framed_plate(_stage, r.grow(-1.0), 18.0, Color(0.02, 0.03, 0.05, 0.75), Color(UiKit.LINE, 0.22))
	var glow := Net.PLAYER_COLORS[0].lerp(Color.WHITE, 0.15)
	var floor_c := Vector2(s.x * 0.5, s.y * 0.88)
	_stage.draw_polygon(PackedVector2Array([Vector2(s.x * 0.5 - 30, 0), Vector2(s.x * 0.5 + 30, 0),
			floor_c + Vector2(130, 0), floor_c - Vector2(130, 0)]),
		PackedColorArray([Color(glow, 0.0), Color(glow, 0.0), Color(glow, 0.12), Color(glow, 0.12)]))
	_stage.draw_set_transform(floor_c, 0.0, Vector2(1.0, 0.26))
	_stage.draw_circle(Vector2.ZERO, 120.0, Color(glow, 0.10))
	_stage.draw_arc(Vector2.ZERO, 120.0, 0.0, TAU, 64, Color(glow, 0.75), 2.0, true)
	for i in 6:
		var a := _time * 0.5 + i * TAU / 6.0
		_stage.draw_arc(Vector2.ZERO, 140.0, a, a + 0.5, 12, Color(UiKit.CYAN, 0.55), 3.0, true)
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	HudStyle.label(_stage, Vector2(16, 20), "CUSTOM UNIT", 11, Color(UiKit.CYAN, 0.9))
	HudStyle.text(_stage, Vector2(16, 44), current.name.to_upper(), 28, Color.WHITE)
	HudStyle.brackets(_stage, r.grow(-8.0), 12.0, Color(1, 1, 1, 0.25), 1.5)


## A small square of colour, for a paint or skin button. as_built: the "leave it
## as it is" choice, an empty square with a stroke through it.
static func _swatch(color: Color, as_built: bool = false) -> Texture2D:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0) if as_built else color)
	for i in 18:
		for e in [0, 17]:
			img.set_pixel(i, e, Color(1, 1, 1, 0.5))
			img.set_pixel(e, i, Color(1, 1, 1, 0.5))
		if as_built:
			img.set_pixel(i, 17 - i, Color(1, 1, 1, 0.5))
	return ImageTexture.create_from_image(img)
