class_name SiteKit
extends MapLayout
## Building blocks for construction-site maps: floor plates with holes, columns,
## stairs, girders, lattice masts, a tower crane, containers, scaffolding and props.
##
## Each block adds what you collide with (a few plain boxes) and what you see (the
## same boxes, or finer drawn-only pieces over a hidden collision box). Anything you
## can stand on, hide behind or hook is solid; thin tubes and rods are drawn only.

const CONTAINER_W := 2.4
const CONTAINER_H := 2.6

const COLORS := {
	"dirt": Color(0.72, 0.58, 0.41),
	"dirt_dark": Color(0.58, 0.46, 0.33),
	"gravel": Color(0.66, 0.64, 0.60),
	"concrete": Color(0.80, 0.80, 0.78),
	"concrete_dark": Color(0.60, 0.62, 0.64),
	"block": Color(0.70, 0.70, 0.69),
	"rebar": Color(0.42, 0.24, 0.18),
	"steel": Color(0.78, 0.33, 0.23),
	"crane": Color(0.97, 0.76, 0.16),
	"plank": Color(0.80, 0.62, 0.38),
	"ply": Color(0.88, 0.74, 0.50),
	"bag": Color(0.83, 0.80, 0.72),
	"pipe": Color(0.72, 0.73, 0.74),
	"scaffold": Color(0.56, 0.62, 0.68),
	"stair": Color(0.38, 0.42, 0.48),
	"stair_side": Color(0.97, 0.76, 0.16),
	"hoarding": Color(0.24, 0.47, 0.72),
	"hoarding_trim": Color(0.93, 0.93, 0.90),
	"hoarding_base": Color(0.18, 0.36, 0.58),
	"barrier": Color(0.96, 0.48, 0.14),
	"box_blue": Color(0.20, 0.46, 0.72),
	"box_red": Color(0.76, 0.27, 0.22),
	"box_green": Color(0.27, 0.58, 0.44),
	"box_white": Color(0.92, 0.92, 0.90),
	"box_orange": Color(0.90, 0.52, 0.18),
	"silo": Color(0.86, 0.87, 0.88),
	"machine": Color(0.96, 0.66, 0.12),
	"machine_dark": Color(0.26, 0.28, 0.32),
	"rubber": Color(0.13, 0.14, 0.16),
	"glass": Color(0.30, 0.52, 0.62),
	"cable": Color(0.12, 0.13, 0.15),
	"weight": Color(0.46, 0.48, 0.52),
	"lamp": Color(1.0, 0.97, 0.85),
	"backdrop": Color(0.62, 0.70, 0.80),
	"street": Color(0.50, 0.50, 0.50),
}

## Time of day and palette. "look" holds MapScenery look keys; "colors" replaces
## entries of COLORS.
const LOOKS := {
	"midday": {
		"label": "Clear midday",
		"look": {
			"sky_top": Color(0.22, 0.48, 0.86),
			"sky_horizon": Color(0.78, 0.88, 0.96),
			"ground_horizon": Color(0.80, 0.80, 0.78),
			"ground_bottom": Color(0.74, 0.74, 0.72),
			"ambient_color": Color(0.70, 0.77, 0.92),
			"ambient_energy": 0.55,
			"sun_angles": Vector3(-58, -150, 0),
			"sun_energy": 0.9,
			"tonemap": "filmic",
			"white": 2.6,
			"sun_color": Color(1.0, 0.96, 0.88),
			"shadow_distance": 220.0,
		},
	},
	"golden": {
		"label": "Golden hour",
		"look": {
			"sky_top": Color(0.24, 0.36, 0.66),
			"sky_horizon": Color(1.0, 0.74, 0.50),
			"ground_horizon": Color(0.92, 0.68, 0.50),
			"ground_bottom": Color(0.62, 0.47, 0.40),
			"ambient_color": Color(0.52, 0.52, 0.76),
			"ambient_energy": 0.75,
			"sun_angles": Vector3(-17, -128, 0),
			"sun_energy": 1.7,
			"sun_color": Color(1.0, 0.68, 0.40),
			"shadow_distance": 260.0,
			"fog_color": Color(1.0, 0.76, 0.56),
			"fog_density": 0.0012,
			"tonemap": "filmic",
			"white": 2.4,
		},
	},
	"dusk": {
		"label": "Dusk under floodlights",
		"look": {
			"sky_top": Color(0.05, 0.07, 0.20),
			"sky_horizon": Color(0.86, 0.45, 0.42),
			"ground_horizon": Color(0.36, 0.26, 0.36),
			"ground_bottom": Color(0.10, 0.10, 0.16),
			"ambient_color": Color(0.30, 0.32, 0.52),
			"ambient_energy": 0.7,
			"sun_angles": Vector3(-34, -150, 0),   # the "sun" is the floodlights' glare
			"sun_energy": 0.8,
			"sun_color": Color(1.0, 0.90, 0.74),
			"tonemap": "filmic",
			"white": 1.6,
			"shadow_distance": 220.0,
			"fog_color": Color(0.20, 0.20, 0.36),
			"fog_density": 0.002,
			"lamps": true,
			"glow": {"lamp": 4.0},
		},
		"colors": {
			"backdrop": Color(0.20, 0.21, 0.30),
			"street": Color(0.36, 0.36, 0.42),
			"hoarding": Color(0.22, 0.36, 0.56),
			"hoarding_base": Color(0.16, 0.27, 0.44),
		},
	},
	"mist": {
		"label": "Misty morning, muted palette",
		"look": {
			"sky_top": Color(0.62, 0.70, 0.80),
			"sky_horizon": Color(0.90, 0.90, 0.88),
			"ground_horizon": Color(0.86, 0.86, 0.84),
			"ground_bottom": Color(0.72, 0.72, 0.72),
			"ambient_color": Color(0.88, 0.90, 0.94),
			"ambient_energy": 0.95,
			"sun_angles": Vector3(-48, -150, 0),
			"sun_energy": 0.8,
			"sun_color": Color(1.0, 0.97, 0.92),
			"shadow_opacity": 0.55,
			"shadow_distance": 220.0,
			"fog_color": Color(0.88, 0.90, 0.92),
			"fog_density": 0.0045,
		},
		"colors": {
			"hoarding": Color(0.27, 0.50, 0.43),
			"hoarding_base": Color(0.19, 0.38, 0.33),
			"steel": Color(0.36, 0.50, 0.58),
			"crane": Color(0.92, 0.50, 0.20),
			"stair_side": Color(0.92, 0.50, 0.20),
			"machine": Color(0.90, 0.70, 0.24),
			"barrier": Color(0.90, 0.36, 0.22),
			"dirt": Color(0.70, 0.62, 0.52),
			"backdrop": Color(0.80, 0.83, 0.86),
		},
	},
}

