class_name CallingCard
extends RefCounted
## Calling cards and icons: the banner behind your name and the badge beside it,
## as other players see you (in the lobby, on their death screen when you get them,
## on the scoreboard and the results). You pick one of each in the main menu
## (Calling Card); most are unlocked by achievements (see Achievements: "card:sunset",
## "icon:skull").
##
## Everything is drawn in code, so there are no picture files: a card is a pattern
## (stripes, a sunset, a city skyline...) in three colours, an icon a glyph (a star, a
## skull, a crown...) on a badge.
##
##   CallingCard.draw_card(canvas_item, rect, "sunset")
##   CallingCard.draw_icon(canvas_item, rect, "skull")
##   CallingCard.draw(canvas_item, rect, "sunset", "skull")    # the card with the icon at its left end
##
## Adding one: a line in CARDS (with one of the patterns in _draw_pattern) or in ICONS
## (with one of the glyphs in _draw_glyph); name it in an achievement's rewards to
## lock it. The picker, the network check and the test read the tables.

const DEFAULT_CARD := "standard"
const DEFAULT_ICON := "star"

## id, name, pattern, and its colours: a and b the background (a gradient), c the pattern.
const CARDS := [
	{"id": "standard", "name": "Standard Issue", "pattern": "plain", "a": Color(0.10, 0.16, 0.24), "b": Color(0.18, 0.30, 0.44), "c": Color(0.55, 0.8, 1.0)},
	{"id": "ember", "name": "Ember", "pattern": "plain", "a": Color(0.30, 0.10, 0.05), "b": Color(0.85, 0.38, 0.10), "c": Color(1.0, 0.8, 0.4)},
	{"id": "racing", "name": "Racing Stripes", "pattern": "stripes", "a": Color(0.07, 0.10, 0.20), "b": Color(0.12, 0.22, 0.45), "c": Color(0.95, 0.95, 1.0)},
	{"id": "grid", "name": "Neon Grid", "pattern": "grid", "a": Color(0.05, 0.03, 0.14), "b": Color(0.20, 0.05, 0.30), "c": Color(0.3, 0.95, 1.0)},
	{"id": "dusk", "name": "Dusk Ridge", "pattern": "mountains", "a": Color(0.16, 0.12, 0.30), "b": Color(0.85, 0.45, 0.35), "c": Color(0.20, 0.16, 0.30)},
	{"id": "tide", "name": "Tide", "pattern": "waves", "a": Color(0.04, 0.20, 0.28), "b": Color(0.10, 0.45, 0.50), "c": Color(0.55, 0.95, 0.9)},
	{"id": "sunset", "name": "Sunset Drive", "pattern": "sun", "a": Color(0.20, 0.05, 0.32), "b": Color(0.95, 0.35, 0.40), "c": Color(1.0, 0.85, 0.3)},
	{"id": "starfield", "name": "Starfield", "pattern": "stars", "a": Color(0.02, 0.03, 0.09), "b": Color(0.08, 0.06, 0.22), "c": Color(0.9, 0.55, 0.3)},
	{"id": "hazard", "name": "Hazard", "pattern": "hazard", "a": Color(0.10, 0.10, 0.11), "b": Color(0.22, 0.21, 0.20), "c": Color(1.0, 0.78, 0.1)},
	{"id": "inferno", "name": "Inferno", "pattern": "flames", "a": Color(0.10, 0.02, 0.02), "b": Color(0.40, 0.05, 0.02), "c": Color(1.0, 0.5, 0.1)},
	{"id": "woodland", "name": "Woodland Camo", "pattern": "camo", "a": Color(0.22, 0.28, 0.14), "b": Color(0.12, 0.17, 0.09), "c": Color(0.42, 0.36, 0.22)},
	{"id": "arctic", "name": "Arctic Camo", "pattern": "camo", "a": Color(0.82, 0.86, 0.90), "b": Color(0.55, 0.62, 0.70), "c": Color(0.96, 0.97, 1.0)},
	{"id": "circuit", "name": "Circuit", "pattern": "circuit", "a": Color(0.02, 0.10, 0.08), "b": Color(0.04, 0.22, 0.16), "c": Color(0.4, 1.0, 0.6)},
	{"id": "sunburst", "name": "Sunburst", "pattern": "rays", "a": Color(0.85, 0.45, 0.05), "b": Color(1.0, 0.75, 0.2), "c": Color(1.0, 0.95, 0.7)},
	{"id": "skyline", "name": "Night Shift", "pattern": "skyline", "a": Color(0.03, 0.05, 0.14), "b": Color(0.25, 0.12, 0.35), "c": Color(1.0, 0.85, 0.45)},
	{"id": "bullseye", "name": "Bullseye", "pattern": "target", "a": Color(0.14, 0.02, 0.03), "b": Color(0.40, 0.06, 0.07), "c": Color(1.0, 0.92, 0.9)},
	{"id": "storm", "name": "Storm Front", "pattern": "bolts", "a": Color(0.06, 0.07, 0.14), "b": Color(0.22, 0.24, 0.38), "c": Color(1.0, 0.95, 0.5)},
	{"id": "chequered", "name": "Chequered Flag", "pattern": "checker", "a": Color(0.08, 0.08, 0.09), "b": Color(0.20, 0.20, 0.22), "c": Color(0.96, 0.96, 0.96)},
	{"id": "honeycomb", "name": "Honeycomb", "pattern": "hex", "a": Color(0.30, 0.18, 0.02), "b": Color(0.80, 0.52, 0.05), "c": Color(1.0, 0.88, 0.4)},
	{"id": "abyss", "name": "Abyss", "pattern": "waves", "a": Color(0.01, 0.02, 0.08), "b": Color(0.03, 0.08, 0.25), "c": Color(0.2, 0.5, 1.0)},
	{"id": "aurora", "name": "Aurora", "pattern": "aurora", "a": Color(0.02, 0.04, 0.10), "b": Color(0.05, 0.10, 0.20), "c": Color(0.3, 1.0, 0.6)},
	{"id": "royal", "name": "Royal", "pattern": "rays", "a": Color(0.20, 0.05, 0.35), "b": Color(0.45, 0.15, 0.65), "c": Color(1.0, 0.82, 0.3)},
	{"id": "blood_moon", "name": "Blood Moon", "pattern": "sun", "a": Color(0.02, 0.01, 0.02), "b": Color(0.30, 0.02, 0.04), "c": Color(0.9, 0.12, 0.1)},
	{"id": "toxic", "name": "Toxic", "pattern": "hazard", "a": Color(0.05, 0.10, 0.04), "b": Color(0.10, 0.22, 0.06), "c": Color(0.6, 1.0, 0.15)},
	{"id": "gold_bar", "name": "Solid Gold", "pattern": "chrome", "a": Color(0.55, 0.36, 0.05), "b": Color(1.0, 0.86, 0.35), "c": Color(1.0, 0.97, 0.75)},
	{"id": "chrome", "name": "Chrome", "pattern": "chrome", "a": Color(0.25, 0.30, 0.38), "b": Color(0.80, 0.86, 0.94), "c": Color(1.0, 1.0, 1.0)},
	{"id": "blueprint", "name": "Blueprint", "pattern": "circuit", "a": Color(0.05, 0.16, 0.40), "b": Color(0.08, 0.26, 0.58), "c": Color(0.85, 0.93, 1.0)},
	{"id": "magma", "name": "Magma", "pattern": "hex", "a": Color(0.08, 0.02, 0.02), "b": Color(0.28, 0.05, 0.02), "c": Color(1.0, 0.4, 0.1)},
	{"id": "frostbite", "name": "Frostbite", "pattern": "mountains", "a": Color(0.05, 0.10, 0.25), "b": Color(0.55, 0.80, 0.95), "c": Color(0.92, 0.97, 1.0)},
	{"id": "vaporwave", "name": "Vaporwave", "pattern": "grid", "a": Color(0.95, 0.45, 0.70), "b": Color(0.25, 0.10, 0.45), "c": Color(1.0, 0.95, 0.5)},
]

