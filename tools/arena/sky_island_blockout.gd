extends SceneTree
## Builds game/maps/sky_island.tscn: a whitebox of seven floating islands at mixed
## heights, three of them carrying castle ruins.
##
##   godot --headless --path . --script tools/arena/sky_island_blockout.gd
##
## It writes the scene FROM SCRATCH, so a run overwrites hand edits. Change the numbers
## below and run it again while the layout is still moving; once the scene is edited by
## hand, stop running it.
##
## The seven islands. The Hearth, in the middle, is the lowest; the six stand round it
## about a sixth of a turn apart, at mixed heights (going round from the east):
##   Shelf     3 m   open: cover blocks and a wall to run along
##   Bluff     8 m   open: cover and a wall to run along
##   Spire     4 m   open and small
##   Citadel   7 m   the Gate and its curtain wall (a wall walk, a gate arch, a drum)
##   Garden    2 m   open: a ring of standing stones and low walls
##   Terrace   6 m   the Broken Tower (an eight-sided shell with a floor inside)
##   Hearth   -3 m   the biggest, with the ruined Keep (broken walls, a piece of its
##                   upper floor, two corner drums)
## No island is round: each is a handful of overlapping many-sided slabs ("lobes") of
## different sizes, so its edge runs in and out, with a cone of rock hung under each.
##
## There is NO path you can walk from one island to another, and no grapple points:
##  - stepping pads (a few big rocks 4.5 to 9 m across, each a step higher or lower than
##    the last, well scattered either side of the straight line) join the six outer
##    islands into a ring: each to the next (see STONES below);
##  - nothing joins the Hearth to the outer islands: about 24 m of open sky each, the
##    Hearth 4 to 11 m below on average (each comes within 7 m of it at some moment). Rocket boots, or a long jump down, get you across.
##
## Everything floats up and down. Each island is a MapMover with its own rise and its
## own moment in the cycle (see BOB), all on one period, and whatever stands on it
## rides along: ruins, cover, spawn points. Each pad is a MapMover too, timed to the
## two islands it lies between, so the rows of pads flex with them. The heights above
## are the middle of each island's bob. In the editor (and in this file) a mover sits at
## the bottom of its bob, so the scene looks a little uneven until the game runs it.
## Every gap is open sky, and falling is death.

const OUT := "res://game/maps/sky_island.tscn"
const PALETTE := "res://game/maps/palettes/sky_island.tres"

const DECK := 1.4          ## how thick an island's deck is

const THICK := 0.8         ## the ruins' walls
const CLEAR := 0.8         ## the least open sky between a pad and an island, or the next pad

## name: [centre (y = the deck's top), lobes]. A lobe: [x, z (from the centre), diameter,
## sides, turn in degrees]. The first lobe is the island's main body.
const ISLANDS := {
	"Shelf": [Vector3(-4, 3, 66), [[0, 0, 30, 8, 20], [11, -6, 20, 7, 0], [-10, 8, 20, 6, 30], [4, 12, 16, 7, 10]]],
	"Bluff": [Vector3(-57, 8, 32), [[0, 0, 30, 8, 15], [9, -8, 20, 7, 0], [-9, 7, 20, 6, 20], [5, 11, 16, 7, 35]]],
	"Spire": [Vector3(-63, 4, -31), [[0, 0, 22, 7, 10], [8, 6, 16, 6, 0], [-7, -6, 14, 7, 30]]],
	"Citadel": [Vector3(-4, 7, -62), [[0, 0, 36, 9, 0], [14, 4, 26, 7, 30], [-14, 3, 26, 8, 10], [0, -13, 22, 6, 20]]],
	"Garden": [Vector3(57, 2, -38), [[0, 0, 28, 7, 15], [-10, 7, 20, 8, 0], [8, -10, 18, 6, 25], [9, 9, 16, 7, 5]]],
	"Terrace": [Vector3(71, 6, 33), [[0, 0, 32, 8, 5], [-11, -9, 22, 7, 30], [10, 10, 22, 6, 0], [11, -9, 18, 7, 20]]],
	"Hearth": [Vector3(0, -3, 0), [[0, 0, 42, 9, 10], [15, 9, 28, 7, 40], [-16, -6, 26, 8, 0], [-5, 17, 24, 7, 25], [9, -16, 24, 6, 15]]],
}

