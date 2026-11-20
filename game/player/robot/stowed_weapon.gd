class_name StowedWeapon
extends Node3D
## A weapon put away on a robot's body: looks only. Deathmatch lets you carry two; the
## one that is not in your hands rides here, where everyone else can see what you have
## (StowedWeapon.put_on, called by Player with what Net says you carry).
##
## Where it rides is WeaponDraw.carried's answer: a long gun or a big melee weapon goes
## across the back, its grip up at the right shoulder; a sidearm or a small blade on the
## right thigh; brass knuckles and claws on the belt; bare hands nowhere. A second one
## of the same kind goes on the other side (crossed on the back, or on the left thigh).
## A body wearing something on its back (a cape, wings, a pack) slings long weapons at
## its left side instead, so neither hides the other.
##
## Put away mid-match, it flies from the hand to its place (fly_from). The weapon that
## leaves your hands for good (Gun Game's last one, one swapped out for a pickup) breaks
## up into light where it was instead (StowedWeapon.break_up).

const FLY := 0.22          ## seconds from the hand to its place
const BREAK_UP := 0.3      ## seconds a weapon let go takes to break up into light...
const BREAK_FROM := 0.25   ## ...already this far gone as it is let go (the new one is in the hand at once)
const LIT := 0.7           ## how brightly its trim shines, of a weapon in the hand
## Each place, on its bone, in the body's own axes at rest (x right, y up, z back) from
## the bone: where the grip is, and which way the weapon points (its muzzle or blade)
## and faces (a gun's top, a blade's flat).
const PLACES := {
	"back": {"bone": "chest", "at": Vector3(0.13, 0.26, 0.15), "points": Vector3(-0.45, -0.89, 0.0), "faces": Vector3(-0.89, 0.45, 0.0)},
	"back_2": {"bone": "chest", "at": Vector3(-0.13, 0.26, 0.20), "points": Vector3(0.45, -0.89, 0.0), "faces": Vector3(0.89, 0.45, 0.0)},
	"sling": {"bone": "chest", "at": Vector3(-0.24, 0.10, 0.03), "points": Vector3(0.0, -1.0, 0.0), "faces": Vector3(0.0, 0.0, 1.0)},
	"sling_2": {"bone": "chest", "at": Vector3(0.24, 0.10, 0.03), "points": Vector3(0.0, -1.0, 0.0), "faces": Vector3(0.0, 0.0, 1.0)},
	"thigh": {"bone": "thigh_r", "at": Vector3(0.085, -0.10, 0.0), "points": Vector3(0.0, -1.0, 0.0), "faces": Vector3(0.0, 0.0, -1.0)},
	"thigh_2": {"bone": "thigh_l", "at": Vector3(-0.085, -0.10, 0.0), "points": Vector3(0.0, -1.0, 0.0), "faces": Vector3(0.0, 0.0, -1.0)},
	"belt": {"bone": "hips", "at": Vector3(0.14, 0.04, 0.09), "points": Vector3(0.0, -1.0, 0.0), "faces": Vector3(0.0, 0.0, 1.0)},
	"belt_2": {"bone": "hips", "at": Vector3(-0.14, 0.04, 0.09), "points": Vector3(0.0, -1.0, 0.0), "faces": Vector3(0.0, 0.0, 1.0)},
}
## A long gun rides with its middle on the back, not its grip: it is moved this far back along itself.
const GUN_SLIDE := 0.12
## A melee weapon's grip rides at least this much higher than a gun's (its handle stands over the shoulder)...
const BLADE_UP := 0.08
const BLADE_MOST := 0.4   ## ...and the longest ones this much

var weapon := ""
var place := ""

var _rest := Transform3D.IDENTITY
var _from := Transform3D.IDENTITY
var _fly := -1.0
var _melt: Dissolve
var _melt_t := -1.0
var _drift := Vector3.ZERO

static var _gun_meshes := {}                    # look -> its mesh, cut out of a robot model file
static var _gun_frame := Transform3D.IDENTITY   # from the model files' space to a gun's own
static var _gun_frame_known := false


