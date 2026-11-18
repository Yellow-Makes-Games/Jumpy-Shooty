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
const DEFAULT_ICON := "recruit"

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
	{"id": "hazard", "name": "Breach", "pattern": "hazard", "a": Color(0.10, 0.10, 0.11), "b": Color(0.22, 0.21, 0.20), "c": Color(1.0, 0.78, 0.1)},
	{"id": "inferno", "name": "Inferno", "pattern": "flames", "a": Color(0.10, 0.02, 0.02), "b": Color(0.40, 0.05, 0.02), "c": Color(1.0, 0.5, 0.1)},
	{"id": "woodland", "name": "Woodland Camo", "pattern": "camo", "a": Color(0.22, 0.28, 0.14), "b": Color(0.12, 0.17, 0.09), "c": Color(0.42, 0.36, 0.22)},
	{"id": "arctic", "name": "Arctic Camo", "pattern": "camo", "a": Color(0.82, 0.86, 0.90), "b": Color(0.55, 0.62, 0.70), "c": Color(0.96, 0.97, 1.0)},
	{"id": "circuit", "name": "Circuit", "pattern": "circuit", "a": Color(0.02, 0.10, 0.08), "b": Color(0.04, 0.22, 0.16), "c": Color(0.4, 1.0, 0.6)},
	{"id": "sunburst", "name": "Flashbulb", "pattern": "rays", "a": Color(0.85, 0.45, 0.05), "b": Color(1.0, 0.75, 0.2), "c": Color(1.0, 0.95, 0.7)},
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
	{"id": "frostbite", "name": "Crevasse", "pattern": "mountains", "a": Color(0.05, 0.10, 0.25), "b": Color(0.55, 0.80, 0.95), "c": Color(0.92, 0.97, 1.0)},
	{"id": "vaporwave", "name": "Vaporwave", "pattern": "grid", "a": Color(0.95, 0.45, 0.70), "b": Color(0.25, 0.10, 0.45), "c": Color(1.0, 0.95, 0.5)},
]