## Crossings by stepping pads: every gap round the ring of outer islands.
const STONES := [["Terrace", "Shelf"], ["Shelf", "Bluff"], ["Bluff", "Spire"], ["Spire", "Citadel"],
	["Citadel", "Garden"], ["Garden", "Terrace"]]

## Seconds for one bob, down to up and back: the same for every island, which is what
## lets a pad follow two islands at once exactly (see pad_bob()).
const PERIOD := 14.0
## name: [rise in metres from the bottom of its bob to the top, phase (0..1: where in
## the cycle it starts)]. Round the ring each island is a sixth of a cycle after the
## last, so the bob travels round it like a slow wave.
const BOB := {
	"Terrace": [5.5, 0.0], "Shelf": [6.5, 0.1667], "Bluff": [8.0, 0.3333], "Spire": [4.8, 0.5],
	"Citadel": [7.0, 0.6667], "Garden": [7.2, 0.8333], "Hearth": [4.0, 0.8333],   # with the Garden, the lowest outer island, so it never rises past it
}

var scn: Node3D
var block_script: Script
var spawn_script: Script
var mover_script: Script
var rng := RandomNumberGenerator.new()


func _init() -> void:
	block_script = load("res://game/arena/map_block.gd")
	spawn_script = load("res://game/arena/map_spawn.gd")
	mover_script = load("res://game/arena/map_mover.gd")
	scn = (load("res://game/arena/map_root.gd") as Script).new()
	rng.seed = 7007
	scn.name = "SkyIsland"
	scn.set("palette", load(PALETTE))
	scn.set("grid_texture", true)      # a 1 m / 4 m grid on every surface, to judge distance
	scn.set("face_shade", Vector3(0.9, 0.8, 0.65))
	scn.set("kill_height", -36.0)      # the deepest rock (the Hearth's, at the bottom of its bob) ends at about -26
	scn.set("bounds", Rect2(-150, -150, 300, 300))
	scn.set("swing_point", centre("Hearth") + Vector3(11, 10.5, -8))   # over the Keep's tall drum
	sky()
	var islands := group(scn, "Islands")
	var links := group(scn, "Crossings")
	for name in ISLANDS:
		island(islands, name)
	shelf(islands.get_node("Shelf"))
	bluff(islands.get_node("Bluff"))
	hearth(islands.get_node("Hearth"))
	terrace(islands.get_node("Terrace"))
	garden(islands.get_node("Garden"))
	citadel(islands.get_node("Citadel"))
	spire(islands.get_node("Spire"))
	for pair in STONES:
		stepping_stones(links, pair[0], pair[1])
	hearth_gaps()
	var ps := PackedScene.new()
	var err := ps.pack(scn)
	if err == OK:
		err = ResourceSaver.save(ps, OUT)
	print("BLOCKOUT: saved %s (%s): %d blocks, %d spawns, %d movers" % [OUT, error_string(err),
		scn.find_children("*", "MapBlock", true, false).size(), scn.find_children("*", "MapSpawn", true, false).size(),
		scn.find_children("*", "MapMover", true, false).size()])
	scn.free()
	quit(0 if err == OK else 1)


# -- helpers -------------------------------------------------------------------------
func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


func centre(name: String) -> Vector3:
	return ISLANDS[name][0]


## Is the point `p` (x and z from the island's centre) on the island's deck?
func on_island(name: String, p: Vector2) -> bool:
	for l in ISLANDS[name][1]:
		var sides: int = l[3]
		var local := (p - Vector2(l[0], l[1])).rotated(deg_to_rad(l[4]))   # undo the lobe's turn
		var half := PI / sides
		var a := fposmod(local.angle(), 2.0 * half) - half
		if local.length() * cos(a) <= l[2] * 0.5 * cos(half):
			return true
	return false


## How far the island's deck runs from its centre in the flat direction `dir`, along a
## line `aside` metres to one side of the centre.
func reach(name: String, dir: Vector3, aside := 0.0) -> float:
	var across := Vector2(-dir.z, dir.x) * aside
	var far := 0.0
	var t := 0.0
	while t < 60.0:
		if on_island(name, Vector2(dir.x, dir.z) * t + across):
			far = t
		t += 0.02
	return far


func group(parent: Node, name: String, at := Transform3D.IDENTITY) -> Node3D:
	var g := Node3D.new()
	g.name = name
	parent.add_child(g, true)
	g.owner = scn
	g.transform = at
	return g


