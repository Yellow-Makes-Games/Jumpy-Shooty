extends SceneTree
## Pilot: rebuilds one Empyrean Tower tier's floors and ramps with the curved block shapes.
##  - Each floor ring (Floor, Storey, Balcony, UpperFloor) was a box per 15 degree sector,
##    its outer face flat at the ring's outside radius and its inner face flat at the
##    inside one. A run of neighbouring sectors with the same radii, top and thickness
##    becomes one tube slice (Arc) whose corners fall on the sector lines: the same
##    outline, without the boxes' overlaps poking into the shaft.
##  - Each curved ramp (SpiralA, SpiralB, UpA, UpB) was a level landing at each end and
##    straight slabs of 7.5 degrees or less between. The landings stay; the slabs become one
##    Spiral block (Slab style) over the same radii, angles and heights, in as many pieces.
##
##   godot --headless --path . --script tools/arena/empyrean_curved_pilot.gd -- --tier=1 [--out=res://...] [--write]
##
## Without --write or --out it only says what it would do. It edits the scene as text: the
## old blocks' sections go, the new blocks' sections stand where the first of them stood.

const SCENE := "res://game/maps/empyrean.tscn"
const NAMES := ["ArcaneEngine", "GrandLibrary", "AlchemyLabs", "Menagerie", "SummoningChamber", "Observatory"]
const TIER := 30.5
const TOP := 183.0
const SEC := 24
const L3 := 19.0
const LANE := 2.6
const STEP := 15.0          # degrees a floor sector
const RING_PREFIXES := ["Floor", "Storey1", "Storey2", "Balcony1", "Balcony2", "UpperFloor"]

var map: Node
var tier := 1
var removed := {}      # node path -> true
var added := {}        # node path of the first block it replaces -> [section lines]
var stats := {"floor boxes": 0, "floor slices": 0, "ramp slabs": 0, "spirals": 0}


func _init() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			tier = a.trim_prefix("--tier=").to_int()
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--write":
			out = SCENE
	map = (load(SCENE) as PackedScene).instantiate()
	var t: Node = map.get_node(NAMES[tier])
	_floors(t.get_node("Floors"))
	_ramps(t.get_node("Ramps"))
	print("%s: %d floor boxes into %d slices, %d ramp slabs into %d spirals: %d blocks fewer" % [NAMES[tier],
		stats["floor boxes"], stats["floor slices"], stats["ramp slabs"], stats["spirals"],
		stats["floor boxes"] + stats["ramp slabs"] - stats["floor slices"] - stats["spirals"]])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(_rewrite(FileAccess.get_file_as_string(SCENE)))
		f.close()
		print("  written to %s" % out)
	map.free()
	quit()


# ---------------------------------------------------------------------------
# The tower's numbers (as tools/arena/empyrean.py has them)

static func ro(y: float) -> float:
	return 30.5 - (30.5 - 20.0) * (y / TOP)


static func ri(y: float) -> float:
	return ro(y) - 1.0


static func rc(i: int) -> float:
	return ri(TIER * (i + 1)) - 5.2


static func chord(r: float) -> float:
	return 2.0 * r * tan(PI / SEC)


# ---------------------------------------------------------------------------
# Floors

func _floors(g: Node) -> void:
	var runs := {}    # [prefix, kind, top, thick, r0, r1] -> {sector: block}
	for b in g.get_children():
		var block := b as MapBlock
		if block == null or block.shape != MapBlock.Shape.BOX or not block.solid or not block.drawn or block.breakable:
			continue
		var prefix := String(block.name).rstrip("0123456789")
		if prefix not in RING_PREFIXES:
			continue
		var xf := block.transform
		var flat := Vector3(xf.origin.x, 0, xf.origin.z)
		var deg := fposmod(rad_to_deg(atan2(flat.x, flat.z)), 360.0)
		var k := roundi(deg / STEP - 0.5)
		if absf(deg - (k + 0.5) * STEP) > 0.05 or (xf.basis.z.normalized() - flat.normalized()).length() > 0.002:
			continue   # not a sector slab square to its radius
		var rm := flat.length()
		var r0 := rm - block.size.z * 0.5
		var r1 := rm + block.size.z * 0.5
		if absf(block.size.x - (chord(r1) + 0.02)) > 0.05:
			continue
		var key := [prefix, block.kind, snappedf(xf.origin.y + block.size.y * 0.5, 0.001), snappedf(block.size.y, 0.001), snappedf(r0, 0.01), snappedf(r1, 0.01)]
		if not runs.has(key):
			runs[key] = {}
		runs[key][posmod(k, SEC)] = block
	for key in runs:
		var by_sector: Dictionary = runs[key]
		for run in _consecutive(by_sector.keys()):
			if run.size() < 2:
				continue   # (a lone sector stays a box)
			var blocks: Array = run.map(func(k): return by_sector[k])
			_floor_slice(g, key, run, blocks)


