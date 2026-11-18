class_name Accessories
extends RefCounted
## The Character Creator's hats, glasses, neckwear and back pieces, modelled in code
## in the same low-poly, flat-shaded style as the robots.
##
## Each one is built in the robot's rest pose (standing, facing -Z) around the body
## it is going on, from a few measurements of that body (see `fit`): where the top
## of the head is, how wide it is, where the eyes and the chest are. Every triangle
## follows one bone (the head, or the chest), the same as the robots' own parts, so
## they move with the body, a hat disappears with the head in first person, and
## nothing else about the robot needs to know they are there.

## Surfaces' materials. Their names are material kinds (see RobotModel): "accent"
## takes the player's colour, "armor" the body paint; the rest stay as they are.
const MATERIALS := {
	"accent": {"color": Color(0.95, 0.35, 0.25), "metallic": 0.05, "roughness": 0.7},
	"armor": {"color": Color(0.90, 0.91, 0.93), "metallic": 0.1, "roughness": 0.55},
	# Gold and steel are only part metal: a full metal goes black where there is no sky
	# to reflect (the menus' robot stages), so a little glow keeps the gold golden.
	"gold": {"color": Color(1.0, 0.76, 0.28), "metallic": 0.45, "roughness": 0.3, "emission": Color(0.45, 0.3, 0.06), "energy": 0.35},
	"steel": {"color": Color(0.70, 0.72, 0.75), "metallic": 0.5, "roughness": 0.3},
	"silk": {"color": Color(0.07, 0.07, 0.08), "metallic": 0.0, "roughness": 0.6},
	"leather": {"color": Color(0.42, 0.25, 0.12), "metallic": 0.0, "roughness": 0.8},
	"lens": {"color": Color(0.03, 0.03, 0.05), "metallic": 0.6, "roughness": 0.08},
	"glass": {"color": Color(0.70, 0.88, 1.0, 0.35), "metallic": 0.2, "roughness": 0.05, "alpha": true},
	"horn": {"color": Color(0.93, 0.89, 0.76), "metallic": 0.0, "roughness": 0.6},
	"hair": {"color": Color(0.17, 0.10, 0.06), "metallic": 0.0, "roughness": 0.9},
	"feather": {"color": Color(0.97, 0.97, 0.95), "metallic": 0.0, "roughness": 0.85},
	"joint": {"color": Color(0.12, 0.13, 0.15), "metallic": 0.3, "roughness": 0.6},
	"glow": {"color": Color(1.0, 0.85, 0.4), "metallic": 0.0, "roughness": 0.5, "emission": Color(1.0, 0.78, 0.3)},
	"flame": {"color": Color(0.3, 0.6, 1.0), "metallic": 0.0, "roughness": 0.5, "emission": Color(0.35, 0.7, 1.0)},
}

## Which bone each slot's pieces follow.
const SLOT_BONE := {"hat": "head", "face": "head", "neck": "chest", "back": "chest"}

static var _materials := {}

var _tris := {}            # material -> PackedVector3Array, three points a triangle
var _bone := "head"
var _out := {}             # bone -> {material -> PackedVector3Array}
var f := {}                # the body's measurements (see fit)


## Measurements of the body the pieces go on, from the triangles of its head and
## chest in the rest pose: `head_shell` (AABB of the head's shell, not its antennas),
## `visor` (AABB of the face's glowing parts, if any), `chest` (AABB of the chest) and
## `collar_front` (how far forward the chest is just under the neck, -Z).
static func fit(head_shell: AABB, visor: AABB, chest: AABB, collar_front: float) -> Dictionary:
	var top := head_shell.end.y
	var bottom := head_shell.position.y
	var eye_y := visor.get_center().y if visor.size != Vector3.ZERO else lerpf(bottom, top, 0.5)
	eye_y = clampf(eye_y, bottom + 0.05, top - 0.04)
	var eye_w := clampf(visor.size.x * 0.5 * 0.6, 0.038, 0.07) if visor.size != Vector3.ZERO else 0.05
	return {
		"top": top, "bottom": bottom,
		"front": head_shell.position.z, "back": head_shell.end.z,
		"w": maxf(head_shell.size.x * 0.5, 0.07), "d": maxf(head_shell.size.z * 0.5, 0.07),
		"cz": head_shell.get_center().z,
		"eye_y": eye_y, "eye_w": eye_w,
		"eye_z": minf(visor.position.z, head_shell.position.z) if visor.size != Vector3.ZERO else head_shell.position.z,
		"neck_y": chest.end.y, "chest_front": chest.position.z, "chest_back": chest.end.z,
		"chest_w": chest.size.x * 0.5, "chest_bottom": chest.position.y,
		"collar_front": collar_front,
	}