## A group that bobs: a MapMover whose blocks ride `rise` metres up and back every
## PERIOD seconds, starting `phase` of the way through the cycle. `at` is where it is
## half way up; the node itself sits at the bottom of the bob.
func mover(parent: Node, name: String, at: Vector3, rise: float, phase: float) -> Node3D:
	var m: Node3D = mover_script.new()
	m.name = name
	m.set("travel", Vector3(0, rise, 0))
	m.set("period", PERIOD)
	m.set("phase", phase)
	parent.add_child(m, true)
	m.owner = scn
	m.position = at - Vector3(0, rise * 0.5, 0)
	return m


## A block in its parent's own frame: `at` is its centre.
func put(parent: Node, name: String, kind: String, size: Vector3, at: Vector3, rot := Basis.IDENTITY, shape := MapBlock.Shape.BOX) -> MapBlock:
	var b: MapBlock = block_script.new()
	b.name = name
	b.shape = shape
	b.size = size
	b.kind = kind
	parent.add_child(b, true)
	b.owner = scn
	b.transform = Transform3D(rot, at)
	return b


## An upright box from `lo` to `hi`, in its parent's frame.
func box(parent: Node, name: String, kind: String, lo: Vector3, hi: Vector3) -> MapBlock:
	return put(parent, name, kind, (hi - lo).abs(), (lo + hi) * 0.5)


## An upright cylinder standing on `base`.
func cyl(parent: Node, name: String, kind: String, base: Vector3, diameter: float, height: float, sides := 16, turn := 0.0) -> MapBlock:
	var b := put(parent, name, kind, Vector3(diameter, height, diameter), base + Vector3(0, height * 0.5, 0), Basis(Vector3.UP, turn), MapBlock.Shape.CYLINDER)
	b.sides = sides
	return b


## A slab whose top runs from `a` to `b` (the middle of each end), `width` across.
func ramp(parent: Node, name: String, kind: String, a: Vector3, b: Vector3, width: float, thick := 0.4) -> MapBlock:
	var along := (b - a).normalized()
	var across := Vector3.UP.cross(along).normalized()
	var up := along.cross(across)
	return put(parent, name, kind, Vector3(width, thick, (b - a).length()), (a + b) * 0.5 - up * thick * 0.5, Basis(across, up, along))


## A spawn point on an island: `at` and `toward` (the way it faces) are in the island's
## frame. It goes inside the island, so it rides the island's bob.
func spawn(island: Node, name: String, at: Vector3, toward: Vector3) -> void:
	var holder := island.get_node_or_null("Spawns")
	if holder == null:
		holder = group(island, "Spawns")
	var m: Marker3D = spawn_script.new()
	m.name = name
	holder.add_child(m, true)
	m.owner = scn
	var away := at - toward
	m.transform = Transform3D(Basis(Vector3.UP, atan2(away.x, away.z)), at)


func sky() -> void:
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.2, 0.42, 0.74)
	mat.sky_horizon_color = Color(0.74, 0.82, 0.9)
	mat.ground_bottom_color = Color(0.52, 0.62, 0.74)   # open sky below too
	mat.ground_horizon_color = Color(0.74, 0.82, 0.9)
	var s := Sky.new()
	s.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = s
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	scn.add_child(we)
	we.owner = scn
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	scn.add_child(sun)
	sun.owner = scn
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-52), deg_to_rad(35), 0)), Vector3.ZERO)


# -- islands ---------------------------------------------------------------------------
## An island: a group standing at its centre (so y = 0 inside it is the deck's top),
## holding a deck slab and a cone of rock for each of its lobes.
func island(parent: Node, name: String) -> void:
	var g := mover(parent, name, centre(name), BOB[name][0], BOB[name][1])
	var ground := group(g, "Ground")
	for l in ISLANDS[name][1]:
		var d: float = l[2]
		var turn := deg_to_rad(l[4])
		cyl(ground, "Deck", "island_top", V(l[0], -DECK, l[1]), d, DECK, l[3], turn)
		# The rock: a cone hung point down (turned over about x), a little narrower than its deck.
		var depth := d * 0.45
		var rock := put(ground, "Rock", "island_rock", Vector3(d * 0.94, depth, d * 0.94), V(l[0], -DECK - depth * 0.5, l[1]),
			Basis(Vector3.UP, turn) * Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)), MapBlock.Shape.CONE)
		rock.sides = l[3]
		rock.top = d * 0.12