## The sectors in runs of neighbours, round the ring (23 is beside 0).
static func _consecutive(sectors: Array) -> Array:
	var have := {}
	for k in sectors:
		have[k] = true
	if have.size() == SEC:
		var all := []
		for k in SEC:
			all.append(k)
		return [all]
	var runs := []
	for k in have:
		if have.has(posmod(k - 1, SEC)):
			continue   # (not the start of a run)
		var run := [k]
		while have.has(posmod(run[-1] + 1, SEC)):
			run.append(posmod(run[-1] + 1, SEC))
		runs.append(run)
	return runs


func _floor_slice(g: Node, key: Array, run: Array, blocks: Array) -> void:
	var count := run.size()
	var arc := STEP * count
	var top: float = key[2]
	var thick: float = key[3]
	var stretch := 1.0 / cos(PI / SEC)   # (a polygon's corners lie this much further out than its flat sides)
	var turn: float = 0.0 if count == SEC else run[0] * STEP + arc * 0.5 + 180.0
	var lines := _header("%sArc" % key[0], g, blocks)
	lines.append(_transform(Basis(Vector3.UP, deg_to_rad(turn)), Vector3(0, top - thick * 0.5, 0)))
	lines.append_array(["script = ExtResource(\"2_block\")", "shape = 2",
		"size = Vector3(%s, %s, %s)" % [_n(2.0 * key[5] * stretch), _n(thick), _n(2.0 * key[5] * stretch)],
		"kind = \"%s\"" % key[1], "sides = %d" % count, "inner = %s" % _n(2.0 * key[4] * stretch)])
	if count < SEC:
		lines.append("arc = %s" % _n(arc))
	_replace(blocks, lines)
	stats["floor boxes"] += blocks.size()
	stats["floor slices"] += 1


# ---------------------------------------------------------------------------
# Ramps

func _ramps(g: Node) -> void:
	var y0 := TIER * tier
	var Rc := rc(tier)
	var Rw := ri(y0 + TIER)
	var spans := [[0.0, 6.35], [6.35, 12.7], [12.7, L3]]
	var made := {}
	for n in 3:
		_ramp(g, "SpiralA", Rc + LANE + 0.1, Rw, 150.0 + n * 30.0, 180.0 + n * 30.0, y0 + spans[n][0], y0 + spans[n][1], made)
		_ramp(g, "SpiralB", Rc + LANE + 0.1, Rw, 360.0 - n * 30.0, 330.0 - n * 30.0, y0 + spans[n][0], y0 + spans[n][1], made)
	var nxt := [rc(tier + 1) - 3.4, rc(tier + 1) - 0.6]
	_ramp(g, "UpA", nxt[0], nxt[1], 150.0, 240.0, y0 + L3, y0 + TIER, made)
	_ramp(g, "UpB", nxt[0], nxt[1], 360.0, 270.0, y0 + L3, y0 + TIER, made)


