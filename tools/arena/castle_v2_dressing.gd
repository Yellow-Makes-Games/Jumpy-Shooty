extends SceneTree
## RETIRED: game/maps/castle_v2.tscn is edited by hand now (blocks were moved in the
## editor), and this script would overwrite that work, so it refuses to run unless
## CASTLE_V2_REBUILD=1 is set. It is kept as a record of how the map was laid out.
##
## Dresses game/maps/castle_v2.tscn: adds the drawn-only detail on top of the block-out.
##
##   godot --headless --path . --script tools/arena/castle_v2_dressing.gd
##
## It changes nothing the block-out made. Almost every piece it adds is drawn only; the
## ones wrapped in hard() below are solid: the canopy roofs with their beams and
## brackets, the counters, racks, troughs, basins and tubs under them, the well head,
## the market booth awning and sacks, the crane jib, the hall benches and
## fireplace, and the gatehouse winch. The spawns and pickups stay where they were.
## What it adds, each inside the object it belongs to:
##  - curtain walls: merlon copings, a string course, pilasters, torches, ivy, weeds,
##    and treads on the wall stairs;
##  - bastions: paving, courses, a flag in the quarter's colour and a beacon;
##  - the gatehouse: arch, portcullis, shields, lit windows, a winch, roof pennants;
##  - the keep: door frames, plinth, courses, quoins, windows, banners, a furnished
##    hall, treads on its ramps, a kerb round the roof opening, the turret's mast;
##  - bridges: fascias, braces, lanterns, and pennants in the colours of the two
##    quarters either side;
##  - each quarter (stables gold, training yard red, well court blue, market green):
##    a canopy against its free wall with its fittings, its climb chain framed in
##    timber, its theme pieces finished, and paint on the ground;
##  - outside: a postern, steps and a jetty under the north wall.
## Everything it adds carries the meta "dressing" (on the top node of each piece), and
## a new run first removes all of that, so it can be run again. After the block-out
## script (which starts over from the old Castle) run this again. Once the dressing is
## edited by hand, stop running both.
##
## The rules it keeps (tests/map_flicker_test.gd checks them): a detail stands proud of
## the surface behind it; two details of different kinds never share a plane; paint on
## the ground is 2 cm thick or more, each kind at its own height. Nothing touches the
## two breakable hoardings.

const SCENE := "res://game/maps/castle_v2.tscn"
const MARK := "dressing"

const FACE := 37.5        ## the walls' outer faces
const INNER := 34.5       ## the walls' inner faces
const WALK := 6.0         ## the wall walk, bridges and keep upper floor
const KEEP := 9.0         ## the keep's outer faces
const KEEP_TOP := 12.0    ## the keep's roof
const BASTION := 33.0     ## the corner bastions' centres

const SIDES := ["North", "East", "South", "West"]
const QUARTERS := ["NorthEast", "SouthEast", "SouthWest", "NorthWest"]
const THEMES := ["Stables", "TrainingYard", "Well", "Market"]
## Each quarter's colour, in the same order.
const COLOURS := ["banner_gold", "banner_red", "banner_blue", "banner_green"]

const BOX := MapBlock.Shape.BOX
const CYLINDER := MapBlock.Shape.CYLINDER
const TUBE := MapBlock.Shape.TUBE

## Quarter turns clockwise seen from above (north to east to south to west).
var Q := [Basis.IDENTITY,
	Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
	Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)),
	Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))]
## Lays a cylinder on its side: its axis along x, or along z.
var AXIS_X := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
var AXIS_Z := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))

var scn: Node3D
var block_script: Script
var rng := RandomNumberGenerator.new()
var count := 0
var solid_count := 0


func _init() -> void:
	# The scene is edited by hand now: a run would throw those edits away.
	if OS.get_environment("CASTLE_V2_REBUILD") != "1":
		printerr("castle_v2.tscn is edited by hand now and this script would overwrite that work. " +
			"It is kept as a record of how the map was laid out. To run it anyway, set CASTLE_V2_REBUILD=1.")
		quit(1)
		return
	block_script = load("res://game/arena/map_block.gd")
	scn = (load(SCENE) as PackedScene).instantiate()
	scn.scene_file_path = ""
	rng.seed = 20261117
	var removed := 0
	for n in scn.find_children("*", "", true, false):
		if is_instance_valid(n) and n.has_meta(MARK):
			n.get_parent().remove_child(n)
			n.free()
			removed += 1
	walls()
	bastions()
	gatehouse()
	keep()
	bridges()
	ground()
	quarters()
	outside()
	var ps := PackedScene.new()
	var err := ps.pack(scn)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	print("DRESSING: saved %s (%s): %d old pieces removed, %d blocks added (%d solid)" % [SCENE, error_string(err), removed, count, solid_count])
	scn.free()
	quit(0 if err == OK else 1)


# -- helpers -------------------------------------------------------------------------
func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


func turn(p: Vector3, quarters: int) -> Vector3:
	for i in posmod(quarters, 4):
		p = Vector3(-p.z, p.y, p.x)
	return p