func shelf(g: Node3D) -> void:
	var cover := group(g, "Cover")
	box(cover, "Block", "cover", V(-6, 0, -3), V(-4, 1.2, 1))
	box(cover, "Block", "cover", V(4, 0, 4), V(7, 1.2, 5.2))
	box(cover, "Block", "cover", V(-1, 0, -10), V(1, 2.2, -8))
	box(cover, "Block", "cover", V(-11, 0, 9), V(-9.5, 2.2, 10.5))
	box(cover, "Block", "cover", V(11, 0, -8), V(13.5, 1.2, -6.8))
	box(g, "WallRun", "wallrun", V(-3, 0, 9.6), V(7, 4.5, 10.4))
	for at in [V(-10, 0, -3), V(3, 0, -5), V(4, 0, 14), V(13, 0, -3)]:
		spawn(g, "Shelf", at, Vector3.ZERO)


func garden(g: Node3D) -> void:
	var ring := group(g, "StandingStones")
	var heights := [4.2, 3.0, 4.2, 1.4, 4.2, 2.2, 3.6]
	for i in heights.size():
		var a := TAU * i / heights.size() + 0.3
		cyl(ring, "Stone", "pillar", V(cos(a) * 7.0, 0, sin(a) * 7.0), 1.4, heights[i], 10)
	var cover := group(g, "Cover")
	box(cover, "LowWall", "cover", V(-2.5, 0, -0.4), V(2.5, 1.2, 0.4))
	box(cover, "LowWall", "cover", V(-0.4, 0, 2.2), V(0.4, 1.2, 5))
	box(cover, "Block", "cover", V(-12, 0, 6), V(-10, 1.2, 8.5))
	for at in [V(-2, 0, -10.5), V(10, 0, 4), V(-11, 0, 3)]:
		spawn(g, "Garden", at, Vector3.ZERO)


func spire(g: Node3D) -> void:
	cyl(g, "Pillar", "pillar", V(-2, 0, -2), 1.8, 5.0, 12)
	box(g, "Cover", "cover", V(2, 0, 3), V(5, 1.2, 4))
	box(g, "Cover", "cover", V(7, 0, 5), V(8.2, 1.2, 7.5))
	spawn(g, "Spire", V(-4, 0, 4.5), Vector3.ZERO)
	spawn(g, "Spire", V(8, 0, 2), Vector3.ZERO)


func bluff(g: Node3D) -> void:
	var cover := group(g, "Cover")
	box(cover, "Block", "cover", V(-5, 0, -4), V(-3, 1.2, -1))
	box(cover, "Block", "cover", V(5, 0, 2), V(8, 1.2, 3.2))
	box(cover, "Block", "cover", V(-10, 0, 8), V(-8.5, 2.2, 9.5))
	box(cover, "Block", "cover", V(9, 0, -10), V(11, 2.2, -8.5))
	box(cover, "LowWall", "cover", V(-1.5, 0, 6), V(3.5, 1.2, 6.8))
	box(g, "WallRun", "wallrun", V(-0.4, 0, -11), V(0.4, 4.5, -3))
	for at in [V(-9, 0, -3), V(6, 0, -5), V(3, 0, 11), V(-10, 0, 4)]:
		spawn(g, "Bluff", at, Vector3.ZERO)


# -- castle ruins ----------------------------------------------------------------------
## A broken wall from `a` to `b` (x and z in the parent's frame), cut into as many
## equal lengths as `heights` has numbers; each stands that high (0 = a breach).
func broken_wall(parent: Node, a: Vector2, b: Vector2, heights: Array, thick := THICK) -> void:
	var n := heights.size()
	var dir := (b - a).normalized()
	var rot := Basis(Vector3.UP, atan2(-dir.y, dir.x))   # the block's x along the wall
	var piece := (b - a).length() / n
	for i in n:
		var h: float = heights[i]
		if h <= 0.0:
			continue
		var mid := a.lerp(b, (i + 0.5) / n)
		put(parent, "Wall", "building", Vector3(piece, h, thick), V(mid.x, h * 0.5, mid.y), rot)


## Fallen stones: [x, z, length, height, depth, turn in degrees] each.
func rubble(parent: Node, stones: Array) -> void:
	var g := group(parent, "Rubble")
	for s in stones:
		put(g, "Stone", "stone", Vector3(s[2], s[3], s[4]), V(s[0], s[3] * 0.5, s[1]), Basis(Vector3.UP, deg_to_rad(s[5])))


