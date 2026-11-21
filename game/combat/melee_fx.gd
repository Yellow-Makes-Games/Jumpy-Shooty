class_name MeleeFx
## What a melee blow looks like where it lands (and a ground slam, see slam()): a flash, a bright streak along the way
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


## A Karate blow landed (instead of hit()): a punch is a tight burst with a small shock
## ring, a kick a wider arc swept along its way; each blow of the combo a little bigger
## than the one before (`step` 0..5), and the combo's last blow or a full wind-up
## (`finisher`) a big flash with a double ring.
static func karate_hit(parent: Node, at: Vector3, from: Vector3, color: Color, power: float, sweep: Vector3,
		kick: bool, step: int, finisher: bool) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	power = clampf(power, 0.0, 1.0)
	var away := at - from
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	var hot := color.lerp(Color.WHITE, 0.55)
	var grow := 1.0 + 0.12 * clampi(step, 0, 5)
	var way := sweep.normalized() if sweep.length_squared() > 0.01 else away
	if finisher:
		_flash(parent, at, hot, 0.34, 0.12)
		_ring(parent, at, away, color.lerp(Color.WHITE, 0.3), 0.75)   # (a little over a heavy blade's: it fills a close view)
		_ring(parent, at, away, hot, 0.42)
		_streak(parent, at, way, hot, 2.4)
		_sparks(parent, at, away, hot, 1.0)
	elif kick:
		_flash(parent, at, hot, 0.16 * grow, 0.08)
		_streak(parent, at, way, hot, 1.5 * grow)
		_streak(parent, at - way * 0.12, way, color, 1.1 * grow)
		_ring(parent, at, away, color.lerp(Color.WHITE, 0.3), 0.35 * grow)
		_sparks(parent, at, away, hot, 0.4 + 0.1 * step)
	else:
		_flash(parent, at, hot, 0.1 * grow, 0.06)
		_ring(parent, at, away, hot, 0.2 * grow)
		_sparks(parent, at, away, hot, 0.15 + 0.08 * step)


## A palm blast (Karate): the aura bursts out ahead of the palms, at `at` going `forward`:
## a flash and two rings racing out, whether it hits anyone or not. Looks only.
static func karate_burst(parent: Node, at: Vector3, forward: Vector3, color: Color) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	var hot := color.lerp(Color.WHITE, 0.5)
	_flash(parent, at, hot, 0.3, 0.1)
	_ring(parent, at, forward, hot, 0.7)
	_ring(parent, at + forward * 0.35, forward, color, 1.0)
	_streak(parent, at, forward, hot, 1.6)


## Karate's ground slam: on top of the slam's own shockwave, the aura bursts up out of
## the floor round the fist: a tall flash, a ring standing up and one more racing out flat.
static func karate_slam(parent: Node, at: Vector3, color: Color) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	var hot := color.lerp(Color.WHITE, 0.45)
	_flash(parent, at + Vector3(0, 0.6, 0), hot, 0.55, 0.14)
	_ring(parent, at + Vector3(0, 0.05, 0), Vector3.UP, hot, 1.6)
	_ring(parent, at + Vector3(0, 0.3, 0), Vector3.UP, color, 1.0)
	_streak(parent, at, Vector3.UP, hot, 2.2)


## A small spark at `at` (fists knocked together: see WeaponDraw): a flash and a few sparks, no more.
## `close`: right in front of your own eyes (the flash alone: sparks that near fill the view).
static func spark(parent: Node, at: Vector3, color: Color, close: bool = false) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	var hot := color.lerp(Color.WHITE, 0.55)
	_flash(parent, at, hot, 0.04 if close else 0.07, 0.06)
	if not close:
		_sparks(parent, at, Vector3.UP, hot, 0.12)


const CHIPS := 3   ## one shot strikes sparks off the bodies it hits at most this many times (a shotgun's pellets)

## A bullet landed on a body at `at`: a few sparks struck off it, back the way it came
## (`away`), in the colour of the body it hit. Small: it marks the hit and no more.
static func chip(parent: Node, at: Vector3, away: Vector3, color: Color) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	var hot := color.lerp(Color.WHITE, 0.35)
	_flash(parent, at, hot, 0.06, 0.06)
	_sparks(parent, at, away, hot, 0.0)


