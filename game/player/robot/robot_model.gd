class_name RobotModel
extends Node3D
## One character on screen: the model from a .glb file (or, for a character from the
## Character Creator, put together from several), coloured for its player.
## RobotAnimator poses its skeleton every frame.

const VIEW_SHADER := "res://game/player/robot/viewmodel.gdshader"
const VISOR_ENERGY := 1.6
const GOLD := Color(1.0, 0.76, 0.22)   ## the Golden Gun
## Left out of the body you see in first person: the camera sits inside the head,
## and the arms and gun are drawn by ViewModel.
const VIEW_HIDDEN := ["head", "upper_arm_l", "forearm_l", "hand_l", "grapple", "upper_arm_r",
	"forearm_r", "hand_r", "pistol", "pistol_slide", "pistol_mag", "muzzle", "pistol_l", "pistol_l_slide", "pistol_l_mag"]

## What a surface's material kind (see material_kind) means for a character:
const PAINTED := ["armor", "extra"]          ## takes the body paint and the team colour
const SKINNED := ["skin", "flesh"]           ## takes the skin tone
## ...and for measuring a body for its accessories: a head's shell (not its ears, horns
## or antennas), its eyes, and what to leave out of the chest and the waist.
const SHELL := ["armor", "steel", "cloth", "mail", "visor", "skin", "hair", "shell"]
const EYES := ["visor", "eye"]
const UNMEASURED := ["visor", "extra", "flesh"]
## The first-person arms: these bones' triangles (a kit's are thinned: Characters.KIT_FP_SLIM).
const ARM_BONES := ["upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r"]
const SLIM_BONES := {"forearm_l": -1.0, "hand_l": -1.0, "forearm_r": 1.0, "hand_r": 1.0}
const ARM_X := 0.215                         ## how far out the arms hang (rig.py: forearm_l)

static var _view_meshes := {}     # body mesh -> the mesh without VIEW_HIDDEN
static var _gun_meshes := {}      # [model file, gun] -> [the mesh with only that gun, which surface of the full mesh each surface was]
static var _custom_meshes := {}   # custom character's parts + gun -> its mesh (see _custom_mesh)
static var _sources := {}         # model file -> [its full mesh, its skin]
static var _skin_parts := {}    # "part id|region" -> whether it shows bare skin
static var _arm_meshes := {}      # kit + gun -> a kit's first-person arms (see _kit_arms_mesh)

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
	var skin := CustomCharacter.skin_color(custom.skin) if custom else Color(0, 0, 0, 0)
	if team_paint.a > 0.0:
		paint = team_paint
	return _setup(path, player_color, viewmodel, gun, custom, paint, skin, arms)


## viewmodel: draw with the first-person shader (own field of view, never clips into walls).
## gun: which gun it holds (an id from WeaponData).
func setup(path: String, player_color: Color, viewmodel: bool = false, gun: String = "pistol") -> RobotModel:
	return _setup(path, player_color, viewmodel, gun)


## custom: a custom character to put together (`path` is its base robot's file: the
## skeleton, the animations and the guns); paint: the colour of its shell ("armor"),
## skin: of its bare skin; alpha 0 leaves either as built. arms: `path` is the
## first-person arms' file.
func _setup(path: String, player_color: Color, viewmodel: bool, gun: String, custom: CustomCharacter = null,
		paint: Color = Color(0, 0, 0, 0), skin: Color = Color(0, 0, 0, 0), arms: bool = false) -> RobotModel:
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
	if custom and not arms:
		mesh.mesh = _custom_mesh(custom, path, mesh.skin, shown_gun)
	elif custom and Characters.is_kit(custom.torso):
		mesh.mesh = _kit_arms_mesh(custom.torso, path, mesh, shown_gun)   # a robot's guns in the kit's own hands
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
		var painted := (kind in PAINTED and paint.a > 0.0) or (kind in SKINNED and skin.a > 0.0)
		if painted:
			color = paint if kind in PAINTED else skin
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


## Whether any of this character's parts shows bare skin (so a skin tone would change it).
static func shows_skin(c: CustomCharacter) -> bool:
	for part in ["legs", "torso", "head"]:
		var id := c.part(part)
		var key := "%s|%s" % [id, part]
		if not _skin_parts.has(key):
			_skin_parts[key] = false
			var path := Characters.part_file(id)
			var source: Mesh = _source(path)[0]
			var names := _bind_list(_source(path)[1])
			for s in source.get_surface_count():
				var mat := source.surface_get_material(s)
				if mat == null or material_kind(mat.resource_name) not in SKINNED:
					continue
				var arrays := source.surface_get_arrays(s)
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var per := bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				for v in range(0, bones.size(), per):
					if CustomCharacter.region_of(names[bones[v]]) == part:
						_skin_parts[key] = true
						break
		if _skin_parts[key]:
			return true
	return false


