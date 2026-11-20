class_name BulletMarks
extends Node3D
## The marks that shots, blows and blasts leave on a map: a chipped pock where a round
## stopped, a dark hole where it went through, a scorch round an explosion, and the
## cracks of a wall that has taken damage but not broken (see MapDestruction: on a map
## that breaks fine, cracks are these marks, not darker cells).
##
## Nothing here is sent or decided by anyone: every copy of the game draws the marks
## from the shots and the broken-cell news it already gets. They are flat squares just
## off the surface, all drawn together (two MultiMeshes, one texture), and there are
## only so many: the oldest go first. A mark on a piece of wall that breaks goes with it.
##
## MapRoot makes one (`marks`) on a map with fine destruction.

const MAX_MARKS := 300     ## pocks, holes and scorches at once
const MAX_CRACKS := 900    ## cracked cells drawn at once (each is two squares: both faces)
const OFF := 0.012         ## metres off the surface
const SEEN_TO := 70.0      ## metres: further off they are not drawn

## The pictures (tiles of the one texture, left to right, top row first).
enum { POCK, HOLE, SCORCH, DENT, CRACK, CRACK_2, CRACK_BAD, CRACK_BAD_2 }
const TILES := Vector2i(4, 2)
const TILE := 128

var root: MapRoot
## How many marks have been made (tests).
var made := 0

var _marks: MultiMesh
var _cracks: MultiMesh
var _next := 0
var _mark_cell := PackedInt32Array()   # per mark: the cell it is on, or -1
var _shown := PackedByteArray()        # per mark: 1 while it is drawn
var _by_cell := {}                     # cell -> [marks on it]
var _next_crack := 0
var _crack_of := PackedInt32Array()    # per pair of crack squares: the cell they are on, or -1
var _crack_at := {}                    # cell -> its pair

static var _atlas: ImageTexture


func setup(map: MapRoot) -> void:
	root = map
	name = "Marks"
	_marks = _batch(MAX_MARKS)
	_cracks = _batch(MAX_CRACKS * 2)
	_mark_cell.resize(MAX_MARKS)
	_mark_cell.fill(-1)
	_shown.resize(MAX_MARKS)
	_crack_of.resize(MAX_CRACKS)
	_crack_of.fill(-1)
	if map.destruction:
		map.destruction.cells_changed.connect(_on_cells_changed)


## The marks of the map being played, or null.
static func current() -> BulletMarks:
	var map := MapRoot.current
	return map.marks if map and is_instance_valid(map) and map.marks and is_instance_valid(map.marks) else null