## A ground slam landed at `at` (on the floor): a shockwave ring racing out across the
## floor in the attacker's colour, a flash, dust rolling out and debris thrown up.
static func slam(parent: Node, at: Vector3, color: Color, power: float) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	power = clampf(power, 0.0, 1.0)
	var hot := color.lerp(Color.WHITE, 0.5)
	var reach := GroundSlam.RADIUS
	_flash(parent, at + Vector3(0, 0.25, 0), hot, lerpf(0.3, 0.55, power), 0.1)
	# Two rings flat on the floor: a bright thin one that reaches the slam's edge, a fainter one behind it.
	for i in 2:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.9 if i == 0 else 0.8
		t.outer_radius = 1.0
		t.rings = 40
		t.ring_segments = 4
		ring.mesh = t
		ring.material_override = _glow(hot if i == 0 else color)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ring)
		ring.global_position = at + Vector3(0, 0.06 + 0.04 * i, 0)
		ring.scale = Vector3(0.3, 0.25, 0.3)
		var out := reach * (1.0 if i == 0 else 0.7)
		var life := lerpf(0.28, 0.4, power) + 0.08 * i
		var tween := ring.create_tween().set_parallel()
		tween.tween_property(ring, "scale", Vector3(out, 0.12, out), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(ring, "transparency", 1.0, life).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(ring.queue_free)
	# Dust: grey puffs rolling outward along the floor.
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var dust := StandardMaterial3D.new()
	dust.albedo_color = Color(0.7, 0.7, 0.72, 0.5)
	dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var puffs := int(lerpf(8.0, 14.0, power))
	for i in puffs:
		var cloud := MeshInstance3D.new()
		cloud.mesh = puff
		cloud.material_override = dust
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(cloud)
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * (float(i) + randf_range(-0.3, 0.3)) / float(puffs))
		cloud.global_position = at + way * 0.4 + Vector3(0, 0.2, 0)
		cloud.scale = Vector3.ONE * 0.4
		var life := randf_range(0.45, 0.75)
		var tween := cloud.create_tween().set_parallel()
		tween.tween_property(cloud, "global_position", at + way * reach * randf_range(0.6, 0.95) + Vector3(0, randf_range(0.3, 0.7), 0), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(cloud, "scale", Vector3.ONE * randf_range(1.2, 1.9) * lerpf(0.7, 1.0, power), life).set_ease(Tween.EASE_OUT)
		tween.tween_property(cloud, "transparency", 1.0, life).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(cloud.queue_free)
	# Debris: chips of floor thrown up and out, and sparks with them.
	var chip := BoxMesh.new()
	chip.size = Vector3(0.09, 0.07, 0.11)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.32, 0.33, 0.36)
	stone.roughness = 0.9
	for i in int(lerpf(10.0, 26.0, power)):
		var bit := MeshInstance3D.new()
		bit.mesh = chip
		bit.material_override = stone
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(bit)
		var way := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		var speed := way * randf_range(2.0, 7.0) + Vector3.UP * randf_range(4.0, lerpf(7.0, 11.0, power))
		var start := at + way * randf_range(0.1, 0.9) + Vector3(0, 0.1, 0)
		var life := randf_range(0.5, 0.9)
		var size := randf_range(0.6, 1.8)
		var tumble := Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var fly := func(t: float) -> void:
			bit.global_transform = Transform3D(Basis.from_euler(tumble * t).scaled(Vector3.ONE * size * (1.0 - 0.6 * t / life)),
				start + speed * t + Vector3.DOWN * 11.0 * t * t)
		fly.call(0.0)
		var tween := bit.create_tween()
		tween.tween_method(fly, 0.0, life, life)
		tween.tween_callback(bit.queue_free)
	_sparks(parent, at + Vector3(0, 0.15, 0), Vector3.UP, hot, power)


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
	var x := Vector3.UP.cross(away).normalized() if absf(away.normalized().y) < 0.95 else Vector3.RIGHT   # (straight up: a ring flat on the floor)
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
