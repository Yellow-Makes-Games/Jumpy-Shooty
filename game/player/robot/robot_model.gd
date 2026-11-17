class_name RobotModel
extends Node3D
## One robot on screen: the model from a .glb file, coloured for its player.
## RobotAnimator poses its skeleton every frame.

const VIEW_SHADER := "res://game/player/robot/viewmodel.gdshader"
const VISOR_ENERGY := 1.6
## Left out of the body you see in first person: the camera sits inside the head,
## and the arms and gun are drawn by ViewModel.
const VIEW_HIDDEN := ["head", "upper_arm_l", "forearm_l", "hand_l", "grapple", "upper_arm_r",
	"forearm_r", "hand_r", "pistol", "pistol_slide", "pistol_mag", "muzzle"]

static var _view_meshes := {}     # body mesh -> the mesh without VIEW_HIDDEN
static var _gun_meshes := {}      # [model file, gun] -> [the mesh with only that gun, which surface of the full mesh each surface was]

## The gun this robot holds (an id from WeaponData). Every model file holds every
## gun; their surfaces' materials are named "<gun>.<kind>", and the others are left out.
var weapon := ""
var rig: RobotRig
var skeleton: Skeleton3D
var mesh: MeshInstance3D
var view_mesh: MeshInstance3D     ## the same body without head and arms (first person only)
var chest_front := 0.12           ## how far the chest sticks out in front of the neck (set by add_view_mesh)

var _glow_materials: Array = []   # [material, is_shader]
var _glow_color := Color.WHITE


## The colour used on a robot's trim and visor: the player colour, made more vivid.
static func trim_color(player_color: Color) -> Color:
	return Color.from_hsv(player_color.h, minf(player_color.s * 1.35, 1.0), player_color.v)


## viewmodel: draw with the first-person shader (own field of view, never clips into walls).
## gun: which gun it holds (an id from WeaponData).
func setup(path: String, player_color: Color, viewmodel: bool = false, gun: String = "pistol") -> RobotModel:
	rig = RobotRig.open(path)
	var node := rig.scene.instantiate()
	add_child(node)
	skeleton = node.find_child("Skeleton3D", true, false)
	var player := node.find_child("AnimationPlayer", true, false)
	if player:
		player.free()   # RobotAnimator plays the clips itself
	for c in skeleton.get_children():
		if c is MeshInstance3D:
			mesh = c
	weapon = gun if gun == "none" else WeaponData.valid(gun)   # "none": empty hands (races)
	mesh.mesh = _with_gun(path, mesh.mesh, weapon)
	var trim := trim_color(player_color)
	_glow_color = trim
	for i in mesh.mesh.get_surface_count():
		var base: StandardMaterial3D = mesh.mesh.surface_get_material(i)
		var kind := material_kind(base.resource_name)
		var color := trim if kind == "accent" else base.albedo_color
		if viewmodel:
			var sm := ShaderMaterial.new()
			sm.shader = load(VIEW_SHADER)
			sm.set_shader_parameter("albedo", color)
			sm.set_shader_parameter("roughness", base.roughness)
			sm.set_shader_parameter("metallic", base.metallic)
			if kind == "visor":
				sm.set_shader_parameter("emission", trim * VISOR_ENERGY)
				_glow_materials.append([sm, true])
			mesh.set_surface_override_material(i, sm)
		elif kind == "accent" or kind == "visor":
			var m: StandardMaterial3D = base.duplicate()
			if kind == "visor":
				m.emission_enabled = true
				m.emission = trim
				m.emission_energy_multiplier = VISOR_ENERGY
				_glow_materials.append([m, false])
			else:
				m.albedo_color = color
			mesh.set_surface_override_material(i, m)
	if viewmodel:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 10.0   # the shader moves it on screen; never cull it
	return self


## "rifle.accent" -> "accent"; "armor" -> "armor".
static func material_kind(material_name: String) -> String:
	return material_name.get_slice(".", 1) if "." in material_name else material_name