func _batch(count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	mm.custom_aabb = AABB(Vector3.ONE * -600.0, Vector3.ONE * 1200.0)
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = SEEN_TO
	node.visibility_range_end_margin = 10.0
	add_child(node)
	return mm


## One mark: `picture` (POCK...) `size` metres across at `at` on a surface facing
## `normal`. `cell`: the breakable cell it is on (-1: none), so it goes when that breaks.
func mark(at: Vector3, normal: Vector3, picture: int, size: float, cell: int = -1, strength: float = 1.0) -> void:
	var slot := _next
	_next = (_next + 1) % MAX_MARKS
	_forget(slot)
	_marks.set_instance_transform(slot, _square(at, normal, size, randf() * TAU))
	_marks.set_instance_custom_data(slot, Color(picture, strength, 0, 0))
	_marks.set_instance_color(slot, Color.WHITE)
	_mark_cell[slot] = cell
	_shown[slot] = 1
	if cell >= 0:
		if not _by_cell.has(cell):
			_by_cell[cell] = []
		_by_cell[cell].append(slot)
	made += 1


func _square(at: Vector3, normal: Vector3, size: float, roll: float) -> Transform3D:
	normal = normal.normalized()
	var side := normal.cross(Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT).normalized()
	var basis := Basis(side, normal.cross(side), normal).rotated(normal, roll)
	return Transform3D(basis.scaled(Vector3.ONE * size), at + normal * OFF)


func _forget(slot: int) -> void:
	var cell := _mark_cell[slot]
	if cell >= 0 and _by_cell.has(cell):
		(_by_cell[cell] as Array).erase(slot)
		if (_by_cell[cell] as Array).is_empty():
			_by_cell.erase(cell)
	_mark_cell[slot] = -1


## The marks of a shot the way ShotFx.spawn is told about it (one end per pellet, `vias`
## where each went through portals), on the map being played.
static func shots(muzzle: Vector3, ends: PackedVector3Array, hits: Array, weapon_id: String, vias: Array = []) -> void:
	var marks := current()
	if marks == null:
		return
	var weapon := WeaponData.by_id(weapon_id)
	if weapon.damage * weapon.structure_damage < 2.0:
		return   # (a puff of air)
	for i in ends.size():
		var via: PackedVector3Array = vias[i] if i < vias.size() else PackedVector3Array()
		marks.shot(via[via.size() - 1] if via.size() >= 2 else muzzle, ends[i], weapon, i < hits.size() and hits[i])


## A round's marks along the last stretch of its path, `from` (the muzzle, or where it
## came out of a portal) to `to` (where it stopped; `in_someone`: in a player): a pock
## where it stopped, and a hole each side of every panel it went through on the way.
## Worked out here from the map as this copy has it; the host has already decided what
## the round did.
func shot(from: Vector3, to: Vector3, weapon: WeaponData, in_someone: bool = false) -> void:
	if not is_inside_tree() or from.distance_squared_to(to) < 0.0025:
		return
	var space := get_world_3d().direct_space_state
	var dir := (to - from).normalized()
	var size := clampf(0.11 + weapon.damage * 0.0025, 0.12, 0.32)
	var burns := weapon.id in ["laser_rifle", "plasma_pistol"]
	var breaks := root.destruction
	var at := from
	var reach := to + dir * (0.0 if in_someone else 0.3)
	for n in MapDestruction.MAX_PIERCE + 1:
		if at.distance_squared_to(reach) < 0.0004 or (reach - at).dot(dir) <= 0.0:
			return
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, reach, 1))
		if hit.is_empty():
			return
		if hit.collider is AnimatableBody3D:
			return   # something that moves: a mark would be left hanging in the air
		var went_on := (hit.position as Vector3).distance_to(to) > 0.25
		var cell := breaks.cell_at(hit.collider, hit.position, hit.normal) if breaks else -1
		if cell >= 0 and breaks.material_of(cell) == "glass":
			return
		if went_on and cell < 0:
			return   # (the round did not stop here, and nothing but a breakable wall lets one through)
		if burns:
			mark(hit.position, hit.normal, SCORCH, size * 1.6, cell)
		else:
			mark(hit.position, hit.normal, HOLE if went_on else POCK, size * (1.15 if went_on else 1.0), cell)
		if not went_on:
			return
		var panel: Dictionary = breaks.panels[breaks.cells[cell].panel]
		var face: Vector3 = (panel.xf as Transform3D).basis[panel.thin].normalized()
		var thick: float = (panel.size as Vector3)[panel.thin] / maxf(absf(dir.dot(face)), 0.2)
		var out: Vector3 = (hit.position as Vector3) + dir * thick
		mark(out, -(hit.normal as Vector3), SCORCH if burns else HOLE, size * 1.5, cell)   # (it tears a bigger hole on the way out)
		at = out + dir * 0.02


## An explosion at `at`: a scorch on each surface near it.
func scorch(at: Vector3, radius: float) -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var reach := clampf(radius * 0.4, 0.6, 2.4)
	var breaks := root.destruction
	for dir: Vector3 in [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at - dir * 0.1, at + dir * reach, 1))
		if hit.is_empty() or hit.collider is AnimatableBody3D:
			continue
		var d := (hit.position as Vector3).distance_to(at)
		var cell := breaks.cell_at(hit.collider, hit.position, hit.normal) if breaks else -1
		mark(hit.position, hit.normal, SCORCH, radius * 0.9 * (1.0 - 0.5 * d / reach), cell, 0.85)


## A heavy blow that landed on the map at `at`: a dent.
func dent(at: Vector3, normal: Vector3, size: float = 0.35) -> void:
	var breaks := root.destruction
	mark(at, normal, DENT, size, -1 if breaks == null else breaks.cell_near(at, normal))


