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
## What it sits on, if that can move (a moving part of the map: an island, the crane's
## load, a walkway): the portal rides it, kept at the same spot on it (see follow).
var carrier: Node3D = null
## Its frame in the carrier's (while it has one).
var carrier_frame := Transform3D.IDENTITY
var _rides := false   # (a carrier that has been freed reads as null: this remembers there was one)
var _look: Node3D   # everything drawn: scaled as it opens (the portal's own frame stays unscaled)
var _disc: MeshInstance3D
var _disc_mat: ShaderMaterial
var _glow: MeshInstance3D          # the band of energy round the edge (portal_rim.gdshader)
var _glow_mat: ShaderMaterial
var _collar: MeshInstance3D        # from the face back to the surface it stands on (see set_seat)
var _light: OmniLight3D
var _motes: CPUParticles3D         # sparks drifting in toward it while it is open
var _t := 0.0
var _open := 0.0

## Opening and closing. A portal put up grows out of a point with a spring to it while
## a ring of light runs off across the surface and sparks fly, and its view clears from
## the middle; one that closes swells for a moment and snaps shut. Closing is looks
## only: Portals has already let go of it (nothing goes through a closing portal), and
## it frees itself when the animation is over.
const OPEN_TIME := 0.34
const CLOSE_TIME := 0.26
const PULSE_TIME := 0.4    ## how long the flare of someone going through lasts
const RIPPLE_TIME := 0.6   ## ...and the ripple across its face
var closing := false
var _age := 0.0            # seconds since it was put up
var _shut := 0.0           # seconds into closing
var _pulse := 0.0          # 1 as someone goes through, easing to 0
var _ripple := 99.0        # seconds since someone went through

## How it sits on what is behind it (see PortalFit.seat): how deep the collar goes, and
## how far behind the middle of its face the surface is (INF: nothing there).
var seat_depth := 0.02
var seat_middle := 0.02

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
	# The oval's own frame for flat meshes that lie in their XZ plane (a cylinder's cap,
	# a plane): x along the portal's x, their up out of the surface.
	var flat := Basis(Vector3(HALF_WIDTH, 0, 0), Vector3(0, 0, 1), Vector3(0, -HALF_HEIGHT, 0))
	# The face while there is nothing to see through it: swirling light in its colour.
	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 28
	disc.rings = 1
	_disc.mesh = disc
	_disc_mat = ShaderMaterial.new()
	_disc_mat.shader = WINDOW_SHADER
	_disc_mat.set_shader_parameter("tint", col)
	_disc_mat.set_shader_parameter("clear", 0.0)
	_disc.material_override = _disc_mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.transform = Transform3D(flat, Vector3.ZERO)
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
	# The collar: from the rim back to the surface, so a portal standing proud of an
	# uneven wall (on a container's ribs, on a sign) is not seen floating off it.
	_collar = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 32
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = col.darkened(0.55)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	tube.material = dark
	_collar.mesh = tube
	_collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_look.add_child(_collar)
	set_seat(seat_depth, seat_middle)
	# The band of energy round the edge: a glow inside the rim, licks of light outside it.
	_glow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0) * RIM_REACH
	_glow.mesh = plane
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = RIM_SHADER
	_glow_mat.set_shader_parameter("tint", col)
	_glow_mat.render_priority = 1
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.transform = Transform3D(flat, Vector3(0, 0, 0.014))
	_look.add_child(_glow)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = LIGHT
	_light.omni_range = 4.0
	_light.position = Vector3(0, 0, 0.6)
	_look.add_child(_light)
	# Sparks that drift in toward the middle while it is open.
	_motes = _sparks(col, 14, 1.1)
	_motes.name = "Motes"
	_motes.local_coords = true
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3(0, 0, 1)
	_motes.emission_ring_radius = 1.25
	_motes.emission_ring_inner_radius = 1.05
	_motes.emission_ring_height = 0.05
	_motes.direction = Vector3(0, 0, 1)
	_motes.spread = 30.0
	_motes.initial_velocity_min = 0.1
	_motes.initial_velocity_max = 0.5
	_motes.radial_accel_min = -1.6
	_motes.radial_accel_max = -0.8
	_motes.scale = Vector3(HALF_WIDTH, HALF_HEIGHT, 1.0)
	_motes.position = Vector3(0, 0, 0.05)
	add_child(_motes)
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
	_animate()


func _ready() -> void:
	if _look:
		_opening_fx(COLORS[slot % 2])
		_motes.emitting = true


