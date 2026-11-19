class_name PlayerCardView
extends VBoxContainer
## A player in the lobby, close up: their calling card with their name, their level,
## their loadout (robot, weapon, mobility tool, colour) and the cosmetics they wear
## (calling card, icon and, on a custom character, its parts, accessories and paints).
## A cosmetic you have not unlocked yourself is drawn in red, and its tooltip says
## which achievement unlocks it and how far you are from it.
##
## The lobby shows one while the mouse is over a player (see LobbyMenu) and keeps one
## open in a window when you click them, so you can point at the red ones.

const WIDTH := 360.0
const LOCKED := Color(1.0, 0.36, 0.32)

var player_id := 0


func _init(id: int) -> void:
	player_id = id
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_constant_override("separation", 10)
	add_child(CallingCardView.new(Net.player_card(id), Net.player_icon(id), Vector2(WIDTH, 64), Net.player_name(id)))
	var level := Net.player_level(id)
	var lv := UiKit.label(self, ("LEVEL %d" % level) if level > 0 else ("BOT" if Net.is_bot(id) else "LEVEL ?"), false, 20)
	lv.name = "level"
	lv.add_theme_font_override("font", HudStyle.font(true))
	lv.add_theme_color_override("font_color", UiKit.ACCENT)
	var grid := GridContainer.new()
	grid.name = "loadout"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	var color := Net.player_color(id)
	var color_name := ""
	var at := Net.PLAYER_COLORS.find(color)
	if at >= 0:
		color_name = Net.PLAYER_COLOR_NAMES[at]
	for line in [["Robot", Characters.name_of(Net.player_character(id))], ["Weapon", WeaponData.name_of(Net.player_weapon(id))],
			["Mobility", Mobility.name_of(Net.player_loadout_mobility(id))], ["Colour", color_name]]:
		if str(line[1]) == "":
			continue
		UiKit.label(grid, str(line[0]), true, 14)
		var v := UiKit.label(grid, str(line[1]), false, 15)
		v.name = str(line[0]).to_lower()
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
	UiKit.section(self, "Cosmetics")
	var chips := HFlowContainer.new()
	chips.name = "cosmetics"
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	add_child(chips)
	var locked := 0
	for key in cosmetics(id):
		var chip := _chip(key)
		chips.add_child(chip)
		if chip.has_meta("locked"):
			locked += 1
	if locked > 0:
		var note := UiKit.label(self, "Red: not unlocked for you yet. Click the player and point at one to see how to get it.", true, 13)
		note.name = "locked_note"
		note.add_theme_color_override("font_color", Color(LOCKED, 0.85))


## What a player wears that can be unlocked: their calling card and icon, and on a
## custom character, its body parts, accessories and paints (item keys, see
## Achievements).
static func cosmetics(id: int) -> Array:
	var out := ["card:" + Net.player_card(id), "icon:" + Net.player_icon(id)]
	var character := Net.player_character(id)
	if Characters.is_custom(character):
		out.append_array(Achievements.keys_of(CustomCharacter.parse(character)))
	return out


## One cosmetic: its name, red with what unlocks it if you don't have it.
func _chip(key: String) -> PanelContainer:
	var locked := Achievements.locked(key)
	var chip := PanelContainer.new()
	chip.name = key.replace(":", "_")
	var box := UiKit.cut_box(Color(LOCKED, 0.16) if locked else Color(1, 1, 1, 0.06), 6, 10, 4)
	box.border_width_left = 2
	box.border_color = LOCKED if locked else Color(UiKit.LINE, 0.5)
	chip.add_theme_stylebox_override("panel", box)
	var l := UiKit.label(chip, Achievements.item_name(key), false, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		chip.set_meta("locked", true)
		l.add_theme_color_override("font_color", LOCKED)
		chip.tooltip_text = "Locked for you.\n" + Achievements.requirement(key)
	else:
		chip.tooltip_text = "You have this one too." if Achievements.achievement_for(key).size() > 0 else "Free for everyone."
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	return chip
