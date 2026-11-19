class_name HookRope
extends Node3D
## Draws the grappling hook's rope and hook (see Grapple and HookLine).
##
## The rope is a curve, not a straight line: while there is slack in it, it sags
## and a corkscrew of ripples runs along it toward the hook (the line uncoiling out
## of the launcher); as the slack comes in it straightens, and the moment it pulls
## tight it twangs like a plucked string. Let go, it falls limp and whips back.
##
## The shape is a pure function of five things (curve): where the rope leaves the
## wrist, where the hook is, how much slack there is, how long since the shot, and
## how long since it pulled tight. Nothing is remembered from frame to frame, so
## every copy of the game, and the killcam playing it back, draws the same rope from
## the same numbers.

const SEGMENTS := 48
const RADIUS := 0.018        ## the cable's thickness
const WAVE_LENGTH := 3.2     ## metres from one ripple to the next
const WAVE_HZ := 5.0         ## ripples passing a point each second
const MAX_AMP := 0.75        ## the ripples never swing wider than this (metres)
const SAG_SHARE := 0.35      ## of the slack, this much hangs as sag; the rest is in the ripples
const SAG_G := 14.0          ## the sag takes time to fall: it deepens at this rate (m/s²)
const TWANG := 0.11          ## how far the rope kicks sideways as it pulls tight (metres)
const TWANG_HZ := 13.0
const TWANG_FADE := 9.0      ## the twang dies away at this rate (1/s)

var _multi: MultiMesh
var _line: MultiMeshInstance3D
var _head: Node3D
var _points := PackedVector3Array()


func _init() -> void:
	name = "HookRope"
	top_level = true
	_points.resize(SEGMENTS + 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.13)
	mat.metallic = 0.6
	mat.roughness = 0.4
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.material = mat
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.mesh = cyl
	_multi.instance_count = SEGMENTS
	_line = MultiMeshInstance3D.new()
	_line.multimesh = _multi
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.extra_cull_margin = 16384.0   # (it stretches right across the map: never culled by where this node sits)
	add_child(_line)
	_head = _build_head()
	add_child(_head)
	visible = false


## The hook: a steel dart with three barbs swept back, on a bright yellow collar (so
## it reads as a hook at a glance).
func _build_head() -> Node3D:
	var head := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.21, 0.23)
	steel.metallic = 0.8
	steel.roughness = 0.35
	var bright := StandardMaterial3D.new()
	bright.albedo_color = Color(0.95, 0.7, 0.15)
	var tip := CylinderMesh.new()   # points along -Z once turned
	tip.top_radius = 0.0
	tip.bottom_radius = 0.055
	tip.height = 0.2
	tip.radial_segments = 8
	tip.rings = 1
	tip.material = steel
	var tip_node := MeshInstance3D.new()
	tip_node.mesh = tip
	tip_node.basis = Basis(Vector3.RIGHT, -PI * 0.5)
	tip_node.position = Vector3(0, 0, -0.06)
	head.add_child(tip_node)
	var collar := BoxMesh.new()
	collar.size = Vector3(0.1, 0.1, 0.09)
	collar.material = bright
	var collar_node := MeshInstance3D.new()
	collar_node.mesh = collar
	collar_node.position = Vector3(0, 0, 0.08)
	head.add_child(collar_node)
	var barb := BoxMesh.new()
	barb.size = Vector3(0.025, 0.025, 0.17)
	barb.material = steel
	for i in 3:
		var around := Basis(Vector3.FORWARD, TAU * i / 3.0)
		var b := MeshInstance3D.new()
		b.mesh = barb
		b.basis = around * Basis(Vector3.RIGHT, deg_to_rad(-32.0))
		b.position = around * Vector3(0, 0.075, 0.03)
		head.add_child(b)
	for c in head.get_children():
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return head