## The Hearth: the ruined Keep, 22 by 16 m. Its walls stand between nothing and 7.2 m;
## the gate in the south wall still has its lintel; a corner of the upper floor is left
## (3 m up, on two piers, a fallen slab for a ramp); a tall drum stands at the north-east
## corner and the stump of another at the south-west.
func hearth(g: Node3D) -> void:
	var k := group(g, "Keep")
	var walls := group(k, "Walls")
	broken_wall(walls, Vector2(-11, 8), Vector2(11, 8), [6.0, 4.8, 3.6, 3.6, 0, 0, 3.6, 4.8, 6.0, 7.2, 4.8])
	box(walls, "GateLintel", "building", V(-3, 2.9, 8 - THICK * 0.5), V(1, 3.6, 8 + THICK * 0.5))
	broken_wall(walls, Vector2(-11, -8), Vector2(11, -8), [7.2, 7.2, 6.0, 4.8, 2.4, 1.2, 0, 1.2, 3.6, 6.0, 6.0])
	broken_wall(walls, Vector2(-11, -8), Vector2(-11, 8), [7.2, 6.0, 4.8, 0, 0, 2.4, 4.8, 6.0])
	broken_wall(walls, Vector2(11, -8), Vector2(11, 8), [6.0, 3.6, 1.2, 1.2, 2.4, 0, 3.6, 4.8])
	cyl(k, "TallDrum", "building", V(11, 0, -8), 6.0, 9.0, 12)
	cyl(k, "DrumStump", "building", V(-11, 0, 8), 6.0, 2.4, 12)
	var upper := group(k, "UpperFloor")
	box(upper, "Slab", "floor", V(-10.6, 2.7, -7.6), V(-1, 3.0, -1.5))
	for x in [-2.0, -6.5]:
		cyl(upper, "Pier", "pillar", V(x, 0, -2.2), 0.9, 2.7, 10)
	ramp(upper, "FallenSlab", "ramp", V(5.5, 0, -4.5), V(-1, 3.0, -4.5), 2.6, 0.35)
	rubble(k, [[3, 2, 2.2, 1.0, 1.4, 20], [-5, 4, 1.6, 1.2, 1.6, 50], [6.5, -1, 2.6, 0.8, 1.2, -15],
		[-1, 11.5, 2.0, 1.2, 1.2, 35], [14.5, 3, 2.4, 1.2, 1.4, 70], [-14.5, -1, 1.8, 1.0, 1.8, 10], [1, -11, 2.8, 1.2, 1.2, -25]])
	for at in [V(0, 0, -14), V(16, 0, 6), V(-16, 0, -6), V(4, 0, 15), V(-8, 0, 16), V(3, 0, 0)]:
		spawn(g, "Hearth", at, Vector3.ZERO)
	spawn(g, "KeepUpper", V(-6, 3.0, -5), V(0, 3.0, 4))


## The Terrace: the Broken Tower. Eight wall panels in a ring (14 m across), from
## nothing (the way in, on the south-west) up to 10.8 m; inside, half a floor 3 m up
## and a fallen slab up to it. A stub of curtain wall runs off east, and two fallen
## columns lie outside.
func terrace(g: Node3D) -> void:
	var t := group(g, "BrokenTower")
	var shell := group(t, "Shell")
	var apothem := 7.0
	var panel := 2.0 * apothem * tan(PI / 8.0) + THICK * 0.8   # a little long, so the corners close
	var heights := [10.8, 9.6, 7.2, 0.0, 3.6, 6.0, 8.4, 10.8]
	for i in 8:
		var h: float = heights[i]
		if h <= 0.0:
			continue
		var a := TAU * i / 8.0
		# The panel's x runs along the ring (the tangent).
		put(shell, "Wall", "building", Vector3(panel, h, THICK), V(cos(a) * apothem, h * 0.5, sin(a) * apothem), Basis(Vector3.UP, atan2(-cos(a), -sin(a))))
	var inside := group(t, "Inside")
	box(inside, "Slab", "floor", V(-4.4, 2.7, -4.4), V(4.4, 3.0, 0))
	ramp(inside, "FallenSlab", "ramp", V(2.5, 0, 5.4), V(2.5, 3.0, 0), 2.4, 0.35)
	broken_wall(t, Vector2(7.6, -0.5), Vector2(15.6, -3.5), [6.0, 4.8, 2.4, 1.2])
	var columns := group(t, "FallenColumns")
	put(columns, "Column", "pillar", Vector3(1.2, 5.0, 1.2), V(-11, 0.6, 7), Basis(Vector3.UP, 0.5) * Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), MapBlock.Shape.CYLINDER)
	put(columns, "Column", "pillar", Vector3(1.2, 3.0, 1.2), V(-9, 0.6, 11.5), Basis(Vector3.UP, -0.4) * Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), MapBlock.Shape.CYLINDER)
	rubble(t, [[-8.5, 8.5, 2.0, 1.2, 1.4, 40], [10, 8, 2.4, 1.0, 1.4, -20], [-5, -12.5, 2.2, 1.2, 1.2, 15], [9, -10, 1.6, 1.2, 1.6, 60]])
	for at in [V(12, 0, 4), V(0, 0, 12.5), V(-13, 0, -3), V(6, 0, -11)]:
		spawn(g, "Terrace", at, Vector3.ZERO)
	spawn(g, "TowerFloor", V(0, 3.0, -2.5), V(0, 3.0, 5))


