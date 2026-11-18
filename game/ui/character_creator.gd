class_name CharacterCreator
extends HBoxContainer
## The Character Creator (main menu > Character Creator): build your own robot
## from any robot's head, torso and legs, give it a coat of paint and a hat,
## glasses, something round its neck and something on its back, name it and save
## it. Saved characters are picked like any robot (in the menus, the lobby and the
## pause menu's Loadout) and everyone in an online match sees them.
##
## The page's buttons (Back, Save, Save and play) are the main menu's; this is
## the body: the robot on a turning stage on the left, the parts on the right.

signal changed

const STAGE := Vector2(360, 440)
const ROW_LABEL := 112.0

var current := CustomCharacter.new()   ## what is on the stage now
var status: Label                      ## a line under the parts ("Saved.")

var _preview: RobotPreview
var _stage: Control
var _name: LineEdit
var _rows := {}         # part key -> Label (the part's name between the arrows)
var _paints: Array = [] # paint buttons, in CustomCharacter.PAINTS order
var _saved: GridContainer
var _paint_name: Label
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
	_name = UiKit.line_edit(col, "Name your robot", current.name)
	_name.max_length = CustomCharacter.MAX_NAME
	_name.text_changed.connect(func(t: String):
		current.name = CustomCharacter.clean_name(t)
		_refresh_saved())
	# The body parts and the accessories side by side, to keep the page short.
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 22)
	col.add_child(halves)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	halves.add_child(body)
	UiKit.section(body, "Body")
	_stepper(body, "head", "Head")
	_stepper(body, "torso", "Torso")
	_stepper(body, "legs", "Legs")
	var extras := VBoxContainer.new()
	extras.add_theme_constant_override("separation", 6)
	extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	halves.add_child(extras)
	UiKit.section(extras, "Accessories")
	for slot in CustomCharacter.SLOTS:
		_stepper(extras, slot, CustomCharacter.SLOT_NAMES[slot])
	UiKit.section(col, "Paint")
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 6)
	col.add_child(swatches)
	var group := ButtonGroup.new()
	for p in CustomCharacter.PAINTS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "Chip"
		b.tooltip_text = p.name
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = _swatch(p.color)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.set_meta("sfx", "select")
		b.pressed.connect(func():
			current.paint = p.id
			_refresh())
		swatches.add_child(b)
		_paints.append(b)
	_paint_name = UiKit.label(col, "", true, 14)
	UiKit.section(col, "Your characters")
	_saved = GridContainer.new()
	_saved.columns = 5
	_saved.add_theme_constant_override("h_separation", 6)
	_saved.add_theme_constant_override("v_separation", 6)
	col.add_child(_saved)
	status = UiKit.label(col, "", true, 15)
	status.custom_minimum_size = Vector2(0, 22)
	_refresh_saved()


## A row: what it is, then < the part's name >.
func _stepper(parent: Node, key: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := UiKit.label(row, title, true, 16)
	l.custom_minimum_size = Vector2(ROW_LABEL, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var prev := _arrow(row, "<", key, -1)
	var shown := Label.new()
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shown.add_theme_font_override("font", HudStyle.font(true))
	shown.add_theme_font_size_override("font_size", 15)
	shown.clip_text = true
	row.add_child(shown)
	row.move_child(shown, prev.get_index() + 1)
	_arrow(row, ">", key, 1)
	_rows[key] = shown


func _arrow(row: Node, text: String, key: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "Chip"
	b.custom_minimum_size = Vector2(44, 38)
	b.set_meta("sfx", "select")
	b.name = "%s_%s" % [key, "next" if step > 0 else "prev"]
	b.pressed.connect(step_part.bind(key, step))
	row.add_child(b)
	return b


## Step a part ("head", "torso", "legs", or an accessory slot) to the next or the
## previous choice.
func step_part(key: String, step: int) -> void:
	if key in ["head", "torso", "legs"]:
		var ids := Characters.ids()
		var next: String = ids[posmod(ids.find(current.part(key)) + step, ids.size())]
		match key:
			"head": current.head = next
			"torso": current.torso = next
			"legs": current.legs = next
	else:
		var list: Array = CustomCharacter.ACCESSORIES[key]
		var at := 0
		for i in list.size():
			if list[i].id == current.accessories[key]:
				at = i
		current.accessories[key] = list[posmod(at + step, list.size())].id
	_refresh()


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
	for key in ["head", "torso", "legs"]:
		_rows[key].text = Characters.name_of(current.part(key)).to_upper()
	for slot in CustomCharacter.SLOTS:
		_rows[slot].text = CustomCharacter.accessory_name(slot, current.accessories[slot]).to_upper()
	for i in _paints.size():
		_paints[i].set_pressed_no_signal(CustomCharacter.PAINTS[i].id == current.paint)
	_paint_name.text = "Paint: %s" % CustomCharacter.paint_name(current.paint)
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


## A small square of colour, for a paint button.
static func _swatch(color: Color) -> Texture2D:
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	img.fill(color)
	for i in 22:
		for e in [0, 21]:
			img.set_pixel(i, e, Color(1, 1, 1, 0.5))
			img.set_pixel(e, i, Color(1, 1, 1, 0.5))
	return ImageTexture.create_from_image(img)
