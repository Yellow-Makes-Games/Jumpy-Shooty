class_name Accessories
extends RefCounted
## The Character Creator's hats, glasses, neckwear, shoulder, back and waist pieces
## and tails, modelled in code in the same low-poly, flat-shaded style as the bodies.
##
## Each one is built in the body's rest pose (standing, facing -Z) around the body
## it is going on, from a few measurements of that body (see `fit`): where the top
## of the head is, how wide it is, where the eyes, the chest and the waist are. Every
## triangle follows one bone (the head, the chest or the hips), the same as the
## bodies' own parts, so they move with the body, a hat disappears with the head in
## first person, and nothing else about the character needs to know they are there.
##
## To add one: write its `_ID()` function here and list it in
## CustomCharacter.ACCESSORIES.

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
	"red": {"color": Color(0.80, 0.10, 0.10), "metallic": 0.0, "roughness": 0.6},
	"orange": {"color": Color(0.96, 0.45, 0.08), "metallic": 0.0, "roughness": 0.6},
	"hazard": {"color": Color(0.98, 0.80, 0.10), "metallic": 0.0, "roughness": 0.5},
	"purple": {"color": Color(0.45, 0.20, 0.65), "metallic": 0.0, "roughness": 0.7},
	"pink": {"color": Color(0.96, 0.50, 0.68), "metallic": 0.0, "roughness": 0.6},
	"leaf": {"color": Color(0.26, 0.56, 0.20), "metallic": 0.0, "roughness": 0.8},
	"moss": {"color": Color(0.22, 0.40, 0.18), "metallic": 0.0, "roughness": 0.7},
	"straw": {"color": Color(0.87, 0.73, 0.36), "metallic": 0.0, "roughness": 0.95},
	"wood": {"color": Color(0.50, 0.32, 0.16), "metallic": 0.0, "roughness": 0.8},
	"pearl": {"color": Color(0.97, 0.95, 0.92), "metallic": 0.3, "roughness": 0.2},
	"redlens": {"color": Color(0.90, 0.12, 0.12), "metallic": 0.2, "roughness": 0.1},
	"bluelens": {"color": Color(0.10, 0.62, 0.92), "metallic": 0.2, "roughness": 0.1},
	# The sci-fi pieces' own: bright and dark metal, bone, a hooded robe's cloth, a
	# tinted lens, and their lights (LIGHTS: the player's trim colour on the body;
	# "hardlight" is see-through, for shields, blades and wings of light).
	"chrome": {"color": Color(0.80, 0.82, 0.86), "metallic": 0.45, "roughness": 0.18, "emission": Color(0.12, 0.13, 0.15), "energy": 0.3},
	"carbon": {"color": Color(0.13, 0.14, 0.16), "metallic": 0.25, "roughness": 0.45},
	"bone": {"color": Color(0.88, 0.84, 0.72), "metallic": 0.0, "roughness": 0.65},
	"robe": {"color": Color(0.34, 0.07, 0.07), "metallic": 0.0, "roughness": 0.85},
	"smoke": {"color": Color(0.08, 0.10, 0.14, 0.62), "metallic": 0.4, "roughness": 0.08, "alpha": true},
	"energy": {"color": Color(0.4, 0.85, 1.0), "metallic": 0.0, "roughness": 0.4, "emission": Color(0.4, 0.85, 1.0)},
	"hardlight": {"color": Color(0.4, 0.85, 1.0, 0.42), "metallic": 0.0, "roughness": 0.3, "emission": Color(0.4, 0.85, 1.0), "energy": 0.8, "alpha": true},
}
## Materials that light up in the player's trim colour (RobotModel), like the visors.
const LIGHTS := ["energy", "hardlight"]

## Which bone each slot's pieces follow.
const SLOT_BONE := {"hat": "head", "face": "head", "neck": "chest", "shoulder": "chest", "back": "chest", "waist": "hips", "tail": "hips"}

## The material an accessory's colour paints, where it is not simply the one most of
## it is made of.
const MAIN := {"jester": "purple", "shield": "accent", "drone": "steel",
	# The sci-fi pieces: the colour paints the body, never the lights.
	"cog_halo": "steel", "machine_cowl": "robe", "void_crest": "chrome", "netrunner_rig": "carbon",
	"plasma_mohawk": "steel", "warlord_crest": "steel", "blade_halo": "chrome", "skull_crown": "chrome",
	"hud_eyepiece": "carbon", "rebreather": "carbon", "holo_visor": "carbon", "optic_cluster": "carbon",
	"power_collar": "carbon", "comm_torque": "chrome", "cable_bundle": "carbon",
	"servo_skull": "bone", "mech_arm": "steel", "missile_pod": "steel", "sentinel": "chrome",
	"energy_wings": "steel", "space_cape": "silk", "antenna_mast": "steel", "gyro_ring": "steel",
	"cell_belt": "carbon", "thruster_skirt": "steel", "shield_belt": "steel",
	"robo_tail": "steel", "light_streamer": "chrome"}

## Accessories that do not simply follow their slot's bone (RobotModel rigs them):
##   cape:  the top on the chest, the bottom on a bone of its own that hangs from the
##          small of the back (never sticking out flat, never through the floor);
##   tail:  every tail, on a bone of its own at its root (kept off the floor);
##   skirt: on the hips at the waist, more and more on each thigh further down, so
##          the legs do not go through it.
const CAPE_BOTTOM := 0.68   ## how far down a cape hangs (its hem's height)
const RIGGED := {"cape": "cape", "space_cape": "cape", "tutu": "skirt", "grass_skirt": "skirt", "thruster_skirt": "skirt"}

## Hats that put something on the head but leave the crown bare: hair stays under
## these. The ear and horn hats also take the place of the head's own ears or horns.
const EAR_HATS := ["devil_horns", "antlers", "bunny_ears", "cat_ears", "unicorn"]
const OPEN_HATS := ["crown", "party", "halo", "headphones", "fez", "flower_crown",
	"devil_horns", "antlers", "bunny_ears", "cat_ears", "unicorn", "cog_halo", "blade_halo", "skull_crown", "netrunner_rig"]
## Hats that float clear of the head (above it, or behind): its thin bits stay.
const FLOATING_HATS := ["halo", "cog_halo", "blade_halo"]
## How wide and deep (half of each) a hat is fitted, whatever the head: a hat on the
## slimmest head is not a thimble, nor on the widest a tent.
const HAT_HALF := Vector2(0.1, 0.175)

## The heads that the measurements alone get wrong, by part id (see Characters).
##   hat:  measurements the hats use instead (top, w, d, cz): where a hat sits, when
##         that is not on the top of the head's shell (on Rivet's hard hat, on top of
##         Orbit's rings, behind the Frog's eyes).
##   face: measurements the glasses and faces use instead: eye_y, eye_z (the front of
##         the eyes), lens_x (how far out each lens is), w, d, cz, front, and
##         mouth_y / mouth_z (where a mustache, a beard or a lollipop goes: out on a
##         snout or a beak) and nose_y / nose_z (a clown nose).
##   thin: the thin bits on top of the head (antennas, stems, crests, fins, tufts),
##         hidden under any hat but the halo.
##   hair: the hair on top, hidden under hats that cover the crown (not OPEN_HATS).
##   ears: its own ears or horns, hidden under the ear and horn hats (EAR_HATS).
## Each of thin, hair and ears is a list of filters: a triangle of the head goes if it
## is of material `m` and its middle is above `y`, behind `z` (z larger) and at
## least `x` out to the side (any of y, z, x left out: anywhere).
const HEADS := {
	"needle": {"thin": [{"m": "detail", "y": 1.79}, {"m": "accent", "y": 1.79}]},
	"vanguard": {"thin": [{"m": "accent", "y": 1.77}]},
	"kestrel": {"thin": [{"m": "accent", "y": 1.69, "z": 0.0}]},
	"rivet": {"hat": {"top": 1.815, "w": 0.14, "d": 0.15, "cz": -0.02}},
	"orbit": {"hat": {"top": 1.78, "w": 0.12, "d": 0.12, "cz": 0.0, "floor": 1.735},
		"face": {"eye_z": -0.078, "w": 0.078, "d": 0.078, "front": -0.078, "cz": 0.0, "mouth_y": 1.585, "mouth_z": -0.06, "nose_y": 1.62, "nose_z": -0.07}},
	"human": {"hair": [{"m": "hair_brown", "y": 1.77}]},
	"goblin": {"thin": [{"m": "hair_black", "y": 1.74}], "ears": [{"m": "flesh_goblin", "x": 0.12}]},
	"frog": {"hat": {"top": 1.725, "w": 0.15, "d": 0.075, "cz": 0.055, "front": -0.03},
		"face": {"eye_y": 1.715, "eye_z": -0.115, "lens_x": 0.09, "mouth_z": -0.175, "nose_y": 1.64, "nose_z": -0.165}},
	"cat": {"ears": [{"m": "extra_cat", "y": 1.7}, {"m": "pink", "y": 1.7}]},
	"rex": {"thin": [{"m": "accent", "y": 1.72}],
		"face": {"eye_y": 1.705, "eye_z": -0.12, "lens_x": 0.085, "w": 0.118, "mouth_y": 1.625, "mouth_z": -0.3, "nose_y": 1.69, "nose_z": -0.3}},
	"yeti": {"ears": [{"m": "mark_horn", "y": 1.72}]},
	"duck": {"thin": [{"m": "extra_duck", "y": 1.76}],
		"face": {"mouth_y": 1.645, "mouth_z": -0.135, "nose_y": 1.63, "nose_z": -0.245}},
	"jack": {"thin": [{"m": "stem", "y": 1.76}]},
	"astronaut": {"thin": [{"m": "accent", "y": 1.85}, {"m": "trim_detail", "y": 1.85}]},
	"imp": {"ears": [{"m": "mark_horn", "y": 1.73}, {"m": "flesh_imp", "x": 0.11}]},
	"shark": {"face": {"eye_y": 1.695, "eye_z": -0.115, "lens_x": 0.085, "w": 0.12, "mouth_y": 1.62, "mouth_z": -0.31, "nose_y": 1.68, "nose_z": -0.31}},
	"zombie": {"thin": [{"m": "brain", "y": 1.73}], "hair": [{"m": "hair_black", "y": 1.74}]},
	"wizard": {"hair": [{"m": "hair_white", "y": 1.74}]},
	"bear": {"ears": [{"m": "extra_bear", "y": 1.72}]},
	"mushroom": {"face": {"eye_y": 1.59, "eye_z": -0.105, "w": 0.1, "d": 0.1, "cz": 0.0, "front": -0.105, "bottom": 1.47, "top": 1.63}},
	"banana": {"thin": [{"m": "wood", "y": 1.8}]},
}
## Legs with a tail of their own, which a tail accessory takes the place of: filters
## (as in HEADS) on the hips' triangles.
const TAILS := {
	"cat": [{"m": "extra_cat", "z": 0.1}, {"m": "trim_white", "z": 0.1}],
	"rex": [{"m": "extra_rex", "z": 0.1}, {"m": "accent", "z": 0.1}],
	"imp": [{"m": "flesh_imp", "z": 0.1}],
	"shark": [{"m": "extra_shark", "z": 0.1}],
}

static var _materials := {}

var _tris := {}            # material -> PackedVector3Array, three points a triangle
var _bone := "head"
var f := {}                # the body's measurements (see fit)


## Measurements of the body the pieces go on, from the triangles of its head and
## chest in the rest pose: `head_shell` (AABB of the head's shell, not its antennas),
## `visor` (AABB of the eyes or the face's glowing parts, if any), `chest` (AABB of the
## chest), `collar_front` (how far forward the chest is just under the neck, -Z) and
## `waist` (AABB of the top of the hips, where a belt goes).
static func fit(head_shell: AABB, visor: AABB, chest: AABB, collar_front: float,
		waist: AABB = AABB(Vector3(-0.14, 0.93, -0.1), Vector3(0.28, 0.12, 0.2))) -> Dictionary:
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
		"waist_y": clampf(waist.end.y - 0.05, 0.97, 1.03),
		"waist_w": maxf(waist.size.x * 0.5, 0.1), "waist_d": maxf(waist.size.z * 0.5, 0.08),
		"waist_cz": waist.get_center().z, "hip_back": waist.end.z,
	}


## Every piece for these accessories ({slot: id}), on a body measured by fit().
## tints: {slot: Color} paints that slot's accessory: its main material (the one most
## of it is made of, or MAIN's) comes out in that colour.
## Returns [{bone, material (name), points (PackedVector3Array, three a triangle),
## tint (a Color, on the painted pieces only)}].
## head: the head's part id, for its fitting (see HEADS).
static func build(picked: Dictionary, measurements: Dictionary, tints: Dictionary = {}, head: String = "") -> Array:
	var a := Accessories.new()
	var merged := {}   # [bone, material, tint] -> PackedVector3Array
	for slot in CustomCharacter.SLOTS:
		var id: String = picked.get(slot, "")
		if id == "":
			continue
		a.f = measured_for(slot, measurements, head)
		a._bone = "tail" if slot == "tail" else RIGGED.get(id, SLOT_BONE[slot])
		a._tris = {}
		var method := "_" + id
		if a.has_method(method):
			a.call(method)
		var main := main_material(id, a._tris) if tints.has(slot) else ""
		for m in a._tris:
			var key := [a._bone, m, tints[slot] if m == main else Color(0, 0, 0, 0)]
			if merged.has(key):
				# A packed array comes out of a dictionary as a copy: append to it and
				# put it back, or the second piece is lost.
				var points: PackedVector3Array = merged[key]
				points.append_array(a._tris[m])
				merged[key] = points
			else:
				merged[key] = a._tris[m]
	var out: Array = []
	for key in merged:
		var piece := {"bone": key[0], "material": key[1], "points": merged[key]}
		if key[2].a > 0.0:
			piece["tint"] = key[2]
		out.append(piece)
	return out


## Where the cape's and the tails' own bones turn (see RIGGED), on a body measured
## by fit(): the cape's at the small of the back, a tail's at its root.
static func pivot(bone: String, measurements: Dictionary) -> Vector3:
	var a := Accessories.new()
	a.f = measurements
	if bone == "cape":
		var top_y: float = a.f.neck_y - 0.01
		var y: float = a.f.chest_bottom
		var t := clampf((top_y - y) / (top_y - CAPE_BOTTOM), 0.0, 1.0)
		var back: float = maxf(a.f.chest_back, 0.1)
		return Vector3(0, y, lerpf(back * 0.55, back + 0.17, t * t * 0.7 + t * 0.3))
	return a._tail_root()


## The measurements one slot's accessory is fitted to: a hat's width kept in
## HAT_HALF, and the head's own fitting (HEADS) over the top.
static func measured_for(slot: String, measurements: Dictionary, head: String) -> Dictionary:
	var out := measurements.duplicate()
	var own: Dictionary = HEADS.get(head, {})
	if slot == "hat":
		out.w = clampf(out.w, HAT_HALF.x, HAT_HALF.y)
		out.d = clampf(out.d, HAT_HALF.x, HAT_HALF.y)
		out.merge(own.get("hat", {}), true)
	elif slot == "face":
		out.merge(own.get("face", {}), true)
		# A mustache's or a beard's line, and a clown nose: under the eyes, on the
		# face, unless the head puts them out on a snout or a beak.
		var fill := {
			"mouth_y": maxf(out.eye_y - 0.075, out.bottom + 0.025), "mouth_z": out.front,
			"nose_y": maxf(out.eye_y - 0.04, out.bottom + 0.05), "nose_z": minf(out.eye_z, out.front),
		}
		out.merge(fill, false)
	return out


## What of a body these accessories take the place of, by body region ("head",
## "legs"): filters (see HEADS) for the triangles to leave out.
static func hidden(picked: Dictionary, head: String, legs: String) -> Dictionary:
	var out := {"head": [], "legs": []}
	var hat: String = picked.get("hat", "")
	var own: Dictionary = HEADS.get(head, {})
	if hat != "" and hat not in FLOATING_HATS:
		out.head.append_array(own.get("thin", []))
	if hat != "" and hat not in OPEN_HATS:
		out.head.append_array(own.get("hair", []))
	if hat in EAR_HATS:
		out.head.append_array(own.get("ears", []))
	if picked.get("tail", "") != "":
		out.legs.append_array(TAILS.get(legs, []))
	return out