## id, name, glyph, its colour, and the badge behind it (shape: circle, shield, hex, diamond or square).
const ICONS := [
	{"id": "star", "name": "Star", "glyph": "star", "color": Color(1.0, 0.85, 0.3), "back": Color(0.12, 0.18, 0.30), "shape": "circle"},
	{"id": "robot", "name": "Robot", "glyph": "robot", "color": Color(0.9, 0.93, 0.97), "back": Color(0.15, 0.35, 0.55), "shape": "square"},
	{"id": "bolt", "name": "Bolt", "glyph": "bolt", "color": Color(1.0, 0.9, 0.3), "back": Color(0.20, 0.12, 0.35), "shape": "hex"},
	{"id": "heart", "name": "Heart", "glyph": "heart", "color": Color(1.0, 0.35, 0.45), "back": Color(0.25, 0.06, 0.12), "shape": "circle"},
	{"id": "rank", "name": "Stripes", "glyph": "chevrons", "color": Color(1.0, 0.8, 0.3), "back": Color(0.14, 0.22, 0.14), "shape": "shield"},
	{"id": "paw", "name": "Paw", "glyph": "paw", "color": Color(0.98, 0.92, 0.85), "back": Color(0.45, 0.25, 0.12), "shape": "circle"},
	{"id": "sun", "name": "Sun", "glyph": "sun", "color": Color(1.0, 0.8, 0.2), "back": Color(0.15, 0.40, 0.65), "shape": "circle"},
	{"id": "moon", "name": "Moon", "glyph": "moon", "color": Color(0.95, 0.95, 0.8), "back": Color(0.08, 0.08, 0.22), "shape": "circle"},
	{"id": "skull", "name": "Skull", "glyph": "skull", "color": Color(0.95, 0.95, 0.92), "back": Color(0.12, 0.12, 0.14), "shape": "circle"},
	{"id": "crosshair", "name": "Crosshair", "glyph": "crosshair", "color": Color(1.0, 0.3, 0.25), "back": Color(0.10, 0.10, 0.12), "shape": "square"},
	{"id": "crown", "name": "Crown", "glyph": "crown", "color": Color(1.0, 0.82, 0.25), "back": Color(0.35, 0.08, 0.45), "shape": "shield"},
	{"id": "flame", "name": "Flame", "glyph": "flame", "color": Color(1.0, 0.55, 0.1), "back": Color(0.22, 0.04, 0.03), "shape": "circle"},
	{"id": "gem", "name": "Gem", "glyph": "gem", "color": Color(0.4, 0.9, 1.0), "back": Color(0.06, 0.12, 0.25), "shape": "diamond"},
	{"id": "shield", "name": "Shield", "glyph": "shield", "color": Color(0.75, 0.82, 0.9), "back": Color(0.12, 0.25, 0.50), "shape": "circle"},
	{"id": "wings", "name": "Wings", "glyph": "wings", "color": Color(0.97, 0.97, 1.0), "back": Color(0.30, 0.55, 0.85), "shape": "circle"},
	{"id": "boot", "name": "Boot", "glyph": "boot", "color": Color(0.95, 0.6, 0.3), "back": Color(0.18, 0.12, 0.08), "shape": "hex"},
	{"id": "hook", "name": "Hook", "glyph": "hook", "color": Color(0.85, 0.9, 0.95), "back": Color(0.10, 0.30, 0.32), "shape": "circle"},
	{"id": "stopwatch", "name": "Stopwatch", "glyph": "stopwatch", "color": Color(0.95, 0.95, 0.95), "back": Color(0.55, 0.12, 0.10), "shape": "circle"},
	{"id": "flag", "name": "Flag", "glyph": "flag", "color": Color(0.95, 0.95, 0.95), "back": Color(0.10, 0.10, 0.12), "shape": "shield"},
	{"id": "duck", "name": "Duck", "glyph": "duck", "color": Color(1.0, 0.85, 0.2), "back": Color(0.20, 0.55, 0.75), "shape": "circle"},
	{"id": "eye", "name": "Eye", "glyph": "eye", "color": Color(0.95, 0.95, 0.9), "back": Color(0.30, 0.08, 0.35), "shape": "diamond"},
	{"id": "swords", "name": "Crossed Swords", "glyph": "swords", "color": Color(0.88, 0.92, 0.96), "back": Color(0.45, 0.08, 0.08), "shape": "shield"},
	{"id": "rocket", "name": "Rocket", "glyph": "rocket", "color": Color(0.95, 0.95, 0.97), "back": Color(0.08, 0.10, 0.28), "shape": "circle"},
	{"id": "trophy", "name": "Trophy", "glyph": "trophy", "color": Color(1.0, 0.82, 0.25), "back": Color(0.10, 0.25, 0.18), "shape": "hex"},
	{"id": "ghost", "name": "Ghost", "glyph": "ghost", "color": Color(0.92, 0.96, 1.0), "back": Color(0.15, 0.10, 0.30), "shape": "circle"},
	{"id": "bomb", "name": "Bomb", "glyph": "bomb", "color": Color(0.18, 0.18, 0.2), "back": Color(0.95, 0.65, 0.15), "shape": "circle"},
	{"id": "dice", "name": "Dice", "glyph": "dice", "color": Color(0.96, 0.96, 0.96), "back": Color(0.10, 0.40, 0.20), "shape": "square"},
	{"id": "medal", "name": "Medal", "glyph": "medal", "color": Color(1.0, 0.82, 0.25), "back": Color(0.10, 0.16, 0.36), "shape": "circle"},
	{"id": "ninja", "name": "Ninja", "glyph": "mask", "color": Color(0.14, 0.14, 0.18), "back": Color(0.75, 0.12, 0.12), "shape": "circle"},
	{"id": "gold_star", "name": "Gold Star", "glyph": "star", "color": Color(1.0, 0.97, 0.75), "back": Color(0.85, 0.6, 0.1), "shape": "hex"},
	{"id": "gold_skull", "name": "Golden Skull", "glyph": "skull", "color": Color(1.0, 0.85, 0.3), "back": Color(0.20, 0.03, 0.03), "shape": "diamond"},
	{"id": "ace", "name": "Ace", "glyph": "wings", "color": Color(1.0, 0.85, 0.3), "back": Color(0.10, 0.12, 0.30), "shape": "shield"},
	{"id": "speed", "name": "Speed", "glyph": "bolt", "color": Color(0.3, 1.0, 0.9), "back": Color(0.03, 0.12, 0.14), "shape": "circle"},
	{"id": "target", "name": "Marksman", "glyph": "crosshair", "color": Color(0.5, 1.0, 0.5), "back": Color(0.05, 0.14, 0.06), "shape": "circle"},
]