## Every piece for these accessories ({slot: id}), on a body measured by fit().
## Returns [{bone, material (name), points (PackedVector3Array, three a triangle)}].
static func build(picked: Dictionary, measurements: Dictionary) -> Array:
	var a := Accessories.new()
	a.f = measurements
	for slot in CustomCharacter.SLOTS:
		var id: String = picked.get(slot, "")
		if id == "":
			continue
		a._bone = SLOT_BONE[slot]
		a._tris = a._out.get_or_add(a._bone, {})
		var method := "_" + id
		if a.has_method(method):
			a.call(method)
	var out: Array = []
	for bone in a._out:
		for m in a._out[bone]:
			out.append({"bone": bone, "material": m, "points": a._out[bone][m]})
	return out


## The shared material for a kind of surface (see MATERIALS).
static func material(kind: String) -> StandardMaterial3D:
	if not _materials.has(kind):
		var d: Dictionary = MATERIALS.get(kind, MATERIALS.armor)
		var m := StandardMaterial3D.new()
		m.resource_name = kind
		m.albedo_color = d.color
		m.metallic = d.metallic
		m.roughness = d.roughness
		m.cull_mode = BaseMaterial3D.CULL_DISABLED   # capes and brims are seen from both sides
		if d.get("alpha", false):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if d.has("emission"):
			m.emission_enabled = true
			m.emission = d.emission
			m.emission_energy_multiplier = d.get("energy", 1.4)
		_materials[kind] = m
	return _materials[kind]


# ---------------------------------------------------------------------------
# Building blocks. Everything is a set of flat triangles, turned to face away from
# a centre point so their normals point out.

func _tri(m: String, a: Vector3, b: Vector3, c: Vector3, centre: Vector3) -> void:
	var pts: PackedVector3Array = _tris.get_or_add(m, PackedVector3Array())
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		pts.append_array([a, c, b])
	else:
		pts.append_array([a, b, c])
	_tris[m] = pts


## Skin a run of rings (each the same number of points) into a closed part.
func _loft(m: String, rings: Array, caps: bool = true) -> void:
	var centre := Vector3.ZERO
	var count := 0
	for r in rings:
		for p in r:
			centre += p
			count += 1
	centre /= maxf(count, 1)
	for i in rings.size() - 1:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var mid := (_mean(a) + _mean(b)) * 0.5
		var c := mid if caps else centre
		for j in a.size():
			var k := (j + 1) % a.size()
			_tri(m, a[j], a[k], b[k], c)
			_tri(m, a[j], b[k], b[j], c)
	if caps:
		for pair in [[rings[0], rings[1]], [rings[-1], rings[-2]]]:
			var ring: Array = pair[0]
			var inside := _mean(pair[1])
			for j in range(1, ring.size() - 1):
				_tri(m, ring[0], ring[j], ring[j + 1], inside)


func _mean(points: Array) -> Vector3:
	var s := Vector3.ZERO
	for p in points:
		s += p
	return s / maxf(points.size(), 1)


## An ellipse of n points at height y (rx across, rz front to back).
func _ellipse(n: int, rx: float, rz: float, y: float, cx: float = 0.0, cz: float = 0.0, phase: float = 0.0) -> Array:
	var out: Array = []
	for i in n:
		var a := phase + i * TAU / n
		out.append(Vector3(cx + rx * cos(a), y, cz + rz * sin(a)))
	return out


## The same ring turned by `basis` round `pivot`.
func _turn(ring: Array, basis: Basis, pivot: Vector3) -> Array:
	return ring.map(func(p): return pivot + basis * (p - pivot))


