class_name Dissolve
extends RefCounted
## Makes a body burn away: every surface under a node (a ragdoll, a giblet) gets a copy
## of its material on dissolve.gdshader, then set_progress runs it from whole (0) to
## gone (1). Materials that are not a StandardMaterial3D are left as they are.
##
##   var d := Dissolve.prepare(body, RobotModel.trim_color(Net.player_color(id)))
##   d.set_progress(t)   # each frame, while it goes

const SHADER := preload("res://game/player/robot/dissolve.gdshader")

var _materials: Array[ShaderMaterial] = []


## Swaps every surface under `root` (it included) onto the dissolve shader, its rim in `edge`.
static func prepare(root: Node, edge: Color = Color(1.0, 0.55, 0.2)) -> Dissolve:
	var d := Dissolve.new()
	d._convert(root, edge)
	return d


## 0 = whole, 1 = gone.
func set_progress(t: float) -> void:
	for m in _materials:
		m.set_shader_parameter("progress", clampf(t, 0.0, 1.0))


func material_count() -> int:
	return _materials.size()


func _convert(n: Node, edge: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var m := _make(mi.get_active_material(i), edge)
				if m:
					mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_convert(c, edge)


func _make(base: Material, edge: Color) -> ShaderMaterial:
	var b := base as BaseMaterial3D
	if b == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", b.albedo_color)
	if b.albedo_texture:
		m.set_shader_parameter("albedo_texture", b.albedo_texture)
		m.set_shader_parameter("use_texture", true)
	m.set_shader_parameter("use_vertex_color", b.vertex_color_use_as_albedo)
	m.set_shader_parameter("metallic", b.metallic)
	m.set_shader_parameter("roughness", b.roughness)
	if b.emission_enabled:
		m.set_shader_parameter("emission", Color(b.emission.r, b.emission.g, b.emission.b))
		m.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
	m.set_shader_parameter("edge_color", edge)
	_materials.append(m)
	return m
