extends SceneTree
## Builds game/maps/sky_island.tscn: seven floating islands at mixed heights, three of
## them carrying the ruins of a stone castle, over a sea of cloud. Each island is grass
## on top, a band of earth, and rock hanging underneath, with green round its rim
## (bushes, a few trees, moss hanging over the edge). game/maps/sky_island_layout.tscn
## keeps the grey block-out this started from.
##
## Grouped the way the castle maps are: by object, each holding its own dressing (a
## wall piece's coping and ivy are in its Wall group, a tree's trunk and leaves in its
## Tree group), and the small things you would move as one are selection groups, so a
## click in the viewport picks the whole thing (a pad, a bush, a tree, a lobe of an
## island with its rocks).
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
const SKY := "res://game/maps/sky/sky_island_sky.gdshader"

const DECK := 1.4          ## how thick an island's deck is
const TURF := 0.3          ## the grass on top of it (the rest is earth)

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

## Bots' crossings (MapJumpLink). Across the pads: a hop each way between each pad and
## the next (a running jump, or a ledge climb for a step up), at any moment, since the
## pads keep every step to about 2 m. To and from the Hearth: the rocket boots, timed
## to the bob. Going down, at any moment. Going up, only while the landing will be at
## most HEARTH_CLIMB metres above the takeoff when the bot comes down. A sprint, a jump
## and the boots, then a glide, top out at about 7.5 m over 24 m of open sky. An outer
## island that never comes that low gets no way up from the Hearth: bots go round by
## the pads instead.
const HEARTH_CLIMB := 6.0
const RUN_UP := 2.5        ## a hop's takeoff stands this far back from the edge
const BOOST_RUN := 6.0     ## a boost's takeoff stands this far back
const BOOST_FLIGHT := 1.6  ## about how long a boost crossing takes (seconds)

## Weapon pickups for Deathmatch: island -> [[weapon, x, y, z], ...] in the island's
## frame (y = 0 is its deck). The big guns sit up high: the rocket launcher on the
## Keep's upper floor, the sniper rifle on the Citadel's wall walk, the railgun on the
## Broken Tower's floor.
const PICKUPS := {
	"Hearth": [["rocket_launcher", -8.0, 3.0, -4.0], ["shotgun", -1.5, 0.0, 0.5], ["smg", 15.0, 0.0, 12.0], ["dagger", -14.0, 0.0, -12.0]],
	"Shelf": [["rifle", 0.0, 0.0, 3.0], ["sword", -12.0, 0.0, 3.0]],
	"Bluff": [["burst_rifle", 1.0, 0.0, 0.0], ["grenade_launcher", -4.0, 0.0, 10.0]],
	"Spire": [["akimbo", 3.0, 0.0, -3.0]],
	"Citadel": [["sniper", -15.3, 5.0, -2.9], ["machine_pistol", 0.0, 0.0, 3.0]],
	"Garden": [["spear", 0.0, 0.0, -3.5], ["lever_action", 4.0, 0.0, 12.0]],
	"Terrace": [["railgun", 1.0, 3.0, -2.5], ["axe", -6.0, 0.0, 12.0]],
}

var scn: Node3D
var block_script: Script
var spawn_script: Script
var mover_script: Script
var link_script: Script
var weapon_script: Script
var rng := RandomNumberGenerator.new()
## island -> its moving group; island -> [[x, z, radius], ...]: what stands on its deck
## (filled in once the islands are built), for keeping crossings and pickups clear.
var island_nodes := {}
var obstacles := {}
var links := 0
## The dressing's own random numbers, apart from `rng` (which lays the pads), so adding
## or changing dressing never moves a pad.
var deco := RandomNumberGenerator.new()
## mover -> where its middle is half way up its bob (in the map).
var mid_of := {}
## [x, z (in the map), radius]: spots the foliage keeps off (spawn points, pickups,
## where bots set off and land, and their run-ups).
var keep_clear := []
## [a group directly inside an island (or the island), Rect2 (x, z)]: paved floors, which grow no grass.
var paved := []
var drips := 0   # (see drip())


func _init() -> void:
	block_script = load("res://game/arena/map_block.gd")
	spawn_script = load("res://game/arena/map_spawn.gd")
	mover_script = load("res://game/arena/map_mover.gd")
	link_script = load("res://game/arena/map_jump_link.gd")
	weapon_script = load("res://game/arena/map_weapon_spawn.gd")
	scn = (load("res://game/arena/map_root.gd") as Script).new()
	rng.seed = 7007
	deco.seed = 4242
	scn.name = "SkyIsland"
	scn.set_meta("breakable_migrated", true)   # (tools/arena/migrate_breakable.gd has nothing to do here: nothing breaks)
	scn.set("palette", load(PALETTE))
	scn.set("grid_texture", false)
	scn.set("face_shade", Vector3(0.9, 0.8, 0.65))
	scn.set("kill_height", -36.0)      # the deepest rock (the Hearth's, at the bottom of its bob) ends at about -26
	scn.set("bounds", Rect2(-150, -150, 300, 300))
	scn.set("swing_point", centre("Hearth") + Vector3(11, 10.5, -8))   # over the Keep's tall drum
	sky()
	var islands := group(scn, "Islands")
	var crossings := group(scn, "Crossings")
	for name in ISLANDS:
		island(islands, name)
	shelf(islands.get_node("Shelf"))
	bluff(islands.get_node("Bluff"))
	hearth(islands.get_node("Hearth"))
	terrace(islands.get_node("Terrace"))
	garden(islands.get_node("Garden"))
	citadel(islands.get_node("Citadel"))
	spire(islands.get_node("Spire"))
	for name in ISLANDS:
		island_nodes[name] = islands.get_node(name)
		obstacles[name] = what_stands_on(island_nodes[name])
	for name in PICKUPS:
		for p in PICKUPS[name]:
			pickup(island_nodes[name], p[0], V(p[1], p[2], p[3]))
	for pair in STONES:
		stepping_stones(crossings, pair[0], pair[1])
	hearth_gaps()
	# Last, so it keeps off everything above: the green round each island.
	for name in ISLANDS:
		foliage(name)
	clouds()
	var ps := PackedScene.new()
	var err := ps.pack(scn)
	if err == OK:
		err = ResourceSaver.save(ps, OUT)
	print("BLOCKOUT: saved %s (%s): %d blocks, %d spawns, %d movers, %d weapon pickups, %d bot crossings" % [OUT, error_string(err),
		scn.find_children("*", "MapBlock", true, false).size(), scn.find_children("*", "MapSpawn", true, false).size(),
		scn.find_children("*", "MapMover", true, false).size(), scn.find_children("*", "MapWeaponSpawn", true, false).size(), links])
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


