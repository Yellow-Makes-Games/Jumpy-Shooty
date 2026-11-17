class_name WeaponPicker
extends VBoxContainer
## "Weapon" chooser for the menus: a card for every weapon (its silhouette and its
## name in full), in rows by class (sidearms, shotguns, rifles, marksman rifles,
## explosives, melee). Under them, a panel about one weapon: its full name, its class,
## a line about it and four bars (damage, fire rate, range, magazine; for melee:
## damage, swing speed, reach, knockback). The panel shows the weapon under the
## mouse while you look around, with a white mark on each bar where the weapon you
## have picked sits, and goes back to your pick when the mouse leaves.
##
## Like CharacterPicker it only reports the choice; the screen decides what to do
## with it (save it, tell the lobby, show it in the robot preview's hands).

signal picked(id: String)

const PER_ROW := 4
const CARD_HEIGHT := 48.0
const TAG_WIDTH := 84.0

var current := ""

var _cards := {}                   # weapon id -> Card
var _shown := ""                   # the weapon the panel is about (under the mouse, or the pick)
var _name: Label
var _class: Label
var _blurb: Label
var _bars: Control


## One weapon: a toggle button that draws the weapon's silhouette over its name.
class Card extends Button:
	var id := ""

	func _init(weapon_id: String) -> void:
		id = weapon_id
		toggle_mode = true
		theme_type_variation = "Chip"
		custom_minimum_size = Vector2(0, WeaponPicker.CARD_HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tooltip_text = WeaponData.by_id(id).display_name
		set_meta("sfx", "none")   # picking a gun plays the gun being readied instead

	func _draw() -> void:
		var col := UiKit.ACCENT_DARK if button_pressed else (Color.WHITE if is_hovered() else Color(1, 1, 1, 0.82))
		var s := 1.5
		var iw := HudStyle.weapon_width(id) * s
		HudStyle.weapon_icon(self, id, Vector2((size.x - iw) * 0.5, 8.0), col, s)
		var f := HudStyle.font(true)
		var text := WeaponData.by_id(id).short_name.to_upper()
		var fs := 12
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw > size.x - 8.0:   # a narrow card: shrink the name rather than cut it
			fs = 10
			tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - tw) * 0.5, size.y - 7.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _init(start: String = "") -> void:
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(520, 0)
	UiKit.section(self, "Weapon")
	var group := ButtonGroup.new()
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 5)
	add_child(grid)
	for g in WeaponData.GROUPS:
		var ids: Array = g[1]
		for from in range(0, ids.size(), PER_ROW):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			grid.add_child(row)
			var tag := Label.new()
			tag.text = String(g[0]).to_upper() if from == 0 else ""
			tag.add_theme_font_override("font", HudStyle.font_spaced(1))
			tag.add_theme_font_size_override("font_size", 11)
			tag.add_theme_color_override("font_color", Color(UiKit.CYAN, 0.8))
			tag.custom_minimum_size = Vector2(TAG_WIDTH, 0)
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tag)
			for i in range(from, mini(from + PER_ROW, ids.size())):
				_add_card(row, ids[i], group)
			for i in PER_ROW - mini(PER_ROW, ids.size() - from):   # keep the columns lined up
				var pad := Control.new()
				pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				pad.custom_minimum_size = Vector2(0, CARD_HEIGHT)
				row.add_child(pad)
	_build_panel()
	select(WeaponData.valid(start))


func _add_card(row: HBoxContainer, id: String, group: ButtonGroup) -> void:
	var b := Card.new(id)
	b.button_group = group
	b.pressed.connect(_on_pressed.bind(id))
	b.mouse_entered.connect(_show.bind(id))
	b.mouse_exited.connect(func(): _show(current))
	row.add_child(b)
	_cards[id] = b


## The panel about one weapon.
func _build_panel() -> void:
	var col := UiKit.inset(self, 4)
	(col.get_parent() as PanelContainer).add_theme_stylebox_override("panel", UiKit.inset_box(12))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	_name = Label.new()
	_name.add_theme_font_override("font", HudStyle.font(true))
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color.WHITE)
	head.add_child(_name)
	_class = Label.new()
	_class.add_theme_font_override("font", HudStyle.font_spaced(2))
	_class.add_theme_font_size_override("font_size", 11)
	_class.add_theme_color_override("font_color", UiKit.CYAN)
	_class.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_class.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_class)
	_blurb = UiKit.label(col, "", true, 15)
	_blurb.custom_minimum_size = Vector2(0, 40)
	_bars = Control.new()
	_bars.custom_minimum_size = Vector2(0, 40)
	_bars.draw.connect(_draw_bars)
	col.add_child(_bars)


