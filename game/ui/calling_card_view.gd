class_name CallingCardView
extends Control
## A calling card on a page: the card, its icon at the left end and, if given, a
## name written over it. See CallingCard for the designs.
##
##   row.add_child(CallingCardView.of_player(id, Vector2(96, 30)))

var card := CallingCard.DEFAULT_CARD
var icon := CallingCard.DEFAULT_ICON
var text := ""                ## written over the card, after the icon
var text_color := Color.WHITE


func _init(card_id: String = CallingCard.DEFAULT_CARD, icon_id: String = CallingCard.DEFAULT_ICON, at_least: Vector2 = Vector2(96, 30), label: String = "") -> void:
	card = CallingCard.valid_card(card_id)
	icon = CallingCard.valid_icon(icon_id)
	text = label
	custom_minimum_size = at_least
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The card and icon a player in the lobby or match wears.
static func of_player(id: int, at_least: Vector2 = Vector2(96, 30)) -> CallingCardView:
	return CallingCardView.new(Net.player_card(id), Net.player_icon(id), at_least)


func show_card(card_id: String, icon_id: String, label: String = "") -> void:
	card = CallingCard.valid_card(card_id)
	icon = CallingCard.valid_icon(icon_id)
	text = label
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	CallingCard.draw(self, r, card, icon, 0.6 if text != "" else 0.0)
	if text != "":
		HudStyle.text(self, Vector2(size.y * 1.1, size.y * 0.5), text, int(size.y * 0.36), text_color)