## The same, exactly as the deck is drawn. (on_island takes each slab's flat sides to
## lie where the drawn slab has its corners, so it is up to a metre off at the rim.
## The pads were laid out with it and the layout is settled, so it stays for them;
## everything placed since goes by this.)
func on_deck(name: String, p: Vector2) -> bool:
	for l in ISLANDS[name][1]:
		var sides: int = l[3]
		var local := (p - Vector2(l[0], l[1])).rotated(deg_to_rad(l[4]))
		var half := PI / sides
		var a := fposmod(local.angle() - half, 2.0 * half) - half   # (a corner at angle 0, as MapMesher draws it)
		if local.length() * cos(a) <= l[2] * 0.5 * cos(half):
			return true
	return false


## How far the drawn deck runs from the island's centre in the flat direction `dir`.
func deck_reach(name: String, dir: Vector3) -> float:
	var far := 0.0
	var t := 0.0
	while t < 60.0:
		if on_deck(name, Vector2(dir.x, dir.z) * t):
			far = t
		t += 0.02
	return far


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
	mid_of[m] = at
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
	clear_of(island, at, 2.5)


## Keeps the foliage `radius` off a spot `at` in a mover's frame.
func clear_of(mover_node: Node3D, at: Vector3, radius: float) -> void:
	var p: Vector3 = mid_of[mover_node] + at
	keep_clear.append([p.x, p.z, radius])


## Midday over a sea of cloud (the sky is a shader: game/maps/sky/sky_island_sky.gdshader),
## a light haze that pales the far islands, and a warm sun from the south-east.
func sky() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load(SKY)
	var sun_dir := Basis.from_euler(Vector3(deg_to_rad(-52), deg_to_rad(35), 0)) * Vector3.BACK   # (toward the sun: the light shines down -z of the Sun node)
	mat.set_shader_parameter("sun_dir", sun_dir)
	mat.set_shader_parameter("cloud_height", -30.0)   # above the kill height (-36), below the deepest rock (about -26)
	var s := Sky.new()
	s.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = s
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.86, 0.95)
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.15
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	scn.add_child(we)
	we.owner = scn
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
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
	var i := 0
	for l in ISLANDS[name][1]:
		i += 1
		var d: float = l[2]
		var turn := deg_to_rad(l[4])
		# Each lobe is one selection group: its grass, its earth and the rock under it.
		var lobe := group(ground, "Lobe%d" % i, Transform3D(Basis.IDENTITY, V(l[0], 0, l[1])))
		lobe.set_meta("_edit_group_", true)
		cyl(lobe, "Turf", "grass", V(0, -TURF, 0), d, TURF, l[3], turn)
		cyl(lobe, "Earth", "earth", V(0, -DECK, 0), d, DECK - TURF, l[3], turn)
		# The rock: a cone hung point down (turned over about x), a little narrower than its deck.
		var depth := d * 0.45
		var rock := hung_cone(lobe, "Rock", "rock", V(0, -DECK, 0), d * 0.94, depth, d * 0.12, l[3], turn)
		rock.solid = true
		# Crags: smaller cones hung round it, so the underside is jagged, not one smooth point.
		for k in deco.randi_range(3, 5):
			var a := deco.randf_range(0.0, TAU)
			var out := deco.randf_range(0.15, 0.32) * d
			var w := deco.randf_range(0.22, 0.4) * d
			var at := V(cos(a) * out, -DECK - deco.randf_range(0.3, 1.2), sin(a) * out)
			var crag := hung_cone(lobe, "Crag", "rock_dark" if k % 2 == 0 else "rock", at, w, w * deco.randf_range(0.9, 1.6), w * 0.1,
				deco.randi_range(5, 7), deco.randf_range(0.0, TAU))
			crag.solid = false


## A cone of rock hung point down from `top` (the middle of its wide end).
func hung_cone(parent: Node, name: String, kind: String, top: Vector3, width: float, depth: float, tip: float, sides: int, turn: float) -> MapBlock:
	var b := put(parent, name, kind, Vector3(width, depth, width), top - V(0, depth * 0.5, 0),
		Basis(Vector3.UP, turn) * Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)), MapBlock.Shape.CONE)
	b.sides = sides
	b.top = tip
	b.solid = false
	return b


func shelf(g: Node3D) -> void:
	var cover := group(g, "Cover")
	masonry(cover, "Block", V(-6, 0, -3), V(-4, 1.2, 1))
	masonry(cover, "Block", V(4, 0, 4), V(7, 1.2, 5.2))
	masonry(cover, "Block", V(-1, 0, -10), V(1, 2.2, -8))
	masonry(cover, "Block", V(-11, 0, 9), V(-9.5, 2.2, 10.5))
	masonry(cover, "Block", V(11, 0, -8), V(13.5, 1.2, -6.8))
	wall_run(g, V(-3, 0, 9.6), V(7, 4.5, 10.4))
	for at in [V(-10, 0, -3), V(3, 0, -5), V(4, 0, 14), V(13, 0, -3)]:
		spawn(g, "Shelf", at, Vector3.ZERO)


## The Garden: a ring of standing stones, mossy at the foot, round a cross of low walls.
func garden(g: Node3D) -> void:
	var ring := group(g, "StandingStones")
	var heights := [4.2, 3.0, 4.2, 1.4, 4.2, 2.2, 3.6]
	for i in heights.size():
		var a := TAU * i / heights.size() + 0.3
		var stone := group(ring, "Stone", Transform3D(Basis.IDENTITY, V(cos(a) * 7.0, 0, sin(a) * 7.0)))
		stone.set_meta("_edit_group_", true)
		cyl(stone, "Block", "stone_dark", V(0, 0, 0), 1.4, heights[i], 10)
		var moss := cyl(stone, "Moss", "moss", V(0, 0, 0), 1.56, minf(0.5, heights[i] * 0.3), 10)
		moss.solid = false
	var cover := group(g, "Cover")
	wall_piece(cover, "masonry", Vector3(5, 1.2, 0.8), V(0, 0.6, 0), Basis.IDENTITY, 0.5)
	wall_piece(cover, "masonry", Vector3(0.8, 1.2, 2.8), V(0, 0.6, 3.6), Basis.IDENTITY, 0.5)
	masonry(cover, "Block", V(-12, 0, 6), V(-10, 1.2, 8.5))
	for at in [V(-2, 0, -10.5), V(10, 0, 4), V(-11, 0, 3)]:
		spawn(g, "Garden", at, Vector3.ZERO)


