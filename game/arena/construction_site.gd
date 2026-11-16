class_name ConstructionSite
extends SiteKit
## "Construction Site": the first player-facing map. An 80 x 80 m building site with
## one half-built tower in the middle and a tower crane over it.
##
## THE TOWER (32 x 32 m, in the middle). Floors every 4 m, each smaller than the one
## below, stepping back toward the north-west corner:
##     ground   an open hall of columns
##     4 m      the whole footprint; its south half is an open terrace
##     8 m      the north two thirds; its east side is an open terrace
##     12 m     the north-west two thirds
##     16 m     a strip along the north
##     20 m     the north-west corner
##     24 m     the crow's nest, a small deck around the top of the lift shaft
##   Where the concrete has not reached yet there is a bare steel frame: girders 8 m
##   or more above each terrace, to walk along and swing from.
##   Ways up: stairs (one flight per floor, spiralling round the lift shaft), the
##   lift shaft itself (wall-jump up it, step out at any floor, or drop down it),
##   crates under every floor edge (jump and climb), the scaffolding on the east
##   face (decks 2 m apart: jump and climb), the hoist tower on the west (a spiral of
##   small decks, with planks or a gap to jump at each floor), the conveyor on the
##   west (up to the 8 m floor: walk up, slide down), and the dirt ramp on the south.
##
## THE YARD (the ring around the tower): the crane and silos (north-east and east),
## stacked containers (south-east and north), site offices (north-west), a pit with
## pipes to run through (south-west), and floodlight masts in the corners to swing
## from. The fence is solid, 7 m high, and good for wall runs.
##
## x runs west to east, z north to south (north is -z), y is up.

const MAP_NAME := "Construction Site"
const HALF := 40.0                ## the site is 80 x 80 m
const TOWER := 16.0               ## the tower is 32 x 32 m
const NEST := 24.0                ## height of the crow's nest
const GRID := [-15.5, -5.5, 5.5, 15.5]   ## column lines (x and z)
const FENCE_HEIGHT := 7.0
const CRANE_BASE := Vector3(27, 0, -27)
const CRANE_HEIGHT := 34.0

# Lift shaft: the gap you wall-jump in is 3 m wide (x) and 4 m deep (z).
const SHAFT_X := 1.5
const SHAFT_Z := 2.0
# Pit in the south-west corner of the yard
const PIT := Rect2(-36, 20, 16, 16)
const PIT_DEPTH := 3.0
# Hoist tower (west of the tower): a spiral of 2.5 m decks, 2 m apart in height
const HOIST := Rect2(-28, -8, 5, 5)
const HOIST_TOP := 20.0
# Scaffolding on the tower's east face
# A tall crate stands by an edge of every floor: climb onto it, then jump and grab
# the floor above. One per floor, from the ground up: its position (floor level).
const STEP_UP := 2.2
const STEP_UPS := [
	Vector3(7.85, 0, -1),      # in the atrium, by its west edge -> 4 m
	Vector3(1.5, 4, 6.85),     # by the 8 m floor's south edge
	Vector3(6.85, 8, -14),     # by the 12 m floor's east edge
	Vector3(4.3, 12, -4.15),   # by the 16 m floor's south edge
	Vector3(-2.15, 16, -10),   # by the 20 m floor's east edge
	Vector3(0, 20, -5.85),     # by the crow's nest's north edge
]
const CONVEYOR_W := 2.2
const SCAFFOLD_X0 := 16.0
const NORTH_STACK_Z := -19.7      ## centre line of the containers north of the tower
const SCAFFOLD_X1 := 18.4


func map_name() -> String:
	return MAP_NAME


func bounds() -> Rect2:
	return Rect2(-HALF - 3, -HALF - 3, HALF * 2 + 6, HALF * 2 + 6)


func swing_point() -> Vector3:
	return Vector3(0, 18, SHAFT_Z + 1.2)   # high on the south face of the lift shaft


func build() -> MapLayout:
	_ground()
	_tower()
	_tower_cover()
	_east_scaffold()
	_hoist_tower()
	_conveyor()
	crane(CRANE_BASE, CRANE_HEIGHT, Vector3(-1, 0, 1), 56, 14, 52, 13)
	_yard()
	hoarding(HALF, FENCE_HEIGHT)
	_spawns()
	return self


static func _r(x0: float, x1: float, z0: float, z1: float) -> Rect2:
	return Rect2(x0, z0, x1 - x0, z1 - z0)


# ---------------------------------------------------------------------------
# Ground, pit and the dirt ramp up to the tower's first floor