## Icons are emblems: a metal-rimmed plate with a glyph on it. id, name, glyph (see
## _draw_glyph), its colour (`color`) and second colour (`accent`: a glow, a gem, a
## grip), the plate (`back`, and its `shape`: circle, shield, crest, hex, diamond,
## square or burst), the rim's metal (`rim`: steel if it does not say) and whether
## rays fan out behind the glyph (`rays`).
const STEEL := Color(0.62, 0.67, 0.74)
const BRONZE := Color(0.78, 0.50, 0.28)
const GOLD := Color(1.0, 0.80, 0.28)
const BONE := Color(0.90, 0.88, 0.80)
const ICONS := [
	{"id": "recruit", "name": "Recruit", "glyph": "chevron", "color": Color(0.95, 0.78, 0.30), "accent": Color(0.95, 0.78, 0.30), "back": Color(0.20, 0.26, 0.16), "shape": "shield"},
	{"id": "unit", "name": "Unit", "glyph": "unit", "color": Color(0.80, 0.84, 0.90), "accent": Color(0.35, 0.95, 1.0), "back": Color(0.10, 0.22, 0.36), "shape": "hex"},
	{"id": "volt", "name": "Live Wire", "glyph": "bolt", "color": Color(1.0, 0.90, 0.30), "accent": Color(1.0, 0.60, 0.10), "back": Color(0.16, 0.10, 0.30), "shape": "diamond"},
	{"id": "claw", "name": "Claw Marks", "glyph": "claw", "color": Color(0.95, 0.22, 0.20), "accent": Color(1.0, 0.60, 0.50), "back": Color(0.10, 0.10, 0.12), "shape": "circle"},
	{"id": "rounds", "name": "Live Rounds", "glyph": "rounds", "color": Color(0.88, 0.70, 0.30), "accent": Color(0.80, 0.42, 0.25), "back": Color(0.14, 0.16, 0.14), "shape": "square"},
	{"id": "dagger", "name": "Combat Knife", "glyph": "dagger", "color": Color(0.82, 0.86, 0.92), "accent": Color(0.30, 0.32, 0.36), "back": Color(0.30, 0.08, 0.08), "shape": "crest"},
	{"id": "eclipse", "name": "Eclipse", "glyph": "eclipse", "color": Color(1.0, 0.92, 0.75), "accent": Color(1.0, 0.65, 0.25), "back": Color(0.06, 0.06, 0.14), "shape": "circle"},
	{"id": "pulse", "name": "Pulse", "glyph": "pulse", "color": Color(0.40, 1.0, 0.55), "accent": Color(0.10, 0.50, 0.25), "back": Color(0.04, 0.10, 0.08), "shape": "square"},
	{"id": "skull", "name": "Skull", "glyph": "skull", "color": BONE, "accent": Color(0.90, 0.15, 0.12), "back": Color(0.12, 0.12, 0.15), "shape": "crest"},
	{"id": "skull_king", "name": "Skull King", "glyph": "skull_king", "color": Color(1.0, 0.82, 0.32), "accent": Color(1.0, 0.25, 0.15), "back": Color(0.22, 0.03, 0.05), "shape": "burst", "rim": GOLD, "rays": true},
	{"id": "headhunter", "name": "Headhunter", "glyph": "headhunter", "color": BONE, "accent": Color(1.0, 0.25, 0.20), "back": Color(0.08, 0.14, 0.10), "shape": "circle", "rim": GOLD},
	{"id": "swords", "name": "Crossed Blades", "glyph": "swords", "color": Color(0.85, 0.89, 0.95), "accent": Color(0.90, 0.72, 0.28), "back": Color(0.38, 0.07, 0.08), "shape": "shield"},
	{"id": "laurels", "name": "Laurels", "glyph": "laurels", "color": Color(1.0, 0.82, 0.30), "accent": Color(1.0, 0.95, 0.70), "back": Color(0.08, 0.22, 0.16), "shape": "circle", "rim": GOLD},
	{"id": "crown", "name": "Crown", "glyph": "crown", "color": Color(1.0, 0.80, 0.25), "accent": Color(0.95, 0.20, 0.30), "back": Color(0.28, 0.07, 0.40), "shape": "crest", "rim": GOLD, "rays": true},
	{"id": "six_shooter", "name": "Six-Shooter", "glyph": "cylinder", "color": Color(0.70, 0.74, 0.80), "accent": Color(0.92, 0.72, 0.30), "back": Color(0.24, 0.14, 0.08), "shape": "hex"},
	{"id": "reticle", "name": "Scope", "glyph": "reticle", "color": Color(0.85, 0.95, 0.88), "accent": Color(1.0, 0.22, 0.18), "back": Color(0.05, 0.14, 0.10), "shape": "circle"},
	{"id": "grenade", "name": "Frag", "glyph": "grenade", "color": Color(0.42, 0.52, 0.28), "accent": Color(0.74, 0.77, 0.80), "back": Color(0.30, 0.16, 0.05), "shape": "hex"},
	{"id": "flame", "name": "Hot Streak", "glyph": "flame", "color": Color(0.95, 0.30, 0.10), "accent": Color(1.0, 0.70, 0.15), "back": Color(0.14, 0.04, 0.04), "shape": "diamond", "rim": BRONZE, "rays": true},
	{"id": "ace", "name": "Death Card", "glyph": "ace", "color": Color(0.93, 0.93, 0.90), "accent": Color(0.90, 0.15, 0.15), "back": Color(0.08, 0.08, 0.10), "shape": "square"},
	{"id": "phantom", "name": "Phantom", "glyph": "phantom", "color": Color(0.72, 0.80, 0.92), "accent": Color(0.40, 1.0, 0.95), "back": Color(0.10, 0.08, 0.24), "shape": "crest"},
	{"id": "blitz", "name": "Blitz", "glyph": "blitz", "color": Color(0.35, 1.0, 0.90), "accent": Color(0.90, 1.0, 1.0), "back": Color(0.03, 0.12, 0.16), "shape": "diamond"},
	{"id": "comet", "name": "Comet", "glyph": "comet", "color": Color(1.0, 0.95, 0.75), "accent": Color(0.45, 0.70, 1.0), "back": Color(0.05, 0.07, 0.22), "shape": "circle", "rim": GOLD},
	{"id": "overwatch", "name": "Overwatch", "glyph": "overwatch", "color": Color(0.90, 0.80, 0.50), "accent": Color(0.45, 0.90, 1.0), "back": Color(0.20, 0.06, 0.26), "shape": "hex"},
	{"id": "wings", "name": "Flight Wings", "glyph": "wings", "color": Color(0.86, 0.90, 0.96), "accent": Color(0.95, 0.75, 0.28), "back": Color(0.10, 0.22, 0.42), "shape": "circle"},
	{"id": "hook", "name": "Grapnel", "glyph": "hook", "color": Color(0.78, 0.83, 0.90), "accent": Color(0.85, 0.65, 0.35), "back": Color(0.06, 0.24, 0.26), "shape": "shield"},
	{"id": "boot", "name": "Steel Toe", "glyph": "boot", "color": Color(0.80, 0.56, 0.30), "accent": Color(0.86, 0.90, 0.95), "back": Color(0.12, 0.15, 0.20), "shape": "hex"},
	{"id": "sergeant", "name": "Top Rank", "glyph": "sergeant", "color": Color(1.0, 0.80, 0.28), "accent": Color(1.0, 0.95, 0.70), "back": Color(0.16, 0.20, 0.12), "shape": "shield", "rim": GOLD},
	{"id": "rec", "name": "On Tape", "glyph": "rec", "color": Color(0.92, 0.94, 0.96), "accent": Color(1.0, 0.18, 0.18), "back": Color(0.08, 0.09, 0.12), "shape": "square"},
	{"id": "c4", "name": "Charge", "glyph": "c4", "color": Color(0.78, 0.68, 0.48), "accent": Color(1.0, 0.20, 0.15), "back": Color(0.12, 0.16, 0.10), "shape": "square"},
	{"id": "defuser", "name": "Wire Cutters", "glyph": "defuser", "color": Color(0.78, 0.82, 0.88), "accent": Color(0.20, 0.55, 0.95), "back": Color(0.08, 0.14, 0.26), "shape": "shield"},
	{"id": "flag", "name": "War Flag", "glyph": "flag", "color": Color(0.90, 0.20, 0.18), "accent": Color(0.95, 0.90, 0.80), "back": Color(0.10, 0.11, 0.14), "shape": "crest"},
	{"id": "stopwatch", "name": "Stopwatch", "glyph": "stopwatch", "color": Color(0.85, 0.88, 0.92), "accent": Color(1.0, 0.35, 0.20), "back": Color(0.30, 0.16, 0.08), "shape": "circle", "rim": BRONZE},
	{"id": "medal", "name": "Gold Medal", "glyph": "medal", "color": Color(1.0, 0.80, 0.25), "accent": Color(0.20, 0.40, 0.90), "back": Color(0.08, 0.12, 0.28), "shape": "circle", "rim": GOLD},
	{"id": "mach", "name": "Mach One", "glyph": "mach", "color": Color(1.0, 0.84, 0.35), "accent": Color(0.55, 0.90, 1.0), "back": Color(0.05, 0.16, 0.30), "shape": "burst", "rim": GOLD},
	{"id": "scrapper", "name": "Scrap", "glyph": "scrapper", "color": Color(0.62, 0.64, 0.68), "accent": Color(1.0, 0.25, 0.15), "back": Color(0.20, 0.10, 0.06), "shape": "hex"},
	{"id": "signal", "name": "Signal", "glyph": "signal", "color": Color(0.85, 0.88, 0.92), "accent": Color(0.35, 1.0, 0.55), "back": Color(0.06, 0.16, 0.14), "shape": "circle"},
	{"id": "service", "name": "Service Stripes", "glyph": "service", "color": Color(0.95, 0.76, 0.28), "accent": Color(1.0, 0.92, 0.60), "back": Color(0.12, 0.16, 0.30), "shape": "crest"},
	{"id": "boomerang", "name": "Boomerang", "glyph": "boomerang", "color": Color(0.80, 0.55, 0.28), "accent": Color(0.95, 0.90, 0.75), "back": Color(0.10, 0.24, 0.12), "shape": "circle"},
	{"id": "diamond", "name": "Flawless", "glyph": "diamond", "color": Color(0.45, 0.88, 1.0), "accent": Color(1.0, 1.0, 1.0), "back": Color(0.05, 0.10, 0.24), "shape": "diamond", "rim": GOLD},
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


## An emblem, in a square: a shadow, a metal rim, the plate, and the glyph with a
## shadow of its own.
static func draw_icon(ci: CanvasItem, rect: Rect2, id: String) -> void:
	var i := icon(id)
	var mid := rect.get_center()
	var half := minf(rect.size.x, rect.size.y) * 0.5
	var back: Color = i.back
	var rim: Color = i.get("rim", STEEL)
	var shape: String = i.shape
	ci.draw_colored_polygon(_badge(shape, mid + Vector2(0, half * 0.07), half), Color(0, 0, 0, 0.45))
	_shaded(ci, _badge(shape, mid, half * 0.97), rim.lightened(0.45), rim.darkened(0.6))
	ci.draw_colored_polygon(_badge(shape, mid, half * 0.86), Color(0.02, 0.025, 0.04))
	var plate := _badge(shape, mid, half * 0.80)
	_shaded(ci, plate, back.lightened(0.22), back.darkened(0.5))
	if i.get("rays", false):   # rays fanning out from the middle
		for n in 10:
			var a := n * TAU / 10.0 - PI / 2.0
			var ray := PackedVector2Array([mid, mid + Vector2.from_angle(a - 0.14) * half, mid + Vector2.from_angle(a + 0.14) * half])
			for piece in Geometry2D.intersect_polygons(ray, plate):
				if piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty():
					ci.draw_colored_polygon(piece, Color(1, 1, 1, 0.07))
	# A gloss over the top of the plate.
	var gloss := PackedVector2Array([mid + Vector2(-half, -half), mid + Vector2(half, -half), mid + Vector2(half, -half * 0.25), mid + Vector2(-half, half * 0.05)])
	for piece in Geometry2D.intersect_polygons(gloss, plate):
		if piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty():
			ci.draw_colored_polygon(piece, Color(1, 1, 1, 0.06))
	plate.append(plate[0])
	ci.draw_polyline(plate, Color(back.lightened(0.55), 0.55), maxf(1.0, half * 0.035), true)
	var s := half * (0.50 if shape in ["diamond", "burst"] else 0.56)
	var pen := Pen.new()
	pen.ci = ci
	pen.s = s
	pen.mid = mid + Vector2(half * 0.04, half * 0.07)
	pen.flat = Color(back.darkened(0.82), 1.0)   # the glyph's shadow first
	_draw_glyph(pen, i.glyph, i.color, i.accent, back.darkened(0.7))
	pen.mid = mid
	pen.flat = Color(0, 0, 0, 0)
	_draw_glyph(pen, i.glyph, i.color, i.accent, back.darkened(0.7))


## A filled shape whose colour runs from `top` at its highest point to `bottom` at its lowest.
static func _shaded(ci: CanvasItem, points: PackedVector2Array, top: Color, bottom: Color) -> void:
	var lo := INF
	var hi := -INF
	for p in points:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var colors := PackedColorArray()
	for p in points:
		colors.append(top.lerp(bottom, (p.y - lo) / maxf(hi - lo, 0.001)))
	ci.draw_polygon(points, colors)


static func _badge(shape: String, mid: Vector2, half: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	match shape:
		"square":
			var cut := half * 0.28
			for p in [Vector2(-half + cut, -half), Vector2(half - cut, -half), Vector2(half, -half + cut), Vector2(half, half - cut),
					Vector2(half - cut, half), Vector2(-half + cut, half), Vector2(-half, half - cut), Vector2(-half, -half + cut)]:
				out.append(mid + p * 0.94)
		"diamond":
			for p in [Vector2(0, -1), Vector2(0.16, -0.84), Vector2(0.84, -0.16), Vector2(1, 0), Vector2(0.84, 0.16), Vector2(0.16, 0.84),
					Vector2(0, 1), Vector2(-0.16, 0.84), Vector2(-0.84, 0.16), Vector2(-1, 0), Vector2(-0.84, -0.16), Vector2(-0.16, -0.84)]:
				out.append(mid + p * half)
		"hex":
			for i in 6:
				out.append(mid + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * half)
		"shield":
			for p in [Vector2(-0.86, -0.92), Vector2(0.86, -0.92), Vector2(0.86, 0.1), Vector2(0.5, 0.66), Vector2(0, 1), Vector2(-0.5, 0.66), Vector2(-0.86, 0.1)]:
				out.append(mid + p * half)
		"crest":   # a shield with a peak and cut shoulders
			for p in [Vector2(0, -1), Vector2(0.3, -0.84), Vector2(0.9, -0.84), Vector2(0.9, 0.18), Vector2(0.6, 0.66), Vector2(0, 1),
					Vector2(-0.6, 0.66), Vector2(-0.9, 0.18), Vector2(-0.9, -0.84), Vector2(-0.3, -0.84)]:
				out.append(mid + p * half)
		"burst":   # a saw-toothed disc
			for i in 24:
				out.append(mid + Vector2.from_angle(i * TAU / 24.0 - PI / 2.0) * half * (1.0 if i % 2 == 0 else 0.86))
		_:
			out = _disc(mid, half, 32)
	return out


## Draws a glyph's shapes round `mid`, `s` to a unit, moved (`shift`), shrunk (`zoom`)
## or turned (`turn`); with `flat` set, everything is that one colour (the shadow).
class Pen:
	var ci: CanvasItem
	var mid := Vector2.ZERO
	var s := 1.0
	var shift := Vector2.ZERO
	var zoom := 1.0
	var turn := 0.0
	var flat := Color(0, 0, 0, 0)

	func at(p: Vector2) -> Vector2:
		return mid + (p * zoom).rotated(turn) * s + shift * s

	func ink(color: Color) -> Color:
		return flat if flat.a > 0.0 else color

	func poly(points: Array, color: Color) -> void:
		var out := PackedVector2Array()
		for p in points:
			out.append(at(p))
		if Geometry2D.triangulate_polygon(out).is_empty():
			return
		ci.draw_colored_polygon(out, ink(color))
		out.append(out[0])
		ci.draw_polyline(out, ink(color), 1.0, true)   # a smooth edge

	func line(a: Vector2, b: Vector2, color: Color, width: float = 0.14) -> void:
		ci.draw_line(at(a), at(b), ink(color), maxf(1.0, width * zoom * s), true)

	func path(points: Array, color: Color, width: float = 0.14) -> void:
		var out := PackedVector2Array()
		for p in points:
			out.append(at(p))
		ci.draw_polyline(out, ink(color), maxf(1.0, width * zoom * s), true)

	func dot(p: Vector2, radius: float, color: Color) -> void:
		ci.draw_circle(at(p), radius * zoom * s, ink(color), true, -1.0, true)

	func arc(p: Vector2, radius: float, from: float, to: float, color: Color, width: float = 0.14) -> void:
		ci.draw_arc(at(p), radius * zoom * s, from + turn, to + turn, 28, ink(color), maxf(1.0, width * zoom * s), true)

	## A star with `n` points.
	func star(p: Vector2, radius: float, color: Color, n: int = 5, inner: float = 0.42) -> void:
		var pts := []
		for i in n * 2:
			pts.append(p + Vector2.from_angle(-PI / 2.0 + i * PI / n) * radius * (1.0 if i % 2 == 0 else inner))
		poly(pts, color)

	## The same shape on both sides: `points` are the right side's.
	func both(points: Array, right: Color, left: Color) -> void:
		poly(points, right)
		poly(points.map(func(p: Vector2): return Vector2(-p.x, p.y)), left)


## A glyph: `k` its colour (and `d`, that in shadow), `a` its second colour, `g` the
## dark of the plate, for holes (a skull's eyes).
static func _draw_glyph(pen: Pen, glyph: String, k: Color, a: Color, g: Color) -> void:
	var d := k.darkened(0.32)
	var l := k.lightened(0.35)
	match glyph:
		"chevron":
			_chevron(pen, -0.3, 0.5, k, d)
		"sergeant":
			pen.zoom = 0.8
			for i in 3:
				_chevron(pen, -0.3 + i * 0.4, 0.26, k, d)
			pen.star(Vector2(0, -0.74), 0.36, a)
			pen.zoom = 1.0
		"service":
			for i in 3:
				var x := -0.86 + i * 0.5
				pen.poly([Vector2(x, 0.8), Vector2(x + 0.42, -0.8), Vector2(x + 0.74, -0.8), Vector2(x + 0.32, 0.8)], k if i != 1 else a)
				pen.poly([Vector2(x + 0.2, 0.8), Vector2(x + 0.62, -0.8), Vector2(x + 0.74, -0.8), Vector2(x + 0.32, 0.8)], d)
		"unit":
			_bot_head(pen, k, d, g)
			pen.poly([Vector2(-0.6, -0.14), Vector2(0, 0.08), Vector2(0.6, -0.14), Vector2(0.6, 0.0), Vector2(0, 0.22), Vector2(-0.6, 0.0)], a)
		"scrapper":
			_bot_head(pen, k, d, g)
			pen.poly([Vector2(-0.6, -0.14), Vector2(-0.12, 0.04), Vector2(-0.12, 0.18), Vector2(-0.6, 0.0)], a)
			pen.path([Vector2(0.22, -0.9), Vector2(0.02, -0.55), Vector2(0.3, -0.38), Vector2(0.08, -0.12), Vector2(0.34, 0.2), Vector2(0.2, 0.52)], g, 0.1)
			pen.line(Vector2(0.3, -0.38), Vector2(0.62, -0.5), g, 0.07)
			for p in [[Vector2(0.5, -1.0), Vector2(0.72, -1.2)], [Vector2(0.86, -0.7), Vector2(1.12, -0.78)], [Vector2(0.2, -1.08), Vector2(0.16, -1.28)]]:
				pen.line(p[0], p[1], a, 0.09)   # sparks
		"bolt":
			pen.poly([Vector2(0.34, -1.06), Vector2(-0.68, 0.14), Vector2(-0.1, 0.14), Vector2(-0.42, 1.06), Vector2(0.68, -0.26), Vector2(0.1, -0.26), Vector2(0.56, -1.06)], a)
			pen.poly([Vector2(0.3, -0.92), Vector2(-0.5, 0.06), Vector2(0.02, 0.06), Vector2(-0.24, 0.8), Vector2(0.5, -0.18), Vector2(-0.02, -0.18), Vector2(0.4, -0.92)], k)
		"blitz":
			for i in 3:
				var y := -0.5 + i * 0.5
				pen.poly([Vector2(-1.0 + i * 0.12, y - 0.06), Vector2(-0.2, y - 0.06), Vector2(-0.3, y + 0.06), Vector2(-1.0 + i * 0.12, y + 0.06)], Color(k, 0.6))
			pen.shift = Vector2(0.3, 0)
			pen.poly([Vector2(0.3, -0.92), Vector2(-0.5, 0.06), Vector2(0.02, 0.06), Vector2(-0.24, 0.9), Vector2(0.5, -0.18), Vector2(-0.02, -0.18), Vector2(0.4, -0.92)], k)
			pen.poly([Vector2(0.3, -0.92), Vector2(-0.3, -0.18), Vector2(-0.02, -0.18), Vector2(0.4, -0.92)], a)
			pen.shift = Vector2.ZERO
		"claw":
			for x: float in [-0.56, 0.0, 0.56]:
				pen.poly([Vector2(x - 0.02, -1.0), Vector2(x + 0.3, -0.72), Vector2(x + 0.16, 0.1), Vector2(x - 0.2, 1.0), Vector2(x - 0.16, 0.1)], k)
				pen.poly([Vector2(x + 0.06, -0.7), Vector2(x + 0.2, -0.6), Vector2(x + 0.08, 0.0), Vector2(x - 0.04, 0.3)], a)
		"rounds":
			for x: float in [-0.58, 0.0, 0.58]:
				var top := -0.96 if x == 0.0 else -0.72
				pen.poly([Vector2(x - 0.19, top + 0.5), Vector2(x - 0.17, top + 0.3), Vector2(x, top), Vector2(x + 0.17, top + 0.3), Vector2(x + 0.19, top + 0.5)], a)
				pen.poly([Vector2(x - 0.2, top + 0.54), Vector2(x + 0.2, top + 0.54), Vector2(x + 0.2, 0.8), Vector2(x - 0.2, 0.8)], k)
				pen.poly([Vector2(x + 0.06, top + 0.54), Vector2(x + 0.2, top + 0.54), Vector2(x + 0.2, 0.8), Vector2(x + 0.06, 0.8)], d)
				pen.poly([Vector2(x - 0.24, 0.8), Vector2(x + 0.24, 0.8), Vector2(x + 0.24, 0.94), Vector2(x - 0.24, 0.94)], d)
		"dagger":
			pen.turn = 0.6
			_blade(pen, k, d, a, 0.2)
			pen.turn = 0.0
		"swords":
			for side: float in [-1.0, 1.0]:
				pen.turn = 0.72 * side
				_blade(pen, k, d, a, 0.12)
			pen.turn = 0.0
		"eclipse":
			for i in 16:   # the corona
				var dir := Vector2.from_angle(i * TAU / 16.0)
				pen.poly([dir.rotated(-0.14) * 0.7, dir * (1.12 if i % 2 == 0 else 0.92), dir.rotated(0.14) * 0.7], Color(a, 0.75))
			pen.dot(Vector2.ZERO, 0.78, k)
			pen.dot(Vector2(-0.06, 0.05), 0.68, Color(0.02, 0.02, 0.05))
			pen.arc(Vector2(-0.06, 0.05), 0.5, 2.2, 3.6, Color(1, 1, 1, 0.12), 0.06)
			pen.dot(Vector2(0.5, -0.5), 0.13, Color.WHITE)
		"pulse":
			var beat := [Vector2(-1.05, 0.12), Vector2(-0.6, 0.12), Vector2(-0.44, -0.24), Vector2(-0.26, 0.12), Vector2(-0.1, 0.12), Vector2(0.1, -0.95),
				Vector2(0.3, 0.8), Vector2(0.46, 0.12), Vector2(0.62, 0.12), Vector2(0.72, -0.14), Vector2(0.84, 0.12), Vector2(1.05, 0.12)]
			for y: float in [-0.6, -0.24, 0.48, 0.84]:
				pen.line(Vector2(-1.0, y), Vector2(1.0, y), Color(a, 0.5), 0.04)   # the monitor's grid
			pen.path(beat, Color(a, 0.9), 0.34)
			pen.path(beat, k, 0.15)
		"skull":
			_skull(pen, k, d, a, g)
		"skull_king":
			pen.zoom = 0.82
			pen.shift = Vector2(0, 0.26)
			_skull(pen, k, d, a, g)
			pen.zoom = 1.0
			pen.shift = Vector2.ZERO
			pen.poly([Vector2(-0.6, -0.5), Vector2(-0.7, -1.08), Vector2(-0.32, -0.76), Vector2(0, -1.2), Vector2(0.32, -0.76), Vector2(0.7, -1.08), Vector2(0.6, -0.5)], k)
			pen.poly([Vector2(0, -0.5), Vector2(0, -1.2), Vector2(0.32, -0.76), Vector2(0.7, -1.08), Vector2(0.6, -0.5)], d)
			for x: float in [-0.36, 0.0, 0.36]:
				pen.dot(Vector2(x, -0.62), 0.08, a)
		"headhunter":
			pen.zoom = 0.72
			pen.shift = Vector2(0, 0.04)
			_skull(pen, k, d, a, g)
			pen.zoom = 1.0
			pen.shift = Vector2.ZERO
			pen.arc(Vector2.ZERO, 0.98, 0.0, TAU, a, 0.1)
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				pen.line(dir * 0.72, dir * 1.22, a, 0.12)
		"reticle":
			pen.arc(Vector2.ZERO, 0.94, 0.0, TAU, k, 0.12)
			pen.arc(Vector2.ZERO, 0.4, 0.0, TAU, Color(k, 0.7), 0.05)
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				pen.line(dir * 0.94, dir * 0.1, Color(k, 0.85), 0.05)
				if dir != Vector2.UP:
					pen.line(dir * 0.94, dir * 0.52, k, 0.17)   # the heavy posts
				for n in 2:
					pen.dot(dir * (0.22 + n * 0.15), 0.035, k)
			pen.dot(Vector2.ZERO, 0.1, a)
		"cylinder":
			pen.dot(Vector2.ZERO, 1.0, d)
			pen.dot(Vector2.ZERO, 0.9, k)
			for i in 6:
				var dir := Vector2.from_angle(i * TAU / 6.0 - PI / 2.0)
				pen.dot(Vector2.from_angle(i * TAU / 6.0 - PI / 3.0) * 1.0, 0.16, g)   # the flutes
				pen.dot(dir * 0.55, 0.23, g)
				if i % 2 == 0 or i == 1:
					pen.dot(dir * 0.55, 0.17, a)   # loaded
					pen.dot(dir * 0.55, 0.07, a.darkened(0.4))
			pen.dot(Vector2.ZERO, 0.15, g)
		"grenade":
			pen.poly([Vector2(-0.5, -0.12), Vector2(-0.32, -0.38), Vector2(0.32, -0.38), Vector2(0.5, -0.12), Vector2(0.5, 0.62), Vector2(0.3, 0.95), Vector2(-0.3, 0.95), Vector2(-0.5, 0.62)], k)
			pen.poly([Vector2(0.1, -0.38), Vector2(0.32, -0.38), Vector2(0.5, -0.12), Vector2(0.5, 0.62), Vector2(0.3, 0.95), Vector2(0.1, 0.95)], d)
			for y: float in [-0.02, 0.3, 0.62]:
				pen.line(Vector2(-0.5, y), Vector2(0.5, y), g, 0.06)
			for x: float in [-0.18, 0.16]:
				pen.line(Vector2(x, -0.38), Vector2(x, 0.95), g, 0.06)
			pen.poly([Vector2(-0.22, -0.38), Vector2(0.22, -0.38), Vector2(0.22, -0.66), Vector2(-0.22, -0.66)], a)
			pen.poly([Vector2(0.16, -0.66), Vector2(0.16, -0.84), Vector2(0.66, -0.68), Vector2(0.8, 0.1), Vector2(0.64, 0.1), Vector2(0.54, -0.54)], a.darkened(0.15))
			pen.arc(Vector2(-0.46, -0.74), 0.2, 0.0, TAU, a, 0.08)
		"flame":
			pen.poly([Vector2(0.1, -1.1), Vector2(0.34, -0.5), Vector2(0.66, -0.7), Vector2(0.78, 0.22), Vector2(0.48, 0.86), Vector2(0, 1.05), Vector2(-0.48, 0.86), Vector2(-0.78, 0.28),
				Vector2(-0.56, -0.36), Vector2(-0.32, -0.06), Vector2(-0.24, -0.62)], k)
			pen.poly([Vector2(0.06, -0.46), Vector2(0.44, 0.1), Vector2(0.42, 0.62), Vector2(0, 0.94), Vector2(-0.42, 0.62), Vector2(-0.44, 0.2), Vector2(-0.2, 0.3)], a)
			pen.poly([Vector2(0, 0.12), Vector2(0.22, 0.56), Vector2(0, 0.88), Vector2(-0.22, 0.56)], Color(1.0, 0.96, 0.7))
		"ace":
			var spade := [Vector2(0, -1.05), Vector2(0.78, -0.08), Vector2(0.84, 0.3), Vector2(0.58, 0.6), Vector2(0.22, 0.56), Vector2(0.1, 0.42), Vector2(0.34, 1.0), Vector2(0, 1.0)]
			pen.both(spade, d, k)
			pen.zoom = 0.4
			pen.shift = Vector2(0, -0.02)
			_skull(pen, g, g, a, k)
			pen.zoom = 1.0
			pen.shift = Vector2.ZERO
		"phantom":
			var cloak := [Vector2(0, -1.08), Vector2(0.5, -0.76), Vector2(0.7, -0.16), Vector2(0.62, 0.36), Vector2(0.94, 1.0), Vector2(0.46, 0.76), Vector2(0.22, 1.04), Vector2(0, 0.76)]
			pen.both(cloak, d, k)
			pen.poly([Vector2(0, -0.78), Vector2(0.36, -0.5), Vector2(0.42, 0.0), Vector2(0, 0.4), Vector2(-0.42, 0.0), Vector2(-0.36, -0.5)], g)
			pen.both([Vector2(0.08, -0.14), Vector2(0.3, -0.26), Vector2(0.32, -0.12), Vector2(0.1, -0.02)], a, a)
		"comet":
			pen.poly([Vector2(0.02, -0.6), Vector2(-1.05, 0.5), Vector2(0.0, -0.1)], Color(a, 0.55))
			pen.poly([Vector2(0.6, 0.0), Vector2(-0.5, 1.05), Vector2(0.14, 0.02)], Color(a, 0.55))
			pen.poly([Vector2(0.0, -0.4), Vector2(-1.0, 1.0), Vector2(0.44, 0.02)], a)
			pen.poly([Vector2(0.1, -0.2), Vector2(-0.62, 0.62), Vector2(0.3, -0.02)], Color.WHITE)
			pen.star(Vector2(0.34, -0.3), 0.62, k)
			pen.star(Vector2(0.34, -0.3), 0.26, Color.WHITE)
		"overwatch":
			pen.both([Vector2(0, -1.08), Vector2(1.0, 0.78), Vector2(0, 0.78)], d, k)
			pen.poly([Vector2(0, -0.66), Vector2(0.66, 0.58), Vector2(-0.66, 0.58)], g)
			var lid := []
			for i in 9:
				lid.append(Vector2(-0.5 + i * 0.125, 0.16 - 0.3 * sin(i * PI / 8.0)))
			for i in 9:
				lid.append(Vector2(0.5 - i * 0.125, 0.16 + 0.3 * sin(i * PI / 8.0)))
			pen.poly(lid, k)
			pen.dot(Vector2(0, 0.16), 0.2, a)
			pen.dot(Vector2(0, 0.16), 0.09, g)
			for i in 5:   # light from the peak
				var dir := Vector2.from_angle(-PI / 2.0 + (i - 2) * 0.42)
				pen.line(Vector2(0, -1.08) + dir * 0.12, Vector2(0, -1.08) + dir * 0.3, a, 0.06)
		"wings":
			_wings(pen, k, d)
			pen.poly([Vector2(-0.22, -0.52), Vector2(0.22, -0.52), Vector2(0.22, 0.3), Vector2(0, 0.62), Vector2(-0.22, 0.3)], a)
			pen.poly([Vector2(0, -0.52), Vector2(0.22, -0.52), Vector2(0.22, 0.3), Vector2(0, 0.62)], a.darkened(0.3))
			pen.star(Vector2(0, -0.06), 0.16, g)
		"mach":
			for i in 3:   # the shock cone
				var y := -0.5 + i * 0.5
				pen.path([Vector2(-0.95 + i * 0.1, y + 0.62), Vector2(0, y - 0.42), Vector2(0.95 - i * 0.1, y + 0.62)], Color(a, 0.7 - i * 0.2), 0.08)
			var jet := [Vector2(0, -1.1), Vector2(0.17, -0.3), Vector2(0.82, 0.46), Vector2(0.82, 0.64), Vector2(0.2, 0.46), Vector2(0.3, 0.92), Vector2(0, 0.8)]
			pen.both(jet, d, k)
			pen.poly([Vector2(0, -0.66), Vector2(0.08, -0.3), Vector2(-0.08, -0.3)], g)
		"hook":
			pen.path([Vector2(0, 0.9), Vector2(0.3, 1.08), Vector2(0.6, 0.86), Vector2(0.95, 1.05)], a, 0.1)   # the rope
			pen.poly([Vector2(-0.08, -0.3), Vector2(0.08, -0.3), Vector2(0.08, 0.72), Vector2(-0.08, 0.72)], k)
			pen.arc(Vector2(0, 0.86), 0.15, 0.0, TAU, k, 0.09)
			pen.poly([Vector2(-0.12, -0.3), Vector2(0, -1.08), Vector2(0.12, -0.3)], k)
			for side: float in [-1.0, 1.0]:
				pen.arc(Vector2(0.4 * side, -0.28), 0.4, PI, TAU, k if side < 0.0 else d, 0.19)
				pen.poly([Vector2(0.64 * side, -0.3), Vector2(0.96 * side, -0.3), Vector2(0.82 * side, 0.2)], k if side < 0.0 else d)
			pen.poly([Vector2(-0.2, 0.1), Vector2(0.2, 0.1), Vector2(0.2, 0.26), Vector2(-0.2, 0.26)], d)
		"boot":
			pen.turn = -0.3
			pen.poly([Vector2(-0.58, -0.98), Vector2(0.02, -0.98), Vector2(0.06, -0.1), Vector2(0.74, 0.14), Vector2(0.92, 0.46), Vector2(0.92, 0.66), Vector2(-0.58, 0.66)], k)
			pen.poly([Vector2(0.46, 0.24), Vector2(0.74, 0.14), Vector2(0.92, 0.46), Vector2(0.92, 0.66), Vector2(0.46, 0.66)], a)
			pen.poly([Vector2(-0.64, 0.66), Vector2(0.96, 0.66), Vector2(0.96, 0.88), Vector2(0.2, 0.88), Vector2(0.14, 0.78), Vector2(-0.2, 0.78), Vector2(-0.26, 0.88), Vector2(-0.64, 0.88)], k.darkened(0.55))
			pen.poly([Vector2(-0.58, -0.98), Vector2(0.02, -0.98), Vector2(0.02, -0.8), Vector2(-0.58, -0.8)], k.lightened(0.25))
			for y: float in [-0.6, -0.36, -0.12]:
				pen.line(Vector2(-0.18, y), Vector2(0.06, y + 0.06), a, 0.06)
			pen.turn = 0.0
			for i in 3:   # the hit
				var dir := Vector2.from_angle(-0.5 + i * 0.5)
				pen.line(Vector2(0.72, 0.1) + dir * 0.22, Vector2(0.72, 0.1) + dir * 0.5, a, 0.08)
		"rec":
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					pen.path([Vector2(0.92 * sx, 0.44 * sy), Vector2(0.92 * sx, 0.84 * sy), Vector2(0.48 * sx, 0.84 * sy)], k, 0.11)
			pen.line(Vector2(-0.16, 0.14), Vector2(0.16, 0.14), Color(k, 0.8), 0.05)
			pen.line(Vector2(0, -0.02), Vector2(0, 0.3), Color(k, 0.8), 0.05)
			pen.dot(Vector2(-0.52, -0.46), 0.2, a)
			for i in 3:   # "REC"
				pen.poly([Vector2(-0.2 + i * 0.28, -0.6), Vector2(0.0 + i * 0.28, -0.6), Vector2(0.0 + i * 0.28, -0.32), Vector2(-0.2 + i * 0.28, -0.32)], k)
			for i in 5:   # the tape counter
				pen.line(Vector2(-0.6 + i * 0.3, 0.56), Vector2(-0.6 + i * 0.3, 0.68), Color(k, 0.7), 0.05)
		"c4":
			pen.path([Vector2(-0.4, -0.6), Vector2(-0.8, -0.72), Vector2(-0.74, -0.2)], Color(0.3, 0.6, 1.0), 0.09)
			pen.path([Vector2(0.4, -0.6), Vector2(0.8, -0.72), Vector2(0.74, -0.2)], a, 0.09)
			pen.poly([Vector2(-0.92, -0.22), Vector2(0.92, -0.22), Vector2(0.92, 0.86), Vector2(-0.92, 0.86)], k)
			pen.poly([Vector2(-0.92, 0.5), Vector2(0.92, 0.5), Vector2(0.92, 0.86), Vector2(-0.92, 0.86)], d)
			for x: float in [-0.56, 0.42]:
				pen.poly([Vector2(x, -0.22), Vector2(x + 0.16, -0.22), Vector2(x + 0.16, 0.86), Vector2(x, 0.86)], g)
			pen.poly([Vector2(-0.46, -0.9), Vector2(0.46, -0.9), Vector2(0.46, -0.3), Vector2(-0.46, -0.3)], g.lightened(0.1))
			pen.poly([Vector2(-0.38, -0.82), Vector2(0.38, -0.82), Vector2(0.38, -0.38), Vector2(-0.38, -0.38)], Color(0.05, 0.02, 0.02))
			for x: float in [-0.28, -0.1, 0.12, 0.3]:
				pen.line(Vector2(x, -0.74), Vector2(x, -0.46), a, 0.08)
			pen.dot(Vector2(0.01, -0.68), 0.035, a)
			pen.dot(Vector2(0.01, -0.52), 0.035, a)
		"defuser":
			pen.line(Vector2(-1.0, -0.62), Vector2(-0.2, -0.62), Color(0.95, 0.2, 0.15), 0.12)
			pen.line(Vector2(0.2, -0.62), Vector2(1.0, -0.62), Color(0.95, 0.2, 0.15), 0.12)
			for side: float in [-1.0, 1.0]:
				pen.line(Vector2(0.46 * side, 1.0), Vector2(-0.16 * side, -0.2), a, 0.24)   # a grip
				pen.poly([Vector2(-0.3 * side, -0.02), Vector2(-0.04 * side, -0.14), Vector2(0.02 * side, -0.86), Vector2(-0.16 * side, -0.62)], k if side < 0.0 else d)
			pen.dot(Vector2(0, 0.08), 0.13, k)
			pen.dot(Vector2(0, 0.08), 0.05, g)
			for dir in [Vector2(-0.5, -1.0), Vector2(0.0, -1.0), Vector2(0.5, -1.0)]:   # the snip
				pen.line(Vector2(0, -0.78) + dir * 0.16, Vector2(0, -0.78) + dir * 0.36, Color.WHITE, 0.06)
		"flag":
			pen.line(Vector2(-0.72, -1.05), Vector2(-0.72, 1.05), a.darkened(0.25), 0.12)
			pen.dot(Vector2(-0.72, -1.05), 0.1, a)
			pen.poly([Vector2(-0.66, -0.92), Vector2(-0.14, -0.76), Vector2(0.38, -0.94), Vector2(0.98, -0.72), Vector2(0.7, -0.46), Vector2(0.94, -0.2), Vector2(0.62, -0.1),
				Vector2(0.86, 0.14), Vector2(0.38, 0.04), Vector2(-0.14, 0.22), Vector2(-0.66, 0.06)], k)
			pen.poly([Vector2(-0.14, -0.76), Vector2(0.38, -0.94), Vector2(0.38, 0.04), Vector2(-0.14, 0.22)], d)
			pen.poly([Vector2(-0.66, -0.52), Vector2(-0.14, -0.36), Vector2(0.38, -0.54), Vector2(0.74, -0.42), Vector2(0.7, -0.34), Vector2(0.38, -0.36), Vector2(-0.14, -0.18), Vector2(-0.66, -0.34)], a)
		"stopwatch":
			pen.poly([Vector2(-0.14, -1.08), Vector2(0.14, -1.08), Vector2(0.14, -0.7), Vector2(-0.14, -0.7)], k)
			pen.line(Vector2(0.52, -0.56), Vector2(0.72, -0.78), k, 0.16)
			pen.dot(Vector2(0, 0.14), 0.86, k)
			pen.dot(Vector2(0, 0.14), 0.7, g)
			var pie := [Vector2(0, 0.14)]
			for i in 9:
				pie.append(Vector2(0, 0.14) + Vector2.from_angle(-PI / 2.0 + i * 0.26) * 0.62)
			pen.poly(pie, Color(a, 0.75))
			for i in 12:
				var dir := Vector2.from_angle(i * TAU / 12.0)
				pen.line(Vector2(0, 0.14) + dir * (0.5 if i % 3 == 0 else 0.56), Vector2(0, 0.14) + dir * 0.64, k, 0.05)
			pen.line(Vector2(0, 0.14), Vector2(0, 0.14) + Vector2.from_angle(-PI / 2.0 + 2.08) * 0.52, Color.WHITE, 0.08)
			pen.dot(Vector2(0, 0.14), 0.09, Color.WHITE)
		"medal":
			pen.poly([Vector2(-0.62, -1.08), Vector2(-0.2, -1.08), Vector2(0.16, -0.2), Vector2(-0.24, -0.06)], a)
			pen.poly([Vector2(0.62, -1.08), Vector2(0.2, -1.08), Vector2(-0.16, -0.2), Vector2(0.24, -0.06)], a.darkened(0.3))
			pen.poly([Vector2(-0.5, -1.08), Vector2(-0.36, -1.08), Vector2(0.0, -0.18), Vector2(-0.12, -0.12)], Color.WHITE)
			pen.star(Vector2(0, 0.38), 0.7, d, 12, 0.84)
			pen.dot(Vector2(0, 0.38), 0.52, k)
			pen.dot(Vector2(0, 0.38), 0.4, d)
			pen.star(Vector2(0, 0.38), 0.32, l)
		"signal":
			for i in 3:
				for side: float in [0.0, PI]:
					pen.arc(Vector2(0, -0.42), 0.36 + i * 0.3, side - 0.7, side + 0.7, Color(a, 1.0 - i * 0.25), 0.1)
			pen.line(Vector2(0, -0.42), Vector2(-0.46, 1.0), k, 0.1)
			pen.line(Vector2(0, -0.42), Vector2(0.46, 1.0), d, 0.1)
			for i in 3:
				var y := 0.0 + i * 0.36
				var wide := (y + 0.42) * 0.32
				pen.line(Vector2(-wide, y), Vector2(wide + 0.11, y + 0.36), k, 0.06)
				pen.line(Vector2(wide, y), Vector2(-wide - 0.11, y + 0.36), d, 0.06)
			pen.dot(Vector2(0, -0.42), 0.15, a)
		"boomerang":
			pen.arc(Vector2(0, 0.1), 1.0, -2.6, -0.6, Color(a, 0.5), 0.06)   # where it has been
			pen.arc(Vector2(0, 0.1), 0.74, -2.3, -0.9, Color(a, 0.35), 0.05)
			pen.turn = 0.5
			var arm := [Vector2(0, -0.82), Vector2(1.02, 0.42), Vector2(0.94, 0.76), Vector2(0.62, 0.7), Vector2(0, -0.2)]
			pen.both(arm, d, k)
			pen.both([Vector2(0.56, 0.2), Vector2(0.76, 0.1), Vector2(0.88, 0.26), Vector2(0.66, 0.4)], a, a)
			pen.turn = 0.0
		"diamond":
			pen.poly([Vector2(-0.56, -0.72), Vector2(0.56, -0.72), Vector2(0.4, -0.2), Vector2(-0.4, -0.2)], l)
			pen.poly([Vector2(-0.56, -0.72), Vector2(-0.4, -0.2), Vector2(-1.04, -0.2)], k)
			pen.poly([Vector2(0.56, -0.72), Vector2(0.4, -0.2), Vector2(1.04, -0.2)], d)
			pen.poly([Vector2(-1.04, -0.2), Vector2(-0.4, -0.2), Vector2(0, 1.0)], k)
			pen.poly([Vector2(-0.4, -0.2), Vector2(0.4, -0.2), Vector2(0, 1.0)], l.lightened(0.3))
			pen.poly([Vector2(0.4, -0.2), Vector2(1.04, -0.2), Vector2(0, 1.0)], d)
			pen.star(Vector2(0.62, -0.82), 0.34, a, 4, 0.22)
		"laurels":
			for side: float in [-1.0, 1.0]:
				pen.arc(Vector2.ZERO, 0.8, PI / 2.0 - 1.36 * (1.0 + side), PI / 2.0 + 1.36 * (1.0 - side), d, 0.05)   # the stem
				for i in 7:
					var ang := PI / 2.0 - 0.16 - i * 0.36
					var p := Vector2(cos(ang) * side, sin(ang)) * 0.84
					var t := Vector2(sin(ang) * side, -cos(ang)).rotated(-0.7 * side)   # along the leaf: up and out
					var n := t.orthogonal()
					pen.poly([p - t * 0.1, p + n * 0.12, p + t * 0.36, p - n * 0.12], k if i % 2 == 0 else d)
			pen.star(Vector2(0, -0.02), 0.5, a)
			pen.star(Vector2(0, -0.02), 0.22, k)
		"crown":
			pen.zoom = 0.86
			pen.poly([Vector2(-0.82, 0.4), Vector2(-1.0, -0.6), Vector2(-0.46, -0.08), Vector2(0, -0.98), Vector2(0.46, -0.08), Vector2(1.0, -0.6), Vector2(0.82, 0.4)], k)
			pen.poly([Vector2(0, 0.4), Vector2(0, -0.98), Vector2(0.46, -0.08), Vector2(1.0, -0.6), Vector2(0.82, 0.4)], d)
			pen.poly([Vector2(-0.84, 0.46), Vector2(0.84, 0.46), Vector2(0.84, 0.8), Vector2(-0.84, 0.8)], l)
			pen.poly([Vector2(0, 0.46), Vector2(0.84, 0.46), Vector2(0.84, 0.8), Vector2(0, 0.8)], k)
			for x: float in [-0.5, 0.0, 0.5]:
				pen.dot(Vector2(x, 0.63), 0.1, a)
			for p in [Vector2(-1.0, -0.6), Vector2(0, -0.98), Vector2(1.0, -0.6)]:
				pen.dot(p, 0.12, l)
			pen.zoom = 1.0
		_:
			pen.dot(Vector2.ZERO, 0.5, k)


## A rank chevron, its point at the top, `y` its point's height.
static func _chevron(pen: Pen, y: float, thick: float, k: Color, d: Color) -> void:
	pen.poly([Vector2(-0.84, y + 0.52), Vector2(0, y), Vector2(0, y + thick), Vector2(-0.84, y + 0.52 + thick)], k)
	pen.poly([Vector2(0.84, y + 0.52), Vector2(0, y), Vector2(0, y + thick), Vector2(0.84, y + 0.52 + thick)], d)


## A robot's head with a V of a visor (dark: the caller lights it).
static func _bot_head(pen: Pen, k: Color, d: Color, g: Color) -> void:
	var half := [Vector2(0, -0.92), Vector2(0.56, -0.92), Vector2(0.86, -0.46), Vector2(0.86, 0.26), Vector2(0.5, 0.92), Vector2(0, 0.92)]
	pen.both(half, d, k)
	pen.poly([Vector2(-0.72, -0.28), Vector2(0, -0.04), Vector2(0.72, -0.28), Vector2(0.72, 0.08), Vector2(0, 0.34), Vector2(-0.72, 0.08)], g)
	for y: float in [0.58, 0.74]:
		pen.line(Vector2(-0.22, y), Vector2(0.22, y), g, 0.06)
	pen.line(Vector2(-0.56, -0.92), Vector2(-0.7, -1.16), k, 0.08)


## A blade, point up, with a guard and a grip (`half`: half the blade's width).
static func _blade(pen: Pen, k: Color, d: Color, a: Color, half: float) -> void:
	pen.poly([Vector2(0, -1.12), Vector2(-half, -0.8), Vector2(-half, 0.3), Vector2(0, 0.3)], k)
	pen.poly([Vector2(0, -1.12), Vector2(half, -0.8), Vector2(half, 0.3), Vector2(0, 0.3)], d)
	pen.poly([Vector2(-half - 0.26, 0.3), Vector2(half + 0.26, 0.3), Vector2(half + 0.2, 0.44), Vector2(-half - 0.2, 0.44)], a)
	pen.poly([Vector2(-half * 0.7, 0.44), Vector2(half * 0.7, 0.44), Vector2(half * 0.7, 0.96), Vector2(-half * 0.7, 0.96)], a.darkened(0.45))
	pen.dot(Vector2(0, 1.02), half * 0.9, a)


## A skull, all angles: `a` glows in its eyes.
static func _skull(pen: Pen, k: Color, d: Color, a: Color, g: Color) -> void:
	var half := [Vector2(0, -1.0), Vector2(0.46, -0.84), Vector2(0.66, -0.36), Vector2(0.58, 0.14), Vector2(0.36, 0.3), Vector2(0.32, 0.84), Vector2(0, 0.84)]
	pen.both(half, d, k)
	pen.both([Vector2(0.12, -0.1), Vector2(0.52, -0.26), Vector2(0.44, 0.14), Vector2(0.14, 0.18)], g, g)
	pen.both([Vector2(0.22, -0.02), Vector2(0.4, -0.1), Vector2(0.36, 0.06), Vector2(0.24, 0.08)], a, a)
	pen.poly([Vector2(0, 0.14), Vector2(0.1, 0.38), Vector2(-0.1, 0.38)], g)
	for x: float in [-0.16, 0.0, 0.16]:
		pen.line(Vector2(x, 0.56), Vector2(x, 0.84), g, 0.06)
	pen.line(Vector2(-0.32, 0.54), Vector2(0.32, 0.54), g, 0.05)


## A pair of wings spread from the middle: three rows of feathers a side.
static func _wings(pen: Pen, k: Color, d: Color) -> void:
	var rows := [[Vector2(0.14, -0.3), Vector2(1.08, -0.7), Vector2(0.98, -0.32), Vector2(0.2, -0.04)],
		[Vector2(0.14, -0.04), Vector2(0.94, -0.28), Vector2(0.82, 0.04), Vector2(0.2, 0.2)],
		[Vector2(0.14, 0.2), Vector2(0.76, 0.08), Vector2(0.6, 0.38), Vector2(0.2, 0.42)]]
	for i in 3:
		pen.both(rows[i], d if i != 1 else k, k if i != 1 else d)