func _box(m: String, centre: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var h := size * 0.5
	var lo: Array = []
	var hi: Array = []
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		lo.append(centre + basis * Vector3(c.x * h.x, -h.y, c.y * h.z))
		hi.append(centre + basis * Vector3(c.x * h.x, h.y, c.y * h.z))
	_loft(m, [lo, hi])


## A cylinder (or cone, r_top 0) standing on `basis`'s Y axis, `centre` at its middle.
func _cyl(m: String, centre: Vector3, r: float, r_top: float, h: float, n: int = 10, basis: Basis = Basis.IDENTITY, squash: float = 1.0) -> void:
	var lo := _ellipse(n, r, r * squash, -h * 0.5).map(func(p): return centre + basis * p)
	if r_top <= 0.0:
		var tip := centre + basis * Vector3(0, h * 0.5, 0)
		var inside := centre
		for j in n:
			_tri(m, lo[j], lo[(j + 1) % n], tip, inside)
		for j in range(1, n - 1):
			_tri(m, lo[0], lo[j], lo[j + 1], tip)
		return
	var hi := _ellipse(n, r_top, r_top * squash, h * 0.5).map(func(p): return centre + basis * p)
	_loft(m, [lo, hi])


## A ball of rings (n round, rows up), `scale` stretching it.
func _ball(m: String, centre: Vector3, r: float, scale: Vector3 = Vector3.ONE, n: int = 8, rows: int = 5) -> void:
	var rings: Array = []
	for i in range(1, rows):
		var a := PI * i / rows
		rings.append(_ellipse(n, sin(a) * r * scale.x, sin(a) * r * scale.z, -cos(a) * r * scale.y)
			.map(func(p): return centre + p))
	_loft(m, rings)
	var bottom := centre - Vector3(0, r * scale.y, 0)
	var top := centre + Vector3(0, r * scale.y, 0)
	for j in n:
		_tri(m, rings[0][j], rings[0][(j + 1) % n], bottom, centre)
		_tri(m, rings[-1][j], rings[-1][(j + 1) % n], top, centre)


## A ring (a thick circle), round `axis_basis`'s Y axis.
func _torus(m: String, centre: Vector3, radius: float, thick: float, n: int = 16, basis: Basis = Basis.IDENTITY, rz: float = -1.0) -> void:
	rz = radius if rz < 0.0 else rz
	for i in n:
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		var p0 := centre + basis * Vector3(radius * cos(a0), 0, rz * sin(a0))
		var p1 := centre + basis * Vector3(radius * cos(a1), 0, rz * sin(a1))
		_segment(m, p0, p1, thick, basis.y)


## A square tube from a to b, `thick` across, its flat side facing `up`.
func _segment(m: String, a: Vector3, b: Vector3, thick: float, up: Vector3 = Vector3.UP) -> void:
	var along := b - a
	if along.length() < 1e-5:
		return
	var dir := along.normalized()
	var side := dir.cross(up)
	if side.length() < 1e-4:
		side = dir.cross(Vector3.FORWARD)
	side = side.normalized() * thick * 0.5
	var up2 := side.cross(dir).normalized() * thick * 0.5
	var ra := [a - side - up2, a + side - up2, a + side + up2, a - side + up2]
	var rb := [b - side - up2, b + side - up2, b + side + up2, b - side + up2]
	_loft(m, [ra, rb])


## A tube along a path of points, its radius going from r0 to r1.
func _tube(m: String, path: Array, r0: float, r1: float, n: int = 6) -> void:
	var rings: Array = []
	for i in path.size():
		var t := float(i) / maxf(path.size() - 1, 1)
		var p: Vector3 = path[i]
		var dir: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(dir).normalized()
		var r := lerpf(r0, r1, t)
		var ring: Array = []
		for j in n:
			var a := j * TAU / n
			ring.append(p + (side * cos(a) + up * sin(a)) * maxf(r, 0.001))
		rings.append(ring)
	_loft(m, rings)


## A flat sheet over a grid of points (rows of columns), `thick` deep along `out`.
func _sheet(m: String, grid: Array, thick: float, out: Vector3) -> void:
	var back := out.normalized() * thick
	for i in grid.size() - 1:
		for j in grid[i].size() - 1:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j + 1]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i + 1][j]
			var mid := (a + b + c + d) * 0.25
			_tri(m, a, b, c, mid - back)
			_tri(m, a, c, d, mid - back)
			_tri(m, a + back, c + back, b + back, mid)
			_tri(m, a + back, d + back, c + back, mid)


# ---------------------------------------------------------------------------
# Hats. On the head bone, sitting on the top of the head's shell.

func _top_hat() -> void:
	var y: float = f.top - 0.015
	var w: float = f.w
	var d: float = f.d
	var cz: float = f.cz
	_loft("silk", [_ellipse(14, w * 1.5, d * 1.5, y, 0, cz), _ellipse(14, w * 1.5, d * 1.5, y + 0.014, 0, cz)])
	_loft("silk", [_ellipse(14, w * 0.86, d * 0.86, y, 0, cz), _ellipse(14, w * 0.92, d * 0.92, y + 0.25, 0, cz)])
	_loft("accent", [_ellipse(14, w * 0.875, d * 0.875, y + 0.015, 0, cz), _ellipse(14, w * 0.885, d * 0.885, y + 0.055, 0, cz)])