func _ground() -> void:
	var out := HALF + 6.0
	var px0 := PIT.position.x
	var px1 := PIT.end.x
	var pz0 := PIT.position.y
	var pz1 := PIT.end.y
	_span(-out, out, -6, 0, -out, pz0, "dirt")
	_span(px1, out, -6, 0, pz0, out, "dirt")
	_span(-out, px0, -6, 0, pz0, pz1, "dirt")
	_span(-out, px1, -6, 0, pz1, out, "dirt")
	_span(px0, px1, -6, -PIT_DEPTH, pz0, pz1, "dirt_dark")
	# Two ramps into the pit (thick, so they are solid mounds of earth)
	_slab(Vector3(px1 - 8, -PIT_DEPTH, pz0 + 3.5), Vector3(px1, 0, pz0 + 3.5), 5, 5.0, "dirt_dark")
	_slab(Vector3(px0 + 3, -PIT_DEPTH, pz1 - 8), Vector3(px0 + 3, 0, pz1), 5, 5.0, "dirt_dark")
	# The earth ramp from the south up to the 4 m floor: run up it, slide down it
	_slab(Vector3(0, 0, 31), Vector3(0, 4, TOWER), 8, 6.0, "dirt")


# ---------------------------------------------------------------------------
# The tower

func _tower() -> void:
	# Lift shaft: two side walls to wall-jump between, open at the top, with a
	# doorway on its north side at every floor and a way through at ground level.
	_span(-3, -SHAFT_X, 0, NEST, -3, 3, "concrete_dark")
	_span(SHAFT_X, 3, 0, NEST, -3, 3, "concrete_dark")
	_span(-SHAFT_X, SHAFT_X, 2.6, NEST, SHAFT_Z, 3, "concrete_dark")
	for f in [0.0, 4.0, 8.0, 12.0, 16.0, 20.0]:
		_span(-SHAFT_X, SHAFT_X, f + 2.6, f + 4.0, -3, -SHAFT_Z, "concrete_dark")

	# Floor plates
	var core := _r(-3, 3, -3, 3)
	var stairwell := _r(-14.6, -11.4, 2, 12.2)
	var atrium := _r(7, 13, -4, 2)          # open from the ground to the sky
	var void_w := _r(-13, -8, -13, -8)      # open from the 4 m floor up to the 16 m floor
	plate(4, [_r(-TOWER, TOWER, -TOWER, TOWER)], [core, stairwell, atrium])
	plate(8, [_r(-TOWER, TOWER, -TOWER, 6)], [core, atrium, void_w])
	plate(12, [_r(-TOWER, 6, -TOWER, 6)], [core, void_w])
	plate(16, [_r(-TOWER, 6, -TOWER, -5), _r(-3, 3, -5, -3)])
	plate(20, [_r(-TOWER, -3, -TOWER, -3), _r(-3, 3, -7, -3)])
	plate(NEST, [_r(-5, 5, -5, 5)], [core], "plank", 0.3)

	# Stairs: one flight per floor, each landing on the edge of the floor above
	stair(Vector3(-13, 0, 12), Vector3(-13, 4, 2))
	stair(Vector3(10, 4, 14), Vector3(10, 8, 6))
	stair(Vector3(14, 8, -10), Vector3(6, 12, -10))
	stair(Vector3(-10, 12, 3), Vector3(-10, 16, -5))
	stair(Vector3(4.5, 16, -13), Vector3(-3, 20, -13))
	stair(Vector3(-12, 20, -4.5), Vector3(-5, NEST, -4.5), 2.4, 1)   # guard panel on the open south side

	# Columns: concrete up to the highest floor above each one...
	var steel_top := {}
	for gx in GRID:
		for gz in GRID:
			var top := floor_at(gx, gz)
			column(gx, gz, 0, top - 0.4)
			steel_top[Vector2(gx, gz)] = top
	# ...then a steel frame where the concrete has not reached: girders along the
	# column lines at 12, 16 and 20 m, wherever they are 8 m or more above the floor.
	for i in GRID.size():
		for j in GRID.size() - 1:
			for along_x in [true, false]:
				var a := Vector2(GRID[j], GRID[i]) if along_x else Vector2(GRID[i], GRID[j])
				var b := Vector2(GRID[j + 1], GRID[i]) if along_x else Vector2(GRID[i], GRID[j + 1])
				var mid := (a + b) * 0.5
				for y in [12.0, 16.0, 20.0]:
					if y - floor_at(mid.x, mid.y) >= 8.0:
						girder(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y))
						steel_top[a] = maxf(steel_top[a], y)
						steel_top[b] = maxf(steel_top[b], y)
	for gx in GRID:
		for gz in GRID:
			var top := floor_at(gx, gz)
			var steel: float = steel_top[Vector2(gx, gz)]
			if steel > top:
				steel_column(gx, gz, top, steel)

	# Block walls. The north face is one unbroken wall from 4 m to 16 m: wall-run it.
	var n := -TOWER + 0.15
	block_wall(-TOWER, n, 6, n, 4, 7.6)
	block_wall(-TOWER, n, 6, n, 8, 11.6)
	block_wall(-TOWER, n, -6, n, 12, 15.6)
	block_wall(0, n, 6, n, 12, 15.6)
	block_wall(n, -TOWER, n, -11, 8, 11.6)
	block_wall(n, -TOWER, n, -9, 16, 19.6)
	# Free-standing walls
	block_wall(7, -10, 15, -10, 0, 3.6)       # ground floor
	block_wall(-7, 7, -7, 13, 0, 3.6)
	block_wall(-12, -10, -5, -10, 0, 1.2)
	block_wall(-9, 11, -3, 11, 4, 6.6)        # on the south terrace (4 m)
	block_wall(11, -15, 11, -13, 8, 10.6)     # on the east terrace (8 m)


