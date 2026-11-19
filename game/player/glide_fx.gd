class_name GlideFx
extends MeshInstance3D
## What a bullet glide looks like around the body, for everyone: a thin wind trail off
## each foot in the player's trim colour, and a few faint speed streaks rushing past,
## more and longer the faster you go. Drawn in the world (top-level), additive and
## see-through, never thick enough to hide anyone. It eases in as a glide starts and
## out as it ends (the trail left behind fades on its own). The foot trail is a mesh of
## its own so your own can be kept out of your first-person view (see set_trail_layers):
## from inside the body it would sweep across the screen whenever you look back.

const LIFE := 0.32          ## seconds a piece of the foot trail lasts (it goes faster once the glide is over)...
const MAX_LENGTH := 2.0     ## ...and the trail is never longer than this (metres), however fast you go
const WIDTH := 0.04         ## half the trail's width at its newest end (metres)
const STREAKS := 7          ## speed streaks around the body at full speed
const STREAK_LIFE := 0.22   ## seconds each one lasts
const STREAK_FROM := 9.0    ## no streaks below this speed (m/s); all of them by STREAK_FULL
const STREAK_FULL := 20.0
const STREAK_RADIUS := Vector2(0.55, 1.25)   ## how far from the body they pass (metres, nearest and furthest)
const ALPHA := 0.45         ## the trail at its brightest
const STREAK_ALPHA := 0.28

var _feet: Array = [[], []]   # per foot: [point, age]
var _streaks: Array = []      # [centre, direction, length, age]
var _mesh := ImmediateMesh.new()          # the speed streaks
var _trail_mesh := ImmediateMesh.new()    # the foot trails
var _trail: MeshInstance3D
var _color := Color.WHITE
var _on := 0.0                # eases in and out with the glide
var _rng := RandomNumberGenerator.new()
var _spawn := 0.0


func setup(color: Color) -> GlideFx:
	_color = color
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	material_override = m
	_trail = MeshInstance3D.new()
	_trail.top_level = true
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.extra_cull_margin = 16.0
	_trail.material_override = m
	add_child(_trail)
	return self


## The render layers the foot trail is drawn on (your own: the body's, which your
## first-person camera does not draw).
func set_trail_layers(mask: int) -> void:
	_trail.layers = mask


func set_color(color: Color) -> void:
	_color = color


## Every frame. `gliding`: the body is in a glide now; `feet`: where its feet are
## (world); `velocity`: how it is moving; `body`: its middle (world).
func tick(delta: float, gliding: bool, feet: Array, velocity: Vector3, body: Vector3) -> void:
	_on = move_toward(_on, 1.0 if gliding else 0.0, delta * (8.0 if gliding else 5.0))
	for list in _feet:
		for p in list:
			p[1] += delta * (1.0 if gliding else 2.5)
		while not list.is_empty() and list[0][1] > LIFE:
			list.pop_front()
	if _on > 0.0 and feet.size() == 2:
		for i in 2:
			var list: Array = _feet[i]
			var at: Vector3 = feet[i]
			if list.is_empty() or (list[-1][0] as Vector3).distance_squared_to(at) > 0.0025:
				list.append([at, 0.0, _on])
			var length := 0.0
			for j in range(list.size() - 1, 0, -1):
				length += (list[j][0] as Vector3).distance_to(list[j - 1][0])
				if length > MAX_LENGTH:
					list = list.slice(j)
					_feet[i] = list
					break
	for s in _streaks:
		s[3] += delta
	while not _streaks.is_empty() and _streaks[0][3] > STREAK_LIFE:
		_streaks.pop_front()
	var speed := velocity.length()
	var many := clampf((speed - STREAK_FROM) / (STREAK_FULL - STREAK_FROM), 0.0, 1.0) * _on
	if many > 0.0 and speed > 0.1:
		_spawn += delta * many * STREAKS / STREAK_LIFE
		var dir := velocity / speed
		var side := dir.cross(Vector3.UP)
		if side.length_squared() < 0.01:
			side = dir.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(dir).normalized()
		while _spawn >= 1.0:
			_spawn -= 1.0
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(STREAK_RADIUS.x, STREAK_RADIUS.y)
			# Spawned a little ahead: the body flies on past them.
			var centre := body + (side * cos(a) + up * sin(a)) * r + dir * _rng.randf_range(0.2, 1.4)
			_streaks.append([centre, dir, clampf(speed * 0.07, 0.4, 2.0), 0.0])
	_draw()


func _draw() -> void:
	_mesh.clear_surfaces()
	_trail_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam else Vector3.ZERO
	var any := false
	for list in _feet:
		if list.size() >= 2:
			any = true
	if any:
		_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for list in _feet:
			for i in range(1, list.size()):
				_ribbon(list[i - 1], list[i], eye)
		_trail_mesh.surface_end()
	if not _streaks.is_empty():
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for st in _streaks:
			_streak(st, eye)
		_mesh.surface_end()


## One piece of a foot's trail, turned to face the camera, thinning and fading with age.
func _ribbon(a: Array, b: Array, eye: Vector3) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var along := pb - pa
	if along.length_squared() < 0.000001:
		return
	var face := (eye - pa).cross(along).normalized() if eye != Vector3.ZERO else along.cross(Vector3.UP).normalized()
	var ka := 1.0 - float(a[1]) / LIFE
	var kb := 1.0 - float(b[1]) / LIFE
	var ca := Color(_color, ALPHA * ka * ka * float(a[2]))
	var cb := Color(_color, ALPHA * kb * kb * float(b[2]))
	var wa := face * WIDTH * ka
	var wb := face * WIDTH * kb
	_tri(pa - wa, ca, pa + wa, ca, pb + wb, cb, _trail_mesh)
	_tri(pa - wa, ca, pb + wb, cb, pb - wb, cb, _trail_mesh)


## A speed streak: a thin line along the flight, brightest in the middle, fading in and out.
func _streak(s: Array, eye: Vector3) -> void:
	var centre: Vector3 = s[0]
	var dir: Vector3 = s[1]
	var half: float = float(s[2]) * 0.5
	var k := float(s[3]) / STREAK_LIFE
	var fade := sin(k * PI)
	var face := (eye - centre).cross(dir).normalized() if eye != Vector3.ZERO else dir.cross(Vector3.UP).normalized()
	var w := face * 0.012
	var tint := _color.lerp(Color.WHITE, 0.6)
	var mid := Color(tint, STREAK_ALPHA * fade)
	var end := Color(tint, 0.0)
	var a := centre - dir * half
	var b := centre + dir * half
	_tri(a, end, centre - w, mid, centre + w, mid, _mesh)
	_tri(centre - w, mid, b, end, centre + w, mid, _mesh)


func _tri(a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color, into: ImmediateMesh) -> void:
	into.surface_set_color(ca)
	into.surface_add_vertex(a)
	into.surface_set_color(cb)
	into.surface_add_vertex(b)
	into.surface_set_color(cc)
	into.surface_add_vertex(c)
