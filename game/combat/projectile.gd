class_name Projectile
extends Node3D
## A rocket or grenade in flight, as everyone sees it. The host follows its own copy
## of the same flight in Match and decides where it blows up; this one is the look:
## a body with a glowing tail and a trail of smoke, flying the same path (the same
## start, speed and drop), drawn out of the muzzle and onto the real path in a moment.

const BLEND := 0.12   ## seconds to slide from the muzzle onto the real flight path

var id := 0
var weapon: WeaponData
var _pos := Vector3.ZERO      # on the real path (from the eyes)
var _vel := Vector3.ZERO
var _offset := Vector3.ZERO   # muzzle minus eyes, shrinking to nothing
var _t := 0.0
var _smoke_t := 0.0


static func make(projectile_id: int, data: WeaponData, origin: Vector3, direction: Vector3, muzzle: Vector3, color: Color) -> Projectile:
	var p := Projectile.new()
	p.id = projectile_id
	p.weapon = data
	p.name = "Projectile_%d" % projectile_id
	p._pos = origin
	p._vel = direction.normalized() * data.projectile_speed
	p._offset = muzzle - origin if muzzle != Vector3.INF else Vector3.ZERO
	p._build(color)
	return p


func _build(color: Color) -> void:
	var rocket := weapon.projectile_gravity <= 0.0
	var body := MeshInstance3D.new()
	if rocket:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.012
		cyl.bottom_radius = 0.045
		cyl.height = 0.42
		cyl.radial_segments = 8
		body.mesh = cyl
		body.rotation = Vector3(-PI / 2.0, 0.0, 0.0)   # the nose along -Z
	else:
		var ball := SphereMesh.new()
		ball.radius = 0.07
		ball.height = 0.14
		ball.radial_segments = 10
		ball.rings = 5
		body.mesh = ball
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.32, 0.35)
	m.metallic = 0.6
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.6
	body.material_override = m
	add_child(body)
	var glow := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09 if rocket else 0.05
	s.height = s.radius * 2.0
	s.radial_segments = 8
	s.rings = 4
	glow.mesh = s
	var g := StandardMaterial3D.new()
	g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.albedo_color = Color(1.0, 0.6, 0.2) if rocket else color
	g.emission_enabled = true
	g.emission = g.albedo_color
	g.emission_energy_multiplier = 4.0
	glow.material_override = g
	glow.position = Vector3(0, 0, 0.24 if rocket else 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	if rocket:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.25)
		light.light_energy = 1.6
		light.omni_range = 4.0
		light.position = glow.position
		add_child(light)


## Where the host's copy would be after `t` seconds (the same sum, step by step).
func _physics_process(delta: float) -> void:
	_t += delta
	_vel.y -= weapon.projectile_gravity * delta
	_pos += _vel * delta
	var k := clampf(1.0 - _t / BLEND, 0.0, 1.0)
	global_position = _pos + _offset * k
	if _vel.length_squared() > 0.01:
		look_at(global_position + _vel, Vector3.UP if absf(_vel.normalized().y) < 0.99 else Vector3.RIGHT)
	_smoke_t -= delta
	if _smoke_t <= 0.0 and DisplayServer.get_name() != "headless":
		_smoke_t = 0.025 if weapon.projectile_gravity <= 0.0 else 0.05
		_puff()
	if _t > weapon.fuse + 1.0:
		queue_free()   # the host never said: give up


func _puff() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	s.radial_segments = 6
	s.rings = 3
	mesh.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.8, 0.8, 0.8, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = global_position - _vel.normalized() * 0.25
	var tw := mesh.create_tween().set_parallel()
	tw.tween_property(mesh, "scale", Vector3.ONE * 3.0, 0.6)
	tw.tween_property(mesh, "transparency", 1.0, 0.6)
	tw.chain().tween_callback(mesh.queue_free)
