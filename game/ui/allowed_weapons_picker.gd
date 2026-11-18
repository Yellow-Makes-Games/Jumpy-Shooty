class_name AllowedWeaponsPicker
extends VBoxContainer
## The host's "Weapons allowed" setting (lobby and Vs Bots pages; see LobbySettings).
## A line saying what is allowed and, for the host, a Change button that opens a chip
## for every weapon in rows by class. "Any mix": tick any set of weapons (at least one
## stays ticked). "One gun": the chip you press is the only weapon, for everyone.
## "Allow all" goes back to every weapon. Everyone else just sees the line.
##
## It only reports the choice (changed, with the stored form: [] for every weapon);
## the screen sends it to the lobby.

signal changed(ids: Array)

const TAG_WIDTH := 78.0

## The weapon "One gun" starts on (the screen sets it to your own pick).
var preferred := ""

var _ids: Array = []          # as stored: [] = every weapon
var _single := false          # "One gun" mode
var _summary: Label
var _edit: Button
var _body: VBoxContainer
var _kind: Container          # Any mix / One gun
var _all: Button
var _chips := {}              # weapon id -> Button


func _init(ids: Array = [], editable: bool = true) -> void:
	add_theme_constant_override("separation", 8)
	UiKit.section(self, "Weapons allowed")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	add_child(head)
	_summary = UiKit.label(head, "", true, 16)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_edit = UiKit.button(head, "Change", func(): _open(not _body.visible))
	_edit.theme_type_variation = "Chip"
	_edit.custom_minimum_size = Vector2(110, 38)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.visible = false
	add_child(_body)
	_kind = UiKit.segmented(_body, ["Any mix", "One gun"], 0, func(i: int): _set_single(i == 1))
	for g in WeaponData.GROUPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_body.add_child(row)
		var tag := Label.new()
		tag.text = String(g[0]).to_upper()
		tag.add_theme_font_override("font", HudStyle.font_spaced(1))
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color(UiKit.CYAN, 0.8))
		tag.custom_minimum_size = Vector2(TAG_WIDTH, 32)   # level with the first row of chips
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(tag)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 5)
		flow.add_theme_constant_override("v_separation", 5)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(flow)
		for id in g[1]:
			var b := Button.new()
			b.toggle_mode = true
			b.theme_type_variation = "Chip"
			b.text = WeaponData.by_id(id).short_name
			b.tooltip_text = WeaponData.name_of(id)
			b.custom_minimum_size = Vector2(0, 32)
			b.add_theme_font_size_override("font_size", 13)
			b.pressed.connect(_on_chip.bind(id))
			flow.add_child(b)
			_chips[id] = b
	_all = UiKit.button(_body, "Allow all", func(): _set_ids([]))
	_all.theme_type_variation = "Chip"
	_all.custom_minimum_size = Vector2(0, 38)
	set_editable(editable)
	set_value(ids)


## Show what is allowed (as stored: [] for every weapon) without reporting it.
func set_value(ids: Array) -> void:
	var clean := LobbySettings.normalized_weapons(ids)
	if clean != _ids:
		_ids = clean
		_single = _ids.size() == 1
	_sync()


## The host can change it; everyone else only sees the line.
func set_editable(on: bool) -> void:
	_edit.visible = on
	if not on:
		_body.visible = false


func value() -> Array:
	return _ids.duplicate()


func _open(on: bool) -> void:
	_body.visible = on
	_edit.text = "Done" if on else "Change"


func _set_single(on: bool) -> void:
	_single = on
	var allowed := LobbySettings.weapons_from(_ids)
	if on and allowed.size() > 1:
		_set_ids([preferred if preferred in allowed else allowed[0]])
	else:
		_sync()


func _on_chip(id: String) -> void:
	if _single:
		_set_ids([id])
		return
	var allowed := LobbySettings.weapons_from(_ids)
	if id in allowed:
		if allowed.size() == 1:
			_sync()   # one weapon has to stay
			return
		allowed.erase(id)
	else:
		allowed.append(id)
	_set_ids(allowed)


func _set_ids(ids: Array) -> void:
	var clean := LobbySettings.normalized_weapons(ids)
	if clean.size() != 1:
		_single = false
	var was := _ids
	_ids = clean
	_sync()
	if clean != was:
		changed.emit(clean.duplicate())


## The line, the mode switch and the chips match the value.
func _sync() -> void:
	_summary.text = LobbySettings.weapons_summary(_ids)
	var allowed := LobbySettings.weapons_from(_ids)
	for id in _chips:
		_chips[id].set_pressed_no_signal(id in allowed)
	for i in _kind.get_child_count():
		(_kind.get_child(i) as Button).set_pressed_no_signal(i == (1 if _single else 0))
	_all.disabled = _ids.is_empty()
