extends SceneTree
## Renders guns on their own, to check their looks without opening the game: each gun
## from its left side and from a three-quarter view. Given two model files it renders
## both with the same camera, for a before/after sheet (see tools/combat/gun_sheet.py).
## Used by tools/combat/gun_preview.sh.
##
##   godot --path . --script tools/combat/gun_preview.gd -- --out=DIR [--guns=pistol,rifle]
##       [--glb=after.glb] [--before=before.glb] [--color=r,g,b]
##
## Writes DIR/<gun>_side.png and DIR/<gun>_quarter.png (and <gun>_before_side.png,
## <gun>_before_quarter.png with --before). "golden_gun" is the revolver, gilded.

const GRIP := Vector3(0.215, 0.835, 0.0)   ## the right fist's grip in the model file (rig.py)
const SIZE := Vector2i(960, 420)

var _out := "."
var _glb := "res://game/player/robot/needle.glb"
var _before := ""
var _guns: Array = WeaponData.GUNS.duplicate()
var _color := Color(0.95, 0.35, 0.25)
var _queue := []    # [file, mesh, camera transform, ortho size]
var _shot := -1
var _wait := 0
var _camera: Camera3D
var _holder: Node3D
var _meshes := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--glb="):
			_glb = arg.substr(6)
		elif arg.begins_with("--before="):
			_before = arg.substr(9)
		elif arg.begins_with("--guns="):
			_guns = Array(arg.substr(7).split(","))
		elif arg.begins_with("--color="):
			var c := arg.substr(8).split_floats(",")
			_color = Color(c[0], c[1], c[2])
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.60, 0.64, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.90)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -118, 0)
	sun.light_energy = 1.15
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -60, 0)
	fill.light_energy = 0.35
	root.add_child(fill)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.05
	root.add_child(_camera)
	_camera.make_current()
	_holder = Node3D.new()
	root.add_child(_holder)
	root.size = SIZE
	DisplayServer.window_set_size(SIZE)
	for gun in _guns:
		var after := _gun_mesh(_glb, gun)
		var before: Mesh = _gun_mesh(_before, gun) if _before != "" else null
		if after == null:
			push_error("gun_preview: no gun %s in %s" % [gun, _glb])
			continue
		var box := after.get_aabb()
		if before:
			box = box.merge(before.get_aabb())
		var mid := box.get_center()
		var aspect := float(SIZE.x) / SIZE.y
		# From the left side: the barrel points left.
		var side_h := maxf(box.size.y, box.size.z / aspect) * 1.12
		var side := Transform3D(Basis.looking_at(Vector3(1, 0, 0)), mid + Vector3(-5, 0, 0))
		# Three-quarter: from the front-left and a little above.
		var dir := Vector3(-0.62, 0.36, -0.70).normalized()
		var q := Transform3D(Basis.looking_at(-dir), mid + dir * 5.0)
		var w := 0.0
		var h := 0.0
		for i in 8:
			var p := q.basis.inverse() * (box.get_endpoint(i) - mid)
			w = maxf(w, absf(p.x))
			h = maxf(h, absf(p.y))
		var q_h := maxf(h * 2.0, w * 2.0 / aspect) * 1.12
		for pair in [["", after], ["_before", before]]:
			if pair[1] == null:
				continue
			_queue.append(["%s/%s%s_side.png" % [_out, gun, pair[0]], pair[1], side, side_h])
			_queue.append(["%s/%s%s_quarter.png" % [_out, gun, pair[0]], pair[1], q, q_h])


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _shot >= 0:
		root.get_texture().get_image().save_png(_queue[_shot][0])
		print("saved ", _queue[_shot][0])
	_shot += 1
	if _shot >= _queue.size():
		return true
	for c in _holder.get_children():
		c.queue_free()
	var shot: Array = _queue[_shot]
	var mi := MeshInstance3D.new()
	mi.mesh = shot[1]
	_holder.add_child(mi)
	_camera.global_transform = shot[2]
	_camera.size = shot[3]
	_wait = 3
	return false


## One gun out of a robot's model file, in gun space (barrel -Z, sights +Y, the grip at
## the origin), coloured as the game colours it.
func _gun_mesh(path: String, gun: String) -> Mesh:
	var key := path + "|" + gun
	if _meshes.has(key):
		return _meshes[key]
	var full := _full_mesh(path)
	if full == null:
		return null
	var golden := WeaponData.has(gun) and WeaponData.by_id(gun).golden
	gun = WeaponData.look_of(gun)   # (the Golden Gun: the revolver, gilded)
	var trim := RobotModel.trim_color(_color)
	# The model file holds the gun as the robot stands at rest: in the fist, barrel down.
	var to_gun := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), GRIP).affine_inverse()
	var out := ArrayMesh.new()
	for s in full.get_surface_count():
		var base: StandardMaterial3D = full.surface_get_material(s)
		if base == null or not base.resource_name.begins_with(gun + "."):
			continue
		var arrays := full.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			verts[i] = to_gun * verts[i]
			normals[i] = to_gun.basis * normals[i]
		var plain := []
		plain.resize(Mesh.ARRAY_MAX)
		plain[Mesh.ARRAY_VERTEX] = verts
		plain[Mesh.ARRAY_NORMAL] = normals
		plain[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plain)
		var m: StandardMaterial3D = base.duplicate()
		var kind := RobotModel.material_kind(base.resource_name)
		var color := trim
		if golden:
			color = RobotModel.GOLD if kind != "accent" else RobotModel.GOLD.darkened(0.25)
			m.albedo_color = color
			m.metallic = 0.9
			m.roughness = 0.25
		if kind == "accent":
			m.albedo_color = color
		elif kind == "glow":
			m.albedo_color = color
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = RobotModel.GUN_GLOW_ENERGY
		out.surface_set_material(out.get_surface_count() - 1, m)
	if out.get_surface_count() == 0:
		return null
	_meshes[key] = out
	return out


func _full_mesh(path: String) -> Mesh:
	var node: Node
	if path.begins_with("res://"):
		node = (load(path) as PackedScene).instantiate()
	else:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_error("gun_preview: cannot read %s" % path)
			return null
		node = doc.generate_scene(state)
	var found: Mesh = null
	for c in node.find_children("*", "MeshInstance3D", true, false):
		found = (c as MeshInstance3D).mesh
		break
	node.free()
	return found
