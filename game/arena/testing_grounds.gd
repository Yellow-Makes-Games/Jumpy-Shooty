class_name TestingGrounds
extends RefCounted
## "Testing Grounds": the long-term test map, built from boxes.
##
## Two parts:
##  - The ARENA (west, 80 x 80 m): the original combat test area. Central tower,
##    corner decks with bridges, free-standing walls, pillars and crates. Players
##    spawn here.
##  - The TRAINING YARD (east, through the big doorway): four practice lanes that
##    run west to east, each with a sign at its start.
##       north  GRAPPLE      swing between overhead beams across the pit
##              WALL RUN     zigzag wall panels across the pit, plus a long wall
##              SLIDE        a hill to slide down, bars to slide under, a kicker
##       south  VAULT/CLIMB  obstacles of marked heights, and a wall-jump chimney
##              GAP JUMPS    platforms with wider and wider gaps: jump, then
##                           jump + dive, then jump + flip + dive
##
## Not player-facing; the first real arena will be the construction site.

const MAP_NAME := "Testing Grounds"

## Each piece: { "xf": Transform3D (centre), "size": Vector3, "kind": String, "solid": bool }
var pieces: Array = []
var spawns: Array = []   ## Array of [Vector3 position, float yaw]
var signs: Array = []    ## Array of {"pos", "text", "yaw", "size"}

const HALF := 40.0       ## the arena part is 80 x 80 m (x and z from -40 to 40)
const WALL_H := 14.0
const YARD_END := 112.0  ## the training yard runs from x = 40 to here
const FACE_WEST := -PI / 2.0  ## sign yaw: readable when looking east, from the doorway

## Lane centre lines (z) in the training yard
const LANE_GRAPPLE := -30.0
const LANE_WALL := -10.0
const LANE_SLIDE := 10.0
const LANE_VAULT := 30.0


func build() -> TestingGrounds:
	_shell()
	_arena()
	_grapple_lane()
	_wall_lane()
	_slide_lane()
	_vault_lane()
	_gap_lane()
	_spawns()
	return self


# ---------------------------------------------------------------------------
# Floor, outer walls and the doorway between arena and yard

func _shell() -> void:
	var length := YARD_END + HALF
	var mid_x := (YARD_END - HALF) * 0.5
	_box(Vector3(mid_x, -0.5, 0), Vector3(length, 1, HALF * 2), "floor")
	_box(Vector3(mid_x, WALL_H / 2, -HALF), Vector3(length, WALL_H, 1), "wall")
	_box(Vector3(mid_x, WALL_H / 2, HALF), Vector3(length, WALL_H, 1), "wall")
	_box(Vector3(-HALF, WALL_H / 2, 0), Vector3(1, WALL_H, HALF * 2), "wall")
	_box(Vector3(YARD_END, WALL_H / 2, 0), Vector3(1, WALL_H, HALF * 2), "wall")
	# Dividing wall with a 20 m doorway in the middle
	_box(Vector3(HALF, WALL_H / 2, -25), Vector3(1, WALL_H, 30), "wall")
	_box(Vector3(HALF, WALL_H / 2, 25), Vector3(1, WALL_H, 30), "wall")
	_sign(Vector3(HALF - 0.6, 9, -12), "TRAINING YARD  >", FACE_WEST, 160)
	# Lane separators: painted lines on the floor
	for z in [-20.0, 0.0, 20.0]:
		_decal(Vector3((HALF + YARD_END) * 0.5 + 2, 0.01, z), Vector3(YARD_END - HALF - 4, 0.02, 0.3), "stripe")


# ---------------------------------------------------------------------------
# The original combat arena

