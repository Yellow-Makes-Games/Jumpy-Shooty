class_name ShotFx
## Placeholder shot effects: tracer line, muzzle flash and impact puff.
## Simple shapes for now; real effects come with the art pass.


## One shot: a tracer and an impact for each pellet (`ends`, `hits`: one per pellet),
## and a muzzle flash sized for the gun. `vias`: per pellet, where it went into and came
## out of portals ([in, out, ...]; see Portals.path_bends): its tracer goes through them.
static func spawn(parent: Node, muzzle: Vector3, ends: PackedVector3Array, hits: Array, weapon: String = "pistol", vias: Array = []) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	weapon = WeaponData.look_of(weapon)
	var flash: float = {"shotgun": 0.2, "rifle": 0.11, "sniper": 0.22, "break_action": 0.24, "revolver": 0.16,
		"lever_action": 0.16, "bolt_action": 0.2, "railgun": 0.26, "lmg": 0.13, "smg": 0.09, "machine_pistol": 0.08, "akimbo": 0.1,
		"derringer": 0.14, "auto_shotgun": 0.18, "slug_shotgun": 0.2, "air_cannon": 0.05, "minigun": 0.12, "battle_rifle": 0.14,
		"laser_rifle": 0.05, "plasma_pistol": 0.07, "anti_materiel": 0.32, "harpoon_gun": 0.06}.get(weapon, 0.12)
	var width: float = {"shotgun": 0.009, "break_action": 0.009, "sniper": 0.028, "bolt_action": 0.022,
		"railgun": 0.05, "auto_shotgun": 0.009, "air_cannon": 0.03, "laser_rifle": 0.012, "plasma_pistol": 0.02,
		"anti_materiel": 0.035, "harpoon_gun": 0.012, "slug_shotgun": 0.02}.get(weapon, 0.015)
	var color := Color(1.0, 0.85, 0.5)
	if weapon in ["sniper", "bolt_action"]:
		color = Color(0.75, 0.9, 1.0)
	elif weapon == "railgun":
		color = Color(0.35, 0.95, 1.0)
	var data := WeaponData.by_id(weapon)
	if data.tracer_color.a > 0.0:
		color = data.tracer_color
	elif weapon == "anti_materiel":
		color = Color(0.75, 0.9, 1.0)
	var life: float = {"sniper": 0.16, "bolt_action": 0.14, "railgun": 0.45, "anti_materiel": 0.22, "laser_rifle": 0.06,
		"harpoon_gun": 0.3, "air_cannon": 0.12}.get(weapon, 0.07)
	_flash(parent, muzzle, Color(1.0, 0.8, 0.4), flash, 0.05)
	for i in ends.size():
		var hit: bool = hits[i] if i < hits.size() else false
		var via: PackedVector3Array = vias[i] if i < vias.size() else PackedVector3Array()
		var from := muzzle
		for k in range(0, via.size() - 1, 2):
			_tracer(parent, from, via[k], width, color, life)
			from = via[k + 1]
		_tracer(parent, from, ends[i], width, color, life)
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


## A projectile came down at `at`: a blast, or (a nail, a bolt) a small puff where it struck.
static func landed(parent: Node, at: Vector3, data: WeaponData) -> void:
	if not data.explosive:
		if DisplayServer.get_name() != "headless" and is_instance_valid(parent):
			_flash(parent, at, Color(0.9, 0.9, 0.8), 0.1, 0.12)
		return
	explosion(parent, at, data.splash_radius, data.look())


## The sound a projectile makes coming down.
static func landed_sound(data: WeaponData) -> String:
	return "explosion" if data.explosive else "impact_wall"


## A rocket or grenade going off (see BlastFx): `look` is the round's
## (WeaponData.look()), which picks the style.
static func explosion(parent: Node, at: Vector3, radius: float, look: String = "rocket") -> void:
	BlastFx.spawn(parent, at, radius, look)