## Cover on the floors, edge barriers, and a tall crate by an edge of every floor so
## you can climb up a level without the stairs.
func _tower_cover() -> void:
	for p in STEP_UPS:
		crate(p, Vector3(1.6, STEP_UP, 1.6))
	# Ground floor
	pallet(Vector3(9.4, 0, -1), PI * 0.5, "blocks")      # a step beside the tall crate
	pallet(Vector3(10, 0, 1.1), 0.0, "bags")
	pallet(Vector3(-9, 0, -4), 0.3, "bags")
	pallet(Vector3(4, 0, -13), 0.0, "blocks")
	pallet(Vector3(-4, 0, 9), PI * 0.5, "timber")
	crate(Vector3(12, 0, 12), Vector3(1.6, 1.2, 1.6), 0.4)
	# A formwork table: 1.4 m clear underneath, so you can slide under it
	_span(-1.5, 4.5, 1.4, 1.6, 10, 13, "ply")
	for x in [-1.3, 4.3]:
		for z in [10.2, 12.8]:
			_box(Vector3(x, 0.7, z), Vector3(0.12, 1.4, 0.12), "scaffold", false)

	# 4 m floor
	pallet(Vector3(3.1, 4, 6.85), 0.0, "blocks")
	pallet(Vector3(13.8, 4, 10), PI * 0.5, "bags")
	pallet(Vector3(4, 4, 12), 0.5, "timber")
	crate(Vector3(-12, 4, -4), Vector3(1.6, 1.2, 1.6))
	pallet(Vector3(2, 4, -10), 0.0, "bags")
	barrier(Vector3(-15, 4, 15.9), Vector3(-6.5, 4, 15.9))
	barrier(Vector3(6.5, 4, 15.9), Vector3(15, 4, 15.9))
	barrier(Vector3(15.9, 4, 7), Vector3(15.9, 4, 15))

	# 8 m floor
	pallet(Vector3(8.4, 8, -14), PI * 0.5, "blocks")
	pallet(Vector3(-6, 8, 2), 0.2, "bags")
	crate(Vector3(12, 8, 4), Vector3(1.6, 1.2, 1.6), 0.2)
	pallet(Vector3(-10, 8, -4), 0.0, "timber")
	barrier(Vector3(13.1, 8, -4), Vector3(13.1, 8, 2))
	barrier(Vector3(-15, 8, 5.9), Vector3(-8, 8, 5.9))
	barrier(Vector3(15.9, 8, -15), Vector3(15.9, 8, -6))

	# 12 m floor
	pallet(Vector3(2, 12, 4.5), 0.0, "bags")
	crate(Vector3(-13, 12, 4), Vector3(1.6, 1.2, 1.6), 0.3)
	barrier(Vector3(5.9, 12, -4), Vector3(5.9, 12, 2))
	# The gap in the middle is the launch spot for grapple swings off the girders above
	barrier(Vector3(-12.5, 12, 5.9), Vector3(-1.6, 12, 5.9))
	barrier(Vector3(1.6, 12, 5.9), Vector3(4, 12, 5.9))

	# 16 m floor
	pallet(Vector3(3, 16, -7), 0.4, "bags")
	barrier(Vector3(-15, 16, -5.1), Vector3(-12, 16, -5.1))
	barrier(Vector3(5.9, 16, -15.5), Vector3(5.9, 16, -9.5))   # the turn onto the stairs is right at the edge

	# 20 m floor
	pallet(Vector3(-12, 20, -12), 0.6, "bags")
	barrier(Vector3(-15, 20, -3.1), Vector3(-13.5, 20, -3.1))


