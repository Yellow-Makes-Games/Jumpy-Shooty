class_name GreyboxLayout
extends RefCounted
## The phase 0 test arena, built from boxes. It exists so we can move around and
## test sync with several levels, ramps, tall walls and gaps. The real arena is
## designed in phase 2, around the full movement set and your chosen theme.

## Each piece: { "xf": Transform3D (centre), "size": Vector3, "kind": String }
var pieces: Array = []
var spawns: Array = []   ## Array of [Vector3 position, float yaw]

const HALF := 40.0       ## arena is 80 x 80 m
const WALL_H := 14.0


func build() -> GreyboxLayout:
	# Floor and perimeter walls (tall enough to wall-run along later)
	_box(Vector3(0, -0.5, 0), Vector3(HALF * 2, 1, HALF * 2), "floor")
	_box(Vector3(0, WALL_H / 2, -HALF), Vector3(HALF * 2, WALL_H, 1), "wall")
	_box(Vector3(0, WALL_H / 2, HALF), Vector3(HALF * 2, WALL_H, 1), "wall")
	_box(Vector3(-HALF, WALL_H / 2, 0), Vector3(1, WALL_H, HALF * 2), "wall")
	_box(Vector3(HALF, WALL_H / 2, 0), Vector3(1, WALL_H, HALF * 2), "wall")

	# Central tower: a 12 x 12 platform 6 m up, with two ramps
	_box(Vector3(0, 3, 0), Vector3(12, 6, 12), "block")
	_ramp(Vector3(0, 0, 20), Vector3(0, 6, 6), 5)
	_ramp(Vector3(0, 0, -20), Vector3(0, 6, -6), 5)
	# Low cover on the tower top
	_box(Vector3(-3.5, 6.6, 0), Vector3(1, 1.2, 4), "cover")
	_box(Vector3(3.5, 6.6, 0), Vector3(1, 1.2, 4), "cover")

	# Four corner decks, 4 m up, each with a ramp
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var c := Vector3(sx * 28, 2, sz * 28)
			_box(c, Vector3(14, 4, 14), "block")
			_ramp(Vector3(sx * 28, 0, sz * 12), Vector3(sx * 28, 4, sz * 21), 4)
			# Bridge rising from each deck toward the tower, ending in a gap to jump
			var start := Vector3(sx * 22, 4, sz * 22)
			var end := Vector3(sx * 9, 6, sz * 9)
			_beam(start, end, 2.5)

	# Free-standing walls for wall-running and cover on the main floor
	_box(Vector3(-18, 3, 0), Vector3(1, 6, 18), "wall")
	_box(Vector3(18, 3, 0), Vector3(1, 6, 18), "wall")
	_box(Vector3(0, 2.5, -30), Vector3(16, 5, 1), "wall")
	_box(Vector3(0, 2.5, 30), Vector3(16, 5, 1), "wall")

	# Pillars and crates
	for p in [Vector3(-10, 0, 12), Vector3(10, 0, -12), Vector3(-12, 0, -10), Vector3(12, 0, 10)]:
		_box(p + Vector3(0, 4, 0), Vector3(2, 8, 2), "pillar")
	for p in [Vector3(-26, 0, 6), Vector3(26, 0, -6), Vector3(6, 0, 26), Vector3(-6, 0, -26), Vector3(-34, 0, -2), Vector3(34, 0, 2)]:
		_box(p + Vector3(0, 0.75, 0), Vector3(2.5, 1.5, 2.5), "cover")

	# Spawn points around the edge, facing the middle
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var pos := Vector3(sin(a), 0, cos(a)) * 34.0 + Vector3(0, 0.2, 0)
		if abs(pos.x) > 20 and abs(pos.z) > 20:
			pos *= 0.55  # stay off the corner decks
		spawns.append([pos, a])
	return self


func _box(center: Vector3, size: Vector3, kind: String) -> void:
	pieces.append({"xf": Transform3D(Basis(), center), "size": size, "kind": kind})


## A slab from `low` up to `high` (both are centres of the walking surface).
func _ramp(low: Vector3, high: Vector3, width: float) -> void:
	_slab(low, high, width, 0.5, "ramp")


func _beam(a: Vector3, b: Vector3, width: float) -> void:
	_slab(a, b, width, 0.6, "bridge")


func _slab(a: Vector3, b: Vector3, width: float, thickness: float, kind: String) -> void:
	var dir := b - a
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	var center := (a + b) * 0.5 - basis.y * (thickness * 0.5)
	pieces.append({"xf": Transform3D(basis, center), "size": Vector3(width, thickness, dir.length()), "kind": kind})