## Show `id` as the picked gun without reporting it.
func select(id: String) -> void:
	id = WeaponData.valid(id)
	if id == current:
		return
	current = id
	for key in _cards:
		_cards[key].set_pressed_no_signal(key == id)
		_cards[key].queue_redraw()
	_show(id)


## Put this weapon in the panel under the cards.
func _show(id: String) -> void:
	_shown = WeaponData.valid(id)
	var w := WeaponData.by_id(_shown)
	_name.text = w.display_name.to_upper()
	var kind := String(WeaponData.GROUPS[WeaponData.group_of(_shown)][0]).to_upper()
	_class.text = kind if _shown == current else kind + "  ·  PREVIEW"
	_class.add_theme_color_override("font_color", UiKit.CYAN if _shown == current else UiKit.ACCENT)
	_blurb.text = w.blurb
	_bars.queue_redraw()


func _on_pressed(id: String) -> void:
	if id == current:
		_cards[id].set_pressed_no_signal(true)
		Sound.play("ui_click")
		return
	Sound.play("equip_" + id)
	select(id)
	picked.emit(id)


## 0..1 ratings, against the best gun at each.
static func ratings(w: WeaponData) -> Array:
	if w.is_melee():
		return [
			["DAMAGE", clampf(w.damage / 110.0, 0.05, 1.0)],
			["SWING", clampf(0.3 / w.fire_interval, 0.05, 1.0)],
			["REACH", clampf(w.max_range / 3.2, 0.05, 1.0)],
			["KNOCKBACK", clampf(w.knockback / 24.0, 0.05, 1.0)],
		]
	if w.is_projectile():
		return [
			["DAMAGE", clampf(w.damage / 110.0, 0.05, 1.0)],
			["FIRE RATE", clampf(1.0 / w.fire_interval / 10.0, 0.05, 1.0)],
			["BLAST", clampf(w.splash_radius / 5.0, 0.05, 1.0)],
			["MAGAZINE", clampf(w.magazine / 30.0, 0.05, 1.0)],
		]
	var shot := w.damage * w.pellets * w.burst
	var per_second := 1.0 / w.fire_interval
	var reach := w.falloff_end if w.falloff_end < 500.0 else 120.0
	return [
		["DAMAGE", clampf(shot / 110.0, 0.05, 1.0)],
		["FIRE RATE", clampf(per_second / 10.0, 0.05, 1.0)],
		["RANGE", clampf(reach / 120.0, 0.05, 1.0) if w.falloff_end < 500.0 or w.id in ["pistol"] else (1.0 if w.max_range >= 250.0 else 0.8)],
		["MAGAZINE", clampf(w.magazine / 30.0, 0.05, 1.0)],
	]


## Four bars, two to a row, each in ten blocks. While another weapon is being looked
## at, a white mark shows where the picked one sits on the same scale (when the two
## bars measure the same thing).
func _draw_bars() -> void:
	var r := ratings(WeaponData.by_id(_shown))
	var mine := ratings(WeaponData.by_id(current)) if _shown != current else []
	var col_w := _bars.size.x / 2.0
	for i in r.size():
		var x := (i % 2) * col_w
		var y := (i / 2) * 21.0 + 9.0
		_bars.draw_string(HudStyle.font_spaced(1), Vector2(x, y + 4.0), r[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.65))
		var bx := x + 96.0
		var bw := col_w - 96.0 - (14.0 if i % 2 == 0 else 0.0)
		var blocks := 10
		var block_w := (bw - (blocks - 1) * 2.0) / blocks
		var value: float = r[i][1]
		for k in blocks:
			var rect := Rect2(bx + k * (block_w + 2.0), y - 4.0, block_w, 8.0)
			_bars.draw_rect(rect, Color(1, 1, 1, 0.1))
			var part := clampf(value * blocks - k, 0.0, 1.0)
			if part > 0.0:
				_bars.draw_rect(Rect2(rect.position, Vector2(block_w * part, rect.size.y)), UiKit.ACCENT)
		if not mine.is_empty() and mine[i][0] == r[i][0]:
			var mx := bx + bw * float(mine[i][1])
			_bars.draw_line(Vector2(mx, y - 7.0), Vector2(mx, y + 7.0), Color.WHITE, 2.0)
