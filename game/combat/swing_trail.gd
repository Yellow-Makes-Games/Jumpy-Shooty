class_name SwingTrail
extends MeshInstance3D
## The glowing smear a blade leaves through the air during a blow: a ribbon
## between where the edge's base and tip have been over the last moment, fading
## out from the newest end. Drawn in the world (top-level), in the player's trim colour.

const LIFE := 0.16          ## seconds each slice of the ribbon lasts

var _slices: Array = []     # [base, tip, age]
var _mesh := ImmediateMesh.new()
var _color := Color.WHITE


func setup(color: Color, layer_mask: int = 1) -> SwingTrail:
	_color = color
	top_level = true
	mesh = _mesh
	layers = layer_mask
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = false
	material_override = m
	return self


## One more slice of the ribbon (call every frame while the blade is cutting).
func add(base: Vector3, tip: Vector3) -> void:
	if not _slices.is_empty() and (_slices[-1][1] as Vector3).distance_squared_to(tip) < 0.0004:
		return
	_slices.append([base, tip, 0.0])


func clear() -> void:
	_slices.clear()
	_mesh.clear_surfaces()


## Ages the slices and redraws the ribbon.
func tick(delta: float) -> void:
	for s in _slices:
		s[2] += delta
	while not _slices.is_empty() and _slices[0][2] > LIFE:
		_slices.pop_front()
	_mesh.clear_surfaces()
	if _slices.size() < 2:
		return
	global_transform = Transform3D.IDENTITY
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s in _slices:
		var fade := clampf(1.0 - float(s[2]) / LIFE, 0.0, 1.0)
		_mesh.surface_set_color(Color(_color, 0.0))
		_mesh.surface_add_vertex(s[0])
		_mesh.surface_set_color(Color(_color.lightened(0.35), 0.75 * fade * fade))
		_mesh.surface_add_vertex(s[1])
	_mesh.surface_end()
