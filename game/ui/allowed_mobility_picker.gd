class_name AllowedMobilityPicker
extends VBoxContainer
## The host's "Mobility allowed" setting (lobby and Vs Bots pages; see LobbySettings):
## a line saying what is allowed and, for the host, a Change button that opens a chip
## for each mobility tool to tick on or off (one always stays ticked; one ticked is the
## same tool for everyone). Laid out like AllowedWeaponsPicker. Everyone else just sees
## the line.
##
## It only reports the choice (changed, with the stored form: [] for every tool); the
## screen sends it to the lobby.

signal changed(ids: Array)

var _ids: Array = []          # as stored: [] = every tool
var _summary: Label
var _edit: Button
var _row: HBoxContainer
var _chips := {}              # mobility id -> Button
var _window: FloatingPanel    # the chips' floating window (see use_window), or null: they open under the line
var _prefix := ""             # "Mobility: " under a shared heading


## heading: false when it sits under a shared "Loadout rules" heading.
func _init(ids: Array = [], editable: bool = true, heading: bool = true) -> void:
	add_theme_constant_override("separation", 8)
	if heading:
		UiKit.section(self, "Mobility allowed")
	else:
		_prefix = "Mobility: "
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	add_child(head)
	_summary = UiKit.label(head, "", true, 16)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_edit = UiKit.button(head, "Change", func(): _open(not (_window.is_open() if _window else _row.visible)))
	_edit.theme_type_variation = "Chip"
	_edit.custom_minimum_size = Vector2(110, 38)
	_row = HBoxContainer.new()
	_row.visible = false
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)
	for id in Mobility.IDS:
		var b := Button.new()
		b.toggle_mode = true
		b.theme_type_variation = "Chip"
		b.text = Mobility.short_name(id)
		b.tooltip_text = Mobility.blurb(id)
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_chip.bind(id))
		_row.add_child(b)
		_chips[id] = b
	set_editable(editable)
	set_value(ids)


## Show what is allowed (as stored: [] for every tool) without reporting it.
func set_value(ids: Array) -> void:
	_ids = LobbySettings.normalized_mobility(ids)
	_sync()


## The host can change it; everyone else only sees the line.
func set_editable(on: bool) -> void:
	_edit.visible = on
	if not on:
		_open(false)


func _open(on: bool) -> void:
	if _window:
		if on:
			_window.open(_edit)
		else:
			_window.close()
		return
	_row.visible = on
	_edit.text = "Done" if on else "Change"

## Show the chips in a floating window (opened by Change) instead of under the line
## (the lobby; see FloatingPanel). `title` heads the window. Call it before the
## picker is in the tree, so its chips enter the tree only once (in the window).
func use_window(window: FloatingPanel, title: String) -> void:
	_window = window
	_row.get_parent().remove_child(_row)
	UiKit.section(window.content, title)
	window.content.add_child(_row)
	_row.visible = true
	_edit.text = "Change"


## The floating window, if the chips are in one (see use_window).
func window() -> FloatingPanel:
	return _window



func value() -> Array:
	return _ids.duplicate()


func _on_chip(id: String) -> void:
	var allowed := LobbySettings.mobility_from(_ids)
	if id in allowed:
		if allowed.size() == 1:
			_sync()   # one tool has to stay
			return
		allowed.erase(id)
	else:
		allowed.append(id)
	var clean := LobbySettings.normalized_mobility(allowed)
	var was := _ids
	_ids = clean
	_sync()
	if clean != was:
		changed.emit(clean.duplicate())


func _sync() -> void:
	_summary.text = _prefix + LobbySettings.mobility_summary(_ids)
	var allowed := LobbySettings.mobility_from(_ids)
	for id in _chips:
		_chips[id].set_pressed_no_signal(id in allowed)
