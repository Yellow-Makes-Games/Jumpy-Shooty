class_name ShotFx
## Placeholder shot effects: tracer line, muzzle flash and impact puff.
## Simple shapes for now; real effects come with the art pass.


## One shot: a tracer and an impact for each pellet (`ends`, `hits`: one per pellet),
## and a muzzle flash sized for the gun.
static func spawn(parent: Node, muzzle: Vector3, ends: PackedVector3Array, hits: Array, weapon: String = "pistol") -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	var flash: float = {"shotgun": 0.2, "rifle": 0.11, "sniper": 0.22}.get(weapon, 0.12)
	var width: float = {"shotgun": 0.009, "sniper": 0.028}.get(weapon, 0.015)
	var color := Color(0.75, 0.9, 1.0) if weapon == "sniper" else Color(1.0, 0.85, 0.5)
	var life := 0.16 if weapon == "sniper" else 0.07
	_flash(parent, muzzle, Color(1.0, 0.8, 0.4), flash, 0.05)
	for i in ends.size():
		var hit: bool = hits[i] if i < hits.size() else false
		_tracer(parent, muzzle, ends[i], width, color, life)
		_flash(parent, ends[i], Color(1.0, 0.3, 0.2) if hit else Color(0.9, 0.9, 0.8), 0.15 if ends.size() == 1 else 0.07, 0.12)


static func _tracer(parent: Node, a: Vector3, b: Vector3, width: float = 0.015, color: Color = Color(1.0, 0.85, 0.5), life: float = 0.07) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = width
	cyl.bottom_radius = width
	cyl.height = length
	cyl.radial_segments = 4
	mesh.mesh = cyl
	mesh.material_override = _glow(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	var dir := (b - a) / length
	var up := Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	# Cylinders point along Y; build a basis whose Y axis follows the shot.
	var x := up.cross(dir).normalized()
	var z := x.cross(dir).normalized()
	mesh.global_transform = Transform3D(Basis(x, dir, z), (a + b) * 0.5)
	_fade_and_free(mesh, life)


static func _flash(parent: Node, at: Vector3, color: Color, size: float, life: float) -> void:
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 8
	s.rings = 4
	mesh.mesh = s
	mesh.material_override = _glow(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = at
	_fade_and_free(mesh, life)


static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _fade_and_free(node: Node3D, life: float) -> void:
	var tween := node.create_tween()
	tween.tween_property(node, "transparency", 1.0, life)
	tween.tween_callback(node.queue_free)