func _arena() -> void:
	# Central tower: a 12 x 12 platform 6 m up, with two ramps
	_box(Vector3(0, 3, 0), Vector3(12, 6, 12), "block")
	_ramp(Vector3(0, 0, 20), Vector3(0, 6, 6), 5)
	_ramp(Vector3(0, 0, -20), Vector3(0, 6, -6), 5)
	_box(Vector3(-3.5, 6.6, 0), Vector3(1, 1.2, 4), "cover")
	_box(Vector3(3.5, 6.6, 0), Vector3(1, 1.2, 4), "cover")

	# Four corner decks, 4 m up, each with a ramp and a bridge toward the tower
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(sx * 28, 2, sz * 28), Vector3(14, 4, 14), "block")
			_ramp(Vector3(sx * 28, 0, sz * 12), Vector3(sx * 28, 4, sz * 21), 4)
			_beam(Vector3(sx * 22, 4, sz * 22), Vector3(sx * 9, 6, sz * 9), 2.5)

	# Free-standing walls (wall runs and cover)
	_box(Vector3(-18, 3, 0), Vector3(1, 6, 18), "wall")
	_box(Vector3(18, 3, 0), Vector3(1, 6, 18), "wall")
	_box(Vector3(0, 2.5, -30), Vector3(16, 5, 1), "wall")
	_box(Vector3(0, 2.5, 30), Vector3(16, 5, 1), "wall")

	# Pillars and crates
	for p in [Vector3(-10, 0, 12), Vector3(10, 0, -12), Vector3(-12, 0, -10), Vector3(12, 0, 10)]:
		_box(p + Vector3(0, 4, 0), Vector3(2, 8, 2), "pillar")
	for p in [Vector3(-26, 0, 6), Vector3(26, 0, -6), Vector3(6, 0, 26), Vector3(-6, 0, -26), Vector3(-34, 0, -2), Vector3(34, 0, 2)]:
		_box(p + Vector3(0, 0.75, 0), Vector3(2.5, 1.5, 2.5), "cover")


# ---------------------------------------------------------------------------
# GRAPPLE: start platform, three overhead beams across a pit, end platform

const GRAPPLE_BEAMS := [62.0, 74.0, 86.0]   ## x of each beam
const GRAPPLE_BEAM_Y := 14.0

func _grapple_lane() -> void:
	var z := LANE_GRAPPLE
	_sign(Vector3(43, 9, z), "GRAPPLE", FACE_WEST, 110, "Right-click a beam and swing. Let go at the bottom to fly.\nJump while swinging to let go with a kick.")
	_steps(Vector3(44, 0, z), 6.0, 5, 6.0)   # climb up by vaulting the steps...
	_box(Vector3(52, 3, z), Vector3(6, 6, 12), "pad")   # ...to the 6 m start platform (x 49-55)
	_decal(Vector3(75, 0.01, z), Vector3(40, 0.02, 14), "pit")   # the "pit" (just paint: no fall damage)
	for x in GRAPPLE_BEAMS:
		_box(Vector3(x, GRAPPLE_BEAM_Y + 0.5, z), Vector3(1.2, 1, 16), "grapple")
		for side in [-1, 1]:
			_box(Vector3(x, (GRAPPLE_BEAM_Y + 1) * 0.5, z + side * 7.5), Vector3(0.8, GRAPPLE_BEAM_Y + 1, 0.8), "pillar")
	_box(Vector3(99, 3, z), Vector3(8, 6, 12), "pad")   # end platform (x 95-103)
	_sign(Vector3(95.5, 8.5, z), "FINISH", FACE_WEST, 96)
	_steps(Vector3(109, 0, z), -6.0, 5, 6.0)  # steps back down on the far side


# ---------------------------------------------------------------------------
# WALL RUN: zigzag panels across a pit, start and end platforms; the long wall
# on the north edge of the lane is for long straight runs.

const WALL_PANELS := [   ## [x from, x to, z of the panel centre]. Faces are 4 m apart.
	[50.0, 66.0, -12.5],    # starts beside the start platform: run along it and jump
	[64.0, 76.0, -7.5],
	[74.0, 86.0, -12.5],
	[84.0, 96.0, -7.5],
]
const WALL_START := Vector3(52.5, 2.5, -10.0)   ## top centre of the start platform

func _wall_lane() -> void:
	var z := LANE_WALL
	_sign(Vector3(43, 7, z), "WALL RUN", FACE_WEST, 110, "Run along the wall, jump and hold forward.\nJump to kick off toward the next wall.")
	_ramp(Vector3(44, 0, z), Vector3(50, 2.5, z), 4)
	_box(Vector3(52.5, 1.25, z), Vector3(5, 2.5, 4), "pad")   # start platform (x 50-55, z -12 to -8), 2.5 m up
	_decal(Vector3(77, 0.01, z), Vector3(44, 0.02, 12), "pit")
	for p in WALL_PANELS:
		_box(Vector3((p[0] + p[1]) * 0.5, 4.0, p[2]), Vector3(p[1] - p[0], 8.0, 1.0), "wallrun")
	_box(Vector3(103, 2.0, z), Vector3(10, 4.0, 6), "pad")    # end platform (x 98-108), 4 m up
	_sign(Vector3(97.9, 5.5, z), "FINISH", FACE_WEST, 96)
	# Long straight wall along the north edge of the lane (both sides usable)
	_box(Vector3(76, 4.0, -19.5), Vector3(40, 8.0, 1.0), "wallrun")