var look_name := "midday"

var _rng := RandomNumberGenerator.new()
var _plates: Array = []   # [top, Rect2] of every floor plate, for floor_at()


func _init() -> void:
	_rng.seed = 20261116   # the same map every time


func kind_colors() -> Dictionary:
	var colors := COLORS.duplicate()
	colors.merge(LOOKS[look_name].get("colors", {}), true)
	return colors


func look() -> Dictionary:
	return LOOKS[look_name].look


func face_shade() -> Vector3:
	return Vector3(0.93, 0.84, 0.66)


# ---------------------------------------------------------------------------
# Small helpers

## Solid, but not drawn (finer pieces are drawn over it).
func _hide(piece: Dictionary) -> Dictionary:
	piece["hidden"] = true
	return piece


## Makes a piece a little lighter or darker than its neighbours.
func _vary(piece: Dictionary, amount: float = 0.06) -> Dictionary:
	var v := 1.0 + _rng.randf_range(-amount, amount * 0.5)
	piece["tint"] = Color(v, v, v)
	return piece


func _shade(piece: Dictionary, v: float) -> Dictionary:
	piece["tint"] = Color(v, v, v)
	return piece


## A box turned by `yaw` (radians) around the vertical; `center` is its middle.
func _obox(center: Vector3, size: Vector3, yaw: float, kind: String, solid: bool = true) -> Dictionary:
	return _add(Transform3D(Basis(Vector3.UP, yaw), center), size, kind, solid, "box")


## A box in the frame of something standing at `origin` and turned by `yaw`:
## `offset` (its centre) and `size` are given as if the thing faced along -z.
func _part(origin: Vector3, yaw: float, offset: Vector3, size: Vector3, kind: String, solid: bool = true) -> Dictionary:
	var basis := Basis(Vector3.UP, yaw)
	return _add(Transform3D(basis, origin + basis * offset), size, kind, solid, "box")


## A cylinder lying between two points.
func _rod(a: Vector3, b: Vector3, radius: float, kind: String, solid: bool = false, sides: int = 8) -> Dictionary:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var basis := Basis(side, dir, side.cross(dir).normalized())
	var piece := _add(Transform3D(basis, (a + b) * 0.5), Vector3(radius * 2.0, a.distance_to(b), radius * 2.0), kind, solid, "cyl")
	piece["sides"] = sides
	return piece


## A box whose long (z) axis points along `dir` (flat), centred on `center`.
func _span_on(center: Vector3, dir: Vector3, size: Vector3, kind: String, solid: bool = true) -> Dictionary:
	return _add(Transform3D(Basis.looking_at(dir, Vector3.UP), center), size, kind, solid, "box")


# ---------------------------------------------------------------------------
# Structure

