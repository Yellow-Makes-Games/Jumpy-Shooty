class_name Portal
extends Node3D
## One portal on a surface: an upright oval (on a wall) or a flat one (floor or
## ceiling), blue or orange, with a rim in its owner's colour. Its basis: x along
## the surface to the right, y the portal's up, z out of the surface.
##
## The arena's Portals node holds them and moves players through them.

const HALF_WIDTH := 0.85
const HALF_HEIGHT := 1.2
const COLORS := [Color(0.25, 0.7, 1.0), Color(1.0, 0.55, 0.12)]   ## slot 0 blue, slot 1 orange

var owner_id := 0
var slot := 0
var normal := Vector3.UP
## Where it sits and which way it faces (x right, y up, z out), unscaled: the same as
## its transform, kept apart so the maths works before it is in the tree.
var frame := Transform3D.IDENTITY
## Half its width and height (metres): the oval a body must touch to go through. A
## portal gun's are HALF_WIDTH x HALF_HEIGHT; a map's ring gate sets its own.
var half_width := HALF_WIDTH
var half_height := HALF_HEIGHT
var _look: Node3D   # everything drawn: scaled as it opens (the portal's own frame stays unscaled)
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _t := 0.0
var _open := 0.0

## Seeing through it (portal gun portals only; see update_view and Portals.update_views):
## a camera at the other portal renders what is beyond it into _view, and _window draws
## that on the oval. Portal cameras never see a window (VIEW_LAYER), only the plain
## glowing face (FLAT_LAYER while the window is up): a portal seen through a portal is
## a plain one, so the views never feed into each other.
const VIEW_LAYER := 19   ## render layer of a live window: only the main view's camera sees it
const FLAT_LAYER := 20   ## the plain face while the window is live: only portal cameras see it
const WINDOW_SHADER := preload("res://game/arena/portal_window.gdshader")
## Is the window up (the view live this frame)?
var live := false
var _window_root: Node3D   # the window, scaled as it opens (without the rim's pulse)
var _window: MeshInstance3D
var _window_mat: ShaderMaterial
var _view: SubViewport
var _view_cam: Camera3D
var _view_env: Environment
var _view_env_src: Environment


static func make(owner: int, which: int, at: Vector3, n: Vector3, up: Vector3, rim: Color) -> Portal:
	var p := Portal.new()
	p.owner_id = owner
	p.slot = which
	p.place(at, n, up)
	p._build(rim)
	return p


## A portal that belongs to the map, not to a player (a PortalSurgeEvent's ring gate):
## only where it is and how big. Whatever is drawn there is the gate's own business.
static func make_frame(at: Vector3, n: Vector3, up: Vector3, half_w: float, half_h: float) -> Portal:
	var p := Portal.new()
	p.owner_id = 0
	p.half_width = half_w
	p.half_height = half_h
	p.place(at, n, up)
	p.set_process(false)
	return p


func place(at: Vector3, n: Vector3, up: Vector3) -> void:
	normal = n.normalized()
	var y := up.normalized()
	var x := y.cross(normal).normalized()
	frame = Transform3D(Basis(x, y, normal), at)
	transform = frame
	_open = 0.0


func _build(rim: Color) -> void:
	var col: Color = COLORS[slot % 2]
	_look = Node3D.new()
	add_child(_look)
	# The glowing face: a flat cylinder squashed into an oval, lying in the surface.
	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 28
	disc.rings = 1
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.albedo_color = Color(col, 0.72)
	_disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material = _disc_mat
	_disc.mesh = disc
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinder's axis is its Y: turn it to point out of the surface.
	_disc.transform = Transform3D(Basis(Vector3(HALF_WIDTH, 0, 0), Vector3(0, 0, 1), Vector3(0, -HALF_HEIGHT, 0)), Vector3.ZERO)
	_look.add_child(_disc)
	# The rim: a ring of the portal's colour, edged in the owner's.
	for layer in [[1.0, 1.12, col.lightened(0.35)], [1.12, 1.2, rim]]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = layer[0]
		torus.outer_radius = layer[1]
		torus.rings = 32
		torus.ring_segments = 6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = layer[2]
		torus.material = m
		ring.mesh = torus
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.transform = Transform3D(Basis(Vector3(HALF_WIDTH, 0, 0), Vector3(0, 0, 0.25), Vector3(0, -HALF_HEIGHT, 0)), Vector3(0, 0, 0.01))
		_look.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0, 0, 0.6)
	_look.add_child(light)
	# The window you see through (hidden until Portals turns the view on).
	_window_root = Node3D.new()
	add_child(_window_root)
	_window = MeshInstance3D.new()
	var face := CylinderMesh.new()
	face.top_radius = 1.0
	face.bottom_radius = 1.0
	face.height = 0.02
	face.radial_segments = 40
	face.rings = 1
	_window.mesh = face
	_window_mat = ShaderMaterial.new()
	_window_mat.shader = WINDOW_SHADER
	_window_mat.set_shader_parameter("tint", col)
	_window.material_override = _window_mat
	_window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_window.layers = 1 << (VIEW_LAYER - 1)
	_window.transform = _disc.transform
	_window.visible = false
	_window_root.add_child(_window)