## Puts `weapons` (ids) away on `model`'s body, in the player's `color`. `character`:
## whose body it is (one wearing something on its back slings them at its side).
## `layer`: the render layer the body is on (0: leave them on the default one).
## Returns them by weapon id.
static func put_on(model: RobotModel, weapons: Array, color: Color, character: String, layer: int = 0) -> Dictionary:
	var out := {}
	if model == null or model.skeleton == null:
		return out
	var taken := {}
	for id in weapons:
		var at := place_for(str(id), character)
		if at == "":
			continue
		if taken.has(at):
			at += "_2"
			if taken.has(at):
				continue   # (two is all anybody carries)
		taken[at] = true
		var spot: Dictionary = PLACES[at]
		var bone := model.skeleton.find_bone(str(spot.bone))
		if bone < 0:
			continue
		var hook := BoneAttachment3D.new()
		hook.name = "Stowed_" + at
		hook.bone_name = str(spot.bone)
		model.skeleton.add_child(hook)
		var prop := build(str(id), color)
		prop.place = at
		# The place is given in the body's axes at rest: into the bone's own.
		var rest := model.skeleton.get_bone_global_rest(bone).basis.orthonormalized().inverse()
		prop._rest = Transform3D(rest * _basis(str(id), spot), rest * _grip(str(id), spot))
		prop.transform = prop._rest
		hook.add_child(prop)
		if layer > 0:
			for mi in prop.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).layers = 1 << (layer - 1)
		out[str(id)] = prop
	return out


## Which of PLACES a weapon rides at on this body ("" for bare hands).
static func place_for(id: String, character: String) -> String:
	var at := WeaponDraw.carried(id)
	if at == "none":
		return ""
	if at == "back" and wears_on_back(character):
		return "sling"
	return at


## This body has something on its back (a Character Creator cape, wings, pack...).
static func wears_on_back(character: String) -> bool:
	if not CustomCharacter.is_custom(character):
		return false
	return str(CustomCharacter.parse(character).accessories.get("back", "")) != ""


## The weapon on its own, as it looks in the hand, in the player's `color`: a gun in gun
## space (x right, y up, -z forward, from the grip), a melee weapon in its own (the
## blade up +y).
static func build(id: String, color: Color) -> StowedWeapon:
	var prop := StowedWeapon.new()
	prop.weapon = id
	prop.name = "Weapon_" + id
	var trim := RobotModel.trim_color(color)
	var look := WeaponData.look_of(id)
	if WeaponData.melee(look):
		var blade := MeleeModel.build(look, trim)
		MeleeModel.set_glow(prop_holder(prop, blade), LIT)
		return prop
	var mesh := gun_mesh(look)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = _gun_space()
	for s in mesh.get_surface_count():
		var base := mesh.surface_get_material(s) as StandardMaterial3D
		if base and RobotModel.material_kind(base.resource_name) in ["accent", "glow"]:
			var m: StandardMaterial3D = base.duplicate()
			m.albedo_color = trim
			m.emission_enabled = true
			m.emission = trim
			m.emission_energy_multiplier = RobotModel.GUN_GLOW_ENERGY * LIT
			mi.set_surface_override_material(s, m)
	prop.add_child(mi)
	return prop


## A gun's surfaces cut out of a robot model file (every model holds every gun),
## unskinned: as the file has it, in the hand of a body at rest (see _gun_space).
## (WeaponPickup has its own copy of this: it needs the match, and this must not.)
static func gun_mesh(look: String) -> Mesh:
	if _gun_meshes.has(look):
		return _gun_meshes[look]
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	var node := rig.scene.instantiate()
	var full: Mesh = null
	for c in node.find_children("*", "MeshInstance3D", true, false):
		full = (c as MeshInstance3D).mesh
		break
	var out := ArrayMesh.new()
	if full:
		for s in full.get_surface_count():
			var mat := full.surface_get_material(s)
			var mname := mat.resource_name if mat else ""
			if not "." in mname or mname.get_slice(".", 0) != look:
				continue
			var arrays := full.surface_get_arrays(s)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	node.free()
	_gun_meshes[look] = out
	return out


