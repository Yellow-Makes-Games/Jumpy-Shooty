class_name MeleeModel
extends RefCounted
## The melee weapons' looks (sword, hammer, dagger, brass knuckles, spear, axe, bat), built from simple shapes and
## carried in the robot's fist on its "pistol" bone (the grip). The guns live in the
## robot model files; the blades are made here so they need no new model files.
##
## Built in weapon space: the grip at the origin, the blade or shaft up +Y, the
## robot's forward -Z (with the arm held out in the aim pose).

const STEEL := Color(0.78, 0.8, 0.83)
const DARK := Color(0.16, 0.17, 0.19)
const GRIP := Color(0.1, 0.1, 0.11)
const VIEW_SHADER := "res://game/player/robot/viewmodel.gdshader"
## From weapon space to the grip bone's space: its -Z is up and -Y forward in the aim pose.
const TO_BONE := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
## The blade leans forward a little in the ready stance.
const READY_TILT := -0.45
## How far up the weapon its cutting edge runs (from, to), in metres from the grip.
const EDGES := {"sword": [0.3, 1.0], "hammer": [0.55, 0.9], "dagger": [0.12, 0.45],
	"brass_knuckles": [0.0, 0.1], "spear": [0.95, 1.5], "axe": [0.52, 0.8], "bat": [0.35, 0.86]}
const WOOD := Color(0.45, 0.28, 0.15)


## Adds the weapon to `model` (a RobotModel). `viewmodel`: first-person arms (own shader).
static func attach(model: RobotModel, id: String, trim: Color, viewmodel: bool) -> Node3D:
	var at := BoneAttachment3D.new()
	at.name = "Melee"
	at.bone_name = "pistol"
	model.skeleton.add_child(at)
	var holder := Node3D.new()
	holder.transform = Transform3D(TO_BONE * Basis(Vector3.RIGHT, READY_TILT), Vector3.ZERO)
	at.add_child(holder)
	for part in parts(id):
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.transform = part[1]
		var kind: String = part[2]
		var color: Color = {"steel": STEEL, "dark": DARK, "grip": GRIP, "edge": trim, "wood": WOOD}[kind]
		var energy := 1.4 if kind == "edge" else 0.0
		if viewmodel:
			var sm := ShaderMaterial.new()
			sm.shader = load(VIEW_SHADER)
			sm.set_shader_parameter("albedo", color)
			sm.set_shader_parameter("roughness", 0.25 if kind == "steel" else 0.6)
			sm.set_shader_parameter("metallic", 0.9 if kind == "steel" else 0.3)
			sm.set_shader_parameter("emission", color * energy)
			mi.material_override = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 10.0
		else:
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			m.roughness = 0.25 if kind == "steel" else 0.6
			m.metallic = 0.9 if kind == "steel" else 0.3
			if energy > 0.0:
				m.emission_enabled = true
				m.emission = color
				m.emission_energy_multiplier = energy
			mi.material_override = m
		holder.add_child(mi)
	# Where the cutting edge starts and ends: the swing trail is drawn between them.
	var edge: Array = EDGES.get(id, EDGES.sword)
	for i in 2:
		var marker := Node3D.new()
		marker.name = "EdgeBase" if i == 0 else "EdgeTip"
		marker.position = Vector3(0, edge[i], 0)
		holder.add_child(marker)
	return at


## The edge's base and tip in the world right now.
static func edge(melee: Node3D) -> Array:
	var holder := melee.get_child(0)
	return [(holder.get_node("EdgeBase") as Node3D).global_position, (holder.get_node("EdgeTip") as Node3D).global_position]


