extends SceneTree
## RETIRED once run: game/maps/construction_site.tscn is edited by hand, and this script
## is kept as a record of how the Construction Site's revamp was built. It was run once,
## on the scene as it stood before the revamp, and refuses to run unless SITE_REVAMP=1
## is set: on the revamped scene it would add everything a second time.
##
##   SITE_REVAMP=1 godot --headless --path . --script tools/arena/construction_site_revamp.gd
##
## What it does:
##  - the palette: a Surface pattern for most kinds (the map's "textures"), and the new
##    kinds the pieces below use;
##  - the crane: rebuilt as a hollow mast you wall-jump up, a tie gangway from the
##    tower's 20 m steel, and two MapIslands a CraneEvent moves (the Jib: slewing deck,
##    cab with its MapLever, jib and counter-jib; the Hook: the slab on its slings);
##  - sightlines: sheeting on the east scaffold and the steel frame, a few blockwork
##    walls inside the tower, and cover and canopies that break up the yard's long lanes;
##  - dressing: drawn-only detail everywhere (tracks and puddles on the ground, props,
##    rebar, lamps, signs).
## Everything it adds is ordinary MapBlocks in groups, one object a group. It keeps the
## rules tests/map_flicker_test.gd checks: a detail stands proud of the surface behind
## it, and paint on the ground is a few centimetres thick, each kind at its own height.

const SCENE := "res://game/maps/construction_site.tscn"
const PALETTE := "res://game/maps/palettes/construction_site.tres"

const BOX := MapBlock.Shape.BOX
const CYL := MapBlock.Shape.CYLINDER
const TUBE := MapBlock.Shape.TUBE
const CONE := MapBlock.Shape.CONE
const WEDGE := MapBlock.Shape.WEDGE

## The crane: the middle of its mast, the height of the deck round the mast head, and
## the height of the tie gangway (6 cm proud of the tower's 20 m steel).
const MAST := Vector3(27, 0, -27)
const DECK := 30.6
const TIE := 20.06
## The hook hangs this far out along the jib, and the slab's top is this high at home.
const REACH := 52.0
const SLAB_TOP := 13.0
## The crane's stops: degrees from home (the tower), and the slab's top at each.
const STOP_TURNS := [0.0, 35.0, -35.0]
const STOP_TOPS := [13.0, 2.6, 2.6]
const CARRY_TOP := 25.2

## Lays a cylinder on its side: its axis along x, or along z.
var AXIS_X := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
var AXIS_Z := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
## The jib's own frame at home: -z along the jib (south-west), +x to its right.
var JIB := Basis(Vector3(-1, 0, -1).normalized(), Vector3.UP, Vector3(1, 0, -1).normalized())

var scn: Node3D
var block_script: Script
var rng := RandomNumberGenerator.new()
var count := 0
var solid_count := 0


func _init() -> void:
	if OS.get_environment("SITE_REVAMP") != "1":
		printerr("construction_site.tscn is edited by hand and this script has already been run on it: " +
			"a second run would add everything again. It is kept as a record. To run it anyway (on the scene " +
			"as it was before the revamp), set SITE_REVAMP=1.")
		quit(1)
		return
	block_script = load("res://game/arena/map_block.gd")
	scn = (load(SCENE) as PackedScene).instantiate()
	scn.scene_file_path = ""
	rng.seed = 20261118
	palette()
	crane()
	sightlines()
	dressing()
	var ps := PackedScene.new()
	var err := ps.pack(scn)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE)
	print("REVAMP: saved %s (%s): %d blocks added (%d solid)" % [SCENE, error_string(err), count, solid_count])
	scn.free()
	quit(0 if err == OK else 1)


# -- helpers -------------------------------------------------------------------------
func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


## Turned `degrees` round the y axis (anticlockwise seen from above).
func Y(degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(degrees))