## Whether a triangle of `material` with its middle at `centre` is one of `filters`.
static func hides(filters: Array, material: String, centre: Vector3) -> bool:
	for rule: Dictionary in filters:
		if rule.m == material and centre.y >= rule.get("y", -INF) and centre.z >= rule.get("z", -INF) \
				and absf(centre.x) >= rule.get("x", 0.0):
			return true
	return false


## The part of an accessory its colour paints: MAIN's, or else the material that
## covers the most of it (by area: a small round bobble is many triangles).
static func main_material(id: String, tris: Dictionary) -> String:
	if MAIN.has(id) and tris.has(MAIN[id]):
		return MAIN[id]
	var best := ""
	var most := -1.0
	for m in tris:
		var points: PackedVector3Array = tris[m]
		var area := 0.0
		for i in range(0, points.size() - 2, 3):
			area += (points[i + 1] - points[i]).cross(points[i + 2] - points[i]).length()
		if area > most:
			most = area
			best = m
	return best


## The shared material for a kind of surface (see MATERIALS); tint: painted that
## colour (an accessory in a colour of its own). A painted material is named "tint",
## so nothing else recolours it.
static func material(kind: String, tint: Color = Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var key: Variant = kind if tint.a <= 0.0 else [kind, tint]
	if not _materials.has(key):
		var d: Dictionary = MATERIALS.get(kind, MATERIALS.armor)
		var m := StandardMaterial3D.new()
		m.resource_name = kind if tint.a <= 0.0 else "tint"
		m.albedo_color = d.color if tint.a <= 0.0 else Color(tint, d.color.a)
		m.metallic = d.metallic
		m.roughness = d.roughness
		m.cull_mode = BaseMaterial3D.CULL_DISABLED   # capes and brims are seen from both sides
		if d.get("alpha", false):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if d.has("emission"):
			m.emission_enabled = true
			m.emission = d.emission if tint.a <= 0.0 else Color(tint.r, tint.g, tint.b) * (d.emission.get_luminance() / maxf(tint.get_luminance(), 0.2))
			m.emission_energy_multiplier = d.get("energy", 1.4)
		_materials[key] = m
	return _materials[key]


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


## A cone from the middle of its base to its tip, whichever way that points.
func _cone(m: String, base: Vector3, tip: Vector3, r: float, n: int = 6, squash: float = 1.0) -> void:
	var dir := (tip - base).normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var ring: Array = []
	for j in n:
		var a := j * TAU / n
		ring.append(base + (side * cos(a) + up * sin(a) * squash) * r)
	for j in n:
		_tri(m, ring[j], ring[(j + 1) % n], tip, base)
	for j in range(1, n - 1):
		_tri(m, ring[0], ring[j], ring[j + 1], tip)


## A tube along a path of points, with a radius for each point.
func _tube_r(m: String, path: Array, radii: Array, n: int = 6) -> void:
	var rings: Array = []
	for i in path.size():
		var p: Vector3 = path[i]
		var dir: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(dir).normalized()
		var r: float = maxf(radii[i], 0.001)
		var ring: Array = []
		for j in n:
			var a := j * TAU / n
			ring.append(p + (side * cos(a) + up * sin(a)) * r)
		rings.append(ring)
	_loft(m, rings)


## A flat plate: `pts` go round its edge (every one in sight of its middle), and it
## is `thick` deep along `out`.
func _plate(m: String, pts: Array, thick: float, out: Vector3) -> void:
	var back := out.normalized() * thick
	var c := _mean(pts)
	var mid := c + back * 0.5
	for j in pts.size():
		var a: Vector3 = pts[j]
		var b: Vector3 = pts[(j + 1) % pts.size()]
		_tri(m, c, a, b, mid)
		_tri(m, c + back, a + back, b + back, mid)
		_tri(m, a, b, b + back, mid)
		_tri(m, a, b + back, a + back, mid)


## A dome: half a ball of rings, w across, d front to back, h tall, its rim at y.
func _dome(m: String, w: float, d: float, y: float, h: float, cz: float, n: int = 14, rows: int = 5) -> void:
	var rings: Array = []
	for k in rows:
		var a := k / float(rows - 1) * PI * 0.5
		rings.append(_ellipse(n, w * cos(a) + 0.003, d * cos(a) + 0.003, y + h * sin(a), 0, cz))
	_loft(m, rings)


## A band round an ellipse: a short open-ended wall, `tall` high and `thick` out from it.
func _band(m: String, rx: float, rz: float, y: float, tall: float, thick: float = 0.01, cz: float = 0.0, n: int = 16) -> void:
	_loft(m, [_ellipse(n, rx + thick, rz + thick, y - tall * 0.5, 0, cz), _ellipse(n, rx + thick, rz + thick, y + tall * 0.5, 0, cz)])


## A basis whose Y axis points along `dir` (for standing a cylinder that way).
func _along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized())


# ---------------------------------------------------------------------------
# Hats. On the head bone, sitting on the top of the head's shell.

## The height a hat's rim sits at, `drop` below the top of the head (or, on a head
## that says so, no lower than its floor: Orbit's hats stay above its rings).
func _rim(drop: float) -> float:
	return maxf(f.top - drop, f.get("floor", -INF))


func _top_hat() -> void:
	var y: float = _rim(0.015)
	var w: float = f.w
	var d: float = f.d
	var cz: float = f.cz
	_loft("silk", [_ellipse(14, w * 1.5, d * 1.5, y, 0, cz), _ellipse(14, w * 1.5, d * 1.5, y + 0.014, 0, cz)])
	_loft("silk", [_ellipse(14, w * 0.86, d * 0.86, y, 0, cz), _ellipse(14, w * 0.92, d * 0.92, y + 0.25, 0, cz)])
	_loft("accent", [_ellipse(14, w * 0.875, d * 0.875, y + 0.015, 0, cz), _ellipse(14, w * 0.885, d * 0.885, y + 0.055, 0, cz)])


func _cowboy() -> void:
	var y: float = _rim(0.025)
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
	var y: float = _rim(0.02)
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
	var y: float = _rim(0.07)
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
	var y: float = _rim(0.02)
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
	var y: float = _rim(0.08)
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
	for side: float in [-1.0, 1.0]:
		var path: Array = []
		for k in 7:
			var t := k / 6.0
			path.append(Vector3(side * (w * 0.85 + 0.14 * t), y + 0.05 + 0.03 * t + 0.16 * t * t, cz - 0.03 * t))
		_tube("horn", path, 0.034, 0.004, 7)


func _party() -> void:
	var y: float = _rim(0.02)
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
	for side: float in [-1.0, 1.0]:
		_cyl("joint", Vector3(side * (w + 0.015), mid, f.cz), 0.062, 0.062, 0.045, 12, sideways)
		_cyl("accent", Vector3(side * (w + 0.042), mid, f.cz), 0.045, 0.04, 0.012, 12, sideways)


func _beanie() -> void:
	var y: float = _rim(0.09)
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


func _pirate() -> void:
	var y: float = _rim(0.03)
	var w: float = f.w
	var d: float = f.d
	var cz: float = f.cz
	_dome("silk", w * 0.92, d * 0.92, y, 0.11, cz, 12, 4)
	# The brim, turned up between its three corners (one over the face).
	var inner := _ellipse(18, w * 0.9, d * 0.9, y, 0, cz)
	var outer: Array = []
	for i in 18:
		var a := i * TAU / 18
		var u := cos(3.0 * (a + PI * 0.5))
		outer.append(Vector3(w * (1.5 + 0.55 * (u * 0.5 + 0.5)) * cos(a), y + 0.1 * (0.5 - 0.5 * u), cz + d * (1.5 + 0.55 * (u * 0.5 + 0.5)) * sin(a)))
	_sheet("silk", [inner + [inner[0]], outer + [outer[0]]], 0.012, Vector3.UP)
	_band("gold", w * 0.92, d * 0.92, y + 0.02, 0.022, 0.004, cz, 12)
	_ball("horn", Vector3(0, y + 0.07, cz - d * 0.86), 0.026, Vector3(1, 1, 0.5), 6, 4)
	for side: float in [-1.0, 1.0]:
		_box("silk", Vector3(side * 0.009, y + 0.073, cz - d * 0.86 - 0.012), Vector3(0.008, 0.008, 0.006))


func _chef() -> void:
	var y: float = _rim(0.03)
	var w: float = f.w
	var d: float = f.d
	var cz: float = f.cz
	_loft("feather", [_ellipse(14, w * 0.9, d * 0.9, y, 0, cz), _ellipse(14, w * 0.9, d * 0.9, y + 0.12, 0, cz)])
	_ball("feather", Vector3(0, y + 0.19, cz), 1.0, Vector3(w * 1.3, 0.1, d * 1.3), 12, 5)
	for i in 6:
		var a := i * TAU / 6
		_ball("feather", Vector3(w * 0.9 * cos(a), y + 0.2, cz + d * 0.9 * sin(a)), 0.06, Vector3(1, 1.1, 1), 6, 4)


func _propeller() -> void:
	var y: float = _rim(0.08)
	var w: float = f.w * 1.05
	var d: float = f.d * 1.05
	var cz: float = f.cz
	_dome("accent", w, d, y, 0.11, cz, 12, 5)
	_band("gold", w, d, y + 0.012, 0.03, 0.004, cz, 12)
	var top := Vector3(0, y + 0.11, cz)
	_cyl("joint", top + Vector3(0, 0.03, 0), 0.008, 0.008, 0.06, 6)
	_ball("gold", top + Vector3(0, 0.065, 0), 0.016, Vector3.ONE, 6, 3)
	var turn := Basis.from_euler(Vector3(0, 0.5, 0))
	_box("flame", top + Vector3(0, 0.06, 0) + turn * Vector3(0.075, 0, 0), Vector3(0.13, 0.006, 0.04), turn * Basis.from_euler(Vector3(0.35, 0, 0)))
	_box("red", top + Vector3(0, 0.06, 0) + turn * Vector3(-0.075, 0, 0), Vector3(0.13, 0.006, 0.04), turn * Basis.from_euler(Vector3(-0.35, 0, 0)))


func _santa() -> void:
	var y: float = _rim(0.06)
	var w: float = f.w * 1.04
	var d: float = f.d * 1.04
	var cz: float = f.cz
	_torus("feather", Vector3(0, y, cz), w, 0.05, 14, Basis.IDENTITY, d)
	var rings: Array = []
	var tip := Vector3.ZERO
	for k in 7:
		var t := k / 6.0
		tip = Vector3(0.2 * t * t, y + 0.02 + 0.26 * sin(t * PI * 0.62), cz + 0.03 * t)
		rings.append(_ellipse(10, w * (1.0 - t) * 0.96 + 0.012, d * (1.0 - t) * 0.96 + 0.012, 0, 0, 0).map(
			func(p): return tip + Basis.from_euler(Vector3(0, 0, -1.3 * t * t)) * p))
	_loft("red", rings)
	_ball("feather", tip + Vector3(0.015, -0.02, 0), 0.04, Vector3.ONE, 7, 4)


func _sombrero() -> void:
	var y: float = _rim(0.03)
	var w: float = f.w
	var d: float = f.d
	var cz: float = f.cz
	var r: float = maxf(w, d)
	var rows: Array = []
	for k in 4:
		var t := k / 3.0
		var ring: Array = _ellipse(18, lerpf(w * 0.9, r * 2.7, t), lerpf(d * 0.9, r * 2.7, t), y + 0.07 * t * t * t - 0.012 * sin(t * PI), 0, cz)
		rows.append(ring + [ring[0]])
	_sheet("straw", rows, 0.012, Vector3.UP)
	_loft("straw", [_ellipse(12, w * 0.9, d * 0.9, y, 0, cz), _ellipse(12, w * 0.72, d * 0.72, y + 0.13, 0, cz),
		_ellipse(12, w * 0.4, d * 0.4, y + 0.2, 0, cz)])
	_band("accent", w * 0.86, d * 0.86, y + 0.035, 0.035, 0.004, cz, 12)
	_torus("red", Vector3(0, y + 0.075, cz), r * 2.7, 0.022, 18, Basis.IDENTITY, r * 2.7)


func _fez() -> void:
	var y: float = _rim(0.02)
	var r: float = minf(f.w, f.d)
	var top := Vector3(0, y + 0.15, f.cz)
	_cyl("red", Vector3(0, y + 0.075, f.cz), r * 0.72, r * 0.58, 0.15, 12)
	_ball("gold", top, 0.012, Vector3.ONE, 5, 3)
	_segment("gold", top, top + Vector3(r * 0.66, 0.0, 0.01), 0.008)
	_segment("gold", top + Vector3(r * 0.66, 0.0, 0.01), top + Vector3(r * 0.72, -0.1, 0.01), 0.008)
	_cyl("gold", top + Vector3(r * 0.72, -0.125, 0.01), 0.008, 0.016, 0.05, 6)


func _hard_hat() -> void:
	var y: float = _rim(0.07)
	var w: float = f.w * 1.08
	var d: float = f.d * 1.08
	var cz: float = f.cz
	_dome("hazard", w, d, y, 0.12, cz, 14, 5)
	_loft("hazard", [_ellipse(14, w * 1.22, d * 1.3, y - 0.004, 0, cz - d * 0.08), _ellipse(14, w * 1.2, d * 1.28, y + 0.012, 0, cz - d * 0.08)])
	_box("hazard", Vector3(0, y + 0.105, cz), Vector3(0.04, 0.03, d * 1.7))
	_box("joint", Vector3(0, y + 0.03, cz - d * 0.98), Vector3(0.06, 0.03, 0.01))


func _mortarboard() -> void:
	var y: float = _rim(0.07)
	var w: float = f.w * 1.04
	var d: float = f.d * 1.04
	var cz: float = f.cz
	_dome("silk", w, d, y, 0.09, cz, 12, 4)
	var r: float = maxf(w, d) * 1.55
	var c := Vector3(0, y + 0.095, cz)
	_box("silk", c, Vector3(r * 2.0, 0.012, r * 2.0), Basis.from_euler(Vector3(0, PI * 0.25, 0)))
	_ball("gold", c + Vector3(0, 0.01, 0), 0.014, Vector3(1, 0.6, 1), 6, 3)
	var edge := c + Vector3(r * 0.95, 0.008, 0.0)
	_segment("gold", c + Vector3(0, 0.008, 0), edge, 0.007)
	_segment("gold", edge, edge + Vector3(0.01, -0.1, 0), 0.007)
	_cyl("gold", edge + Vector3(0.01, -0.125, 0), 0.006, 0.016, 0.05, 6)


func _jester() -> void:
	var y: float = _rim(0.07)
	var w: float = f.w * 1.05
	var d: float = f.d * 1.05
	var cz: float = f.cz
	_band("gold", w, d, y + 0.01, 0.04, 0.006, cz, 12)
	for i in 8:
		var a := i * TAU / 8
		_cone("gold", Vector3(w * 1.04 * cos(a), y - 0.005, cz + d * 1.04 * sin(a)), Vector3(w * 1.12 * cos(a), y - 0.055, cz + d * 1.12 * sin(a)), 0.03, 4)
	for side: float in [-1.0, 1.0]:
		var m := "accent" if side < 0.0 else "purple"
		var path: Array = []
		var radii: Array = []
		for k in 7:
			var t := k / 6.0
			path.append(Vector3(side * (w * 0.42 + 0.25 * t), y + 0.05 + 0.2 * sin(t * PI * 0.75), cz))
			radii.append(lerpf(maxf(w, d) * 0.62, 0.012, t))
		_tube_r(m, path, radii, 8)
		_ball("gold", path[-1] + Vector3(side * 0.01, -0.02, 0), 0.026, Vector3.ONE, 6, 4)


