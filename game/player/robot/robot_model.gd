class_name RobotModel
extends Node3D
## One robot on screen: the model from a .glb file, coloured for its player.
## RobotAnimator poses its skeleton every frame.

const VIEW_SHADER := "res://game/player/robot/viewmodel.gdshader"
const VISOR_ENERGY := 1.6
const GOLD := Color(1.0, 0.76, 0.22)   ## the Golden Gun
## Left out of the body you see in first person: the camera sits inside the head,
## and the arms and gun are drawn by ViewModel.
const VIEW_HIDDEN := ["head", "upper_arm_l", "forearm_l", "hand_l", "grapple", "upper_arm_r",
	"forearm_r", "hand_r", "pistol", "pistol_slide", "pistol_mag", "muzzle", "pistol_l", "pistol_l_slide", "pistol_l_mag"]

static var _view_meshes := {}     # body mesh -> the mesh without VIEW_HIDDEN
static var _gun_meshes := {}      # [model file, gun] -> [the mesh with only that gun, which surface of the full mesh each surface was]
static var _custom_meshes := {}   # custom character's parts + gun -> its mesh (see _custom_mesh)
static var _source_meshes := {}   # model file -> its full mesh

## The gun this robot holds (an id from WeaponData). Every model file holds every
## gun; their surfaces' materials are named "<gun>.<kind>", and the others are left out.
var weapon := ""
var rig: RobotRig
var skeleton: Skeleton3D
var mesh: MeshInstance3D
var view_mesh: MeshInstance3D     ## the same body without head and arms (first person only)
var chest_front := 0.12           ## how far the chest sticks out in front of the neck (set by add_view_mesh)
var melee: Node3D                 ## the sword, hammer or dagger in the fist (see MeleeModel), if any
var melee_left: Node3D            ## the left fist's brass knuckles, if any

var _glow_materials: Array = []   # [material, is_shader]
var _glow_color := Color.WHITE


## The colour used on a robot's trim and visor: the player colour, made more vivid.
static func trim_color(player_color: Color) -> Color:
	return Color.from_hsv(player_color.h, minf(player_color.s * 1.35, 1.0), player_color.v)


## Any character (a robot's id, or a custom one's; see Characters): its model,
## put together from its parts if it is a custom character. arms: the first-person
## arms model instead of the full body. team_paint: the armour all in this colour (the
## team modes paint everyone in their team's colour; alpha 0 leaves it as it is).
func build(character: String, player_color: Color, viewmodel: bool = false, gun: String = "pistol", arms: bool = false,
		team_paint: Color = Color(0, 0, 0, 0)) -> RobotModel:
	var custom: CustomCharacter = CustomCharacter.parse(character) if Characters.is_custom(character) else null
	var path := Characters.arms(character) if arms else Characters.body(character)
	var paint := CustomCharacter.paint_color(custom.paint) if custom else Color(0, 0, 0, 0)
	if team_paint.a > 0.0:
		paint = team_paint
	return _setup(path, player_color, viewmodel, gun, custom if not arms else null, paint)


## viewmodel: draw with the first-person shader (own field of view, never clips into walls).
## gun: which gun it holds (an id from WeaponData).
func setup(path: String, player_color: Color, viewmodel: bool = false, gun: String = "pistol") -> RobotModel:
	return _setup(path, player_color, viewmodel, gun)


## custom: a custom character to put together (its torso is `path`); paint: the
## colour of its shell ("armor"), or alpha 0 to leave it as built.
func _setup(path: String, player_color: Color, viewmodel: bool, gun: String, custom: CustomCharacter = null, paint: Color = Color(0, 0, 0, 0)) -> RobotModel:
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
	# A melee weapon is not in the model file: empty hands, then the blade in the fist.
	var shown_gun := "none" if WeaponData.melee(weapon) else WeaponData.look_of(weapon)   # (the Golden Gun: the revolver)
	var golden := weapon != "none" and WeaponData.by_id(weapon).golden
	if custom:
		mesh.mesh = _custom_mesh(custom, mesh.skin, shown_gun)
	else:
		mesh.mesh = _with_gun(path, mesh.mesh, shown_gun)
	var trim := trim_color(player_color)
	if WeaponData.melee(weapon):
		melee = MeleeModel.attach(self, weapon, trim, viewmodel)
		melee_left = MeleeModel.attach_left(self, weapon, trim, viewmodel)
	_glow_color = trim
	for i in mesh.mesh.get_surface_count():
		var base: StandardMaterial3D = mesh.mesh.surface_get_material(i)
		var kind := material_kind(base.resource_name)
		var color := trim if kind == "accent" else base.albedo_color
		var painted := kind == "armor" and paint.a > 0.0
		if painted:
			color = paint
		var gilded := golden and base.resource_name.begins_with(shown_gun + ".")   # the gun's own surfaces
		if gilded:
			color = GOLD if kind != "accent" else GOLD.darkened(0.25)
		if viewmodel:
			var sm := ShaderMaterial.new()
			sm.shader = load(VIEW_SHADER)
			sm.set_shader_parameter("albedo", color)
			sm.set_shader_parameter("roughness", 0.25 if gilded else base.roughness)
			sm.set_shader_parameter("metallic", 0.9 if gilded else base.metallic)
			if kind == "visor":
				sm.set_shader_parameter("emission", trim * VISOR_ENERGY)
				_glow_materials.append([sm, true])
			mesh.set_surface_override_material(i, sm)
		elif kind == "accent" or kind == "visor" or painted or gilded:
			var m: StandardMaterial3D = base.duplicate()
			if kind == "visor":
				m.emission_enabled = true
				m.emission = trim
				m.emission_energy_multiplier = VISOR_ENERGY
				_glow_materials.append([m, false])
			else:
				m.albedo_color = color
				if gilded:
					m.metallic = 0.9
					m.roughness = 0.25
			mesh.set_surface_override_material(i, m)
	if viewmodel:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 10.0   # the shader moves it on screen; never cull it
	return self