static func card(id: String) -> Dictionary:
	for c in CARDS:
		if c.id == id:
			return c
	return CARDS[0]


static func icon(id: String) -> Dictionary:
	for i in ICONS:
		if i.id == id:
			return i
	return ICONS[0]


## A real card's id: `id`, or the default for anything made up (the host checks what it is sent).
static func valid_card(id: String) -> String:
	return card(id).id


static func valid_icon(id: String) -> String:
	return icon(id).id


static func card_name(id: String) -> String:
	return card(id).name


static func icon_name(id: String) -> String:
	return icon(id).name


# ---------------------------------------------------------------------------
# Drawing

## The card with its icon at the left end. shade: how dark the left of the card is
## made (0 to 1), for a name written over it.
static func draw(ci: CanvasItem, rect: Rect2, card_id: String, icon_id: String, shade: float = 0.0) -> void:
	draw_card(ci, rect, card_id, shade)
	var side := rect.size.y * 0.86
	draw_icon(ci, Rect2(rect.position + Vector2(rect.size.y * 0.07, rect.size.y * 0.07), Vector2(side, side)), icon_id)


static func draw_card(ci: CanvasItem, rect: Rect2, id: String, shade: float = 0.0) -> void:
	var c := card(id)
	_draw_pattern(ci, rect, c)
	if shade > 0.0:
		var dark := Color(0.02, 0.03, 0.05, shade)
		ci.draw_polygon(_corners(rect), PackedColorArray([dark, Color(dark, 0.0), Color(dark, 0.0), dark]))
	ci.draw_rect(rect, Color(1, 1, 1, 0.22), false, 1.0)


static func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A filled shape, cut to the card.
static func _fill(ci: CanvasItem, clip: Rect2, points: PackedVector2Array, color: Color) -> void:
	for piece in Geometry2D.intersect_polygons(points, _corners(clip)):
		if piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty():
			ci.draw_colored_polygon(piece, color)