func _bucket() -> void:
	var y: float = _rim(0.1)
	var r: float = maxf(f.w, f.d)
	_cyl("steel", Vector3(0, y + 0.11, f.cz), r * 1.22, r * 0.98, 0.22, 14)
	_torus("steel", Vector3(0, y, f.cz), r * 1.24, 0.016, 14)
	_torus("joint", Vector3(0, y + 0.15, f.cz), r * 1.08, 0.008, 14)
	# The handle, hanging round the back.
	for k in 8:
		var a0 := PI * k / 8.0
		var a1 := PI * (k + 1) / 8.0
		_segment("joint", Vector3((r * 1.24 + 0.02) * cos(a0), y + 0.01 - 0.06 * sin(a0), f.cz + (r * 1.24 + 0.02) * sin(a0)),
			Vector3((r * 1.24 + 0.02) * cos(a1), y + 0.01 - 0.06 * sin(a1), f.cz + (r * 1.24 + 0.02) * sin(a1)), 0.008)


func _traffic_cone() -> void:
	var y: float = _rim(0.03)
	var r: float = minf(f.w, f.d)
	_box("orange", Vector3(0, y + 0.008, f.cz), Vector3(r * 2.5, 0.016, r * 2.5))
	_cyl("orange", Vector3(0, y + 0.19, f.cz), r * 0.86, 0.02, 0.36, 12)
	for band in [[0.09, 0.05], [0.19, 0.04]]:
		var lo: float = band[0]
		var hi: float = band[0] + band[1]
		_loft("feather", [_ellipse(12, r * 0.86 * (1.0 - lo / 0.37) + 0.006, r * 0.86 * (1.0 - lo / 0.37) + 0.006, y + 0.01 + lo, 0, f.cz),
			_ellipse(12, r * 0.86 * (1.0 - hi / 0.37) + 0.006, r * 0.86 * (1.0 - hi / 0.37) + 0.006, y + 0.01 + hi, 0, f.cz)])


func _bandana() -> void:
	var y: float = _rim(0.1)
	var w: float = f.w * 1.05
	var d: float = f.d * 1.05
	var cz: float = f.cz
	_dome("accent", w, d, y, 0.105, cz, 14, 5)
	_band("accent", w, d, y + 0.012, 0.035, 0.006, cz, 14)
	var knot := Vector3(0, y + 0.01, cz + d + 0.012)
	_ball("accent", knot, 0.026, Vector3.ONE, 6, 4)
	for side: float in [-1.0, 1.0]:
		_cone("accent", knot, knot + Vector3(side * 0.07, -0.13 - 0.03 * side, 0.05), 0.03, 4, 0.3)


func _flower_crown() -> void:
	var y: float = _rim(0.07)
	var w: float = f.w * 1.04
	var d: float = f.d * 1.04
	var cz: float = f.cz
	_torus("leaf", Vector3(0, y, cz), w, 0.02, 16, Basis.IDENTITY, d)
	var petals := ["pink", "feather", "hazard", "red"]
	for i in 9:
		var a := i * TAU / 9
		var c := Vector3((w + 0.016) * cos(a), y + 0.008, cz + (d + 0.016) * sin(a))
		_ball(petals[i % petals.size()], c, 0.034, Vector3(1, 0.85, 1), 6, 3)
		_ball("gold", c + Vector3(cos(a), 0.3, sin(a)) * 0.022, 0.014, Vector3.ONE, 5, 3)
		_cone("leaf", c, c + Vector3(-sin(a) * 0.05, 0.03, cos(a) * 0.05), 0.016, 4, 0.4)


func _mohawk() -> void:
	var y: float = _rim(0.03)
	var d: float = f.d
	var cz: float = f.cz
	for k in 7:
		var t := k / 6.0
		var z := cz + lerpf(-d * 0.75, d * 0.95, t)
		var h := 0.1 + 0.07 * sin(t * PI)
		var drop := 0.05 * pow(absf(t - 0.45) * 2.0, 2.0)
		_cone("accent", Vector3(0, y - drop, z), Vector3(0, y - drop + h, z + 0.035), d * 0.3, 4, 0.35)


func _afro() -> void:
	var y: float = _rim(0.01)
	_ball("hair", Vector3(0, y, f.cz + f.d * 0.12), 1.0, Vector3(f.w * 1.55, 0.16, f.d * 1.5), 10, 6)


func _devil_horns() -> void:
	var y: float = _rim(0.04)
	for side: float in [-1.0, 1.0]:
		var path: Array = []
		for k in 6:
			var t := k / 5.0
			path.append(Vector3(side * (f.w * 0.55 + 0.05 * sin(t * PI)), y + 0.13 * t, f.cz - 0.02 - 0.05 * t * t))
		_tube("red", path, 0.03, 0.003, 6)


func _antlers() -> void:
	var y: float = _rim(0.04)
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * f.w * 0.5, y, f.cz)
		var a := root + Vector3(side * 0.06, 0.1, 0.0)
		var b := a + Vector3(side * 0.07, 0.1, -0.01)
		_tube("leather", [root, a, b, b + Vector3(side * 0.02, 0.07, 0)], 0.018, 0.005, 5)
		_tube("leather", [a, a + Vector3(side * 0.07, 0.02, -0.03), a + Vector3(side * 0.1, 0.07, -0.04)], 0.013, 0.004, 5)
		_tube("leather", [root.lerp(a, 0.5), root.lerp(a, 0.5) + Vector3(-side * 0.01, 0.06, -0.05)], 0.012, 0.004, 5)
		_tube("leather", [b, b + Vector3(side * 0.06, 0.03, 0.02), b + Vector3(side * 0.08, 0.08, 0.03)], 0.011, 0.004, 5)


## A band over the top of the head, ear to ear (what ears and antennae sit on).
func _headband(m: String = "joint") -> void:
	var mid: float = lerpf(f.bottom, f.top, 0.6)
	var w: float = f.w + 0.008
	var path: Array = []
	for k in 11:
		var a := PI * k / 10.0
		path.append(Vector3(-w * cos(a), mid + (f.top + 0.008 - mid) * sin(a), f.cz))
	for k in path.size() - 1:
		_segment(m, path[k], path[k + 1], 0.016, Vector3.FORWARD)


func _bunny_ears() -> void:
	_headband("feather")
	for side: float in [-1.0, 1.0]:
		var tilt := Basis.from_euler(Vector3(-0.08, 0, -side * 0.2))
		var root := Vector3(side * f.w * 0.42, f.top - 0.01, f.cz)
		var bend := Basis.from_euler(Vector3(0, 0, -side * 0.5)) if side > 0.0 else Basis.IDENTITY   # one ear flops
		_ball("feather", root + tilt * Vector3(0, 0.07, 0), 1.0, Vector3(0.036, 0.075, 0.018), 7, 4)
		var mid := root + tilt * Vector3(0, 0.135, 0)
		_ball("feather", mid + tilt * bend * Vector3(0, 0.065, 0), 1.0, Vector3(0.034, 0.075, 0.017), 7, 4)
		_ball("pink", root + tilt * Vector3(0, 0.075, -0.012), 1.0, Vector3(0.018, 0.055, 0.008), 6, 3)
		_ball("pink", mid + tilt * bend * Vector3(0, 0.06, -0.012), 1.0, Vector3(0.017, 0.05, 0.008), 6, 3)


func _cat_ears() -> void:
	_headband("silk")
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * f.w * 0.55, f.top - 0.035, f.cz)
		_cone("silk", root, root + Vector3(side * 0.035, 0.12, 0), 0.055, 4, 0.5)
		_cone("pink", root + Vector3(0, 0.01, -0.016), root + Vector3(side * 0.028, 0.09, -0.012), 0.032, 4, 0.3)


func _unicorn() -> void:
	_headband("feather")
	var root := Vector3(0, f.top - 0.04, f.cz - f.d * 0.55)
	var dir := Vector3(0, 0.9, -0.42).normalized()
	_cone("feather", root, root + dir * 0.26, 0.032, 8)
	for k in 4:
		var t := 0.12 + k * 0.2
		_torus("gold", root + dir * 0.26 * t, 0.033 * (1.0 - t) + 0.003, 0.009, 8, _along(dir) * Basis.from_euler(Vector3(0.35, 0, 0)))


# ---------------------------------------------------------------------------
# Glasses and faces. On the head bone, in front of the eyes.

func _lens_x() -> float:
	if f.has("lens_x"):
		return f.lens_x
	return clampf(f.eye_w, 0.04, minf(0.075, f.w * 0.6))


func _shades() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.012
	var x := _lens_x()
	for side: float in [-1.0, 1.0]:
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
	for side: float in [-1.0, 1.0]:
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
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * x, y, f.eye_z - 0.025)
		_cyl("gold", c, 0.04, 0.036, 0.04, 12, facing)
		_cyl("flame", c - Vector3(0, 0, 0.021), 0.031, 0.031, 0.004, 12, facing)
	_box("gold", Vector3(0, y, f.eye_z - 0.015), Vector3(x * 2.0 - 0.07, 0.014, 0.014))


func _mustache() -> void:
	var y: float = f.mouth_y
	var z: float = f.mouth_z - 0.008
	for side: float in [-1.0, 1.0]:
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


## The arms of a pair of glasses: from each lens's outer edge back to the ears.
func _temples(m: String, x: float, y: float, z: float, thick: float = 0.008) -> void:
	for side: float in [-1.0, 1.0]:
		var corner := Vector3(side * (f.w + 0.008), y + 0.004, f.front + 0.01)
		_segment(m, Vector3(side * x, y, z), corner, thick)
		_segment(m, corner, Vector3(side * (f.w + 0.008), y, f.cz), thick)


func _aviators() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.012
	var x := _lens_x()
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * x, y - 0.006, z)
		var rim: Array = []
		for k in 12:
			var a := k * TAU / 12
			var drop := 1.0 + 0.3 * maxf(sin(a), 0.0)   # a teardrop: deeper below
			rim.append(c + Vector3(0.04 * cos(a) * (1.0 - 0.15 * maxf(sin(a), 0.0) * side * signf(cos(a))), -0.032 * sin(a) * drop, 0))
		_plate("lens", rim, 0.006, Vector3.BACK)
		for k in 12:
			_segment("gold", rim[k] + Vector3(0, 0, -0.002), rim[(k + 1) % 12] + Vector3(0, 0, -0.002), 0.006, Vector3.BACK)
	_segment("gold", Vector3(-x + 0.03, y + 0.022, z), Vector3(x - 0.03, y + 0.022, z), 0.006)
	_segment("gold", Vector3(-x + 0.036, y + 0.004, z), Vector3(x - 0.036, y + 0.004, z), 0.006)
	_temples("gold", x + 0.038, y + 0.018, z, 0.006)


func _three_d() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.012
	var x := _lens_x()
	_box("feather", Vector3(0, y, z), Vector3(x * 2.0 + 0.1, 0.064, 0.012))
	_box("redlens", Vector3(-x, y, z - 0.004), Vector3(0.07, 0.044, 0.012))
	_box("bluelens", Vector3(x, y, z - 0.004), Vector3(0.07, 0.044, 0.012))
	_temples("feather", x + 0.05, y + 0.01, z, 0.012)


func _heart_shades() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.012
	var x := _lens_x()
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * x, y + 0.004, z)
		var rim: Array = []
		for k in 16:
			var t := k * TAU / 16
			rim.append(c + Vector3(16.0 * pow(sin(t), 3.0), 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t), 0) * 0.0027)
		_plate("pink", rim, 0.01, Vector3.BACK)
		_ball("feather", c + Vector3(-0.016, 0.014, -0.004), 0.008, Vector3(1, 1, 0.4), 5, 3)
	_box("pink", Vector3(0, y + 0.008, z + 0.004), Vector3(maxf(x * 2.0 - 0.07, 0.01), 0.012, 0.008))
	_temples("pink", x + 0.04, y + 0.012, z + 0.004)


func _laser_visor() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.014
	var w: float = f.w + 0.012
	var rows: Array = []
	for row in 2:
		var r: Array = []
		for k in 9:
			var a := lerpf(-PI * 0.93, -PI * 0.07, k / 8.0)
			r.append(Vector3(w * cos(a), y + 0.024 - row * 0.048, minf(f.cz + (f.d + 0.012) * sin(a), 0.0) if absf(cos(a)) > 0.75 else z))
		rows.append(r)
	_sheet("steel", rows, 0.012, Vector3.BACK)
	_box("flame", Vector3(0, y, z - 0.004), Vector3(w * 1.5, 0.016, 0.012))
	_torus("steel", Vector3(0, y, f.cz), w, 0.018, 16, Basis.IDENTITY, f.d + 0.012)


func _bandit_mask() -> void:
	var y: float = f.eye_y
	var x := _lens_x()
	var z: float = f.eye_z - 0.01
	_torus("silk", Vector3(0, y, f.cz), f.w + 0.006, 0.034, 18, Basis.IDENTITY, f.d + 0.008)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	for side: float in [-1.0, 1.0]:
		_cyl("silk", Vector3(side * x, y, z), 0.046, 0.046, 0.012, 10, facing, 0.75)
		_cyl("feather", Vector3(side * x, y, z - 0.006), 0.026, 0.026, 0.006, 8, facing, 0.5)
		_ball("silk", Vector3(side * x, y, z - 0.01), 0.009, Vector3(1, 1, 0.4), 5, 3)
	_box("silk", Vector3(0, y, z), Vector3(x * 2.0, 0.04, 0.012))
	var knot := Vector3(0.02, y, f.cz + f.d + 0.02)
	_cone("silk", knot, knot + Vector3(0.05, -0.09, 0.04), 0.022, 4, 0.3)
	_cone("silk", knot, knot + Vector3(-0.03, -0.1, 0.035), 0.022, 4, 0.3)


func _bandana_mask() -> void:
	var top: float = maxf(f.eye_y - 0.035, f.bottom + 0.06)
	var w: float = f.w + 0.012
	var d: float = f.d + 0.012
	var tip := Vector3(0, f.bottom - 0.07, f.front - 0.015)
	var rows: Array = []
	for row in 4:
		var t := row / 3.0
		var r: Array = []
		for k in 9:
			var a := lerpf(-PI, 0.0, k / 8.0)
			var edge := Vector3(w * cos(a), top, minf(f.cz + d * sin(a), f.cz) if absf(cos(a)) > 0.9 else minf(f.cz + d * sin(a), f.front - 0.012 + 0.03 * absf(cos(a))))
			r.append(edge.lerp(tip, t * (0.35 + 0.65 * sin(-a))) + Vector3(0, -0.02 * t, 0))
		rows.append(r)
	_sheet("accent", rows, 0.01, Vector3.BACK)
	_torus("accent", Vector3(0, top, f.cz), w - 0.004, 0.022, 16, Basis.IDENTITY, d - 0.004)
	_ball("accent", Vector3(0, top, f.cz + d + 0.008), 0.024, Vector3.ONE, 6, 4)


func _snorkel() -> void:
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.02
	var x := _lens_x()
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	_torus("joint", Vector3(0, y, f.cz), f.w + 0.008, 0.022, 16, Basis.IDENTITY, f.d + 0.01)
	_cyl("accent", Vector3(0, y, z + 0.008), x + 0.05, x + 0.046, 0.03, 14, facing, 0.6)
	_cyl("glass", Vector3(0, y, z - 0.009), x + 0.04, x + 0.04, 0.004, 14, facing, 0.55)
	_box("accent", Vector3(0, y - 0.035, z - 0.004), Vector3(0.035, 0.03, 0.03))
	var side: float = -(f.w + 0.03)
	var mouth := Vector3(-0.02, maxf(y - 0.085, f.bottom + 0.02), f.front - 0.02)
	_tube("accent", [mouth, Vector3(side * 0.7, mouth.y - 0.01, f.front + 0.0), Vector3(side, mouth.y + 0.02, f.cz - 0.02),
		Vector3(side, y + 0.06, f.cz), Vector3(side, f.top + 0.1, f.cz + 0.02)], 0.016, 0.016, 6)
	_cyl("orange", Vector3(side, f.top + 0.11, f.cz + 0.02), 0.02, 0.02, 0.04, 6)
	_box("joint", mouth, Vector3(0.05, 0.025, 0.02))


