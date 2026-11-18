class_name CallingCardPicker
extends VBoxContainer
## The Calling Card page's body (main menu > Calling Card): your card as others see
## it, then every calling card and every icon to pick from. The ones an achievement
## unlocks are dimmed with a padlock until it is done; hovering over one (or clicking
## it) says what it needs. Your pick is saved, and sent to the lobby if you are in one.

signal picked   ## a card or an icon was chosen

const CARD_COLUMNS := 6
const ICON_COLUMNS := 17
const CARD_SIZE := Vector2(0, 46)
const ICON_SIZE := Vector2(54, 54)

var status: Label           ## what a locked one needs, or what you picked
var saves := true           ## write the pick to the settings file (tests: false)

var _preview: CallingCardView
var _cards := {}            # card id -> Choice
var _icons := {}            # icon id -> Choice


## A card or an icon as a button: the design, an orange frame when it is the pick,
## dimmed under a padlock while it is locked.
class Choice extends Button:
	var kind := "card"
	var id := ""
	var locked := false
	var chosen := false

	func _init(what: String, which: String) -> void:
		kind = what
		id = which
		name = "%s_%s" % [kind, id]
		flat = true
		focus_mode = Control.FOCUS_NONE
		set_meta("sfx", "select")

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(-3.0)
		if kind == "card":
			CallingCard.draw_card(self, r, id)
		else:
			CallingCard.draw_icon(self, r, id)
		if locked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.06, 0.72))
			_padlock(r.get_center(), minf(r.size.x, r.size.y) * 0.2)
		if chosen:
			draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), UiKit.ACCENT, false, 2.5)
		elif is_hovered():
			draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), Color(1, 1, 1, 0.5), false, 1.5)

	func _padlock(mid: Vector2, s: float) -> void:
		var ink := Color(1, 1, 1, 0.85)
		draw_arc(mid + Vector2(0, -s * 0.35), s * 0.5, PI, TAU, 12, ink, maxf(1.5, s * 0.22), true)
		draw_rect(Rect2(mid + Vector2(-s * 0.8, -s * 0.35), Vector2(s * 1.6, s * 1.3)), ink)


func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	add_child(top)
	_preview = CallingCardView.new(Settings.calling_card, Settings.icon, Vector2(420, 92), Settings.player_name)
	top.add_child(_preview)
	var about := VBoxContainer.new()
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(about)
	UiKit.label(about, "This is how other players see you: in the lobby, on the results, and on their screen when you take them out.", true, 16)
	status = UiKit.label(about, "", false, 16)
	status.custom_minimum_size = Vector2(0, 44)
	UiKit.section(self, "Calling card")
	var cards := GridContainer.new()
	cards.columns = CARD_COLUMNS
	cards.add_theme_constant_override("h_separation", 6)
	cards.add_theme_constant_override("v_separation", 6)
	add_child(cards)
	for c in CallingCard.CARDS:
		var b := Choice.new("card", c.id)
		b.custom_minimum_size = CARD_SIZE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(pick.bind("card", c.id))
		cards.add_child(b)
		_cards[c.id] = b
	UiKit.section(self, "Icon")
	var icons := GridContainer.new()
	icons.columns = ICON_COLUMNS
	icons.add_theme_constant_override("h_separation", 6)
	icons.add_theme_constant_override("v_separation", 6)
	add_child(icons)
	for i in CallingCard.ICONS:
		var b := Choice.new("icon", i.id)
		b.custom_minimum_size = ICON_SIZE
		b.pressed.connect(pick.bind("icon", i.id))
		icons.add_child(b)
		_icons[i.id] = b
	_refresh()


## Choose a card ("card") or an icon ("icon"). A locked one is not taken: the line
## beside the preview says what it needs.
func pick(kind: String, id: String) -> void:
	var key := "%s:%s" % [kind, id]
	if Achievements.locked(key):
		status.text = "%s is locked.  %s" % [Achievements.item_name(key), Achievements.requirement(key)]
		status.add_theme_color_override("font_color", CharacterCreator.LOCKED)
		return
	if kind == "card":
		Settings.calling_card = CallingCard.valid_card(id)
	else:
		Settings.icon = CallingCard.valid_icon(id)
	if saves:
		Settings.save_settings()
	if Net.players.has(Net.my_id()):
		Net.set_my_card(Settings.calling_card, Settings.icon)
	status.text = "%s picked." % Achievements.item_name(key)
	status.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	_refresh()
	picked.emit()


func _refresh() -> void:
	_preview.show_card(Settings.calling_card, Settings.icon, Settings.player_name)
	for group in [["card", _cards, Settings.calling_card], ["icon", _icons, Settings.icon]]:
		for id in group[1]:
			var b: Choice = group[1][id]
			var key := "%s:%s" % [group[0], id]
			b.locked = Achievements.locked(key)
			b.chosen = id == group[2]
			b.tooltip_text = Achievements.item_name(key) if not b.locked else "%s (locked)\n%s" % [Achievements.item_name(key), Achievements.requirement(key)]
			b.queue_redraw()