static func _line(ci: CanvasItem, clip: Rect2, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var n := (to - from).orthogonal().normalized() * width * 0.5
	if n != Vector2.ZERO:
		_fill(ci, clip, PackedVector2Array([from - n, to - n, to + n, from + n]), color)


static func _disc(center: Vector2, radius: float, n: int = 28, squash: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(center + Vector2(cos(i * TAU / n), sin(i * TAU / n) * squash) * radius)
	return out


static func _ring(ci: CanvasItem, clip: Rect2, center: Vector2, radius: float, width: float, color: Color, n: int = 28) -> void:
	for i in n:
		_line(ci, clip, center + Vector2.from_angle(i * TAU / n) * radius, center + Vector2.from_angle((i + 1) * TAU / n) * radius, width, color)


## A background gradient: across (left to right) or down.
static func _gradient(ci: CanvasItem, r: Rect2, a: Color, b: Color, down: bool = false) -> void:
	ci.draw_polygon(_corners(r), PackedColorArray([a, a, b, b] if down else [a, b, b, a]))


static func _draw_pattern(ci: CanvasItem, r: Rect2, c: Dictionary) -> void:
	var h := r.size.y
	var wide := r.size.x / h   # the card's width in card heights
	var a: Color = c.a
	var b: Color = c.b
	var k: Color = c.c
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c.id)
	var at := func(x: float, y: float) -> Vector2: return r.position + Vector2(x, y) * h   # (in card heights)
	match c.pattern:
		"plain":
			_gradient(ci, r, a, b)
			_fill(ci, r, PackedVector2Array([at.call(wide * 0.58, 0), at.call(wide * 0.72, 0), at.call(wide * 0.52, 1), at.call(wide * 0.38, 1)]), Color(k, 0.16))
			_fill(ci, r, PackedVector2Array([at.call(wide * 0.76, 0), at.call(wide * 0.80, 0), at.call(wide * 0.60, 1), at.call(wide * 0.56, 1)]), Color(k, 0.12))
			_line(ci, r, at.call(0, 0.93), at.call(wide, 0.93), h * 0.05, Color(k, 0.55))
		"stripes":
			_gradient(ci, r, a, b)
			for i in 3:
				var x := wide * 0.52 + i * 0.42
				_fill(ci, r, PackedVector2Array([at.call(x, 1), at.call(x + [0.26, 0.12, 0.26][i], 1), at.call(x + [0.26, 0.12, 0.26][i] + 0.6, 0), at.call(x + 0.6, 0)]),
					Color(k, 0.9) if i != 1 else Color(1.0, 0.3, 0.25))
		"sun":
			_gradient(ci, r, a, b, true)
			var sun: Vector2 = at.call(wide * 0.70, 0.66)
			_fill(ci, r, _disc(sun, h * 0.46), k)
			for i in 4:   # the slits across the lower half of the sun
				var y := 0.66 + 0.10 * i + 0.01 * i * i
				_line(ci, r, at.call(wide * 0.70 - 0.5, y), at.call(wide * 0.70 + 0.5, y), h * (0.025 + 0.012 * i), b)
			_fill(ci, r, PackedVector2Array([at.call(0, 0.86), at.call(wide, 0.86), at.call(wide, 1), at.call(0, 1)]), a.darkened(0.45))
			_line(ci, r, at.call(0, 0.86), at.call(wide, 0.86), h * 0.03, Color(k, 0.8))
		"grid":
			_gradient(ci, r, a, b, true)
			var horizon := 0.42
			var vanish: Vector2 = at.call(wide * 0.62, horizon)
			for i in range(-9, 10):
				_line(ci, r, vanish, at.call(wide * 0.62 + i * 0.55, 1.0), h * 0.022, Color(k, 0.75))
			for i in 6:
				var y := horizon + 0.58 * pow((i + 1) / 6.0, 1.8)
				_line(ci, r, at.call(0, y), at.call(wide, y), h * 0.022, Color(k, 0.75))
			_fill(ci, r, PackedVector2Array([at.call(0, 0), at.call(wide, 0), at.call(wide, horizon), at.call(0, horizon)]), Color(a, 0.92))
			_line(ci, r, at.call(0, horizon), at.call(wide, horizon), h * 0.03, k)
			_fill(ci, r, _disc(at.call(wide * 0.62, horizon), h * 0.2, 20), Color(k, 0.25))
		"stars", "aurora":
			_gradient(ci, r, a, b, true)
			if c.pattern == "aurora":
				for band in 3:
					var pts := PackedVector2Array()
					var low := PackedVector2Array()
					for i in 17:
						var x := wide * i / 16.0
						var y := 0.25 + 0.14 * band + 0.12 * sin(x * (2.2 + band * 0.7) + band * 1.9)
						pts.append(at.call(x, y))
						low.append(at.call(x, y + 0.22 + 0.06 * sin(x * 3.1 + band)))
					low.reverse()
					_fill(ci, r, pts + low, Color(k if band != 1 else Color(0.6, 0.4, 1.0), 0.30))
			for i in 34:
				var p: Vector2 = at.call(rng.randf() * wide, rng.randf())
				var s := h * rng.randf_range(0.02, 0.055)
				_fill(ci, r, PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), Color(1, 1, 1, rng.randf_range(0.35, 1.0)))
			if c.pattern == "stars":
				var planet: Vector2 = at.call(wide * 0.78, 0.42)
				_fill(ci, r, _disc(planet, h * 0.24), k)
				_fill(ci, r, _disc(planet + Vector2(h * 0.06, -h * 0.05), h * 0.16), k.lightened(0.18))
				_line(ci, r, planet + Vector2(-h * 0.44, h * 0.12), planet + Vector2(h * 0.44, -h * 0.12), h * 0.035, Color(1, 1, 1, 0.75))
		"hazard":
			_gradient(ci, r, a, b)
			for i in 9:
				var x := wide * 0.58 + i * 0.3
				if i % 2 == 0:
					_fill(ci, r, PackedVector2Array([at.call(x, 1), at.call(x + 0.3, 1), at.call(x + 0.85, 0), at.call(x + 0.55, 0)]), k)
			_line(ci, r, at.call(0, 0.91), at.call(wide * 0.6, 0.91), h * 0.06, k)
		"flames":
			_gradient(ci, r, a, b, true)
			for layer in 2:
				var x := -0.2
				while x < wide + 0.3:
					var width := rng.randf_range(0.28, 0.5) * (1.0 - 0.3 * layer)
					var tall := rng.randf_range(0.45, 0.95) * (1.0 - 0.35 * layer)
					var lean := rng.randf_range(-0.12, 0.12)
					_fill(ci, r, PackedVector2Array([at.call(x, 1.02), at.call(x + width * 0.18, 1.0 - tall * 0.5), at.call(x + width * 0.5 + lean, 1.0 - tall),
						at.call(x + width * 0.72, 1.0 - tall * 0.42), at.call(x + width, 1.02)]), k if layer == 0 else Color(1.0, 0.88, 0.35))
					x += width * 0.62
		"camo":
			_gradient(ci, r, a, a)
			for i in 26:
				var center: Vector2 = at.call(rng.randf() * wide, rng.randf())
				var blob := PackedVector2Array()
				var size := rng.randf_range(0.14, 0.36)
				for j in 9:
					blob.append(center + Vector2.from_angle(j * TAU / 9.0) * h * size * rng.randf_range(0.55, 1.2) * Vector2(1.5, 1.0))
				_fill(ci, r, blob, b if i % 2 == 0 else k)
		"circuit":
			_gradient(ci, r, a, b)
			for i in 9:
				var p := Vector2(rng.randf_range(wide * 0.3, wide * 0.6), 0.1 + 0.1 * i)
				var pos: Vector2 = at.call(p.x, p.y)
				for seg in 3:
					var run := rng.randf_range(0.3, 0.9)
					var next: Vector2 = pos + Vector2(run * h, 0)
					_line(ci, r, pos, next, h * 0.028, Color(k, 0.8))
					var jog := h * rng.randf_range(-0.14, 0.14)
					_line(ci, r, next, next + Vector2(absf(jog), jog), h * 0.028, Color(k, 0.8))
					pos = next + Vector2(absf(jog), jog)
				_fill(ci, r, _disc(pos, h * 0.05, 8), k)
				_fill(ci, r, _disc(at.call(p.x, p.y), h * 0.035, 8), Color(k, 0.8))
		"rays":
			_gradient(ci, r, a, b)
			var from: Vector2 = at.call(wide * 0.80, 1.1)
			for i in 12:
				var a0 := PI + (i + 0.0) * PI / 12.0
				var a1 := PI + (i + 0.5) * PI / 12.0
				_fill(ci, r, PackedVector2Array([from, from + Vector2.from_angle(a0) * h * 6.0, from + Vector2.from_angle(a1) * h * 6.0]), Color(k, 0.32))
			_fill(ci, r, _disc(from, h * 0.42), k)
		"mountains":
			_gradient(ci, r, a, b, true)
			_fill(ci, r, _disc(at.call(wide * 0.82, 0.3), h * 0.13, 20), Color(1, 1, 1, 0.8))
			for layer in 3:
				var ridge := PackedVector2Array([at.call(0, 1.05)])
				var x := 0.0
				var up := true
				while x <= wide + 0.4:
					ridge.append(at.call(x, (0.34 + 0.2 * layer + rng.randf_range(0.0, 0.16)) if up else (0.62 + 0.13 * layer + rng.randf_range(0.0, 0.1))))
					x += rng.randf_range(0.3, 0.55)
					up = not up
				ridge.append(at.call(wide + 0.4, 1.05))
				_fill(ci, r, ridge, k.lerp(a, 0.5 - 0.25 * layer) if layer < 2 else k)
		"waves":
			_gradient(ci, r, a, b, true)
			for band in 4:
				var pts := PackedVector2Array()
				for i in 25:
					var x := wide * i / 24.0
					pts.append(at.call(x, 0.34 + 0.17 * band + 0.07 * sin(x * (3.0 + band * 0.8) + band * 2.1)))
				pts.append(at.call(wide, 1.05))
				pts.append(at.call(0, 1.05))
				_fill(ci, r, pts, Color(k, 0.16 + 0.07 * band))
		"hex":
			_gradient(ci, r, a, b)
			var size := 0.19
			for row in 5:
				for col in 12:
					var center := Vector2(wide * 0.36 + col * size * 1.74 + (size * 0.87 if row % 2 == 1 else 0.0), -0.02 + row * size * 1.5)
					var fade := clampf((center.x - wide * 0.36) / (wide * 0.5), 0.0, 1.0)
					if center.x > wide + size:
						continue
					for i in 6:
						_line(ci, r, at.call(center.x, center.y) + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * h * size,
							at.call(center.x, center.y) + Vector2.from_angle(PI / 6.0 + (i + 1) * PI / 3.0) * h * size, h * 0.022, Color(k, 0.15 + 0.7 * fade))
					if rng.randf() < 0.2:
						_fill(ci, r, _disc(at.call(center.x, center.y), h * size * 0.82, 6), Color(k, 0.45 * fade))
		"skyline":
			_gradient(ci, r, a, b, true)
			_fill(ci, r, _disc(at.call(wide * 0.86, 0.26), h * 0.12, 20), Color(1, 1, 0.9, 0.9))
			var x := 0.0
			while x < wide:
				var width := rng.randf_range(0.16, 0.34)
				var top := rng.randf_range(0.28, 0.72)
				_fill(ci, r, PackedVector2Array([at.call(x, top), at.call(x + width, top), at.call(x + width, 1), at.call(x, 1)]), Color(0.02, 0.02, 0.05))
				var wy := top + 0.07
				while wy < 0.95:
					var wx := x + 0.04
					while wx < x + width - 0.05:
						if rng.randf() < 0.45:
							_fill(ci, r, PackedVector2Array([at.call(wx, wy), at.call(wx + 0.04, wy), at.call(wx + 0.04, wy + 0.05), at.call(wx, wy + 0.05)]), Color(k, 0.9))
						wx += 0.075
					wy += 0.1
				x += width + 0.015
		"target":
			_gradient(ci, r, a, b)
			var mid: Vector2 = at.call(wide * 0.76, 0.5)
			for i in 4:
				_ring(ci, r, mid, h * (0.16 + 0.2 * i), h * 0.05, Color(k, 0.85 - 0.15 * i), 36)
			_fill(ci, r, _disc(mid, h * 0.06, 14), k)
			_line(ci, r, mid - Vector2(h * 1.2, 0), mid + Vector2(h * 1.2, 0), h * 0.02, Color(k, 0.6))
			_line(ci, r, mid - Vector2(0, h), mid + Vector2(0, h), h * 0.02, Color(k, 0.6))
		"bolts":
			_gradient(ci, r, a, b, true)
			for i in 3:
				var x := wide * (0.5 + 0.17 * i)
				var s := 1.0 - 0.18 * i
				_fill(ci, r, PackedVector2Array([at.call(x + 0.22 * s, -0.02), at.call(x - 0.10 * s, 0.50), at.call(x + 0.08 * s, 0.50), at.call(x - 0.16 * s, 1.02),
					at.call(x + 0.26 * s, 0.38), at.call(x + 0.07 * s, 0.38), at.call(x + 0.40 * s, -0.02)]), Color(k, 1.0 - 0.25 * i))
		"checker":
			_gradient(ci, r, a, b)
			var size := 0.2
			for row in 5:
				for col in 14:
					var x := wide * 0.42 + col * size + row * 0.05   # (leaning, like a flag in the wind)
					if (row + col) % 2 == 0 and x < wide:
						_fill(ci, r, PackedVector2Array([at.call(x, row * size), at.call(x + size, row * size), at.call(x + size + 0.05, (row + 1) * size), at.call(x + 0.05, (row + 1) * size)]),
							Color(k, clampf(0.25 + (x - wide * 0.42) / (wide * 0.4), 0.0, 1.0)))
		"chrome":
			var top := Rect2(r.position, Vector2(r.size.x, h * 0.52))
			var low := Rect2(r.position + Vector2(0, h * 0.52), Vector2(r.size.x, h * 0.48))
			_gradient(ci, top, b.lerp(a, 0.35), k, true)
			_gradient(ci, low, a, b, true)
			_line(ci, r, at.call(0, 0.52), at.call(wide, 0.52), h * 0.03, a.darkened(0.3))
			for i in 2:
				var x := wide * (0.5 + 0.22 * i)
				_fill(ci, r, PackedVector2Array([at.call(x + 0.3, 0), at.call(x + 0.42 + 0.1 * i, 0), at.call(x + 0.12 + 0.1 * i, 1), at.call(x, 1)]), Color(1, 1, 1, 0.35))
		_:
			_gradient(ci, r, a, b)