## Where a node is, in the map's frame.
func wx(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur := n
	while cur != null and cur != scn:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func _add(parent: Node, n: Node, called: String) -> void:
	n.name = called
	parent.add_child(n, true)
	n.owner = scn


## A group: one object. `at` and `turn` are in the parent's frame.
func G(parent: Node, called: String, at := Vector3.ZERO, turn := Basis.IDENTITY, click_as_one := true) -> Node3D:
	var g := Node3D.new()
	g.transform = Transform3D(turn, at)
	if click_as_one:
		g.set_meta("_edit_group_", true)
	_add(parent, g, called)
	return g


## A group under `parent` placed by where it is in the map.
func GW(parent: Node, called: String, at: Vector3, turn := Basis.IDENTITY) -> Node3D:
	var g := G(parent, called)
	g.transform = wx(parent).affine_inverse() * Transform3D(turn, at)
	return g


## A block. Drawn only unless opts.solid. opts: solid, hidden (solid but not drawn),
## turn (Basis), shape, tint, sides, inner, top, breaks (a BlockBreakable preset),
## (breaks "" is breakable the default way, with its kind's own health), health, material.
func B(parent: Node, called: String, kind: String, at: Vector3, size: Vector3, opts := {}) -> Node3D:
	var b := Node3D.new()
	b.set_script(block_script)
	b.transform = Transform3D(opts.get("turn", Basis.IDENTITY), at)
	b.set("shape", opts.get("shape", BOX))
	b.set("size", size)
	b.set("kind", kind)
	var solid: bool = opts.get("solid", false) or opts.get("hidden", false)
	b.set("solid", solid)
	if opts.get("hidden", false):
		b.set("drawn", false)
	if opts.has("tint"):
		b.set("tint", opts.tint)
	if opts.has("sides"):
		b.set("sides", opts.sides)
	if opts.has("inner"):
		b.set("inner", opts.inner)
	if opts.has("top"):
		b.set("top", opts.top)
	if opts.has("breaks"):
		b.set("breakable", true)
		if opts.breaks != "":
			b.set("break_settings", opts.breaks)
		if opts.has("health"):
			b.set("break_health", opts.health)
	if opts.has("material"):
		b.set("material_type", opts.material)
	_add(parent, b, called)
	count += 1
	if solid:
		solid_count += 1
	return b


func S(extra := {}) -> Dictionary:
	var o := {"solid": true}
	o.merge(extra)
	return o


## A straight bar from `a` to `b`, `thick` square.
func rod(parent: Node, called: String, kind: String, a: Vector3, b: Vector3, thick: float, opts := {}) -> Node3D:
	var z := (b - a).normalized()
	var up := Vector3.UP if absf(z.y) < 0.99 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var o := opts.duplicate()
	o["turn"] = Basis(x, z.cross(x), z)
	return B(parent, called, kind, (a + b) * 0.5, Vector3(thick, thick, a.distance_to(b)), o)


## A slightly lighter or darker shade, so neighbours of one kind do not look stamped.
func shade(spread := 0.05) -> Color:
	var v := 1.0 + rng.randf_range(-spread, spread)
	return Color(v, v, v)


## A flat ring of 12 boxes round the y axis, its top at `top`: inside it a 12-sided
## hole `r_in` to its flat sides, outside 12 flat sides `r_out` away.
func ring(parent: Node, called: String, kind: String, top: float, thick: float, r_in: float, r_out: float, opts := {}) -> void:
	var across := 2.0 * r_out * tan(deg_to_rad(15.0)) + 0.02
	for i in 12:
		var turn := Y(i * 30.0)
		var o := opts.duplicate()
		o["turn"] = turn
		B(parent, called, kind, turn * V(0, top - thick * 0.5, (r_in + r_out) * 0.5), V(across, thick, r_out - r_in), o)


## A sign: dark letters, like the site boards.
func label(parent: Node, text: String, at: Vector3, turn: Basis, font: int, pixel := 0.01, colour := Color(0.16, 0.18, 0.22)) -> Label3D:
	var l := Label3D.new()
	l.transform = Transform3D(turn, at)
	l.pixel_size = pixel
	l.double_sided = false
	l.modulate = colour
	l.outline_modulate = colour
	l.text = text
	l.font_size = font
	var clean := ""
	for word in text.replace("\n", " ").split(" ", false):
		if clean.length() < 22:
			clean += word.capitalize().replace(" ", "")
	var keep := ""
	for c in clean:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			keep += c
	_add(parent, l, "Sign_" + keep)
	return l


# -- the palette ---------------------------------------------------------------------
func palette() -> void:
	var p := load(PALETTE) as MapPalette
	var colors := p.colors.duplicate()
	colors.merge({
		"deck": Color(0.36, 0.39, 0.44),                 # steel grating: the crane's decks and walkways
		"crane_mesh": Color(0.93, 0.8, 0.42, 0.2),       # the guard mesh on the mast's faces
		"cab_glass": Color(0.6, 0.82, 0.92, 0.3),
		"beacon": Color(1.0, 0.16, 0.1),                 # the crane's red lights
		"sheeting": Color(0.24, 0.52, 0.42),             # debris netting on scaffold and steel
		"tarp": Color(0.22, 0.42, 0.72),
		"canopy": Color(0.74, 0.77, 0.8),                # corrugated roof sheets
		"brick": Color(0.72, 0.37, 0.27),
		"barrier_red": Color(0.86, 0.2, 0.16),           # water-filled road barriers
		"puddle": Color(0.33, 0.4, 0.46),
		"sign_blue": Color(0.14, 0.36, 0.72),
		"sign_green": Color(0.16, 0.56, 0.34),
		"sign_red": Color(0.8, 0.16, 0.14),
		"insulation": Color(0.96, 0.82, 0.36),
	}, true)
	p.colors = colors
	p.surface = {
		"dirt": "dirt", "dirt_dark": "dirt", "gravel": "gravel", "street": "tarmac",
		"concrete": "slabs", "concrete_dark": "panels_plain", "weight": "slabs",
		"block": "blocks_small", "brick": "bricks",
		"plank": "planks", "ply": "planks_upright",
		"hazard": "hazard", "stair": "treads", "deck": "grating",
		"hoarding": "corrugated", "canopy": "corrugated", "sheeting": "panels_plain",
		"silo": "plates", "backdrop": "windows", "puddle": "water",
	}
	p.glow = {"lamp": 1.6, "beacon": 3.0}
	var breakable := p.breakable.duplicate()
	breakable.merge({"sheeting": 60.0, "cab_glass": 25.0}, true)
	p.breakable = breakable
	p.material = {"deck": "metal", "sheeting": "rubber", "tarp": "rubber", "canopy": "metal", "cab_glass": "glass",
		"crane": "metal", "crane_mesh": "metal", "scaffold": "metal", "weight": "concrete", "brick": "concrete",
		"barrier_red": "rubber", "machine": "metal", "machine_dark": "metal", "hoarding": "metal", "silo": "metal"}
	var err := ResourceSaver.save(p, PALETTE)
	print("REVAMP: palette saved (%s): %d kinds, %d with a pattern" % [error_string(err), p.colors.size(), p.surface.size()])


# -- the crane -----------------------------------------------------------------------
## A box truss along z from `z0` to `z1` (in the parent's frame), `y0` at its foot: four
## chords, posts, diagonals and cross members every bay, and one hidden solid box.
func truss(parent: Node, z0: float, z1: float, y0: float, bays: int) -> void:
	var length := z1 - z0
	var mid := (z0 + z1) * 0.5
	B(parent, "Body", "crane", V(0, y0 + 0.8, mid), V(1.8, 1.6, length), {"hidden": true})
	for sx in [-1.0, 1.0]:
		for y in [0.09, 1.51]:
			B(parent, "Chord", "crane", V(sx * 0.81, y0 + y, mid), V(0.18, 0.18, length))
	var step := length / bays
	for i in bays + 1:
		var z := z0 + i * step
		for sx in [-1.0, 1.0]:
			B(parent, "Post", "crane", V(sx * 0.81, y0 + 0.8, z), V(0.09, 1.3, 0.09))
		B(parent, "Tie", "crane", V(0, y0 + 0.09, z), V(1.5, 0.09, 0.09))
		B(parent, "Tie", "crane", V(0, y0 + 1.51, z), V(1.5, 0.09, 0.09))
		if i == bays:
			break
		var up := i % 2 == 0
		for sx in [-1.0, 1.0]:
			rod(parent, "Brace", "crane", V(sx * 0.81, y0 + (0.14 if up else 1.46), z), V(sx * 0.81, y0 + (1.46 if up else 0.14), z + step), 0.09)
		rod(parent, "Lacing", "crane", V(-0.81 if up else 0.81, y0 + 0.09, z), V(0.81 if up else -0.81, y0 + 0.09, z + step), 0.07)


func crane() -> void:
	var old := scn.get_node("Crane")
	var index := old.get_index()
	scn.remove_child(old)
	old.free()
	var crane := Node3D.new()
	_add(scn, crane, "Crane")
	scn.move_child(crane, index)
	_mast(crane)
	_tie(crane)
	_jib(crane)
	_hook(crane)
	var event := Node.new()
	event.set_script(load("res://game/arena/crane_event.gd"))
	event.set("jib", NodePath("../Jib"))
	event.set("hook", NodePath("../Hook"))
	event.set("rope_top", NodePath("../Jib/RopeTop"))
	event.set("rope_bottom", NodePath("../Hook/RopeBottom"))
	# (Typed arrays, not packed ones: an export drops a packed array from a node whose
	# script does not run in the editor, and the crane then has no stops.)
	var turns: Array[float] = []
	var heights: Array[float] = []
	for i in STOP_TURNS.size():
		turns.append(float(STOP_TURNS[i]))
		heights.append(float(STOP_TOPS[i]) - SLAB_TOP)
	var route: Array[int] = [0, 1, 0, 2]
	event.set("turns", turns)
	event.set("heights", heights)
	event.set("route", route)
	event.set("carry_height", CARRY_TOP - SLAB_TOP)
	event.set("hoist_speed", 7.0)
	event.set("slew_speed", 10.0)
	_add(crane, event, "CraneEvent")
	for stop in [1, 2]:
		_loading_zone(crane, stop)
	# The pallet that stood where the south-east loading zone is.
	var pallet := scn.get_node("Yard/Pallet5") as Node3D
	pallet.position = V(14.6, 0, 20.2)


## The mast: a hollow shaft 2 m square inside (wall-jump up it like the lift shaft),
## open to the south at the foot and at the tie gangway, and a round collar at its head
## that the jib's deck turns round.
func _mast(crane: Node3D) -> void:
	var mast := G(crane, "Mast", MAST)
	B(mast, "Base", "concrete_dark", V(0, 0.5, 0), V(5.5, 1, 5.5), S())
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B(mast, "Ballast", "weight", V(sx * 1.9, 1.5, sz * 1.9), V(1.5, 1, 1.5), S({"tint": shade(0.03)}))
	# A ramp up onto the base, to the mast's door (bots walk it too).
	var slope := atan2(1.0, 1.85)
	B(mast, "Ramp", "deck", V(0, 0.5 - 0.1 * cos(slope), 3.675 - 0.1 * sin(slope)), V(1.8, 0.2, sqrt(1.0 + 1.85 * 1.85)), S({"turn": Basis(Vector3.RIGHT, slope)}))
	for sx in [-1.0, 1.0]:
		B(mast, "RampEdge", "hazard", V(sx * 0.93, 0.5 - 0.06 * cos(slope), 3.675 - 0.06 * sin(slope)), V(0.08, 0.2, sqrt(1.0 + 1.85 * 1.85)), {"turn": Basis(Vector3.RIGHT, slope)})
	# Bay heights: 8 to the tie gangway, the gangway's doorway, 3 above it.
	var ys: Array[float] = []
	for i in 9:
		ys.append(1.0 + i * (TIE - 1.0) / 8.0)
	ys.append(TIE + 2.4)
	for i in 3:
		ys.append(TIE + 2.4 + (i + 1) * (DECK - 0.3 - TIE - 2.4) / 3.0)
	var top := DECK
	# The shaft's walls (hidden; the lattice and the mesh are what you see).
	var walls := G(mast, "Shaft", Vector3.ZERO, Basis.IDENTITY, false)
	B(walls, "West", "crane", V(-1.1, (1.0 + top) * 0.5, 0), V(0.2, top - 1.0, 2.4), {"hidden": true})
	B(walls, "East", "crane", V(1.1, (1.0 + top) * 0.5, 0), V(0.2, top - 1.0, 2.4), {"hidden": true})
	B(walls, "North", "crane", V(0, (1.0 + top) * 0.5, -1.1), V(2.0, top - 1.0, 0.2), {"hidden": true})
	B(walls, "South", "crane", V(0, (ys[1] + TIE) * 0.5, 1.1), V(2.0, TIE - ys[1], 0.2), {"hidden": true})
	B(walls, "South", "crane", V(0, (TIE + 2.4 + top) * 0.5, 1.1), V(2.0, top - TIE - 2.4, 0.2), {"hidden": true})
	# The lattice.
	var lattice := G(mast, "Lattice")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B(lattice, "Chord", "crane", V(sx * 1.09, (1.0 + DECK - 0.3) * 0.5, sz * 1.09), V(0.22, DECK - 1.3, 0.22))
	for i in ys.size():
		var y: float = ys[i]
		var door := i == 0 or i == 8                 # a doorway starts here on the south face
		var above_door := i == 1 or i == 9
		for f in 4:
			var q := Y(f * 90.0)                       # f 0: the south face, 1: east, 2: north, 3: west
			if not (f == 0 and door) and i > 0:
				B(lattice, "Rail", "crane", q * V(0, y, 1.09), V(1.96, 0.1, 0.1) if f % 2 == 0 else V(0.1, 0.1, 1.96))
			if i == ys.size() - 1 or (f == 0 and door):
				continue
			var up := (i + f) % 2 == 0
			rod(lattice, "Brace", "crane", q * V(-0.98 if up else 0.98, y + 0.06, 1.09), q * V(0.98 if up else -0.98, ys[i + 1] - 0.06, 1.09), 0.1)
		if above_door:
			# A black and yellow lintel over the doorway.
			B(lattice, "Lintel", "hazard", V(0, y + 0.02, 1.15), V(2.0, 0.2, 0.14))
	# Guard mesh on the faces (see-through; the hidden walls behind it are what stops you).
	var mesh := G(mast, "GuardMesh")
	for f in [1, 2, 3]:
		var q := Y(f * 90.0)
		B(mesh, "Mesh", "crane_mesh", q * V(0, (1.0 + DECK - 0.3) * 0.5, 1.1), V(1.96, DECK - 1.3, 0.03) if f % 2 == 0 else V(0.03, DECK - 1.3, 1.96))
	B(mesh, "Mesh", "crane_mesh", V(0, (ys[1] + TIE) * 0.5, 1.1), V(1.96, TIE - ys[1], 0.03))
	B(mesh, "Mesh", "crane_mesh", V(0, (TIE + 2.4 + DECK - 0.3) * 0.5, 1.1), V(1.96, DECK - 0.3 - TIE - 2.4, 0.03))
	# The ladder up the inside of the north face.
	var ladder := G(mast, "Ladder")
	for sx in [-1.0, 1.0]:
		B(ladder, "Rail", "scaffold", V(sx * 0.24, (1.0 + DECK - 0.4) * 0.5, -0.93), V(0.05, DECK - 1.4, 0.05))
	var rung := 1.3
	while rung < DECK - 0.5:
		B(ladder, "Rung", "scaffold", V(0, rung, -0.93), V(0.48, 0.035, 0.035))
		rung += 0.45
	# The head: a collar level with the deck that turns round it, over the slew ring.
	var head := G(mast, "Head")
	ring(head, "Collar", "deck", DECK, 0.25, 1.0, 1.8, S())
	B(head, "SlewRing", "machine_dark", V(0, DECK - 0.6, 0), V(3.3, 0.7, 3.3), {"shape": CYL, "sides": 16})
	B(head, "Gear", "weight", V(0, DECK - 0.33, 0), V(3.52, 0.1, 3.52), {"shape": CYL, "sides": 24})
	# Paint and signs at the foot.
	B(mast, "Kerb", "hazard", V(0, 1.03, 2.6), V(2.3, 0.06, 0.3))
	var board := G(mast, "Notice", V(0, 2.9, 1.24))
	B(board, "Board", "sign_red", V(0, 0.92, 0), V(1.9, 0.5, 0.04))
	label(board, "CRANE  ·  OPERATOR ONLY", V(0, 0.92, 0.03), Basis.IDENTITY, 44, fit("CRANE  ·  OPERATOR ONLY", 44, 0.006, Vector2(1.9, 0.5)), Color(0.97, 0.97, 0.95))


## The tie: a gangway from the corner of the tower's 20 m steel to a landing at the
## mast's south door.
func _tie(crane: Node3D) -> void:
	var tie := G(crane, "Tie")
	var from := V(15.5, 0, -15.5)                   # the tower's north-east steel column
	var along := V(1, 0, -1).normalized()
	var across := V(1, 0, 1).normalized()
	var turn := Basis(across, Vector3.UP, across.cross(Vector3.UP))   # z along the gangway... toward the tower
	turn = Basis(Vector3.UP.cross(along).normalized(), Vector3.UP, along)
	var run := 14.3
	B(tie, "Deck", "deck", from + along * run * 0.5 + V(0, TIE - 0.1, 0), V(1.3, 0.2, run), S({"turn": turn}))
	B(tie, "Landing", "deck", V(26.25, TIE - 0.1, -25.05), V(3.9, 0.2, 1.5), S())
	# The lattice strut under it.
	for side in [-1.0, 1.0]:
		var edge: Vector3 = from + across * side * 0.5
		rod(tie, "Chord", "crane", edge + along * 0.5 + V(0, TIE - 1.1, 0), edge + along * (run - 0.3) + V(0, TIE - 1.1, 0), 0.14)
		for i in 8:
			var a := 0.5 + i * (run - 0.8) / 8.0
			var b := 0.5 + (i + 1) * (run - 0.8) / 8.0
			rod(tie, "Brace", "crane", edge + along * a + V(0, TIE - (1.1 if i % 2 == 0 else 0.22), 0), edge + along * b + V(0, TIE - (0.22 if i % 2 == 0 else 1.1), 0), 0.08)
	for i in 9:
		var a := 0.5 + i * (run - 0.8) / 8.0
		rod(tie, "Tie", "crane", from + across * -0.5 + along * a + V(0, TIE - 1.1, 0), from + across * 0.5 + along * a + V(0, TIE - 1.1, 0), 0.08)
	# Handrails (drawn only: you can go over them).
	for side in [-1.0, 1.0]:
		var edge: Vector3 = from + across * side * 0.6
		for i in 9:
			var a := 0.9 + i * (run - 1.2) / 8.0
			B(tie, "Post", "crane", edge + along * a + V(0, TIE + 0.55, 0), V(0.06, 1.1, 0.06), {"turn": turn})
		for h in [0.55, 1.1]:
			rod(tie, "Handrail", "crane", edge + along * 0.9 + V(0, TIE + h, 0), edge + along * (run - 0.3) + V(0, TIE + h, 0), 0.05)
	for x in [24.4, 26.1, 28.1]:
		B(tie, "Post", "crane", V(x, TIE + 0.55, -24.4), V(0.06, 1.1, 0.06))
	for h in [0.55, 1.1]:
		rod(tie, "Handrail", "crane", V(24.4, TIE + h, -24.4), V(28.1, TIE + h, -24.4), 0.05)
		rod(tie, "Handrail", "crane", V(28.1, TIE + h, -24.4), V(28.1, TIE + h, -25.7), 0.05)
	# Where it is fixed to the tower.
	B(tie, "Bracket", "steel", V(15.5, TIE - 0.5, -15.5), V(0.9, 0.5, 0.9), {"turn": turn})
	var notice := G(tie, "Notice", from + along * 1.6 + across * -0.68 + V(0, TIE + 0.75, 0), turn * Y(-90.0))
	B(notice, "Board", "hazard", V(0, 0, 0), V(1.5, 0.42, 0.03))
	var small := fit("CRANE ACCESS", 40, 0.006, Vector2(1.5, 0.42))
	label(notice, "CRANE ACCESS", V(0, 0, -0.025), Y(180.0), 40, small)
	label(notice, "CRANE ACCESS", V(0, 0, 0.025), Basis.IDENTITY, 40, small)


## The part that turns: a MapIsland whose pivot is the mast.
func _jib(crane: Node3D) -> void:
	var jib := Node3D.new()
	jib.set_script(load("res://game/arena/map_island.gd"))
	jib.transform = Transform3D(JIB, V(MAST.x, DECK, MAST.z))
	jib.set("pivot", V(MAST.x, DECK, MAST.z))
	jib.set("over_ground", true)   # (bots: this is not a map of islands over a drop)
	jib.set_meta("_edit_group_", true)
	_add(crane, jib, "Jib")
	# The deck round the mast head, and the frame that carries the jib over it.
	var deck := G(jib, "Deck", Vector3.ZERO, Basis.IDENTITY, false)
	ring(deck, "Ring", "deck", 0.0, 0.25, 1.89, 3.3, S())
	B(deck, "CabFloor", "deck", V(2.4, -0.125, -3.1), V(2.6, 0.25, 4.2), S())
	B(deck, "Skirt", "crane", V(0, -0.36, 0), V(6.5, 0.22, 6.5), {"shape": TUBE, "inner": 6.1, "sides": 12})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B(deck, "Post", "crane", V(sx * 1.55, 2.0, sz * 1.55), V(0.24, 4.0, 0.24), S())
	rod(deck, "Brace", "crane", V(-1.55, 0.2, 1.55), V(1.55, 3.8, 1.55), 0.1)
	rod(deck, "Brace", "crane", V(1.55, 0.2, 1.55), V(-1.55, 3.8, 1.55), 0.1)
	rod(deck, "Brace", "crane", V(-1.55, 0.2, -1.55), V(-1.55, 3.8, 1.55), 0.1)
	rod(deck, "Brace", "crane", V(-1.55, 0.2, 1.55), V(-1.55, 3.8, -1.55), 0.1)
	# Handrail round the deck's rim, left open where the cab stands.
	var rail := G(deck, "Handrail")
	var last := Vector3.INF
	for i in 13:
		var a := i * 30.0 - 195.0                     # from behind the cab, round the back, to its front
		if a > 75.0:
			break
		var at := Y(a) * V(0, 0, 3.2)
		B(rail, "Post", "crane", at + V(0, 0.55, 0), V(0.06, 1.1, 0.06))
		if last != Vector3.INF:
			for h in [0.55, 1.1]:
				rod(rail, "Rail", "crane", last + V(0, h, 0), at + V(0, h, 0), 0.05)
		last = at
	# A cabinet behind the cab: the first step of the climb to the jib's top.
	B(deck, "Cabinet", "machine_dark", V(3.25, 0.65, -1.5), V(0.8, 1.3, 0.9), S())
	B(deck, "CabinetDoor", "weight", V(3.25, 0.7, -1.03), V(0.6, 1.0, 0.04))
	_cab(jib)
	# The jib and the counter-jib, one line over the mast, and the walkway along their top.
	var arm := G(jib, "Arm", Vector3.ZERO, Basis.IDENTITY, false)
	truss(arm, -56.0, 0.6, 4.0, 25)
	B(arm, "Walkway", "deck", V(0, 5.63, -27.7), V(1.5, 0.06, 56.6), S())
	var back := G(jib, "CounterJib", Vector3.ZERO, Basis.IDENTITY, false)
	truss(back, 0.6, 15.0, 4.0, 6)
	B(back, "Walkway", "deck", V(0, 5.63, 7.8), V(1.5, 0.06, 14.4), S())
	for i in 3:
		B(back, "Ballast", "weight", V(0, 3.9, 11.4 + i * 1.15), V(2.2, 2.6, 1.1), S({"tint": shade(0.03)}))
	B(back, "WinchHouse", "machine_dark", V(0, 6.22, 7.6), V(1.3, 1.1, 2.2), S())
	B(back, "WinchDrum", "weight", V(0, 6.1, 5.9), V(0.8, 1.1, 0.8), {"shape": CYL, "turn": AXIS_X, "sides": 12})
	B(back, "WinchVent", "weight", V(0.66, 6.3, 7.6), V(0.04, 0.5, 1.2))
	# The cat head over the mast, and the pendants that hold the jib up.
	var cat := G(jib, "CatHead", Vector3.ZERO, Basis.IDENTITY, false)
	B(cat, "Body", "crane", V(0, 8.5, 0), V(1.2, 5.8, 1.2), {"hidden": true})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B(cat, "Chord", "crane", V(sx * 0.53, 8.53, sz * 0.53), V(0.14, 5.74, 0.14))
	for i in 4:
		var y := 5.8 + i * 1.82
		for f in 4:
			var q := Y(f * 90.0)
			B(cat, "Rail", "crane", q * V(0, y, 0.53), V(0.92, 0.07, 0.07) if f % 2 == 0 else V(0.07, 0.07, 0.92))
			if i < 3:
				var up := (i + f) % 2 == 0
				rod(cat, "Brace", "crane", q * V(-0.46 if up else 0.46, y, 0.53), q * V(0.46 if up else -0.46, y + 1.82, 0.53), 0.06)
	B(cat, "Beacon", "beacon", V(0, 11.55, 0), V(0.26, 0.26, 0.26))
	rod(cat, "Pendant", "cable", V(0, 11.3, 0), V(0, 5.7, -36.0), 0.1)
	rod(cat, "Pendant", "cable", V(0, 11.3, 0), V(0, 5.7, -18.0), 0.1)
	rod(cat, "Pendant", "cable", V(0, 11.3, 0), V(0, 5.7, 12.4), 0.1)
	# The trolley the hook hangs from, the lights, and the builder's name along the jib.
	var trolley := G(jib, "Trolley", V(0, 0, -REACH))
	B(trolley, "Frame", "weight", V(0, 3.72, 0), V(1.4, 0.5, 1.8))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B(trolley, "Wheel", "machine_dark", V(sx * 0.81, 3.93, sz * 0.6), V(0.3, 0.12, 0.3), {"shape": CYL, "turn": AXIS_X, "sides": 10})
	B(trolley, "Sheave", "machine_dark", V(0, 3.5, 0), V(0.5, 0.14, 0.5), {"shape": CYL, "turn": AXIS_X, "sides": 10})
	var top := Marker3D.new()
	top.position = V(0, 3.45, -REACH)
	_add(jib, top, "RopeTop")
	B(arm, "Beacon", "beacon", V(0, 5.85, -55.8), V(0.26, 0.26, 0.26))
	B(arm, "Floodlight", "lamp", V(0, 3.9, -30.0), V(0.7, 0.14, 0.4))
	B(arm, "Floodlight", "lamp", V(0, 3.9, -8.0), V(0.7, 0.14, 0.4))
	for sx in [-1.0, 1.0]:
		var name_board := G(arm, "NameBoard", V(sx * 0.94, 4.8, -12.0), Y(90.0 * sx))
		B(name_board, "Board", "board", V(0, 0, 0), V(9.0, 1.0, 0.05))
		label(name_board, "JS BUILD CO.", V(0, 0, 0.04), Basis.IDENTITY, 96)


## The operator's cab: a floor level with the deck, a door at the back, breakable
## glass, and the lever that works the crane.
func _cab(jib: Node3D) -> void:
	var cab := G(jib, "Cab", V(2.3, 0, -3.6))
	# Walls: white below, glass above, a band under the roof.
	B(cab, "Back", "box_white", V(-0.85, 1.2, 1.55), V(0.7, 2.4, 0.1), S())
	B(cab, "Back", "box_white", V(0.85, 1.2, 1.55), V(0.7, 2.4, 0.1), S())
	B(cab, "Lintel", "box_white", V(0, 2.25, 1.55), V(1.0, 0.3, 0.1), S())
	for sx in [-1.0, 1.0]:
		B(cab, "Side", "box_white", V(sx * 1.15, 0.45, 0), V(0.1, 0.9, 3.0), S())
		B(cab, "Band", "box_white", V(sx * 1.15, 2.3, 0), V(0.1, 0.2, 3.0), S())
		B(cab, "Post", "box_white", V(sx * 1.15, 1.2, -1.55), V(0.1, 2.4, 0.1), S())
		B(cab, "Window", "cab_glass", V(sx * 1.15, 1.55, -0.02), V(0.05, 1.3, 2.96), S({"breaks": "Whole Block, Fragile"}))
	B(cab, "Front", "box_white", V(0, 0.3, -1.55), V(2.2, 0.6, 0.1), S())
	B(cab, "Band", "box_white", V(0, 2.3, -1.55), V(2.2, 0.2, 0.1), S())
	B(cab, "Windscreen", "cab_glass", V(0, 1.4, -1.55), V(2.2, 1.6, 0.05), S({"breaks": "Whole Block, Fragile"}))
	B(cab, "Roof", "crane", V(0, 2.475, 0), V(2.7, 0.15, 3.5), S())
	B(cab, "AirCon", "machine_dark", V(0.55, 3.05, 0.8), V(0.9, 1.0, 1.1), S())
	B(cab, "AirConGrille", "weight", V(0.55, 3.1, 0.23), V(0.7, 0.6, 0.04))
	B(cab, "Stripe", "crane", V(0, 0.75, 1.61), V(2.4, 0.16, 0.03))
	# Inside: the seat, the desk under the windscreen, and the lever on its pedestal.
	B(cab, "Seat", "machine_dark", V(0.55, 0.24, -0.55), V(0.5, 0.48, 0.5))
	B(cab, "SeatBack", "machine_dark", V(0.55, 0.78, -0.27), V(0.5, 0.62, 0.1))
	B(cab, "Desk", "machine_dark", V(0.2, 0.42, -1.3), V(1.5, 0.84, 0.36))
	B(cab, "Screen", "lamp", V(0.3, 0.9, -1.25), V(0.5, 0.06, 0.2))
	B(cab, "Pedestal", "machine_dark", V(-0.65, 0.275, -0.75), V(0.32, 0.55, 0.32))
	B(cab, "PedestalPlate", "hazard", V(-0.65, 0.56, -0.75), V(0.36, 0.03, 0.36))
	var lever := Node3D.new()
	lever.set_script(load("res://game/arena/map_lever.gd"))
	lever.position = V(-0.65, 0, -0.75)
	lever.set("event", NodePath("../../../CraneEvent"))
	lever.set("range", 1.7)
	lever.set("light", Color(0.25, 1.0, 0.4))
	lever.set("bots", false)
	lever.set("pivot_height", 0.58)
	lever.set("lamp_at", V(0.0, 0.66, -0.2))
	_add(cab, lever, "Lever")
	label(cab, "CRANE SLEW LEVER", V(0, 2.3, -1.49), Basis.IDENTITY, 40, 0.0035)
	label(cab, "OPERATOR", V(0, 2.25, 1.61), Basis.IDENTITY, 44, 0.004)


## What hangs from the hook: a second MapIsland with the same pivot.
func _hook(crane: Node3D) -> void:
	var at := MAST + JIB * V(0, 0, -REACH)
	var hook := Node3D.new()
	hook.set_script(load("res://game/arena/map_island.gd"))
	hook.transform = Transform3D(JIB, V(at.x, SLAB_TOP, at.z))
	hook.set("pivot", V(MAST.x, SLAB_TOP, MAST.z))
	hook.set("over_ground", true)
	hook.set_meta("_edit_group_", true)
	_add(crane, hook, "Hook")
	B(hook, "Slab", "concrete", V(0, -0.3, 0), V(2.4, 0.6, 6.0), S())
	for sz in [-1.0, 1.0]:
		B(hook, "Stripe", "hazard", V(0, 0.012, sz * 2.8), V(2.4, 0.024, 0.4))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B(hook, "LiftingEye", "weight", V(sx * 0.95, 0.06, sz * 2.3), V(0.16, 0.12, 0.16))
			rod(hook, "Sling", "cable", V(sx * 0.95, 0.1, sz * 2.3), V(0, 3.1, 0), 0.05)
	B(hook, "HookBlock", "crane", V(0, 3.5, 0), V(0.6, 0.8, 0.6))
	B(hook, "Hook", "weight", V(0, 3.0, 0), V(0.18, 0.3, 0.18))
	var bottom := Marker3D.new()
	bottom.position = V(0, 3.9, 0)
	_add(hook, bottom, "RopeBottom")


## Paint on the ground where the slab comes down in the yard.
func _loading_zone(crane: Node3D, stop: int) -> void:
	var turn: Basis = Y(STOP_TURNS[stop]) * JIB
	var at := MAST + turn * V(0, 0, -REACH)
	var zone := G(crane, "LoadingZone", V(at.x, 0, at.z), turn)
	for sx in [-1.0, 1.0]:
		B(zone, "Line", "hazard", V(sx * 1.85, 0.025, 0), V(0.3, 0.05, 7.8))
	for sz in [-1.0, 1.0]:
		B(zone, "Line", "hazard", V(0, 0.025, sz * 3.75), V(3.4, 0.05, 0.3))
	label(zone, "CRANE LOADING ZONE", V(2.35, 0.03, 0), Y(90.0) * Basis(Vector3.RIGHT, -PI * 0.5), 56, 0.01, Color(0.2, 0.2, 0.2))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			cone(zone, V(sx * 2.25, 0, sz * 4.1))


## A traffic cone (drawn only).
func cone(parent: Node, at: Vector3) -> void:
	var c := G(parent, "Cone", at)
	B(c, "Foot", "barrier", V(0, 0.02, 0), V(0.36, 0.04, 0.36))
	B(c, "Body", "barrier", V(0, 0.34, 0), V(0.26, 0.6, 0.26), {"shape": CONE, "top": 0.06, "sides": 10})
	B(c, "Band", "board", V(0, 0.38, 0), V(0.172, 0.12, 0.172), {"shape": CONE, "top": 0.128, "sides": 10})


# -- props ---------------------------------------------------------------------------
## A pallet with `layers` courses of something stacked on it (blocks, bricks), 1.2 x 1.0 m.
## Solid as one box.
func pack(parent: Node, called: String, at: Vector3, turn: Basis, kind: String, layers: int, wrap := "") -> Node3D:
	var g := GW(parent, called, at, turn)
	var h := 0.14 + layers * 0.4
	B(g, "Body", "plank", V(0, h * 0.5, 0), V(1.2, h, 1.0), {"hidden": true})
	for sz in [-0.4, 0.0, 0.4]:
		B(g, "Bearer", "plank", V(0, 0.05, sz), V(1.2, 0.1, 0.12))
	B(g, "Boards", "plank", V(0, 0.12, 0), V(1.2, 0.04, 1.0))
	for i in layers:
		B(g, "Course", kind, V(0, 0.34 + i * 0.4, 0), V(1.12 - 0.02 * (i % 2), 0.4, 0.92 - 0.02 * (i % 2)), {"tint": shade(0.06)})
	if wrap != "":
		for sx in [-0.3, 0.3]:
			B(g, "Strap", wrap, V(sx, 0.15 + layers * 0.2, 0), V(0.05, layers * 0.4 + 0.03, 0.96))
	return g


## A one-tonne bulk bag. Solid.
func bulk_bag(parent: Node, at: Vector3, turn := Basis.IDENTITY, load := "gravel") -> void:
	var g := GW(parent, "BulkBag", at, turn)
	B(g, "Bag", "bag", V(0, 0.475, 0), V(0.95, 0.95, 0.95), S({"tint": shade(0.05)}))
	B(g, "Load", load, V(0, 0.965, 0), V(0.8, 0.05, 0.8))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B(g, "Loop", "bag", V(sx * 0.43, 1.02, sz * 0.43), V(0.07, 0.2, 0.07))


## A water-filled road barrier, 1.5 m long along x. Solid.
func water_barrier(parent: Node, at: Vector3, turn: Basis, kind: String) -> void:
	var g := GW(parent, "WaterBarrier", at, turn)
	B(g, "Foot", kind, V(0, 0.15, 0), V(1.5, 0.3, 0.5), S())
	B(g, "Body", kind, V(0, 0.6, 0), V(1.5, 0.6, 0.3), S())
	B(g, "Cap", "rubber", V(0.45, 0.92, 0), V(0.14, 0.05, 0.14))


## A 1000 litre tank in its cage, on its pallet. Solid.
func tote(parent: Node, at: Vector3, turn := Basis.IDENTITY) -> void:
	var g := GW(parent, "WaterTote", at, turn)
	B(g, "Pallet", "plank", V(0, 0.07, 0), V(1.2, 0.14, 1.0))
	B(g, "Tank", "board", V(0, 0.69, 0), V(1.1, 1.1, 0.9), S())
	B(g, "Lid", "box_blue", V(0, 1.27, 0), V(0.3, 0.06, 0.3), {"shape": CYL, "sides": 10})
	for y in [0.3, 0.69, 1.08]:
		for sz in [-0.47, 0.47]:
			B(g, "Cage", "scaffold", V(0, y, sz), V(1.17, 0.04, 0.035))
		for sx in [-0.57, 0.57]:
			B(g, "Cage", "scaffold", V(sx, y, 0), V(0.035, 0.04, 0.97))
	for sx in [-0.57, -0.19, 0.19, 0.57]:
		B(g, "Cage", "scaffold", V(sx, 0.69, 0.47), V(0.035, 1.1, 0.035))
		B(g, "Cage", "scaffold", V(sx, 0.69, -0.47), V(0.035, 1.1, 0.035))


## A work light on a tripod (drawn only).
func tripod_light(parent: Node, at: Vector3, facing: float) -> void:
	var g := GW(parent, "WorkLight", at, Y(facing))
	for i in 3:
		rod(g, "Leg", "machine_dark", Y(i * 120.0) * V(0, 0.02, 0.55), V(0, 1.0, 0), 0.04)
	B(g, "Pole", "machine_dark", V(0, 1.35, 0), V(0.05, 0.9, 0.05))
	B(g, "Bar", "machine_dark", V(0, 1.8, 0), V(0.9, 0.05, 0.05))
	for sx in [-0.28, 0.28]:
		B(g, "Housing", "machine", V(sx, 1.95, 0), V(0.42, 0.3, 0.14))
		B(g, "Lens", "lamp", V(sx, 1.95, 0.08), V(0.36, 0.24, 0.02))


## A telescopic prop from a floor to the slab above it (drawn only).
func prop(parent: Node, at: Vector3, height: float) -> void:
	var g := GW(parent, "Prop", at)
	B(g, "Foot", "weight", V(0, 0.015, 0), V(0.22, 0.03, 0.22))
	B(g, "Outer", "box_red", V(0, height * 0.3, 0), V(0.085, height * 0.6 - 0.03, 0.085))
	B(g, "Inner", "scaffold", V(0, height * 0.79, 0), V(0.06, height * 0.4, 0.06))
	B(g, "Collar", "weight", V(0, height * 0.6, 0), V(0.13, 0.08, 0.13))
	B(g, "Head", "weight", V(0, height - 0.025, 0), V(0.22, 0.03, 0.22))


## Starter bars standing out of a column or a slab edge (drawn only).
func starter_bars(parent: Node, at: Vector3, across: Vector3, n: int, height: float) -> void:
	var g := GW(parent, "StarterBars", at)
	for i in n:
		var t := (i / float(n - 1) - 0.5) if n > 1 else 0.0
		var h := height * rng.randf_range(0.8, 1.0)
		B(g, "Bar", "rebar", across * t + V(0, h * 0.5, 0), V(0.035, h, 0.035))
		B(g, "Cap", "barrier", across * t + V(0, h + 0.03, 0), V(0.07, 0.06, 0.07))


## A sign board with its lettering, flat against something: `turn`'s z axis is the way
## it faces. `at` is the middle of its back.
func board_sign(parent: Node, text: String, at: Vector3, turn: Basis, size: Vector2, kind: String, font: int, ink := Color(0.16, 0.18, 0.22), pixel := 0.008) -> Node3D:
	var g := GW(parent, "Poster", at, turn)
	B(g, "Board", kind, V(0, 0, 0.03), V(size.x, size.y, 0.06))
	label(g, text, V(0, 0, 0.067), Basis.IDENTITY, font, fit(text, font, pixel, size), ink)
	return g


## The pixel size at which `text` fits a board of `size`, no larger than `pixel`.
func fit(text: String, font: int, pixel: float, size: Vector2) -> float:
	var lines := text.split("\n")
	var longest := 1
	for line in lines:
		longest = maxi(longest, line.length())
	return minf(pixel, minf(size.x * 0.88 / (longest * font * 0.62), size.y * 0.8 / (lines.size() * font * 1.3)))


## A paint mark or a patch on the ground: `thick` is also how high its top is, so give
## every kind its own.
func ground(parent: Node, called: String, kind: String, at: Vector2, size: Vector2, thick: float, turn := 0.0, opts := {}) -> void:
	var o := opts.duplicate()
	o["turn"] = Y(turn)
	B(parent, called, kind, V(at.x, thick * 0.5, at.y), V(size.x, thick, size.y), o)


## A pair of tyre tracks from `a` to `b` on the dirt.
func tracks(parent: Node, a: Vector2, b: Vector2, gauge := 1.9) -> void:
	var along := (b - a).normalized()
	var side := Vector2(-along.y, along.x) * gauge * 0.5
	var turn := rad_to_deg(atan2(along.x, along.y))
	for s in [-1.0, 1.0]:
		var mid: Vector2 = (a + b) * 0.5 + side * s
		ground(parent, "Track", "dirt_dark", mid, Vector2(0.4, a.distance_to(b)), 0.026, turn, {"tint": Color(0.78, 0.76, 0.74)})


# -- sightlines: sheeting, walls and cover -------------------------------------------
func sightlines() -> void:
	_scaffold_sheeting()
	_steel_netting()
	_tower_walls()
	_yard_cover()
	_canopies()


## Debris netting on the outside of the east scaffold, a sheet a bay: it hides whoever
## is on the decks from the east yard (and the yard from them) until it is shot out.
func _scaffold_sheeting() -> void:
	var g := G(scn.get_node("EastScaffold"), "Sheeting", Vector3.ZERO, Basis.IDENTITY, false)
	var bay := 35.0 / 13.0
	# lift (the deck it stands on) -> the bays that are sheeted, counted from the north
	var plan := {4.0: [1, 2, 3, 6, 7, 10, 11], 8.0: [0, 1, 2, 4, 5]}
	for lift in plan:
		for i in plan[lift]:
			var z: float = -16.0 + (i + 0.5) * bay
			for half in 2:
				B(g, "Sheet", "sheeting", V(18.43, lift + 1.0 + half * 1.94, z), V(0.06, 1.9, bay - 0.12), S({"breaks": "", "tint": shade(0.07)}))
			for y in [lift + 0.02, lift + 1.97, lift + 3.92]:
				B(g, "Lacing", "board", V(18.47, y, z), V(0.02, 0.05, bay - 0.3))
	# The builder's banner on the sheeting, facing the yard.
	var banner := G(g, "Banner", V(18.47, 6.9, 2.84), Y(90.0))
	B(banner, "Board", "board", V(0, 0, 0.02), V(4.6, 1.2, 0.04))
	label(banner, "JS BUILD CO.", V(0, 0, 0.05), Basis.IDENTITY, 84, fit("JS BUILD CO.", 84, 0.01, Vector2(4.6, 1.2)))


## Netting on the open steel frame: the bays round the slab's berth, and two more.
## The middle bay of the south face stays open (the swing out over the yard).
func _steel_netting() -> void:
	var g := G(scn.get_node("Tower"), "Netting", Vector3.ZERO, Basis.IDENTITY, false)
	# [face, the bay's middle along the face, the floor it stands on]
	var nets := [["south", -10.5, 12.0], ["south", -10.5, 16.0], ["south", 10.5, 12.0],
		["west", 10.5, 12.0], ["east", 10.5, 16.0], ["east", 0.0, 12.0]]
	for net in nets:
		for i in 4:
			var along: float = net[1] + (i - 1.5) * 2.375
			var y: float = net[2] + 1.6
			var o := S({"breaks": "", "tint": shade(0.07)})
			match net[0]:
				"south":
					B(g, "Net", "sheeting", V(along, y, 15.87), V(2.3, 3.1, 0.06), o)
					B(g, "Lacing", "board", V(along, y + 1.5, 15.91), V(2.1, 0.05, 0.02))
				"west":
					B(g, "Net", "sheeting", V(-15.87, y, along), V(0.06, 3.1, 2.3), o)
					B(g, "Lacing", "board", V(-15.91, y + 1.5, along), V(0.02, 0.05, 2.1))
				"east":
					B(g, "Net", "sheeting", V(15.87, y, along), V(0.06, 3.1, 2.3), o)
					B(g, "Lacing", "board", V(15.91, y + 1.5, along), V(0.02, 0.05, 2.1))


## A few blockwork walls inside the tower, to break up the long looks down its floors.
## Breakable, like the ones already there.
func _tower_walls() -> void:
	var tower := scn.get_node("Tower")
	# [where its foot's middle is, its size]
	var walls := [
		[V(-9.0, 4, -11.75), V(0.3, 2.6, 4.5)], [V(-7.35, 4, -9.65), V(3.0, 2.6, 0.3)],   # 4 m: an L in the north-west
		[V(12.0, 4, -7.0), V(5.0, 2.6, 0.3)],                                              # 4 m: east side
		[V(-4.5, 8, -12.25), V(0.3, 2.6, 4.5)],                                            # 8 m: north side
		[V(-13.0, 8, -1.0), V(4.0, 2.6, 0.3)],                                             # 8 m: west side
		[V(-3.0, 12, -11.25), V(0.3, 2.6, 4.5)],                                           # 12 m: north side
	]
	for w in walls:
		var size: Vector3 = w[1]
		var g := GW(tower, "BlockWall", w[0])
		B(g, "Block", "block", V(0, size.y * 0.5, 0), size, S({"breaks": ""}))
		# A few blocks waiting to go on, and the mortar board.
		var wide := size.x > size.z
		var along: Vector3 = V(1, 0, 0) if wide else V(0, 0, 1)
		var out: Vector3 = V(0, 0, 1) if wide else V(1, 0, 0)
		var half := maxf(size.x, size.z) * 0.5
		B(g, "LooseBlocks", "block", along * (half - 0.6) + out * 0.5 + V(0, 0.2, 0), V(0.45, 0.4, 0.45), {"tint": shade(0.05)})
		B(g, "LooseBlock", "block", along * (half - 0.62) + out * 0.52 + V(0, 0.5, 0), V(0.44, 0.2, 0.22), {"tint": shade(0.05), "turn": Y(20.0)})
		B(g, "MortarBoard", "ply", along * (half - 1.5) + out * 0.55 + V(0, 0.03, 0), V(0.6, 0.06, 0.6))
		B(g, "Mortar", "concrete_dark", along * (half - 1.5) + out * 0.55 + V(0, 0.1, 0), V(0.34, 0.08, 0.34), {"shape": CONE, "top": 0.1, "sides": 8})


## Things standing in the yard's long lanes.
func _yard_cover() -> void:
	var yard := scn.get_node("Yard")
	# North lane: a rack of precast panels against the fence, and packs of bricks.
	var rack := GW(yard, "PanelRack", V(-9, 0, -37.0))
	B(rack, "Body", "concrete", V(0, 1.35, 0), V(4.2, 2.7, 1.7), {"hidden": true})
	for sx in [-1.6, 0.0, 1.6]:
		B(rack, "Foot", "steel", V(sx, 0.08, 0), V(0.14, 0.16, 1.9))
		rod(rack, "Leg", "steel", V(sx, 0.16, -0.8), V(sx, 2.7, -0.06), 0.12)
		rod(rack, "Leg", "steel", V(sx, 0.16, 0.8), V(sx, 2.7, 0.06), 0.12)
	B(rack, "Ridge", "steel", V(0, 2.72, 0), V(3.6, 0.12, 0.2))
	for side in [-1.0, 1.0]:
		for i in 2:
			var lean := Basis(Vector3.RIGHT, deg_to_rad(16.5 * side))
			B(rack, "Panel", "concrete", V(0, 1.3, side * (0.62 + i * 0.19)), V(4.0 - i * 0.3, 2.3, 0.15), {"turn": lean, "tint": shade(0.05)})
	pack(yard, "BrickPack", V(6.9, 0, -36.4), Y(4.0), "brick", 4, "cable")
	pack(yard, "BrickPack", V(8.3, 0, -36.5), Y(-3.0), "brick", 4, "cable")
	pack(yard, "BrickPack", V(7.6, 0, -35.1), Y(88.0), "brick", 2, "cable")
	# West lane: packs of blocks north of the conveyor, a dumper south of it.
	pack(yard, "BlockPack", V(-37.2, 0, -8.6), Y(2.0), "block", 4, "cable")
	pack(yard, "BlockPack", V(-37.3, 0, -7.3), Y(-4.0), "block", 4, "cable")
	pack(yard, "BlockPack", V(-35.8, 0, -8.0), Y(92.0), "block", 2, "cable")
	_dumper(yard, V(-34.2, 0, 16.6), Y(8.0))
	# South lane: a spoil heap by the pit and a tipper waiting on the road.
	var heap := GW(yard, "SpoilHeap", V(-15.4, 0, 35.3))
	B(heap, "Heap", "dirt_dark", V(0, 0.95, 0), V(5.6, 1.9, 5.6), S({"shape": CONE, "top": 1.4, "sides": 10}))
	B(heap, "Heap", "dirt_dark", V(2.3, 0.5, -1.7), V(3.2, 1.0, 3.2), S({"shape": CONE, "top": 0.8, "sides": 9, "tint": Color(1.06, 1.05, 1.03)}))
	for i in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.9, 3.6)
		B(heap, "Clod", "dirt_dark", V(cos(a) * r, 0.09, sin(a) * r), V(0.3, 0.18, 0.26), {"turn": Y(rng.randf() * 90.0)})
	rod(heap, "Shovel", "plank", V(-1.5, 0.9, 1.6), V(-1.2, 2.1, 1.3), 0.05)
	_tipper(yard, V(13.5, 0, 35.3), Y(90.0))
	# North of the tower: bulk bags between the containers and the scaffold stair.
	bulk_bag(yard, V(5.6, 0, -22.4), Y(5.0))
	bulk_bag(yard, V(6.7, 0, -22.5), Y(-3.0), "dirt_dark")
	bulk_bag(yard, V(6.1, 0, -23.5), Y(10.0))
	bulk_bag(yard, V(6.2, 0.95, -22.6), Y(-8.0), "dirt_dark")
	# North-east: water barriers between the crane's foot and the fence.
	for i in 4:
		water_barrier(yard, V(28.4 + i * 1.56, 0, -20.6 - i * 0.12), Y(4.0), "barrier_red" if i % 2 == 0 else "board")
	# East: water tanks by the silos, and a cage of gas bottles by the tower's west face.
	tote(yard, V(28.6, 0, -1.6), Y(3.0))
	tote(yard, V(28.5, 0, -0.4), Y(-2.0))
	tote(yard, V(28.6, 1.3, -1.0), Y(1.0))
	var cage := GW(yard, "GasCage", V(-19.5, 0, -14.5))
	B(cage, "Body", "scaffold", V(0, 0.95, 0), V(1.7, 1.9, 0.95), {"hidden": true})
	B(cage, "Base", "weight", V(0, 0.04, 0), V(1.7, 0.08, 0.95))
	B(cage, "Roof", "weight", V(0, 1.88, 0), V(1.74, 0.05, 1.0))
	for sx in [-0.83, 0.0, 0.83]:
		for sz in [-0.45, 0.45]:
			B(cage, "Post", "machine", V(sx, 0.96, sz), V(0.05, 1.8, 0.05))
	for y in [0.5, 1.0, 1.5]:
		for sz in [-0.45, 0.45]:
			B(cage, "Bar", "machine", V(0, y, sz), V(1.66, 0.03, 0.03))
		for sx in [-0.83, 0.83]:
			B(cage, "Bar", "machine", V(sx, y, 0), V(0.03, 0.03, 0.9))
	for i in 5:
		var kind: String = ["box_red", "box_red", "box_blue", "box_orange", "box_red"][i]
		B(cage, "Bottle", kind, V(-0.62 + i * 0.31, 0.7, 0.05), V(0.25, 1.24, 0.25), {"shape": CYL, "sides": 10})
		B(cage, "Valve", "weight", V(-0.62 + i * 0.31, 1.38, 0.05), V(0.09, 0.12, 0.09), {"shape": CYL, "sides": 8})
	board_sign(cage, "NO SMOKING", V(-19.5, 1.45, -14.02), Basis.IDENTITY, Vector2(1.1, 0.3), "sign_red", 40, Color(0.97, 0.97, 0.95), 0.005)


