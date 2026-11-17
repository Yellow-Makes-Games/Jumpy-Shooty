class_name WeaponPicker
extends VBoxContainer
## "Weapon" chooser for the menus: one button per weapon (guns on one row, melee
## weapons on the next), a line about it and four bars (damage, fire rate, range,
## magazine; for melee: damage, swing speed, reach, knockback) to compare them at a glance.
##
## Like CharacterPicker it only reports the choice; the screen decides what to do
## with it (save it, tell the lobby, show it in the robot preview's hands).

signal picked(id: String)

const BAR_W := 120.0

var current := ""

var _buttons := {}                 # weapon id -> Button
var _blurb: Label
var _bars: Control


func _init(start: String = "") -> void:
	add_theme_constant_override("separation", 8)
	UiKit.section(self, "Weapon")
	var group := ButtonGroup.new()
	var row: HBoxContainer
	for id in WeaponData.IDS:
		if id == WeaponData.GUNS[0] or id == WeaponData.MELEE[0]:   # guns on one row, melee on the next
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			add_child(row)
		var b := Button.new()
		b.text = WeaponData.by_id(id).short_name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_pressed.bind(id))
		b.set_meta("sfx", "none")   # picking a gun plays the gun being readied instead
		row.add_child(b)
		_buttons[id] = b
	_blurb = UiKit.label(self, "", true, 15)
	_blurb.custom_minimum_size = Vector2(0, 40)
	_bars = Control.new()
	_bars.custom_minimum_size = Vector2(0, 46)
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	select(WeaponData.valid(start))


## Show `id` as the picked gun without reporting it.
func select(id: String) -> void:
	id = WeaponData.valid(id)
	if id == current:
		return
	current = id
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(key == id)
	_blurb.text = WeaponData.by_id(id).blurb
	_bars.queue_redraw()


func _on_pressed(id: String) -> void:
	if id == current:
		_buttons[id].set_pressed_no_signal(true)
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
	var shot := w.damage * w.pellets
	var per_second := 1.0 / w.fire_interval
	var reach := w.falloff_end if w.falloff_end < 500.0 else 120.0
	return [
		["DAMAGE", clampf(shot / 110.0, 0.05, 1.0)],
		["FIRE RATE", clampf(per_second / 10.0, 0.05, 1.0)],
		["RANGE", clampf(reach / 120.0, 0.05, 1.0) if w.id != "sniper" else 1.0],
		["MAGAZINE", clampf(w.magazine / 30.0, 0.05, 1.0)],
	]


func _draw_bars() -> void:
	var r := ratings(WeaponData.by_id(current))
	var col_w := _bars.size.x / 2.0
	for i in r.size():
		var x := (i % 2) * col_w
		var y := (i / 2) * 23.0
		HudStyle.text(_bars, Vector2(x, y + 8.0), r[i][0], 11, Color(1, 1, 1, 0.6))
		var bx := x + 76.0
		var bw := minf(BAR_W, col_w - 86.0)
		_bars.draw_rect(Rect2(bx, y + 4.0, bw, 6.0), Color(1, 1, 1, 0.12))
		_bars.draw_rect(Rect2(bx, y + 4.0, bw * float(r[i][1]), 6.0), UiKit.ACCENT)