func _clown_nose() -> void:
	_ball("red", Vector3(0, f.nose_y, f.nose_z - 0.028), 0.034, Vector3.ONE, 8, 5)


func _beard() -> void:
	var y: float = f.mouth_y
	var z: float = f.mouth_z - 0.004
	var rows: Array = []
	for row in 4:
		var t := row / 3.0
		var r: Array = []
		for k in 9:
			var u := k / 8.0 * 2.0 - 1.0
			var a := u * PI * 0.5
			var hang := (0.16 - 0.1 * u * u) * t
			r.append(Vector3((f.w + 0.006) * sin(a) * (1.0 - 0.45 * t), y - 0.012 - hang, minf(f.cz - (f.d + 0.008) * cos(a), z + 0.05 * absf(u)) - 0.02 * sin(t * PI)))
		rows.append(r)
	_sheet("hair", rows, 0.03, Vector3.BACK)
	_mustache()


func _handlebar() -> void:
	var y: float = f.mouth_y
	var z: float = f.mouth_z - 0.01
	for side: float in [-1.0, 1.0]:
		var path: Array = []
		for k in 9:
			var t := k / 8.0
			var curl := maxf(t - 0.55, 0.0) / 0.45
			path.append(Vector3(side * (0.006 + 0.1 * t - 0.035 * curl * curl), y - 0.014 * sin(minf(t / 0.55, 1.0) * PI) + 0.06 * curl * curl, z + 0.012 * t))
		_tube("hair", path, 0.017, 0.004, 6)


func _lollipop() -> void:
	var mouth := Vector3(0.02, f.mouth_y - 0.02, f.mouth_z - 0.004)
	var out := Vector3(0.45, -0.12, -0.88).normalized()
	_segment("feather", mouth, mouth + out * 0.09, 0.008)
	var c := mouth + out * 0.115
	_ball("pink", c, 0.032, Vector3.ONE, 8, 5)
	_torus("feather", c, 0.031, 0.008, 10, _along(out) * Basis.from_euler(Vector3(0.6, 0, 0)))


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
	for side: float in [-1.0, 1.0]:
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
	for side: float in [-1.0, 1.0]:
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


func _neckerchief() -> void:
	_torus("accent", Vector3(0, f.neck_y, 0.0), 0.115, 0.03, 14, Basis.IDENTITY, maxf(0.1, -f.collar_front + 0.005))
	var c := _collar() + Vector3(0, 0.015, -0.006)
	_plate("accent", [c + Vector3(-0.09, 0, 0.012), c + Vector3(0.09, 0, 0.012), c + Vector3(0, -0.13, -0.012)], 0.012, Vector3.BACK)
	_ball("accent", c + Vector3(0, 0.0, -0.01), 0.02, Vector3.ONE, 6, 3)


func _lei() -> void:
	var petals := ["pink", "hazard", "feather", "red", "purple"]
	var n := 16
	for k in n:
		var p := _necklace_point(k * TAU / n, 0.13, 0.02)
		_ball(petals[k % petals.size()], p, 0.036, Vector3(1, 0.8, 1), 6, 4)
		_ball("leaf", p + Vector3(0, -0.014, 0.004), 0.022, Vector3(1.5, 0.5, 1.5), 5, 3)


func _bell_collar() -> void:
	_torus("red", Vector3(0, f.neck_y + 0.005, 0.0), 0.1, 0.03, 14, Basis.IDENTITY, maxf(0.09, -f.collar_front - 0.005))
	var c := _collar() + Vector3(0, -0.005, -0.012)
	_ball("gold", c, 0.03, Vector3.ONE, 8, 5)
	_box("joint", c + Vector3(0, -0.014, -0.022), Vector3(0.03, 0.006, 0.012))
	_box("gold", c + Vector3(0, 0.03, 0.008), Vector3(0.014, 0.02, 0.014))


func _spiked_collar() -> void:
	var rz: float = maxf(0.09, -f.collar_front - 0.005)
	_torus("silk", Vector3(0, f.neck_y + 0.005, 0.0), 0.1, 0.034, 14, Basis.IDENTITY, rz)
	for k in 10:
		var a := k * TAU / 10 + 0.31
		var dir := Vector3(cos(a), 0.0, sin(a))
		var base := Vector3(0.115 * cos(a), f.neck_y + 0.005, (rz + 0.015) * sin(a))
		_cone("steel", base, base + dir * 0.055, 0.016, 5)


func _pearls() -> void:
	var n := 26
	for k in n:
		_ball("pearl", _necklace_point(k * TAU / n, 0.1, 0.016), 0.017, Vector3.ONE, 6, 4)


func _ruff() -> void:
	var y: float = f.neck_y + 0.01
	var rz: float = maxf(0.08, -f.collar_front - 0.02)
	var n := 24
	var inner: Array = []
	var outer: Array = []
	for k in n + 1:
		var a := k * TAU / n
		var up := 0.03 if k % 2 == 0 else -0.03
		inner.append(Vector3(0.07 * cos(a), y + up * 0.4, rz * 0.8 * sin(a)))
		outer.append(Vector3(0.2 * cos(a), y + up, (rz + 0.13) * sin(a)))
	_sheet("feather", [inner, outer], 0.01, Vector3.UP)
	_sheet("feather", [inner.map(func(p): return p + Vector3(0, -0.02, 0)), outer.map(func(p): return Vector3(p.x, 2.0 * y - p.y - 0.02, p.z))], 0.01, Vector3.UP)


func _dog_tags() -> void:
	var n := 30
	var pts: Array = []
	for k in n + 1:
		pts.append(_necklace_point(k * TAU / n, 0.2, 0.01))
	for k in n:
		_segment("steel", pts[k], pts[k + 1], 0.008)
	var bottom := _necklace_point(0.0, 0.2, 0.012)
	_box("steel", bottom + Vector3(-0.012, -0.03, -0.004), Vector3(0.034, 0.055, 0.006), Basis.from_euler(Vector3(0, 0, 0.18)))
	_box("steel", bottom + Vector3(0.014, -0.034, -0.01), Vector3(0.034, 0.055, 0.006), Basis.from_euler(Vector3(0, 0, -0.14)))


func _stethoscope() -> void:
	var join := _necklace_point(0.0, 0.17, 0.014)
	for side: float in [-1.0, 1.0]:
		var path: Array = []
		for k in 9:
			path.append(_necklace_point(side * lerpf(2.6, 0.0, k / 8.0), 0.17, 0.014))
		for k in path.size() - 1:
			_segment("joint", path[k], path[k + 1], 0.014)
		_cyl("steel", path[0] + Vector3(0, 0.03, 0), 0.008, 0.008, 0.06, 5)
	var disc := join + Vector3(0.035, -0.1, -0.012)
	_tube("joint", [join, join + Vector3(0.005, -0.05, -0.006), disc], 0.008, 0.008, 5)
	_cyl("steel", disc, 0.032, 0.032, 0.016, 12, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))


# ---------------------------------------------------------------------------
# Back pieces. On the chest bone, behind the shoulders.

## A cape's cloth, from the shoulders down to CAPE_BOTTOM: rows of points, `top` and
## `hem` how wide it is there (times the chest's half width), `ripple` how much it folds.
func _cape_grid(top: float = 0.85, hem: float = 1.35, ripple: float = 0.02) -> Array:
	var top_y: float = f.neck_y - 0.01
	var back: float = maxf(f.chest_back, 0.1)
	var sw: float = f.chest_w
	var grid: Array = []
	var rows := 6
	var cols := 8
	for i in rows + 1:
		var t := i / float(rows)
		var y := lerpf(top_y, CAPE_BOTTOM, t)
		var half := lerpf(sw * top, sw * hem, t)
		var z := lerpf(back * 0.55, back + 0.17, t * t * 0.7 + t * 0.3)
		var row: Array = []
		for j in cols + 1:
			var u := j / float(cols) * 2.0 - 1.0
			row.append(Vector3(u * half, y - 0.015 * (1.0 - u * u) * t, z + 0.05 * (1.0 - u * u) + ripple * sin(u * 6.0) * t))
		grid.append(row)
	return grid


func _cape() -> void:
	var top_y: float = f.neck_y - 0.01
	var back: float = maxf(f.chest_back, 0.1)
	var sw: float = f.chest_w
	_sheet("accent", _cape_grid(), 0.012, Vector3.FORWARD)
	for side: float in [-1.0, 1.0]:
		_ball("gold", Vector3(side * sw * 0.7, top_y - 0.01, f.collar_front + 0.02), 0.024, Vector3(1, 1, 0.6), 7, 4)
		_segment("accent", Vector3(side * sw * 0.7, top_y - 0.01, f.collar_front + 0.02), Vector3(side * sw * 0.85, top_y, back * 0.55), 0.03, Vector3.UP)


func _wings() -> void:
	var back: float = maxf(f.chest_back, 0.1)
	var root_y: float = f.neck_y - 0.09
	for side: float in [-1.0, 1.0]:
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
	for side: float in [-1.0, 1.0]:
		_segment("joint", Vector3(side * w * 0.3, y + 0.13, back + 0.01), Vector3(side * w * 0.33, f.neck_y + 0.01, 0.0), 0.03, Vector3.RIGHT)
		_segment("joint", Vector3(side * w * 0.33, f.neck_y + 0.01, 0.0), Vector3(side * w * 0.35, f.neck_y - 0.12, f.chest_front - 0.005), 0.03, Vector3.RIGHT)


func _rocket_pack() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var y: float = f.neck_y - 0.17
	_box("steel", Vector3(0, y, back + 0.03), Vector3(0.12, 0.24, 0.06))
	for side: float in [-1.0, 1.0]:
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


func _bat_wings() -> void:
	var back: float = maxf(f.chest_back, 0.1)
	var root_y: float = f.neck_y - 0.1
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * 0.05, root_y, back + 0.01)
		var wrist := root + Vector3(side * 0.24, 0.26, 0.08)
		var tips: Array = [wrist + Vector3(side * 0.3, -0.02, 0.06), wrist + Vector3(side * 0.24, -0.3, 0.05), wrist + Vector3(side * 0.06, -0.42, 0.03)]
		var edge: Array = [root, wrist]
		for k in tips.size():
			edge.append(tips[k])
			var next: Vector3 = tips[k + 1] if k + 1 < tips.size() else root + Vector3(side * 0.02, -0.22, 0.01)
			edge.append((tips[k] + next) * 0.5 + (root - (tips[k] + next) * 0.5) * 0.28)   # the scallop between two fingers
		edge.append(root + Vector3(side * 0.02, -0.22, 0.01))
		_plate("accent", edge, 0.008, Vector3.BACK)
		_tube("silk", [root, wrist], 0.018, 0.014, 5)
		for t in tips:
			_tube("silk", [wrist, t], 0.012, 0.004, 4)
		_cone("silk", wrist, wrist + Vector3(0, 0.07, -0.01), 0.012, 4)


func _butterfly_wings() -> void:
	var back: float = maxf(f.chest_back, 0.1) + 0.015
	var root_y: float = f.neck_y - 0.16
	for side: float in [-1.0, 1.0]:
		for lobe in [[Vector2(0.25, 0.14), Vector2(0.23, 0.19), 0.5], [Vector2(0.17, -0.16), Vector2(0.15, 0.13), -0.5]]:
			var c := Vector3(side * lobe[0].x, root_y + lobe[0].y, back + 0.03)
			var turn := Basis.from_euler(Vector3(0, -side * 0.25, side * lobe[2]))
			var rim: Array = []
			var spot: Array = []
			for k in 12:
				var a := k * TAU / 12
				rim.append(c + turn * Vector3(lobe[1].x * cos(a), lobe[1].y * sin(a), 0))
				spot.append(c + turn * Vector3(lobe[1].x * 0.55 * cos(a) + side * 0.03, lobe[1].y * 0.55 * sin(a), -0.006))
			_plate("accent", rim, 0.008, Vector3.BACK)
			_plate("glow", spot, 0.02, Vector3.BACK)
			for k in 12:
				_segment("silk", rim[k], rim[(k + 1) % 12], 0.014, Vector3.BACK)
	_ball("silk", Vector3(0, root_y, back), 1.0, Vector3(0.03, 0.16, 0.03), 6, 4)


func _turtle_shell() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var c := Vector3(0, f.neck_y - 0.2, back - 0.02)
	var w: float = maxf(f.chest_w * 1.05, 0.19)
	_ball("moss", c, 1.0, Vector3(w, 0.23, 0.13), 10, 5)
	_torus("straw", c, w * 0.98, 0.03, 14, Basis.from_euler(Vector3(PI * 0.5, 0, 0)), 0.225)
	for spot in [Vector2(0, 0), Vector2(0.09, 0.09), Vector2(-0.09, 0.09), Vector2(0.09, -0.09), Vector2(-0.09, -0.09), Vector2(0, 0.16), Vector2(0, -0.16)]:
		var out := 0.118 * sqrt(maxf(1.0 - pow(spot.x / w, 2.0) - pow(spot.y / 0.23, 2.0), 0.0))
		_cyl("leaf", c + Vector3(spot.x, spot.y, out + 0.006), 0.045, 0.036, 0.016, 6, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))


func _guitar() -> void:
	var back: float = maxf(f.chest_back, 0.08) + 0.03
	var tilt := Basis.from_euler(Vector3(0, 0, -0.75))
	var flat := tilt * Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	var c := Vector3(-0.05, f.neck_y - 0.3, back)
	_cyl("accent", c, 0.13, 0.13, 0.04, 12, flat)
	_cyl("accent", c + tilt * Vector3(0, 0.15, 0), 0.095, 0.095, 0.04, 12, flat)
	_cyl("silk", c + tilt * Vector3(0, 0.07, 0) + Vector3(0, 0, 0.021), 0.036, 0.036, 0.004, 10, flat)
	_box("wood", c + tilt * Vector3(0, 0.42, 0), Vector3(0.04, 0.4, 0.022), tilt)
	_box("wood", c + tilt * Vector3(0, 0.66, 0), Vector3(0.06, 0.09, 0.02), tilt)
	_box("steel", c + tilt * Vector3(0, -0.03, 0) + Vector3(0, 0, 0.024), Vector3(0.07, 0.014, 0.01), tilt)
	for k in 3:
		_box("steel", c + tilt * Vector3(-0.012 + 0.012 * k, 0.3, 0) + Vector3(0, 0, 0.014), Vector3(0.003, 0.66, 0.003), tilt)
	_segment("joint", Vector3(f.chest_w * 0.8, f.neck_y - 0.02, 0.0), Vector3(-f.chest_w * 0.6, f.chest_bottom + 0.05, back - 0.02), 0.035, Vector3.BACK)
	_segment("joint", Vector3(f.chest_w * 0.8, f.neck_y - 0.02, 0.0), Vector3(-f.chest_w * 0.5, f.chest_bottom + 0.06, f.chest_front - 0.005), 0.035, Vector3.BACK)


func _quiver() -> void:
	var back: float = maxf(f.chest_back, 0.08) + 0.045
	var tilt := Basis.from_euler(Vector3(0, 0, -0.45))
	var c := Vector3(0.02, f.neck_y - 0.22, back)
	_cyl("leather", c, 0.045, 0.055, 0.42, 8, tilt)
	_cyl("gold", c + tilt * Vector3(0, 0.2, 0), 0.058, 0.058, 0.03, 8, tilt)
	var fletch := ["red", "feather", "accent", "feather"]
	for k in 4:
		var off := Vector3(0.022 * cos(k * 1.7), 0, 0.022 * sin(k * 1.7))
		var top := c + tilt * (off + Vector3(0, 0.34 + 0.02 * k, 0))
		_segment("wood", c + tilt * (off + Vector3(0, 0.15, 0)), top, 0.008)
		_cone(fletch[k], top + tilt * Vector3(0, -0.07, 0), top, 0.02, 4, 0.3)
	_segment("leather", Vector3(f.chest_w * 0.75, f.neck_y - 0.02, 0.0), Vector3(-f.chest_w * 0.6, f.chest_bottom + 0.05, back - 0.03), 0.03, Vector3.BACK)
	_segment("leather", Vector3(f.chest_w * 0.75, f.neck_y - 0.02, 0.0), Vector3(-f.chest_w * 0.5, f.chest_bottom + 0.06, f.chest_front - 0.005), 0.03, Vector3.BACK)


