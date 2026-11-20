class_name CharacterCreator
extends HBoxContainer
## The Character Creator (main menu > Character Creator, or the lobby's robot
## window): build your own character from any head, torso and legs (the robots'
## and the creatures': a person, a goblin, a frog...), pick its colours (a main, a
## second and a detail colour, and a skin tone) and things to wear (a hat, glasses,
## something round its neck, on its shoulder, on its back, round its waist, a
## tail), each in a colour of its own, name it and save it. Saved characters are
## picked like any robot (in the menus, the lobby and the pause menu's Loadout) and
## everyone in an online match sees them.
##
## The page's buttons (Back, Save, Save and play) are the main menu's; this is
## the body: the character on a turning stage on the left, the parts on the right.
## Each part is a row: < its name >. The arrows step through the choices; a click
## on the name lists them all. A colour is a button showing it; a click opens the
## palette.
##
## Some parts, accessories and paints are unlocked by achievements (see
## Achievements). A locked one can be tried on (its name is drawn in orange and
## the line under the parts says what it needs) but not saved; a locked paint is
## greyed out in the palette.

signal changed

const STAGE := Vector2(360, 440)
const ROW_LABEL := 100.0
const BODY_PARTS := ["head", "torso", "legs"]
const WHOLE := "whole"       ## the row that changes head, torso and legs together
const PALETTE_COLUMNS := 6
const LOCKED := Color(1.0, 0.62, 0.3)   ## a locked choice's name

var current := CustomCharacter.new()   ## what is on the stage now
var status: Label                      ## a line under the parts ("Saved.")

var _preview: RobotPreview
var _stage: PortraitFrame
var _name: LineEdit
var _rows := {}         # part key -> Button (the part's name between the arrows)
var _colors := {}       # colour key (a body colour's "p", "p2", "p3", "s", or an accessory slot) -> its Button
var _saved: GridContainer
var _palette: SwatchPalette    # the colours to pick from, for the colour button that was clicked
var _palette_grid: GridContainer
var _list: PopupMenu    # every choice of the row whose name was clicked
var _list_key := ""
var _entrance := false  # the next character put on the stage is another one: it builds in


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
	_stage = PortraitFrame.new(STAGE, 0.95)
	col.add_child(_stage)
	_preview = _stage.preview
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var dice := UiKit.button(row, "Randomize", randomize_parts)
	dice.custom_minimum_size.x = 260
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
		_stage.title = current.name.to_upper()
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
	for pair in CustomCharacter.BODY_COLORS:
		_color_row(body, pair[0], pair[1])
	var extras := VBoxContainer.new()
	extras.add_theme_constant_override("separation", 6)
	extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	halves.add_child(extras)
	UiKit.section(extras, "Accessories")
	for slot in CustomCharacter.SLOTS:
		var row := _stepper(extras, slot, CustomCharacter.SLOT_NAMES[slot])
		var tint := _color_button(slot)
		tint.custom_minimum_size = Vector2(40, 38)
		tint.tooltip_text = "Colour"
		row.add_child(tint)
	_palette = SwatchPalette.new(PALETTE_COLUMNS)
	_palette_grid = _palette.grid
	add_child(_palette)
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
	status.autowrap_mode = TextServer.AUTOWRAP_OFF   # one line, cut short if need be: the page keeps its height
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_refresh_saved()