## A floor plate with its top at `top`: the area of `rects` minus `holes` (Rect2 of
## x, z, width, depth). Cut into as few boxes as the holes allow.
func plate(top: float, rects: Array, holes: Array = [], kind: String = "concrete", thickness: float = 0.4) -> void:
	var xs := {}
	var zs := {}
	for r: Rect2 in rects + holes:
		xs[r.position.x] = true
		xs[r.end.x] = true
		zs[r.position.y] = true
		zs[r.end.y] = true
	var xl := xs.keys()
	var zl := zs.keys()
	xl.sort()
	zl.sort()
	var filled := func(x: float, z: float) -> bool:
		var p := Vector2(x, z)
		for h: Rect2 in holes:
			if h.has_point(p):
				return false
		for r: Rect2 in rects:
			if r.has_point(p):
				return true
		return false
	# Strips along x for each z band, then join equal strips of neighbouring bands.
	var strips: Array = []   # [x0, x1, z0, z1]
	for j in zl.size() - 1:
		var start := -1
		for i in xl.size():
			var inside: bool = i < xl.size() - 1 and filled.call((xl[i] + xl[i + 1]) * 0.5, (zl[j] + zl[j + 1]) * 0.5)
			if inside and start < 0:
				start = i
			elif not inside and start >= 0:
				var strip := [xl[start], xl[i], zl[j], zl[j + 1]]
				var joined := false
				for s in strips:
					if s[0] == strip[0] and s[1] == strip[1] and s[3] == strip[2]:
						s[3] = strip[3]
						joined = true
						break
				if not joined:
					strips.append(strip)
				start = -1
	for s in strips:
		_span(s[0], s[1], top - thickness, top, s[2], s[3], kind)
		_plates.append([top, Rect2(s[0], s[2], s[1] - s[0], s[3] - s[2])])


## The height of the highest floor plate over this spot (0 = just the ground).
func floor_at(x: float, z: float) -> float:
	var best := 0.0
	for p in _plates:
		if (p[1] as Rect2).has_point(Vector2(x, z)):
			best = maxf(best, p[0])
	return best


## A concrete column. With `stub`, bare reinforcing bars stick out of its top.
func column(x: float, z: float, y0: float, y1: float, width: float = 0.9, stub: bool = false) -> void:
	_span(x - width * 0.5, x + width * 0.5, y0, y1, z - width * 0.5, z + width * 0.5, "concrete")
	if stub:
		var w := width * 0.3
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var h := _rng.randf_range(0.7, 1.3)
				_box(Vector3(x + sx * w, y1 + h * 0.5, z + sz * w), Vector3(0.07, h, 0.07), "rebar", false)


## A steel column (an H section).
func steel_column(x: float, z: float, y0: float, y1: float, width: float = 0.5) -> void:
	_hide(_span(x - width * 0.5, x + width * 0.5, y0, y1, z - width * 0.5, z + width * 0.5, "steel"))
	var mid := (y0 + y1) * 0.5
	var h := y1 - y0
	for s in [-1, 1]:
		_box(Vector3(x, mid, z + s * (width * 0.5 - 0.05)), Vector3(width, h, 0.1), "steel", false)
	_box(Vector3(x, mid, z), Vector3(0.1, h, width - 0.2), "steel", false)


## A steel girder (an I section) between two points on its top face.
func girder(a: Vector3, b: Vector3, width: float = 0.6, depth: float = 0.8, kind: String = "steel") -> void:
	_hide(_slab(a, b, width, depth, kind))
	_slab(a, b, width, 0.12, kind, false)
	var drop := Vector3(0, depth - 0.12, 0)
	_slab(a - drop, b - drop, width, 0.12, kind, false)
	var web := Vector3(0, 0.12, 0)
	_slab(a - web, b - web, 0.12, depth - 0.24, kind, false)


## Stairs from `low` to `high` (centres of the walking surface at each end). You walk
## on a smooth ramp; the steps are only drawn.
const RAMP_BASE := 2.3   ## stairs and ramps are closed in underneath until they are this high

## Closes in the low end of a ramp from `low` to `high` underneath, up to where
## you can stand under it, so nobody gets wedged in the gap (bots included).
func ramp_base(low: Vector3, high: Vector3, width: float, kind: String) -> void:
	var flat := Vector3(high.x - low.x, 0, high.z - low.z)
	var run := flat.length()
	var dir := flat / run
	var rise := high.y - low.y
	var yaw := atan2(-dir.x, -dir.z)
	var base_run := minf(RAMP_BASE / rise, 1.0) * run
	var blocks: int = max(int(ceil(base_run / 0.5)), 1)
	for i in blocks:
		var from := base_run * i / blocks
		var to := base_run * (i + 1) / blocks
		var top := rise * from / run - 0.02
		if top < 0.1:
			continue
		_obox(low + dir * (from + to) * 0.5 + Vector3(0, top * 0.5, 0), Vector3(width, top, to - from), yaw, kind)


func stair(low: Vector3, high: Vector3, width: float = 3.0, rail_side: int = 0) -> void:
	_hide(_slab(low, high, width, 0.3, "stair"))
	var flat := Vector3(high.x - low.x, 0, high.z - low.z)
	var run := flat.length()
	var dir := flat / run
	var side := dir.cross(Vector3.UP)
	var rise := high.y - low.y
	var count: int = max(int(round(rise / 0.2)), 1)
	var yaw := atan2(-dir.x, -dir.z)
	ramp_base(low, high, width - 0.02, "concrete_dark")
	for i in count:
		var along := (i + 0.5) / count
		var pos := low + dir * run * along + Vector3(0, rise * (i + 1) / count - 0.04, 0)
		_obox(pos, Vector3(width - 0.16, 0.08, run / count * 0.92), yaw, "stair", false)
	for s in [-1, 1]:
		var off: Vector3 = side * s * (width * 0.5 - 0.06)
		_strut(low + off + Vector3(0, -0.12, 0), high + off + Vector3(0, -0.12, 0), 0.12, 0.34, "stair_side", false)
	# A guard panel along one side (-1 left, 1 right, looking up the stairs) where the
	# stairs run along an open edge
	if rail_side != 0:
		var off: Vector3 = side * rail_side * (width * 0.5 - 0.06) + Vector3(0, 0.5, 0)
		_strut(low + off, high + off, 0.1, 1.0, "barrier")