## Walls cracked or broke: a cracked cell gets its cracks (both faces), and every mark
## on a cell that is gone goes too.
func _on_cells_changed(cells: PackedInt32Array, stages: PackedByteArray) -> void:
	var breaks := root.destruction
	for i in mini(cells.size(), stages.size()):
		var c := cells[i]
		var stage := int(stages[i])
		if c < 0 or c >= breaks.cells.size():
			continue
		if stage == 0 or stage >= MapDestruction.BROKEN:
			_uncrack(c)
			if stage != 0:
				for slot: int in _by_cell.get(c, []).duplicate():
					_marks.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
					_forget(slot)
					_shown[slot] = 0
			continue
		var panel: Dictionary = breaks.panels[breaks.cells[c].panel]
		if not panel.fine or panel.material == "glass" or panel.get("frame") != null:
			continue
		var pair: int = _crack_at.get(c, -1)
		if pair < 0:
			pair = _next_crack
			_next_crack = (_next_crack + 1) % MAX_CRACKS
			if _crack_of[pair] >= 0:
				_crack_at.erase(_crack_of[pair])
			_crack_of[pair] = c
			_crack_at[c] = pair
		# One square the size of the cell on each face (so no crack hangs over a hole
		# beside it), turned and picked by the cell's number: the same on every copy.
		var xf: Transform3D = panel.xf
		var u: int = panel.u
		var v: int = panel.v
		var thin: int = panel.thin
		var box: AABB = breaks._local_box(panel, breaks.cells[c].ijk)
		var half: float = (panel.size as Vector3)[thin] * 0.5
		for skin in panel.skins:   # (a skin on the face: the cracks go on top of it)
			var sb: AABB = skin.box
			half = maxf(half, maxf(absf(sb.position[thin]), absf(sb.end[thin])))
		var pick := hash(c)
		var picture := (CRACK if stage == 1 else CRACK_BAD) + (pick >> 2 & 1)
		var turned := (pick & 1) == 1
		var flipped := (pick >> 1 & 1) == 1
		for side in 2:
			var out := 1.0 if side == 0 else -1.0
			var x := Vector3.ZERO   # the square's own axes, in the panel's frame
			var y := Vector3.ZERO
			var z := Vector3.ZERO
			x[u] = box.size[u] * (-1.0 if flipped else 1.0)
			y[v] = box.size[v] * (-1.0 if flipped else 1.0) * out   # (so it faces out on both faces)
			z[thin] = out
			if turned and absf(box.size[u] - box.size[v]) < 0.1:
				var was := x
				x = y.normalized() * was.length()
				y = -was.normalized() * y.length()
			var centre := box.get_center()
			centre[thin] = out * (half + OFF)
			_cracks.set_instance_transform(pair * 2 + side, xf * Transform3D(Basis(x, y, z), centre))
			_cracks.set_instance_custom_data(pair * 2 + side, Color(picture, 1.0, 0, 0))
			_cracks.set_instance_color(pair * 2 + side, Color.WHITE)
		made += 1


func _uncrack(cell: int) -> void:
	var pair: int = _crack_at.get(cell, -1)
	if pair < 0:
		return
	_crack_at.erase(cell)
	_crack_of[pair] = -1
	for side in 2:
		_cracks.set_instance_transform(pair * 2 + side, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))


## How many marks are drawn now: [pocks, holes and scorches, cracked cells] (tests).
func counts() -> Array:
	return [_shown.count(1), _crack_at.size()]


# ---------------------------------------------------------------------------
# The pictures

