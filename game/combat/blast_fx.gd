class_name BlastFx
## How a rocket, grenade, mortar shell, flare or ball of plasma looks going off: a white
## flash, a fireball of glowing puffs thrown out and slowed, sparks or shrapnel, a shock
## ring along whatever it hit, dust kicked out along the floor, a column of smoke, and a
## flash of light. Looks only (the damage, the scorch mark and the rubble are the
## arena's).
##
## Cheap on purpose: a handful of CPU particle bursts that share a few materials (made
## once, and drawn once as the match starts by FxWarmup, so the first blast does not
## stall while the graphics card builds them), one light, no shadows.
##
## Each sort of round has a style: fire and smoke for a rocket, more shrapnel for a
## grenade, a bigger blast and a tall column of dirt and smoke for a mortar shell,
## burning red sparks for a flare, a cold blue burst with no smoke for plasma.

const LIFE := 3.2   ## seconds before the whole blast is gone (the longest smoke)

static var headless_too := false   ## tests: make blasts without a screen as well

## The styles. Sizes and speeds are in units of the blast's size (`s`, from its radius),
## so one style serves a big blast and a small one.
const STYLES := {
	"rocket": {
		"fire": [Color(1.0, 0.95, 0.75, 1.0), Color(1.0, 0.62, 0.2, 1.0), Color(0.85, 0.28, 0.06, 0.9), Color(0.3, 0.1, 0.04, 0.6), Color(0.1, 0.07, 0.05, 0.0)],
		"fire_n": 25, "fire_life": 0.8, "fire_size": 1.42, "fire_speed": 2.6,
		"flash": Color(2.6, 2.0, 1.3), "flash_size": 2.0,
		"light": Color(1.0, 0.62, 0.28), "light_energy": 14.0, "light_life": 0.5,
		"smoke": [Color(0.18, 0.13, 0.1, 0.0), Color(0.1, 0.09, 0.085, 0.95), Color(0.17, 0.16, 0.15, 0.7), Color(0.3, 0.29, 0.28, 0.0)],
		"smoke_n": 14, "smoke_life": 2.8, "smoke_rise": 0.55, "smoke_size": 2.17,
		"spark": [Color(1.0, 0.8, 0.45), Color(1.0, 0.4, 0.1), Color(0.0, 0.0, 0.0)],
		"spark_n": 18, "spark_speed": 9.0, "spark_life": 0.7, "spark_fall": 14.0,
		"ring": Color(0.9, 0.7, 0.5, 0.7), "dust": true, "chunks": 0,
	},
	"grenade": {
		"fire": [Color(1.0, 0.97, 0.85, 1.0), Color(1.0, 0.7, 0.28, 1.0), Color(0.8, 0.3, 0.07, 0.85), Color(0.28, 0.12, 0.05, 0.5), Color(0.12, 0.1, 0.08, 0.0)],
		"fire_n": 21, "fire_life": 0.6, "fire_size": 1.28, "fire_speed": 3,
		"flash": Color(2.8, 2.3, 1.6), "flash_size": 2.0,
		"light": Color(1.0, 0.68, 0.34), "light_energy": 13.0, "light_life": 0.4,
		"smoke": [Color(0.2, 0.17, 0.13, 0.0), Color(0.14, 0.13, 0.12, 0.95), Color(0.22, 0.21, 0.2, 0.65), Color(0.34, 0.33, 0.31, 0.0)],
		"smoke_n": 12, "smoke_life": 2.4, "smoke_rise": 0.5, "smoke_size": 1.96,
		"spark": [Color(1.0, 0.85, 0.55), Color(0.9, 0.45, 0.15), Color(0.0, 0.0, 0.0)],
		"spark_n": 32, "spark_speed": 13.0, "spark_life": 0.5, "spark_fall": 16.0,
		"ring": Color(0.9, 0.75, 0.55, 0.7), "dust": true, "chunks": 6,
	},
	"shell": {
		"fire": [Color(1.0, 0.92, 0.7, 1.0), Color(1.0, 0.58, 0.18, 1.0), Color(0.8, 0.25, 0.05, 0.9), Color(0.28, 0.1, 0.04, 0.6), Color(0.1, 0.07, 0.05, 0.0)],
		"fire_n": 30, "fire_life": 0.9, "fire_size": 1.49, "fire_speed": 2.5,
		"flash": Color(2.6, 1.9, 1.2), "flash_size": 2.2,
		"light": Color(1.0, 0.6, 0.26), "light_energy": 18.0, "light_life": 0.65,
		"smoke": [Color(0.16, 0.12, 0.09, 0.0), Color(0.09, 0.08, 0.07, 0.95), Color(0.16, 0.15, 0.13, 0.75), Color(0.28, 0.27, 0.25, 0.0)],
		"smoke_n": 22, "smoke_life": 3.0, "smoke_rise": 1.1, "smoke_size": 2.25,
		"spark": [Color(1.0, 0.85, 0.5), Color(0.95, 0.38, 0.1), Color(0.0, 0.0, 0.0)],
		"spark_n": 22, "spark_speed": 8.0, "spark_life": 0.8, "spark_fall": 12.0,
		"ring": Color(0.85, 0.65, 0.45, 0.75), "dust": true, "chunks": 10,
	},
	"flare": {
		"fire": [Color(1.0, 0.75, 0.7, 1.0), Color(1.0, 0.25, 0.18, 1.0), Color(0.7, 0.05, 0.1, 0.85), Color(0.25, 0.02, 0.05, 0.4), Color(0.1, 0.02, 0.03, 0.0)],
		"fire_n": 14, "fire_life": 0.6, "fire_size": 1.22, "fire_speed": 2.3,
		"flash": Color(2.8, 1.4, 1.2), "flash_size": 1.8,
		"light": Color(1.0, 0.3, 0.22), "light_energy": 12.0, "light_life": 1.1,
		"smoke": [Color(0.6, 0.35, 0.35, 0.0), Color(0.5, 0.4, 0.4, 0.5), Color(0.58, 0.54, 0.54, 0.3), Color(0.65, 0.62, 0.62, 0.0)],
		"smoke_n": 7, "smoke_life": 2.4, "smoke_rise": 0.7, "smoke_size": 1.74,
		"spark": [Color(1.0, 0.7, 0.5), Color(1.0, 0.2, 0.12), Color(0.5, 0.02, 0.04), Color(0.0, 0.0, 0.0)],
		"spark_n": 40, "spark_speed": 7.5, "spark_life": 1.3, "spark_fall": 6.0,
		"ring": Color(1.0, 0.35, 0.3, 0.7), "dust": false, "chunks": 0,
	},
	"orb": {
		"fire": [Color(0.85, 0.95, 1.0, 1.0), Color(0.35, 0.7, 1.0, 1.0), Color(0.08, 0.3, 0.9, 0.8), Color(0.02, 0.08, 0.35, 0.4), Color(0.0, 0.02, 0.1, 0.0)],
		"fire_n": 16, "fire_life": 0.5, "fire_size": 1.15, "fire_speed": 2.6,
		"flash": Color(1.6, 2.3, 3.0), "flash_size": 2.0,
		"light": Color(0.45, 0.7, 1.0), "light_energy": 12.0, "light_life": 0.4,
		"smoke": [], "smoke_n": 0, "smoke_life": 0.0, "smoke_rise": 0.0, "smoke_size": 1.45,
		"spark": [Color(0.8, 0.95, 1.0), Color(0.25, 0.6, 1.0), Color(0.0, 0.0, 0.0)],
		"spark_n": 22, "spark_speed": 8.0, "spark_life": 0.45, "spark_fall": 3.0,
		"ring": Color(0.5, 0.85, 1.0, 0.85), "dust": false, "chunks": 0, "air_ring": true,
	},
}