# ---------------------------------------------------------------------------
# SLIDE: steps up to a hill, slide down, under three bars, off a kicker

const SLIDE_BARS := [80.0, 86.0, 92.0]   ## x of each bar to slide under
const SLIDE_BAR_GAP := 1.4               ## clear height under the bars
const SLIDE_HILL := 4.8                  ## height of the hill top

func _slide_lane() -> void:
	var z := LANE_SLIDE
	_sign(Vector3(43, 8, z), "SLIDE", FACE_WEST, 110, "Sprint, then crouch (Ctrl) to slide.\nSlide down the hill and under the bars.")
	_steps(Vector3(44, 0, z), 5.0, 4, SLIDE_HILL)
	_box(Vector3(50.5, SLIDE_HILL * 0.5, z), Vector3(3, SLIDE_HILL, 10), "pad")   # top of the hill (x 49-52)
	_ramp(Vector3(72, 0, z), Vector3(52, SLIDE_HILL, z), 10)    # downhill toward the east, about 14 degrees
	for x in SLIDE_BARS:
		_box(Vector3(x, SLIDE_BAR_GAP + 0.3, z), Vector3(0.6, 0.6, 10), "slide")
		for side in [-1, 1]:
			_box(Vector3(x, SLIDE_BAR_GAP * 0.5, z + side * 5.25), Vector3(0.5, SLIDE_BAR_GAP, 0.5), "pillar")
	_ramp(Vector3(98, 0, z), Vector3(104, 1.5, z), 8)            # kicker: slide-jump off it
	# Distance marks every 5 m from the bottom of the hill
	for i in 7:
		_decal(Vector3(72 + i * 5, 0.01, z), Vector3(0.25, 0.02, 10), "stripe")


# ---------------------------------------------------------------------------
# VAULT / CLIMB: a row of obstacles at marked heights, and a wall-jump chimney

const VAULT_HEIGHTS := [0.5, 0.75, 1.0, 1.25]    ## you vault these at a run
const LEDGE_HEIGHTS := [1.6, 2.4, 3.2, 3.8]      ## jump and hold forward to climb (3.8 is too high)
const LEDGE_TOO_HIGH := 3.5                      ## above this, a running jump can't reach the ledge
const CHIMNEY_TOP := 12.0

func _vault_lane() -> void:
	var z := 26.0
	_sign(Vector3(43, 6, z), "VAULT + CLIMB", FACE_WEST, 110, "Run into low blocks to vault them.\nJump at higher ledges and hold forward to climb.")
	var x := 50.0
	for h in VAULT_HEIGHTS:
		_box(Vector3(x, h * 0.5, z), Vector3(1.0, h, 5), "vault")
		_sign(Vector3(x - 0.55, h + 0.5, z), "%.2f m" % h, FACE_WEST, 48)
		x += 6.0
	for h in LEDGE_HEIGHTS:
		_box(Vector3(x, h * 0.5, z), Vector3(2.0, h, 5), "vault")
		_sign(Vector3(x - 1.05, h + 0.5, z), ("%.1f m" % h) + ("\ntoo high" if h > LEDGE_TOO_HIGH else ""), FACE_WEST, 48)
		x += 6.0
	# Wall-jump chimney: two walls 3 m apart, open to the west. Jump back and
	# forth between them, then climb out onto the platform at the east end.
	var cz := 35.0
	_sign(Vector3(93, 14, cz), "WALL JUMP", FACE_WEST, 110, "Jump back and forth between the walls to climb.")
	for side in [-1, 1]:
		_box(Vector3(98, CHIMNEY_TOP * 0.5, cz + side * 2.0), Vector3(8, CHIMNEY_TOP, 1.0), "wallrun")
	_box(Vector3(106, (CHIMNEY_TOP - 1.5) * 0.5, cz), Vector3(8, CHIMNEY_TOP - 1.5, 6), "pad")   # platform 10.5 m up
	_sign(Vector3(102.2, CHIMNEY_TOP + 1.0, cz), "TOP", FACE_WEST, 96)


# ---------------------------------------------------------------------------
# GAP JUMPS: platforms 2 m up with gaps of 6, 10 and 13 m. The first needs a
# sprinting jump, the second a jump then a dive, the third a jump, a flip and a dive.

const GAP_Z := 35.0
const GAP_HEIGHT := 2.0
const GAP_PLATFORMS := [   ## [x from, x to]
	[46.0, 52.0],
	[58.0, 61.0],   # 6 m gap: jump
	[71.0, 74.0],   # 10 m gap: jump + dive
	[87.0, 90.0],   # 13 m gap: jump + flip + dive
]
const GAP_HINTS := ["", "JUMP", "JUMP + DIVE", "JUMP + FLIP + DIVE"]