func _process(delta: float) -> void:
	_t += delta
	_open = minf(_open + delta * 6.0, 1.0)
	var s := _open * (1.0 + 0.03 * sin(_t * 5.0))
	if _look:
		_look.scale = Vector3(maxf(s, 0.01), maxf(s, 0.01), 1.0)
	if _disc_mat:
		_disc_mat.albedo_color.a = 0.6 + 0.15 * sin(_t * 3.0)
	if _window_root:
		_window_root.scale = Vector3(maxf(_open, 0.01), maxf(_open, 0.01), 1.0)
	if live and _window_mat:
		_window_mat.set_shader_parameter("time", _t)
		_window_mat.set_shader_parameter("clear", clampf((_open - 0.4) / 0.6, 0.0, 1.0))


## Shows the view from `to` (its partner) on this portal, as `cam` would see through
## it, rendered `px` pixels tall. Returns false (and shows the plain face) if the
## camera is not in front of it. Portals calls it every frame for the portals in view,
## and set_live(false) for the rest.
func update_view(cam: Camera3D, to: Portal, px: int) -> bool:
	if _window == null:
		return false
	var eye := cam.global_position
	var l := to_local_frame(eye)
	if l.z < 0.03 or to == null or not is_instance_valid(to):
		set_live(false)
		return false
	if _view == null:
		_make_view()
	# The camera stands where your eye would be on the far side, looking straight
	# out of the other portal (its near plane is that portal's surface, so the wall
	# it sits on is cut away), its frustum through exactly the portal's oval.
	# Coming out of a portal, right and in turn round (Portal.carry): x -> -x, z -> -z.
	var b := to.frame.basis
	var origin := to.frame * Vector3(-l.x, l.y, -l.z)
	_view_cam.global_transform = Transform3D(Basis(-b.x, b.y, -b.z), origin)
	var near := l.z + 0.012   # just past the other portal's own face
	var k := near / l.z
	var h := maxi(px, 32)
	var w := maxi(int(round(h * half_width / half_height)), 16)
	if _view.size != Vector2i(w, h):
		_view.size = Vector2i(w, h)
	_view_cam.set_frustum(2.0 * half_height * k, Vector2(-l.x, -l.y) * k, near, maxf(cam.far, near + 1.0))
	_view_cam.cull_mask = _view_mask(cam.cull_mask)
	_match_environment(cam)
	set_live(true)
	return true


func set_live(on: bool) -> void:
	if live == on or _window == null:
		return
	live = on
	_window.visible = on
	if _disc:
		_disc.layers = (1 << (FLAT_LAYER - 1)) if on else 1
	if _view:
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## What a portal camera draws: what the main camera does, but the full body of
## whoever it is following (the eye is somewhere else now: you see yourself), no
## first-person arms or gun, and portals as plain glowing faces.
## (The layer numbers are CameraRig's and Player's, written out: naming those classes
## here would tie this script to the game's autoloads, and map tests load it bare.)
const _BODY_LAYER := 2        ## CameraRig.BODY_LAYER
const _VIEW_BODY_LAYER := 4   ## CameraRig.VIEW_BODY_LAYER
const _VIEWMODEL_LAYER := 3   ## Player.VIEWMODEL_LAYER


static func _view_mask(main: int) -> int:
	var m := main
	m |= 1 << (_BODY_LAYER - 1)
	m &= ~(1 << (_VIEW_BODY_LAYER - 1))
	m &= ~(1 << (_VIEWMODEL_LAYER - 1))
	m &= ~(1 << (VIEW_LAYER - 1))
	m |= 1 << (FLAT_LAYER - 1)
	return m