func _cowboy() -> void:
	var y: float = f.top - 0.025
	var w: float = f.w
	var d: float = f.d
	var cz: float = f.cz
	# A wide brim, curling up at the sides.
	var inner := _ellipse(16, w * 0.9, d * 0.9, y, 0, cz)
	var outer: Array = []
	for i in 16:
		var a := i * TAU / 16
		outer.append(Vector3(w * 2.0 * cos(a), y + 0.055 * pow(absf(cos(a)), 3.0) - 0.01 * absf(sin(a)), cz + d * 1.75 * sin(a)))
	_sheet("leather", [inner + [inner[0]], outer + [outer[0]]], 0.012, Vector3.UP)
	# The crown, with a dent along the top.
	var rings: Array = []
	for k in 4:
		var t := k / 3.0
		var ring := _ellipse(12, w * lerpf(0.86, 0.74, t), d * lerpf(0.9, 0.82, t), y + 0.17 * t, 0, cz)
		if k == 3:
			ring = ring.map(func(p): return p - Vector3(0, 0.035 * (1.0 - absf(p.x) / maxf(w, 0.01)), 0))
		rings.append(ring)
	_loft("leather", rings)
	_loft("silk", [_ellipse(12, w * 0.87, d * 0.91, y + 0.012, 0, cz), _ellipse(12, w * 0.85, d * 0.89, y + 0.045, 0, cz)])


func _crown() -> void:
	var y: float = f.top - 0.02
	var w: float = f.w * 0.92
	var d: float = f.d * 0.92
	var cz: float = f.cz
	_loft("gold", [_ellipse(16, w, d, y, 0, cz), _ellipse(16, w * 1.04, d * 1.04, y + 0.06, 0, cz)])
	for i in 8:
		var a := i * TAU / 8 + PI / 8
		var base := Vector3(w * 1.02 * cos(a), y + 0.055, cz + d * 1.02 * sin(a))
		_cyl("gold", base + Vector3(0, 0.04, 0), 0.026, 0.0, 0.08, 4)
		_ball("gold", base + Vector3(0, 0.085, 0), 0.012, Vector3.ONE, 6, 3)
	for x: float in [-0.6, 0.0, 0.6]:
		var a: float = -PI * 0.5 + x
		_ball("accent", Vector3(w * 1.06 * cos(a), y + 0.03, cz + d * 1.06 * sin(a)), 0.016, Vector3(1, 1, 0.6), 6, 3)


func _cap() -> void:
	var y: float = f.top - 0.07
	var w: float = f.w * 1.06
	var d: float = f.d * 1.06
	var cz: float = f.cz
	var rings: Array = []
	for k in 5:
		var a := k / 4.0 * PI * 0.5
		rings.append(_ellipse(14, w * cos(a) + 0.002, d * cos(a) + 0.002, y + 0.11 * sin(a), 0, cz))
	_loft("accent", rings)
	# The peak, out over the face.
	var front: float = f.front
	var peak: Array = []
	for row in 2:
		var r: Array = []
		for k in 7:
			var a := lerpf(-PI * 0.85, -PI * 0.15, k / 6.0)
			var reach := 1.0 if row == 0 else 1.0
			var rr := (w * 0.98) if row == 0 else (w * 1.0)
			var zz := cz + d * sin(a) * reach
			if row == 1:
				zz = minf(zz, front) - 0.11 * pow(sin(-a), 2.0)
			r.append(Vector3(rr * cos(a), y + 0.005 - row * 0.02, zz))
		peak.append(r)
	_sheet("accent", peak, 0.012, Vector3.UP)
	_ball("accent", Vector3(0, y + 0.115, cz), 0.014, Vector3(1, 0.6, 1), 6, 3)


func _wizard() -> void:
	var y: float = f.top - 0.02
	var w: float = f.w
	var d: float = f.d
	var cz: float = f.cz
	_loft("accent", [_ellipse(16, w * 1.6, d * 1.6, y, 0, cz), _ellipse(16, w * 1.6, d * 1.6, y + 0.012, 0, cz)])
	var path: Array = []
	for k in 7:
		var t := k / 6.0
		path.append(Vector3(0, y + 0.42 * t, cz + 0.12 * t * t * t))
	var rings: Array = []
	for k in path.size():
		var t := k / float(path.size() - 1)
		rings.append(_ellipse(10, w * 0.88 * (1.0 - t) + 0.004, d * 0.88 * (1.0 - t) + 0.004, path[k].y, 0, path[k].z))
	_loft("accent", rings)
	_loft("gold", [_ellipse(16, w * 0.9, d * 0.9, y + 0.012, 0, cz), _ellipse(16, w * 0.84, d * 0.84, y + 0.05, 0, cz)])
	_ball("gold", Vector3(0, y + 0.43, cz + 0.13), 0.016, Vector3.ONE, 6, 3)