## A lattice truss (crane mast, jib, light mast) between two points on its centre
## line: four corner bars and zigzag bracing, over one solid box.
func lattice(a: Vector3, b: Vector3, width: float, height: float, kind: String, bar: float = 0.16, solid: bool = true) -> void:
	if solid:
		_hide(_strut(a, b, width, height, kind))
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	var hx := basis.x * (width * 0.5 - bar * 0.5)
	var hy := basis.y * (height * 0.5 - bar * 0.5)
	var corners := [hx + hy, -hx + hy, -hx - hy, hx - hy]
	for c in corners:
		_strut(a + c, b + c, bar, bar, kind, false)
	var length := a.distance_to(b)
	var bays: int = max(int(round(length / maxf(width, height))), 1)
	for i in bays:
		var p0 := a + dir * length * i / bays
		var p1 := a + dir * length * (i + 1) / bays
		for f in 4:
			var c0: Vector3 = corners[f]
			var c1: Vector3 = corners[(f + 1) % 4]
			if (i + f) % 2 == 0:
				_strut(p0 + c0, p1 + c1, bar * 0.6, bar * 0.6, kind, false)
			else:
				_strut(p0 + c1, p1 + c0, bar * 0.6, bar * 0.6, kind, false)


## A wall of concrete blocks, `thick` wide, from (x0, z0) to (x1, z1) along x or z.
func block_wall(x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, thick: float = 0.3) -> void:
	if absf(x1 - x0) > absf(z1 - z0):
		_span(x0, x1, y0, y1, z0 - thick * 0.5, z0 + thick * 0.5, "block")
	else:
		_span(x0 - thick * 0.5, x0 + thick * 0.5, y0, y1, z0, z1, "block")