# (MeleeModel.set_glow wants the node the weapon's holder hangs from.)
static func prop_holder(prop: StowedWeapon, blade: Node3D) -> Node3D:
	prop.add_child(blade)
	return prop


## The weapon was in the hand at `hand` (in the world) a moment ago: it flies from there
## to its place.
func fly_from(hand: Transform3D) -> void:
	_from = hand
	_fly = 0.0
	if is_inside_tree():
		global_transform = hand


## A weapon let go for good: it breaks up into light of the player's `color` where it was
## (`at`, in the world), drifting along at `velocity`, and is gone. Added to `parent`.
static func break_up(parent: Node, id: String, color: Color, at: Transform3D, velocity: Vector3 = Vector3.ZERO) -> StowedWeapon:
	if parent == null or not WeaponData.has(id) or WeaponDraw.carried(id) == "none":
		return null
	var prop := build(id, color)
	prop.name = "Dropped_" + id
	prop.top_level = true
	parent.add_child(prop)
	prop.global_transform = at.orthonormalized()
	prop._melt = Dissolve.prepare(prop, RobotModel.trim_color(color))
	prop._melt_t = 0.0
	prop._melt.set_progress(BREAK_FROM)
	prop._drift = velocity * 0.5 + Vector3(0.0, 0.7, 0.0)
	for mi in prop.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return prop


func _process(delta: float) -> void:
	if _melt_t >= 0.0:
		_melt_t += delta
		global_position += _drift * delta
		_melt.set_progress(lerpf(BREAK_FROM, 1.0, _melt_t / BREAK_UP))
		if _melt_t >= BREAK_UP:
			queue_free()
		return
	if _fly < 0.0:
		return
	_fly += delta
	var parent := get_parent() as Node3D
	if _fly >= FLY or parent == null:
		_fly = -1.0
		transform = _rest
		return
	var u := smoothstep(0.0, 1.0, _fly / FLY)
	global_transform = _from.orthonormalized().interpolate_with(parent.global_transform * _rest, u)


## Still on its way from the hand.
func flying() -> bool:
	return _fly >= 0.0


static func _basis(id: String, spot: Dictionary) -> Basis:
	var points := (spot.points as Vector3).normalized()
	var faces := (spot.faces as Vector3).normalized()
	if WeaponData.melee(WeaponData.look_of(id)):
		# The blade (+y) points along the place; its edge (-z) lies in the body's surface.
		var x := faces
		return Basis(x, points, x.cross(points)).orthonormalized()
	# The muzzle (-z) points along the place, the gun's top (+y) where the place faces.
	var z := -points
	return Basis(faces.cross(z), faces, z).orthonormalized()


static func _grip(id: String, spot: Dictionary) -> Vector3:
	var points := (spot.points as Vector3).normalized()
	var at: Vector3 = spot.at
	var look := WeaponData.look_of(id)
	if WeaponData.melee(look):
		# (A long blade rides higher: its handle stands over the shoulder and its point clears the floor.)
		var edge: Array = MeleeModel.EDGES.get(look, [0.0, 0.3])
		return at - points * (clampf(float(edge[1]) * 0.3 - 0.1, BLADE_UP, BLADE_MOST) if str(spot.bone) == "chest" else 0.0)
	if str(spot.bone) == "chest":
		return at + points * GUN_SLIDE
	return at


## From the space the model files hold a gun in (in the hand of a body at rest) to the
## gun's own.
static func _gun_space() -> Transform3D:
	if _gun_frame_known:
		return _gun_frame
	var rig := RobotRig.open(Characters.body(Characters.default_id()))
	var node := rig.scene.instantiate()
	for c in node.find_children("*", "Skeleton3D", true, false):
		var sk := c as Skeleton3D
		var bone := sk.find_bone("pistol")
		if bone >= 0:
			var grip := sk.get_bone_global_rest(bone)
			_gun_frame = (grip * Transform3D(GunRecoil.REST, Vector3.ZERO)).affine_inverse()
		break
	node.free()
	_gun_frame_known = true
	return _gun_frame