## The model's mesh with only one gun's surfaces (made once per model file and gun).
static func _with_gun(path: String, full: Mesh, gun: String) -> Mesh:
	var key := path + "|" + gun
	if _gun_meshes.has(key):
		return _gun_meshes[key]
	var out := ArrayMesh.new()
	for s in full.get_surface_count():
		var mat := full.surface_get_material(s)
		var mname := mat.resource_name if mat else ""
		if "." in mname and mname.get_slice(".", 0) != gun:
			continue
		var flags: int = full.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, full.surface_get_arrays(s), [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	_gun_meshes[key] = out
	return out


## Where the gun's shots leave its barrel, in the world.
func muzzle() -> Vector3:
	return marker(WeaponData.by_id(weapon).muzzle_bone)


## Where a marker bone ("muzzle", "grapple") is in the world right now.
func marker(bone: String) -> Vector3:
	var i: int = rig.bones.get(bone, -1)
	if i < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin


## How brightly the visor and lights glow: 1 = on, 0 = powered down (dead).
func set_power(power: float) -> void:
	for entry in _glow_materials:
		if entry[1]:
			(entry[0] as ShaderMaterial).set_shader_parameter("emission", _glow_color * VISOR_ENERGY * power)
		else:
			(entry[0] as StandardMaterial3D).emission_energy_multiplier = VISOR_ENERGY * power


func set_layer(layer: int) -> void:
	mesh.layers = 1 << (layer - 1)


## Where a bone is in the model's own space (x right, y up, -z forward).
func bone_position(bone: String) -> Vector3:
	return global_transform.affine_inverse() * marker(bone)


## Your own robot in first person: a second copy of the mesh on the same skeleton,
## without the head and arms, on its own render layer. It casts no shadow (the
## full mesh, hidden from the camera, already casts the whole robot's).
func add_view_mesh(layer: int) -> void:
	if view_mesh:
		return
	view_mesh = MeshInstance3D.new()
	view_mesh.name = "ViewBody"
	var cut: Array = _view_mesh_for(rig, mesh)   # [mesh, which surface of the full mesh each surface was, chest depth]
	view_mesh.mesh = cut[0]
	chest_front = cut[2]
	view_mesh.skin = mesh.skin
	view_mesh.layers = 1 << (layer - 1)
	view_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view_mesh.extra_cull_margin = 2.0
	for i in cut[1].size():
		view_mesh.set_surface_override_material(i, mesh.get_surface_override_material(cut[1][i]))
	skeleton.add_child(view_mesh)
	view_mesh.skeleton = view_mesh.get_path_to(skeleton)


## The model's mesh with the triangles of VIEW_HIDDEN bones removed. Every triangle
## follows one bone, so this is a clean cut at the neck and shoulders.
static func _view_mesh_for(model_rig: RobotRig, full: MeshInstance3D) -> Array:
	if _view_meshes.has(full.mesh):
		return _view_meshes[full.mesh]
	var skin := full.skin
	var hidden := {}   # bone number as the mesh knows it -> true
	var chest := -1
	for b in skin.get_bind_count():
		var bone_name := String(skin.get_bind_name(b))
		if bone_name == "":
			bone_name = model_rig.bone_names[skin.get_bind_bone(b)]
		if bone_name in VIEW_HIDDEN:
			hidden[b] = true
		elif bone_name == "chest":
			chest = b
	var front := 0.0   # the chest's most forward point (-z), in the standing pose
	var source := full.mesh
	var out := ArrayMesh.new()
	var surfaces := PackedInt32Array()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per := bones.size() / verts.size()   # 4 or 8 bones per vertex
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		var kept := PackedInt32Array()
		for t in range(0, index.size(), 3):
			var v := index[t]
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			if not hidden.has(bones[v * per + best]):
				kept.append_array([index[t], index[t + 1], index[t + 2]])
			if bones[v * per + best] == chest:
				front = maxf(front, maxf(-verts[index[t]].z, maxf(-verts[index[t + 1]].z, -verts[index[t + 2]].z)))
		if kept.is_empty():
			continue   # a material only the head or arms use (the visor, the gun)
		arrays[Mesh.ARRAY_INDEX] = kept
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(surfaces.size(), source.surface_get_material(s))
		surfaces.append(s)
	_view_meshes[full.mesh] = [out, surfaces, front]
	return _view_meshes[full.mesh]