func gx(x: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while x != null and x != scn:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t


## Adds a node; the top node of each added piece is marked so a new run can remove it.
func _own(n: Node, parent: Node) -> void:
	parent.add_child(n, true)
	n.owner = scn
	var up := parent
	while up != null and up != scn:
		if up.has_meta(MARK):
			return
		up = up.get_parent()
	n.set_meta(MARK, true)


func grp(parent: Node, name: String) -> Node3D:
	var g := parent.get_node_or_null(name) as Node3D
	if g == null:
		g = Node3D.new()
		g.name = name
		_own(g, parent)
	return g


## A small thing you move as one: a group standing at `at` (frame `q`), its own +z
## pointing the way north-frame +z points after `q` quarter turns.
func thing(parent: Node, name: String, q: int, at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = name
	_own(g, parent)
	g.transform = gx(parent).affine_inverse() * Transform3D(Q[posmod(q, 4)], turn(at, q))
	g.set_meta("_edit_group_", true)
	return g


## A drawn-only block in its parent's own frame.
func part(parent: Node, name: String, kind: String, size: Vector3, at: Vector3, rot := Basis.IDENTITY, shape := BOX, sides := 12) -> MapBlock:
	var b: MapBlock = block_script.new()
	b.name = name
	b.shape = shape
	b.size = size
	b.kind = kind
	b.solid = false
	if shape != BOX:
		b.sides = sides
	_own(b, parent)
	b.transform = Transform3D(rot, at)
	count += 1
	return b


## Makes a piece solid: you bump into it and stand on it.
func hard(b: MapBlock) -> MapBlock:
	b.solid = true
	solid_count += 1
	return b


## A drawn-only block given in the north frame and turned `q` quarters.
func qpart(parent: Node, name: String, kind: String, q: int, size: Vector3, at: Vector3, rot := Basis.IDENTITY, shape := BOX, sides := 12) -> MapBlock:
	var b := part(parent, name, kind, size, Vector3.ZERO, Basis.IDENTITY, shape, sides)
	b.transform = gx(parent).affine_inverse() * Transform3D(Q[posmod(q, 4)] * rot, turn(at, q))
	return b


func qb(parent: Node, name: String, kind: String, q: int, lo: Vector3, hi: Vector3) -> MapBlock:
	return qpart(parent, name, kind, q, (hi - lo).abs(), (lo + hi) * 0.5)


## An upright cylinder standing on `base`.
func qcyl(parent: Node, name: String, kind: String, q: int, base: Vector3, diameter: float, height: float, sides := 12) -> MapBlock:
	return qpart(parent, name, kind, q, Vector3(diameter, height, diameter), base + Vector3(0, height * 0.5, 0), Basis.IDENTITY, CYLINDER, sides)


## A cylinder on its side, centred on `centre`, its axis along "x" or "z".
func qround(parent: Node, name: String, kind: String, q: int, centre: Vector3, diameter: float, length: float, axis: String, sides := 14) -> MapBlock:
	return qpart(parent, name, kind, q, Vector3(diameter, length, diameter), centre, AXIS_X if axis == "x" else AXIS_Z, CYLINDER, sides)


func slope_basis(a: Vector3, b: Vector3) -> Basis:
	var along := (b - a).normalized()
	var across := Vector3.UP.cross(along)
	if across.length() < 0.001:
		across = Vector3.RIGHT
	across = across.normalized()
	return Basis(across, along.cross(across), along)


## A beam whose centre line runs from `a` to `b`.
func qbeam(parent: Node, name: String, kind: String, q: int, a: Vector3, b: Vector3, width: float, thick: float) -> MapBlock:
	return qpart(parent, name, kind, q, Vector3(width, thick, (b - a).length()), (a + b) * 0.5, slope_basis(a, b))


## A slab whose top runs from `a` to `b` (the middle of each end), `width` across.
func qslab(parent: Node, name: String, kind: String, q: int, a: Vector3, b: Vector3, width: float, thick: float) -> MapBlock:
	var bs := slope_basis(a, b)
	return qpart(parent, name, kind, q, Vector3(width, thick, (b - a).length()), (a + b) * 0.5 - bs.y * thick * 0.5, bs)


## Pale strips across a ramp so it reads as a stair. `a` to `b` is the ramp's top.
func treads(parent: Node, q: int, a: Vector3, b: Vector3, width: float) -> void:
	var bs := slope_basis(a, b)
	var n := int((b - a).length() / 0.55)
	for i in n:
		qpart(parent, "Tread", "stone_light", q, Vector3(width, 0.024, 0.09), a.lerp(b, (i + 0.5) / n) + bs.y * 0.012, bs)


## A wall torch: its back on the wall at `at`, pointing along the frame's +z.
func torch(parent: Node, q: int, at: Vector3) -> void:
	var t := thing(parent, "Torch", q, at)
	part(t, "Plate", "iron", V(0.2, 0.3, 0.03), V(0, 0.05, 0.015))
	part(t, "Arm", "iron", V(0.08, 0.08, 0.34), V(0, 0.04, 0.17))
	part(t, "Cup", "iron", V(0.22, 0.14, 0.22), V(0, 0.15, 0.3))
	part(t, "Flame", "torch", V(0.16, 0.38, 0.16), V(0, 0.41, 0.3))


func shield(parent: Node, q: int, at: Vector3, kind: String) -> void:
	var s := thing(parent, "Shield", q, at)
	part(s, "Plate", kind, V(0.7, 0.8, 0.06), V(0, 0, 0.03))
	part(s, "Boss", "iron", V(0.2, 0.2, 0.05), V(0, 0, 0.085))


## Thin strips round a box's four sides, from `y0` to `y1`, sitting on its faces.
func ring_band(parent: Node, q: int, lo: Vector3, hi: Vector3, y0: float, y1: float, kind: String, t: float, west := true) -> void:
	qb(parent, "Band", kind, q, V(lo.x, y0, lo.z - t), V(hi.x, y1, lo.z))
	qb(parent, "Band", kind, q, V(lo.x, y0, hi.z), V(hi.x, y1, hi.z + t))
	if west:
		qb(parent, "Band", kind, q, V(lo.x - t, y0, lo.z), V(lo.x, y1, hi.z))
	qb(parent, "Band", kind, q, V(hi.x, y0, lo.z), V(hi.x + t, y1, hi.z))


## Posts on a box's four upright corners, `proud` of both faces and `rise` over the top.
func corner_posts(parent: Node, q: int, lo: Vector3, hi: Vector3, kind: String, thick: float, proud: float, rise: float) -> void:
	for cx in [lo.x, hi.x]:
		for cz in [lo.z, hi.z]:
			var sx := -1.0 if cx == lo.x else 1.0
			var sz := -1.0 if cz == lo.z else 1.0
			qb(parent, "Post", kind, q, V(cx + sx * proud, 0, cz + sz * proud), V(cx - sx * (thick - proud), hi.y + rise, cz - sz * (thick - proud)))


# -- curtain walls ---------------------------------------------------------------------
## In a wall's frame it is the north wall: it runs along x, its inner face is at
## z = -INNER looking +z, the stair climbs from x 12 to 26, and the half from x -29 to
## -6 is free (the quarter before it builds its canopy there).
func walls() -> void:
	for w in 4:
		var side := scn.get_node("Walls/Curtain" + SIDES[w])
		var south := w == 2   # the gatehouse fills the middle 12 m
		var cop := grp(side.get_node("Battlements"), "Copings")
		var u := -30.0
		while u <= 30.0:
			if not (south and absf(u) < 7.0):
				qb(cop, "Coping", "stone_light", w, V(u - 0.77, WALK + 1.2, -FACE - 0.07), V(u + 0.77, WALK + 1.31, -FACE + 0.67))
			u += 3.0
		var course := grp(side, "StringCourse")
		var gap := 6.0 if south else 1.62
		qb(course, "Band", "stone_light", w, V(-BASTION, 5.6, -INNER), V(-gap, 5.85, -INNER + 0.08))
		qb(course, "Band", "stone_light", w, V(gap, 5.6, -INNER), V(BASTION, 5.85, -INNER + 0.08))
		var pil := grp(side, "Pilasters")
		var at := [-24.0, -18.0, -12.0, -6.6 if south else -6.0, 10.0]
		if not south:
			at.append(4.5)
		for x in at:
			var p := thing(pil, "Pilaster", w, V(x, 0, -INNER))
			part(p, "Plinth", "stone_dark", V(0.9, 0.5, 0.25), V(0, 0.25, 0.125))
			part(p, "Shaft", "stone", V(0.7, 5.1, 0.18), V(0, 3.05, 0.09))
			part(p, "Cap", "stone_light", V(0.9, 0.3, 0.26), V(0, 5.7, 0.13))
		var tor := grp(side, "Torches")
		torch(tor, w, V(10.9, 2.9, -INNER))      # the stair's foot
		torch(tor, w, V(27.4, 3.6, -INNER))      # and under its head
		if not south:
			torch(tor, w, V(-3.0, 4.2, -INNER))  # beside the bridge
		torch(tor, w, V(-24.0, 1.9, -INNER + 0.18))
		torch(tor, w, V(-12.0, 1.9, -INNER + 0.18))
		var green := grp(side, "Greenery")
		if not south:
			ivy(green, w, 7.3, 5.5, 3.2)
		ivy(green, w, -21.0, 5.5, 0.9)
		ivy(green, w, -9.0, 5.5, 0.9)
		for span in [[2.3, 3.9], [6.3, 9.3], [26.4, 28.4]]:
			if south and span[0] < 6.0:
				continue
			for i in 2:
				var wd := rng.randf_range(0.25, 0.5)
				var h := rng.randf_range(0.15, 0.4)
				var x := rng.randf_range(span[0], span[1])
				qb(green, "Weeds", "grass", w, V(x - wd * 0.5, 0, -INNER), V(x + wd * 0.5, h, -INNER + 0.1))
		# The stair: treads, and a kerb along its open edge.
		var st := grp(side, "StairDressing")
		var a := V(12, 0, -INNER + 1.5)
		var b := V(26, WALK, -INNER + 1.5)
		treads(st, w, a, b, 2.6)
		var bs := slope_basis(a, b)
		qpart(st, "Kerb", "stone_light", w, Vector3(0.24, 0.05, (b - a).length()), (a + b) * 0.5 + bs.y * 0.025 + V(0, 0, 1.37), bs)
		qb(st, "LandingKerb", "stone_light", w, V(26, WALK, -INNER + 2.75), V(28.7, WALK + 0.05, -INNER + 2.99))


## Ivy hanging on a wall's inner face from `top`, `drop` metres down.
func ivy(parent: Node, w: int, u: float, top: float, drop: float) -> void:
	var g := thing(parent, "Ivy", w, V(u, 0, -INNER))
	# Dark leaves end on a 10 cm grid and light ones half way between, so an edge of
	# one never lies in the same plane as an edge of the other.
	var y := top
	while y > top - drop:
		var wd := snappedf(rng.randf_range(0.5, 1.2), 0.2)
		var h := snappedf(rng.randf_range(0.5, 1.0), 0.2)
		var x := snappedf(rng.randf_range(-0.3, 0.3), 0.1)
		part(g, "Leaves", "ivy", V(wd, h, 0.06), V(x, y - h * 0.5, 0.03))
		if rng.randf() < 0.6:
			part(g, "Leaves", "ivy_light", V(0.3, 0.3, 0.1), V(x + snappedf(rng.randf_range(-0.2, 0.2), 0.1), y - h * 0.5, 0.05))
		y -= 0.6 if h > 0.7 else 0.4


# -- bastions --------------------------------------------------------------------------
func bastions() -> void:
	for q in 4:
		var b := scn.get_node("Bastions/" + QUARTERS[q])
		var c := V(BASTION, 0, -BASTION)
		var top := grp(b, "Paving")
		qcyl(top, "Paving", "stone_light", q, c + V(0, WALK, 0), 7.0, 0.03, 48)
		qcyl(top, "Pad", "stone_dark", q, c + V(0.5, WALK, -0.5), 2.0, 0.05, 24)
		var courses := grp(b, "Courses")
		qcyl(courses, "Band", "stone_light", q, c + V(0, 5.55, 0), 9.16, 0.25, 48)
		qcyl(courses, "Foot", "stone_dark", q, c, 9.3, 0.6, 48)
		# A flag in the quarter's colour on the outer corner, and a beacon on its pole.
		var f := thing(b, "Flag", q, c + V(3.32, 0, -3.32))
		part(f, "Pole", "wood", V(0.16, 7.0, 0.16), V(0, 8.1, 0), Basis.IDENTITY, CYLINDER, 8)
		for y in [5.0, 5.8]:
			part(f, "Bracket", "iron", V(0.6, 0.08, 0.08), V(-0.18, y, 0.18), Basis(Vector3.UP, PI / 4))
		part(f, "Cloth", COLOURS[q], V(1.9, 1.2, 0.05), V(1.03, 10.9, 0))
		part(f, "Finial", "banner_gold", V(0.24, 0.24, 0.24), V(0, 11.72, 0))
		var beacons := [1.0]
		if q % 2 == 1:
			beacons.append(-1.0)   # the two bastions with the big guns burn two
		for s in beacons:
			part(f, "BeaconArm", "iron", V(0.7, 0.08, 0.08), V(s * 0.25, 6.5, s * 0.25), Basis(Vector3.UP, -PI / 4))
			part(f, "BeaconCup", "iron", V(0.4, 0.22, 0.4), V(s * 0.5, 6.65, s * 0.5))
			part(f, "BeaconFlame", "torch", V(0.28, 0.45, 0.28), V(s * 0.5, 6.985, s * 0.5))


# -- gatehouse -------------------------------------------------------------------------
## In the south wall's frame: its bailey face is at z = -33.5, its outer face at -FACE.
func gatehouse() -> void:
	var g := scn.get_node("Gatehouse")
	var w := 2
	var z := -(INNER - 1.0)
	var arch := grp(g, "Arch")
	for s in [-1.0, 1.0]:
		qb(arch, "Jamb", "stone_light", w, V(s * 2.0, 0, z), V(s * 2.5, 4.5, z + 0.18))
	qb(arch, "Lintel", "stone_light", w, V(-2.5, 4.5, z), V(2.5, 5.0, z + 0.18))
	qb(arch, "Keystone", "stone_dark", w, V(-0.3, 4.4, z), V(0.3, 5.12, z + 0.24))
	var port := grp(g, "Portcullis")
	port.set_meta("_edit_group_", true)
	var u := -1.6
	while u <= 1.61:
		qb(port, "Bar", "iron", w, V(u - 0.04, 0, z + 0.1), V(u + 0.04, 4.5, z + 0.15))
		u += 0.4
	for y in [0.8, 1.7, 2.6, 3.5, 4.3]:
		qb(port, "Rail", "iron", w, V(-2, y - 0.04, z + 0.1), V(2, y + 0.04, z + 0.155))
	# The quarter each side of the gate: red to the east, blue to the west.
	shield(g, w, V(-3.8, 3.3, z), COLOURS[1])
	shield(g, w, V(3.8, 3.3, z), COLOURS[2])
	torch(g, w, V(-3.0, 2.6, z))
	torch(g, w, V(3.0, 2.6, z))
	var win := grp(g, "Windows")
	for s in [-1.0, 1.0]:
		qb(win, "Surround", "stone_light", w, V(s * 3.75 - 0.45, 6.9, z), V(s * 3.75 + 0.45, 8.4, z + 0.06))
		qb(win, "Glass", "glass_lit", w, V(s * 3.75 - 0.25, 7.1, z), V(s * 3.75 + 0.25, 8.2, z + 0.1))
	var winch := grp(g, "Winch")
	winch.set_meta("_edit_group_", true)
	hard(qround(winch, "Drum", "wood", w, V(0, 8.4, -35.5), 0.5, 3.0, "x"))
	qround(winch, "Rope", "rope", w, V(0, 8.4, -35.5), 0.58, 1.1, "x")
	var pen := grp(g, "Pennants")
	for s in [-1.0, 1.0]:
		var p := thing(pen, "Pennant", w, V(s * 5.9, WALK + 3.5, -FACE + 0.3))
		part(p, "Pole", "wood", V(0.12, 2.8, 0.12), V(0, 1.4, 0), Basis.IDENTITY, CYLINDER, 8)
		part(p, "Cloth", COLOURS[1] if s < 0 else COLOURS[2], V(1.2, 0.7, 0.04), V(0.66, 2.4, 0))
	# The gate seen from the causeway.
	var outer := grp(g, "OuterGate")
	qb(outer, "Gate", "door", w, V(-2, 0, -FACE - 0.06), V(2, 4.5, -FACE))
	for s in [-1.0, 1.0]:
		qb(outer, "Jamb", "stone_light", w, V(s * 2.0, 0, -FACE - 0.14), V(s * 2.5, 4.5, -FACE))
	qb(outer, "Lintel", "stone_light", w, V(-2.5, 4.5, -FACE - 0.14), V(2.5, 5.0, -FACE))


# -- keep ------------------------------------------------------------------------------
## In a face's frame it is the north face: outer face at z = -KEEP looking -z, inner
## face at z = -8 looking +z, the doors 3 m wide in the middle on both floors. The +x
## half looks onto quarter `q`, the -x half onto the quarter before it.
func keep() -> void:
	var k := scn.get_node("Keep")
	for q in 4:
		var f := k.get_node(SIDES[q] + "Face")
		var cop := grp(f.get_node("Battlements"), "Copings")
		var u := -7.5
		while u <= 7.6:
			qb(cop, "Coping", "stone_light", q, V(u - 0.67, KEEP_TOP + 1.0, -KEEP - 0.07), V(u + 0.67, KEEP_TOP + 1.1, -KEEP + 0.57))
			u += 2.5
		var doors := grp(f, "DoorFrames")
		for d in [[0.0, 3.5], [WALK, WALK + 3.0]]:
			for s in [-1.0, 1.0]:
				qb(doors, "Jamb", "stone_light", q, V(s * 1.44, d[0], -KEEP - 0.12), V(s * 1.95, d[1] - 0.06, -KEEP + 1.12))
			qb(doors, "Lintel", "stone_light", q, V(-1.95, d[1] - 0.06, -KEEP - 0.12), V(1.95, d[1] + 0.4, -KEEP + 1.12))
		var courses := grp(f, "Courses")
		for s in [-1.0, 1.0]:
			qb(courses, "Plinth", "stone_dark", q, V(s * 1.95, 0, -KEEP - 0.14), V(s * (KEEP + 0.14), 0.7, -KEEP))
			qb(courses, "Band", "stone_light", q, V(s * 1.62, 5.7, -KEEP - 0.08), V(s * (KEEP + 0.08), 5.95, -KEEP))
		qb(courses, "Corbels", "stone_light", q, V(-KEEP - 0.15, 11.2, -KEEP - 0.15), V(KEEP + 0.15, 11.5, -KEEP))
		var quoins := grp(f, "Quoins")
		for i in 10:
			var y := 0.9 + 1.1 * i
			if i % 2 == 0:
				qb(quoins, "Quoin", "stone_light", q, V(KEEP - 0.7, y, -KEEP - 0.06), V(KEEP + 0.06, y + 0.5, -KEEP + 0.4))
			else:
				qb(quoins, "Quoin", "stone_light", q, V(KEEP - 0.4, y, -KEEP - 0.06), V(KEEP + 0.06, y + 0.5, -KEEP + 0.7))
		var win := grp(f, "Windows")
		for s in [-1.0, 1.0]:
			for y in [1.5, 7.5]:
				qb(win, "Surround", "stone_light", q, V(s * 5.5 - 0.3, y, -KEEP - 0.05), V(s * 5.5 + 0.3, y + 1.5, -KEEP))
				qb(win, "Slit", "glass_lit", q, V(s * 5.5 - 0.09, y + 0.2, -KEEP - 0.09), V(s * 5.5 + 0.09, y + 1.3, -KEEP))
		var ban := grp(f, "Banners")
		for s in [-1.0, 1.0]:
			var kind: String = COLOURS[q] if s > 0 else COLOURS[posmod(q - 1, 4)]
			qb(ban, "Banner", kind, q, V(s * 3.3 - 0.5, 9.6, -KEEP - 0.05), V(s * 3.3 + 0.5, 11.0, -KEEP))
			qb(ban, "Rod", "wood", q, V(s * 3.3 - 0.6, 11.0, -KEEP - 0.1), V(s * 3.3 + 0.6, 11.08, -KEEP))
		# Inside: torches and hangings on both floors, benches in the hall.
		var inside := grp(f, "Inside")
		var zi := -KEEP + 1.0
		for s in [-1.0, 1.0]:
			torch(inside, q, V(s * 3.0, 2.6, zi))
			torch(inside, q, V(s * 3.0, 8.0, zi))
			var hang: String = COLOURS[q] if s > 0 else COLOURS[posmod(q - 1, 4)]
			qb(inside, "Hanging", hang, q, V(s * 5.3 - 0.7, 7.0, zi), V(s * 5.3 + 0.7, 9.4, zi + 0.04))
			qb(inside, "Rod", "wood", q, V(s * 5.3 - 0.8, 9.4, zi), V(s * 5.3 + 0.8, 9.48, zi + 0.09))
			if not (q == 2 and s > 0):   # the fireplace stands there
				var bench := thing(inside, "Bench", q, V(s * 5.3, 0, zi))
				hard(part(bench, "Seat", "wood", V(2.4, 0.08, 0.4), V(0, 0.45, 0.2)))
				for e in [-1.0, 1.0]:
					part(bench, "Leg", "wood", V(0.1, 0.41, 0.36), V(e * 1.0, 0.205, 0.2))
	var hall := k.get_node("Hall")
	# The fireplace, on the south wall's inner face.
	var fire := thing(hall, "Fireplace", 2, V(5.0, 0, -KEEP + 1.0))
	hard(part(fire, "Surround", "stone_light", V(2.0, 1.8, 0.3), V(0, 0.9, 0.15)))
	part(fire, "Opening", "shadow", V(1.2, 1.2, 0.32), V(0, 0.6, 0.16))
	part(fire, "Logs", "wood", V(0.8, 0.15, 0.4), V(0, 0.075, 0.2))
	part(fire, "Fire", "torch", V(0.5, 0.4, 0.36), V(0, 0.35, 0.18))
	hard(part(fire, "Mantel", "stone_dark", V(2.3, 0.13, 0.45), V(0, 1.865, 0.225)))
	hard(part(fire, "Breast", "stone", V(1.4, 3.67, 0.2), V(0, 3.765, 0.1)))
	var rug := grp(hall, "Rug")
	rug.set_meta("_edit_group_", true)
	qb(rug, "Border", "banner_gold", 0, V(-2.6, 0, 3.4), V(2.6, 0.05, 7.4))
	qb(rug, "Field", "banner_red", 0, V(-2.4, 0, 3.6), V(2.4, 0.06, 7.2))
	var lamp := thing(hall, "Chandelier", 0, V(0, 0, 5.4))
	part(lamp, "Chain", "iron", V(0.05, 1.2, 0.05), V(0, 5.0, 0))
	part(lamp, "Ring", "iron", V(1.8, 0.1, 1.8), V(0, 4.35, 0), Basis.IDENTITY, TUBE, 12).inner = 1.6
	for i in 4:
		part(lamp, "Flame", "torch", V(0.12, 0.26, 0.12), turn(V(0.85, 4.53, 0), i))
	var hall_ramp := grp(hall, "RampDressing")
	treads(hall_ramp, 0, V(5.5, 0, -3), V(-5.5, WALK, -3), 2.2)
	var roof_ramp := grp(k.get_node("UpperFloor"), "RampDressing")
	treads(roof_ramp, 0, V(-5.5, WALK, 3), V(5.5, KEEP_TOP, 3), 2.2)
	# The roof: a kerb round the opening over the ramp, and the turret's mast.
	var roof := k.get_node("Roof")
	var kerb := grp(roof, "Kerb")
	qb(kerb, "Kerb", "stone_light", 0, V(-5.7, KEEP_TOP, 1.55), V(5.7, KEEP_TOP + 0.03, 1.75))
	qb(kerb, "Kerb", "stone_light", 0, V(-5.7, KEEP_TOP, 4.25), V(5.7, KEEP_TOP + 0.03, 4.45))
	qb(kerb, "Kerb", "stone_light", 0, V(-5.7, KEEP_TOP, 1.75), V(-5.5, KEEP_TOP + 0.03, 4.25))
	qb(kerb, "Kerb", "stone_light", 0, V(5.5, KEEP_TOP, 1.75), V(5.7, KEEP_TOP + 0.03, 4.25))
	var mast := thing(roof, "Mast", 0, V(0, KEEP_TOP + 1.6, -4))
	part(mast, "Coping", "stone_light", V(3.14, 0.12, 3.14), V(0, 0.06, 0))
	part(mast, "Pole", "wood", V(0.2, 5.6, 0.2), V(0, 2.92, 0), Basis.IDENTITY, CYLINDER, 8)
	part(mast, "Cloth", "banner_gold", V(0.05, 1.5, 2.6), V(0, 4.9, -1.4))
	part(mast, "Finial", "banner_gold", V(0.28, 0.28, 0.28), V(0, 5.86, 0))
	for i in 4:
		var at := turn(V(1.3, 0, -1.3), i)
		part(mast, "Cup", "iron", V(0.3, 0.15, 0.3), at + V(0, 0.195, 0))
		part(mast, "Flame", "torch", V(0.2, 0.35, 0.2), at + V(0, 0.445, 0))


# -- bridges ---------------------------------------------------------------------------
func bridges() -> void:
	for q in 4:
		var g := scn.get_node("Bridges/" + SIDES[q])
		var end := INNER - (1.0 if q == 2 else 0.0)
		var mid := (end + KEEP) * 0.5
		var timber := grp(g, "Timber")
		for s in [-1.0, 1.0]:
			qb(timber, "Fascia", "wood", q, V(s * 1.5, WALK - 0.45, -end), V(s * 1.6, WALK + 0.04, -KEEP))
			qbeam(timber, "Brace", "wood", q, V(0, 3.4, -mid + s * 0.5), V(0, 5.62, -mid + s * 2.9), 0.18, 0.18)
			qbeam(timber, "Brace", "wood", q, V(s * 0.5, 4.3, -mid), V(s * 1.4, 5.62, -mid), 0.18, 0.18)
		var pier := grp(g, "PierDressing")
		qb(pier, "Plinth", "stone_dark", q, V(-0.7, 0, -mid - 0.7), V(0.7, 0.5, -mid + 0.7))
		qb(pier, "Cap", "stone_light", q, V(-0.65, 5.4, -mid - 0.65), V(0.65, 5.7, -mid + 0.65))
		# Pennants under each edge, in the colour of the quarter that edge looks onto.
		var pen := grp(g, "Pennants")
		var z := -end + 2.0
		while z < -KEEP - 1.5:
			for s in [-1.0, 1.0]:
				if s > 0 and z > -24.6 and z < -20.4:
					continue   # the climb chain comes up here
				var kind: String = COLOURS[q] if s > 0 else COLOURS[posmod(q - 1, 4)]
				qb(pen, "Pennant", kind, q, V(s * 1.6, 4.85, z - 0.25), V(s * 1.63, 5.55, z + 0.25))
			z += 2.5
		for s in [-1.0, 1.0]:
			var l := thing(g, "Lantern", q, V(s * 1.56, WALK + 0.04, -mid))
			part(l, "Post", "iron", V(0.08, 1.16, 0.08), V(0, 0.58, 0))
			part(l, "Lamp", "glass_lit", V(0.2, 0.26, 0.2), V(0, 1.29, 0))
			part(l, "Cap", "iron", V(0.26, 0.05, 0.26), V(0, 1.445, 0))


# -- the ground --------------------------------------------------------------------------
func ground() -> void:
	var p := grp(scn.get_node("Ground"), "Paint")
	# Flagstones under and round the keep, and a worn track from each door to its wall.
	qb(p, "KeepPaving", "stone_light", 0, V(-12, 0, -12), V(12, 0.035, 12))
	for q in 4:
		var half := 2.2 if q == 2 else 1.3
		var end := INNER - (1.0 if q == 2 else 0.0)
		qb(p, "Track", "dirt", q, V(-half, 0, -end), V(half, 0.02, -12))


# -- quarters --------------------------------------------------------------------------
## In a quarter's frame it is the north-east one: its stair is on the north wall, its
## free wall is the east one (x = INNER), the bridge on its north side runs along x = 0.
func quarters() -> void:
	for q in 4:
		var g := scn.get_node("Quarters/" + QUARTERS[q] + THEMES[q])
		var d := grp(g, "Dressing")
		# The wall-run wall keeps flat faces: a coping only (and thin paint, per theme).
		qb(d, "WallRunCoping", "stone_light", q, V(21.5, 4.5, -22.1), V(22.5, 4.66, -11.9))
		qb(d, "LowWallCoping", "stone_light", q, V(12.94, 1.2, -13.86), V(17.06, 1.3, -13.14))
		qb(d, "LowWallCoping", "stone_light", q, V(26.64, 1.2, -10.06), V(27.36, 1.3, -5.94))
		var battens := grp(d, "CrateBattens")
		corner_posts(battens, q, V(26.4, 0, -27.6), V(27.6, 1.2, -26.4), "wood_light", 0.1, 0.02, 0.02)
		corner_posts(battens, q, V(27.8, 0, -27.2), V(28.9, 1.1, -26.1), "wood_light", 0.1, 0.02, 0.02)
		for i in 8:
			var wd := rng.randf_range(0.25, 0.45)
			var h := rng.randf_range(0.15, 0.35)
			var z := rng.randf_range(-21.6, -12.4)
			if i % 2 == 0:
				qb(d, "Weeds", "grass", q, V(21.5, 0, z), V(21.6, h, z + wd))
			else:
				qb(d, "Weeds", "grass", q, V(22.4, 0, z), V(22.5, h, z + wd))
		# The climb chain, framed in timber.
		var chain := grp(g.get_node("ClimbChain"), "Dressing")
		var low := [V(4.6, 0, -25), V(8.6, 2.2, -20)]
		var high := [V(1.6, 0, -24), V(4.6, 4.2, -21)]
		for blk in [low, high]:
			corner_posts(chain, q, blk[0], blk[1], "wood", 0.2, 0.03, 0.02)
			ring_band(chain, q, blk[0], blk[1], blk[1].y - 0.16, blk[1].y + 0.02, "wood", 0.03, blk != low)   # the low block's west face is against the high one
		ring_band(chain, q, high[0], high[1], 2.0, 2.16, "wood", 0.03)
		var theme := g.get_node(THEMES[q])
		var paint := grp(g, "GroundPaint")
		match THEMES[q]:
			"Stables":
				stables(q, grp(theme, "Dressing"), chain, paint)
			"TrainingYard":
				training_yard(q, grp(g, "YardDressing"), chain, paint)
			"Well":
				well(q, grp(theme, "Dressing"), chain, paint)
			"Market":
				market(q, grp(theme, "Dressing"), chain, paint)
		canopy(q, grp(g, "Canopy"))


## A cart wheel on a face that looks along x.
func wheel(parent: Node, q: int, centre: Vector3, diameter: float) -> void:
	qround(parent, "Wheel", "wood", q, centre, diameter, 0.14, "x", 16)
	qround(parent, "Hub", "iron", q, centre, 0.22, 0.2, "x", 8)


func stables(q: int, d: Node3D, chain: Node3D, paint: Node3D) -> void:
	# The cart: wheels, side rails, shafts.
	for x in [16.7, 18.5]:
		for z in [-28.56, -26.84]:
			qround(d, "Wheel", "wood", q, V(x, 0.5, z), 1.0, 0.12, "z", 16)
			qround(d, "Hub", "iron", q, V(x, 0.5, z), 0.2, 0.17, "z", 8)
	qb(d, "Rail", "wood_light", q, V(16, 1.1, -28.5), V(19.2, 1.45, -28.44))
	qb(d, "Rail", "wood_light", q, V(16, 1.1, -26.96), V(19.2, 1.45, -26.9))
	qb(d, "Rail", "wood_light", q, V(16, 1.1, -28.44), V(16.06, 1.45, -26.96))
	for z in [-28.3, -27.1]:
		qbeam(d, "Shaft", "wood", q, V(16, 0.9, z), V(14.3, 0.12, z), 0.1, 0.1)
	# Rope round the hay bales.
	for x in [21.0, 21.9]:
		qb(d, "BaleRope", "rope", q, V(x, 0, -29.02), V(x + 0.08, 1.12, -27.78))
		qb(d, "BaleRope", "rope", q, V(x + 0.03, 1.12, -28.92), V(x + 0.11, 2.12, -27.88))
	# The climb chain: a hay wagon, then a hayloft with a ladder.
	qb(chain, "HayTop", "hay", q, V(4.8, 2.2, -24.8), V(8.4, 2.23, -20.2))
	qb(chain, "HayTop", "hay", q, V(1.8, 4.2, -23.8), V(4.4, 4.23, -21.2))
	wheel(chain, q, V(8.67, 0.65, -23.8), 1.3)
	wheel(chain, q, V(8.67, 0.65, -21.2), 1.3)
	var ladder := grp(chain, "Ladder")
	ladder.set_meta("_edit_group_", true)
	for x in [2.6, 3.4]:
		qb(ladder, "Rail", "wood", q, V(x, 0, -21), V(x + 0.08, 4.2, -20.92))
	var y := 0.4
	while y < 4.1:
		qb(ladder, "Rung", "wood", q, V(2.68, y, -20.98), V(3.4, y + 0.05, -20.94))
		y += 0.4
	qb(paint, "Dirt", "dirt", q, V(13, 0, -30.5), V(25, 0.02, -25))
	qb(paint, "Straw", "hay", q, V(32.4, 0, -28.4), V(INNER, 0.03, -6))
	for i in 7:
		# On a grid no other piece's edge is on.
		var x := snappedf(rng.randf_range(12, 29), 0.1) + 0.05
		var z := snappedf(rng.randf_range(-30.5, -12), 0.1) + 0.05
		qb(paint, "Straw", "hay", q, V(x, 0, z), V(x + snappedf(rng.randf_range(0.6, 1.5), 0.1), 0.03, z + snappedf(rng.randf_range(0.5, 1.2), 0.1)))


func training_yard(q: int, d: Node3D, chain: Node3D, paint: Node3D) -> void:
	# Archery targets painted on the wall-run wall's inner face.
	for z in [-20.0, -17.0, -14.0]:
		qb(d, "TargetRing", "cloth", q, V(21.57, 1.0, z - 0.6), V(21.6, 2.2, z + 0.6))
		qb(d, "TargetRed", "banner_red", q, V(21.555, 1.25, z - 0.35), V(21.6, 1.95, z + 0.35))
		qb(d, "TargetGold", "banner_gold", q, V(21.54, 1.48, z - 0.12), V(21.6, 1.72, z + 0.12))
	# The climb chain: a draped stand, then a tower with a pennon.
	qb(chain, "Drape", "banner_red", q, V(5.0, 0.7, -20), V(8.2, 1.9, -19.96))
	qb(chain, "Drape", "banner_red", q, V(8.6, 0.7, -24.6), V(8.64, 1.9, -20.4))
	qcyl(chain, "PennonPole", "wood", q, V(1.75, 4.22, -21.15), 0.1, 2.4, 8)
	qb(chain, "Pennon", "banner_red", q, V(1.8, 6.05, -21.17), V(2.7, 6.55, -21.13))
	qb(paint, "Sand", "sand", q, V(11, 0, -31), V(31, 0.025, -10))
	qb(paint, "Chalk", "cloth", q, V(15.5, 0, -21), V(15.62, 0.04, -14.5))


func well(q: int, d: Node3D, chain: Node3D, paint: Node3D) -> void:
	var c := V(19, 0, -27)
	qpart(d, "Rim", "stone_dark", q, V(3.0, 0.12, 3.0), c + V(0, 1.16, 0), Basis.IDENTITY, TUBE, 20).inner = 2.2
	qcyl(d, "Water", "water", q, c + V(0, 1.1, 0), 2.2, 0.04, 20)
	for s in [-1.0, 1.0]:
		hard(qb(d, "Post", "wood", q, c + V(s * 1.3 - 0.1, 1.22, -0.1), c + V(s * 1.3 + 0.1, 3.2, 0.1)))
	hard(qb(d, "Beam", "wood", q, c + V(-1.5, 3.2, -0.1), c + V(1.5, 3.36, 0.1)))
	hard(qround(d, "Windlass", "wood", q, c + V(0, 2.6, 0), 0.26, 2.4, "x", 10))
	qb(d, "Rope", "rope", q, c + V(-0.02, 1.6, -0.02), c + V(0.02, 2.5, 0.02))
	qcyl(d, "Bucket", "wood", q, c + V(0, 1.3, 0), 0.36, 0.34, 10)
	for s in [-1.0, 1.0]:
		hard(qslab(d, "Roof", "slate", q, c + V(0, 4.0, 0), c + V(0, 3.3, s * 1.0), 3.4, 0.08))
	# A spout and its streak on the wall-run wall (thin, so the wall stays flat).
	qb(d, "Spout", "stone_light", q, V(21.35, 3.0, -17.2), V(21.6, 3.25, -16.8))
	qb(d, "Streak", "water", q, V(21.57, 0, -17.1), V(21.6, 3.0, -16.9))
	# The climb chain: an iron-bound cistern, then a crane.
	var low := [V(4.6, 0, -25), V(8.6, 2.2, -20)]
	ring_band(chain, q, low[0], low[1], 0.6, 0.72, "iron", 0.035)
	ring_band(chain, q, low[0], low[1], 1.5, 1.62, "iron", 0.035)
	qb(chain, "Drape", "banner_blue", q, V(5.4, 0.8, -20), V(7.8, 1.4, -19.955))
	hard(qbeam(chain, "Jib", "wood", q, V(4.4, 4.3, -23.9), V(7.5, 6.2, -26.5), 0.22, 0.22))
	qb(chain, "JibRope", "rope", q, V(7.48, 3.9, -26.52), V(7.52, 6.15, -26.48))
	qb(chain, "Hook", "iron", q, V(7.42, 3.7, -26.53), V(7.58, 3.9, -26.47))
	qcyl(paint, "Flagstones", "stone_light", q, c, 7.5, 0.035, 24)
	for at in [V(15.5, 0, -23.5), V(22.8, 0, -24.2), V(17.2, 0, -30.2)]:
		qcyl(paint, "Puddle", "water", q, at, rng.randf_range(0.8, 1.5), 0.05, 10)
	for i in 8:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(2.6, 4.2)
		var at := c + V(cos(a) * r, 0, sin(a) * r)
		qb(paint, "Moss", "moss", q, at, at + V(rng.randf_range(0.5, 1.2), 0.045, rng.randf_range(0.4, 1.0)))


func market(q: int, d: Node3D, chain: Node3D, paint: Node3D) -> void:
	# The stall: a green valance and stripes on its cloth roof, goods on the counter.
	qb(d, "Valance", "banner_green", q, V(15.8, 1.8, -25.2), V(20.6, 2.2, -25.17))
	qb(d, "Valance", "banner_green", q, V(15.8, 1.8, -29.23), V(20.6, 2.2, -29.2))
	qb(d, "Valance", "banner_green", q, V(15.77, 1.8, -29.2), V(15.8, 2.2, -25.2))
	qb(d, "Valance", "banner_green", q, V(20.6, 1.8, -29.2), V(20.63, 2.2, -25.2))
	for x in [16.4, 17.6, 18.8, 20.0]:
		qb(d, "Stripe", "banner_green", q, V(x, 2.2, -29.2), V(x + 0.6, 2.22, -25.2))
	for i in 3:
		qb(d, "Bread", "bread", q, V(16.7 + i * 0.4, 1.0, -26.05), V(17.0 + i * 0.4, 1.12, -25.85))
	qb(d, "Tray", "wood_light", q, V(18.0, 1.0, -26.15), V(18.8, 1.12, -25.65))
	qb(d, "Apples", "apple", q, V(18.05, 1.12, -26.1), V(18.75, 1.17, -25.7))
	qb(d, "Pumpkin", "pumpkin", q, V(19.1, 1.0, -26.1), V(19.4, 1.28, -25.8))
	qb(d, "Pumpkin", "pumpkin", q, V(19.5, 1.0, -26.0), V(19.75, 1.22, -25.75))
	hard(qcyl(d, "Sack", "cloth", q, V(17.0, 0, -28.3), 0.5, 0.7, 8))
	hard(qcyl(d, "Sack", "cloth", q, V(17.6, 0, -28.6), 0.45, 0.55, 8))
	# Bunting from the stall to the wall-run wall, and on to the bridge.
	bunting(d, q, V(20.6, 2.2, -25.2), V(21.6, 4.66, -22))
	bunting(d, q, V(22, 4.66, -12), V(22, 5.55, -1.63))
	# The climb chain: a covered wagon, then a booth with an awning and a sign.
	qb(chain, "Cover", "cloth", q, V(4.8, 2.2, -24.8), V(8.4, 2.23, -20.2))
	qb(chain, "Cover", "cloth", q, V(5.0, 1.3, -20), V(8.2, 2.0, -19.96))
	wheel(chain, q, V(8.67, 0.65, -23.8), 1.3)
	wheel(chain, q, V(8.67, 0.65, -21.2), 1.3)
	hard(qslab(chain, "Awning", "banner_green", q, V(3.1, 3.3, -21), V(3.1, 2.75, -19.9), 2.8, 0.06))
	qb(chain, "Sign", "wood_light", q, V(2.5, 3.5, -21), V(3.7, 4.0, -20.95))
	qb(chain, "SignMark", "banner_gold", q, V(2.9, 3.6, -21), V(3.3, 3.9, -20.93))
	qb(paint, "Dirt", "dirt", q, V(15.5, 0, -25), V(21, 0.02, -23.2))
	for i in 6:
		var x := rng.randf_range(16, 20.5)
		var z := rng.randf_range(-24.8, -23.6)
		var s := 0.1 if i % 2 == 0 else 0.18   # different heights: two that overlap never share a top
		qb(paint, "Spill", ["apple", "cabbage"][i % 2], q, V(x, 0, z), V(x + s, s, z + s))


func bunting(parent: Node, q: int, a: Vector3, b: Vector3) -> void:
	var g := grp(parent, "Bunting")
	qbeam(g, "Line", "rope", q, a, b, 0.03, 0.03)
	var n := maxi(2, int((b - a).length() / 0.9))
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		qb(g, "Flag", COLOURS[i % 4], q, p + V(-0.13, -0.33, -0.015), p + V(0.13, -0.03, 0.015))


## The canopy on the quarter's free wall, with what stands under it. Written in that
## wall's frame (the wall after the quarter): the free half runs from x -28.6 to -6.
func canopy(q: int, g: Node3D) -> void:
	var w := (q + 1) % 4
	var last := -6.6 if w == 2 else -6.0
	var edges := [-28.6, -24.0, -18.0, -12.0, last]
	var roof_kind: String = ["hay", "wood", "slate", "banner_green"][q]
	for i in 4:
		var u0: float = edges[i] + 0.15
		var u1: float = edges[i + 1] - 0.15
		var c := (u0 + u1) * 0.5
		var kind := roof_kind
		if q == 3 and i % 2 == 1:
			kind = "cloth"   # the market's awnings alternate
		hard(qslab(g, "Roof", kind, w, V(c, 4.3, -INNER), V(c, 3.45, -INNER + 1.3), u1 - u0, 0.1))
		hard(qb(g, "Beam", "wood", w, V(u0 + 0.06, 3.3, -INNER + 1.19), V(u1 - 0.06, 3.42, -INNER + 1.31)))
		for u in [u0 + 0.3, u1 - 0.3]:
			hard(qbeam(g, "Bracket", "wood", w, V(u, 2.7, -INNER), V(u, 3.36, -INNER + 1.22), 0.12, 0.12))
		var bay := grp(g, "Bay%d" % (i + 1))
		match THEMES[q]:
			"Stables":
				stable_bay(bay, w, c, i)
			"TrainingYard":
				armoury_bay(bay, w, c, i)
			"Well":
				wash_bay(bay, w, c, i, u0, u1)
			"Market":
				stall_bay(bay, w, c, i)
	# The quarter's colour on the pilasters, above the canopy.
	for u in [-24.0, -18.0, -12.0]:
		qb(g, "Banner", COLOURS[q], w, V(u - 0.3, 4.45, -INNER + 0.18), V(u + 0.3, 5.45, -INNER + 0.22))


func stable_bay(bay: Node3D, w: int, c: float, i: int) -> void:
	var z := -INNER
	if i % 3 == 0:
		# A stable door in the wall, a horseshoe over it.
		qb(bay, "Door", "door", w, V(c - 0.8, 0, z), V(c + 0.8, 2.2, z + 0.05))
		for y in [0.5, 1.6]:
			qb(bay, "Hinge", "iron", w, V(c - 0.86, y, z), V(c - 0.15, y + 0.08, z + 0.07))
		qb(bay, "Lintel", "wood", w, V(c - 1.0, 2.2, z), V(c + 1.0, 2.4, z + 0.12))
		qb(bay, "Horseshoe", "iron", w, V(c - 0.13, 2.6, z), V(c + 0.13, 2.86, z + 0.04))
		if i == 3:
			qb(bay, "Peg", "wood", w, V(c + 1.6, 1.3, z), V(c + 1.7, 1.4, z + 0.4))
			qb(bay, "Saddle", "door", w, V(c + 1.4, 1.4, z + 0.04), V(c + 1.9, 1.7, z + 0.4))
	elif i == 1:
		# A hay rack.
		for s in [-1.0, 1.0]:
			qb(bay, "Leg", "wood", w, V(c + s * 1.25 - 0.05, 0, z + 0.3), V(c + s * 1.25 + 0.05, 0.9, z + 0.4))
		hard(qb(bay, "Shelf", "wood", w, V(c - 1.3, 0.9, z), V(c + 1.3, 1.0, z + 0.4)))
		hard(qb(bay, "Rail", "wood", w, V(c - 1.3, 1.0, z + 0.34), V(c + 1.3, 1.5, z + 0.4)))
		hard(qb(bay, "Hay", "hay", w, V(c - 1.2, 1.0, z), V(c + 1.2, 1.7, z + 0.33)))
	else:
		# A water trough.
		hard(qb(bay, "Trough", "wood", w, V(c - 1.1, 0, z), V(c + 1.1, 0.5, z + 0.45)))
		qb(bay, "Water", "water", w, V(c - 1.0, 0.5, z + 0.05), V(c + 1.0, 0.53, z + 0.4))


func armoury_bay(bay: Node3D, w: int, c: float, i: int) -> void:
	var z := -INNER
	for y in [0.8, 1.7]:
		qb(bay, "Rail", "wood", w, V(c - 1.3, y, z), V(c + 1.3, y + 0.1, z + 0.12))
	if i % 2 == 0:
		for k in 5:
			var x := c - 1.0 + k * 0.5
			qb(bay, "Spear", "wood_light", w, V(x - 0.03, 0, z + 0.12), V(x + 0.03, 2.4, z + 0.18))
			qb(bay, "SpearTip", "iron", w, V(x - 0.05, 2.4, z + 0.11), V(x + 0.05, 2.65, z + 0.19))
	else:
		for k in 3:
			var x := c - 0.9 + k * 0.9
			qb(bay, "Blade", "iron", w, V(x - 0.04, 0.5, z + 0.12), V(x + 0.04, 1.5, z + 0.16))
			qb(bay, "Guard", "iron", w, V(x - 0.15, 1.5, z + 0.12), V(x + 0.15, 1.55, z + 0.18))
			qb(bay, "Grip", "door", w, V(x - 0.03, 1.55, z + 0.12), V(x + 0.03, 1.78, z + 0.17))
			shield(bay, w, V(x, 2.45, z), ["banner_red", "banner_gold", "banner_red"][k])


func wash_bay(bay: Node3D, w: int, c: float, i: int, u0: float, u1: float) -> void:
	var z := -INNER
	if i % 2 == 0:
		# A stone basin fed from a spout, a bucket beside it.
		hard(qb(bay, "Basin", "stone_light", w, V(c - 1.3, 0, z), V(c + 1.3, 0.7, z + 0.45)))
		qb(bay, "Water", "water", w, V(c - 1.15, 0.7, z + 0.05), V(c + 1.15, 0.73, z + 0.35))
		qb(bay, "Spout", "iron", w, V(c - 0.05, 1.2, z), V(c + 0.05, 1.28, z + 0.3))
		qcyl(bay, "Bucket", "wood", w, V(c + 1.6, 0, z + 0.25), 0.34, 0.36, 10)
		for k in 3:
			var x := rng.randf_range(c - 2.4, c + 1.8)
			qb(bay, "Moss", "moss", w, V(x, 0, z), V(x + rng.randf_range(0.4, 0.9), rng.randf_range(0.3, 0.8), z + 0.04))
	else:
		# A washing line.
		qb(bay, "Line", "rope", w, V(u0 + 0.2, 2.5, z + 0.3), V(u1 - 0.2, 2.53, z + 0.33))
		for k in 3:
			var x := c - 1.5 + k * 1.5
			qb(bay, "Sheet", "banner_blue" if k % 2 == 0 else "cloth", w, V(x - 0.45, 1.5, z + 0.29), V(x + 0.45, 2.5, z + 0.32))
		hard(qcyl(bay, "Tub", "wood", w, V(c, 0, z + 0.38), 0.7, 0.4, 12))
		qcyl(bay, "Suds", "cloth", w, V(c, 0.4, z + 0.38), 0.6, 0.03, 12)


func stall_bay(bay: Node3D, w: int, c: float, i: int) -> void:
	var z := -INNER
	hard(qb(bay, "Counter", "wood", w, V(c - 1.4, 0, z), V(c + 1.4, 0.9, z + 0.45)))
	hard(qb(bay, "Top", "wood_light", w, V(c - 1.5, 0.9, z), V(c + 1.5, 0.96, z + 0.5)))
	qb(bay, "Shelf", "wood", w, V(c - 1.3, 1.7, z), V(c + 1.3, 1.75, z + 0.25))
	qb(bay, "Sign", "wood_light", w, V(c - 0.5, 2.4, z), V(c + 0.5, 2.9, z + 0.06))
	qb(bay, "SignMark", "banner_gold", w, V(c - 0.15, 2.5, z), V(c + 0.15, 2.8, z + 0.08))
	match i:
		0:
			for k in 5:
				qb(bay, "Bread", "bread", w, V(c - 1.1 + k * 0.45, 0.96, z + 0.15), V(c - 0.8 + k * 0.45, 1.08, z + 0.35))
			for k in 3:
				qb(bay, "Bread", "bread", w, V(c - 0.9 + k * 0.6, 1.75, z + 0.04), V(c - 0.55 + k * 0.6, 1.87, z + 0.2))
		1:
			qb(bay, "Tray", "wood_light", w, V(c - 1.2, 0.96, z + 0.08), V(c + 0.1, 1.06, z + 0.44))
			qb(bay, "Apples", "apple", w, V(c - 1.15, 1.06, z + 0.12), V(c + 0.05, 1.11, z + 0.4))
			for k in 3:
				qb(bay, "Cabbage", "cabbage", w, V(c + 0.3 + k * 0.32, 0.96, z + 0.14), V(c + 0.52 + k * 0.32, 1.16, z + 0.36))
		2:
			for k in 4:
				var s := 0.26 + 0.04 * (k % 2)
				qb(bay, "Pumpkin", "pumpkin", w, V(c - 1.1 + k * 0.6, 0.96, z + 0.1), V(c - 1.1 + k * 0.6 + s, 0.96 + s * 0.85, z + 0.1 + s))
			for k in 4:
				qb(bay, "Cabbage", "cabbage", w, V(c - 1.0 + k * 0.55, 1.75, z + 0.03), V(c - 0.8 + k * 0.55, 1.93, z + 0.21))
		_:
			for k in 3:
				qb(bay, "Bolt", ["banner_green", "banner_gold", "cloth"][k], w, V(c - 1.2 + k * 0.8, 0.96, z + 0.08), V(c - 0.6 + k * 0.8, 1.14, z + 0.4))
			qb(bay, "Apples", "apple", w, V(c - 1.0, 1.75, z + 0.04), V(c + 1.0, 1.8, z + 0.2))


# -- outside ---------------------------------------------------------------------------
## A postern in the north wall, steps down the rock and a jetty: the north side's own
## landmark from the wall walk. Nobody can stand there (the lake kills at -5).
func outside() -> void:
	var j := grp(scn.get_node("Outside"), "Jetty")
	qb(j, "Postern", "door", 0, V(-0.7, 0, -FACE - 0.06), V(0.7, 2.1, -FACE))
	for s in [-1.0, 1.0]:
		qb(j, "Jamb", "stone_light", 0, V(s * 0.7, 0, -FACE - 0.12), V(s * 1.0, 2.1, -FACE))
	qb(j, "Lintel", "stone_light", 0, V(-1.0, 2.1, -FACE - 0.12), V(1.0, 2.45, -FACE))
	qslab(j, "Steps", "wood_light", 0, V(0, 0, -FACE), V(0, -4.15, -40.2), 1.2, 0.12)
	qb(j, "Deck", "wood", 0, V(-1.4, -4.3, -52), V(1.4, -4.15, -40.2))
	for z in [-42.0, -46.0, -50.0, -51.8]:
		for s in [-1.0, 1.0]:
			qcyl(j, "Pile", "wood", 0, V(s * 1.3, -7, z), 0.3, 3.3, 8)
	var l := thing(j, "Lantern", 0, V(1.3, -3.7, -51.8))
	part(l, "Post", "iron", V(0.08, 1.2, 0.08), V(0, 0.6, 0))
	part(l, "Lamp", "glass_lit", V(0.22, 0.28, 0.22), V(0, 1.34, 0))
	var boat := thing(j, "Boat", 0, V(3.0, -4.6, -47))
	part(boat, "Hull", "wood", V(1.5, 0.7, 4.0), V(0, 0.2, 0))
	part(boat, "Gunwale", "wood_light", V(1.62, 0.08, 4.12), V(0, 0.59, 0))
	part(boat, "Thwart", "wood_light", V(1.5, 0.06, 0.3), V(0, 0.66, 0.3))
	qbeam(j, "Mooring", "rope", 0, V(1.4, -4.15, -46), V(2.25, -4.0, -46.6), 0.03, 0.03)