## The Spire: a lone obelisk with a pointed cap, and two blocks of fallen masonry.
func spire(g: Node3D) -> void:
	var obelisk := group(g, "Pillar", Transform3D(Basis.IDENTITY, V(-2, 0, -2)))
	obelisk.set_meta("_edit_group_", true)
	cyl(obelisk, "Shaft", "stone", V(0, 0, 0), 1.8, 5.0, 12)
	var plinth := cyl(obelisk, "Plinth", "stone_dark", V(0, 0, 0), 2.4, 0.5, 12)
	plinth.solid = false
	var cap := put(obelisk, "Cap", "coping", Vector3(2.0, 1.2, 2.0), V(0, 5.6, 0), Basis.IDENTITY, MapBlock.Shape.CONE)
	cap.sides = 12
	cap.top = 0.0
	cap.solid = false
	masonry(g, "Cover", V(2, 0, 3), V(5, 1.2, 4))
	masonry(g, "Cover", V(7, 0, 5), V(8.2, 1.2, 7.5))
	spawn(g, "Spire", V(-4, 0, 4.5), Vector3.ZERO)
	spawn(g, "Spire", V(8, 0, 2), Vector3.ZERO)


func bluff(g: Node3D) -> void:
	var cover := group(g, "Cover")
	masonry(cover, "Block", V(-5, 0, -4), V(-3, 1.2, -1))
	masonry(cover, "Block", V(5, 0, 2), V(8, 1.2, 3.2))
	masonry(cover, "Block", V(-10, 0, 8), V(-8.5, 2.2, 9.5))
	masonry(cover, "Block", V(9, 0, -10), V(11, 2.2, -8.5))
	wall_piece(cover, "masonry", Vector3(5, 1.2, 0.8), V(1, 0.6, 6.4), Basis.IDENTITY, 0.5)
	wall_run(g, V(-0.4, 0, -11), V(0.4, 4.5, -3))
	for at in [V(-9, 0, -3), V(6, 0, -5), V(3, 0, 11), V(-10, 0, 4)]:
		spawn(g, "Bluff", at, Vector3.ZERO)


# -- stonework -------------------------------------------------------------------------
## A block of fallen masonry from `lo` to `hi` (cover), with moss on part of its top.
func masonry(parent: Node, name: String, lo: Vector3, hi: Vector3) -> Node3D:
	var mid := (lo + hi) * 0.5
	var size := (hi - lo).abs()
	var g := group(parent, name, Transform3D(Basis.IDENTITY, V(mid.x, lo.y, mid.z)))
	g.set_meta("_edit_group_", true)
	box(g, "Stone", "masonry", V(-size.x * 0.5, 0, -size.z * 0.5), V(size.x * 0.5, size.y, size.z * 0.5))
	var mx := size.x * deco.randf_range(0.4, 0.75)
	var mz := size.z * deco.randf_range(0.4, 0.75)
	var ox := (size.x - mx) * 0.5 * (1.0 if deco.randf() < 0.5 else -1.0)
	var oz := (size.z - mz) * 0.5 * (1.0 if deco.randf() < 0.5 else -1.0)
	var moss := box(g, "Moss", "moss", V(ox - mx * 0.5, size.y, oz - mz * 0.5), V(ox + mx * 0.5, size.y + 0.04, oz + mz * 0.5))
	moss.solid = false
	return g


## A wall to run along (`lo` to `hi`): bricks of its own colour, so it reads as one,
## under a coping.
func wall_run(parent: Node, lo: Vector3, hi: Vector3) -> void:
	var g := group(parent, "WallRun")
	g.set_meta("_edit_group_", true)
	box(g, "Wall", "wallrun", lo, hi)
	var c := box(g, "Coping", "coping", V(lo.x - 0.08, hi.y, lo.z - 0.08), V(hi.x + 0.08, hi.y + 0.16, hi.z + 0.08))
	c.solid = false


## One piece of a stone wall: a group holding the block itself, a coping along its top
## (on pieces more than 0.6 m tall) and, now and then (`ivy_chance`), ivy climbing one
## face. `size` and `at` (its middle) and `rot` as for put(): the block's x runs along
## the wall, z through it.
func wall_piece(parent: Node, kind: String, size: Vector3, at: Vector3, rot: Basis, ivy_chance := 0.3) -> Node3D:
	var g := group(parent, "Wall", Transform3D(rot, at))
	g.set_meta("_edit_group_", true)
	put(g, "Stone", kind, size, Vector3.ZERO)
	if size.y > 0.6:
		var c := put(g, "Coping", "coping", Vector3(size.x + 0.04, 0.16, size.z + 0.16), V(0, size.y * 0.5 + 0.08, 0))
		c.solid = false
	if size.y > 1.0 and deco.randf() < ivy_chance:
		# Ivy: a sheet a hand's breadth proud of one face, from the foot up part of the way.
		var face := 1.0 if deco.randf() < 0.5 else -1.0
		var w := size.x * deco.randf_range(0.35, 0.8)
		var h := size.y * deco.randf_range(0.4, 0.85)
		var along := (size.x - w) * 0.5 * deco.randf_range(-1.0, 1.0)
		var ivy := put(g, "Ivy", "ivy", Vector3(w, h, 0.06), V(along, -size.y * 0.5 + h * 0.5, face * (size.z * 0.5 + 0.04)))
		ivy.solid = false
	return g


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
		wall_piece(parent, "stone", Vector3(piece, h, thick), V(mid.x, h * 0.5, mid.y), rot)


## Fallen stones: [x, z, length, height, depth, turn in degrees] each.
func rubble(parent: Node, stones: Array) -> void:
	var g := group(parent, "Rubble")
	for s in stones:
		var stone := put(g, "Stone", "masonry", Vector3(s[2], s[3], s[4]), V(s[0], s[3] * 0.5, s[1]), Basis(Vector3.UP, deg_to_rad(s[5])))
		stone.shape = MapBlock.Shape.BEVEL
		stone.bevel = 0.15