static func _material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 tiles = vec2(4.0, 2.0);
varying float strength;
void vertex() {
	float tile = floor(INSTANCE_CUSTOM.x + 0.5);
	vec2 corner = vec2(mod(tile, tiles.x), floor(tile / tiles.x));
	// (a little in from the tile's edge, so its neighbours never bleed in)
	UV = (corner + 0.5 + (UV - 0.5) * 0.97) / tiles;
	strength = INSTANCE_CUSTOM.y;
}
void fragment() {
	vec4 t = texture(atlas, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a * strength;
	ROUGHNESS = 1.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("atlas", atlas())
	m.set_shader_parameter("tiles", Vector2(TILES))
	return m


## The one texture: every picture, drawn once when first wanted.
static func atlas() -> ImageTexture:
	if _atlas:
		return _atlas
	var img := Image.create(TILE * TILES.x, TILE * TILES.y, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 5.5 / TILE
	var dark := Color(0.07, 0.07, 0.08)
	for picture: int in [POCK, HOLE, SCORCH, DENT]:
		var corner := Vector2i(picture % TILES.x, picture / TILES.x) * TILE
		for y in TILE:
			for x in TILE:
				var p := (Vector2(x + 0.5, y + 0.5) / TILE - Vector2(0.5, 0.5)) * 2.0
				var r := p.length() + noise.get_noise_2d(x + picture * 191.0, y) * 0.22
				var c := Color(0, 0, 0, 0)
				match picture:
					POCK:   # a dark dint with a paler chipped rim
						if r < 0.27:
							c = Color(0.09, 0.09, 0.09, 0.92)
						elif r < 0.66:
							c = Color(0.84, 0.84, 0.82, 0.62 * smoothstep(0.66, 0.4, r))
					HOLE:   # black through the middle, a dark torn rim, then chipped paler
						if r < 0.34:
							c = Color(0.01, 0.01, 0.015, 1.0)
						elif r < 0.5:
							c = Color(0.17, 0.16, 0.15, 0.85)
						elif r < 0.78:
							c = Color(0.8, 0.8, 0.78, 0.5 * smoothstep(0.78, 0.52, r))
					SCORCH:
						c = Color(0.05, 0.045, 0.04, 0.62 * smoothstep(0.92, 0.15, r))
					DENT:   # a crushed patch: paler dust, a dark middle
						if r < 0.25:
							c = Color(0.2, 0.2, 0.2, 0.55)
						elif r < 0.8:
							c = Color(0.9, 0.9, 0.88, 0.35 * smoothstep(0.8, 0.3, r))
				img.set_pixel(corner.x + x, corner.y + y, c)
		if picture == POCK or picture == HOLE:   # a few short cracks out from the rim
			for a in 5:
				var angle := TAU * a / 5.0 + rng.randf_range(-0.4, 0.4)
				var from := Vector2(TILE, TILE) * 0.5 + Vector2.from_angle(angle) * TILE * (0.14 if picture == POCK else 0.25)
				_crack_line(img, corner, from, from + Vector2.from_angle(angle) * TILE * rng.randf_range(0.12, 0.24), dark, 0.75, 0.6, rng)
	# Cracks: each runs from near the middle of its tile to the middle of an edge, so the
	# cracks of two cracked cells side by side meet, whichever way each is turned.
	var mids := [Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5), Vector2(0.5, 0.0)]
	for picture: int in [CRACK, CRACK_2, CRACK_BAD, CRACK_BAD_2]:
		var corner := Vector2i(picture % TILES.x, picture / TILES.x) * TILE
		var bad: bool = picture >= CRACK_BAD
		var middle := Vector2(TILE, TILE) * (Vector2(0.5, 0.5) + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12)))
		var edges := [0, 1, 2, 3] if bad else ([0, 2] if picture == CRACK else [0, 1, 2])
		for e: int in edges:
			var to: Vector2 = mids[e] * TILE
			_crack_line(img, corner, middle, to, dark, 0.9, 1.3 if bad else 0.8, rng)
			for twig in (2 if bad else 1):   # side cracks off it
				var t := rng.randf_range(0.25, 0.8)
				var from := middle.lerp(to, t)
				var angle := (to - middle).angle() + rng.randf_range(0.5, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
				_crack_line(img, corner, from, from + Vector2.from_angle(angle) * TILE * rng.randf_range(0.12, 0.3), dark, 0.7, 0.6, rng)
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


## A wandering crack from `from` to `to` (pixels in the tile at `corner`), `width` pixels
## wide at the start and thinner towards its end.
static func _crack_line(img: Image, corner: Vector2i, from: Vector2, to: Vector2, color: Color, alpha: float, width: float,
		rng: RandomNumberGenerator) -> void:
	var length := from.distance_to(to)
	var steps := maxi(2, int(length * 2.0))
	var side := (to - from).orthogonal().normalized()
	var sway := rng.randf_range(0.0, TAU)
	var bends := rng.randf_range(1.5, 3.0)
	var drift := 0.0
	for k in steps + 1:
		var t := float(k) / steps
		drift = clampf(drift + rng.randf_range(-0.35, 0.35), -2.5, 2.5)
		# (pinned at both ends: it starts and stops exactly where it was asked to)
		var off := (sin(sway + t * bends * TAU) * length * 0.06 + drift) * sin(t * PI)
		var at := from.lerp(to, t) + side * off
		var w := width * (1.0 - 0.45 * t)
		var reach := int(ceil(w))
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var px := Vector2i(floori(at.x) + dx, floori(at.y) + dy)
				if px.x < 1 or px.y < 1 or px.x >= TILE - 1 or px.y >= TILE - 1:
					continue
				var cover := clampf(w + 0.5 - Vector2(dx, dy).length(), 0.0, 1.0) * alpha
				var was := img.get_pixel(corner.x + px.x, corner.y + px.y)
				if cover > was.a or was.get_luminance() > 0.3:
					img.set_pixel(corner.x + px.x, corner.y + px.y, Color(color.r, color.g, color.b, maxf(cover, was.a * (1.0 - cover))))