## The Citadel: the Gate and its curtain wall, 2 m thick and 5 m high with a wall walk
## on top. West to east: a long run with a stair up its inner face, a breach, the gate
## (a 4 m arch, the walk carried over it), a second run with a low breach in it, and a
## drum at the east end. A row of column stumps stands in front.
func citadel(g: Node3D) -> void:
	var w := group(g, "CurtainWall")
	var z0 := -4.0   # the outer face
	var z1 := -2.0   # the inner face
	var top := 5.0
	box(w, "Wall", "building", V(-17, 0, z0), V(-6, top, z1))
	box(w, "Wall", "building", V(-3.5, 0, z0), V(-2, top, z1))
	box(w, "GateLintel", "building", V(-2, 3.6, z0), V(2, top, z1))
	box(w, "Wall", "building", V(2, 0, z0), V(7, top, z1))
	box(w, "Wall", "building", V(7, 0, z0), V(9, 2.4, z1))
	box(w, "Wall", "building", V(9, 0, z0), V(12, top, z1))
	var merlons := group(w, "Merlons")
	for x in [-16.3, -14.3, -12.3, -10.3, -8.3, -2.9, -0.7, 1.3, 3.3, 5.3, 9.7, 11.3]:
		box(merlons, "Merlon", "building", V(x - 0.5, top, z0), V(x + 0.5, top + 0.9, z0 + 0.5))
	ramp(w, "Stair", "ramp", V(-6.5, 0, z1 + 1.0), V(-16, top, z1 + 1.0), 2.0, 0.4)
	box(w, "StairLanding", "floor", V(-18.5, top - 0.4, z1), V(-16, top, z1 + 2.03))   # level with the wall walk, to step across from
	cyl(w, "Drum", "building", V(14, 0, -3), 6.0, 7.2, 12)
	var columns := group(g, "Colonnade")
	var heights := [4.0, 1.2, 3.0, 4.0, 0.8]
	for i in heights.size():
		cyl(columns, "Column", "pillar", V(-9 + i * 4.5, 0, 6), 1.0, heights[i], 10)
	rubble(g, [[-4.8, -3, 1.8, 1.2, 1.6, 20], [-5.2, 0.5, 1.4, 0.8, 1.2, 60], [8, -0.5, 2.0, 1.0, 1.2, -30],
		[-12, 10, 2.2, 1.2, 1.4, 15], [13, 8, 1.8, 1.2, 1.8, 45], [0, -12, 2.4, 1.2, 1.2, -10]])
	for at in [V(0, 0, 11), V(-13, 0, 6), V(13, 0, 4), V(-4, 0, -12)]:
		spawn(g, "Citadel", at, Vector3.ZERO)
	spawn(g, "WallWalk", V(-11, top, -3), V(-11, top, 6))