## Scaffolding up the east face. Decks at 4, 8 and 12 m run along the floors; the
## short decks at 2, 6 and 10 m are steps, so the whole thing can be climbed by
## jumping and grabbing the next deck's end.
func _east_scaffold() -> void:
	scaffold(SCAFFOLD_X0, SCAFFOLD_X1, -TOWER, TOWER + 3, [
		[2.0, TOWER, TOWER + 3],
		[4.0, -TOWER, TOWER],
		[6.0, 8, 12],
		[8.0, -TOWER, 8],
		[10.0, -2, 2],
		[12.0, -TOWER, -2],
	], 13.2)
	stair(Vector3(17.2, 0, -TOWER - 8), Vector3(17.2, 4, -TOWER), 2.2)


## The hoist tower: ten small decks, each 2 m higher than the last, going round and
## round (north-west, north-east, south-east, south-west, and again). Planks cross
## to the 4 m and 12 m floors; the top landing is level with the 20 m floor, 7 m
## away (a gap to jump).
func _hoist_tower() -> void:
	var x0 := HOIST.position.x
	var z0 := HOIST.position.y
	var h := HOIST.size.x * 0.5
	var quads := [Vector2(0, 0), Vector2(h, 0), Vector2(h, h), Vector2(0, h)]   # NW, NE, SE, SW
	var count := int(HOIST_TOP / 2.0)
	for i in count:
		var q: Vector2 = quads[i % 4]
		var y := 2.0 * (i + 1)
		_vary(_span(x0 + q.x, x0 + q.x + h, y - 0.14, y, z0 + q.y, z0 + q.y + h, "plank"), 0.05)
	# The top landing is three quarters of the footprint: room for a run-up
	_vary(_span(x0, x0 + h * 2, HOIST_TOP - 0.14, HOIST_TOP, z0 + h, z0 + h * 2, "plank"), 0.05)
	var mast_top := HOIST_TOP + 2.2
	for cx in [0.0, h, h * 2]:
		for cz in [0.0, h, h * 2]:
			if cx == h and cz == h:
				continue
			_box(Vector3(x0 + cx, mast_top * 0.5, z0 + cz), Vector3(0.12, mast_top, 0.12), "scaffold", false)
	var y := 4.0
	while y <= mast_top:
		for s in [0.0, h * 2]:
			_strut(Vector3(x0, y - 0.3, z0 + s), Vector3(x0 + h * 2, y - 0.3, z0 + s), 0.08, 0.08, "scaffold", false)
			_strut(Vector3(x0 + s, y - 0.3, z0), Vector3(x0 + s, y - 0.3, z0 + h * 2), 0.08, 0.08, "scaffold", false)
		y += 4.0
	_span(x0 - 0.2, x0 + h * 2 + 0.2, mast_top, mast_top + 0.3, z0 - 0.2, z0 + h * 2 + 0.2, "crane")
	# Planks across to the tower from the north-east decks (4 m and 12 m)
	var bridge_z := z0 + h * 0.5
	for level in [4.0, 12.0]:
		_vary(_beam(Vector3(x0 + h * 2, level, bridge_z), Vector3(-TOWER, level, bridge_z), 1.4, "plank"), 0.05)


## A belt conveyor from the west yard up to the 8 m floor. Walk up it, slide down it.
func _conveyor() -> void:
	var low := Vector3(-34, 0, 4)
	var high := Vector3(-TOWER, 8, 4)
	_slab(low, high, CONVEYOR_W, 0.3, "rubber")
	ramp_base(low, high, CONVEYOR_W + 0.5, "machine")   # the drive housing at the low end
	var dir := (high - low).normalized()
	for s in [-1, 1]:
		var off := Vector3(0, -0.1, s * (CONVEYOR_W * 0.5 + 0.1))
		_strut(low + off, high + off, 0.5, 0.2, "machine", false)
		# Side boards at the loading end: you get on at the end, not over the side
		var board := Vector3(0, 0.3, s * (CONVEYOR_W * 0.5 + 0.17))
		_strut(low + board - dir * 0.1, low + board + dir * 2.6, 0.14, 0.9, "machine")
	for t in [0.3, 0.55, 0.8]:
		var p := low.lerp(high, t)
		for s in [-1, 1]:
			_box(Vector3(p.x, (p.y - 0.4) * 0.5, p.z + s * (CONVEYOR_W * 0.5 + 0.1)), Vector3(0.16, p.y - 0.4, 0.16), "machine_dark", false)
		_box(Vector3(p.x, (p.y - 0.4) * 0.6, p.z), Vector3(0.1, 0.1, CONVEYOR_W + 0.2), "machine_dark", false)