## A site dumper: the skip in front (-z), the driver behind.
func _dumper(yard: Node, at: Vector3, turn: Basis) -> void:
	var d := GW(yard, "Dumper", at, turn)
	B(d, "SkipBody", "machine", V(0, 1.0, -1.05), V(2.0, 2.0, 2.0), {"hidden": true})
	B(d, "RearBody", "machine", V(0, 0.85, 1.05), V(1.8, 1.7, 2.1), {"hidden": true})
	B(d, "Chassis", "machine_dark", V(0, 0.62, 0), V(1.2, 0.3, 4.0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.15, 1.25]:
			B(d, "Wheel", "rubber", V(sx * 0.88, 0.55, sz), V(1.1, 0.42, 1.1), {"shape": CYL, "turn": AXIS_X, "sides": 14})
			B(d, "Hub", "machine", V(sx * 1.1, 0.55, sz), V(0.42, 0.03, 0.42), {"shape": CYL, "turn": AXIS_X, "sides": 10})
	B(d, "SkipFloor", "machine", V(0, 1.0, -1.0), V(1.96, 0.5, 1.9))
	B(d, "SkipFront", "machine", V(0, 1.5, -1.85), V(1.96, 0.9, 0.16), {"turn": Basis(Vector3.RIGHT, -0.3)})
	for sx in [-1.0, 1.0]:
		B(d, "SkipSide", "machine", V(sx * 0.92, 1.56, -1.0), V(0.12, 0.66, 1.9))
	B(d, "Load", "gravel", V(0, 1.42, -1.0), V(1.7, 0.4, 1.6), {"shape": CONE, "top": 0.7, "sides": 8})
	B(d, "Engine", "machine", V(0, 1.05, 1.5), V(1.5, 0.75, 1.1))
	B(d, "Grille", "machine_dark", V(0, 1.05, 2.07), V(1.1, 0.5, 0.04))
	B(d, "Seat", "rubber", V(0, 1.0, 0.45), V(0.6, 0.5, 0.6))
	B(d, "SeatBack", "rubber", V(0, 1.45, 0.72), V(0.6, 0.6, 0.12))
	B(d, "SteeringWheel", "rubber", V(0, 1.5, 0.05), V(0.42, 0.05, 0.42), {"shape": CYL, "turn": Basis(Vector3.RIGHT, 1.0), "sides": 10})
	for sx in [-1.0, 1.0]:
		B(d, "RollBar", "machine_dark", V(sx * 0.7, 1.95, 0.95), V(0.08, 1.2, 0.08))
	B(d, "RollBar", "machine_dark", V(0, 2.55, 0.95), V(1.48, 0.08, 0.08))
	B(d, "Beacon", "barrier", V(0, 2.67, 0.95), V(0.16, 0.14, 0.16), {"shape": CYL, "sides": 8})


## A tipper truck, loaded: the cab in front (-z).
func _tipper(yard: Node, at: Vector3, turn: Basis) -> void:
	var t := GW(yard, "Tipper", at, turn)
	B(t, "CabBody", "machine", V(0, 1.3, -2.3), V(2.3, 2.6, 1.9), {"hidden": true})
	B(t, "TipBody", "weight", V(0, 1.3, 0.95), V(2.4, 2.6, 4.5), {"hidden": true})
	B(t, "Chassis", "machine_dark", V(0, 0.75, 0.2), V(0.9, 0.3, 6.2))
	for sx in [-1.0, 1.0]:
		for sz in [-2.25, 1.35, 2.5]:
			B(t, "Wheel", "rubber", V(sx * 0.98, 0.5, sz), V(1.0, 0.36, 1.0), {"shape": CYL, "turn": AXIS_X, "sides": 14})
			B(t, "Hub", "weight", V(sx * 1.17, 0.5, sz), V(0.4, 0.03, 0.4), {"shape": CYL, "turn": AXIS_X, "sides": 10})
		B(t, "Mudguard", "machine_dark", V(sx * 1.01, 1.08, 1.92), V(0.46, 0.06, 2.5))
	B(t, "Cab", "box_blue", V(0, 1.75, -2.3), V(2.26, 1.7, 1.86))
	B(t, "Bumper", "machine_dark", V(0, 0.75, -3.27), V(2.3, 0.4, 0.14))
	B(t, "Windscreen", "cab_glass", V(0, 2.05, -3.25), V(1.9, 0.8, 0.03))
	for sx in [-1.0, 1.0]:
		B(t, "DoorGlass", "cab_glass", V(sx * 1.145, 2.05, -2.45), V(0.03, 0.7, 0.9))
		B(t, "Headlight", "lamp", V(sx * 0.8, 1.15, -3.245), V(0.3, 0.16, 0.03))
		B(t, "Mirror", "machine_dark", V(sx * 1.28, 2.1, -3.0), V(0.08, 0.36, 0.2))
	B(t, "Grille", "machine_dark", V(0, 1.5, -3.245), V(1.3, 0.36, 0.03))
	B(t, "Beacon", "barrier", V(0, 2.67, -2.3), V(0.6, 0.12, 0.2))
	B(t, "TipFloor", "weight", V(0, 1.05, 0.95), V(2.36, 0.2, 4.46))
	for sx in [-1.0, 1.0]:
		B(t, "TipSide", "weight", V(sx * 1.12, 1.75, 1.01), V(0.12, 1.2, 4.34), {"tint": shade(0.04)})
		for i in 4:
			B(t, "Rib", "machine_dark", V(sx * 1.2, 1.75, -0.8 + i * 1.15), V(0.06, 1.2, 0.12))
	B(t, "TipFront", "weight", V(0, 1.95, -1.22), V(2.44, 1.6, 0.12))
	B(t, "Tailgate", "weight", V(0, 1.77, 3.15), V(2.44, 1.24, 0.1))
	B(t, "LoadBed", "dirt_dark", V(0, 2.1, 0.95), V(2.12, 0.5, 4.3))
	B(t, "Load", "dirt_dark", V(0, 2.56, 0.95), V(1.9, 0.42, 3.9), {"tint": Color(1.06, 1.05, 1.03)})


## Roofs over two corners of the yard: they hide who is under them from the tower.
func _canopies() -> void:
	var yard := scn.get_node("Yard")
	# The rebar store, over the cable drums south-west of the tower.
	var store := GW(yard, "RebarStore", V(-12.0, 0, 24.5))
	for sx in [-3.5, 0.0, 3.5]:
		for sz in [-2.9, 2.9]:
			B(store, "Post", "scaffold", V(sx, 1.7 + (0.15 if sz < 0 else -0.15), sz), V(0.14, 3.4 + (0.3 if sz < 0 else -0.3), 0.14), S())
	var pitch := Basis(Vector3.RIGHT, deg_to_rad(5.9))
	B(store, "Roof", "canopy", V(0, 3.5, 0), V(7.6, 0.1, 6.5), S({"turn": pitch}))
	for sx in [-3.5, 0.0, 3.5]:
		B(store, "Rafter", "scaffold", V(sx, 3.39, 0), V(0.1, 0.1, 6.0), {"turn": pitch})
	# Bundles of bar on timbers, under the east half (the drums stand in the west half).
	var bars := GW(store, "RebarBundles", V(-9.6, 0, 22.6))
	B(bars, "Body", "rebar", V(0, 0.28, 0), V(3.2, 0.56, 1.5), {"hidden": true})
	for sx in [-1.2, 0.0, 1.2]:
		B(bars, "Bearer", "plank", V(sx, 0.06, 0), V(0.14, 0.12, 1.6))
	for i in 5:
		var z := -0.6 + i * 0.3
		B(bars, "Bundle", "rebar", V(rng.randf_range(-0.08, 0.08), 0.24, z), V(0.24, 3.2, 0.24), {"shape": CYL, "turn": Basis(Vector3.FORWARD, PI * 0.5), "sides": 7, "tint": shade(0.1)})
	for i in 3:
		B(bars, "Bundle", "rebar", V(0.06 * i, 0.46, -0.3 + i * 0.3), V(0.22, 3.0, 0.22), {"shape": CYL, "turn": Basis(Vector3.FORWARD, PI * 0.5), "sides": 7, "tint": shade(0.1)})
	board_sign(store, "REBAR STORE", V(-12.0, 2.75, 27.48), Basis.IDENTITY, Vector2(2.6, 0.5), "board", 56)
	# The break shelter between the site office and the north-west loading zone.
	var shelter := GW(yard, "BreakShelter", V(-28.0, 0, -27.5))
	for sx in [-2.4, 2.4]:
		for sz in [-1.9, 1.9]:
			B(shelter, "Post", "scaffold", V(sx, 1.4, sz), V(0.12, 2.8, 0.12), S())
	B(shelter, "Roof", "canopy", V(0, 2.86, 0), V(5.4, 0.1, 4.4), S())
	B(shelter, "Fascia", "hazard", V(0, 2.78, 2.22), V(5.4, 0.16, 0.04))
	B(shelter, "Back", "hoarding", V(-2.4, 1.3, 0), V(0.1, 2.6, 3.66), S())
	B(shelter, "Table", "plank", V(0.3, 0.74, 0), V(1.8, 0.06, 0.8))
	for sx in [-0.5, 1.1]:
		B(shelter, "TableLeg", "scaffold", V(sx, 0.36, 0), V(0.06, 0.72, 0.7))
	for sz in [-0.75, 0.75]:
		B(shelter, "Bench", "plank", V(0.3, 0.225, sz), V(1.8, 0.45, 0.36), S())
	B(shelter, "Urn", "silo", V(0.9, 0.95, 0.1), V(0.22, 0.36, 0.22), {"shape": CYL, "sides": 10})
	B(shelter, "Mug", "box_red", V(0.2, 0.82, -0.15), V(0.08, 0.1, 0.08), {"shape": CYL, "sides": 8})
	B(shelter, "Mug", "box_blue", V(-0.1, 0.82, 0.2), V(0.08, 0.1, 0.08), {"shape": CYL, "sides": 8})
	B(shelter, "Bin", "machine_dark", V(1.9, 0.4, -1.5), V(0.5, 0.8, 0.5), {"shape": CYL, "sides": 10})
	board_sign(shelter, "0 DAYS\nSINCE LAST INCIDENT", V(-30.35, 1.7, -27.5), Y(90.0), Vector2(2.6, 1.1), "board", 54)


# -- dressing: drawn-only detail -----------------------------------------------------
func dressing() -> void:
	_ground_marks()
	_yard_props()
	_tower_dressing()
	_fence_posters()


func _ground_marks() -> void:
	var g := G(scn.get_node("Ground"), "Marks", Vector3.ZERO, Basis.IDENTITY, false)
	# Tyre tracks off the gravel: to the pit, to the excavator, round the north-west.
	tracks(g, Vector2(-4.6, 34.8), Vector2(-11.6, 31.4))
	tracks(g, Vector2(-12.4, 30.4), Vector2(-18.6, 22.4))
	tracks(g, Vector2(-19.0, 21.4), Vector2(-20.8, 12.5))
	tracks(g, Vector2(-16.4, -32.0), Vector2(-24.0, -24.0))
	tracks(g, Vector2(-24.6, -23.4), Vector2(-31.0, -20.4))
	tracks(g, Vector2(25.8, 15.6), Vector2(35.5, 16.6))
	tracks(g, Vector2(26.0, -18.5), Vector2(33.0, -12.0), 2.1)
	# Puddles, where the ground is low.
	var puddles := [[Vector2(-19.6, -23.6), Vector2(2.6, 1.7)], [Vector2(-31.5, 9.5), Vector2(2.2, 1.5)], [Vector2(9.5, 28.6), Vector2(3.0, 1.8)],
		[Vector2(31.5, -9.5), Vector2(2.0, 1.4)], [Vector2(-6.5, -26.5), Vector2(2.4, 1.5)], [Vector2(33.5, 7.6), Vector2(1.8, 1.3)],
		[Vector2(-27.0, 7.9), Vector2(2.2, 1.2)], [Vector2(13.0, -25.6), Vector2(1.9, 1.3)]]
	for p in puddles:
		var skew := Y(rng.randf() * 180.0)
		B(g, "Puddle", "puddle", V(p[0].x, 0.02, p[0].y), V(p[1].x, 0.04, p[1].y), {"shape": CYL, "sides": 11, "turn": skew})
		B(g, "Puddle", "puddle", V(p[0].x, 0.02, p[0].y) + skew * V(p[1].x * 0.42, 0, p[1].y * 0.2), V(p[1].x * 0.55, 0.04, p[1].y * 0.6), {"shape": CYL, "sides": 9, "turn": skew})
		B(g, "Puddle", "puddle", V(p[0].x, 0.02, p[0].y) + skew * V(-p[1].x * 0.36, 0, -p[1].y * 0.3), V(p[1].x * 0.45, 0.04, p[1].y * 0.5), {"shape": CYL, "sides": 8, "turn": skew})
	# Lines along the road's edges, a stop line at the gate and a walkway to the tower.
	for z in [-34.3, -29.7]:
		for i in 9:
			ground(g, "RoadLine", "board", Vector2(-13.0 + i * 4.0, z), Vector2(2.2, 0.14), 0.06)
	ground(g, "StopLine", "board", Vector2(0, 37.6), Vector2(7.4, 0.3), 0.06)
	for x in [-7.2, -5.6]:
		for i in 6:
			ground(g, "Walkway", "board", Vector2(x, 30.3 - i * 2.3), Vector2(0.12, 1.5), 0.06)
	for i in 3:
		ground(g, "WalkwayMark", "sign_green", Vector2(-6.4, 29.2 - i * 4.6), Vector2(0.9, 0.9), 0.045)
	# The pit's edge.
	for i in 8:
		if i < 3:   # (the excavator and the ramp into the pit take the rest of the north edge)
			ground(g, "PitEdge", "hazard", Vector2(-35.0 + i * 2.0, 19.55), Vector2(1.6, 0.3), 0.05)
		ground(g, "PitEdge", "hazard", Vector2(-19.55, 21.0 + i * 2.0), Vector2(0.3, 1.6), 0.05)
	# Rubble and offcuts scattered where the work is.
	var litter := [Vector2(-18.5, 9.5), Vector2(19.8, 10.5), Vector2(-17.6, -9.0), Vector2(8.0, 19.0), Vector2(-9.0, -24.0),
		Vector2(26.5, 16.5), Vector2(-33.0, -18.0), Vector2(20.0, -9.0), Vector2(-9.2, 19.4), Vector2(31.0, 33.5)]
	for at in litter:
		for i in 5:
			var off := Vector2(rng.randf_range(-1.1, 1.1), rng.randf_range(-1.1, 1.1))
			var kind: String = ["block", "concrete_dark", "plank", "brick", "block"][rng.randi() % 5]
			var size := V(rng.randf_range(0.7, 1.4), 0.04 + i * 0.007, 0.12) if kind == "plank" else V(rng.randf_range(0.18, 0.42), 0.1 + i * 0.021, rng.randf_range(0.16, 0.3))
			B(g, "Rubble", kind, V(at.x + off.x, size.y * 0.5, at.y + off.y), size, {"turn": Y(rng.randf() * 180.0), "tint": shade(0.08)})


func _yard_props() -> void:
	var yard := scn.get_node("Yard")
	# Cones: along the walkway, at the road's bends and round the pit.
	for at in [V(-5.4, 0, 31.6), V(-5.4, 0, 27.0), V(-5.4, 0, 22.4), V(19.4, 0, 31.6), V(26.4, 0, 33.6), V(19.6, 0, -28.6), V(26.4, 0, -22.0),
			V(-17.0, 0, -28.8), V(-37.0, 0, 19.0), V(-19.0, 0, 19.0), V(4.9, 0, 38.4), V(-4.9, 0, 38.4)]:
		cone(yard, at)
	# Wheelbarrows, a generator, a cement mixer and its bags, a stack of timber.
	_wheelbarrow(yard, V(-18.6, 0, 11.4), Y(35.0), "concrete_dark")
	_wheelbarrow(yard, V(9.4, 0, 20.6), Y(-70.0), "dirt_dark")
	_wheelbarrow(yard, V(-13.4, 0, 32.2), Y(160.0), "dirt_dark")
	var gen := GW(yard, "Generator", V(-22.0, 0, -37.0))
	B(gen, "Body", "machine", V(0, 0.55, 0), V(1.8, 0.9, 0.9), S())
	B(gen, "Skid", "machine_dark", V(0, 0.05, 0), V(1.9, 0.1, 0.8))
	B(gen, "Panel", "machine_dark", V(-0.45, 0.6, 0.46), V(0.6, 0.5, 0.03))
	B(gen, "Vent", "machine_dark", V(0.45, 0.6, 0.46), V(0.7, 0.5, 0.03))
	B(gen, "Exhaust", "weight", V(0.6, 1.2, -0.2), V(0.1, 0.4, 0.1), {"shape": CYL, "sides": 8})
	B(gen, "Lamp", "lamp", V(-0.6, 0.72, 0.48), V(0.08, 0.08, 0.02))
	rod(gen, "Cable", "cable", V(-0.9, 0.3, 0.2), V(-1.5, 0.1, 0.9), 0.05)
	rod(gen, "Cable", "cable", V(-1.5, 0.1, 0.9), V(-1.9, 0.1, 5.2), 0.05)
	var mixer := GW(yard, "CementMixer", V(11.2, 0, 21.2), Y(-25.0))
	B(mixer, "Body", "machine", V(0, 0.6, 0), V(0.9, 1.2, 1.3), {"hidden": true})
	B(mixer, "Frame", "machine_dark", V(0, 0.3, 0), V(0.7, 0.08, 1.3))
	for sx in [-1.0, 1.0]:
		B(mixer, "Wheel", "rubber", V(sx * 0.42, 0.2, 0.45), V(0.4, 0.1, 0.4), {"shape": CYL, "turn": AXIS_X, "sides": 10})
		B(mixer, "Leg", "machine_dark", V(sx * 0.3, 0.15, -0.5), V(0.06, 0.3, 0.06))
	B(mixer, "Drum", "machine", V(0, 0.85, -0.05), V(0.8, 0.8, 0.8), {"shape": CONE, "top": 0.5, "sides": 10, "turn": Basis(Vector3.RIGHT, -0.6)})
	B(mixer, "Motor", "machine_dark", V(0, 0.57, 0.5), V(0.5, 0.45, 0.4))
	var bags := GW(yard, "CementBags", V(12.7, 0, 21.9), Y(12.0))
	B(bags, "Body", "bag", V(0, 0.35, 0), V(1.2, 0.7, 1.0), {"hidden": true})
	B(bags, "Pallet", "plank", V(0, 0.07, 0), V(1.2, 0.14, 1.0))
	for i in 4:
		for j in 2:
			B(bags, "Bag", "bag", V(-0.3 + j * 0.6 + (0.03 if i % 2 == 0 else -0.03), 0.21 + i * 0.14, 0), V(0.55, 0.13, 0.9), {"tint": shade(0.06)})
	var timber := GW(yard, "TimberStack", V(6.6, 0, 17.6), Y(90.0))
	B(timber, "Body", "plank", V(0, 0.4, 0), V(1.2, 0.8, 3.6), {"hidden": true})
	for sz in [-1.3, 0.0, 1.3]:
		B(timber, "Bearer", "plank", V(0, 0.05, sz), V(1.2, 0.1, 0.1))
	for i in 4:
		for j in 5:
			B(timber, "Length", "plank", V(-0.48 + j * 0.24, 0.19 + i * 0.165, rng.randf_range(-0.12, 0.12)), V(0.22, 0.15, 3.4), {"tint": shade(0.09)})
	# The site office: windows, a door with its step and lamp, a sign, an air conditioner.
	var office := GW(yard, "OfficeFittings", V(-30.0, 0, -31.66))
	for i in 2:
		var x := -3.0 + i * 6.0
		for y in [1.6, 4.2]:
			B(office, "WindowBack", "weight", V(x, y, -0.07), V(1.66, 0.96, 0.14))
			B(office, "Window", "cab_glass", V(x, y, 0.02), V(1.5, 0.8, 0.04))
			B(office, "Sill", "board", V(x, y - 0.52, -0.02), V(1.8, 0.07, 0.28))
	B(office, "Door", "box_blue", V(0.2, 1.05, -0.06), V(0.95, 2.1, 0.16))
	B(office, "DoorHandle", "weight", V(0.55, 1.05, 0.04), V(0.06, 0.2, 0.05))
	B(office, "Step", "deck", V(0.2, 0.1, 0.5), V(1.4, 0.2, 0.9), S())
	B(office, "Lamp", "lamp", V(0.2, 2.4, 0.08), V(0.4, 0.1, 0.12))
	B(office, "AirCon", "silo", V(4.9, 3.0, 0.22), V(0.9, 0.6, 0.4))
	B(office, "AirConFan", "weight", V(4.9, 3.0, 0.43), V(0.44, 0.03, 0.44), {"shape": CYL, "turn": AXIS_Z, "sides": 10})
	board_sign(office, "SITE OFFICE\nALL VISITORS REPORT HERE", V(-30.2, 3.1, -31.66), Basis.IDENTITY, Vector2(3.4, 0.8), "sign_blue", 44, Color(0.97, 0.97, 0.95), 0.006)
	# The silos: ladders with hoops, and the feed pipes.
	for z in [-4.1, 1.1]:
		var silo := GW(yard, "SiloFittings", V(32.72, 0, z))
		for sz in [-0.22, 0.22]:
			B(silo, "LadderRail", "scaffold", V(0, 6.3, sz), V(0.05, 11.4, 0.05))
		for i in 25:
			B(silo, "Rung", "scaffold", V(0, 0.9 + i * 0.45, 0), V(0.035, 0.035, 0.44))
		for i in 5:
			B(silo, "Hoop", "scaffold", V(-0.36, 3.2 + i * 2.0, 0), V(0.8, 0.05, 0.8), {"shape": TUBE, "inner": 0.72, "sides": 10})
		rod(silo, "FeedPipe", "pipe", V(0.3, 0.4, 1.6), V(0.3, 9.0, 1.6), 0.16)
		rod(silo, "FeedPipe", "pipe", V(0.3, 0.4, 1.6), V(-1.6, 0.4, 1.6), 0.16)
		B(silo, "Coupling", "box_red", V(-1.6, 0.4, 1.6), V(0.26, 0.26, 0.26))
	# A hand-wash station by the toilets; the skip gets its load.
	var wash := GW(yard, "WashStation", V(-38.6, 0, -13.2))
	B(wash, "Body", "box_blue", V(0, 0.55, 0), V(0.8, 1.1, 0.6), S())
	B(wash, "Basin", "silo", V(0, 1.13, 0.05), V(0.6, 0.06, 0.4))
	B(wash, "Tap", "weight", V(0, 1.3, -0.15), V(0.05, 0.3, 0.05))
	var skip := GW(yard, "SkipLoad", V(-31.0, 0, -13.0))
	for i in 7:
		var kind: String = ["plank", "block", "ply", "concrete_dark", "plank", "rebar", "brick"][i]
		var size := V(rng.randf_range(0.6, 1.6), rng.randf_range(0.08, 0.3), rng.randf_range(0.2, 0.7))
		B(skip, "Waste", kind, V(rng.randf_range(-0.6, 0.6), 1.5 + i * 0.05, rng.randf_range(-1.1, 1.1)), size, {"turn": Y(rng.randf() * 180.0) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))})
	# Bollards round the crane's foot.
	for at in [V(30.4, 0, -23.6), V(30.4, 0, -30.4), V(23.6, 0, -30.4)]:
		var bollard := GW(yard, "Bollard", at)
		B(bollard, "Post", "crane", V(0, 0.5, 0), V(0.22, 1.0, 0.22), S({"shape": CYL, "sides": 8}))
		B(bollard, "Band", "cable", V(0, 0.8, 0), V(0.24, 0.12, 0.24), {"shape": CYL, "sides": 8})