const RIM_SHADER := preload("res://game/arena/portal_rim.gdshader")
const RIM_REACH := 1.6   ## the band of energy is drawn out to this many times the oval
const LIGHT := 1.2       ## how bright its light is, open and at rest


## How it sits on the surface (PortalFit.seat): the collar reaches back `depth` metres
## from the face; the surface is `middle` behind the middle of it.
func set_seat(depth: float, middle: float) -> void:
	seat_depth = maxf(depth, 0.02)
	seat_middle = middle
	if _collar:
		_collar.transform = Transform3D(
			Basis(Vector3(HALF_WIDTH * 1.1, 0, 0), Vector3(0, 0, seat_depth), Vector3(0, -HALF_HEIGHT * 1.1, 0)),
			Vector3(0, 0, -seat_depth * 0.5))


## Starts closing: it swells, snaps shut with a flash and frees itself. It is no longer
## anyone's portal (Portals lets go of it before calling this).
func close() -> void:
	if closing:
		return
	closing = true
	_shut = 0.0
	set_live(false)
	name = "ClosingPortal"
	if _motes:
		_motes.emitting = false
	if _look == null:
		queue_free()   # (a map's ring gate has nothing to animate)
		return
	# (Sound looked up, not named: a test run as a script has no autoloads.)
	var sound := get_node_or_null("/root/Sound") if is_inside_tree() else null
	if sound:
		sound.play_at("portal_close", frame.origin + normal * 0.3, "move", 0.0, 0.06)


## Someone (or something) just went through: the rim flares, a ripple crosses the
## face and sparks fly. `out`: they came out of this one (the sparks go with them).
func pulse(out: bool, speed: float = 8.0) -> void:
	if _look == null or closing:
		return
	_pulse = 1.0
	_ripple = 0.0
	var fx := _sparks(COLORS[slot % 2], 22 if out else 14, 0.45)
	fx.one_shot = true
	fx.explosiveness = 0.95
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	fx.emission_ring_axis = Vector3(0, 0, 1)
	fx.emission_ring_radius = 0.9
	fx.emission_ring_inner_radius = 0.2
	fx.emission_ring_height = 0.05
	fx.direction = Vector3(0, 0, 1)
	fx.spread = 28.0 if out else 80.0
	var v := clampf(speed, 4.0, 30.0)
	fx.initial_velocity_min = (v * 0.35) if out else 0.8
	fx.initial_velocity_max = (v * 0.8) if out else 2.4
	fx.damping_min = 4.0
	fx.damping_max = 8.0
	fx.scale = Vector3(HALF_WIDTH, HALF_HEIGHT, 1.0)
	fx.position = Vector3(0, 0, 0.08)
	add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)


## A shot just went through: a ripple across the face and a flicker of the rim (no
## sparks: a shotgun sends eight through at once).
func ripple() -> void:
	if _look == null or closing:
		return
	_pulse = maxf(_pulse, 0.55)
	if _ripple > 0.12:
		_ripple = 0.0


## What it looks like as it opens: a ring of light running off across the surface and
## sparks thrown out along it.
func _opening_fx(col: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.94
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.lightened(0.4), 0.9)
	torus.material = m
	ring.mesh = torus
	ring.name = "Shock"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var small := Basis(Vector3(HALF_WIDTH, 0, 0), Vector3(0, 0, 0.2), Vector3(0, -HALF_HEIGHT, 0))
	ring.transform = Transform3D(small.scaled(Vector3(0.2, 0.2, 1.0)), Vector3(0, 0, 0.02))
	add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "transform", Transform3D(small.scaled(Vector3(1.75, 1.75, 1.0)), Vector3(0, 0, 0.02)), 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)
	var fx := _sparks(col, 30, 0.5)
	fx.name = "OpenSparks"
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	fx.emission_ring_axis = Vector3(0, 0, 1)
	fx.emission_ring_radius = 0.35
	fx.emission_ring_inner_radius = 0.1
	fx.emission_ring_height = 0.02
	fx.direction = Vector3(0, 0, 1)
	fx.spread = 82.0   # mostly along the surface
	fx.initial_velocity_min = 2.0
	fx.initial_velocity_max = 6.5
	fx.damping_min = 5.0
	fx.damping_max = 9.0
	fx.gravity = Vector3(0, -3.0, 0)
	fx.position = Vector3(0, 0, 0.08)
	add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)