## A custom character's mesh: each body region's triangles from the body it comes
## from (see CustomCharacter.region_of), a gun from its base robot's file (`host`),
## then its accessories (see Accessories), fitted to that head, chest and waist.
## Every body shares one skeleton and one list of skin binds, so the parts go onto
## the base robot's skeleton as they are.
static func _custom_mesh(c: CustomCharacter, host: String, skin: Skin, gun: String) -> Mesh:
	var picked := []
	for slot in CustomCharacter.SLOTS:
		picked.append(c.accessories.get(slot, ""))
	var key := "%s|%s|%s|%s|%s" % [c.legs, c.torso, c.head, ",".join(picked), gun]
	if _custom_meshes.has(key):
		return _custom_meshes[key]
	var bind_of := _bind_names(skin)   # bone name -> skin bind
	var out := ArrayMesh.new()
	var head_shell := AABB()
	var visor := AABB()
	var chest := AABB()
	var waist := AABB()
	var seen := {"shell": false, "visor": false, "chest": false, "waist": false}
	for part in ["legs", "torso", "head"]:
		var path := Characters.part_file(c.part(part))
		var source: Mesh = _source(path)[0]
		var names := _bind_list(_source(path)[1])   # this file's skin bind -> bone name
		for s in source.get_surface_count():
			var mat := source.surface_get_material(s)
			if mat and "." in mat.resource_name:
				continue   # a gun: from the base robot, below
			var arrays := source.surface_get_arrays(s)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var per := bones.size() / verts.size()
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
			var kind := material_kind(mat.resource_name) if mat else ""
			var kept := PackedInt32Array()
			for t in range(0, index.size(), 3):
				var v := index[t]
				var best := 0
				for k in per:
					if weights[v * per + k] > weights[v * per + best]:
						best = k
				var bone_name: String = names[bones[v * per + best]]
				if CustomCharacter.region_of(bone_name) != part:
					continue
				kept.append_array([index[t], index[t + 1], index[t + 2]])
				# Measure the head, chest and waist, for fitting the accessories.
				for corner in 3:
					var p := verts[index[t + corner]]
					if bone_name == "head" and p.y > 1.48 and kind in SHELL:
						head_shell = head_shell.expand(p) if seen.shell else AABB(p, Vector3.ZERO)
						seen.shell = true
					if bone_name == "head" and kind in EYES:
						visor = visor.expand(p) if seen.visor else AABB(p, Vector3.ZERO)
						seen.visor = true
					if bone_name == "chest" and kind not in UNMEASURED:
						chest = chest.expand(p) if seen.chest else AABB(p, Vector3.ZERO)
						seen.chest = true
					if bone_name == "hips" and kind not in UNMEASURED and p.y > 0.93:
						waist = waist.expand(p) if seen.waist else AABB(p, Vector3.ZERO)
						seen.waist = true
			if kept.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = kept
			arrays[Mesh.ARRAY_BONES] = _rebind(bones, names, bind_of)
			var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	_add_gun(out, host, gun, bind_of)
	if not seen.shell:
		head_shell = AABB(Vector3(-0.12, 1.5, -0.14), Vector3(0.24, 0.3, 0.27))
	if not seen.chest:
		chest = AABB(Vector3(-0.2, 1.18, -0.14), Vector3(0.4, 0.32, 0.28))
	if not seen.waist:
		waist = AABB(Vector3(-0.14, 0.93, -0.1), Vector3(0.28, 0.12, 0.2))
	# How far forward the chest is just below the neck: the second measurement
	# needs the chest's height first.
	var collar := chest.position.z
	var collar_set := false
	var torso_path := Characters.part_file(c.torso)
	var torso_src: Mesh = _source(torso_path)[0]
	var torso_names := _bind_list(_source(torso_path)[1])
	for s in torso_src.get_surface_count():
		var mat := torso_src.surface_get_material(s)
		if mat and ("." in mat.resource_name or material_kind(mat.resource_name) in UNMEASURED):
			continue
		var arrays := torso_src.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per := bones.size() / verts.size()
		for i in verts.size():
			if torso_names[bones[i * per]] == "chest" and verts[i].y > chest.end.y - 0.07:
				collar = verts[i].z if not collar_set else minf(collar, verts[i].z)
				collar_set = true
	var fit := Accessories.fit(head_shell, visor, chest, collar, waist)
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