func _shield() -> void:
	var back: float = maxf(f.chest_back, 0.08) + 0.03
	var c := Vector3(0, f.neck_y - 0.2, back)
	var facing := Basis.from_euler(Vector3(PI * 0.5 - 0.08, 0, 0))
	_cyl("steel", c, 0.22, 0.22, 0.02, 14, facing)
	_cyl("accent", c + Vector3(0, 0, 0.012), 0.19, 0.17, 0.02, 14, facing)
	_ball("gold", c + Vector3(0, 0, 0.025), 0.05, Vector3(1, 1, 0.6), 8, 4)
	for k in 8:
		var a := k * TAU / 8
		_ball("gold", c + facing * Vector3(0.205 * cos(a), 0.012, 0.205 * sin(a)), 0.012, Vector3.ONE, 5, 3)


func _surfboard() -> void:
	var back: float = maxf(f.chest_back, 0.08) + 0.03
	var tilt := Basis.from_euler(Vector3(0.04, 0, 0.16))
	var c := Vector3(0, f.neck_y - 0.12, back)
	var rim: Array = []
	var stripe: Array = []
	for k in 16:
		var a := k * TAU / 16
		var squeeze := 1.0 - 0.25 * maxf(sin(a), 0.0)   # narrower at the nose
		rim.append(c + tilt * Vector3(0.17 * cos(a) * squeeze, 0.72 * sin(a), 0))
		stripe.append(c + tilt * Vector3(0.035 * cos(a), 0.66 * sin(a), 0.006))
	_plate("accent", rim, 0.03, Vector3.BACK)
	_plate("feather", stripe, 0.03, Vector3.BACK)
	_cone("silk", c + tilt * Vector3(0, -0.5, 0.03), c + tilt * Vector3(0, -0.6, 0.14), 0.05, 4, 0.2)
	_segment("joint", Vector3(f.chest_w * 0.8, f.neck_y - 0.02, 0.0), Vector3(-f.chest_w * 0.6, f.chest_bottom + 0.05, back - 0.02), 0.03, Vector3.BACK)
	_segment("joint", Vector3(f.chest_w * 0.8, f.neck_y - 0.02, 0.0), Vector3(-f.chest_w * 0.5, f.chest_bottom + 0.06, f.chest_front - 0.005), 0.03, Vector3.BACK)


func _banner() -> void:
	var back: float = maxf(f.chest_back, 0.08) + 0.03
	var foot := Vector3(0, f.neck_y - 0.3, back)
	var top := Vector3(0, 2.2, back + 0.05)
	_segment("wood", foot, top, 0.022)
	_ball("gold", top + Vector3(0, 0.02, 0), 0.026, Vector3.ONE, 6, 4)
	_segment("wood", top + Vector3(-0.15, -0.04, 0), top + Vector3(0.15, -0.04, 0), 0.016)
	var grid: Array = []
	for i in 5:
		var t := i / 4.0
		var row: Array = []
		for j in 5:
			var u := j / 4.0 * 2.0 - 1.0
			row.append(top + Vector3(u * 0.14, -0.045 - 0.42 * t - (0.05 * (1.0 - absf(u)) if i == 4 else 0.0), 0.012 + 0.02 * sin(u * 3.0 + t * 4.0) * t))
		grid.append(row)
	_sheet("accent", grid, 0.008, Vector3.FORWARD)
	_cyl("gold", top + Vector3(0, -0.2, 0.024), 0.055, 0.055, 0.006, 10, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
	_box("joint", foot + Vector3(0, 0.04, -0.01), Vector3(maxf(f.chest_w * 1.2, 0.2), 0.035, 0.03))


func _balloons() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var knot := Vector3(0, f.neck_y - 0.12, back + 0.01)
	_ball("joint", knot, 0.02, Vector3.ONE, 5, 3)
	var colours := ["accent", "red", "hazard"]
	var spots: Array = [Vector3(-0.2, 2.25, back + 0.22), Vector3(0.05, 2.42, back + 0.3), Vector3(0.26, 2.2, back + 0.18)]
	for k in 3:
		var c: Vector3 = spots[k]
		_ball(colours[k], c, 1.0, Vector3(0.12, 0.145, 0.12), 9, 6)
		_cone(colours[k], c + Vector3(0, -0.165, 0), c + Vector3(0, -0.13, 0), 0.02, 5)
		var steps := 6
		for i in steps:
			var a := knot.lerp(c + Vector3(0, -0.16, 0), i / float(steps)) + Vector3(0, 0, 0.03 * sin(i / float(steps) * PI))
			var b := knot.lerp(c + Vector3(0, -0.16, 0), (i + 1) / float(steps)) + Vector3(0, 0, 0.03 * sin((i + 1) / float(steps) * PI))
			_segment("feather", a, b, 0.005)


func _windup_key() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var c := Vector3(0, f.neck_y - 0.2, back)
	var along := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	_cyl("gold", c + Vector3(0, 0, 0.08), 0.018, 0.018, 0.18, 8, along)
	_cyl("gold", c + Vector3(0, 0, 0.005), 0.04, 0.04, 0.02, 10, along)
	for side: float in [-1.0, 1.0]:
		_torus("gold", c + Vector3(side * 0.075, 0, 0.18), 0.065, 0.024, 12, Basis.from_euler(Vector3(PI * 0.5, 0, 0)), 0.085)
	_box("gold", c + Vector3(0, 0, 0.18), Vector3(0.04, 0.05, 0.024))


# ---------------------------------------------------------------------------
# Shoulder pieces. On the chest bone, on top of the shoulders.

## The top of a shoulder (side: -1 the left, 1 the right).
func _shoulder(side: float) -> Vector3:
	return Vector3(side * maxf(f.chest_w * 0.95, 0.19), clampf(f.neck_y - 0.03, 1.45, 1.5), 0.0)


func _parrot() -> void:
	var s := _shoulder(1.0) + Vector3(-0.01, 0.0, 0.0)
	for dx: float in [-0.014, 0.014]:
		_segment("hazard", s + Vector3(dx, -0.02, 0), s + Vector3(dx, 0.04, 0), 0.01)
	_ball("red", s + Vector3(0, 0.1, 0.005), 1.0, Vector3(0.045, 0.07, 0.05), 8, 5)
	_ball("red", s + Vector3(0, 0.185, -0.012), 0.04, Vector3.ONE, 8, 5)
	_cone("hazard", s + Vector3(0, 0.185, -0.045), s + Vector3(0, 0.155, -0.085), 0.02, 5)
	for side: float in [-1.0, 1.0]:
		_ball("feather", s + Vector3(side * 0.026, 0.195, -0.036), 0.012, Vector3.ONE, 5, 3)
		_ball("silk", s + Vector3(side * 0.03, 0.196, -0.043), 0.006, Vector3.ONE, 4, 3)
		_ball("bluelens", s + Vector3(side * 0.042, 0.095, 0.015), 1.0, Vector3(0.014, 0.06, 0.04), 6, 4)
	for k in 3:
		var hue := ["red", "bluelens", "hazard"]
		_cone(hue[k], s + Vector3(-0.012 + 0.012 * k, 0.06, 0.04), s + Vector3(-0.03 + 0.03 * k, -0.07, 0.11), 0.018, 4, 0.3)


func _epaulettes() -> void:
	for side: float in [-1.0, 1.0]:
		var s := _shoulder(side) + Vector3(side * 0.02, 0.012, 0)
		var tilt := Basis.from_euler(Vector3(0, 0, -side * 0.25))
		_cyl("gold", s, 0.075, 0.075, 0.016, 10, tilt, 1.15)
		_cyl("accent", s + tilt * Vector3(-side * 0.01, 0.012, 0), 0.05, 0.045, 0.012, 10, tilt, 1.15)
		for k in 7:
			var a := lerpf(-PI * 0.5, PI * 0.5, k / 6.0)
			var p := s + tilt * Vector3(side * 0.07 * cos(a), -0.005, 0.085 * sin(a))
			_cyl("gold", p + Vector3(0, -0.03, 0), 0.009, 0.007, 0.06, 5)


func _pauldrons() -> void:
	for side: float in [-1.0, 1.0]:
		var s := _shoulder(side) + Vector3(side * 0.035, -0.03, 0)
		var tilt := Basis.from_euler(Vector3(0, 0, -side * 0.45))
		var rings: Array = []
		for k in 4:
			var a := k / 3.0 * PI * 0.5
			rings.append(_ellipse(10, 0.1 * cos(a) + 0.004, 0.115 * cos(a) + 0.004, 0.085 * sin(a)).map(func(p): return s + tilt * p))
		_loft("steel", rings)
		_loft("accent", [_ellipse(10, 0.106, 0.121, -0.012).map(func(p): return s + tilt * p), _ellipse(10, 0.106, 0.121, 0.012).map(func(p): return s + tilt * p)])
		_ball("gold", s + tilt * Vector3(0, 0.09, 0), 0.018, Vector3.ONE, 6, 3)


func _shoulder_spikes() -> void:
	for side: float in [-1.0, 1.0]:
		var s := _shoulder(side) + Vector3(side * 0.025, 0.0, 0)
		var tilt := Basis.from_euler(Vector3(0, 0, -side * 0.4))
		_cyl("silk", s, 0.085, 0.07, 0.03, 8, tilt, 1.2)
		for k in 3:
			var base := s + tilt * Vector3(0, 0.012, -0.055 + 0.055 * k)
			_cone("steel", base, base + tilt * Vector3(side * 0.02, 0.11 if k == 1 else 0.08, (k - 1) * 0.02), 0.022, 5)


func _drone() -> void:
	var c := _shoulder(1.0) + Vector3(0.1, 0.3, 0.06)
	_ball("steel", c, 1.0, Vector3(0.055, 0.04, 0.055), 8, 5)
	_ball("flame", c + Vector3(0, -0.004, -0.045), 0.02, Vector3(1, 1, 0.6), 6, 4)
	_cyl("accent", c + Vector3(0, 0.03, 0), 0.03, 0.02, 0.02, 8)
	for side: float in [-1.0, 1.0]:
		var hub := c + Vector3(side * 0.095, 0.02, 0)
		_segment("joint", c + Vector3(side * 0.04, 0.01, 0), hub, 0.012)
		_cyl("joint", hub + Vector3(0, 0.012, 0), 0.008, 0.008, 0.03, 5)
		_cyl("glass", hub + Vector3(0, 0.03, 0), 0.06, 0.06, 0.004, 10)
	_cyl("joint", c + Vector3(0, -0.05, 0.01), 0.006, 0.006, 0.04, 4)


func _boombox() -> void:
	var s := _shoulder(-1.0) + Vector3(-0.005, 0.065, 0.0)
	_box("joint", s, Vector3(0.24, 0.12, 0.075))
	_box("accent", s + Vector3(0, 0.045, -0.002), Vector3(0.245, 0.02, 0.078))
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	for side: float in [-1.0, 1.0]:
		_cyl("steel", s + Vector3(side * 0.07, -0.012, -0.036), 0.04, 0.04, 0.012, 10, facing)
		_cyl("silk", s + Vector3(side * 0.07, -0.012, -0.042), 0.03, 0.02, 0.01, 10, facing)
		_segment("steel", s + Vector3(side * 0.09, 0.06, 0), s + Vector3(side * 0.09, 0.1, 0), 0.01)
	_box("flame", s + Vector3(0, 0.015, -0.039), Vector3(0.04, 0.02, 0.006))
	_segment("steel", s + Vector3(-0.09, 0.1, 0), s + Vector3(0.09, 0.1, 0), 0.012)


func _bandolier() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var top := Vector3(maxf(f.chest_w * 0.72, 0.13), f.neck_y - 0.02, 0.0)
	var low_front := Vector3(-maxf(f.chest_w * 0.62, 0.11), f.chest_bottom + 0.04, f.chest_front - 0.012)
	var low_back := Vector3(-maxf(f.chest_w * 0.62, 0.11), f.chest_bottom + 0.04, back + 0.012)
	var up_front := Vector3(top.x * 0.85, f.neck_y - 0.06, minf(f.collar_front, f.chest_front + 0.04) - 0.012)
	_segment("leather", top, up_front, 0.05, Vector3.BACK)
	_segment("leather", up_front, low_front, 0.05, Vector3.BACK)
	_segment("leather", top, Vector3(top.x * 0.85, f.neck_y - 0.06, back * 0.8), 0.05, Vector3.BACK)
	_segment("leather", Vector3(top.x * 0.85, f.neck_y - 0.06, back * 0.8), low_back, 0.05, Vector3.BACK)
	var lean := _along(up_front - low_front)
	for k in 6:
		var p := low_front.lerp(up_front, (k + 0.6) / 6.5) + Vector3(0, 0, -0.016)
		_cyl("gold", p, 0.011, 0.011, 0.05, 6, lean * Basis.from_euler(Vector3(0, 0, PI * 0.5)))
		_cone("steel", p + lean * Vector3(0.025, 0, 0), p + lean * Vector3(0.045, 0, 0), 0.011, 6)


# ---------------------------------------------------------------------------
# Waist pieces. On the hips bone, round the top of the hips.

## A point on the waist line: angle 0 is the right side, -PI/2 the front; `out` beyond the body.
func _waist_point(a: float, out: float = 0.0, y: float = 0.0) -> Vector3:
	return Vector3((f.waist_w + out) * cos(a), f.waist_y + y, f.waist_cz + (f.waist_d + out) * sin(a))


func _buckle_belt() -> void:
	_band("leather", f.waist_w, f.waist_d, f.waist_y, 0.05, 0.008, f.waist_cz)
	var c := _waist_point(-PI * 0.5, 0.012)
	_box("gold", c, Vector3(0.1, 0.075, 0.016))
	_box("leather", c + Vector3(0, 0, -0.006), Vector3(0.062, 0.04, 0.012))
	_box("gold", c + Vector3(0.012, 0, -0.01), Vector3(0.04, 0.01, 0.01))


func _utility_belt() -> void:
	_band("joint", f.waist_w, f.waist_d, f.waist_y, 0.045, 0.008, f.waist_cz)
	for k in 7:
		var a := -PI * 0.5 + (k - 3) * 0.78
		if k == 3:
			continue
		var p := _waist_point(a, 0.03, -0.01)
		var turn := Basis.from_euler(Vector3(0, -a - PI * 0.5, 0))
		_box("leather" if k % 2 == 0 else "steel", p, Vector3(0.06, 0.075, 0.04), turn)
		_box("gold", p + Vector3(0, 0.02, 0) + turn * Vector3(0, 0, -0.022), Vector3(0.014, 0.014, 0.006), turn)
	_cyl("accent", _waist_point(-PI * 0.5, 0.014), 0.04, 0.04, 0.016, 8, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))


func _champion_belt() -> void:
	_band("silk", f.waist_w, f.waist_d, f.waist_y, 0.085, 0.008, f.waist_cz)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	var c := _waist_point(-PI * 0.5, 0.012)
	_cyl("gold", c, 0.085, 0.085, 0.018, 12, facing)
	_cyl("accent", c + Vector3(0, 0, -0.01), 0.045, 0.045, 0.012, 8, facing)
	_ball("gold", c + Vector3(0, 0, -0.018), 0.02, Vector3(1, 1, 0.5), 6, 3)
	for side: float in [-1.0, 1.0]:
		var a := -PI * 0.5 + side * 0.85
		_cyl("gold", _waist_point(a, 0.012), 0.045, 0.045, 0.014, 8, Basis.from_euler(Vector3(0, -a - PI * 0.5, 0)) * facing)