## The rope's shape: SEGMENTS + 1 points from the wrist (hand) to the hook, written
## into `out`. slack: metres of rope beyond the straight line. age: seconds since the
## shot. twang: seconds since the rope pulled tight (below 0: it has not).
static func curve(hand: Vector3, hook: Vector3, slack: float, age: float, twang: float, out: PackedVector3Array) -> void:
	var n := out.size() - 1
	var span := hook - hand
	var d := span.length()
	if d < 0.001:
		out.fill(hand)
		return
	var dir := span / d
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir)   # square to the rope, and as near to straight up as that gets
	var loose := maxf(slack, 0.0)
	# Slack shows two ways: the rope sags (as far as it has had time to fall), and the
	# rest of the spare length winds round the line as ripples running toward the hook.
	var level := sqrt(maxf(1.0 - dir.y * dir.y, 0.0))   # a rope going straight up has nowhere to sag
	var sag := minf(0.5 * SAG_G * age * age, sqrt(0.375 * d * loose * SAG_SHARE)) * level
	var waves := clampf(d / WAVE_LENGTH, 1.0, 9.0)
	var amp := 0.0
	if loose > 0.0001:
		amp = minf(d / waves / TAU * sqrt(4.0 * loose * (1.0 - SAG_SHARE) / d), MAX_AMP)
	var buzz := 0.0
	if twang >= 0.0:
		buzz = TWANG * clampf(d / 12.0, 0.35, 1.0) * exp(-TWANG_FADE * twang) * cos(TAU * TWANG_HZ * twang)
	for i in n + 1:
		var u := float(i) / n
		var p := hand + span * u
		var mid := sin(PI * u)   # nothing moves at the wrist or at the hook
		if sag > 0.0:
			p -= up * (sag * 4.0 * u * (1.0 - u))
		if amp > 0.0:
			var turn := TAU * (waves * u - WAVE_HZ * age)
			# (looser by the wrist, where it has just left the reel; the hook pulls its end straighter)
			p += (side * cos(turn) + up * sin(turn)) * (amp * mid * (1.0 - 0.45 * u))
		if buzz != 0.0:
			p += side * (buzz * sin(TAU * u)) + up * (buzz * 0.6 * mid)
		out[i] = p


## How long the drawn rope is (metres): the tests check it against the rope really out.
static func length_of(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


## Draws what HookLine.look says ([] hides it).
func show_look(hand: Vector3, look: Array) -> void:
	if look.is_empty():
		hide_line()
		return
	show_line(hand, look[1], float(look[2]), float(look[3]), float(look[4]))


func show_line(hand: Vector3, hook: Vector3, slack: float, age: float, twang: float) -> void:
	visible = true
	if not global_transform.is_equal_approx(Transform3D.IDENTITY):
		global_transform = Transform3D.IDENTITY   # the points below are places in the world
	curve(hand, hook, slack, age, twang, _points)
	var shown := 0
	for i in SEGMENTS:
		var a := _points[i]
		var along := _points[i + 1] - a
		var l := along.length()
		if l < 0.0005:
			continue
		var y := along / l
		var x := y.cross(Vector3.UP)
		if x.length_squared() < 0.001:
			x = y.cross(Vector3.RIGHT)
		x = x.normalized()
		# (a touch longer than the stretch it covers, so no light shows through at the bends)
		_multi.set_instance_transform(shown, Transform3D(Basis(x, along + y * RADIUS, x.cross(y)), a + along * 0.5))
		shown += 1
	_multi.visible_instance_count = shown
	# The hook points the way the rope's last stretch runs.
	var nose := hook - _points[SEGMENTS - 1]
	if nose.length_squared() < 0.000001:
		nose = hook - hand
	if nose.length_squared() > 0.000001:
		nose = nose.normalized()
		var top := Vector3.UP if absf(nose.y) < 0.99 else Vector3.RIGHT
		_head.global_transform = Transform3D(Basis.looking_at(nose, top), hook)
	else:
		_head.global_position = hook


func hide_line() -> void:
	visible = false


## Where the hook is drawn (the tests ask).
func hook_position() -> Vector3:
	return _head.global_position