## A round tower (a drum) standing on `base`: courses of darker stone at its foot, and
## round its top a ring of merlons (on a whole one) or nothing (on a broken stump).
func drum(parent: Node, name: String, base: Vector3, diameter: float, height: float, sides: int, merlons: bool) -> Node3D:
	var g := group(parent, name, Transform3D(Basis.IDENTITY, base))
	g.set_meta("_edit_group_", true)
	cyl(g, "Stone", "stone", V(0, 0, 0), diameter, height, sides)
	var plinth := cyl(g, "Plinth", "stone_dark", V(0, 0, 0), diameter + 0.3, 0.8, sides)
	plinth.solid = false
	if merlons:
		var string := cyl(g, "Course", "coping", V(0, height - 0.32, 0), diameter + 0.2, 0.24, sides)   # (its top below the drum's, not in the same plane)
		string.solid = false
		for k in sides:
			if k % 2 == 1:
				continue
			var a := TAU * (k + 0.5) / sides
			var r := diameter * 0.5 * cos(PI / sides) - 0.25
			put(g, "Merlon", "stone", Vector3(0.9, 0.9, 0.5), V(cos(a) * r, height + 0.45, sin(a) * r), Basis(Vector3.UP, -a + PI * 0.5))
	return g


## A banner hanging on a pole set out from a wall: `at` is the top of the pole (in the
## parent's frame) and `out` the way the wall faces.
func banner(parent: Node, at: Vector3, out: Vector3, kind: String, drop := 3.2) -> void:
	var g := group(parent, "Banner", Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), at))
	g.set_meta("_edit_group_", true)
	var pole := put(g, "Pole", "wood", Vector3(0.12, 0.12, 0.9), V(0, 0, 0.45))
	pole.solid = false
	var cloth := put(g, "Cloth", kind, Vector3(1.3, drop, 0.05), V(0, -drop * 0.5, 0.8))
	cloth.solid = false
	var trim := put(g, "Trim", "banner_gold", Vector3(1.34, 0.2, 0.07), V(0, -drop + 0.07, 0.8))   # (hangs 3 cm below the cloth: their feet are not in one plane)
	trim.solid = false


## A paved floor (paint on the ground, 3 cm thick) from `lo` to `hi` (x and z).
func paving(parent: Node, name: String, lo: Vector2, hi: Vector2, y := 0.0) -> void:
	var p := box(parent, name, "paving", V(lo.x, y, lo.y), V(hi.x, y + 0.03, hi.y))
	p.solid = false
	paved.append([parent, Rect2(lo, hi - lo)])


## A column standing on `base`: shaft, with a base under it and (if it still stands
## to full height, 3.5 m or more) a capital on top.
func column(parent: Node, base: Vector3, diameter: float, height: float) -> void:
	var g := group(parent, "Column", Transform3D(Basis.IDENTITY, base))
	g.set_meta("_edit_group_", true)
	cyl(g, "Shaft", "marble", V(0, 0, 0), diameter, height, 10)
	var foot := cyl(g, "Base", "stone_dark", V(0, 0, 0), diameter + 0.35, 0.35, 10)
	foot.solid = false
	if height >= 3.5:
		var cap := put(g, "Capital", "coping", Vector3(diameter + 0.5, 0.35, diameter + 0.5), V(0, height + 0.175, 0))
		cap.solid = false


