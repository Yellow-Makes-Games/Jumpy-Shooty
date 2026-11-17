class_name WeaponPickup
extends Node3D
## Deathmatch: a weapon floating over its spot (placed in a map with a MapWeaponSpawn),
## bobbing up and down and turning slowly over a glowing pad. Walk through it and the
## host gives you the weapon (Match._host_pickups); it vanishes and comes back
## Match.PICKUP_RESPAWN seconds later. It is only a picture: the host decides who
## took it, and every copy shows it gone or back when the host says so.

const HOVER := 1.0          ## metres above the floor marker (the middle of the bob)
const BOB_HEIGHT := 0.15    ## metres up and down from HOVER
const BOB_SPEED := 2.4      ## radians a second
const SPIN_SPEED := 1.3     ## radians a second
const SIZE := 2.2           ## drawn bigger than in a robot's hands, to be seen from afar
const GLOW := Color(1.0, 0.62, 0.18)

var index := 0
var weapon := "pistol"
## Where its middle is in the world: a player whose middle comes within
## Match.PICKUP_REACH of this takes it.
var spot := Vector3.ZERO

var _float: Node3D
var _pad_material: StandardMaterial3D
var _label: Label3D
var _t := 0.0
var _taken := false

static var _gun_meshes := {}


static func make(i: int, pos: Vector3, gun: String) -> WeaponPickup:
	var p := WeaponPickup.new()
	p.index = i
	p.weapon = WeaponData.valid(gun)
	p.name = "Pickup_%d_%s" % [i, p.weapon]
	p.position = pos
	p.spot = pos + Vector3(0, HOVER, 0)
	p._t = float(i) * 1.7   # neighbours bob out of step
	return p


func _ready() -> void:
	_float = Node3D.new()
	_float.name = "Float"
	add_child(_float)
	var model := Node3D.new()
	model.scale = Vector3.ONE * SIZE
	_float.add_child(model)
	if WeaponData.melee(weapon):
		_add_blade(model)
	else:
		_add_gun(model)
	# A glowing pad on the floor shows where it is (and stays, dimmed, while it is gone).
	_pad_material = StandardMaterial3D.new()
	_pad_material.albedo_color = Color(GLOW, 0.5)
	_pad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.03
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	pad.mesh = disc
	pad.position.y = 0.04
	pad.material_override = _pad_material
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pad)
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.position.y = 0.6
	light.shadow_enabled = false
	_float.add_child(light)
	_label = Label3D.new()
	_label.text = WeaponData.by_id(weapon).short_name.to_upper()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.outline_size = 10
	_label.modulate = Color(1, 1, 1, 0.9)
	_label.position.y = 0.55
	_label.no_depth_test = false
	_float.add_child(_label)
	set_taken(Match.pickups_taken.has(index))
	_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	_float.position.y = HOVER + sin(_t * BOB_SPEED) * BOB_HEIGHT
	_float.rotation.y = _t * SPIN_SPEED


func set_taken(taken: bool) -> void:
	_taken = taken
	_float.visible = not taken
	_pad_material.albedo_color = Color(GLOW, 0.15 if taken else 0.5)


func is_taken() -> bool:
	return _taken


## A gun: its surfaces cut out of a robot model file (every model holds every gun),
## unskinned and centred on its middle.
func _add_gun(model: Node3D) -> void:
	var mesh := gun_mesh(weapon)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = -mesh.get_aabb().get_center()
	# Lit trim, like the guns robots carry.
	for s in mesh.get_surface_count():
		var base := mesh.surface_get_material(s) as StandardMaterial3D
		if base and RobotModel.material_kind(base.resource_name) == "accent":
			var m: StandardMaterial3D = base.duplicate()
			m.albedo_color = GLOW
			m.emission_enabled = true
			m.emission = GLOW
			m.emission_energy_multiplier = 1.2
			mi.set_surface_override_material(s, m)
	# The model file holds the gun as the robot's hand does at rest (barrel down):
	# lay it flat, its longest side (the barrel) along x.
	var holder := Node3D.new()
	match mesh.get_aabb().get_longest_axis_index():
		Vector3.AXIS_Y:
			holder.rotation.z = PI * 0.5
		Vector3.AXIS_Z:
			holder.rotation.y = PI * 0.5
	holder.add_child(mi)
	model.add_child(holder)


## One gun's surfaces from the default robot's model file, without the skin (made once per gun).
static func gun_mesh(gun: String) -> Mesh:
	if _gun_meshes.has(gun):
		return _gun_meshes[gun]
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
			if not "." in mname or mname.get_slice(".", 0) != gun:
				continue
			var arrays := full.surface_get_arrays(s)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	node.free()
	_gun_meshes[gun] = out
	return out


## A blade or hammer: the same shapes a robot swings (see MeleeModel), lying on its side.
func _add_blade(model: Node3D) -> void:
	var holder := Node3D.new()
	holder.rotation = Vector3(0, 0, PI * 0.5)   # blade along the ground, like a gun
	model.add_child(holder)
	var parts := MeleeModel.parts(weapon)
	var top := 0.0
	for part in parts:
		top = maxf(top, (part[1] as Transform3D).origin.y)
	holder.position.x = top * 0.5   # turn about its middle, not the grip
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.transform = part[1]
		var kind: String = part[2]
		var m := StandardMaterial3D.new()
		m.albedo_color = {"steel": MeleeModel.STEEL, "dark": MeleeModel.DARK, "grip": MeleeModel.GRIP, "edge": GLOW,
			"wood": MeleeModel.WOOD}.get(kind, MeleeModel.DARK)
		m.roughness = 0.25 if kind == "steel" else 0.6
		m.metallic = 0.9 if kind == "steel" else 0.3
		if kind == "edge":
			m.emission_enabled = true
			m.emission = GLOW
			m.emission_energy_multiplier = 1.4
		mi.material_override = m
		holder.add_child(mi)