func _fanny_pack() -> void:
	_band("joint", f.waist_w, f.waist_d, f.waist_y, 0.03, 0.006, f.waist_cz)
	var c := _waist_point(-PI * 0.5 + 0.35, 0.035, -0.02)
	var turn := Basis.from_euler(Vector3(0, -0.35, 0))
	_ball("accent", c, 1.0, Vector3(0.085, 0.055, 0.045), 8, 5)
	_box("steel", c + turn * Vector3(0, 0.02, -0.04), Vector3(0.11, 0.008, 0.01), turn)
	_box("gold", c + turn * Vector3(0.05, 0.02, -0.044), Vector3(0.012, 0.022, 0.008), turn)


func _tutu() -> void:
	_band("accent", f.waist_w, f.waist_d, f.waist_y, 0.04, 0.008, f.waist_cz)
	var n := 24
	for layer in 2:
		var inner: Array = []
		var outer: Array = []
		for k in n + 1:
			var a := k * TAU / n
			var up := 0.035 if k % 2 == layer else -0.03
			inner.append(_waist_point(a, 0.0, -0.01 - 0.02 * layer))
			outer.append(_waist_point(a, 0.2 - 0.03 * layer, up - 0.03 - 0.05 * layer))
		_sheet("pink", [inner, outer], 0.008, Vector3.UP)


func _grass_skirt() -> void:
	_band("straw", f.waist_w, f.waist_d, f.waist_y, 0.04, 0.01, f.waist_cz)
	var n := 26
	for k in n:
		var a := k * TAU / n
		var top := _waist_point(a, 0.012, -0.01)
		var bottom := _waist_point(a + 0.04 * sin(k * 2.3), 0.07 + 0.02 * sin(k * 1.7), -0.3 - 0.04 * sin(k * 3.1))
		_segment("straw" if k % 3 != 0 else "leaf", top, bottom, 0.03, Vector3(cos(a), 0, sin(a)))
	for k in 5:
		var p := _waist_point(-PI * 0.5 + (k - 2) * 0.55, 0.022, 0.005)
		_ball(["pink", "hazard", "red"][k % 3], p, 0.026, Vector3(1, 0.8, 1), 6, 3)


func _pool_float() -> void:
	var c := Vector3(0, f.waist_y, f.waist_cz)
	var ring: Array = []
	for k in 15:
		ring.append(c + Vector3((f.waist_w + 0.1) * cos(k * TAU / 14), 0, (f.waist_d + 0.1) * sin(k * TAU / 14)))
	_tube("hazard", ring, 0.085, 0.085, 7)
	# A duck's head on the front.
	var head := _waist_point(-PI * 0.5, 0.16, 0.17)
	_tube("hazard", [_waist_point(-PI * 0.5, 0.12, 0.05), head], 0.05, 0.045, 7)
	_ball("hazard", head, 0.075, Vector3.ONE, 8, 5)
	_cone("orange", head + Vector3(0, -0.01, -0.06), head + Vector3(0, -0.02, -0.14), 0.035, 6, 0.5)
	for side: float in [-1.0, 1.0]:
		_ball("silk", head + Vector3(side * 0.04, 0.025, -0.055), 0.013, Vector3.ONE, 5, 3)


func _hula_hoop() -> void:
	var tilt := Basis.from_euler(Vector3(0.14, 0, 0.1))
	var c := Vector3(0.03, f.waist_y - 0.01, f.waist_cz)
	var n := 20
	for k in n:
		var a0 := k * TAU / n
		var a1 := (k + 1) * TAU / n
		_segment("accent" if k % 4 < 2 else "feather", c + tilt * Vector3(0.4 * cos(a0), 0, 0.4 * sin(a0)), c + tilt * Vector3(0.4 * cos(a1), 0, 0.4 * sin(a1)), 0.03, tilt.y)


# ---------------------------------------------------------------------------
# Tails. On the hips bone, out of the back.

## Where a tail leaves the body.
func _tail_root() -> Vector3:
	return Vector3(0, f.waist_y - 0.06, f.hip_back - 0.02)


func _fox_tail() -> void:
	var r := _tail_root()
	var path: Array = [r, r + Vector3(0, -0.02, 0.1), r + Vector3(0, 0.06, 0.22), r + Vector3(0, 0.2, 0.3), r + Vector3(0, 0.34, 0.33)]
	_tube_r("orange", path, [0.03, 0.055, 0.08, 0.085, 0.065], 8)
	_tube_r("feather", [path[4], path[4] + Vector3(0, 0.08, 0.0), path[4] + Vector3(0, 0.15, -0.02)], [0.066, 0.05, 0.004], 8)


func _monkey_tail() -> void:
	var r := _tail_root()
	var path: Array = [r, r + Vector3(0, -0.06, 0.12), r + Vector3(0, -0.02, 0.26), r + Vector3(0, 0.14, 0.34)]
	var c := r + Vector3(0, 0.24, 0.3)
	for k in 9:   # the curl at the end
		var a := -0.4 + k * 0.62
		path.append(c + Vector3(0, -sin(a + 1.2) * (0.1 - k * 0.009), cos(a + 1.2) * (0.1 - k * 0.009)))
	_tube("leather", path, 0.024, 0.012, 6)


func _bunny_tail() -> void:
	var r := _tail_root() + Vector3(0, 0.0, 0.035)
	_ball("feather", r, 0.065, Vector3.ONE, 8, 5)
	for k in 5:
		var a := k * TAU / 5
		_ball("feather", r + Vector3(0.04 * cos(a), 0.04 * sin(a), 0.02), 0.035, Vector3.ONE, 6, 4)


func _dino_tail() -> void:
	var r := _tail_root()
	var path: Array = [r + Vector3(0, 0, -0.03), r + Vector3(0, -0.08, 0.18), r + Vector3(0, -0.2, 0.38), r + Vector3(0, -0.27, 0.58)]
	_tube_r("moss", path, [0.085, 0.07, 0.045, 0.008], 8)
	for k in 3:
		var p: Vector3 = path[k].lerp(path[k + 1], 0.5)
		var rad: float = [0.075, 0.055, 0.025][k]
		_cone("accent", p + Vector3(0, rad * 0.7, 0), p + Vector3(0, rad + 0.07, 0.03), 0.03, 4, 0.35)


func _devil_tail() -> void:
	var r := _tail_root()
	var path: Array = [r, r + Vector3(0.02, -0.12, 0.12), r + Vector3(0.05, -0.2, 0.27), r + Vector3(0.06, -0.12, 0.4), r + Vector3(0.05, 0.03, 0.45)]
	_tube("red", path, 0.02, 0.011, 6)
	var tip: Vector3 = path[4]
	_plate("red", [tip + Vector3(0, 0.13, 0.02), tip + Vector3(0, 0.03, 0.07), tip + Vector3(0, -0.01, 0.0), tip + Vector3(0, 0.03, -0.05)], 0.016, Vector3.RIGHT)


func _scorpion_tail() -> void:
	var r := _tail_root()
	var prev := r
	for k in 7:
		var a := k / 6.0 * 2.5
		var p := r + Vector3(0, 0.36 * (1.0 - cos(a)) * 0.9, 0.3 * sin(a) + 0.04)
		var rad := lerpf(0.055, 0.035, k / 6.0)
		_ball("silk", p, rad, Vector3(1, 1, 1), 7, 4)
		_segment("joint", prev, p, 0.02)
		prev = p
	_ball("red", prev + Vector3(0, -0.02, -0.04), 0.04, Vector3(1, 1, 1), 7, 4)
	_cone("red", prev + Vector3(0, -0.03, -0.06), prev + Vector3(0, -0.11, -0.13), 0.022, 5)


func _peacock() -> void:
	var r := _tail_root() + Vector3(0, 0.02, 0.03)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	for k in 9:
		var a := lerpf(-1.25, 1.25, k / 8.0)
		var length := 0.62 - 0.08 * absf(a)
		var tip := r + Vector3(sin(a) * length, cos(a) * length, 0.1 + 0.05 * cos(a))
		_segment("moss", r, tip, 0.012, Vector3.BACK)
		_cyl("leaf", tip, 0.06, 0.06, 0.008, 8, facing, 1.25)
		_cyl("bluelens", tip + Vector3(0, 0, -0.006), 0.036, 0.036, 0.008, 8, facing, 1.2)
		_cyl("gold", tip + Vector3(0, -0.006, -0.011), 0.016, 0.016, 0.006, 6, facing)
	_ball("bluelens", r, 0.05, Vector3(1, 1, 0.7), 7, 4)


func _power_cord() -> void:
	var r := _tail_root()
	var path: Array = []
	for k in 9:
		var t := k / 8.0
		path.append(r + Vector3(0.06 * sin(t * 5.0) * t, -0.62 * t * t + 0.1 * sin(t * PI), 0.42 * t))
	_tube("silk", path, 0.014, 0.014, 5)
	_cyl("steel", r, 0.03, 0.03, 0.02, 8, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
	var end: Vector3 = path[8]
	var dir: Vector3 = (path[8] - path[7]).normalized()
	_box("joint", end + dir * 0.03, Vector3(0.05, 0.05, 0.06), _along(dir) * Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
	for side: float in [-1.0, 1.0]:
		_segment("steel", end + dir * 0.06 + Vector3(side * 0.012, 0, 0), end + dir * 0.1 + Vector3(side * 0.012, 0, 0), 0.008)


# ---------------------------------------------------------------------------
# The sci-fi pieces: robot-tech and space opera, with grim cathedral-tech, sleek
# alien armour and street-level cyberware in the mix. Their lights ("energy",
# "hardlight") shine in the player's trim colour; a colour picked for one paints
# its body (MAIN).

# Hats.

## A great spiked gear standing up behind the head, a lit core in its hub, chains
## hanging from it.
func _cog_halo() -> void:
	var c := Vector3(0, f.top - 0.05, f.cz + f.d + 0.07)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))   # its face to the back
	var r := 0.17
	_torus("steel", c, r, 0.035, 24, facing)
	for k in 16:   # the teeth
		var a := k * TAU / 16
		var out := Vector3(cos(a), sin(a), 0)
		_box("steel", c + out * (r + 0.03), Vector3(0.03, 0.03, 0.022), Basis(Vector3.BACK, a))
		if k % 4 == 0:
			_cone("gold", c + out * (r + 0.045), c + out * (r + 0.1), 0.014, 4)
	for k in 6:   # spokes
		var a := k * TAU / 6 + 0.26
		_segment("carbon", c + Vector3(cos(a), sin(a), 0) * 0.05, c + Vector3(cos(a), sin(a), 0) * (r - 0.01), 0.018, Vector3.BACK)
	_torus("energy", c, 0.12, 0.01, 20, facing)
	_cyl("gold", c, 0.055, 0.055, 0.03, 12, facing)
	_cyl("energy", c + Vector3(0, 0, 0.018), 0.036, 0.036, 0.01, 12, facing)
	for side: float in [-1.0, 1.0]:   # chain links hanging from the rim
		var top := c + Vector3(side * 0.09, -0.14, 0)
		for k in 4:
			var p := top + Vector3(0, -0.03 * k, 0)
			_torus("carbon", p, 0.011, 0.005, 6, Basis.from_euler(Vector3(0, PI * 0.5 * (k % 2), PI * 0.5)))
		_cone("gold", top + Vector3(0, -0.125, 0), top + Vector3(0, -0.16, 0), 0.014, 4)