## The Hearth: the ruined Keep, 22 by 16 m. Its walls stand between nothing and 7.2 m;
## the gate in the south wall still has its lintel; a corner of the upper floor is left
## (3 m up, on two piers, a fallen slab for a ramp); a tall drum stands at the north-east
## corner and the stump of another at the south-west.
func hearth(g: Node3D) -> void:
	var k := group(g, "Keep")
	var walls := group(k, "Walls")
	broken_wall(walls, Vector2(-11, 8), Vector2(11, 8), [6.0, 4.8, 3.6, 3.6, 0, 0, 3.6, 4.8, 6.0, 7.2, 4.8])
	box(walls, "GateLintel", "stone_dark", V(-3, 2.9, 8 - THICK * 0.5), V(1, 3.6, 8 + THICK * 0.5))
	broken_wall(walls, Vector2(-11, -8), Vector2(11, -8), [7.2, 7.2, 6.0, 4.8, 2.4, 1.2, 0, 1.2, 3.6, 6.0, 6.0])
	broken_wall(walls, Vector2(-11, -8), Vector2(-11, 8), [7.2, 6.0, 4.8, 0, 0, 2.4, 4.8, 6.0])
	broken_wall(walls, Vector2(11, -8), Vector2(11, 8), [6.0, 3.6, 1.2, 1.2, 2.4, 0, 3.6, 4.8])
	var tall := drum(k, "TallDrum", V(11, 0, -8), 6.0, 9.0, 12, true)
	banner(tall, V(2.85, 8.2, 0), Vector3(1, 0, 0), "banner_red", 3.6)
	drum(k, "DrumStump", V(-11, 0, 8), 6.0, 2.4, 12, false)
	paving(k, "Paving", Vector2(-10.6, -7.6), Vector2(10.6, 7.6))
	var upper := group(k, "UpperFloor")
	box(upper, "Slab", "paving", V(-10.6, 2.7, -7.6), V(-1, 3.0, -1.5))
	for x in [-2.0, -6.5]:
		cyl(upper, "Pier", "marble", V(x, 0, -2.2), 0.9, 2.7, 10)
	ramp(upper, "FallenSlab", "slab", V(5.5, 0, -4.5), V(-1, 3.0, -4.5), 2.6, 0.35)
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
		wall_piece(shell, "stone", Vector3(panel, h, THICK), V(cos(a) * apothem, h * 0.5, sin(a) * apothem), Basis(Vector3.UP, atan2(-cos(a), -sin(a))), 0.5)
	var inside := group(t, "Inside")
	var floor := cyl(inside, "Paving", "paving", V(0, 0, 0), 13.0, 0.03, 16)   # (round, to stay inside the eight walls)
	floor.solid = false
	paved.append([inside, Rect2(-6.5, -6.5, 13.0, 13.0)])
	box(inside, "Slab", "paving", V(-4.4, 2.7, -4.4), V(4.4, 3.0, 0))
	ramp(inside, "FallenSlab", "slab", V(2.5, 0, 5.4), V(2.5, 3.0, 0), 2.4, 0.35)
	banner(shell, V(cos(PI * 0.25) * (apothem + THICK * 0.5 - 0.05), 8.6, sin(PI * 0.25) * (apothem + THICK * 0.5 - 0.05)),
		Vector3(cos(PI * 0.25), 0, sin(PI * 0.25)), "banner_blue", 4.0)
	broken_wall(t, Vector2(7.6, -0.5), Vector2(15.6, -3.5), [6.0, 4.8, 2.4, 1.2])
	var columns := group(t, "FallenColumns")
	put(columns, "Column", "marble", Vector3(1.2, 5.0, 1.2), V(-11, 0.6, 7), Basis(Vector3.UP, 0.5) * Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), MapBlock.Shape.CYLINDER)
	put(columns, "Column", "marble", Vector3(1.2, 3.0, 1.2), V(-9, 0.6, 11.5), Basis(Vector3.UP, -0.4) * Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)), MapBlock.Shape.CYLINDER)
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
	# The wall itself, stone all through (no copings: the walk runs along its top).
	box(w, "Wall", "stone", V(-17, 0, z0), V(-6, top, z1))
	box(w, "Wall", "stone", V(-3.5, 0, z0), V(-2, top, z1))
	box(w, "GateLintel", "stone_dark", V(-2, 3.6, z0), V(2, top, z1))
	box(w, "Wall", "stone", V(2, 0, z0), V(7, top, z1))
	wall_piece(w, "stone", Vector3(2, 2.4, z1 - z0), V(8, 1.2, (z0 + z1) * 0.5), Basis.IDENTITY, 0.0)   # the low breach: it has a coping
	box(w, "Wall", "stone", V(9, 0, z0), V(12, top, z1))
	# Banners down its outer face either side of the gate, and the ivy on it.
	for x in [-2.75, 4.5]:
		banner(w, V(x, top - 0.4, z0 + 0.05), Vector3(0, 0, -1), "banner_blue", 3.0)
	for ivy in [[-14.0, 3.6, 3.2], [10.4, 2.0, 3.8]]:
		var sheet := box(w, "Ivy", "ivy", V(ivy[0] - ivy[1] * 0.5, 0, z0 - 0.07), V(ivy[0] + ivy[1] * 0.5, ivy[2], z0 - 0.01))
		sheet.solid = false
	var merlons := group(w, "Merlons")
	for x in [-16.3, -14.3, -12.3, -10.3, -8.3, -2.9, -0.7, 1.3, 3.3, 5.3, 9.7, 11.3]:
		var m := group(merlons, "Merlon", Transform3D(Basis.IDENTITY, V(x, top, z0 + 0.25)))
		m.set_meta("_edit_group_", true)
		box(m, "Stone", "stone", V(-0.5, 0, -0.25), V(0.5, 0.9, 0.25))
		var cap := box(m, "Coping", "coping", V(-0.56, 0.9, -0.31), V(0.56, 1.02, 0.31))
		cap.solid = false
	ramp(w, "Stair", "slab", V(-6.5, 0, z1 + 1.0), V(-16, top, z1 + 1.0), 2.0, 0.4)
	box(w, "StairLanding", "paving", V(-18.5, top - 0.4, z1), V(-16, top, z1 + 2.03))   # level with the wall walk, to step across from
	var tower := drum(w, "Drum", V(14, 0, -3), 6.0, 7.2, 12, true)
	banner(tower, V(0, 6.4, -2.85), Vector3(0, 0, -1), "banner_blue", 3.4)
	paving(g, "Courtyard", Vector2(-12, -2), Vector2(12, 9))
	var columns := group(g, "Colonnade")
	var heights := [4.0, 1.2, 3.0, 4.0, 0.8]
	for i in heights.size():
		column(columns, V(-9 + i * 4.5, 0, 6), 1.0, heights[i])
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
	var stops := []         # the pads in the row, in order: [their mover, the middle of their top (half way up), diameter]
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
		stops.append([pad(g, at, d, bob), at, d])
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
	# The bots' way along the row: a hop each way between each stop and the next.
	hop_links(from, stops[0])
	for i in stops.size() - 1:
		pad_links(stops[i], stops[i + 1])
	hop_links(to, stops[stops.size() - 1])


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
func pad(parent: Node, at: Vector3, d: float, bob: Array) -> Node3D:
	var sides := rng.randi_range(5, 9)
	var turn := rng.randf_range(0.0, TAU)
	var m := mover(parent, "Pad", at, bob[0], bob[1])
	m.set_meta("_edit_group_", true)   # (one click in the viewport picks the whole pad)
	# A little island of its own: grass on top, earth, a cone of rock under it.
	cyl(m, "Turf", "grass", V(0, -0.25, 0), d, 0.25, sides, turn)
	cyl(m, "Earth", "earth", V(0, -1.0, 0), d, 0.75, sides, turn)
	var rock := hung_cone(m, "Rock", "rock", V(0, -1.0, 0), d * 0.9, d * 0.55, d * 0.2, sides, turn)
	rock.solid = true
	var crag := hung_cone(m, "Crag", "rock", V(deco.randf_range(-0.15, 0.15) * d, -1.3, deco.randf_range(-0.15, 0.15) * d),
		d * 0.45, d * 0.7, d * 0.05, 5, deco.randf_range(0.0, TAU))
	crag.solid = false
	# Moss hanging over its edge (one colour: every colour on a moving part is one more
	# thing to draw, 25 pads over).
	for k in deco.randi_range(1, 3):
		var a := deco.randf_range(0.0, TAU)
		drip(m, V(cos(a), 0, sin(a)) * (d * 0.5 * cos(PI / sides) - 0.05), deco.randf_range(0.9, 2.2), "moss")
	return m


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
	boost_links()


# -- bots' crossings and pickups -----------------------------------------------------
## A weapon pickup on an island (`at` in its frame): it rides the island's bob.
func pickup(island: Node3D, weapon: String, at: Vector3) -> void:
	var holder := island.get_node_or_null("WeaponSpawns")
	if holder == null:
		holder = group(island, "WeaponSpawns")
	var w: Marker3D = weapon_script.new()
	w.name = weapon.to_pascal_case()
	w.set("weapon", weapon)
	holder.add_child(w, true)
	w.owner = scn
	w.position = at
	clear_of(island, at, 2.0)


