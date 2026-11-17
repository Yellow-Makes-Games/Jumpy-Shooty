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
		"revolver":
			shapes = [[Vector2(0, 1), Vector2(26, 1), Vector2(26, 3.5), Vector2(11, 3.5), Vector2(10, 5),
				Vector2(5, 10), Vector2(1, 10), Vector2(3, 4), Vector2(0, 4)], [Vector2(6, 0), Vector2(12, 0), Vector2(12, 5), Vector2(6, 5)]]
		"machine_pistol":
			shapes = [[Vector2(0, 0), Vector2(21, 0), Vector2(21, 4), Vector2(9, 4), Vector2(8, 15), Vector2(5, 15),
				Vector2(5, 4), Vector2(0, 4)], [Vector2(15, 4), Vector2(17, 4), Vector2(17, 8), Vector2(15, 8)]]
		"akimbo":   # two pistols, one behind and above the other
			for off in [Vector2(6, -5), Vector2(0, 0)]:
				shapes.append([Vector2(0, 0) + off, Vector2(18, 0) + off, Vector2(18, 4) + off, Vector2(9.5, 4) + off,
					Vector2(8.5, 9) + off, Vector2(5, 9) + off, Vector2(5.5, 4) + off, Vector2(0, 4) + off])
		"break_action":
			shapes = [[Vector2(0, 2), Vector2(10, 1), Vector2(40, 0), Vector2(40, 3.5), Vector2(14, 4), Vector2(12, 9),
				Vector2(9, 9), Vector2(10, 4.5), Vector2(0, 7)], [Vector2(15, 3.5), Vector2(28, 3.5), Vector2(28, 6), Vector2(15, 6)]]
		"smg":
			shapes = [[Vector2(0, 2), Vector2(6, 1), Vector2(28, 1), Vector2(28, 3.5), Vector2(22, 4), Vector2(22, 8),
				Vector2(20, 8), Vector2(20, 4.5), Vector2(15, 4.5), Vector2(15, 12), Vector2(12, 12), Vector2(12, 4.5),
				Vector2(9, 4.5), Vector2(8, 8), Vector2(6, 8), Vector2(6, 4.5), Vector2(0, 5)]]
		"burst_rifle":
			shapes = [[Vector2(0, 1), Vector2(8, 0), Vector2(36, 0), Vector2(38, 2), Vector2(36, 4.5), Vector2(19, 5),
				Vector2(18, 10), Vector2(15, 10), Vector2(15, 5), Vector2(11, 5), Vector2(10, 9), Vector2(7, 9),
				Vector2(8, 5), Vector2(0, 6)], [Vector2(12, -3), Vector2(22, -3), Vector2(22, 0), Vector2(12, 0)]]
		"lmg":
			shapes = [[Vector2(0, 1), Vector2(8, 0), Vector2(46, 0.5), Vector2(46, 3), Vector2(28, 3.5), Vector2(28, 5),
				Vector2(12, 5), Vector2(11, 9), Vector2(8, 9), Vector2(9, 5), Vector2(0, 6)],
				[Vector2(13, 5), Vector2(23, 5), Vector2(23, 12), Vector2(13, 12)], [Vector2(14, -3), Vector2(24, -3), Vector2(24, -1), Vector2(14, -1)]]
		"lever_action":
			shapes = [[Vector2(0, 2), Vector2(9, 1), Vector2(42, 0.5), Vector2(42, 2.5), Vector2(14, 3.5), Vector2(12, 5),
				Vector2(0, 6.5)], [Vector2(9, 4.5), Vector2(15, 4.5), Vector2(15, 9), Vector2(9, 9)], [Vector2(16, 3), Vector2(30, 3), Vector2(30, 5), Vector2(16, 5)]]
		"bolt_action":
			shapes = [[Vector2(0, 2), Vector2(9, 1), Vector2(26, 1), Vector2(44, 1.2), Vector2(44, 3), Vector2(36, 3.5),
				Vector2(36, 5), Vector2(12, 5), Vector2(11, 9), Vector2(8, 9), Vector2(9, 5), Vector2(0, 6.5)],
				[Vector2(14, -1.5), Vector2(16, -1.5), Vector2(16, 1), Vector2(14, 1)]]
		"railgun":
			shapes = [[Vector2(0, 1), Vector2(10, -1), Vector2(44, -1), Vector2(44, 1), Vector2(18, 1), Vector2(18, 3),
				Vector2(44, 3), Vector2(44, 5), Vector2(15, 5), Vector2(14, 10), Vector2(11, 10), Vector2(11, 5), Vector2(0, 6)]]
		"rocket_launcher":
			shapes = [[Vector2(0, -1), Vector2(44, -1), Vector2(46, 0), Vector2(46, 5), Vector2(44, 6), Vector2(0, 6), Vector2(-2, 7), Vector2(-2, -2)],
				[Vector2(14, 6), Vector2(17, 6), Vector2(17, 11), Vector2(14, 11)], [Vector2(26, 6), Vector2(29, 6), Vector2(29, 10), Vector2(26, 10)]]
		"grenade_launcher":
			shapes = [[Vector2(0, 2), Vector2(8, 1), Vector2(14, 1), Vector2(14, 5), Vector2(11, 5), Vector2(10, 10),
				Vector2(7, 10), Vector2(8, 5), Vector2(0, 6)], [Vector2(13, -2), Vector2(23, -2), Vector2(23, 8), Vector2(13, 8)],
				[Vector2(23, 0), Vector2(36, 0), Vector2(36, 5), Vector2(23, 5)]]
		"brass_knuckles":
			shapes = [[Vector2(0, 0), Vector2(18, 0), Vector2(18, 4), Vector2(0, 4)], [Vector2(1, 4), Vector2(17, 4), Vector2(14, 9), Vector2(4, 9)],
				[Vector2(1, -3), Vector2(4, -3), Vector2(4, 0), Vector2(1, 0)], [Vector2(5.5, -3), Vector2(8.5, -3), Vector2(8.5, 0), Vector2(5.5, 0)],
				[Vector2(10, -3), Vector2(13, -3), Vector2(13, 0), Vector2(10, 0)], [Vector2(14.5, -3), Vector2(17.5, -3), Vector2(17.5, 0), Vector2(14.5, 0)]]
		"spear":
			shapes = [[Vector2(0, 3.2), Vector2(40, 3.2), Vector2(40, 4.8), Vector2(0, 4.8)],
				[Vector2(40, 1.5), Vector2(46, 1.5), Vector2(52, 4), Vector2(46, 6.5), Vector2(40, 6.5)]]
		"axe":
			shapes = [[Vector2(0, 3), Vector2(30, 3), Vector2(30, 5), Vector2(0, 5)],
				[Vector2(24, 1), Vector2(30, 1), Vector2(33, -4), Vector2(33, 12), Vector2(30, 7), Vector2(24, 7)]]
		"bat":
			shapes = [[Vector2(0, 3), Vector2(10, 3), Vector2(34, 1.5), Vector2(38, 2.5), Vector2(38, 5.5), Vector2(34, 6.5),
				Vector2(10, 5), Vector2(0, 5)], [Vector2(-1.5, 2), Vector2(0.5, 2), Vector2(0.5, 6), Vector2(-1.5, 6)]]

		"none":   # a boot (Deathmatch: killed with a kick, or a crash, before finding a weapon)
			shapes = [[Vector2(2, -2), Vector2(9, -2), Vector2(9, 5), Vector2(19, 6), Vector2(21, 10), Vector2(2, 10)]]
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


## How wide a weapon's icon is at size 1 (to centre it).
static func weapon_width(id: String) -> float:
	return {"shotgun": 40.0, "rifle": 38.0, "sniper": 49.0, "sword": 40.0, "hammer": 32.0, "dagger": 24.0,
		"revolver": 26.0, "machine_pistol": 21.0, "akimbo": 24.0, "break_action": 40.0, "smg": 28.0, "burst_rifle": 38.0, "lmg": 46.0,
		"lever_action": 42.0, "bolt_action": 44.0, "railgun": 44.0, "rocket_launcher": 46.0, "grenade_launcher": 36.0,
		"brass_knuckles": 18.0, "spear": 52.0, "axe": 33.0, "bat": 38.0}.get(id, 22.0)


static func health_color(hp: float) -> Color:
	return RED if hp <= LOW_HEALTH else WHITE