## A custom character's mesh: each body region's triangles from the robot it comes
## from (see CustomCharacter.region_of), then its accessories (see Accessories),
## fitted to that head and chest. Every robot shares one skeleton and one list of
## skin binds, so the parts go onto the torso robot's skeleton as they are.
static func _custom_mesh(c: CustomCharacter, skin: Skin, gun: String) -> Mesh:
	var picked := []
	for slot in CustomCharacter.SLOTS:
		picked.append(c.accessories[slot])
	var key := "%s|%s|%s|%s|%s" % [c.legs, c.torso, c.head, ",".join(picked), gun]
	if _custom_meshes.has(key):
		return _custom_meshes[key]
	var region := {}   # skin bind -> "head", "legs" or "torso"
	var bind_of := {}  # bone name -> skin bind
	for b in skin.get_bind_count():
		var bone_name := String(skin.get_bind_name(b))
		region[b] = CustomCharacter.region_of(bone_name)
		bind_of[bone_name] = b
	var out := ArrayMesh.new()
	var head_shell := AABB()
	var visor := AABB()
	var chest := AABB()
	var collar := 0.0
	var seen := {"shell": false, "visor": false, "chest": false}
	for part in ["legs", "torso", "head"]:
		var path := Characters.DIR + c.part(part) + ".glb"
		var source := _with_gun(path, _source_mesh(path), gun)
		for s in source.get_surface_count():
			var arrays := source.surface_get_arrays(s)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var per := bones.size() / verts.size()
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
			var mat := source.surface_get_material(s)
			var kind := material_kind(mat.resource_name) if mat else ""
			var kept := PackedInt32Array()
			for t in range(0, index.size(), 3):
				var v := index[t]
				var best := 0
				for k in per:
					if weights[v * per + k] > weights[v * per + best]:
						best = k
				var bind := bones[v * per + best]
				if region.get(bind, "torso") != part:
					continue
				kept.append_array([index[t], index[t + 1], index[t + 2]])
				# Measure the head and chest, for fitting the accessories.
				var bone_name := String(skin.get_bind_name(bind))
				for corner in 3:
					var p := verts[index[t + corner]]
					if bone_name == "head" and p.y > 1.48 and kind in ["armor", "steel", "cloth", "mail", "visor"]:
						head_shell = head_shell.expand(p) if seen.shell else AABB(p, Vector3.ZERO)
						seen.shell = true
					if bone_name == "head" and kind == "visor":
						visor = visor.expand(p) if seen.visor else AABB(p, Vector3.ZERO)
						seen.visor = true
					if bone_name == "chest" and kind != "visor":
						chest = chest.expand(p) if seen.chest else AABB(p, Vector3.ZERO)
						seen.chest = true
			if kept.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = kept
			var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	if not seen.shell:
		head_shell = AABB(Vector3(-0.12, 1.5, -0.14), Vector3(0.24, 0.3, 0.27))
	if not seen.chest:
		chest = AABB(Vector3(-0.2, 1.18, -0.14), Vector3(0.4, 0.32, 0.28))
	# How far forward the chest is just below the neck: the second measurement
	# needs the chest's height first.
	collar = chest.position.z
	var collar_set := false
	var torso_path := Characters.DIR + c.torso + ".glb"
	var torso_src := _source_mesh(torso_path)
	for s in torso_src.get_surface_count():
		var mat := torso_src.surface_get_material(s)
		if mat and "." in mat.resource_name:
			continue
		var arrays := torso_src.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per := bones.size() / verts.size()
		for i in verts.size():
			if bones[i * per] == bind_of.get("chest", -1) and verts[i].y > chest.end.y - 0.07:
				collar = verts[i].z if not collar_set else minf(collar, verts[i].z)
				collar_set = true
	var fit := Accessories.fit(head_shell, visor, chest, collar)
	for piece in Accessories.build(c.accessories, fit):
		var pts: PackedVector3Array = piece.points
		if pts.is_empty():
			continue
		var normals := PackedVector3Array()
		normals.resize(pts.size())
		var bones := PackedInt32Array()
		bones.resize(pts.size() * 4)
		var weights := PackedFloat32Array()
		weights.resize(pts.size() * 4)
		var bind: int = bind_of.get(piece.bone, 0)
		for t in range(0, pts.size(), 3):
			# Godot's front faces wind clockwise: the triangles come out counter-clockwise.
			var a := pts[t]
			pts[t] = pts[t + 2]
			pts[t + 2] = a
			var n := (pts[t + 2] - pts[t]).cross(pts[t + 1] - pts[t]).normalized()
			for k in 3:
				normals[t + k] = n
		for i in pts.size():
			bones[i * 4] = bind
			weights[i * 4] = 1.0
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, Accessories.material(piece.material))
	if _custom_meshes.size() > 64:
		_custom_meshes.clear()
	_custom_meshes[key] = out
	return out


## A model file's full mesh (every gun), loaded once.
static func _source_mesh(path: String) -> Mesh:
	if not _source_meshes.has(path):
		var node := RobotRig.open(path).scene.instantiate()
		var skeleton: Skeleton3D = node.find_child("Skeleton3D", true, false)
		for c in skeleton.get_children():
			if c is MeshInstance3D:
				_source_meshes[path] = c.mesh
		node.free()
	return _source_meshes[path]


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
	for held in [melee, melee_left]:
		if held:
			for c in held.get_child(0).get_children():
				if c is MeshInstance3D:
					c.layers = mesh.layers


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