func _make_view() -> void:
	_view = SubViewport.new()
	_view.name = "View"
	# Same world as the main view (no own_world_3d): it draws the real arena.
	_view.use_hdr_2d = true   # linear and unclamped: the main view tonemaps it once
	_view.msaa_3d = Viewport.MSAA_DISABLED
	_view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_view.use_taa = false
	_view.positional_shadow_atlas_size = 1024
	_view.audio_listener_enable_3d = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.size = Vector2i(96, 136)
	add_child(_view)
	_view_cam = Camera3D.new()
	_view_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_view_cam.attributes = CameraAttributesPractical.new()   # exposure 1, no blur: the main view does those
	_view.add_child(_view_cam)
	_view_cam.current = true
	_window_mat.set_shader_parameter("view", _view.get_texture())


## The portal camera uses the arena's own look (sky, light, fog...) without its
## tonemapping, glow or colour adjustments, which the main view puts on the window.
## A map event can swap or change the arena's environment as it runs: the copy
## follows.
func _match_environment(cam: Camera3D) -> void:
	var src: Environment = cam.environment
	if src == null:
		var world := cam.get_world_3d()
		if world:
			src = world.environment if world.environment else world.fallback_environment
	if src == null:
		_view_cam.environment = null
		return
	if src != _view_env_src or _view_env == null:
		_view_env_src = src
		_view_env = src.duplicate()
		_view_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_view_env.tonemap_exposure = 1.0
		_view_env.tonemap_white = 1.0
		_view_env.glow_enabled = false
		_view_env.adjustment_enabled = false
		_view_cam.environment = _view_env
	# What the map events change while they run.
	_view_env.ambient_light_color = src.ambient_light_color
	_view_env.ambient_light_energy = src.ambient_light_energy
	_view_env.background_energy_multiplier = src.background_energy_multiplier
	_view_env.fog_light_color = src.fog_light_color
	_view_env.fog_density = src.fog_density
	_view_env.fog_light_energy = src.fog_light_energy


## In the portal's own frame (x right, y up, z out): where `p` is.
func to_local_frame(p: Vector3) -> Vector3:
	return frame.basis.transposed() * (p - frame.origin)


## Is a point inside the oval when seen straight on?
func covers(p: Vector3, margin: float = 1.0) -> bool:
	var l := to_local_frame(p)
	var ex := l.x / (half_width * margin)
	var ey := l.y / (half_height * margin)
	return ex * ex + ey * ey <= 1.0


## A direction going in through this portal, as it comes out of `other`.
func carry(other: Portal, v: Vector3) -> Vector3:
	var l := frame.basis.transposed() * v
	return other.frame.basis * Vector3(-l.x, l.y, -l.z)


## A quick burst of light where someone blinked or went through a portal (visual only).
static func flash(parent: Node, at: Vector3, col: Color) -> void:
	if parent == null:
		return
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.8
	sphere.radial_segments = 12
	sphere.rings = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col, 0.7)
	sphere.material = mat
	m.mesh = sphere
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.top_level = true
	parent.add_child(m)
	m.global_position = at
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(0.15, 1.4, 0.15), 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(m.queue_free)


## Blink: a stream of sparks that flies from where you set off to where you land,
## leaving a fading trail along the way (visual only).
static func trail(parent: Node, from: Vector3, to: Vector3, col: Color) -> void:
	if parent == null:
		return
	const TRAVEL := 0.16   # seconds for the sparks to reach where you land
	var fx := CPUParticles3D.new()
	fx.name = "BlinkTrail"
	fx.top_level = true
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	fx.mesh = mesh
	fx.amount = 90
	fx.lifetime = 0.45
	fx.explosiveness = 0.0
	fx.local_coords = false   # sparks stay where they were dropped as the emitter flies on
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fx.emission_sphere_radius = 0.35
	fx.direction = Vector3.UP
	fx.spread = 180.0
	fx.gravity = Vector3.ZERO
	fx.initial_velocity_min = 0.3
	fx.initial_velocity_max = 1.2
	fx.damping_min = 1.0
	fx.damping_max = 2.0
	fx.scale_amount_min = 0.6
	fx.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(col.lightened(0.6), 1.0))
	fade.set_color(1, Color(col, 0.0))
	fx.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	fx.scale_amount_curve = shrink
	parent.add_child(fx)
	fx.global_position = from
	fx.emitting = true
	var tw := fx.create_tween()
	tw.tween_property(fx, "global_position", to, TRAVEL).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): fx.emitting = false)
	tw.tween_interval(fx.lifetime + 0.1)
	tw.tween_callback(fx.queue_free)
