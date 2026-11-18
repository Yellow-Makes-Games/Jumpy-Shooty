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
var _look: Node3D   # everything drawn: scaled as it opens (the portal's own frame stays unscaled)
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _t := 0.0
var _open := 0.0


static func make(owner: int, which: int, at: Vector3, n: Vector3, up: Vector3, rim: Color) -> Portal:
	var p := Portal.new()
	p.owner_id = owner
	p.slot = which
	p.place(at, n, up)
	p._build(rim)
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


func _process(delta: float) -> void:
	_t += delta
	_open = minf(_open + delta * 6.0, 1.0)
	var s := _open * (1.0 + 0.03 * sin(_t * 5.0))
	if _look:
		_look.scale = Vector3(maxf(s, 0.01), maxf(s, 0.01), 1.0)
	if _disc_mat:
		_disc_mat.albedo_color.a = 0.6 + 0.15 * sin(_t * 3.0)


## In the portal's own frame (x right, y up, z out): where `p` is.
func to_local_frame(p: Vector3) -> Vector3:
	return frame.basis.transposed() * (p - frame.origin)


## Is a point inside the oval when seen straight on?
func covers(p: Vector3, margin: float = 1.0) -> bool:
	var l := to_local_frame(p)
	var ex := l.x / (HALF_WIDTH * margin)
	var ey := l.y / (HALF_HEIGHT * margin)
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