## A node's transform in `top`'s frame (the scene is not in a tree yet, so no globals).
func frame_in(node: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != top:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## What stands on an island's deck (everything but its Ground): [x, z, radius] each, in
## its frame, the radius reaching the corners of the block's footprint.
func what_stands_on(island: Node3D) -> Array:
	var out := []
	var ground := island.get_node("Ground")
	for b in island.find_children("*", "MapBlock", true, false):
		if ground.is_ancestor_of(b) or not (b as MapBlock).solid:
			continue   # (drawn-only dressing is in nobody's way)
		var box := frame_in(b, island) * AABB(-(b as MapBlock).size * 0.5, (b as MapBlock).size)
		out.append([box.get_center().x, box.get_center().z, Vector2(box.size.x, box.size.z).length() * 0.5])
	return out


## Room for a bot at `p` (an island's frame): nothing standing within `r`, and deck all round.
func clear_spot(name: String, p: Vector2, r: float) -> bool:
	for o in obstacles[name]:
		if p.distance_to(Vector2(o[0], o[1])) < r + float(o[2]):
			return false
	if not on_deck(name, p):
		return false
	for k in 8:
		if not on_deck(name, p + Vector2.from_angle(TAU * k / 8.0) * r):
			return false
	return true


## Nothing standing within `r` of the line from `a` to `b` (an island's frame).
func clear_run(name: String, a: Vector2, b: Vector2, r: float) -> bool:
	var steps := ceili(a.distance_to(b) / 0.5)
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(steps, 1))
		for o in obstacles[name]:
			if p.distance_to(Vector2(o[0], o[1])) < r + float(o[2]):
				return false
	return true


## Coming from `outside` toward `inside` (an island's frame), the first point on its deck.
func rim_toward(name: String, outside: Vector2, inside: Vector2) -> Vector2:
	var dir := (inside - outside).normalized()
	var p := outside
	var gone := 0.0
	while not on_deck(name, p) and gone < 140.0:
		p += dir * 0.05
		gone += 0.05
	return p


## The group in a mover that holds the crossings setting off from it and the spots
## landing on it.
func crossings_of(node: Node3D) -> Node3D:
	var holder := node.get_node_or_null("BotCrossings") as Node3D
	return holder if holder else group(node, "BotCrossings")


## A crossing for bots (a MapJumpLink): it sets off at `from_at` in `from_node` (a mover)
## and comes down at `land_at` in `to_node`. `land` reuses a landing spot already there.
func add_link(from_node: Node3D, from_at: Vector3, to_node: Node3D, land_at: Vector3, how: int, rise := Vector2.ZERO, flight := 0.8, land: Node3D = null) -> Node3D:
	var l: Marker3D = link_script.new()
	l.name = ("Hop" if how == MapJumpLink.How.HOP else "Boost") + "To" + str(to_node.name)
	l.set("how", how)
	l.set("rise_min", rise.x)
	l.set("rise_max", rise.y)
	l.set("flight", flight)
	crossings_of(from_node).add_child(l, true)
	l.owner = scn
	l.position = from_at
	if land == null:
		land = Marker3D.new()
		land.name = "LandFrom" + str(from_node.name)
		crossings_of(to_node).add_child(land, true)
		land.owner = scn
		land.position = land_at
	l.set("landing", l.get_path_to(land))
	# The foliage keeps off where it sets off, its run-up and where it comes down.
	var from_map: Vector3 = mid_of[from_node] + from_at
	var to_map: Vector3 = mid_of[to_node] + land.position
	var run := Vector3(to_map.x - from_map.x, 0, to_map.z - from_map.z)
	for s in range(0, int(minf(run.length(), 8.0)) + 1):
		var p := from_map + run.normalized() * s
		keep_clear.append([p.x, p.z, 2.0])
	keep_clear.append([to_map.x, to_map.z, 2.5])
	links += 1
	return land


## A pad's own landing spot (its middle), made once.
func pad_landing(stop: Array) -> Node3D:
	var holder := crossings_of(stop[0])
	var land := holder.get_node_or_null("Land") as Node3D
	if land == null:
		land = Marker3D.new()
		land.name = "Land"
		holder.add_child(land)
		land.owner = scn
	return land


## Hops both ways between two pads in a row (`stop` = [mover, middle of its top, diameter]).
func pad_links(s1: Array, s2: Array) -> void:
	var a: Vector3 = s1[1]
	var b: Vector3 = s2[1]
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	add_link(s1[0], dir * (float(s1[2]) * 0.5 - RUN_UP), s2[0], Vector3.ZERO, MapJumpLink.How.HOP, Vector2.ZERO, 0.8, pad_landing(s2))
	add_link(s2[0], -dir * (float(s2[2]) * 0.5 - RUN_UP), s1[0], Vector3.ZERO, MapJumpLink.How.HOP, Vector2.ZERO, 0.8, pad_landing(s1))


## Hops both ways between an island and the pad next to it: on the line from the pad
## toward the island's middle, or a line beside it if something stands in the way.
func hop_links(name: String, stop: Array) -> void:
	var c := centre(name)
	var at: Vector3 = stop[1]
	var d: float = stop[2]
	var pad_xz := Vector2(at.x - c.x, at.z - c.z)   # the pad's middle, in the island's frame
	var toward := -pad_xz.normalized()               # from the pad into the island
	var across := Vector2(-toward.y, toward.x)
	for off in [0.0, 1.5, -1.5, 3.0, -3.0, 4.5, -4.5]:
		var line: Vector2 = pad_xz + across * off
		var rim := rim_toward(name, line, line + toward * 120.0)
		var takeoff := rim + toward * RUN_UP
		var landing := rim + toward * 3.5
		var gap := rim.distance_to(pad_xz) - d * 0.5
		if gap > 5.0 or not clear_spot(name, takeoff, 0.8) or not clear_spot(name, landing, 1.2) or not clear_run(name, takeoff, rim, 0.8):
			continue
		var node: Node3D = island_nodes[name]
		var pad_dir := Vector3(toward.x, 0, toward.y)
		add_link(node, V(takeoff.x, 0, takeoff.y), stop[0], Vector3.ZERO, MapJumpLink.How.HOP, Vector2.ZERO, 0.8, pad_landing(stop))
		add_link(stop[0], pad_dir * (d * 0.5 - RUN_UP) + Vector3(across.x, 0, across.y) * off * 0.5, node, V(landing.x, 0, landing.y), MapJumpLink.How.HOP)
		return
	print("  WARNING: no clear way for bots between %s and its pad at %s" % [name, at])


