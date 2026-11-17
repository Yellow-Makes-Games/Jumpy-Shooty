class_name HudStyle
extends RefCounted
## Colours, font and small drawing helpers shared by every part of the in-game HUD.
## Everything is drawn in code (no textures), with a dark edge under each shape
## and each line of text so it reads on bright and dark backgrounds alike.

const WHITE := Color(1, 1, 1, 0.95)
const DIM := Color(1, 1, 1, 0.25)
const EDGE := Color(0, 0, 0, 0.45)
const PANEL := Color(0.04, 0.05, 0.07, 0.55)
const CYAN := Color(0.4, 0.9, 1.0)
const ORANGE := Color(1.0, 0.54, 0.24)
const RED := Color(1.0, 0.29, 0.24)
const YELLOW := Color(1.0, 0.85, 0.29)

const LOW_HEALTH := 30.0   ## at or below this the health readouts turn red

static var _fonts := {}


## Chakra Petch (SIL Open Font License, see fonts/OFL.txt).
static func font(bold: bool = true) -> Font:
	var key := "Bold" if bold else "SemiBold"
	if not _fonts.has(key):
		_fonts[key] = load("res://game/ui/fonts/ChakraPetch-%s.ttf" % key)
	return _fonts[key]


## Text with a soft dark outline. `pos` is the anchor point: its x is the left
## edge, centre or right edge (by `align`), and its y is the vertical middle.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color = WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = true) -> float:
	var f := font(bold)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	var baseline := pos.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5
	var edge := Color(0, 0, 0, 0.6 * color.a)
	ci.draw_string_outline(f, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2 if size < 16 else max(3, size / 6), edge)
	ci.draw_string(f, Vector2(x, baseline), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return w


static func text_width(s: String, size: int, bold: bool = true) -> float:
	return font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## An arc between two angles in degrees (0 = right, 90 = down, clockwise).
static func arc(ci: CanvasItem, c: Vector2, r: float, from_deg: float, to_deg: float, color: Color, width: float) -> void:
	if absf(to_deg - from_deg) < 0.05:
		return
	var points := maxi(4, int(absf(to_deg - from_deg) / 3.0))
	ci.draw_arc(c, r, deg_to_rad(from_deg), deg_to_rad(to_deg), points, color, width, true)


## An arc with a dark edge under it.
static func edged_arc(ci: CanvasItem, c: Vector2, r: float, from_deg: float, to_deg: float, color: Color, width: float) -> void:
	arc(ci, c, r, from_deg, to_deg, Color(0, 0, 0, EDGE.a * minf(color.a / 0.95, 1.0)), width + 3.0)
	arc(ci, c, r, from_deg, to_deg, color, width)


static func edged_rect(ci: CanvasItem, r: Rect2, color: Color) -> void:
	ci.draw_rect(r.grow(1.5), EDGE)
	ci.draw_rect(r, color)


## A rounded dark plate behind text.
static func plate(ci: CanvasItem, r: Rect2, radius: float = 4.0, color: Color = PANEL) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	ci.draw_style_box(box, r)


## A small pistol silhouette (kill feed).
static func pistol(ci: CanvasItem, at: Vector2, color: Color, s: float = 1.0) -> void:
	var pts := PackedVector2Array([
		Vector2(0, 0), Vector2(19, 0), Vector2(19, 4), Vector2(10, 4), Vector2(9, 9),
		Vector2(5, 9), Vector2(6, 4), Vector2(0, 4)])
	for i in pts.size():
		pts[i] = at + pts[i] * s
	ci.draw_colored_polygon(pts, color)


## A small silhouette of a gun, barrel to the right (kill feed, death screen). Returns its width.
static func weapon_icon(ci: CanvasItem, id: String, at: Vector2, color: Color, s: float = 1.0) -> float:
	var shapes := []
	match id:
		"shotgun":
			shapes = [[Vector2(0, 1), Vector2(9, 0), Vector2(36, 0), Vector2(36, 3), Vector2(13, 4), Vector2(11, 9),
				Vector2(8, 9), Vector2(9, 4), Vector2(0, 6)], [Vector2(18, 4), Vector2(28, 4), Vector2(28, 7), Vector2(18, 7)]]
		"rifle":
			shapes = [[Vector2(0, 1), Vector2(8, 0), Vector2(34, 0), Vector2(34, 2.5), Vector2(28, 3), Vector2(28, 5),
				Vector2(18, 5), Vector2(17, 11), Vector2(14, 11), Vector2(14, 5), Vector2(11, 5), Vector2(10, 9),
				Vector2(7, 9), Vector2(8, 5), Vector2(0, 6)]]
		"sniper":
			shapes = [[Vector2(0, 2), Vector2(8, 1), Vector2(26, 1), Vector2(44, 1.5), Vector2(44, 3), Vector2(26, 3.5),
				Vector2(24, 5), Vector2(12, 5), Vector2(11, 9), Vector2(8, 9), Vector2(9, 5), Vector2(0, 6)],
				[Vector2(11, -3), Vector2(23, -3), Vector2(23, 0), Vector2(11, 0)]]
		"sword":   # blade to the right
			shapes = [[Vector2(0, 3), Vector2(8, 3), Vector2(8, 5), Vector2(0, 5)],
				[Vector2(8, -1), Vector2(10, -1), Vector2(10, 9), Vector2(8, 9)],
				[Vector2(10, 2.5), Vector2(36, 2.5), Vector2(40, 4), Vector2(36, 5.5), Vector2(10, 5.5)]]
		"hammer":
			shapes = [[Vector2(0, 3), Vector2(24, 3), Vector2(24, 5), Vector2(0, 5)],
				[Vector2(22, -3), Vector2(32, -3), Vector2(32, 11), Vector2(22, 11)]]
		"dagger":
			shapes = [[Vector2(0, 3), Vector2(6, 3), Vector2(6, 5), Vector2(0, 5)],
				[Vector2(6, 0), Vector2(8, 0), Vector2(8, 8), Vector2(6, 8)],
				[Vector2(8, 2.5), Vector2(20, 2.5), Vector2(24, 4), Vector2(20, 5.5), Vector2(8, 5.5)]]
		_:
			pistol(ci, at, color, s)
			return 19.0 * s
	var width := 0.0
	for shape in shapes:
		var pts := PackedVector2Array()
		for p in shape:
			pts.append(at + p * s)
			width = maxf(width, p.x * s)
		ci.draw_colored_polygon(pts, color)
	return width


static func health_color(hp: float) -> Color:
	return RED if hp <= LOW_HEALTH else WHITE