static var _mats := {}
static var _ramps := {}
static var _curves := {}
static var _meshes := {}
static var _look := "rocket"   # the style of the blast being made (for the caches' keys)


## A blast at `at`, `radius` the weapon's splash radius, in the style `look` (a
## WeaponData.look(); anything else is a rocket's). It finds the surface it went off
## against itself: on a wall or the floor the blast is thrown off it, with a ring along
## it (and, on the floor, dust); in the air it is round.
static func spawn(parent: Node, at: Vector3, radius: float, look: String = "rocket", normal: Vector3 = Vector3.INF) -> void:
	if (DisplayServer.get_name() == "headless" and not headless_too) or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	_look = look if STYLES.has(look) else "rocket"
	var st: Dictionary = STYLES[_look]
	var s := radius * 0.4   # the blast's size: the fireball is about this far across each way
	if normal == Vector3.INF:
		normal = _surface(parent, at, s)
	var on_surface := normal != Vector3.ZERO
	var up := normal if on_surface else Vector3.UP
	var root := Node3D.new()
	root.name = "Blast"
	parent.add_child(root, true)
	root.global_transform = Transform3D(_basis_up(up), at)
	_flash(root, st, s)
	_fire(root, st, s, on_surface)
	if st.smoke_n > 0:
		_smoke(root, st, s, on_surface, up)
	_sparks(root, st, s, on_surface)
	if int(st.chunks) > 0 and on_surface:
		_chunks(root, st, s)
	if on_surface or st.get("air_ring", false):
		_ring(root, st, s, on_surface)
	if st.dust and on_surface and up.y > 0.7:
		_dust(root, s)
	_light(root, st, s)
	root.get_tree().create_timer(LIFE, false).timeout.connect(root.queue_free)