# -- crossings between islands ---------------------------------------------------------
## Stepping pads across the gap between two islands: few and big. As few as keep every
## step about 2 m or less in height (a ledge climb reaches 2.3 m) and every jump about
## 4.5 m or less across, each 5 to 8 m across to fill the gap, and then
## scattered: the row swings to one side and back in an S of its own, and each pad is
## thrown off it sideways (up to 2 m), along (up to 1 m) and up or down (up to 0.15 m),
## with its own size (4.5 to 9 m), number of sides (5 to 9) and turn. About one pad in
## four has a smaller one beside it, as another way round. The numbers come from a
## seeded generator, so every run lays the same pads. The longest hop between two pads
## in a row stays well inside a sprinting jump (7.5 m).
##
## Every pad is a MapMover of its own, timed to its two islands: a pad `part` of the
## way across rides at that share of the far island's bob and the rest of the near
## one's, so the row stays a staircase from one deck to the other as they rise and fall
## (see pad_bob()).
func stepping_stones(parent: Node, from: String, to: String) -> void:
	var a := centre(from)
	var b := centre(to)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var dist := flat.length()
	flat = flat.normalized()
	var across := Vector3.UP.cross(flat)
	var out := reach(from, flat)
	var gap := dist - out - reach(to, -flat)
	# The two islands bob out of step, so the climb between them swings either side of its
	# average by `swing` (half the gap between their two arrows: see pad_bob()). The pads
	# are counted for the climb at its greatest.
	var swing: float = (Vector2.from_angle(TAU * BOB[from][1]) * BOB[from][0] - Vector2.from_angle(TAU * BOB[to][1]) * BOB[to][0]).length() * 0.5
	var count := maxi(1, ceili((absf(b.y - a.y) + swing) / 2.0) - 1)
	while (gap - count * 6.5) / (count + 1) > 4.5:
		count += 1
	var size := clampf((gap - (count + 1) * 2.5) / count, 5.0, 8.0)
	var space := (gap - size * count) / (count + 1)
	var bow := rng.randf_range(2.0, 4.5) * (1.0 if rng.randf() < 0.5 else -1.0)
	var wave := rng.randf_range(-3.0, 3.0)
	var g := group(parent, from + "To" + to)
	var extras := 0
	var hop := 0.0          # the longest gap between one pad's edge and the next's
	var last := Vector3.ZERO
	var last_d := 0.0
	var row := [[a.y, BOB[from][0], BOB[from][1]]]   # [mean height, rise, phase] of each stop along the row
	var slid := 0           # pads moved along the row to clear an island
	for i in count:
		var part := (i + 1.0) / (count + 1)
		var along := out + space * (i + 1) + size * (i + 0.5) + rng.randf_range(-1.0, 1.0)
		var aside := sin(PI * part) * bow + sin(TAU * part) * wave + rng.randf_range(-2.0, 2.0)
		var lift := rng.randf_range(-0.15, 0.15)
		var d := clampf(size * rng.randf_range(0.8, 1.2), 4.5, 9.0)
		var spot := Vector3(a.x, 0, a.z) + flat * along + across * aside
		# No pad may stand in an island. The gap was measured down the middle of the row,
		# but an island's rim runs in and out and the pad is thrown to one side, so it can
		# land on a deck: slide it along the row, toward the middle of the gap, until it
		# is clear (with CLEAR to spare).
		var inward := 1.0 if along < out + gap * 0.5 else -1.0
		var tries := 0
		while touches_island(spot, d * 0.5) and tries < 60:
			along += 0.25 * inward
			spot = Vector3(a.x, 0, a.z) + flat * along + across * aside
			tries += 1
		if tries > 0:
			slid += 1
		# Nor in the pad before it: it gives way by being smaller.
		if i > 0:
			var room := Vector2(spot.x - last.x, spot.z - last.z).length() - last_d * 0.5 - CLEAR
			d = clampf(minf(d, room * 2.0), 3.0, 9.0)
		# (Its height and its bob still go by its number in the row, so the steps stay even.)
		var top := lerpf(a.y, b.y, part) + lift
		var at := Vector3(spot.x, top, spot.z)
		var bob := pad_bob(from, to, part)
		pad(g, at, d, bob)
		row.append([top, bob[0], bob[1]])
		if i > 0:
			hop = maxf(hop, Vector2(at.x - last.x, at.z - last.z).length() - (d + last_d) * 0.5)
		last = at
		last_d = d
		if rng.randf() < 0.25:
			# A smaller pad off to one side, a little higher or lower, moving with its
			# neighbour: on whichever side is clear of the islands, or not at all.
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var reach_out := d * 0.5 + rng.randf_range(2.8, 4.0)
			var shift := rng.randf_range(-1.5, 1.5)
			var small := rng.randf_range(3.0, 4.2)
			var drop := rng.randf_range(-0.6, 0.6)
			for s in [side, -side]:
				var beside: Vector3 = at + across * reach_out * s + flat * shift + V(0, drop, 0)
				if not touches_island(beside, small * 0.5):
					pad(g, beside, small, bob)
					extras += 1
					break
	row.append([b.y, BOB[to][0], BOB[to][1]])
	# The tallest step in the row at any moment of the cycle.
	var step := 0.0
	for k in 96:
		var t := PERIOD * k / 96.0
		for i in row.size() - 1:
			step = maxf(step, absf(height_at(row[i], t) - height_at(row[i + 1], t)))
	print("  %s to %s: %.1f m of open sky, %+.1f m, %d pads (%d slid clear of an island, %d beside them); longest hop %.1f m; tallest step at any moment %.2f m" % [from, to, gap,
		b.y - a.y, count, slid, extras, hop, step])