func _viking() -> void:
	var y: float = f.top - 0.08
	var w: float = f.w * 1.07
	var d: float = f.d * 1.07
	var cz: float = f.cz
	var rings: Array = []
	for k in 5:
		var a := k / 4.0 * PI * 0.5
		rings.append(_ellipse(14, w * cos(a) + 0.003, d * cos(a) + 0.003, y + 0.11 * sin(a), 0, cz))
	_loft("steel", rings)
	_loft("gold", [_ellipse(14, w * 1.02, d * 1.02, y - 0.005, 0, cz), _ellipse(14, w * 1.02, d * 1.02, y + 0.025, 0, cz)])
	_box("gold", Vector3(0, y + 0.06, cz - d * 0.75), Vector3(0.018, 0.1, 0.03), Basis.from_euler(Vector3(-0.7, 0, 0)))
	for side in [-1.0, 1.0]:
		var path: Array = []
		for k in 7:
			var t := k / 6.0
			path.append(Vector3(side * (w * 0.85 + 0.14 * t), y + 0.05 + 0.03 * t + 0.16 * t * t, cz - 0.03 * t))
		_tube("horn", path, 0.034, 0.004, 7)


func _party() -> void:
	var y: float = f.top - 0.02
	var r: float = minf(f.w, f.d) * 0.62
	var tilt := Basis.from_euler(Vector3(0, 0, -0.18))
	var base := Vector3(0.02, y, f.cz)
	_cyl("accent", base + tilt * Vector3(0, 0.13, 0), r, 0.0, 0.26, 10, tilt)
	_cyl("gold", base + tilt * Vector3(0, 0.02, 0), r * 0.98, r * 0.88, 0.035, 10, tilt)
	_ball("gold", base + tilt * Vector3(0, 0.27, 0), 0.028, Vector3.ONE, 7, 4)


func _halo() -> void:
	_torus("glow", Vector3(0, f.top + 0.1, f.cz), f.w * 0.85, 0.022, 20, Basis.from_euler(Vector3(0.12, 0, 0)), f.d * 0.85)


func _headphones() -> void:
	var mid: float = lerpf(f.bottom, f.top, 0.48)
	var w: float = f.w + 0.025
	var path: Array = []
	for k in 13:
		var a := PI * k / 12.0
		path.append(Vector3(-w * cos(a), mid + (f.top + 0.03 - mid) * sin(a), f.cz))
	for k in path.size() - 1:
		_segment("joint", path[k], path[k + 1], 0.026, Vector3.FORWARD)
	var sideways := Basis.from_euler(Vector3(0, 0, PI * 0.5))
	for side in [-1.0, 1.0]:
		_cyl("joint", Vector3(side * (w + 0.015), mid, f.cz), 0.062, 0.062, 0.045, 12, sideways)
		_cyl("accent", Vector3(side * (w + 0.042), mid, f.cz), 0.045, 0.04, 0.012, 12, sideways)


func _beanie() -> void:
	var y: float = f.top - 0.09
	var w: float = f.w * 1.06
	var d: float = f.d * 1.06
	var cz: float = f.cz
	var rings: Array = []
	for k in 6:
		var a := k / 5.0 * PI * 0.5
		rings.append(_ellipse(14, w * cos(a) + 0.004, d * cos(a) + 0.004, y + 0.04 + 0.12 * sin(a), 0, cz))
	_loft("accent", rings)
	_loft("accent", [_ellipse(14, w * 1.04, d * 1.04, y - 0.005, 0, cz), _ellipse(14, w * 1.05, d * 1.05, y + 0.05, 0, cz)])
	_ball("feather", Vector3(0, y + 0.175, cz), 0.04, Vector3.ONE, 8, 4)


# ---------------------------------------------------------------------------
# Glasses and faces. On the head bone, in front of the eyes.

func _lens_x() -> float:
	return clampf(f.eye_w, 0.04, minf(0.075, f.w * 0.6))


func _shades() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.012
	var x := _lens_x()
	for side in [-1.0, 1.0]:
		_box("lens", Vector3(side * x, y, z), Vector3(0.072, 0.042, 0.012))
		_box("joint", Vector3(side * x, y + 0.023, z), Vector3(0.078, 0.008, 0.016))
		var hinge := Vector3(side * (x + 0.038), y + 0.015, z)
		var ear := Vector3(side * (f.w + 0.008), y + 0.012, f.cz)
		_segment("joint", hinge, Vector3(side * (f.w + 0.008), y + 0.015, f.front + 0.01), 0.008)
		_segment("joint", Vector3(side * (f.w + 0.008), y + 0.015, f.front + 0.01), ear, 0.008)
	_box("joint", Vector3(0, y + 0.012, z), Vector3(x * 2.0 - 0.07, 0.01, 0.01))