## Orange edge protection: a solid panel 1 m high between two points at floor level.
func barrier(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5 + Vector3(0, 0.55, 0)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var yaw := atan2(-flat.x, -flat.z)
	_obox(mid, Vector3(0.1, 0.9, flat.length()), yaw, "barrier")
	for p in [a, b]:
		_box(p + Vector3(0, 0.55, 0), Vector3(0.14, 1.1, 0.14), "scaffold", false)


## A concrete road barrier, 0.8 m high: cover you can vault.
func jersey(center: Vector3, length: float, yaw: float = 0.0) -> void:
	_hide(_obox(center + Vector3(0, 0.4, 0), Vector3(0.6, 0.8, length), yaw, "concrete_dark"))
	_obox(center + Vector3(0, 0.15, 0), Vector3(0.6, 0.3, length), yaw, "concrete_dark", false)
	_obox(center + Vector3(0, 0.55, 0), Vector3(0.3, 0.5, length), yaw, "concrete_dark", false)


# ---------------------------------------------------------------------------
# Site furniture

## A shipping container standing on `base` (centre of its footprint), `length`
## metres long along x, or along z when `turned`.
func container(base: Vector3, kind: String, turned: bool = false, length: float = 12.0) -> void:
	var yaw := 0.0 if turned else PI * 0.5
	var c := base + Vector3(0, CONTAINER_H * 0.5, 0)
	_obox(c, Vector3(CONTAINER_W, CONTAINER_H, length), yaw, kind)
	# Corrugation ribs on the long sides, a frame, and door bars at one end
	var ribs := int(length / 0.6)
	for i in ribs:
		var along := -length * 0.5 + (i + 0.5) * length / ribs
		for s in [-1, 1]:
			_shade(_part(base, yaw, Vector3(s * (CONTAINER_W * 0.5 + 0.02), CONTAINER_H * 0.5, along),
				Vector3(0.06, CONTAINER_H - 0.4, 0.22), kind, false), 0.88)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_shade(_part(base, yaw, Vector3(sx * CONTAINER_W * 0.5, CONTAINER_H * 0.5, sz * length * 0.5),
				Vector3(0.2, CONTAINER_H + 0.04, 0.2), kind, false), 0.7)
	for s in [-1, 1]:
		_shade(_part(base, yaw, Vector3(s * CONTAINER_W * 0.5, CONTAINER_H, 0), Vector3(0.16, 0.1, length), kind, false), 0.7)
		_shade(_part(base, yaw, Vector3(s * CONTAINER_W * 0.5, 0.06, 0), Vector3(0.16, 0.12, length), kind, false), 0.7)
		for d in [-0.3, 0.3]:
			_part(base, yaw, Vector3(s * 0.6 + d, CONTAINER_H * 0.5, -length * 0.5 - 0.04), Vector3(0.06, CONTAINER_H - 0.3, 0.06), "scaffold", false)


## A site office: a white container with a door and windows.
func office(base: Vector3, turned: bool = false, length: float = 12.0) -> void:
	container(base, "box_white", turned, length)
	var yaw := 0.0 if turned else PI * 0.5
	for along in [-length * 0.3, 0.0, length * 0.3]:
		_part(base, yaw, Vector3(CONTAINER_W * 0.5 + 0.05, 1.55, along), Vector3(0.06, 0.9, 1.6), "glass", false)
	_part(base, yaw, Vector3(CONTAINER_W * 0.5 + 0.05, 1.05, length * 0.5 - 1.0), Vector3(0.06, 2.0, 0.9), "box_blue", false)


## Hoarding (the fence around the site) on all four sides: panels between posts,
## with a pale band along the top. Solid, and tall enough to wall-run.
func hoarding(half: float, height: float) -> void:
	for side in 4:
		var yaw := side * PI * 0.5
		var origin := Vector3.ZERO
		_part(origin, yaw, Vector3(0, height * 0.5, -half - 0.2), Vector3(half * 2 + 0.8, height, 0.4), "hoarding")
		_part(origin, yaw, Vector3(0, height - 0.5, -half + 0.02), Vector3(half * 2, 0.6, 0.06), "hoarding_trim", false)
		_part(origin, yaw, Vector3(0, 0.35, -half + 0.02), Vector3(half * 2, 0.7, 0.06), "hoarding_base", false)
		var posts := int(half * 2 / 4.0)
		for i in posts + 1:
			_part(origin, yaw, Vector3(-half + i * half * 2 / posts, height * 0.5 + 0.2, -half + 0.06),
				Vector3(0.18, height + 0.4, 0.12), "hoarding_trim", false)


## A pallet with a load on it: cover about 1.2 m high that you can vault.
## `load`: "blocks", "bags" or "timber".
func pallet(base: Vector3, yaw: float = 0.0, load: String = "blocks", height: float = 1.2) -> void:
	_hide(_obox(base + Vector3(0, height * 0.5, 0), Vector3(1.3, height, 1.1), yaw, "plank"))
	_part(base, yaw, Vector3(0, 0.08, 0), Vector3(1.3, 0.16, 1.1), "plank", false)
	var kind: String = {"blocks": "block", "bags": "bag", "timber": "ply"}[load]
	var layers: int = max(int(round((height - 0.16) / 0.26)), 1)
	var lh := (height - 0.16) / layers
	for i in layers:
		var inset := 0.0 if load != "bags" else 0.05 * (i % 2)
		_vary(_part(base, yaw, Vector3(0, 0.16 + lh * (i + 0.5), 0), Vector3(1.2 - inset * 2, lh - 0.02, 1.0 - inset * 2), kind, false), 0.08)


## A big crate: cover and a step up. Solid.
func crate(base: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	_vary(_obox(base + Vector3(0, size.y * 0.5, 0), size, yaw, "ply"), 0.07)
	for s in [-1, 1]:
		_part(base, yaw, Vector3(s * (size.x * 0.5 - 0.1), size.y * 0.5, 0), Vector3(0.12, size.y + 0.02, size.z + 0.04), "plank", false)


## A cable drum lying on its side (a low round obstacle).
func cable_drum(base: Vector3, yaw: float = 0.0, radius: float = 0.9, width: float = 1.1) -> void:
	var axis := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var c := base + Vector3(0, radius, 0)
	_rod(c - axis * width * 0.5, c + axis * width * 0.5, radius * 0.55, "cable", false, 10)
	for s in [-1, 1]:
		_rod(c + axis * s * (width * 0.5 - 0.04), c + axis * s * (width * 0.5 + 0.04), radius, "plank", false, 12)
	_hide(_obox(c, Vector3(width, radius * 2.0, radius * 1.7), yaw, "plank"))


## A pyramid of pipes on timbers, `count` wide at the bottom. Solid as a stepped pile.
func pipe_stack(base: Vector3, yaw: float, count: int = 3, length: float = 6.0, radius: float = 0.45) -> void:
	var axis := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var side := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	for row in count:
		var n := count - row
		var y0 := 0.12 + row * radius * 1.74
		for i in n:
			var c := base + side * ((i - (n - 1) * 0.5) * radius * 2.0) + Vector3(0, y0 + radius, 0)
			var p := _rod(c - axis * length * 0.5, c + axis * length * 0.5, radius, "pipe", false, 10)
			p["shape"] = "tube"
			p["inner"] = radius * 1.6
			_vary(p, 0.05)
		var top := y0 + radius * 2.0
		_hide(_obox(base + Vector3(0, top * 0.5, 0), Vector3(n * radius * 2.0, top, length), yaw, "pipe"))
	for along in [-length * 0.3, length * 0.3]:
		_part(base, yaw, Vector3(0, 0.06, along), Vector3(count * radius * 2.0 + 0.3, 0.12, 0.2), "plank", false)


## A big concrete pipe you can run through, from `a` to `b` (centre line).
func culvert(a: Vector3, b: Vector3, outer: float = 1.35, inner: float = 1.15, sides: int = 10) -> void:
	var p := _rod(a, b, outer, "pipe", false, sides)
	p["shape"] = "tube"
	p["inner"] = inner * 2.0
	var xf: Transform3D = p.xf
	var length := a.distance_to(b)
	var wall := outer - inner
	var mid_r := (outer + inner) * 0.5
	for i in sides:
		var ang := TAU * (i + 0.5) / sides
		var n := Vector3(cos(ang), 0, sin(ang))
		var tangent := Vector3(-sin(ang), 0, cos(ang))
		var basis := xf.basis * Basis(tangent, Vector3.UP, n)
		var width := 2.0 * outer * tan(PI / sides) + 0.02
		_hide(_add(Transform3D(basis, xf * (n * mid_r * cos(PI / sides))), Vector3(width, length, wall), "pipe", true, "box"))


## A portable toilet.
func toilet(base: Vector3, yaw: float = 0.0) -> void:
	_part(base, yaw, Vector3(0, 1.15, 0), Vector3(1.2, 2.3, 1.2), "box_blue")
	_part(base, yaw, Vector3(0, 2.36, 0), Vector3(1.3, 0.14, 1.3), "box_white", false)
	_part(base, yaw, Vector3(0, 1.1, -0.61), Vector3(0.8, 1.9, 0.04), "box_white", false)


## A skip (an open-topped rubbish container), 1.4 m high.
func skip(base: Vector3, yaw: float = 0.0) -> void:
	_part(base, yaw, Vector3(0, 0.7, 0), Vector3(2.0, 1.4, 3.6), "box_orange")
	_shade(_part(base, yaw, Vector3(0, 1.36, 0), Vector3(1.7, 0.12, 3.3), "dirt_dark", false), 0.7)
	for s in [-1, 1]:
		_part(base, yaw, Vector3(s * 1.02, 1.2, 0), Vector3(0.08, 0.2, 3.7), "scaffold", false)


## A floodlight mast: a lattice pole with a rack of lamps on top. Good to swing from.
func light_mast(base: Vector3, height: float = 15.0, toward: Vector3 = Vector3.ZERO) -> void:
	_box(base + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 1.4), "concrete_dark")
	lattice(base + Vector3(0, 0.8, 0), base + Vector3(0, height, 0), 0.7, 0.7, "scaffold", 0.1)
	var to := toward - base
	var yaw := atan2(-to.x, -to.z)
	_part(base + Vector3(0, height, 0), yaw, Vector3(0, 0.5, 0), Vector3(3.0, 1.0, 0.5), "scaffold")
	for i in 4:
		_part(base + Vector3(0, height, 0), yaw, Vector3(-1.05 + i * 0.7, 0.5, -0.27), Vector3(0.55, 0.7, 0.06), "lamp", false)


## The world outside the fence: flat ground to the horizon and a ring of plain
## blocks for a skyline, taller the further off they are. Drawn only. `half` is
## where the site's own ground ends.
func surroundings(half: float, reach: float = 420.0) -> void:
	_span(-reach, reach, -1, -0.03, -reach, -half, "street", false)
	_span(-reach, reach, -1, -0.03, half, reach, "street", false)
	_span(-reach, -half, -1, -0.03, -half, half, "street", false)
	_span(half, reach, -1, -0.03, -half, half, "street", false)
	var count := 72
	for i in count:
		var ang := TAU * i / count + _rng.randf_range(-0.03, 0.03)
		var far := _rng.randf()
		var dist := half + 70.0 + far * 190.0
		var h := _rng.randf_range(8.0, 20.0) * (1.0 + far * 2.2)
		var block := _obox(Vector3(cos(ang) * dist, h * 0.5, sin(ang) * dist),
			Vector3(_rng.randf_range(12, 26), h, _rng.randf_range(12, 26)), _rng.randf_range(0.0, PI), "backdrop", false)
		_shade(block, _rng.randf_range(0.80, 1.05))


## A work light hanging under a ceiling at `pos`.
func work_light(pos: Vector3, reach: float = 14.0) -> void:
	_box(pos + Vector3(0, 0.25, 0), Vector3(0.04, 0.5, 0.04), "cable", false)
	_box(pos, Vector3(0.5, 0.12, 0.5), "lamp", false)
	_light(pos - Vector3(0, 0.3, 0), reach, 3.5, Color(1.0, 0.82, 0.56))


## A cement silo on legs.
func silo(base: Vector3, radius: float = 2.2, height: float = 12.0) -> void:
	var legs := 3.0
	for i in 4:
		var ang := TAU * (i + 0.5) / 4
		var foot := base + Vector3(cos(ang), 0, sin(ang)) * radius * 0.8
		_box(foot + Vector3(0, legs * 0.5, 0), Vector3(0.3, legs, 0.3), "scaffold", false)
	var body := _cyl(base + Vector3(0, legs, 0), radius, height - legs, "silo")
	body["sides"] = 12
	var cone := _cyl(base + Vector3(0, 1.2, 0), radius * 0.45, legs - 1.2, "silo")
	cone["sides"] = 12
	_shade(cone, 0.85)
	var band := _cyl(base + Vector3(0, height - 1.6, 0), radius + 0.04, 0.5, "box_red", false)
	band["sides"] = 12


## A flatbed trailer loaded with girders. The bed is 1.4 m up: slide under it.
func flatbed(base: Vector3, yaw: float = 0.0, length: float = 10.0) -> void:
	_part(base, yaw, Vector3(0, 1.55, 0), Vector3(2.5, 0.3, length), "machine_dark")
	for along in [-length * 0.5 + 0.9, -length * 0.5 + 2.1, length * 0.5 - 0.9]:
		for s in [-1, 1]:
			_part(base, yaw, Vector3(s * 0.95, 0.5, along), Vector3(0.5, 1.0, 1.0), "rubber")
	for i in 3:
		_vary(_part(base, yaw, Vector3(-0.7 + i * 0.7, 1.95, 0.3), Vector3(0.5, 0.5, length - 1.6), "steel"), 0.06)
	_part(base, yaw, Vector3(0, 2.0, -length * 0.5 + 0.2), Vector3(2.5, 1.2, 0.15), "machine_dark")


## A concrete mixer truck: cab, chassis and drum. Solid cover about 3.5 m high.
func mixer_truck(base: Vector3, yaw: float = 0.0) -> void:
	_part(base, yaw, Vector3(0, 0.9, 0), Vector3(2.4, 0.5, 8.0), "machine_dark", false)
	_part(base, yaw, Vector3(0, 1.75, -3.0), Vector3(2.4, 2.3, 2.0), "machine")
	_part(base, yaw, Vector3(0, 2.2, -4.02), Vector3(2.1, 0.9, 0.06), "glass", false)
	for s in [-1, 1]:
		_part(base, yaw, Vector3(s * 1.21, 2.2, -3.1), Vector3(0.04, 0.8, 1.2), "glass", false)
		for along in [-3.0, 1.0, 2.4]:
			_part(base, yaw, Vector3(s * 0.95, 0.5, along), Vector3(0.5, 1.0, 1.0), "rubber", false)
	var basis := Basis(Vector3.UP, yaw)
	_rod(base + basis * Vector3(0, 2.2, -1.6), base + basis * Vector3(0, 3.0, 3.6), 1.25, "box_white", false, 10)
	_rod(base + basis * Vector3(0, 2.5, 0.4), base + basis * Vector3(0, 2.66, 1.4), 1.29, "box_red", false, 10)
	_hide(_part(base, yaw, Vector3(0, 1.9, 1.0), Vector3(2.4, 3.3, 6.0), "machine"))


## An excavator: tracks, a body turned by `swing`, and an arm reaching out.
func excavator(base: Vector3, yaw: float = 0.0, swing: float = 0.5) -> void:
	for s in [-1, 1]:
		_part(base, yaw, Vector3(s * 1.2, 0.45, 0), Vector3(0.7, 0.9, 4.4), "rubber")
	_part(base, yaw, Vector3(0, 0.75, 0), Vector3(1.8, 0.5, 2.6), "machine_dark", false)
	var top := base + Vector3(0, 1.0, 0)
	var t := yaw + swing
	_part(top, t, Vector3(0, 0.75, 0.5), Vector3(2.8, 1.5, 3.8), "machine")
	_part(top, t, Vector3(-0.75, 1.9, -0.6), Vector3(1.2, 1.3, 1.6), "machine")
	_part(top, t, Vector3(-0.75, 2.0, -1.42), Vector3(1.0, 0.9, 0.05), "glass", false)
	_part(top, t, Vector3(-1.37, 2.0, -0.6), Vector3(0.05, 0.9, 1.3), "glass", false)
	_part(top, t, Vector3(0, 0.9, 2.3), Vector3(2.6, 1.1, 0.5), "machine_dark", false)
	var basis := Basis(Vector3.UP, t)
	var shoulder := top + basis * Vector3(0.5, 1.2, -1.2)
	var elbow := top + basis * Vector3(0.5, 5.6, -5.0)
	var wrist := top + basis * Vector3(0.5, 1.6, -8.4)
	_strut(shoulder, elbow, 0.6, 0.8, "machine")
	_strut(elbow, wrist, 0.5, 0.6, "machine")
	_part(top, t, Vector3(0.5, 0.9, -8.6), Vector3(1.1, 1.2, 1.0), "machine_dark")


## Scaffolding over a footprint: `decks` is a list of [height, from, to] along its
## long side (z when `along_z`, else x): solid plank decks. Tubes are drawn only.
func scaffold(x0: float, x1: float, z0: float, z1: float, decks: Array, top: float, along_z: bool = true) -> void:
	for d in decks:
		var piece: Dictionary
		if along_z:
			piece = _span(x0, x1, d[0] - 0.14, d[0], d[1], d[2], "plank")
		else:
			piece = _span(d[1], d[2], d[0] - 0.14, d[0], z0, z1, "plank")
		_vary(piece, 0.05)
	var a0 := z0 if along_z else x0
	var a1 := z1 if along_z else x1
	var bays: int = max(int(round(absf(a1 - a0) / 2.6)), 1)
	var rows := [x0 + 0.08, x1 - 0.08] if along_z else [z0 + 0.08, z1 - 0.08]
	for i in bays + 1:
		var a := lerpf(a0, a1, float(i) / bays)
		for r in rows:
			var foot := Vector3(r, 0, a) if along_z else Vector3(a, 0, r)
			_box(foot + Vector3(0, top * 0.5, 0), Vector3(0.09, top, 0.09), "scaffold", false)
	var lift := 2.0
	while lift <= top - 0.5:
		for r in rows:
			var p0 := Vector3(r, lift - 0.2, a0) if along_z else Vector3(a0, lift - 0.2, r)
			var p1 := Vector3(r, lift - 0.2, a1) if along_z else Vector3(a1, lift - 0.2, r)
			_strut(p0, p1, 0.07, 0.07, "scaffold", false)
		lift += 2.0
	# Diagonal braces on the outer row, every other bay
	var outer: float = rows[1]
	for i in range(0, bays, 2):
		var b0 := lerpf(a0, a1, float(i) / bays)
		var b1 := lerpf(a0, a1, float(i + 1) / bays)
		var y := 0.0
		while y + 4.0 <= top:
			var p0 := Vector3(outer, y, b0) if along_z else Vector3(b0, y, outer)
			var p1 := Vector3(outer, y + 4.0, b1) if along_z else Vector3(b1, y + 4.0, outer)
			_strut(p0, p1, 0.06, 0.06, "scaffold", false)
			y += 4.0


## A tower crane. `base` is the foot of the mast, `dir` the way the jib points
## (flat), `load_at` how far along the jib the hook hangs and `load_top` the height
## of the top of the load it carries (0 = no load).
func crane(base: Vector3, height: float, dir: Vector3, jib_len: float, counter_len: float,
		load_at: float = 0.0, load_top: float = 0.0, load_size: Vector3 = Vector3(6, 0.6, 2.4)) -> void:
	dir = Vector3(dir.x, 0, dir.z).normalized()
	var side := dir.cross(Vector3.UP)
	_box(base + Vector3(0, 0.5, 0), Vector3(5.5, 1, 5.5), "concrete_dark")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_vary(_box(base + Vector3(sx * 1.9, 1.5, sz * 1.9), Vector3(1.5, 1.0, 1.5), "weight"), 0.05)
	lattice(base + Vector3(0, 1, 0), base + Vector3(0, height, 0), 2.4, 2.4, "crane", 0.22)
	var top := base + Vector3(0, height, 0)
	_box(top + Vector3(0, 0.3, 0), Vector3(3.0, 0.6, 3.0), "crane")                    # slewing ring
	# Jib and counter-jib: one long truss, walkable on top if you can get there
	var jib_y := Vector3(0, 1.4, 0)
	lattice(top + jib_y + dir * 1.5, top + jib_y + dir * jib_len, 1.8, 1.6, "crane", 0.18)
	lattice(top + jib_y - dir * counter_len, top + jib_y + dir * 1.5, 1.8, 1.6, "crane", 0.18)
	_span_on(top + jib_y - dir * counter_len * 0.5 + Vector3(0, 0.85, 0), dir, Vector3(1.9, 0.1, counter_len), "stair", false)
	# Tower head and the tie bars that hold the jib up
	var head := top + Vector3(0, 8.0, 0)
	lattice(top + Vector3(0, 0.6, 0), head, 1.2, 1.2, "crane", 0.14, false)
	_hide(_box(top + Vector3(0, 4.6, 0), Vector3(1.2, 6.8, 1.2), "crane"))
	_strut(head, top + jib_y + dir * jib_len * 0.62 + Vector3(0, 0.8, 0), 0.12, 0.12, "cable", false)
	_strut(head, top + jib_y + dir * jib_len * 0.3 + Vector3(0, 0.8, 0), 0.12, 0.12, "cable", false)
	_strut(head, top + jib_y - dir * (counter_len - 1.5) + Vector3(0, 0.8, 0), 0.12, 0.12, "cable", false)
	# Counterweights and the driver's cab
	for i in 3:
		_vary(_span_on(top + jib_y - dir * (counter_len - 1.2 - i * 1.3) + Vector3(0, -0.9, 0), dir, Vector3(2.2, 2.6, 1.1), "weight"), 0.06)
	var cab := top + side * 2.3 + dir * 1.6 + Vector3(0, -0.5, 0)
	_span_on(cab, dir, Vector3(1.7, 2.1, 2.4), "box_white")
	_span_on(cab + dir * 1.22 + Vector3(0, 0.2, 0), dir, Vector3(1.5, 1.2, 0.06), "glass", false)
	if load_at > 0.0:
		var hook := top + jib_y + dir * load_at + Vector3(0, -0.8, 0)
		_span_on(hook + Vector3(0, -0.3, 0), dir, Vector3(1.4, 0.6, 1.8), "weight", false)      # trolley
		var block := Vector3(hook.x, load_top + 3.2, hook.z)
		_strut(hook, block, 0.08, 0.08, "cable", false)
		_box(block, Vector3(0.6, 0.8, 0.6), "crane", false)                                   # hook block
		var basis := Basis.looking_at(dir, Vector3.UP)
		var centre := Vector3(hook.x, load_top - load_size.y * 0.5, hook.z)
		_add(Transform3D(basis, centre), Vector3(load_size.z, load_size.y, load_size.x), "concrete", true, "box")
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var corner := centre + basis * Vector3(sx * (load_size.z * 0.5 - 0.2), load_size.y * 0.5, sz * (load_size.x * 0.5 - 0.5))
				_strut(block + Vector3(0, -0.4, 0), corner, 0.05, 0.05, "cable", false)


## A label that always faces the camera (concept pictures only).
func tag(pos: Vector3, text: String, size: int = 240) -> void:
	signs.append({"pos": pos, "text": text, "yaw": NAN, "size": size})