## A body colour's row: what it is, then a button showing the colour and its name.
func _color_row(parent: Node, key: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := UiKit.label(row, title, true, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(ROW_LABEL + 46, 0)   # (lined up with the names above, past the < arrow)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := _color_button(key)
	b.custom_minimum_size = Vector2(0, 32)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_constant_override("h_separation", 10)
	row.add_child(b)


## A button that shows a colour and opens the palette to change it.
func _color_button(key: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Chip"
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if key in _body_keys() else HORIZONTAL_ALIGNMENT_CENTER
	SwatchPalette.true_colors(b)
	b.name = "color_%s" % key
	b.set_meta("sfx", "select")
	b.pressed.connect(open_palette.bind(key))
	_colors[key] = b
	return b


static func _body_keys() -> Array:
	return CustomCharacter.BODY_COLORS.map(func(pair): return pair[0])


## The colours a colour button picks from: skin tones for the skin, paints for the rest.
static func palette_of(key: String) -> Array:
	return CustomCharacter.SKINS if key == "s" else CustomCharacter.PAINTS


## What a colour button is set to now ("" = as built).
func color_of(key: String) -> String:
	return current.body_color(key) if key in _body_keys() else current.color_of(key)


## Paint a body colour ("p", "p2", "p3", "s") or a slot's accessory with a colour of its palette.
func pick_color(key: String, id: String) -> void:
	if key in _body_keys():
		current.set_body_color(key, id)
	elif id == "":
		current.colors.erase(key)
	else:
		current.colors[key] = id
	_refresh()


## Open the palette under a colour button.
func open_palette(key: String) -> void:
	var title := "%s colour" % CustomCharacter.accessory_name(key, current.accessories.get(key, ""))
	for pair in CustomCharacter.BODY_COLORS:
		if pair[0] == key:
			title = pair[1]
	var entries := []
	for p in palette_of(key):
		var e := {"id": p.id, "name": p.name if p.id != "" else "As it comes", "color": p.color, "as_built": p.id == ""}
		if key != "s" and p.id != "" and Achievements.locked("paint:" + p.id):
			e["off"] = "locked. " + Achievements.requirement("paint:" + p.id)
		entries.append(e)
	_palette.open(_colors[key], title, entries, color_of(key), func(id): pick_color(key, id))


## A row: what it is, then < the part's name >. The name lists every choice when clicked.
func _stepper(parent: Node, key: String, title: String) -> HBoxContainer:
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
	shown.name = "%s_list" % key
	shown.set_meta("sfx", "select")
	shown.pressed.connect(open_list.bind(key))
	row.add_child(shown)
	_arrow(row, ">", key, 1)
	_rows[key] = shown
	return row


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
		_:
			current.accessories[key] = id
			if id == "":
				current.colors.erase(key)
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
		_list.add_radio_check_item(choice.name if not Achievements.locked(_item_key(key, choice.id)) else "%s  (locked)" % choice.name)
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
	current = CustomCharacter.random(null, func(key: String): return not Achievements.locked(key))   # only what you have
	current.name = keep
	_entrance = true
	_refresh()


## Put a saved (or any) character on the stage to edit.
func load_character(id: String) -> void:
	current = CustomCharacter.parse(Characters.valid(id))
	_name.text = current.name
	_entrance = true
	_refresh()


func _refresh() -> void:
	_rows[WHOLE].text = Characters.part_name(_chosen(WHOLE)).to_upper() if _chosen(WHOLE) != "" else "MIX"
	for key in BODY_PARTS:
		_rows[key].text = Characters.part_name(current.part(key)).to_upper()
	for slot in CustomCharacter.SLOTS:
		_rows[slot].text = CustomCharacter.accessory_name(slot, current.accessories.get(slot, "")).to_upper()
	var channel := 0
	for pair in CustomCharacter.BODY_COLORS:
		var key: String = pair[0]
		var b: Button = _colors[key]
		var has := RobotModel.shows(current, channel)   # is there anything of this colour on this body?
		channel += 1
		b.disabled = not has
		b.icon = SwatchPalette.swatch(_palette_color(key, current.body_color(key)), current.body_color(key) == "")
		b.text = (CustomCharacter.skin_name(current.skin) if key == "s" else CustomCharacter.paint_name(current.body_color(key))) if has \
			else ("No bare skin on these parts" if key == "s" else "Nothing of this colour on these parts")
	for slot in CustomCharacter.SLOTS:
		var b: Button = _colors[slot]
		b.disabled = current.accessories.get(slot, "") == ""
		b.icon = SwatchPalette.swatch(_palette_color(slot, current.color_of(slot)), current.color_of(slot) == "")
	for key in _rows:
		var item := _item_key(key, _chosen(key))
		var is_locked := (item != "" and Achievements.locked(item)) if key != WHOLE else BODY_PARTS.any(func(part): return Achievements.locked("part:" + current.part(part)))
		var shown: Button = _rows[key]
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			if is_locked:
				shown.add_theme_color_override(state, LOCKED)
			else:
				shown.remove_theme_color_override(state)
		shown.tooltip_text = "" if not is_locked or key == WHOLE else "Locked. %s" % Achievements.requirement(item)
	# In your colour, holding the weapon you take into matches.
	_stage.title = current.name.to_upper()
	_preview.show_robot(current.to_id(), Net.menu_color(), Game.local_weapon(), _entrance)
	_entrance = false
	if status:
		status.text = locked_note()
		status.add_theme_color_override("font_color", LOCKED if status.text != "" else UiKit.TEXT_DIM)
	_refresh_saved()
	changed.emit()


## The item (see Achievements) a row's choice is: "part:frog", "hat:crown"; "" for none.
static func _item_key(key: String, id: String) -> String:
	if id == "":
		return ""
	return "part:" + id if key == WHOLE or key in BODY_PARTS else "%s:%s" % [key, id]


## Whether the character on the stage can be saved: nothing on it is still locked.
func can_save() -> bool:
	return Achievements.locked_in(current).is_empty()


## What is locked on the character on the stage and what the first of them needs
## ("" when nothing is): "Locked: Crown. Warlord: Get 500 kills (37 / 500)".
func locked_note() -> String:
	var keys := Achievements.locked_in(current)
	if keys.is_empty():
		return ""
	var names := ", ".join(keys.slice(0, 2).map(Achievements.item_name)) + (" and %d more" % (keys.size() - 2) if keys.size() > 2 else "")
	return "Locked: %s.  %s" % [names, Achievements.requirement(keys[0])]


## The saved characters, as buttons that load them; the one with this name is lit.
func _refresh_saved() -> void:
	if _saved == null:
		return
	UiKit.clear(_saved)
	if Settings.custom_characters.is_empty():
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


## Keep it (under its name: saving again with the same name replaces it). Returns its
## id, or "" if it wears something still locked (the line under the parts says what).
func save() -> String:
	if not can_save():
		status.text = locked_note()
		return ""
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


static func _palette_color(key: String, id: String) -> Color:
	for p in palette_of(key):
		if p.id == id:
			return p.color
	return Color(0, 0, 0, 0)