func _round_specs() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.012
	var x := _lens_x()
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	for side in [-1.0, 1.0]:
		_torus("gold", Vector3(side * x, y, z), 0.032, 0.007, 14, facing)
		_cyl("glass", Vector3(side * x, y, z), 0.03, 0.03, 0.004, 12, facing)
		_segment("gold", Vector3(side * (x + 0.032), y, z), Vector3(side * (f.w + 0.006), y + 0.004, f.front + 0.01), 0.006)
		_segment("gold", Vector3(side * (f.w + 0.006), y + 0.004, f.front + 0.01), Vector3(side * (f.w + 0.006), y, f.cz), 0.006)
	var bridge: Array = []
	for k in 5:
		var t := k / 4.0
		bridge.append(Vector3(lerpf(-x + 0.032, x - 0.032, t), y + 0.012 * sin(PI * t), z))
	for k in 4:
		_segment("gold", bridge[k], bridge[k + 1], 0.006)


func _monocle() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.014
	var x := _lens_x()
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	_torus("gold", Vector3(x, y, z), 0.036, 0.008, 16, facing)
	_cyl("glass", Vector3(x, y, z), 0.034, 0.034, 0.004, 12, facing)
	# A little chain hanging down to the side of the head.
	var path: Array = []
	for k in 9:
		var t := k / 8.0
		path.append(Vector3(x + 0.03 + t * (f.w - x - 0.02), y - 0.035 - 0.12 * sin(PI * t * 0.8), z + t * (f.cz - z) * 0.6))
	for k in path.size() - 1:
		_segment("gold", path[k], path[k + 1], 0.005)


func _goggles() -> void:
	var y: float = f.eye_y
	var x := _lens_x()
	_torus("leather", Vector3(0, y, f.cz), f.w + 0.012, 0.03, 18, Basis.IDENTITY, f.d + 0.012)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	for side in [-1.0, 1.0]:
		var c := Vector3(side * x, y, f.eye_z - 0.025)
		_cyl("gold", c, 0.04, 0.036, 0.04, 12, facing)
		_cyl("flame", c - Vector3(0, 0, 0.021), 0.031, 0.031, 0.004, 12, facing)
	_box("gold", Vector3(0, y, f.eye_z - 0.015), Vector3(x * 2.0 - 0.07, 0.014, 0.014))


func _mustache() -> void:
	var y: float = maxf(f.eye_y - 0.075, f.bottom + 0.025)
	var z: float = f.front - 0.008
	for side in [-1.0, 1.0]:
		var path: Array = []
		for k in 7:
			var t := k / 6.0
			path.append(Vector3(side * (0.008 + 0.075 * t), y - 0.012 * sin(PI * t) + 0.03 * t * t * t, z + 0.02 * t * t))
		_tube("hair", path, 0.02, 0.005, 6)


func _eye_patch() -> void:
	var y: float = f.eye_y
	var x := _lens_x()
	_box("silk", Vector3(-x, y, f.eye_z - 0.012), Vector3(0.06, 0.055, 0.012))
	var tilt := Basis.from_euler(Vector3(0, 0, -0.35))
	var centre := Vector3(0, y, f.cz)
	var ring: Array = []
	for k in 16:
		var a := k * TAU / 16
		ring.append(centre + tilt * Vector3((f.w + 0.006) * cos(a), 0, (f.d + 0.01) * sin(a)))
	for k in 16:
		_segment("silk", ring[k], ring[(k + 1) % 16], 0.008, tilt.y)


# ---------------------------------------------------------------------------
# Neckwear. On the chest bone, round the neck and down the front.

## The way round the neck and down the chest: angle 0 is the front, `drop` how far
## it hangs down there.
func _necklace_point(a: float, drop: float, out: float = 0.012) -> Vector3:
	var y: float = f.neck_y - 0.01
	var front := -minf(f.chest_front, f.collar_front - 0.02) + out
	var c := cos(a)
	var z := -sqrt(maxf(c, 0.0)) * front if c > 0.0 else -c * 0.09
	return Vector3(0.12 * sin(a), y - drop * pow(maxf(c, 0.0), 2.0), z)


func _gold_chain() -> void:
	var n := 36
	var pts: Array = []
	for k in n + 1:
		pts.append(_necklace_point(k * TAU / n, 0.17))
	for k in n:
		var up: Vector3 = Vector3.UP if k % 2 == 0 else (pts[k + 1] - pts[k]).cross(Vector3.UP).normalized()
		_segment("gold", pts[k], pts[k + 1].lerp(pts[k], 0.1), 0.022, up)
	var bottom := _necklace_point(0.0, 0.17)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	_cyl("gold", bottom + Vector3(0, -0.045, -0.008), 0.048, 0.048, 0.014, 14, facing)
	_cyl("accent", bottom + Vector3(0, -0.045, -0.017), 0.022, 0.022, 0.006, 8, facing)


