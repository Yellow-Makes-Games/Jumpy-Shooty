class_name SwingTrail
extends MeshInstance3D
## The glowing smear a blade leaves through the air during a blow: a ribbon
## between where the edge's base and tip have been over the last moment, fading
## out from the newest end. Drawn in the world (top-level), in the player's trim colour.
##
## A blow is over in a few frames, so the ribbon is rounded off between the places the
## blade was actually seen (a curve through them), not drawn as straight pieces. The more
## the swing was wound up (`power`), the longer it lasts and the brighter it is, with a
## white-hot streak along the edge's outer end.

const LIFE := 0.14          ## seconds each slice of the ribbon lasts for a tap...
const LIFE_FULL := 0.3      ## ...and for a full wind-up
const STEPS := 5            ## pieces drawn between two places the blade was seen

var power := 0.0            ## how wound up the swing being drawn was, 0..1

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
	var life := lerpf(LIFE, LIFE_FULL, power)
	for s in _slices:
		s[2] += delta
	while not _slices.is_empty() and _slices[0][2] > life:
		_slices.pop_front()
	_mesh.clear_surfaces()
	var n := _slices.size()
	if n < 2:
		return
	global_transform = Transform3D.IDENTITY
	var bright := lerpf(0.6, 1.0, power)
	var body := _color.lightened(0.3)
	var hot := _color.lerp(Color.WHITE, 0.75)
	# Two strips: the ribbon over the whole edge, and a hot streak along its outer fifth.
	for strip in 2:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n - 1:
			var steps := STEPS if i < n - 2 else STEPS + 1   # (the last piece draws its own end)
			for j in steps:
				var u := float(j) / float(STEPS)
				var base := _between(i, 0, u)
				var tip := _between(i, 1, u)
				var age := lerpf(_slices[i][2], _slices[i + 1][2], u)
				var fade := clampf(1.0 - age / life, 0.0, 1.0)
				fade *= fade
				if strip == 0:
					_mesh.surface_set_color(Color(_color, 0.0))
					_mesh.surface_add_vertex(base)
					_mesh.surface_set_color(Color(body, 0.8 * bright * fade))
					_mesh.surface_add_vertex(tip)
				else:
					_mesh.surface_set_color(Color(hot, 0.0))
					_mesh.surface_add_vertex(base.lerp(tip, 0.8))
					_mesh.surface_set_color(Color(hot, lerpf(0.35, 1.0, power) * fade))
					_mesh.surface_add_vertex(tip)
		_mesh.surface_end()


## A point on the curve through the slices' bases (which = 0) or tips (1), a part u of
## the way from slice i to the next.
func _between(i: int, which: int, u: float) -> Vector3:
	var n := _slices.size()
	var a: Vector3 = _slices[maxi(i - 1, 0)][which]
	var b: Vector3 = _slices[i][which]
	var c: Vector3 = _slices[i + 1][which]
	var d: Vector3 = _slices[mini(i + 2, n - 1)][which]
	return b.cubic_interpolate(c, a, d, u)