## One curved ramp (as empyrean.py's curved_ramp): its straight slabs, between its two
## level landings, become one spiral.
func _ramp(g: Node, name: String, r0: float, r1: float, deg0: float, deg1: float, y0: float, y1: float, made: Dictionary) -> void:
	var way := 1.0 if deg1 > deg0 else -1.0
	var a := deg0 + way * 3.0
	var b := deg1 - way * 3.0
	var pieces := maxi(1, ceili(absf(b - a) / 7.5 - 1e-6))
	var rm := (r0 + r1) * 0.5
	# Its slabs: the ramp's blocks (not its landings) whose middles lie over its run.
	var slabs := []
	for c in g.get_children():
		var block := c as MapBlock
		if block == null or String(block.name).rstrip("0123456789") != name:
			continue
		var p := block.position
		var deg := rad_to_deg(atan2(p.x, p.z))
		var along := fposmod((deg - a) * way, 360.0)
		var r := Vector2(p.x, p.z).length()
		if along <= absf(b - a) and absf(r - rm) < 0.6 and p.y > y0 - 0.5 and p.y < y1 + 0.5:
			slabs.append(block)
	if slabs.size() != pieces:
		push_error("%s from %.0f degrees: expected %d slabs, found %d; left as it is" % [name, deg0, pieces, slabs.size()])
		return
	var arc := absf(b - a)
	var rise := y1 - y0
	var slope := atan2(rise, deg_to_rad(arc) * rm)
	var thick := 0.4 / cos(slope)   # (the slabs were 0.4 thick square to their slope; a spiral's is upright)
	var middle := (a + b) * 0.5
	made[name] = made.get(name, 0) + 1
	var lines := _header(name if made[name] == 1 else "%s%d" % [name, made[name]], g, slabs)
	lines.append(_transform(Basis(Vector3.UP, deg_to_rad(middle + 180.0)), Vector3(0, (y0 - thick + y1) * 0.5, 0)))
	lines.append_array(["script = ExtResource(\"2_block\")", "shape = 9",
		"size = Vector3(%s, %s, %s)" % [_n(2.0 * r1), _n(rise + thick), _n(2.0 * r1)],
		"kind = \"ramp\"", "sides = %d" % pieces, "inner = %s" % _n(2.0 * r0), "arc = %s" % _n(arc),
		"step_style = 1", "thickness = %s" % _n(thick)])
	if way < 0.0:
		lines.append("clockwise = true")   # (empyrean.py's angles go anticlockwise seen from above)
	_replace(slabs, lines)
	stats["ramp slabs"] += slabs.size()
	stats["spirals"] += 1


# ---------------------------------------------------------------------------
# Writing

func _header(name: String, g: Node, blocks: Array) -> PackedStringArray:
	var taken := {}
	for c in g.get_children():
		if not removed.has(_path(c)) and c not in blocks:
			taken[String(c.name)] = true
	for lines: PackedStringArray in added.values():
		taken[lines[0].get_slice("\"", 1)] = true
	var unique := name
	var i := 2
	while taken.has(unique):
		unique = "%s%d" % [name, i]
		i += 1
	return PackedStringArray(["[node name=\"%s\" type=\"Node3D\" parent=\"%s\"]" % [unique, _path(g)]])


func _replace(blocks: Array, lines: PackedStringArray) -> void:
	lines.append("")
	added[_path(blocks[0])] = lines
	for b in blocks:
		removed[_path(b)] = true


func _path(n: Node) -> String:
	return String(map.get_path_to(n))


func _transform(basis: Basis, at: Vector3) -> String:
	var v := [basis.x.x, basis.y.x, basis.z.x, basis.x.y, basis.y.y, basis.z.y, basis.x.z, basis.y.z, basis.z.z, at.x, at.y, at.z]
	return "transform = Transform3D(%s)" % ", ".join(v.map(func(x): return _n(x)))


static func _n(v: float) -> String:
	var s := String.num(snappedf(v, 0.0001), 4)
	return "0" if s == "-0" else s


func _rewrite(text: String) -> String:
	var newline := "\r\n" if text.contains("\r\n") else "\n"
	var lines := text.split(newline)
	var out := PackedStringArray()
	var i := 0
	while i < lines.size():
		var at := _section_path(lines[i])
		if at == "" or not removed.has(at):
			out.append(lines[i])
			i += 1
			continue
		if added.has(at):
			out.append_array(added[at])
		i += 1
		while i < lines.size() and not lines[i].begins_with("["):
			i += 1
	return newline.join(out)


static func _section_path(line: String) -> String:
	if not line.begins_with("[node ") or not line.contains(" parent=\""):
		return ""
	var name := line.get_slice("name=\"", 1).get_slice("\"", 0)
	var parent := line.get_slice("parent=\"", 1).get_slice("\"", 0)
	return name if parent == "." else parent + "/" + name