func _collar() -> Vector3:
	return Vector3(0, f.neck_y - 0.035, minf(f.collar_front, f.chest_front + 0.05) - 0.012)


func _bow_tie() -> void:
	var c := _collar()
	for side in [-1.0, 1.0]:
		var tip_hi := c + Vector3(side * 0.075, 0.032, 0.006)
		var tip_lo := c + Vector3(side * 0.075, -0.032, 0.006)
		var mid := c + Vector3(side * 0.01, 0, 0)
		var back := Vector3(0, 0, 0.022)
		var centre := (tip_hi + tip_lo + mid) / 3.0 + back * 0.5
		for p in [[mid, tip_hi, tip_lo], [mid + back, tip_lo + back, tip_hi + back]]:
			_tri("accent", p[0], p[1], p[2], centre)
		for e in [[mid, tip_hi], [tip_hi, tip_lo], [tip_lo, mid]]:
			_tri("accent", e[0], e[1], e[1] + back, centre)
			_tri("accent", e[0], e[1] + back, e[0] + back, centre)
	_box("accent", c + Vector3(0, 0, -0.004), Vector3(0.026, 0.03, 0.03))


func _scarf() -> void:
	_torus("accent", Vector3(0, f.neck_y + 0.0, 0.0), 0.13, 0.055, 14, Basis.IDENTITY, maxf(0.11, -f.collar_front + 0.01))
	var c := _collar() + Vector3(0.05, -0.02, -0.02)
	var tail: Array = [
		[c + Vector3(-0.035, 0, 0), c + Vector3(0.035, 0, 0)],
		[c + Vector3(-0.025, -0.12, -0.012), c + Vector3(0.045, -0.12, -0.012)],
		[c + Vector3(-0.015, -0.24, -0.02), c + Vector3(0.06, -0.24, -0.02)],
	]
	_sheet("accent", tail, 0.014, Vector3.BACK)
	for k in 5:
		_box("gold", c + Vector3(-0.01 + k * 0.016, -0.245, -0.02), Vector3(0.006, 0.02, 0.006))


func _medal() -> void:
	var bottom := _necklace_point(0.0, 0.19)
	for side in [-1.0, 1.0]:
		var top := _necklace_point(side * 1.2, 0.19)
		_segment("accent", top, bottom + Vector3(side * 0.012, 0.03, 0), 0.03, Vector3.BACK)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	_cyl("gold", bottom + Vector3(0, -0.02, -0.01), 0.045, 0.045, 0.012, 16, facing)
	_ball("gold", bottom + Vector3(0, -0.02, -0.018), 0.018, Vector3(1, 1, 0.4), 5, 3)


func _tie() -> void:
	var c := _collar()
	var bottom := Vector3(0, maxf(f.chest_bottom + 0.06, c.y - 0.3), f.chest_front - 0.014)
	_box("accent", c + Vector3(0, -0.005, -0.004), Vector3(0.035, 0.03, 0.025))
	var rings: Array = []
	for k in 5:
		var t := k / 4.0
		var p := c.lerp(bottom, t) + Vector3(0, -0.02, 0)
		var w := lerpf(0.022, 0.05, t)
		rings.append([p + Vector3(-w, 0, 0), p + Vector3(0, 0, -0.008), p + Vector3(w, 0, 0), p + Vector3(0, 0, 0.006)])
	var tip := bottom + Vector3(0, -0.06, 0)
	rings.append([tip + Vector3(-0.002, 0, 0), tip + Vector3(0, 0, -0.002), tip + Vector3(0.002, 0, 0), tip + Vector3(0, 0, 0.002)])
	_loft("accent", rings)


# ---------------------------------------------------------------------------
# Back pieces. On the chest bone, behind the shoulders.

func _cape() -> void:
	var top_y: float = f.neck_y - 0.01
	var back: float = maxf(f.chest_back, 0.1)
	var sw: float = f.chest_w
	var grid: Array = []
	var rows := 6
	var cols := 8
	for i in rows + 1:
		var t := i / float(rows)
		var y := lerpf(top_y, 0.68, t)
		var half := lerpf(sw * 0.85, sw * 1.35, t)
		var z := lerpf(back * 0.55, back + 0.17, t * t * 0.7 + t * 0.3)
		var row: Array = []
		for j in cols + 1:
			var u := j / float(cols) * 2.0 - 1.0
			row.append(Vector3(u * half, y - 0.015 * (1.0 - u * u) * t, z + 0.05 * (1.0 - u * u) + 0.02 * sin(u * 6.0) * t))
		grid.append(row)
	_sheet("accent", grid, 0.012, Vector3.FORWARD)
	for side in [-1.0, 1.0]:
		_ball("gold", Vector3(side * sw * 0.7, top_y - 0.01, f.collar_front + 0.02), 0.024, Vector3(1, 1, 0.6), 7, 4)
		_segment("accent", Vector3(side * sw * 0.7, top_y - 0.01, f.collar_front + 0.02), Vector3(side * sw * 0.85, top_y, back * 0.55), 0.03, Vector3.UP)