## A deep hood, three lit optics staring out of its shadow, cables down the back.
func _machine_cowl() -> void:
	var w: float = f.w * 1.25
	var d: float = f.d * 1.25
	var cz: float = f.cz
	var top: float = f.top + 0.05
	var low: float = f.bottom - 0.03
	var rows: Array = []
	for i in 7:
		var t := i / 6.0
		var y := lerpf(top, low, t)
		var s := clampf(sqrt((top - y) / 0.09), 0.45, 1.0)   # rounds over the crown, then straight down: never inside the head
		var open := lerpf(0.1, 0.85, smoothstep(0.1, 0.55, t))   # the face's opening, widening down
		var row: Array = []
		for j in 15:
			var a := lerpf(-PI * 0.5 + open, PI * 1.5 - open, j / 14.0)
			var lip := 0.03 * (1.0 - t) * pow(maxf(-sin(a), 0.0), 2.0)   # a peak over the brow
			row.append(Vector3(w * s * cos(a), y, cz + d * s * sin(a) - lip))
		rows.append(row)
	_sheet("robe", rows, 0.014, Vector3.UP)
	_dome("robe", w * 0.52, d * 0.52, top - 0.004, 0.025, cz, 12, 3)
	var eye_y: float = f.get("eye_y", lerpf(f.bottom, f.top, 0.5))
	var front: float = minf(f.eye_z, f.front) - 0.012
	for k in 3:   # the optics: a triangle of them
		var p := Vector3([-0.04, 0.04, 0.0][k], eye_y + [0.012, 0.012, -0.035][k], front)
		_cyl("carbon", p + Vector3(0, 0, 0.004), 0.022, 0.018, 0.018, 8, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
		_ball("energy", p - Vector3(0, 0, 0.006), 0.013, Vector3(1, 1, 0.6), 6, 3)
	for side: float in [-1.0, 1.0]:   # cables from the back of the hood
		var a := Vector3(side * 0.05, low + 0.04, cz + d * 0.85)
		_tube("carbon", [a, a + Vector3(side * 0.02, -0.06, 0.03), a + Vector3(side * 0.03, -0.15, 0.02)], 0.012, 0.01, 5)
		_cyl("energy", a + Vector3(side * 0.03, -0.155, 0.02), 0.014, 0.014, 0.02, 6)


## Chrome swept back over the head into two blade horns, lit seams along it.
func _void_crest() -> void:
	var y: float = _rim(0.07)
	var w: float = f.w * 1.06
	var d: float = f.d * 1.08
	var cz: float = f.cz
	_dome("chrome", w, d, y, 0.1, cz, 16, 6)
	_band("carbon", w, d, y + 0.012, 0.026, 0.006, cz, 16)
	# A brow point out over the face.
	_plate("chrome", [Vector3(-0.05, y + 0.06, cz - d * 0.92), Vector3(0, y + 0.03, cz - d - 0.06), Vector3(0.05, y + 0.06, cz - d * 0.92),
		Vector3(0, y + 0.095, cz - d * 0.7)], 0.012, Vector3.UP)
	for side: float in [-1.0, 1.0]:
		# A horn: a blade from the temple, sweeping back and up.
		var root := Vector3(side * w * 0.8, y + 0.05, cz - d * 0.2)
		var blade := [root + Vector3(0, 0.035, -0.04), root + Vector3(side * 0.035, 0.075, 0.12), root + Vector3(side * 0.06, 0.13, 0.34),
			root + Vector3(side * 0.035, 0.035, 0.2), root + Vector3(0, -0.01, 0.05)]
		_plate("chrome", blade, 0.014, Vector3(side, 0.6, 0))
		_segment("energy", root + Vector3(side * 0.012, 0.04, -0.03), root + Vector3(side * 0.07, 0.13, 0.34), 0.008)
		_segment("energy", Vector3(side * w * 0.45, y + 0.075, cz - d * 0.75), Vector3(side * w * 0.5, y + 0.09, cz + d * 0.6), 0.007)
	_segment("energy", Vector3(0, y + 0.1, cz - d * 0.6), Vector3(0, y + 0.1, cz + d * 0.6), 0.008)


## A harness round the head: pods at the temples with cables to the back of the
## neck, a flip-down smoked visor, a little cooling fan.
func _netrunner_rig() -> void:
	var eye_y: float = f.get("eye_y", lerpf(f.bottom, f.top, 0.5))
	var y: float = lerpf(eye_y, f.top, 0.55)
	var w: float = f.w + 0.012
	var d: float = f.d + 0.012
	_torus("carbon", Vector3(0, y, f.cz), w, 0.016, 18, Basis.IDENTITY, d)
	_segment("carbon", Vector3(-w * 0.6, y, f.cz), Vector3(-w * 0.2, f.top + 0.006, f.cz), 0.014)
	_segment("carbon", Vector3(-w * 0.2, f.top + 0.006, f.cz), Vector3(w * 0.6, y, f.cz), 0.014)
	for side: float in [-1.0, 1.0]:
		var pod := Vector3(side * (w + 0.012), eye_y + 0.02, f.cz - 0.01)
		_box("carbon", pod, Vector3(0.03, 0.07, 0.07))
		_box("energy", pod + Vector3(side * 0.016, 0.012, -0.01), Vector3(0.004, 0.012, 0.04))
		var back := Vector3(side * 0.05, f.bottom - 0.03, f.cz + d)
		_tube("joint", [pod + Vector3(0, -0.03, 0.03), pod + Vector3(side * 0.01, -0.08, 0.09), back], 0.009, 0.009, 5)
		_tube("energy", [pod + Vector3(0, -0.02, 0.035), pod + Vector3(side * 0.012, -0.06, 0.1), back + Vector3(0, 0.02, -0.01)], 0.004, 0.004, 4)
		# The visor's arms, down from the pods.
		_segment("carbon", pod + Vector3(0, 0.025, -0.03), Vector3(side * w * 0.95, eye_y + 0.035, f.front + 0.01), 0.01)
	var vz: float = minf(f.eye_z, f.front) - 0.03
	var rows: Array = []
	for row in 2:
		var r: Array = []
		for k in 7:
			var u := k / 6.0 * 2.0 - 1.0
			r.append(Vector3(u * w * 0.95, eye_y + 0.035 - row * 0.05, vz + 0.035 * u * u + row * 0.012))
		rows.append(r)
	_sheet("smoke", rows, 0.006, Vector3.BACK)
	_segment("energy", Vector3(-w * 0.9, eye_y + 0.037, vz + 0.03), Vector3(w * 0.9, eye_y + 0.037, vz + 0.03), 0.005)
	var fan := Vector3(w + 0.03, eye_y + 0.02, f.cz - 0.01)
	var sideways := Basis.from_euler(Vector3(0, 0, PI * 0.5))
	_cyl("steel", fan, 0.026, 0.026, 0.012, 10, sideways)
	for k in 4:
		_box("joint", fan + Vector3(0.008, 0, 0), Vector3(0.004, 0.044, 0.008), Basis(Vector3.RIGHT, k * PI / 4))


## A blade of hard light down the middle of the head, on a steel spine.
func _plasma_mohawk() -> void:
	var y: float = f.top + 0.004
	var spine: Array = []
	for k in 7:
		var t := k / 6.0
		var a := lerpf(-1.2, 1.25, t)
		spine.append(Vector3(0, y - 0.05 * (1.0 - cos(a)) * 1.6, f.cz + f.d * 0.95 * sin(a)))
	for k in 6:
		_segment("steel", spine[k], spine[k + 1], 0.026)
		_box("energy", (spine[k] + spine[k + 1]) * 0.5 + Vector3(0, 0.014, 0), Vector3(0.03, 0.004, 0.01))
	var blade: Array = []
	for k in 7:
		var t := k / 6.0
		blade.append(spine[k] + Vector3(0, 0.03 + 0.12 * sin(t * PI * 0.8) + 0.04 * t, 0.02 * t))
	_plate("hardlight", [spine[0]] + blade + [spine[6]] + [spine[3]], 0.01, Vector3.RIGHT)
	for k in 6:
		_segment("energy", blade[k], blade[k + 1], 0.008)


## An armoured half-helm with a tall bristle crest from brow to nape.
func _warlord_crest() -> void:
	var y: float = _rim(0.06)
	var w: float = f.w * 1.07
	var d: float = f.d * 1.07
	var cz: float = f.cz
	_dome("steel", w, d, y, 0.095, cz, 16, 6)
	_band("gold", w, d, y + 0.01, 0.022, 0.006, cz, 16)
	_band("energy", w, d, y + 0.03, 0.006, 0.008, cz, 16)
	# The ridge, then the crest along it.
	var ridge: Array = []
	for k in 9:
		var a := lerpf(-1.25, 1.25, k / 8.0)
		ridge.append(Vector3(0, y + 0.095 * cos(a * 0.8) + 0.004, cz + d * sin(a)))
	for k in 8:
		_segment("gold", ridge[k], ridge[k + 1], 0.024)
	for k in 17:
		var t := k / 16.0
		var base: Vector3 = (ridge[int(t * 8.0 - 0.001)] as Vector3).lerp(ridge[mini(int(t * 8.0) + 1, 8)], fmod(t * 8.0, 1.0))
		var tall := 0.15 * sin(lerpf(0.25, 2.9, t)) + 0.03
		var lean := lerpf(-0.03, 0.09, t)
		_cone("red", base - Vector3(0, 0.01, 0), base + Vector3(0, tall, lean), 0.022, 4, 0.35)


## A ring of floating blades above the head, round a thin ring of light.
func _blade_halo() -> void:
	var c := Vector3(0, f.top + 0.045, f.cz)
	var r: float = maxf(f.w, f.d) * 1.1
	_torus("energy", c, r * 0.8, 0.009, 24)
	for k in 10:
		var a := k * TAU / 10 + PI * 0.1
		var out := Vector3(cos(a), 0, sin(a))
		var side := out.cross(Vector3.UP)
		var base := c + out * r * 0.85
		var tip := base + out * 0.09 + Vector3(0, 0.13, 0)
		var lean := (tip - base).normalized()
		_plate("chrome", [base + side * 0.022, base + lean * 0.08 + side * 0.016, tip, base + lean * 0.08 - side * 0.012, base - side * 0.022], 0.008, -out)
		_box("carbon", base, Vector3(0.026, 0.016, 0.026), Basis(Vector3.UP, -a))


## A chrome skull on the brow, its eyes lit, on a spiked band.
func _skull_crown() -> void:
	var y: float = _rim(0.035)
	var w: float = f.w + 0.006
	var d: float = f.d + 0.006
	var cz: float = f.cz
	_band("carbon", w, d, y, 0.03, 0.006, cz, 18)
	for k in 12:
		var a := k * TAU / 12 + PI * 0.5
		if absf(sin(a) + 1.0) < 0.2:
			continue   # the skull sits at the front
		var p := Vector3(w * 1.02 * cos(a), y + 0.012, cz + d * 1.02 * sin(a))
		_cone("chrome", p, p + Vector3(0, 0.075, 0), 0.014, 4)
	var s := Vector3(0, y + 0.06, cz - d - 0.016)
	_ball("chrome", s, 1.0, Vector3(0.058, 0.055, 0.05), 9, 5)
	_box("chrome", s + Vector3(0, -0.055, -0.01), Vector3(0.056, 0.03, 0.042))
	for side: float in [-1.0, 1.0]:
		_ball("carbon", s + Vector3(side * 0.022, -0.006, -0.039), 1.0, Vector3(0.018, 0.017, 0.012), 6, 3)
		_ball("energy", s + Vector3(side * 0.022, -0.006, -0.045), 0.009, Vector3.ONE, 5, 3)
	for k in 4:
		_box("carbon", s + Vector3(-0.021 + k * 0.014, -0.062, -0.031), Vector3(0.006, 0.018, 0.004))
	_cone("carbon", s + Vector3(0, -0.026, -0.046), s + Vector3(0, -0.04, -0.049), 0.009, 3)


# Faces.

## An eyepiece on an arm from the temple, a lit reticle on its screen.
func _hud_eyepiece() -> void:
	var x := _lens_x()
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.03
	var temple := Vector3(-(f.w + 0.01), y + 0.01, f.cz)
	_box("carbon", temple, Vector3(0.02, 0.05, 0.06))
	_cyl("energy", temple + Vector3(-0.011, 0, 0), 0.01, 0.01, 0.004, 6, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	var corner := Vector3(-(f.w + 0.012), y + 0.012, f.front + 0.005)
	_segment("carbon", temple + Vector3(0, 0, -0.03), corner, 0.012)
	_segment("carbon", corner, Vector3(-x - 0.03, y + 0.01, z), 0.012)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	var lens := Vector3(-x, y, z)
	_box("carbon", lens + Vector3(0, 0, 0.004), Vector3(0.062, 0.05, 0.01))
	_cyl("hardlight", lens - Vector3(0, 0, 0.003), 0.024, 0.024, 0.004, 12, facing)
	_torus("energy", lens - Vector3(0, 0, 0.006), 0.016, 0.003, 12, facing)
	_box("energy", lens - Vector3(0, 0, 0.007), Vector3(0.03, 0.002, 0.002))
	_box("energy", lens - Vector3(0, 0, 0.007), Vector3(0.002, 0.03, 0.002))


## A mask over the mouth: vents, two canisters, lit tubes back round the head.
func _rebreather() -> void:
	var y: float = f.mouth_y + 0.005
	var z: float = f.mouth_z - 0.022
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	_ball("carbon", Vector3(0, y, z + 0.012), 1.0, Vector3(0.065, 0.048, 0.032), 10, 5)
	_cyl("steel", Vector3(0, y - 0.004, z - 0.016), 0.03, 0.026, 0.02, 10, facing)
	for k in 3:
		_box("energy", Vector3(0, y - 0.016 + k * 0.012, z - 0.027), Vector3(0.034, 0.004, 0.003))
	for side: float in [-1.0, 1.0]:
		var can := Vector3(side * 0.06, y - 0.018, z + 0.02)
		_cyl("steel", can, 0.019, 0.019, 0.06, 8, Basis.from_euler(Vector3(0.35, 0, -side * 0.5)))
		_cyl("energy", can + Vector3(side * 0.012, -0.024, -0.008), 0.012, 0.012, 0.008, 8, Basis.from_euler(Vector3(0.35, 0, -side * 0.5)))
		var ear := Vector3(side * (f.w + 0.008), y + 0.02, f.cz)
		_tube("joint", [Vector3(side * 0.05, y + 0.01, z + 0.02), Vector3(side * (f.w * 0.9), y + 0.016, f.front + 0.02), ear], 0.008, 0.008, 5)
		_segment("energy", Vector3(side * (f.w * 0.9), y + 0.026, f.front + 0.02), ear + Vector3(0, 0.01, 0), 0.004)
	_torus("joint", Vector3(0, y + 0.02, f.cz), f.w + 0.006, 0.01, 16, Basis.IDENTITY, f.d + 0.008)


## A see-through shield of light across the eyes, on a band round the head.
func _holo_visor() -> void:
	var y: float = f.eye_y
	var w: float = f.w + 0.014
	var z: float = minf(f.eye_z, f.front) - 0.026
	_torus("carbon", Vector3(0, y + 0.012, f.cz), w, 0.012, 18, Basis.IDENTITY, f.d + 0.014)
	for side: float in [-1.0, 1.0]:
		_cyl("steel", Vector3(side * w, y + 0.006, f.front + 0.012), 0.016, 0.016, 0.014, 8, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	var rows: Array = []
	for row in 2:
		var r: Array = []
		for k in 9:
			var u := k / 8.0 * 2.0 - 1.0
			r.append(Vector3(u * w, y + 0.035 - row * 0.065 + 0.012 * u * u * row, z + 0.04 * u * u))
		rows.append(r)
	_sheet("hardlight", rows, 0.004, Vector3.BACK)
	for row in 2:
		for k in 8:
			_segment("energy", rows[row][k] - Vector3(0, 0, 0.002), rows[row][k + 1] - Vector3(0, 0, 0.002), 0.004)


## Three little camera lenses over one eye, in a housing strapped to the head.
func _optic_cluster() -> void:
	var x := _lens_x()
	var y: float = f.eye_y
	var z: float = f.eye_z - 0.02
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	var c := Vector3(x, y, z)
	_box("carbon", c + Vector3(0.004, 0, 0.004), Vector3(0.075, 0.07, 0.022))
	var lenses := [[Vector3(-0.012, 0.01, 0), 0.022, 0.045], [Vector3(0.022, 0.018, 0), 0.012, 0.03], [Vector3(0.018, -0.022, 0), 0.01, 0.025]]
	for l in lenses:
		var p: Vector3 = c + (l[0] as Vector3) - Vector3(0, 0, l[2] * 0.5)
		_cyl("steel", p, l[1] + 0.006, l[1] + 0.004, l[2], 10, facing)
		_cyl("energy", p - Vector3(0, 0, l[2] * 0.5 + 0.001), l[1], l[1], 0.003, 10, facing)
	_torus("carbon", Vector3(0, y + 0.01, f.cz), f.w + 0.006, 0.01, 16, Basis.IDENTITY, f.d + 0.008)
	_box("energy", c + Vector3(-0.03, -0.028, -0.012), Vector3(0.008, 0.006, 0.003))


# Neckwear.

## A thick collar with lit core segments round the front.
func _power_collar() -> void:
	var rz: float = maxf(0.11, -f.collar_front + 0.01)
	var c := Vector3(0, f.neck_y - 0.005, 0)
	_torus("carbon", c, 0.13, 0.05, 18, Basis.IDENTITY, rz)
	_torus("steel", c + Vector3(0, 0.026, 0), 0.128, 0.016, 18, Basis.IDENTITY, rz)
	for k in 7:
		var a := -PI * 0.5 + (k - 3) * 0.42
		var p := Vector3(0.155 * cos(a), c.y, (rz + 0.025) * sin(a))
		_box("energy", p, Vector3(0.026, 0.028, 0.012), Basis(Vector3.UP, -a - PI * 0.5))
		_box("steel", p + Vector3(0, 0.022, 0), Vector3(0.03, 0.008, 0.016), Basis(Vector3.UP, -a - PI * 0.5))


## A sleek ring round the neck with a comm badge at the throat.
func _comm_torque() -> void:
	var rz: float = maxf(0.11, -f.collar_front + 0.01)
	_torus("chrome", Vector3(0, f.neck_y - 0.015, 0), 0.128, 0.026, 20, Basis.IDENTITY, rz)
	_torus("energy", Vector3(0, f.neck_y - 0.002, 0), 0.128, 0.006, 20, Basis.IDENTITY, rz)
	var b := _collar() + Vector3(0, -0.02, -0.008)
	var hexagon: Array = []
	for k in 6:
		hexagon.append(b + Vector3(cos(k * TAU / 6) * 0.034, sin(k * TAU / 6) * 0.034, 0))
	_plate("chrome", hexagon, 0.01, Vector3.BACK)
	_cyl("energy", b + Vector3(0, 0, -0.004), 0.016, 0.016, 0.006, 10, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
	for side: float in [-1.0, 1.0]:
		_segment("energy", b + Vector3(side * 0.03, 0.01, -0.004), b + Vector3(side * 0.075, 0.03, 0.01), 0.005)


## Cables from the back of the neck, over the shoulders, into sockets on the chest.
func _cable_bundle() -> void:
	var front: float = minf(f.collar_front, f.chest_front + 0.05)
	var y: float = f.neck_y - 0.03
	_box("carbon", Vector3(0, y, 0.085), Vector3(0.16, 0.05, 0.05))
	_box("energy", Vector3(0, y + 0.005, 0.111), Vector3(0.1, 0.008, 0.002))
	for k in 4:
		var side := -1.0 if k < 2 else 1.0
		var lane := 0.0 if k % 3 == 0 else 1.0   # inner or outer
		var start := Vector3(side * (0.03 + 0.03 * lane), y, 0.08)
		var round := Vector3(side * (0.115 + 0.025 * lane), y - 0.01, 0.0)
		var plug := Vector3(side * (0.04 + 0.04 * lane), f.neck_y - 0.14 - 0.02 * lane, front - 0.012)
		_tube("joint" if k % 2 == 0 else "carbon", [start, round + Vector3(0, 0.012, 0.04), round, round.lerp(plug, 0.5) + Vector3(0, 0.01, -0.012), plug], 0.012, 0.012, 5)
		_cyl("steel", plug + Vector3(0, -0.008, 0.004), 0.018, 0.018, 0.026, 8)
		_torus("energy", plug + Vector3(0, -0.02, 0.004), 0.017, 0.004, 8)


# Shoulder pieces.

## A floating skull drone by the shoulder, one great lit eye, a grav ring under it.
func _servo_skull() -> void:
	var c := _shoulder(1.0) + Vector3(0.06, 0.27, 0.05)
	_ball("bone", c, 1.0, Vector3(0.055, 0.05, 0.06), 9, 5)
	_box("bone", c + Vector3(0, -0.05, -0.02), Vector3(0.05, 0.03, 0.04))
	for k in 4:
		_box("carbon", c + Vector3(-0.018 + k * 0.012, -0.058, -0.041), Vector3(0.006, 0.014, 0.004))
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	_cyl("carbon", c + Vector3(0.02, 0.004, -0.05), 0.024, 0.02, 0.03, 10, facing)
	_cyl("energy", c + Vector3(0.02, 0.004, -0.066), 0.016, 0.016, 0.004, 10, facing)
	_ball("carbon", c + Vector3(-0.022, 0.004, -0.048), 1.0, Vector3(0.014, 0.013, 0.008), 6, 3)
	_box("steel", c + Vector3(0, 0.03, 0.03), Vector3(0.05, 0.025, 0.04))
	_torus("energy", c + Vector3(0, -0.09, 0), 0.035, 0.006, 14)
	_torus("steel", c + Vector3(0, -0.075, 0), 0.025, 0.008, 10)
	_tube("joint", [c + Vector3(0, -0.06, 0.03), c + Vector3(0.01, -0.12, 0.04), c + Vector3(-0.01, -0.17, 0.03)], 0.005, 0.003, 4)


## An articulated arm rising over the shoulder, a claw at its end.
func _mech_arm() -> void:
	var s := _shoulder(1.0) + Vector3(-0.02, 0.03, 0.05)
	_box("steel", s, Vector3(0.09, 0.05, 0.1))
	_box("hazard", s + Vector3(0, 0.026, 0.03), Vector3(0.09, 0.004, 0.02))
	var j1 := s + Vector3(0.02, 0.2, 0.09)
	var j2 := j1 + Vector3(-0.03, 0.09, -0.2)
	var tip := j2 + Vector3(0.0, -0.06, -0.08)
	_segment("steel", s + Vector3(0, 0.02, 0), j1, 0.04)
	_segment("joint", s + Vector3(0.02, 0.02, 0.03), j1 + Vector3(0.02, -0.04, 0), 0.014)
	_segment("steel", j1, j2, 0.034)
	_segment("steel", j2, tip, 0.028)
	for j in [j1, j2, tip]:
		_ball("carbon", j, 0.03, Vector3.ONE, 8, 4)
		_torus("energy", j, 0.031, 0.005, 10, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	var dir := (tip - j2).normalized()
	for k in 3:
		var a := k * TAU / 3
		var out := Vector3(cos(a), sin(a) * 0.6, 0) * 0.025
		_cone("chrome", tip + out, tip + dir * 0.07 + out * 0.3, 0.01, 4)


## A rack of missiles on the shoulder, their tips lit.
func _missile_pod() -> void:
	var s := _shoulder(1.0) + Vector3(0.02, 0.12, 0.03)
	var tilt := Basis.from_euler(Vector3(0.15, 0, 0))
	_box("steel", s + Vector3(0, -0.07, 0.0), Vector3(0.05, 0.06, 0.06))
	_box("steel", s, Vector3(0.13, 0.1, 0.2), tilt)
	_box("hazard", s + tilt * Vector3(0, 0.051, 0.04), Vector3(0.13, 0.004, 0.03), tilt)
	var facing := tilt * Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	for row in 2:
		for col in 3:
			var p := s + tilt * Vector3(-0.038 + col * 0.038, -0.02 + row * 0.04, -0.1)
			_cyl("carbon", p, 0.016, 0.016, 0.01, 8, facing)
			_cone("energy", p + tilt * Vector3(0, 0, 0.004), p + tilt * Vector3(0, 0, -0.02), 0.011, 6)
	_box("carbon", s + tilt * Vector3(0.068, 0, 0.03), Vector3(0.012, 0.06, 0.1), tilt)


## A floating companion: a chrome orb with three fins, a lit eye and a halo under it.
func _sentinel() -> void:
	var c := _shoulder(-1.0) + Vector3(-0.07, 0.28, 0.05)
	_ball("chrome", c, 1.0, Vector3(0.045, 0.05, 0.045), 10, 6)
	_torus("energy", c + Vector3(0, 0.0, 0), 0.047, 0.006, 16, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
	_ball("energy", c + Vector3(0, 0.008, -0.044), 1.0, Vector3(0.016, 0.01, 0.008), 6, 3)
	for k in 3:
		var a := k * TAU / 3 + PI * 0.5
		var out := Vector3(cos(a), 0, sin(a))
		var root := c + out * 0.04
		_plate("carbon", [root + Vector3(0, 0.03, 0), root + out * 0.07 + Vector3(0, 0.07, 0), root + out * 0.045 + Vector3(0, -0.02, 0), root + Vector3(0, -0.03, 0)],
			0.008, out.cross(Vector3.UP))
	_torus("hardlight", c + Vector3(0, -0.075, 0), 0.04, 0.01, 16)


# Back pieces.

## Blades of hard light fanned out from two emitters between the shoulders.
func _energy_wings() -> void:
	var back: float = maxf(f.chest_back, 0.1)
	var root_y: float = f.neck_y - 0.1
	for side: float in [-1.0, 1.0]:
		var root := Vector3(side * 0.06, root_y, back + 0.02)
		_box("steel", root, Vector3(0.05, 0.12, 0.04))
		_box("energy", root + Vector3(0, 0, 0.021), Vector3(0.012, 0.09, 0.002))
		for k in 3:
			var a := lerpf(0.55, 1.35, k / 2.0)
			var length: float = [0.66, 0.52, 0.38][k]
			var dir := Vector3(side * sin(a), cos(a) * 0.9 - 0.05, 0.3).normalized()
			var tip := root + dir * length
			var across := dir.cross(Vector3.BACK).normalized() * 0.06
			_plate("hardlight", [root + across * 0.4, root.lerp(tip, 0.55) + across, tip, root.lerp(tip, 0.6) - across * 0.5, root - across * 0.3], 0.008, Vector3.BACK)
			_segment("energy", root + across * 0.4, root.lerp(tip, 0.55) + across, 0.007)
			_segment("energy", root.lerp(tip, 0.55) + across, tip, 0.007)


## A short, sleek cape with armoured shoulder plates and lit trim (a cape: its own bone).
func _space_cape() -> void:
	var grid := _cape_grid(0.82, 1.15, 0.12)
	_sheet("silk", grid, 0.012, Vector3.FORWARD)
	var cols: int = grid[0].size()
	for i in grid.size() - 1:   # lit trim down both edges and along the hem
		for e in [0, cols - 1]:
			_segment("energy", grid[i][e] + Vector3(0, 0, 0.008), grid[i + 1][e] + Vector3(0, 0, 0.008), 0.008)
	for j in cols - 1:
		_segment("energy", grid[-1][j] + Vector3(0, 0, 0.008), grid[-1][j + 1] + Vector3(0, 0, 0.008), 0.008)
	var top_y: float = f.neck_y - 0.01
	var sw: float = f.chest_w
	for side: float in [-1.0, 1.0]:
		var s := Vector3(side * sw * 0.72, top_y + 0.01, 0.0)
		var tilt := Basis.from_euler(Vector3(0, 0, -side * 0.35))
		var rings: Array = []
		for k in 3:
			var a := k / 2.0 * PI * 0.5
			rings.append(_ellipse(10, 0.085 * cos(a) + 0.004, 0.11 * cos(a) + 0.004, 0.05 * sin(a)).map(func(p): return s + tilt * p))
		_loft("chrome", rings)
		_ball("energy", Vector3(side * sw * 0.7, top_y - 0.01, f.collar_front + 0.02), 0.018, Vector3(1, 1, 0.6), 6, 3)


## A tall comms mast from a box on the back: crossbars, a little dish, a lit tip.
func _antenna_mast() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var base := Vector3(-0.07, f.neck_y - 0.12, back + 0.04)
	_box("steel", base, Vector3(0.09, 0.14, 0.06))
	_box("energy", base + Vector3(0, 0.03, 0.031), Vector3(0.05, 0.008, 0.002))
	var top := base + Vector3(-0.03, 0.62, 0.05)
	_segment("carbon", base + Vector3(0, 0.07, 0), top, 0.018)
	for k in 3:
		var p := base.lerp(top, 0.45 + k * 0.17)
		_segment("steel", p + Vector3(-0.05 + k * 0.012, 0, 0), p + Vector3(0.05 - k * 0.012, 0, 0), 0.01)
	_ball("energy", top + Vector3(0, 0.015, 0), 0.016, Vector3.ONE, 6, 4)
	var dish := base.lerp(top, 0.3) + Vector3(0.05, 0, 0.02)
	_segment("steel", base.lerp(top, 0.3), dish, 0.01)
	_cyl("steel", dish + Vector3(0.012, 0, 0), 0.045, 0.012, 0.02, 10, Basis.from_euler(Vector3(0, 0, -PI * 0.5)) * Basis.from_euler(Vector3(0.4, 0, 0)))
	_ball("energy", dish + Vector3(0.03, 0, 0), 0.008, Vector3.ONE, 5, 3)


## A great ring standing behind the back on two struts, lit inside, with nodes round it.
func _gyro_ring() -> void:
	var back: float = maxf(f.chest_back, 0.08)
	var c := Vector3(0, f.neck_y - 0.16, back + 0.1)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	_torus("steel", c, 0.3, 0.04, 28, facing)
	_torus("energy", c, 0.27, 0.01, 28, facing)
	for k in 4:
		var a := k * TAU / 4 + PI * 0.25
		var p := c + Vector3(cos(a), sin(a), 0) * 0.3
		_box("carbon", p, Vector3(0.06, 0.06, 0.06), Basis(Vector3.BACK, a))
		_box("energy", p + Vector3(0, 0, 0.031), Vector3(0.026, 0.026, 0.002), Basis(Vector3.BACK, a))
	for side: float in [-1.0, 1.0]:
		var on := Vector3(side * 0.07, c.y, back + 0.01)
		_segment("carbon", on, c + Vector3(side * 0.27, 0, 0), 0.03)
		_box("steel", on, Vector3(0.05, 0.08, 0.03))


# Waist pieces.

## A belt of lit power cells in steel holders.
func _cell_belt() -> void:
	_band("carbon", f.waist_w, f.waist_d, f.waist_y, 0.05, 0.008, f.waist_cz)
	for k in 9:
		var a := -PI * 0.5 + (k - 4) * 0.62
		if k == 4:
			continue
		var p := _waist_point(a, 0.026, -0.004)
		var turn := Basis.from_euler(Vector3(0, -a - PI * 0.5, 0))
		_box("steel", p, Vector3(0.034, 0.07, 0.03), turn)
		_cyl("energy", p + turn * Vector3(0, 0, -0.012), 0.011, 0.011, 0.056, 8)
	var c := _waist_point(-PI * 0.5, 0.014)
	var hexagon: Array = []
	for k in 6:
		hexagon.append(c + Vector3(cos(k * TAU / 6) * 0.04, sin(k * TAU / 6) * 0.04, 0))
	_plate("steel", hexagon, 0.014, Vector3.BACK)
	_cyl("energy", c + Vector3(0, 0, -0.008), 0.018, 0.018, 0.004, 6, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))


## Armoured plates hanging over the hips (a skirt: they move with the thighs) and
## two little thruster nozzles at the back.
func _thruster_skirt() -> void:
	_band("carbon", f.waist_w, f.waist_d, f.waist_y, 0.04, 0.01, f.waist_cz)
	for k in 6:
		var a := -PI * 0.5 + (k - 2.5) * 0.62
		var top := _waist_point(a, 0.02, -0.02)
		var bottom := _waist_point(a, 0.055, -0.2)
		var across := Vector3(-sin(a), 0, cos(a)) * 0.05
		_plate("steel", [top - across, top + across, bottom + across * 0.8, bottom - across * 0.8], 0.012, Vector3(cos(a), 0.1, sin(a)))
		_segment("energy", bottom - across * 0.7 + Vector3(cos(a), 0, sin(a)) * 0.008, bottom + across * 0.7 + Vector3(cos(a), 0, sin(a)) * 0.008, 0.006)
	for side: float in [-1.0, 1.0]:
		var n := _waist_point(PI * 0.5 + side * 0.55, 0.04, -0.06)
		var down := Basis.from_euler(Vector3(PI + 0.4, 0, 0))
		_cyl("steel", n, 0.03, 0.022, 0.06, 10, down)
		_cyl("energy", n + Vector3(0, -0.028, 0.012), 0.017, 0.017, 0.006, 10, down)


## A steel belt with a shield emitter at the front and a ring of hard light round it.
func _shield_belt() -> void:
	_band("steel", f.waist_w, f.waist_d, f.waist_y, 0.045, 0.008, f.waist_cz)
	var facing := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	var c := _waist_point(-PI * 0.5, 0.016)
	_cyl("chrome", c, 0.042, 0.038, 0.02, 12, facing)
	_cyl("energy", c + Vector3(0, 0, -0.011), 0.024, 0.024, 0.004, 12, facing)
	for k in 4:
		var a := k * TAU / 4 + PI * 0.25
		_box("carbon", c + Vector3(cos(a), sin(a), 0) * 0.042 + Vector3(0, 0, -0.004), Vector3(0.01, 0.01, 0.012))
	_torus("hardlight", Vector3(0, f.waist_y - 0.005, f.waist_cz), f.waist_w + 0.11, 0.012, 28, Basis.from_euler(Vector3(0.12, 0, 0)), f.waist_d + 0.11)
	for side: float in [-1.0, 1.0]:
		_box("steel", _waist_point(PI * 0.5 + side * PI * 0.5, 0.012), Vector3(0.02, 0.04, 0.05))


# Tails.

## A tail of steel segments with lit joints, a blade at its tip.
func _robo_tail() -> void:
	var r := _tail_root()
	var path: Array = []
	for k in 9:
		var t := k / 8.0
		var a := t * 2.2
		path.append(r + Vector3(0.02 * sin(t * 4.0), -0.06 * sin(t * PI) + 0.34 * (1.0 - cos(a)) * 0.6, 0.04 + 0.3 * sin(a)))
	for k in 8:
		var a: Vector3 = path[k]
		var b: Vector3 = path[k + 1]
		var rad := lerpf(0.032, 0.016, k / 7.0)
		_cyl("steel", a.lerp(b, 0.5), rad, rad * 0.9, a.distance_to(b) * 0.82, 8, _along(b - a))
		_torus("energy", b, rad * 0.85, 0.005, 8, _along(b - a))
	var tip: Vector3 = path[8]
	var dir: Vector3 = ((path[8] as Vector3) - (path[7] as Vector3)).normalized()
	_plate("chrome", [tip + Vector3(0.0, 0.02, 0), tip + dir * 0.09, tip + Vector3(0.0, -0.02, 0), tip - dir * 0.01], 0.01, Vector3.RIGHT)
	_ball("carbon", r + Vector3(0, 0, 0.03), 0.035, Vector3.ONE, 8, 4)


## A tapered ribbon of hard light flowing back from a little emitter.
func _light_streamer() -> void:
	var r := _tail_root()
	_cyl("chrome", r + Vector3(0, 0, 0.03), 0.03, 0.026, 0.05, 10, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
	_torus("energy", r + Vector3(0, 0, 0.056), 0.022, 0.005, 10, Basis.from_euler(Vector3(PI * 0.5, 0, 0)))
	var rows: Array = [[], []]
	for k in 10:
		var t := k / 9.0
		var spine := r + Vector3(0.07 * sin(t * 5.0) * t, -0.12 * t + 0.1 * sin(t * PI * 1.6) * t, 0.06 + 0.66 * t)
		var half := lerpf(0.065, 0.008, t)
		rows[0].append(spine + Vector3(-half, 0, 0))
		rows[1].append(spine + Vector3(half, 0, 0))
	_sheet("hardlight", rows, 0.006, Vector3.UP)
	for k in 9:
		for e in 2:
			_segment("energy", rows[e][k], rows[e][k + 1], 0.005)