# ---------------------------------------------------------------------------
# The yard around the tower

func _yard() -> void:
	# North: two stacked containers 2.5 m from the tower's north wall: jump from the
	# top one to the wall and run along it
	container(Vector3(-10, 0, NORTH_STACK_Z), "box_green")
	container(Vector3(-13, CONTAINER_H, NORTH_STACK_Z), "box_blue", false, 6)
	pallet(Vector3(7, 0, -25), 0.3, "blocks")
	pallet(Vector3(9, 0, -24), 1.2, "bags")
	jersey(Vector3(0, 0, -31), 6, PI * 0.5)

	# North-west: site offices, two high, and a store beside them
	office(Vector3(-30, 0, -33))
	office(Vector3(-30, CONTAINER_H, -33))
	container(Vector3(-34, 0, -27), "box_blue", true, 6)
	for i in 3:
		toilet(Vector3(-38.6, 0, -18 + i * 1.5), -PI * 0.5)
	skip(Vector3(-31, 0, -13), 0.2)

	# West: around the hoist tower and the conveyor
	pallet(Vector3(-21, 0, -12), 0.0, "blocks")
	pallet(Vector3(-30, 0, -1), 0.6, "timber")
	cable_drum(Vector3(-22, 0, 9), 0.4)
	jersey(Vector3(-36, 0, 8.5), 5, PI * 0.5)

	# South-west: the pit, with two big pipes to run through and a block of foundation
	culvert(Vector3(-29.5, -PIT_DEPTH + 1.3, 33), Vector3(-22.5, -PIT_DEPTH + 1.3, 33))
	culvert(Vector3(-28.5, -PIT_DEPTH + 1.3, 30), Vector3(-21.5, -PIT_DEPTH + 1.3, 30))
	_span(-34, -29, -PIT_DEPTH, -PIT_DEPTH + 0.7, 21.5, 26, "concrete")
	for x in [-33.2, -31.5, -29.8]:
		for z in [22.3, 23.75, 25.2]:
			_box(Vector3(x, -PIT_DEPTH + 1.2, z), Vector3(0.07, 1.0, 0.07), "rebar", false)
	excavator(Vector3(-27, 0, 15.5), PI, 0.35)

	# South: either side of the earth ramp
	jersey(Vector3(-6, 0, 33), 6, PI * 0.5)
	jersey(Vector3(6.5, 0, 34), 6, PI * 0.5)
	pipe_stack(Vector3(11, 0, 25), PI * 0.5, 3, 6)
	cable_drum(Vector3(-10, 0, 25), 0.0)
	cable_drum(Vector3(-12.4, 0, 26.2), 0.9)
	pallet(Vector3(18, 0, 22), 0.2, "timber")

	# South-east: containers. Two side by side with a third across them (a gateway)
	container(Vector3(27, 0, 26), "box_red", true)
	container(Vector3(32.4, 0, 26), "box_blue", true)
	container(Vector3(29.7, CONTAINER_H, 21.5), "box_green")
	container(Vector3(32.4, CONTAINER_H, 29), "box_white", true, 6)

	# East: a loaded trailer to slide under, pipes, silos and a mixer truck
	flatbed(Vector3(29, 0, 12), PI * 0.5)
	pipe_stack(Vector3(25, 0, 3), 0.0, 3, 6)
	silo(Vector3(35, 0, -4.5))
	silo(Vector3(35, 0, 1.5))
	mixer_truck(Vector3(26, 0, -11), 0.0)
	jersey(Vector3(22, 0, -4), 5, 0.0)

	# North-east: around the crane
	crate(Vector3(34, 0, -34), Vector3(2.4, 1.4, 1.4), 0.2)
	cable_drum(Vector3(19, 0, -31), 0.6)
	pallet(Vector3(35, 0, -20), 0.0, "bags")

	# Floodlight masts in the corners: 15 m up, something to swing from
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			light_mast(Vector3(sx * 37.5, 0, sz * 37.5), 15.0)


func _spawns() -> void:
	for p in [Vector3(-36.5, 0, -22), Vector3(0, 0, -35.5), Vector3(36, 0, -16), Vector3(37, 0, 17),
			Vector3(20, 0, 36), Vector3(-10, 0, 37), Vector3(-37.5, 0, 14), Vector3(-36, 0, -2),
			Vector3(14, 0, -36), Vector3(37, 0, 31), Vector3(-20, 0, -30), Vector3(22, 0, -20)]:
		_spawn(p, Vector3.ZERO)