func _wings() -> void:
	var back: float = maxf(f.chest_back, 0.1)
	var root_y: float = f.neck_y - 0.09
	for side in [-1.0, 1.0]:
		var root := Vector3(side * 0.05, root_y, back + 0.01)
		for k in 5:
			var a := lerpf(0.35, 1.45, k / 4.0)   # angle up from straight out
			var length := lerpf(0.5, 0.26, k / 4.0)
			var dir := Vector3(side * sin(a), cos(a) * 0.9 - 0.15, 0.25).normalized()
			var tip := root + dir * length
			var plane_up := Vector3(0, 0, 1)
			var side_v := dir.cross(plane_up).normalized() * 0.05
			var c := (root + tip) * 0.5
			_tri("feather", root, tip + side_v * 0.4, tip - side_v, c + Vector3(0, 0, 0.02))
			_tri("feather", root + Vector3(0, 0, 0.012), tip - side_v + Vector3(0, 0, 0.012), tip + side_v * 0.4 + Vector3(0, 0, 0.012), c)
			_segment("feather", root, root.lerp(tip, 0.55) - side_v * 0.7, 0.04, Vector3.BACK)
		_ball("armor", root, 0.04, Vector3.ONE, 7, 4)


func _backpack() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var y: float = f.neck_y - 0.17
	var w: float = maxf(f.chest_w * 1.1, 0.2)
	_box("leather", Vector3(0, y, back + 0.07), Vector3(w, 0.28, 0.14))
	_box("leather", Vector3(0, y + 0.14, back + 0.07), Vector3(w * 0.95, 0.03, 0.15), Basis.from_euler(Vector3(0.15, 0, 0)))
	_box("accent", Vector3(0, y - 0.05, back + 0.145), Vector3(w * 0.6, 0.12, 0.03))
	for side in [-1.0, 1.0]:
		_segment("joint", Vector3(side * w * 0.3, y + 0.13, back + 0.01), Vector3(side * w * 0.33, f.neck_y + 0.01, 0.0), 0.03, Vector3.RIGHT)
		_segment("joint", Vector3(side * w * 0.33, f.neck_y + 0.01, 0.0), Vector3(side * w * 0.35, f.neck_y - 0.12, f.chest_front - 0.005), 0.03, Vector3.RIGHT)


func _rocket_pack() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var y: float = f.neck_y - 0.17
	_box("steel", Vector3(0, y, back + 0.03), Vector3(0.12, 0.24, 0.06))
	for side in [-1.0, 1.0]:
		var c := Vector3(side * 0.075, y, back + 0.08)
		_cyl("steel", c, 0.048, 0.048, 0.26, 10)
		_cyl("accent", c + Vector3(0, 0.15, 0), 0.048, 0.0, 0.06, 10)
		_cyl("joint", c + Vector3(0, -0.15, 0), 0.034, 0.046, 0.05, 10)
		_cyl("flame", c + Vector3(0, -0.2, 0), 0.03, 0.0, 0.07, 8, Basis.from_euler(Vector3(PI, 0, 0)))


func _sword() -> void:
	var back: float = maxf(f.chest_back, 0.08) + 0.03
	var tilt := Basis.from_euler(Vector3(0, 0, 0.6))
	var c := Vector3(0, f.neck_y - 0.2, back)
	_box("steel", c + tilt * Vector3(0, -0.05, 0), Vector3(0.05, 0.62, 0.012), tilt)
	_cyl("steel", c + tilt * Vector3(0, -0.385, 0), 0.025, 0.0, 0.05, 4, tilt, 0.25)
	_box("gold", c + tilt * Vector3(0, 0.26, 0), Vector3(0.17, 0.025, 0.03), tilt)
	_box("leather", c + tilt * Vector3(0, 0.33, 0), Vector3(0.028, 0.12, 0.028), tilt)
	_ball("gold", c + tilt * Vector3(0, 0.4, 0), 0.025, Vector3.ONE, 6, 3)
	_segment("leather", Vector3(-f.chest_w * 0.8, f.neck_y - 0.02, 0.0), Vector3(f.chest_w * 0.6, f.chest_bottom + 0.05, back - 0.01), 0.035, Vector3.BACK)