## The badge and its glyph, in a square.
static func draw_icon(ci: CanvasItem, rect: Rect2, id: String) -> void:
	var i := icon(id)
	var mid := rect.get_center()
	var half := minf(rect.size.x, rect.size.y) * 0.5
	var back: Color = i.back
	var badge := _badge(i.shape, mid, half)
	ci.draw_colored_polygon(badge, back)
	ci.draw_colored_polygon(_badge(i.shape, mid - Vector2(0, half * 0.08), half * 0.8), back.lightened(0.10))
	badge.append(badge[0])
	ci.draw_polyline(badge, back.lightened(0.45), maxf(1.0, half * 0.07), true)
	_draw_glyph(ci, i.glyph, mid, half * (0.56 if i.shape in ["diamond", "hex"] else 0.62), i.color, back.lightened(0.10))


static func _badge(shape: String, mid: Vector2, half: float) -> PackedVector2Array:
	match shape:
		"square":
			var out := PackedVector2Array()
			var cut := half * 0.28
			for p in [Vector2(-half + cut, -half), Vector2(half - cut, -half), Vector2(half, -half + cut), Vector2(half, half - cut),
					Vector2(half - cut, half), Vector2(-half + cut, half), Vector2(-half, half - cut), Vector2(-half, -half + cut)]:
				out.append(mid + p * 0.94)
			return out
		"diamond":
			return PackedVector2Array([mid + Vector2(0, -half), mid + Vector2(half, 0), mid + Vector2(0, half), mid + Vector2(-half, 0)])
		"hex":
			var out := PackedVector2Array()
			for i in 6:
				out.append(mid + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * half)
			return out
		"shield":
			return PackedVector2Array([mid + Vector2(-half * 0.86, -half * 0.92), mid + Vector2(half * 0.86, -half * 0.92), mid + Vector2(half * 0.86, half * 0.1),
				mid + Vector2(half * 0.5, half * 0.66), mid + Vector2(0, half), mid + Vector2(-half * 0.5, half * 0.66), mid + Vector2(-half * 0.86, half * 0.1)])
	return _disc(mid, half, 28)