## The rocket boots between the Hearth and each outer island, on the line between their
## middles (or one beside it): down onto the Hearth at any moment; up off it only while
## the landing will be at most HEARTH_CLIMB above the takeoff, and not at all to an
## island that never comes that low.
func boost_links() -> void:
	var hearth: Node3D = island_nodes["Hearth"]
	var hc := centre("Hearth")
	for name in ISLANDS:
		if name == "Hearth":
			continue
		var oc := centre(name)
		var dir := Vector2(oc.x - hc.x, oc.z - hc.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		var least := INF
		for k in 96:
			var t := PERIOD * k / 96.0
			least = minf(least, height_at([oc.y, BOB[name][0], BOB[name][1]], t) - height_at([hc.y, BOB["Hearth"][0], BOB["Hearth"][1]], t))
		var made := false
		for off in [0.0, 2.0, -2.0, 4.0, -4.0, 6.0, -6.0, 8.0, -8.0]:
			var h_rim := rim_toward("Hearth", side * float(off) + dir * 120.0, side * float(off))
			var h_spot := h_rim - dir * BOOST_RUN
			var o_line: Vector2 = Vector2(hc.x - oc.x, hc.z - oc.z) + side * off   # the Hearth's side, in the outer island's frame
			var o_rim := rim_toward(name, o_line, side * float(off))
			var o_spot := o_rim + dir * BOOST_RUN
			if not clear_spot("Hearth", h_spot, 2.0) or not clear_run("Hearth", h_spot, h_rim, 0.9) \
					or not clear_spot(name, o_spot, 2.0) or not clear_run(name, o_spot, o_rim, 0.9):
				continue
			var outer: Node3D = island_nodes[name]
			add_link(outer, V(o_spot.x, 0, o_spot.y), hearth, V(h_spot.x, 0, h_spot.y), MapJumpLink.How.BOOST, Vector2.ZERO, BOOST_FLIGHT)
			if least <= HEARTH_CLIMB:
				add_link(hearth, V(h_spot.x, 0, h_spot.y), outer, V(o_spot.x, 0, o_spot.y), MapJumpLink.How.BOOST, Vector2(-4.0, HEARTH_CLIMB), BOOST_FLIGHT)
			print("  bots: boots from %s down to the Hearth%s" % [name, "" if least > HEARTH_CLIMB else ", and back up (when it is %.1f m up or less)" % HEARTH_CLIMB])
			made = true
			break
		if not made:
			print("  WARNING: no clear way for bots between the Hearth and %s" % name)


# -- the green and the clouds -----------------------------------------------------------
## How many trees each island grows (round its rim, clear of everything that matters).
const TREES := {"Hearth": 3, "Shelf": 2, "Bluff": 2, "Spire": 1, "Citadel": 2, "Garden": 3, "Terrace": 2}


## An island's green: moss hanging over its rim all the way round, bushes along the
## rim, a few trees, and tufts of long grass. All drawn only but the tree trunks, and
## none of it near a spawn point, a pickup, or where bots set off and land.
func foliage(name: String) -> void:
	var island: Node3D = island_nodes[name]
	var c := centre(name)
	# Moss over the rim (in the ground it hangs from).
	var moss := group(island.get_node("Ground"), "Moss")
	var a := 0.0
	while a < TAU:
		var dir := Vector3(cos(a), 0, sin(a))
		var rim := deck_reach(name, dir)
		drip(moss, dir * (rim - 0.1), deco.randf_range(1.8, 4.8))
		a += deco.randf_range(0.8, 1.8) / maxf(rim, 6.0)
	var g := group(island, "Foliage")
	var trees := group(g, "Trees")
	var planted := 0
	for attempt in 80:
		if planted >= int(TREES[name]):
			break
		var p := rim_spot(name, 2.8, 5.0)
		if spot_ok(name, p, 2.2, 4.0):
			tree(trees, V(p.x, 0, p.y), deco.randf_range(4.2, 6.0))
			obstacles[name].append([p.x, p.y, 2.4])   # (no bush in its trunk)
			planted += 1
	var bushes := group(g, "Bushes")
	var want: int = (ISLANDS[name][1] as Array).size() * 7
	var grown := 0
	for attempt in want * 12:
		if grown >= want:
			break
		var size := deco.randf_range(1.3, 2.4)
		var p := rim_spot(name, 0.3, 2.0)
		if spot_ok(name, p, size * 0.55, 1.2):
			bush(bushes, V(p.x, 0, p.y), size)
			grown += 1
	var grass := group(g, "Grass")
	var reach_all := 0.0
	for l in ISLANDS[name][1]:
		reach_all = maxf(reach_all, Vector2(l[0], l[1]).length() + float(l[2]) * 0.5)
	var tufts := 0
	for attempt in 400:
		if tufts >= want * 2:
			break
		var p := Vector2(deco.randf_range(-1.0, 1.0), deco.randf_range(-1.0, 1.0)) * reach_all
		if spot_ok(name, p, 1.0, 0.0):
			tuft(grass, V(p.x, 0, p.y))
			tufts += 1


## A spot `inset_min` to `inset_max` metres in from the island's rim, in a random way
## out from its middle (its frame).
func rim_spot(name: String, inset_min: float, inset_max: float) -> Vector2:
	var a := deco.randf_range(0.0, TAU)
	var dir := Vector3(cos(a), 0, sin(a))
	var r := deck_reach(name, dir) - deco.randf_range(inset_min, inset_max)
	return Vector2(dir.x, dir.z) * maxf(r, 0.0)


## Room to grow something `r` across at `p` (an island's frame): on the deck, clear of
## the ruins and cover, off paved floors, and `keep` metres (or more) off the spots the
## foliage keeps clear of.
func spot_ok(name: String, p: Vector2, r: float, keep: float) -> bool:
	if not clear_spot(name, p, r):
		return false
	var island: Node3D = island_nodes[name]
	for pv in paved:
		var holder: Node = pv[0]
		if (holder == island or island.is_ancestor_of(holder)) and (pv[1] as Rect2).grow(r).has_point(p):
			return false
	if keep > 0.0:
		var c := centre(name)
		var m := Vector2(c.x + p.x, c.z + p.y)
		for k in keep_clear:
			if m.distance_to(Vector2(k[0], k[1])) < float(k[2]) + keep + r:
				return false
	return true


## Moss hanging over a rim: a cone point down from just under the grass at `at`, `length` long.
func drip(parent: Node, at: Vector3, length: float, kind := "") -> void:
	var w := deco.randf_range(0.6, 1.4)
	# Each one's top a little lower than the last one's (four steps, then round again), its
	# colour going with its step: two side by side never meet in one plane in two colours.
	drips += 1
	var d := hung_cone(parent, "Drip", kind if kind != "" else ("moss" if drips % 2 == 0 else "ivy"), at + V(0, -0.05 - (drips % 4) * 0.012, 0), w, length, 0.0, 5, deco.randf_range(0.0, TAU))
	d.solid = false


## A tuft of long grass: two or three blades (thin cones).
func tuft(parent: Node, at: Vector3) -> void:
	for k in deco.randi_range(2, 3):
		var off := V(deco.randf_range(-0.2, 0.2), 0, deco.randf_range(-0.2, 0.2))
		var h := deco.randf_range(0.35, 0.65)
		var blade := put(parent, "Blade", "leaves_light" if k % 2 == 0 else "grass", Vector3(0.22, h, 0.22), at + off + V(0, h * 0.5 - 0.02, 0),
			Basis(Vector3.UP, deco.randf_range(0.0, TAU)), MapBlock.Shape.CONE)
		blade.sides = 4
		blade.top = 0.0
		blade.solid = false


## A bush `size` across standing at `at`: a few mounds of leaves, now and then in flower.
func bush(parent: Node, at: Vector3, size: float) -> void:
	var g := group(parent, "Bush", Transform3D(Basis.IDENTITY, at))
	g.set_meta("_edit_group_", true)
	var flowers := "" if deco.randf() < 0.5 else ("flowers" if deco.randf() < 0.6 else "flowers_pink")
	for k in deco.randi_range(2, 4):
		var w := size * deco.randf_range(0.55, 1.0)
		var off := V(deco.randf_range(-0.3, 0.3), 0, deco.randf_range(-0.3, 0.3)) * size
		var h := minf(w * deco.randf_range(0.5, 0.7), 1.1)
		var mound := put(g, "Leaves", "leaves" if k % 2 == 0 else "leaves_light", Vector3(w, h, w * deco.randf_range(0.8, 1.0)),
			off + V(0, h * 0.5 - k * 0.01, 0), Basis(Vector3.UP, deco.randf_range(0.0, TAU)), MapBlock.Shape.DOME)
		mound.sides = 8
		mound.solid = false
		if flowers != "":
			for f in 2:
				var fa := deco.randf_range(0.0, TAU)
				var bloom := put(g, "Flower", flowers, Vector3(0.14, 0.14, 0.14),
					off + V(cos(fa) * w * 0.3, h * 0.8, sin(fa) * w * 0.3), Basis(Vector3.UP, fa))
				bloom.solid = false


## A tree `height` tall at `at`: a trunk (solid: you can hide behind it) and a crown of
## leaves, each mound starting at its own height.
func tree(parent: Node, at: Vector3, height: float) -> void:
	var g := group(parent, "Tree", Transform3D(Basis.IDENTITY, at))
	g.set_meta("_edit_group_", true)
	cyl(g, "Trunk", "trunk", V(0, 0, 0), 0.55, height - 0.8, 7, deco.randf_range(0.0, TAU))
	var crown := [[0.0, 0.0, height - 1.6, 4.6, 2.8, "leaves"], [1.2, 0.7, height - 2.2, 3.0, 2.0, "leaves_light"],
		[-1.0, -0.9, height - 2.5, 3.2, 1.9, "leaves"], [-0.3, 1.1, height - 1.0, 2.6, 1.6, "leaves_light"]]
	var turn := deco.randf_range(0.0, TAU)
	for m in crown:
		var off := Vector3(m[0], 0, m[1]).rotated(Vector3.UP, turn)
		var leaves := put(g, "Leaves", m[5], Vector3(m[3], m[4], m[3]) * deco.randf_range(0.9, 1.1), off + V(0, float(m[2]) + float(m[4]) * 0.5, 0),
			Basis(Vector3.UP, deco.randf_range(0.0, TAU)), MapBlock.Shape.DOME)
		leaves.sides = 10
		leaves.solid = false


## Clouds: a slow-turning ring of them down among the islands' rocks (just above the
## sea of cloud the sky draws), and big ones far off beyond the edge of the map.
func clouds() -> void:
	var sky_group := group(scn, "Clouds")
	var spinner_script: Script = load("res://game/arena/map_spinner.gd")
	var low: Node3D = spinner_script.new()
	low.name = "Low"
	low.set("speed", 0.8)
	sky_group.add_child(low)
	low.owner = scn
	low.position = V(0, -27, 0)
	for k in 34:
		var a := TAU * k / 34.0 + deco.randf_range(-0.08, 0.08)
		var r := deco.randf_range(18.0, 135.0)
		puff(low, V(cos(a) * r, deco.randf_range(-2.0, 3.0), sin(a) * r), deco.randf_range(10.0, 22.0))
	var far: Node3D = spinner_script.new()
	far.name = "Far"
	far.set("speed", -0.35)
	sky_group.add_child(far)
	far.owner = scn
	for k in 16:
		var a := TAU * k / 16.0 + deco.randf_range(-0.12, 0.12)
		var r := deco.randf_range(180.0, 250.0)
		puff(far, V(cos(a) * r, deco.randf_range(-12.0, 28.0), sin(a) * r), deco.randf_range(26.0, 46.0))


## One cloud `size` across: a few flattened mounds of white.
func puff(parent: Node, at: Vector3, size: float) -> void:
	var g := group(parent, "Cloud", Transform3D(Basis.IDENTITY, at))
	g.set_meta("_edit_group_", true)
	for k in deco.randi_range(3, 5):
		var w := size * deco.randf_range(0.45, 0.85)
		var off := V(deco.randf_range(-0.35, 0.35) * size, deco.randf_range(-0.04, 0.12) * size, deco.randf_range(-0.25, 0.25) * size)
		var mound := put(g, "Puff", "cloud", Vector3(w, w * deco.randf_range(0.3, 0.45), w * deco.randf_range(0.6, 0.9)), off,
			Basis(Vector3.UP, deco.randf_range(0.0, TAU)), MapBlock.Shape.DOME)
		mound.sides = 10
		mound.solid = false