func _gap_lane() -> void:
	var z := GAP_Z
	_sign(Vector3(44.5, 8.5, z), "GAP JUMPS", FACE_WEST, 110, "Q dives toward where you look.\nJump again in mid-air to flip toward your WASD direction.")
	_ramp(Vector3(42, 0, z), Vector3(46, GAP_HEIGHT, z), 4)
	_decal(Vector3(71.5, 0.01, z), Vector3(35, 0.02, 4), "pit")
	for i in GAP_PLATFORMS.size():
		var p: Array = GAP_PLATFORMS[i]
		_box(Vector3((p[0] + p[1]) * 0.5, GAP_HEIGHT * 0.5, z), Vector3(p[1] - p[0], GAP_HEIGHT, 4), "pad")
		if GAP_HINTS[i] != "":
			var gap: float = p[0] - GAP_PLATFORMS[i - 1][1]
			_sign(Vector3(p[0] - gap * 0.5, GAP_HEIGHT + 3.0, z), "%s\n%d m" % [GAP_HINTS[i], int(gap)], FACE_WEST, 56)


# ---------------------------------------------------------------------------

func _spawns() -> void:
	# Around the edge of the arena part, facing the middle
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var pos := Vector3(sin(a), 0, cos(a)) * 34.0 + Vector3(0, 0.2, 0)
		if abs(pos.x) > 20 and abs(pos.z) > 20:
			pos *= 0.55  # stay off the corner decks
		spawns.append([pos, a])


## A staircase of blocks you vault up, each `rise` higher. Starts at `start`
## (ground level) and runs along x by `run` metres in total.
func _steps(start: Vector3, run: float, count: int, top: float) -> void:
	var depth := run / count
	for i in count:
		var h := top * (i + 1) / count
		_box(Vector3(start.x + depth * (i + 0.5), h * 0.5, start.z), Vector3(abs(depth), h, 4), "block")


func _box(center: Vector3, size: Vector3, kind: String) -> void:
	pieces.append({"xf": Transform3D(Basis(), center), "size": size, "kind": kind, "solid": true})


## Paint on the floor: drawn but not solid, so it never trips you.
func _decal(center: Vector3, size: Vector3, kind: String) -> void:
	pieces.append({"xf": Transform3D(Basis(), center), "size": size, "kind": kind, "solid": false})


func _sign(pos: Vector3, text: String, yaw: float, size: int = 72, help: String = "") -> void:
	signs.append({"pos": pos, "text": text, "yaw": yaw, "size": size})
	if help != "":
		signs.append({"pos": pos - Vector3(0, 1.1, 0), "text": help, "yaw": yaw, "size": 40})


## A slab from `low` up to `high` (both are centres of the walking surface).
func _ramp(low: Vector3, high: Vector3, width: float) -> void:
	_slab(low, high, width, 0.5, "ramp")


func _beam(a: Vector3, b: Vector3, width: float) -> void:
	_slab(a, b, width, 0.6, "bridge")


func _slab(a: Vector3, b: Vector3, width: float, thickness: float, kind: String) -> void:
	var dir := b - a
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var center := (a + b) * 0.5 - basis.y * (thickness * 0.5)
	pieces.append({"xf": Transform3D(basis, center), "size": Vector3(width, thickness, dir.length()), "kind": kind, "solid": true})


## Adds the level's collision (and, if `materials` is given, its meshes) under `parent`.
func instantiate(parent: Node3D, materials: Dictionary = {}) -> void:
	for piece in pieces:
		var body: Node3D
		if piece.solid:
			body = StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = piece.size
			shape.shape = box
			body.add_child(shape)
		else:
			body = Node3D.new()
		body.transform = piece.xf
		if not materials.is_empty():
			var mesh := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = piece.size
			mesh.mesh = bm
			mesh.material_override = materials[piece.kind]
			body.add_child(mesh)
		parent.add_child(body)
	if materials.is_empty():
		return
	for s in signs:
		var label := Label3D.new()
		label.text = s.text
		label.font_size = s.size
		label.pixel_size = 0.01
		label.outline_size = 12
		label.modulate = Color(1, 1, 1)
		label.outline_modulate = Color(0.05, 0.05, 0.08)
		label.position = s.pos
		label.rotation.y = s.yaw
		label.double_sided = false
		parent.add_child(label)