func _wheelbarrow(yard: Node, at: Vector3, turn: Basis, load: String) -> void:
	var w := GW(yard, "Wheelbarrow", at, turn)
	B(w, "Tray", "box_green", V(0, 0.52, 0), V(0.66, 0.3, 0.9))
	B(w, "Load", load, V(0, 0.69, 0), V(0.54, 0.1, 0.76))
	B(w, "Wheel", "rubber", V(0, 0.19, -0.62), V(0.38, 0.1, 0.38), {"shape": CYL, "turn": AXIS_X, "sides": 10})
	for sx in [-1.0, 1.0]:
		rod(w, "Handle", "scaffold", V(sx * 0.2, 0.3, -0.55), V(sx * 0.3, 0.6, 0.95), 0.035)
		B(w, "Leg", "scaffold", V(sx * 0.26, 0.19, 0.35), V(0.03, 0.38, 0.03))


## Detail inside the tower and on its steel (drawn only).
func _tower_dressing() -> void:
	var g := G(scn.get_node("TowerCover"), "Dressing", Vector3.ZERO, Basis.IDENTITY, false)
	# Props under the slab edges that are still curing.
	for at in [V(6.4, 0, -3.4), V(6.4, 0, 1.4), V(13.6, 0, -3.4), V(13.6, 0, 1.4), V(-2.0, 0, 13.6), V(2.0, 0, 13.6),
			V(6.4, 4, -3.4), V(6.4, 4, 1.4), V(13.6, 4, -3.4), V(13.6, 4, 1.4), V(-13.6, 4, -13.4), V(-7.4, 4, -13.4), V(-13.6, 4, -7.4),
			V(-13.4, 8, 5.4), V(-9.0, 8, 5.4), V(-4.4, 8, 5.4), V(5.4, 8, 3.4), V(5.4, 8, 1.0)]:
		prop(g, at, 3.6)
	# Work lights.
	tripod_light(g, V(-13.5, 0, -13.0), 135.0)
	tripod_light(g, V(13.7, 0, 14.1), -45.0)
	tripod_light(g, V(13.4, 4, -13.4), -135.0)
	tripod_light(g, V(-13.6, 4, 13.8), 45.0)
	tripod_light(g, V(-13.5, 8, -3.8), 60.0)
	tripod_light(g, V(4.6, 12, 4.8), -150.0)
	tripod_light(g, V(-13.6, 16, -6.4), 120.0)
	tripod_light(g, V(-14.0, 20, -14.0), 135.0)
	# Festoon lights under the slabs, north of the core.
	for floor_y in [0.0, 4.0, 8.0]:
		var lamps := 5 if floor_y > 7.0 else 7       # (the 12 m slab stops at x = 6)
		for i in lamps:
			var x := -13.5 + i * 4.5
			B(g, "Festoon", "lamp", V(x, floor_y + 3.36, -4.4), V(0.16, 0.16, 0.16), {"shape": CYL, "sides": 8})
			B(g, "FestoonCap", "machine", V(x, floor_y + 3.475, -4.4), V(0.1, 0.07, 0.1), {"shape": CYL, "sides": 8})
		rod(g, "FestoonCable", "cable", V(-15.0, floor_y + 3.53, -4.4), V(-13.5 + (lamps - 1) * 4.5 + 1.0, floor_y + 3.53, -4.4), 0.03)
	# Starter bars on the columns that go on up, and along the top floors' open edges.
	for at in [V(-15.5, 20, -15.5), V(-5.5, 20, -15.5), V(-15.5, 20, -5.5)]:
		starter_bars(g, at + V(0, 0, 0.3), V(0.6, 0, 0), 3, 1.1)
		starter_bars(g, at + V(0, 0, -0.3), V(0.6, 0, 0), 3, 1.1)
	for x in [-14.6, -13.2, -7.2, -5.8, -4.4]:   # (not where the stair and the crate climb come up)
		starter_bars(g, V(x, 16, -5.12), V(0.9, 0, 0), 3, 0.9)
	# Warnings on the core.
	board_sign(g, "LIFT SHAFT\nOPEN EDGE", V(0, 5.6, -3.0), Y(180.0), Vector2(1.6, 0.7), "hazard", 40, Color(0.1, 0.1, 0.1), 0.006)
	board_sign(g, "LIFT SHAFT\nOPEN EDGE", V(0, 9.6, -3.0), Y(180.0), Vector2(1.6, 0.7), "hazard", 40, Color(0.1, 0.1, 0.1), 0.006)
	board_sign(g, "HARD HAT AREA", V(-3.0, 1.9, 1.8), Y(-90.0), Vector2(1.5, 0.4), "sign_blue", 44, Color(0.97, 0.97, 0.95), 0.006)
	board_sign(g, "FIRE POINT", V(3.0, 5.4, -1.8), Y(90.0), Vector2(1.0, 0.34), "sign_red", 40, Color(0.97, 0.97, 0.95), 0.006)
	B(g, "Extinguisher", "box_red", V(3.14, 4.5, -1.8), V(0.2, 0.6, 0.2), {"shape": CYL, "sides": 8})
	B(g, "ExtinguisherTop", "cable", V(3.14, 4.86, -1.8), V(0.08, 0.12, 0.08), {"shape": CYL, "sides": 6})
	# Odds and ends on the floors: buckets, sheets of board against the columns.
	for at in [V(-8.4, 4, 6.4), V(4.6, 8, -13.6), V(-12.6, 12, -13.4), V(12.4, 4, 4.2), V(-6.4, 0, -13.2)]:
		B(g, "Bucket", "box_orange" if rng.randf() < 0.5 else "machine_dark", at + V(0, 0.17, 0), V(0.32, 0.34, 0.32), {"shape": CONE, "top": 0.36, "sides": 9})
		B(g, "Bucket", "box_blue", at + V(0.42, 0.17, 0.2), V(0.32, 0.34, 0.32), {"shape": CONE, "top": 0.36, "sides": 9})
	for at in [[V(-15.0, 4, -5.5), Y(90.0)], [V(5.5, 8, -15.1), Basis.IDENTITY], [V(-15.0, 12, -5.5), Y(90.0)]]:
		var sheets := GW(g, "BoardSheets", at[0], at[1])
		for i in 4:
			B(sheets, "Sheet", "board" if i % 2 == 0 else "ply", V(1.6, 0.62, 0.3 + i * 0.05), V(2.4, 1.2, 0.04), {"turn": Basis(Vector3.RIGHT, -0.16), "tint": shade(0.04)})