## Which way the surface it went off against faces (the nearest within reach), or
## Vector3.ZERO in the open air. Six short rays, as BulletMarks.scorch does.
static func _surface(parent: Node, at: Vector3, s: float) -> Vector3:
	var world: World3D = parent.get_viewport().find_world_3d() if parent.get_viewport() else null
	if world == null:
		return Vector3.ZERO
	var space := world.direct_space_state
	if space == null:
		return Vector3.ZERO
	var reach := clampf(s * 0.35, 0.25, 0.8)
	var best := INF
	var out := Vector3.ZERO
	for dir: Vector3 in [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at - dir * 0.05, at + dir * reach, 1))
		if hit.is_empty():
			continue
		var d := (hit.position as Vector3).distance_to(at)
		if d < best:
			best = d
			out = (hit.normal as Vector3).normalized()
	return out


## A basis whose Y axis is `up`.
static func _basis_up(up: Vector3) -> Basis:
	var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := side.cross(up).normalized()
	var x := up.cross(z).normalized()
	return Basis(x, up, z)


# ---------------------------------------------------------------------------
# The parts

## The white-hot flash at the heart of it, gone in a tenth of a second or so.
static func _flash(root: Node3D, st: Dictionary, s: float) -> void:
	var quad := MeshInstance3D.new()
	quad.mesh = _quad()
	quad.material_override = _additive("flash:%s" % st.flash, st.flash, true)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(quad)
	quad.position = Vector3.UP * s * 0.5
	quad.scale = Vector3.ONE * s * st.flash_size * 0.6
	var tw := quad.create_tween().set_parallel()
	tw.tween_property(quad, "scale", Vector3.ONE * s * st.flash_size, 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(quad, "transparency", 1.0, 0.1).set_delay(0.02)
	tw.chain().tween_callback(quad.queue_free)


## The fireball: glowing puffs thrown out fast and slowed hard, white to orange to
## nothing.
static func _fire(root: Node3D, st: Dictionary, s: float, on_surface: bool) -> void:
	var p := _burst(root, int(st.fire_n), st.fire_life, _quad(), _particles_mat("fire"))
	p.position = Vector3.UP * s * (0.35 if on_surface else 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = s * 0.35
	p.direction = Vector3.UP
	p.spread = 80.0 if on_surface else 180.0
	p.initial_velocity_min = s * st.fire_speed * 0.25
	p.initial_velocity_max = s * st.fire_speed
	p.damping_min = s * st.fire_speed * 1.8
	p.damping_max = s * st.fire_speed * 2.4
	p.gravity = Vector3.UP * s * 1.2
	p.lifetime_randomness = 0.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.scale_amount_min = s * st.fire_size * 0.75
	p.scale_amount_max = s * st.fire_size * 1.25
	p.scale_amount_curve = _curve("swell", [Vector2(0.0, 0.55), Vector2(0.2, 1.0), Vector2(1.0, 1.35)])
	p.color_ramp = _ramp("fire:" + _look, st.fire, [0.0, 0.15, 0.4, 0.7, 1.0])
	p.emitting = true


## Smoke: dark puffs that stay, swell and rise after the fire has gone.
static func _smoke(root: Node3D, st: Dictionary, s: float, on_surface: bool, up: Vector3) -> void:
	var p := _burst(root, int(st.smoke_n), st.smoke_life, _quad(), _particles_mat("smoke"))
	p.position = Vector3.UP * s * (0.4 if on_surface else 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = s * 0.35
	p.direction = Vector3.UP
	p.spread = 60.0 if on_surface else 180.0
	p.initial_velocity_min = s * 0.4
	p.initial_velocity_max = s * 1.6
	p.damping_min = s * 1.2
	p.damping_max = s * 1.8
	# (the air carries smoke up, whichever way the wall it came off faces)
	p.gravity = Vector3.UP * s * st.smoke_rise
	p.local_coords = false
	p.lifetime_randomness = 0.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -25.0
	p.angular_velocity_max = 25.0
	p.scale_amount_min = s * st.smoke_size * 0.8
	p.scale_amount_max = s * st.smoke_size * 1.2
	p.scale_amount_curve = _curve("billow", [Vector2(0.0, 0.5), Vector2(0.3, 1.0), Vector2(1.0, 1.8)])
	p.color_ramp = _ramp("smoke:" + _look, st.smoke, [0.0, 0.1, 0.5, 1.0])
	if up.y < 0.5 and on_surface:
		p.spread = 75.0
	p.emitting = true


## Sparks or shrapnel: bright streaks along the way they fly, dropping.
static func _sparks(root: Node3D, st: Dictionary, s: float, on_surface: bool) -> void:
	var p := _burst(root, int(st.spark_n), st.spark_life, _streak(), _particles_mat("spark"))
	p.position = Vector3.UP * s * 0.15
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = s * 0.15
	p.direction = Vector3.UP
	p.spread = 85.0 if on_surface else 180.0
	p.initial_velocity_min = s * st.spark_speed * 0.4
	p.initial_velocity_max = s * st.spark_speed
	p.damping_min = s * 1.0
	p.damping_max = s * 2.0
	p.gravity = Vector3.DOWN * st.spark_fall
	p.lifetime_randomness = 0.5
	p.particle_flag_align_y = true
	p.scale_amount_min = minf(s * 0.45, 1.6)
	p.scale_amount_max = minf(s * 0.75, 2.2)
	p.scale_amount_curve = _curve("dwindle", [Vector2(0.0, 1.0), Vector2(1.0, 0.3)])
	p.color_ramp = _ramp("spark:" + _look, st.spark, [])
	p.emitting = true


## Bits of dirt and stone thrown up, that fall back.
static func _chunks(root: Node3D, st: Dictionary, s: float) -> void:
	var p := _burst(root, int(st.chunks), 1.1, _chunk(), _particles_mat("chunk"))
	p.position = Vector3.UP * s * 0.1
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = s * 3.0
	p.initial_velocity_max = s * 6.5
	p.gravity = Vector3.DOWN * 18.0
	p.lifetime_randomness = 0.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = minf(s * 0.25, 0.8)
	p.scale_amount_max = minf(s * 0.55, 1.4)
	p.color_ramp = _ramp("chunk", [Color(0.36, 0.29, 0.22), Color(0.3, 0.25, 0.2), Color(0.3, 0.25, 0.2, 0.0)], [0.0, 0.85, 1.0])
	p.emitting = true


## The shock ring: a thin bright circle racing out along the surface (or, for plasma
## in the air, facing the way up).
static func _ring(root: Node3D, st: Dictionary, s: float, on_surface: bool) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = _plane()
	ring.material_override = _additive("ring:%s" % st.ring, st.ring, false)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	ring.position = Vector3.UP * (0.06 if on_surface else 0.0)
	ring.scale = Vector3.ONE * s * 0.4
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3.ONE * s * 3.6, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring, "transparency", 1.0, 0.32).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)


## Dust kicked out flat along the floor, all the way round.
static func _dust(root: Node3D, s: float) -> void:
	var p := _burst(root, 12, 1.5, _quad(), _particles_mat("smoke"))
	p.position = Vector3.UP * s * 0.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = s * 0.3
	p.direction = Vector3.RIGHT
	p.spread = 180.0
	p.flatness = 1.0   # (round, along the floor)
	p.initial_velocity_min = s * 5.0
	p.initial_velocity_max = s * 7.5
	p.damping_min = s * 7.0
	p.damping_max = s * 9.0
	p.gravity = Vector3.UP * s * 0.3
	p.lifetime_randomness = 0.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = s * 0.7
	p.scale_amount_max = s * 1.0
	p.scale_amount_curve = _curve("billow", [Vector2(0.0, 0.5), Vector2(0.3, 1.0), Vector2(1.0, 1.8)])
	p.color_ramp = _ramp("dust", [Color(0.55, 0.5, 0.44, 0.0), Color(0.55, 0.5, 0.44, 0.55), Color(0.6, 0.57, 0.52, 0.0)], [0.0, 0.1, 1.0])
	p.emitting = true


## The flash of light on everything round it: bright at once, then fast away.
static func _light(root: Node3D, st: Dictionary, s: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = st.light
	light.light_energy = st.light_energy
	light.omni_range = s * 7.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	root.add_child(light)
	light.position = Vector3.UP * s * 0.6
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, st.light_life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_callback(light.queue_free)


# ---------------------------------------------------------------------------
# Shared pieces (made once)

## A one-shot burst of `amount` particles under `root`, all let go at once.
static func _burst(root: Node3D, amount: int, life: float, mesh: Mesh, material: Material) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = maxf(life, 0.05)
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.mesh = mesh
	p.material_override = material
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.emitting = false
	root.add_child(p)
	return p


static func _ramp(key: String, colors: Array, offsets: Array) -> Gradient:
	if _ramps.has(key):
		return _ramps[key]
	var g := Gradient.new()
	var offs: Array = offsets if offsets.size() == colors.size() else []
	if offs.is_empty():
		for i in colors.size():
			offs.append(float(i) / maxf(colors.size() - 1, 1))
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(colors)
	_ramps[key] = g
	return g


static func _curve(key: String, points: Array) -> Curve:
	if _curves.has(key):
		return _curves[key]
	var c := Curve.new()
	c.max_value = 2.0
	for pt: Vector2 in points:
		c.add_point(pt)
	_curves[key] = c
	return c


## A quad that the particle material turns to face the camera.
static func _quad() -> QuadMesh:
	if not _meshes.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	return _meshes["quad"]


## A flat square, facing up (the ring).
static func _plane() -> PlaneMesh:
	if not _meshes.has("plane"):
		var q := PlaneMesh.new()
		q.size = Vector2.ONE
		_meshes["plane"] = q
	return _meshes["plane"]


## A thin streak along Y (a spark: CPUParticles3D lines it up with the way it flies).
static func _streak() -> BoxMesh:
	if not _meshes.has("streak"):
		var b := BoxMesh.new()
		b.size = Vector3(0.025, 0.4, 0.025)
		_meshes["streak"] = b
	return _meshes["streak"]


static func _chunk() -> BoxMesh:
	if not _meshes.has("chunk"):
		var b := BoxMesh.new()
		b.size = Vector3(0.12, 0.09, 0.1)
		_meshes["chunk"] = b
	return _meshes["chunk"]


## The particle materials: "fire" is a glowing puff that covers what is behind it,
## "spark" adds light, "smoke" covers what is behind it, "chunk" is solid. Fire and
## sparks are drawn brighter than white, so the screen's glow picks them up.
static func _particles_mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	match kind:
		"fire":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1.7, 1.7, 1.7)   # (bright enough for the screen's glow to catch)
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.albedo_texture = _fire_texture()
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		"smoke":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.albedo_texture = MapDebris.puff_texture()
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		"spark":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(4.0, 4.0, 4.0)
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		"chunk":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
	_mats[kind] = m
	return m


## A flat additive glow in one colour: the flash (turned to the camera) or the ring
## (lying on the surface).
static func _additive(key: String, color: Color, billboard: bool) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.albedo_texture = _glow_texture()
	else:
		m.albedo_texture = _ring_texture()
	_mats[key] = m
	return m


## A soft round glow, brightest in the middle.
static func _glow_texture() -> Texture2D:
	if not _meshes.has("glow_tex"):
		_meshes["glow_tex"] = _radial([0.0, 0.25, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	return _meshes["glow_tex"]


## A thin ring with a soft inside edge.
static func _ring_texture() -> Texture2D:
	if not _meshes.has("ring_tex"):
		_meshes["ring_tex"] = _radial([0.0, 0.55, 0.86, 0.94, 1.0],
			[Color(1, 1, 1, 0), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	return _meshes["ring_tex"]


## A fire puff: soft and lumpy, its middle hottest.
static func _fire_texture() -> Texture2D:
	if _meshes.has("fire_tex"):
		return _meshes["fire_tex"]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.09
	for y in size:
		for x in size:
			var p := (Vector2(x + 0.5, y + 0.5) / size - Vector2(0.5, 0.5)) * 2.0
			var r := p.length() + noise.get_noise_2d(x, y) * 0.3
			var a := smoothstep(1.0, 0.1, r) * smoothstep(0.98, 0.7, p.length())
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_meshes["fire_tex"] = ImageTexture.create_from_image(img)
	return _meshes["fire_tex"]


static func _radial(offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## One of each part (every style shares these), under `stage`, for FxWarmup: drawn
## once, tiny, as the match starts, so the first real blast finds them built.
static func warm(stage: Node3D) -> void:
	spawn(stage, stage.global_position, 0.004, "grenade", Vector3.UP)   # (on the floor: fire, smoke, sparks, chunks, ring, dust)
	spawn(stage, stage.global_position, 0.004, "orb", Vector3.ZERO)     # (in the air: the ring facing up)