## A glyph round `mid`, about `s` in every direction, in `ink`; `gap`: the badge's
## colour, for the holes (a skull's eyes).
static func _draw_glyph(ci: CanvasItem, glyph: String, mid: Vector2, s: float, ink: Color, gap: Color) -> void:
	var at := func(x: float, y: float) -> Vector2: return mid + Vector2(x, y) * s
	var poly := func(points: Array, color: Color) -> void:
		var out := PackedVector2Array()
		for p in points:
			out.append(mid + (p as Vector2) * s)
		ci.draw_colored_polygon(out, color)
	var w := maxf(1.0, s * 0.16)   # a stroke
	match glyph:
		"star":
			var pts := []
			for i in 10:
				pts.append(Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * (1.0 if i % 2 == 0 else 0.42))
			poly.call(pts, ink)
		"skull":
			ci.draw_circle(at.call(0, -0.2), s * 0.72, ink)
			poly.call([Vector2(-0.42, 0.2), Vector2(0.42, 0.2), Vector2(0.36, 0.9), Vector2(-0.36, 0.9)], ink)
			ci.draw_circle(at.call(-0.3, -0.18), s * 0.2, gap)
			ci.draw_circle(at.call(0.3, -0.18), s * 0.2, gap)
			poly.call([Vector2(0, 0.08), Vector2(0.1, 0.32), Vector2(-0.1, 0.32)], gap)
			for x in [-0.14, 0.14]:
				ci.draw_line(at.call(x, 0.56), at.call(x, 0.9), gap, w * 0.6)
		"crosshair":
			ci.draw_arc(mid, s * 0.66, 0, TAU, 28, ink, w, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(mid + d * s * 0.38, mid + d * s * 1.0, ink, w)
			ci.draw_circle(mid, s * 0.12, ink)
		"bolt":
			poly.call([Vector2(0.25, -1.0), Vector2(-0.5, 0.12), Vector2(-0.05, 0.12), Vector2(-0.3, 1.0), Vector2(0.55, -0.2), Vector2(0.08, -0.2), Vector2(0.42, -1.0)], ink)
		"crown":
			poly.call([Vector2(-0.9, 0.55), Vector2(-0.9, -0.5), Vector2(-0.45, 0.05), Vector2(0, -0.75), Vector2(0.45, 0.05), Vector2(0.9, -0.5), Vector2(0.9, 0.55)], ink)
			ci.draw_line(at.call(-0.9, 0.78), at.call(0.9, 0.78), ink, w)
			for x in [-0.9, 0.0, 0.9]:
				ci.draw_circle(at.call(x, -0.62 if x != 0.0 else -0.86), s * 0.13, ink)
		"flame":
			poly.call([Vector2(0.05, -1.0), Vector2(0.55, -0.2), Vector2(0.7, 0.35), Vector2(0.4, 0.85), Vector2(0, 1.0), Vector2(-0.4, 0.85), Vector2(-0.7, 0.35),
				Vector2(-0.5, -0.1), Vector2(-0.25, 0.1), Vector2(-0.2, -0.5)], ink)
			poly.call([Vector2(0.05, 0.0), Vector2(0.32, 0.5), Vector2(0.15, 0.85), Vector2(-0.15, 0.85), Vector2(-0.3, 0.5)], Color(1.0, 0.92, 0.5))
		"heart":
			ci.draw_circle(at.call(-0.42, -0.3), s * 0.5, ink)
			ci.draw_circle(at.call(0.42, -0.3), s * 0.5, ink)
			poly.call([Vector2(-0.88, -0.08), Vector2(0.88, -0.08), Vector2(0, 0.95)], ink)
		"gem":
			poly.call([Vector2(-0.5, -0.7), Vector2(0.5, -0.7), Vector2(0.95, -0.2), Vector2(0, 0.9), Vector2(-0.95, -0.2)], ink)
			poly.call([Vector2(-0.5, -0.7), Vector2(0.5, -0.7), Vector2(0.3, -0.2), Vector2(-0.3, -0.2)], ink.lightened(0.5))
			poly.call([Vector2(-0.3, -0.2), Vector2(0.3, -0.2), Vector2(0, 0.9)], ink.darkened(0.25))
		"shield":
			poly.call([Vector2(-0.75, -0.85), Vector2(0.75, -0.85), Vector2(0.75, 0.1), Vector2(0, 0.95), Vector2(-0.75, 0.1)], ink)
			poly.call([Vector2(-0.14, -0.85), Vector2(0.14, -0.85), Vector2(0.14, 0.78), Vector2(0, 0.95), Vector2(-0.14, 0.78)], gap)
			poly.call([Vector2(-0.75, -0.35), Vector2(0.75, -0.35), Vector2(0.75, -0.08), Vector2(-0.75, -0.08)], gap)
		"wings":
			for side: float in [-1.0, 1.0]:
				poly.call([Vector2(0.08 * side, 0.1), Vector2(0.3 * side, -0.55), Vector2(1.0 * side, -0.75), Vector2(0.85 * side, -0.35), Vector2(1.0 * side, -0.2),
					Vector2(0.72 * side, 0.02), Vector2(0.82 * side, 0.2), Vector2(0.5 * side, 0.3), Vector2(0.55 * side, 0.5), Vector2(0.08 * side, 0.55)], ink)
			ci.draw_circle(at.call(0, 0.05), s * 0.2, ink)
		"boot":
			poly.call([Vector2(-0.45, -0.95), Vector2(0.2, -0.95), Vector2(0.2, 0.05), Vector2(0.9, 0.3), Vector2(0.95, 0.75), Vector2(-0.6, 0.75), Vector2(-0.6, 0.1)], ink)
			ci.draw_line(at.call(-0.65, 0.92), at.call(0.98, 0.92), ink.darkened(0.3), w)
			ci.draw_line(at.call(-0.45, -0.6), at.call(0.2, -0.6), gap, w * 0.6)
		"hook":
			ci.draw_arc(at.call(0, -0.72), s * 0.22, 0, TAU, 16, ink, w, true)
			ci.draw_line(at.call(0, -0.5), at.call(0, 0.85), ink, w)
			ci.draw_arc(at.call(0, 0.2), s * 0.68, 0.15, PI - 0.15, 18, ink, w, true)
			for side: float in [-1.0, 1.0]:
				poly.call([Vector2(0.9 * side, 0.02), Vector2(0.48 * side, 0.3), Vector2(0.86 * side, 0.5)], ink)
			ci.draw_line(at.call(-0.4, -0.2), at.call(0.4, -0.2), ink, w)
		"stopwatch":
			ci.draw_arc(at.call(0, 0.12), s * 0.72, 0, TAU, 28, ink, w, true)
			poly.call([Vector2(-0.16, -0.98), Vector2(0.16, -0.98), Vector2(0.16, -0.66), Vector2(-0.16, -0.66)], ink)
			ci.draw_line(at.call(0.55, -0.6), at.call(0.72, -0.78), ink, w)
			ci.draw_line(at.call(0, 0.12), at.call(0.3, -0.32), ink, w)
			ci.draw_circle(at.call(0, 0.12), s * 0.1, ink)
		"flag":
			ci.draw_line(at.call(-0.6, -0.9), at.call(-0.6, 0.95), ink, w)
			for row in 3:
				for col in 4:
					if (row + col) % 2 == 0:
						var x := -0.5 + col * 0.36
						var y := -0.85 + row * 0.3 + 0.05 * col
						poly.call([Vector2(x, y), Vector2(x + 0.36, y + 0.05), Vector2(x + 0.36, y + 0.35), Vector2(x, y + 0.3)], ink)
			var edge := PackedVector2Array([at.call(-0.5, -0.85), at.call(0.94, -0.65), at.call(0.94, 0.25), at.call(-0.5, 0.05), at.call(-0.5, -0.85)])
			ci.draw_polyline(edge, ink, w * 0.5, true)
		"duck":
			ci.draw_colored_polygon(_disc(at.call(-0.1, 0.4), s * 0.72, 20, 0.62), ink)
			ci.draw_circle(at.call(0.32, -0.38), s * 0.4, ink)
			poly.call([Vector2(0.62, -0.42), Vector2(1.0, -0.3), Vector2(0.62, -0.16)], Color(1.0, 0.5, 0.1))
			ci.draw_circle(at.call(0.4, -0.46), s * 0.08, Color(0.1, 0.1, 0.12))
			poly.call([Vector2(-0.82, 0.25), Vector2(-1.0, -0.1), Vector2(-0.55, 0.12)], ink)
		"robot":
			poly.call([Vector2(-0.7, -0.45), Vector2(0.7, -0.45), Vector2(0.82, -0.3), Vector2(0.82, 0.7), Vector2(0.6, 0.9), Vector2(-0.6, 0.9), Vector2(-0.82, 0.7), Vector2(-0.82, -0.3)], ink)
			poly.call([Vector2(-0.6, -0.12), Vector2(0.6, -0.12), Vector2(0.6, 0.28), Vector2(-0.6, 0.28)], Color(0.1, 0.14, 0.2))
			ci.draw_circle(at.call(-0.3, 0.08), s * 0.13, Color(0.4, 0.95, 1.0))
			ci.draw_circle(at.call(0.3, 0.08), s * 0.13, Color(0.4, 0.95, 1.0))
			ci.draw_line(at.call(0, -0.45), at.call(0, -0.85), ink, w * 0.7)
			ci.draw_circle(at.call(0, -0.9), s * 0.12, Color(1.0, 0.4, 0.3))
			ci.draw_line(at.call(-0.3, 0.6), at.call(0.3, 0.6), Color(0.1, 0.14, 0.2), w * 0.6)
		"eye":
			var lid := PackedVector2Array()
			for i in 13:
				lid.append(at.call(-1.0 + i / 6.0, -0.62 * sin(i * PI / 12.0)))
			for i in 13:
				lid.append(at.call(1.0 - i / 6.0, 0.62 * sin(i * PI / 12.0)))
			ci.draw_colored_polygon(lid, ink)
			ci.draw_circle(mid, s * 0.42, Color(0.25, 0.6, 0.9))
			ci.draw_circle(mid, s * 0.2, Color(0.05, 0.05, 0.08))
			ci.draw_circle(at.call(0.14, -0.14), s * 0.08, Color.WHITE)
		"swords":
			for side: float in [-1.0, 1.0]:
				ci.draw_line(at.call(-0.8 * side, -0.9), at.call(0.5 * side, 0.55), ink, w * 1.2)
				ci.draw_line(at.call(0.15 * side, 0.62), at.call(0.72 * side, 0.2), ink.darkened(0.25), w)
				ci.draw_line(at.call(0.5 * side, 0.55), at.call(0.78 * side, 0.9), Color(0.55, 0.35, 0.15), w * 1.2)
		"rocket":
			poly.call([Vector2(0, -1.0), Vector2(0.38, -0.45), Vector2(0.38, 0.5), Vector2(-0.38, 0.5), Vector2(-0.38, -0.45)], ink)
			for side: float in [-1.0, 1.0]:
				poly.call([Vector2(0.38 * side, 0.05), Vector2(0.82 * side, 0.7), Vector2(0.38 * side, 0.5)], Color(0.95, 0.3, 0.25))
			ci.draw_circle(at.call(0, -0.25), s * 0.18, Color(0.3, 0.7, 1.0))
			poly.call([Vector2(-0.24, 0.55), Vector2(0.24, 0.55), Vector2(0, 1.0)], Color(1.0, 0.7, 0.2))
		"trophy":
			poly.call([Vector2(-0.6, -0.85), Vector2(0.6, -0.85), Vector2(0.5, -0.1), Vector2(0.15, 0.25), Vector2(0.15, 0.55), Vector2(-0.15, 0.55), Vector2(-0.15, 0.25), Vector2(-0.5, -0.1)], ink)
			poly.call([Vector2(-0.5, 0.55), Vector2(0.5, 0.55), Vector2(0.5, 0.88), Vector2(-0.5, 0.88)], ink)
			for side: float in [-1.0, 1.0]:
				ci.draw_arc(at.call(0.62 * side, -0.48), s * 0.27, -PI / 2.0 if side > 0.0 else PI / 2.0, PI / 2.0 if side > 0.0 else PI * 1.5, 12, ink, w * 0.8, true)
		"ghost":
			var body := PackedVector2Array()
			for i in 13:
				body.append(at.call(-0.72 * cos(i * PI / 12.0), -0.15 - 0.8 * sin(i * PI / 12.0)))
			for p in [Vector2(0.72, 0.9), Vector2(0.48, 0.62), Vector2(0.24, 0.9), Vector2(0.0, 0.62), Vector2(-0.24, 0.9), Vector2(-0.48, 0.62), Vector2(-0.72, 0.9)]:
				body.append(mid + p * s)
			ci.draw_colored_polygon(body, ink)
			ci.draw_circle(at.call(-0.26, -0.2), s * 0.15, Color(0.1, 0.1, 0.2))
			ci.draw_circle(at.call(0.26, -0.2), s * 0.15, Color(0.1, 0.1, 0.2))
		"paw":
			ci.draw_colored_polygon(_disc(at.call(0, 0.38), s * 0.52, 18, 0.85), ink)
			for p in [Vector2(-0.68, -0.12), Vector2(-0.26, -0.58), Vector2(0.26, -0.58), Vector2(0.68, -0.12)]:
				ci.draw_circle(mid + p * s, s * 0.23, ink)
		"moon":
			for piece in Geometry2D.clip_polygons(_disc(mid, s * 0.9, 28), _disc(at.call(0.42, -0.2), s * 0.74, 28)):
				ci.draw_colored_polygon(piece, ink)
		"sun":
			ci.draw_circle(mid, s * 0.48, ink)
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0)
				ci.draw_line(mid + d * s * 0.66, mid + d * s * 1.0, ink, w)
		"chevrons":
			for i in 3:
				var y := -0.75 + i * 0.52
				poly.call([Vector2(-0.8, y + 0.4), Vector2(0, y), Vector2(0.8, y + 0.4), Vector2(0.8, y + 0.68), Vector2(0, y + 0.28), Vector2(-0.8, y + 0.68)], ink)
		"bomb":
			ci.draw_circle(at.call(-0.1, 0.25), s * 0.68, ink)
			poly.call([Vector2(0.18, -0.6), Vector2(0.5, -0.3), Vector2(0.3, -0.12), Vector2(0.0, -0.42)], ink)
			ci.draw_line(at.call(0.36, -0.48), at.call(0.72, -0.8), Color(0.6, 0.45, 0.25), w * 0.7)
			ci.draw_circle(at.call(0.78, -0.86), s * 0.16, Color(1.0, 0.3, 0.1))
			ci.draw_circle(at.call(-0.35, 0.02), s * 0.14, Color(1, 1, 1, 0.35))
		"dice":
			poly.call([Vector2(-0.6, -0.8), Vector2(0.6, -0.8), Vector2(0.8, -0.6), Vector2(0.8, 0.6), Vector2(0.6, 0.8), Vector2(-0.6, 0.8), Vector2(-0.8, 0.6), Vector2(-0.8, -0.6)], ink)
			for p in [Vector2(-0.42, -0.42), Vector2(0.42, -0.42), Vector2(0, 0), Vector2(-0.42, 0.42), Vector2(0.42, 0.42)]:
				ci.draw_circle(mid + p * s, s * 0.14, Color(0.1, 0.1, 0.12))
		"medal":
			poly.call([Vector2(-0.55, -1.0), Vector2(-0.15, -1.0), Vector2(0.2, -0.2), Vector2(-0.2, -0.2)], Color(0.85, 0.2, 0.2))
			poly.call([Vector2(0.55, -1.0), Vector2(0.15, -1.0), Vector2(-0.2, -0.2), Vector2(0.2, -0.2)], Color(0.25, 0.45, 0.9))
			ci.draw_circle(at.call(0, 0.35), s * 0.6, ink)
			ci.draw_circle(at.call(0, 0.35), s * 0.4, ink.darkened(0.18))
			var pts := []
			for i in 10:
				pts.append(Vector2(0, 0.35) + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * (0.3 if i % 2 == 0 else 0.13))
			poly.call(pts, ink.lightened(0.5))
		"mask":
			ci.draw_circle(mid, s * 0.86, ink)
			poly.call([Vector2(-0.8, -0.3), Vector2(0.8, -0.3), Vector2(0.86, 0.12), Vector2(-0.86, 0.12)], Color(0.92, 0.8, 0.68))
			ci.draw_line(at.call(-0.55, -0.16), at.call(-0.16, -0.02), Color(0.08, 0.08, 0.1), w)
			ci.draw_line(at.call(0.55, -0.16), at.call(0.16, -0.02), Color(0.08, 0.08, 0.1), w)
			poly.call([Vector2(0.7, -0.5), Vector2(1.15, -0.85), Vector2(1.05, -0.4)], ink)
		_:
			ci.draw_circle(mid, s * 0.5, ink)