## The first-person arms of a character whose torso is a kit: the kit's own arms
## (thinned, if they are bulky), holding the gun from the base robot's arms file.
## Kits have no arms files of their own.
static func _kit_arms_mesh(kit: String, arms_path: String, full: MeshInstance3D, gun: String) -> Mesh:
	var key := "%s|%s|%s" % [kit, arms_path, gun]
	if _arm_meshes.has(key):
		return _arm_meshes[key]
	var bind_of := _bind_names(full.skin)
	var out := ArrayMesh.new()
	var source: Mesh = _source(Characters.part_file(kit))[0]
	var names := _bind_list(_source(Characters.part_file(kit))[1])
	var slim: float = Characters.KIT_FP_SLIM.get(kit, 1.0)
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per := bones.size() / verts.size()
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		var kept := PackedInt32Array()
		for t in range(0, index.size(), 3):
			if names[bones[index[t] * per]] in ARM_BONES:   # (every triangle follows one bone)
				kept.append_array([index[t], index[t + 1], index[t + 2]])
		if kept.is_empty():
			continue
		if slim != 1.0:
			for i in verts.size():
				var side: float = SLIM_BONES.get(names[bones[i * per]], 0.0)
				if side != 0.0:
					verts[i] = Vector3(side * ARM_X + (verts[i].x - side * ARM_X) * slim, verts[i].y, verts[i].z * slim)
			arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_INDEX] = kept
		arrays[Mesh.ARRAY_BONES] = _rebind(bones, names, bind_of)
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, source.surface_get_material(s))
	_add_gun(out, arms_path, gun, bind_of)
	if _arm_meshes.size() > 64:
		_arm_meshes.clear()
	_arm_meshes[key] = out
	return out


## Adds one gun's surfaces from a robot's model file to `out`.
static func _add_gun(out: ArrayMesh, path: String, gun: String, bind_of: Dictionary) -> void:
	var source := _with_gun(path, _source(path)[0], gun)
	var names := _bind_list(_source(path)[1])
	for s in source.get_surface_count():
		var mat := source.surface_get_material(s)
		if mat == null or not "." in mat.resource_name:
			continue
		var arrays := source.surface_get_arrays(s)
		arrays[Mesh.ARRAY_BONES] = _rebind(arrays[Mesh.ARRAY_BONES], names, bind_of)
		var flags: int = source.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mat)


## A skin's binds: bone name -> bind number.
static func _bind_names(skin: Skin) -> Dictionary:
	var out := {}
	for b in skin.get_bind_count():
		out[String(skin.get_bind_name(b))] = b
	return out


## A skin's binds: bind number -> bone name.
static func _bind_list(skin: Skin) -> PackedStringArray:
	var out := PackedStringArray()
	for b in skin.get_bind_count():
		out.append(String(skin.get_bind_name(b)))
	return out


## Bone numbers from one model file's skin, as another skin numbers the same bones.
## Every file is built on one skeleton, so they almost always already agree.
static func _rebind(bones: PackedInt32Array, names: PackedStringArray, bind_of: Dictionary) -> PackedInt32Array:
	var same := true
	for b in names.size():
		if bind_of.get(names[b], -1) != b:
			same = false
			break
	if same:
		return bones
	var out := PackedInt32Array()
	out.resize(bones.size())
	for i in bones.size():
		out[i] = bind_of.get(names[bones[i]], 0) if bones[i] < names.size() else 0
	return out


## A model file's full mesh (every gun, if it has any) and its skin, loaded once.
static func _source(path: String) -> Array:
	if not _sources.has(path):
		var node: Node = (load(path) as PackedScene).instantiate()
		var skeleton: Skeleton3D = node.find_child("Skeleton3D", true, false)
		for c in skeleton.get_children():
			if c is MeshInstance3D:
				_sources[path] = [c.mesh, c.skin]
		node.free()
	return _sources[path]


## What kind of surface a material is, from its name: "rifle.accent" -> "accent";
## "armor" -> "armor"; "armor_frog" -> "armor" (the kits' materials each have their
## own colour, and say their kind before the "_").
static func material_kind(material_name: String) -> String:
	var kind := material_name.get_slice(".", 1) if "." in material_name else material_name
	return kind.get_slice("_", 0)


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