## A puff of small glowing sparks (CPUParticles3D), not yet emitting: the caller says
## where from and which way.
static func _sparks(col: Color, amount: int, life: float) -> CPUParticles3D:
	var fx := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 5
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	fx.mesh = mesh
	fx.amount = amount
	fx.lifetime = life
	fx.emitting = false
	fx.gravity = Vector3.ZERO
	fx.scale_amount_min = 0.6
	fx.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(col.lightened(0.6), 1.0))
	fade.set_color(1, Color(col, 0.0))
	fx.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.2))
	fx.scale_amount_curve = shrink
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return fx


## How big it is drawn (1: full size), as it opens (out of a point, past full size
## and back: a spring) or closes (a swell, then shut).
func grown() -> float:
	if closing:
		var u := clampf(_shut / CLOSE_TIME, 0.0, 1.0)
		return (1.0 + 0.12 * smoothstep(0.0, 0.3, u)) * (1.0 - u * u * u)
	var v := clampf(_age / OPEN_TIME, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * v * v * v + 1.70158 * v * v


## Does it draw itself (a portal gun's portal: a map's ring gate is drawn by its gate)?
func has_look() -> bool:
	return _look != null


## Fully open (the animation is over)?
func is_open() -> bool:
	return not closing and _age >= OPEN_TIME


func _process(delta: float) -> void:
	_t += delta
	_age += delta
	_ripple += delta
	_pulse = maxf(_pulse - delta / PULSE_TIME, 0.0)
	if closing:
		_shut += delta
		follow()   # (Portals has let go of it: it keeps to a moving part by itself)
		if _shut >= CLOSE_TIME:
			if is_inside_tree():
				flash(get_parent(), frame.origin + normal * 0.15, COLORS[slot % 2], 0.35)
			queue_free()
			return
	_open = clampf(_age / OPEN_TIME, 0.0, 1.0)
	_animate()


## Draws it as it is at this moment of its opening, closing and pulses.
func _animate() -> void:
	var g := grown()
	var beat := _pulse * _pulse
	var s := maxf(g * (1.0 + 0.02 * sin(_t * 5.0) + 0.07 * beat), 0.01)
	if _look:
		_look.scale = Vector3(s, s, 1.0)
	if _window_root:
		var w := maxf(g, 0.01)
		_window_root.scale = Vector3(w, w, 1.0)
	# The view clears out of the swirl from the middle, a little after it opens.
	var clear := clampf((_age - 0.1) / 0.3, 0.0, 1.0)
	if closing:
		clear = minf(clear, 1.0 - clampf(_shut / 0.1, 0.0, 1.0))
	if _disc_mat:
		_disc_mat.set_shader_parameter("time", _t)
		_disc_mat.set_shader_parameter("ripple", _ripple)
	if _window_mat:
		_window_mat.set_shader_parameter("time", _t)
		_window_mat.set_shader_parameter("clear", clear)
		_window_mat.set_shader_parameter("ripple", _ripple)
	if _glow_mat:
		_glow_mat.set_shader_parameter("time", _t)
		_glow_mat.set_shader_parameter("power", 1.0 + 1.2 * beat + (1.0 - _open) * 0.8 + (0.8 if closing else 0.0))
		_glow_mat.set_shader_parameter("shown", clampf(g * 1.5, 0.0, 1.0))
	if _light:
		_light.light_energy = LIGHT * clampf(g, 0.0, 1.0) * (1.0 + 2.0 * beat + 1.5 * (1.0 - _open))


## Shows the view from `to` (its partner) on this portal, as `cam` would see through
## it, rendered `px` pixels tall. Returns false (and shows the plain face) if the
## camera is not in front of it. Portals calls it every frame for the portals in view,
## and set_live(false) for the rest.
func update_view(cam: Camera3D, to: Portal, px: int) -> bool:
	if _window == null or closing:
		set_live(false)
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
	_view_cam.compositor = Compositor.new()   # none: the world's CMAA2 (GraphicsQuality.use_cmaa2) is the main view's
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


## Rides what it sits on: `carrier` (see Portals.place) and where on it.
func ride(on: Node3D) -> void:
	carrier = on
	_rides = on != null
	if on:
		carrier_frame = on.global_transform.affine_inverse() * frame


## Keeps it where it is on its carrier, if it has one. False when the carrier has gone
## (a walkway drawn in, a part taken away): the portal should close.
func follow() -> bool:
	if not _rides:
		return true
	if not is_instance_valid(carrier) or not carrier.is_inside_tree() or carrier.get_meta("unhookable", false):
		return false
	var now := (carrier.global_transform * carrier_frame).orthonormalized()
	if not now.is_equal_approx(frame):
		frame = now
		normal = frame.basis.z
		transform = frame
	return true


## In the portal's own frame (x right, y up, z out): where `p` is.
func to_local_frame(p: Vector3) -> Vector3:
	return frame.basis.transposed() * (p - frame.origin)


## Is a point inside the oval when seen straight on?
func covers(p: Vector3, margin: float = 1.0) -> bool:
	var l := to_local_frame(p)
	var ex := l.x / (half_width * margin)
	var ey := l.y / (half_height * margin)
	return ex * ex + ey * ey <= 1.0


## A point at (or in front of) this portal, as it is at `other`: the same spot on its
## face, turned round to match (see carry).
func carry_point(other: Portal, p: Vector3) -> Vector3:
	var l := to_local_frame(p)
	return other.frame * Vector3(-l.x, l.y, -l.z)


## A direction going in through this portal, as it comes out of `other`.
func carry(other: Portal, v: Vector3) -> Vector3:
	var l := frame.basis.transposed() * v
	return other.frame.basis * Vector3(-l.x, l.y, -l.z)


## A quick burst of light where someone blinked or went through a portal (visual only).
static func flash(parent: Node, at: Vector3, col: Color, size: float = 1.0) -> void:
	if parent == null:
		return
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7 * size
	sphere.height = 1.8 * size
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


## The portal gun's shot: a bolt of light in the portal's colour from the gun to where
## the portal opens, gone in a moment (visual only: the portal is there at once).
static func bolt(parent: Node, from: Vector3, to: Vector3, col: Color) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return
	var length := from.distance_to(to)
	if length < 0.3:
		return
	var dir := (to - from) / length
	var side := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var x := side.cross(dir).normalized()
	var basis := Basis(x, dir, x.cross(dir).normalized())   # (cylinders point along their Y)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.lightened(0.35), 0.9)
	# The streak it leaves, thinning out behind it.
	var streak := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.012
	cyl.height = length
	cyl.radial_segments = 5
	cyl.rings = 1
	cyl.material = mat
	streak.mesh = cyl
	streak.name = "PortalBolt"
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streak.top_level = true
	parent.add_child(streak)
	streak.global_transform = Transform3D(basis, (from + to) * 0.5)
	var tw := streak.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, BOLT_TIME * 2.2).set_ease(Tween.EASE_IN)
	tw.tween_property(streak, "scale", Vector3(0.2, 1.0, 0.2), BOLT_TIME * 2.2)
	tw.chain().tween_callback(streak.queue_free)
	# The bolt itself: a bright slug that flies the length of it.
	var head := MeshInstance3D.new()
	var slug := SphereMesh.new()
	slug.radius = 0.05
	slug.height = 0.1
	slug.radial_segments = 8
	slug.rings = 4
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = col.lightened(0.6)
	slug.material = hot
	head.mesh = slug
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.top_level = true
	parent.add_child(head)
	head.global_transform = Transform3D(basis.scaled(Vector3(1.0, 6.0, 1.0)), from + dir * minf(0.6, length * 0.5))
	var fly := head.create_tween()
	fly.tween_property(head, "global_position", to, BOLT_TIME)
	fly.tween_callback(head.queue_free)