## Posters on the hoarding, between its posts.
func _fence_posters() -> void:
	var sign := scn.get_node("Signage")
	var north := Basis.IDENTITY               # on the north fence, facing south into the site
	var south := Y(180.0)
	var west := Y(90.0)
	var east := Y(-90.0)
	var white := Color(0.97, 0.97, 0.95)
	var black := Color(0.1, 0.1, 0.1)
	board_sign(sign, "ASSEMBLY\nPOINT", V(-2.0, 2.2, -39.99), north, Vector2(2.2, 1.5), "sign_green", 72, white)
	board_sign(sign, "CRANE WORKING OVERHEAD", V(30.0, 2.2, -39.99), north, Vector2(3.4, 0.8), "hazard", 40, black)
	board_sign(sign, "NO ENTRY WITHOUT INDUCTION", V(-26.0, 2.2, -39.99), north, Vector2(3.4, 0.8), "sign_red", 36, white)
	board_sign(sign, "CAUTION\nDEEP EXCAVATION", V(-39.99, 2.2, 26.0), west, Vector2(3.0, 1.3), "hazard", 52, black)
	board_sign(sign, "WASH YOUR BOOTS", V(-39.99, 2.2, -10.0), west, Vector2(3.0, 0.8), "sign_blue", 48, white)
	board_sign(sign, "ALL DELIVERIES\nREPORT TO SITE OFFICE", V(10.0, 2.2, 39.99), south, Vector2(3.4, 1.2), "sign_blue", 44, white)
	board_sign(sign, "SPEED LIMIT 5", V(-10.0, 2.2, 39.99), south, Vector2(2.6, 0.8), "board", 52)
	board_sign(sign, "CRANE LOADING ZONE\nKEEP CLEAR", V(22.0, 2.2, 39.99), south, Vector2(3.4, 1.2), "hazard", 44, black)
	board_sign(sign, "SILO 1  ·  SILO 2\nCEMENT", V(39.99, 2.2, -2.0), east, Vector2(3.0, 1.2), "board", 48)
	board_sign(sign, "THINK SAFE\nWORK SAFE\nGO HOME SAFE", V(39.99, 2.4, 22.0), east, Vector2(3.0, 1.9), "sign_green", 52, white)
	board_sign(sign, "PLANT CROSSING", V(39.99, 2.2, -22.0), east, Vector2(3.0, 0.8), "hazard", 48, black)
