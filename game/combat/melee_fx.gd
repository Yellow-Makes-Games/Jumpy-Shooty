class_name MeleeFx
## What a melee blow looks like where it lands: a flash, a bright streak along the way
## the weapon was going, a burst of sparks in the attacker's colour and, for a blow
## that was wound up, a ring that snaps outward.
## Everyone sees them. Bigger the more the swing was wound up (`power` 0..1).


## A blow landed at `at`, struck from `from` (where the attacker stands), the weapon
## travelling along `sweep` (zero: a thrust, straight in).
static func hit(parent: Node, at: Vector3, from: Vector3, color: Color, power: float, sweep: Vector3 = Vector3.ZERO) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	power = clampf(power, 0.0, 1.0)
	var away := at - from
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	var hot := color.lerp(Color.WHITE, 0.55)
	_flash(parent, at, hot, lerpf(0.11, 0.2, power), lerpf(0.06, 0.1, power))
	_streak(parent, at, sweep.normalized() if sweep.length_squared() > 0.01 else away, hot, lerpf(0.8, 2.0, power))
	_sparks(parent, at, away, hot, power)
	if power >= MeleeSwing.HEAVY_AT:
		_ring(parent, at, away, color.lerp(Color.WHITE, 0.3), lerpf(0.35, 0.7, power))


static func _sparks(parent: Node, at: Vector3, away: Vector3, color: Color, power: float) -> void:
	var throw := (away + Vector3.UP * 0.6).normalized()   # on the way the blow was going, and up
	var streak := BoxMesh.new()
	streak.size = Vector3(0.03, 0.24, 0.03)
	var material := _glow(color)
	for i in int(lerpf(8.0, 26.0, power)):
		var spark := MeshInstance3D.new()
		spark.mesh = streak
		spark.material_override = material
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(spark)
		# Each flies its own way inside a cone, slows, drops and shrinks away.
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var speed := (throw + off * 0.85).normalized() * randf_range(lerpf(2.5, 4.0, power), lerpf(6.5, 12.0, power))
		var life := randf_range(0.22, lerpf(0.34, 0.52, power))
		var size := randf_range(0.5, lerpf(1.0, 1.5, power))
		var fly := func(t: float) -> void:
			var slowed := (1.0 - exp(-3.0 * t)) / 3.0
			var where := at + speed * slowed + Vector3.DOWN * 7.0 * t * t
			var going := (speed * exp(-3.0 * t) + Vector3.DOWN * 14.0 * t).normalized()
			var side := going.cross(Vector3.UP if absf(going.y) < 0.95 else Vector3.RIGHT).normalized()
			var left := 1.0 - t / life
			spark.global_transform = Transform3D(Basis(side, going, side.cross(going)).scaled_local(Vector3(left, 0.4 + 0.6 * left, left) * size), where)
		fly.call(0.0)
		var tween := spark.create_tween()
		tween.tween_method(fly, 0.0, life, life)
		tween.tween_callback(spark.queue_free)


static func _flash(parent: Node, at: Vector3, color: Color, size: float, life: float) -> void:
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 12
	s.rings = 6
	mesh.mesh = s
	mesh.material_override = _glow(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = at
	var tween := mesh.create_tween().set_parallel()
	tween.tween_property(mesh, "scale", Vector3.ONE * 1.8, life)
	tween.tween_property(mesh, "transparency", 1.0, life)
	tween.chain().tween_callback(mesh.queue_free)


## The mark of the blow: a thin bright streak along `way` that stretches out and fades.
static func _streak(parent: Node, at: Vector3, way: Vector3, color: Color, length: float) -> void:
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 6
	s.rings = 3
	mesh.mesh = s
	mesh.material_override = _glow(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	var up := Vector3.UP if absf(way.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := up.cross(way).normalized()
	var turned := Basis(x, way, x.cross(way))
	mesh.global_transform = Transform3D(turned, at)
	mesh.scale = Vector3(0.1, length * 0.3, 0.1)
	var tween := mesh.create_tween().set_parallel()
	tween.tween_property(mesh, "scale", Vector3(0.02, length, 0.02), 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mesh, "transparency", 1.0, 0.16).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh.queue_free)


## A thin ring facing the attacker that snaps out from the blow and fades.
static func _ring(parent: Node, at: Vector3, away: Vector3, color: Color, size: float) -> void:
	var mesh := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 20
	t.ring_segments = 4
	mesh.mesh = t
	mesh.material_override = _glow(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	# A torus lies flat (its axis is Y): stand it up across the way the blow went.
	var x := Vector3.UP.cross(away).normalized()
	mesh.global_transform = Transform3D(Basis(x, away, x.cross(away)), at)
	mesh.scale = Vector3(0.12, 0.02, 0.12)
	var tween := mesh.create_tween().set_parallel()
	tween.tween_property(mesh, "scale", Vector3(size, 0.02, size), 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mesh, "transparency", 1.0, 0.18).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh.queue_free)


static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m