## Would a pad `radius` across its middle at `spot` (x and z in the map) stand in an
## island, or within CLEAR of one? Its middle and two rings of points round it are
## tried against every island's deck.
func touches_island(spot: Vector3, radius: float) -> bool:
	for name in ISLANDS:
		var c := centre(name)
		var p := Vector2(spot.x - c.x, spot.z - c.z)
		if p.length() > 45.0 + radius:
			continue
		if on_island(name, p):
			return true
		for k in 32:
			var dir := Vector2.from_angle(TAU * k / 32.0)
			if on_island(name, p + dir * (radius + CLEAR)) or on_island(name, p + dir * radius * 0.5):
				return true
	return false


## How a pad `part` of the way from one island to another must bob to stay on the line
## between them: [rise, phase] for its MapMover. A MapMover with no hold moves as one
## cosine: rise * (0.5 - 0.5 * cos(turn)), where turn = TAU * (time / PERIOD + phase).
## The pad needs (1 - part) of one island's cosine plus `part` of the other's; two
## cosines of the same period add up to one cosine, whose size and timing come from
## adding them as arrows (size = rise, direction = phase).
func pad_bob(from: String, to: String, part: float) -> Array:
	var arrow: Vector2 = Vector2.from_angle(TAU * BOB[from][1]) * BOB[from][0] * (1.0 - part) + Vector2.from_angle(TAU * BOB[to][1]) * BOB[to][0] * part
	return [arrow.length(), fposmod(arrow.angle() / TAU, 1.0)]


## Where something that bobs is at time `t`: `stop` = [mean height, rise, phase].
func height_at(stop: Array, t: float) -> float:
	return stop[0] - 0.5 * stop[1] * cos(TAU * (t / PERIOD + stop[2]))


## One pad: a mover holding a slab (its top at `at` when half way up its bob) and a
## small cone of rock under it. `bob` = [rise, phase].
func pad(parent: Node, at: Vector3, d: float, bob: Array) -> void:
	var sides := rng.randi_range(5, 9)
	var turn := rng.randf_range(0.0, TAU)
	var m := mover(parent, "Pad", at, bob[0], bob[1])
	cyl(m, "Slab", "stone", V(0, -1.0, 0), d, 1.0, sides, turn)
	var rock := put(m, "Rock", "island_rock", Vector3(d * 0.9, d * 0.55, d * 0.9), V(0, -1.0 - d * 0.275, 0),
		Basis(Vector3.UP, turn) * Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)), MapBlock.Shape.CONE)
	rock.sides = sides
	rock.top = d * 0.2


## Prints the open sky between the Hearth and each outer island (nothing crosses it).
func hearth_gaps() -> void:
	var a := centre("Hearth")
	for name in ISLANDS:
		if name == "Hearth":
			continue
		var b := centre(name)
		var flat := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var least := INF
		var most := -INF
		for k in 96:
			var t := PERIOD * k / 96.0
			var up := height_at([b.y, BOB[name][0], BOB[name][1]], t) - height_at([a.y, BOB["Hearth"][0], BOB["Hearth"][1]], t)
			least = minf(least, up)
			most = maxf(most, up)
		print("  Hearth to %s: %.1f m of open sky, %+.1f m on average (from %.1f to %.1f m), nothing across" % [name,
			Vector2(b.x - a.x, b.z - a.z).length() - reach("Hearth", flat) - reach(name, -flat), b.y - a.y, least, most])