const BOLT_TIME := 0.07   ## seconds the portal gun's bolt takes to get there, however far


## A shot that reached a surface which takes no portal: the bolt bursts into a dull
## scatter of sparks and a ring that fades, and nothing opens (visual only).
static func fizzle(parent: Node, at: Vector3, n: Vector3, col: Color) -> void:
	if parent == null:
		return
	var dim := col.lerp(Color(0.7, 0.7, 0.75), 0.55)
	var fx := _sparks(dim, 18, 0.4)
	fx.name = "PortalFizzle"
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.direction = Vector3(0, 0, 1)
	fx.spread = 70.0
	fx.initial_velocity_min = 1.5
	fx.initial_velocity_max = 4.5
	fx.damping_min = 4.0
	fx.damping_max = 7.0
	fx.gravity = Vector3(0, -9.0, 0)
	fx.top_level = true
	parent.add_child(fx)
	var up := Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD
	fx.global_transform = Transform3D(Basis.looking_at(-n, up), at + n * 0.06)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.27
	torus.rings = 20
	torus.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(dim, 0.8)
	torus.material = m
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.top_level = true
	parent.add_child(ring)
	# (A torus lies in its XZ plane: its Y out of the surface.)
	var rx := up.cross(n).normalized()
	ring.global_transform = Transform3D(Basis(rx, n, rx.cross(n)), at + n * 0.03)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(0.3, 1.0, 0.3), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(ring.queue_free)


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