## [mesh, transform, material kind] for each piece of a weapon.
static func parts(id: String) -> Array:
	match id:
		"brass_knuckles":   # four rings across the fingers, a bar in the palm, spikes on the knuckles
			var out := [[_box(0.03, 0.105, 0.022), _at(0, 0.0, -0.05), "steel"], [_box(0.026, 0.09, 0.014), _at(0, 0.0, 0.005), "dark"]]
			for i in 4:
				var y := -0.04 + i * 0.027
				out.append([_box(0.032, 0.006, 0.06), _at(0, y + 0.0135, -0.022), "steel"])
				out.append([_tip(0.022, 0.024, 0.018), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, y, -0.072)), "edge"])
			return out
		"spear":
			return [
				[_cyl(0.019, 1.95), _at(0, 0.45), "wood"],
				[_cyl(0.024, 0.14), _at(0, -0.02), "grip"],
				[_cyl(0.026, 0.05), _at(0, 1.43), "dark"],
				[_box(0.07, 0.2, 0.014), _at(0, 1.56), "steel"],
				[_tip(0.07, 0.14, 0.014), _at(0, 1.73), "steel"],
				[_box(0.012, 0.3, 0.018), _at(0, 1.6), "edge"],
				[_cyl(0.022, 0.06), _at(0, -0.52), "dark"],
			]
		"axe":
			return [
				[_cyl(0.022, 0.8), _at(0, 0.28), "wood"],
				[_cyl(0.027, 0.13), _at(0, -0.06), "grip"],
				[_box(0.04, 0.12, 0.1), _at(0, 0.66, 0.0), "dark"],
				[_box(0.022, 0.24, 0.16), _at(0, 0.66, -0.12), "steel"],
				[_box(0.026, 0.27, 0.025), _at(0, 0.66, -0.205), "edge"],
				[_box(0.034, 0.06, 0.06), _at(0, 0.66, 0.07), "steel"],
			]
		"bat":
			return [
				[_cone(0.022, 0.05, 0.7), _at(0, 0.5), "wood"],
				[_cyl(0.022, 0.24), _at(0, 0.03), "grip"],
				[_cyl(0.032, 0.03), _at(0, -0.1), "dark"],
				[_cyl(0.052, 0.025), _at(0, 0.72), "edge"],
				[_cyl(0.05, 0.03), _at(0, 0.86), "dark"],
			]
		"hammer":
			return [
				[_cyl(0.026, 0.8), _at(0, 0.24), "grip"],
				[_cyl(0.034, 0.12), _at(0, -0.18), "dark"],
				[_box(0.17, 0.17, 0.38), _at(0, 0.7), "steel"],
				[_box(0.18, 0.18, 0.045), _at(0, 0.7, -0.15), "edge"],
				[_box(0.18, 0.18, 0.045), _at(0, 0.7, 0.15), "edge"],
				[_box(0.13, 0.13, 0.07), _at(0, 0.7, -0.22), "dark"],
				[_box(0.13, 0.13, 0.07), _at(0, 0.7, 0.22), "dark"],
			]
		"dagger":
			return [
				[_cyl(0.02, 0.13), _at(0, -0.005), "grip"],
				[_box(0.11, 0.025, 0.04), _at(0, 0.07), "dark"],
				[_box(0.042, 0.3, 0.01), _at(0, 0.23), "steel"],
				[_tip(0.042, 0.08, 0.01), _at(0, 0.42), "steel"],
				[_box(0.008, 0.26, 0.012), _at(0, 0.22), "edge"],
				[_sphere(0.026), _at(0, -0.085), "dark"],
			]
	return [   # sword
		[_cyl(0.022, 0.2), _at(0, -0.01), "grip"],
		[_sphere(0.032), _at(0, -0.125), "dark"],
		[_box(0.24, 0.035, 0.055), _at(0, 0.1), "dark"],
		[_box(0.06, 0.78, 0.014), _at(0, 0.505), "steel"],
		[_tip(0.06, 0.13, 0.014), _at(0, 0.96), "steel"],
		[_box(0.012, 0.72, 0.017), _at(0, 0.49), "edge"],
	]


static func _at(x: float, y: float, z: float = 0.0) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func _box(w: float, h: float, d: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(w, h, d)
	return m


static func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	return m


## A round bar that widens from `r0` at the bottom to `r1` at the top.
static func _cone(r0: float, r1: float, h: float) -> CylinderMesh:
	var m := _cyl(r0, h)
	m.top_radius = r1
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


## A blade's point: a flat triangle prism.
static func _tip(w: float, h: float, d: float) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = Vector3(w, h, d)
	return m
