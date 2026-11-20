class_name SpawnIn
extends RefCounted
## A body arriving (a spawn, a respawn): it is put together out of light in its own trim
## colour, from the feet up, in TIME seconds. Looks only: the player is there, can move and
## shoot and can be shot from the first frame, exactly as before.
##
## The body is never hidden and never see-through. Every mesh of it (the robot, the gun in
## its hands, what it carries on its back, a cape) gets a layer over its own materials
## (material_overlay, on spawn_in.gdshader) that is solid light at first: a bright
## silhouette where the robot will be. A line of brighter light climbs it from the feet
## and leaves the robot itself below. Meshes that turn up part of the way through (a
## weapon handed over as it arrives) are taken in as they do. Your own first-person arms
## get the same, the line running out from the eye.
##
## A Player keeps one while it goes (Player.spawn_in) and steps it every frame (update);
## ground() is the rest of it: a ring of light spreading out over the floor from the feet
## and a short column of light, in the same colour.

const SHADER := preload("res://game/player/robot/spawn_in.gdshader")
const LIGHT := preload("res://game/player/robot/spawn_light.gdshader")
const TIME := 0.4            ## seconds from all light to all body
const HEIGHT := 2.25         ## metres the line climbs (a body, and what stands up off its back)
const VIEW_FOV := 70.0       ## your own arms are drawn with this field of view (ViewModel.VIEW_FOV, viewmodel.gdshader): the layer over them too
const ARMS_FROM := 0.12      ## your own arms: the line starts this far from the eye (metres)...
const ARMS_LENGTH := 0.62    ## ...and runs out this far (past the muzzle of a long gun)
const RING := 1.5            ## the ring on the floor spreads to this radius (metres)...
const RING_TIME := 0.45      ## ...in this long
const COLUMN_HEIGHT := 2.6   ## the column of light: this tall...
const COLUMN_RADIUS := 0.5   ## ...this wide...
const COLUMN_TIME := 0.5     ## ...and gone in this long

var t := 0.0                 ## seconds in

var _body: ShaderMaterial    # the layer over the body's meshes
var _arms: ShaderMaterial    # ...and over your own first-person arms'
var _lit: Array = []         # the meshes that have a layer (weak references)


## A body starts to arrive, in `color` (its trim).
static func start(color: Color) -> SpawnIn:
	var s := SpawnIn.new()
	s._body = _layer(color, false)
	s._arms = _layer(color, true)
	return s


static func _layer(color: Color, view_model: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("color", Color(color.r, color.g, color.b))
	m.set_shader_parameter("view_model", view_model)
	m.set_shader_parameter("view_fov", VIEW_FOV)
	m.set_shader_parameter("height", ARMS_LENGTH if view_model else HEIGHT)
	m.set_shader_parameter("feet", ARMS_FROM if view_model else 0.0)
	m.set_shader_parameter("band", 0.07 if view_model else 0.14)
	m.set_shader_parameter("progress", 0.0)
	return m


## How far through it is: 0 all light, 1 all body.
func progress() -> float:
	return clampf(t / TIME, 0.0, 1.0)


## Every frame. body: everything of this player that is drawn in the world (its meshes
## are found each time: what it holds can change as it arrives); feet_y: how high its
## feet are, in the world; arms: your own first-person arms, if this is you. False once
## it is over (the layers are off again): let go of it then.
func update(delta: float, body: Node, feet_y: float, arms: Node = null) -> bool:
	t += delta
	if t >= TIME:
		stop()
		return false
	_body.set_shader_parameter("progress", progress())
	_body.set_shader_parameter("feet", feet_y)
	_arms.set_shader_parameter("progress", progress())
	_cover(body, _body)
	if arms != null:
		_cover(arms, _arms)
	return true


func _cover(n: Node, layer: ShaderMaterial) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is GeometryInstance3D and (n as GeometryInstance3D).material_overlay == null:
		(n as GeometryInstance3D).material_overlay = layer
		_lit.append(weakref(n))
	for c in n.get_children():
		_cover(c, layer)


## Over (or cut short: a death, the body made anew): the layers come off.
func stop() -> void:
	for ref in _lit:
		var n: Object = (ref as WeakRef).get_ref()
		if n != null and ((n as GeometryInstance3D).material_overlay == _body or (n as GeometryInstance3D).material_overlay == _arms):
			(n as GeometryInstance3D).material_overlay = null
	_lit.clear()
	t = TIME


## How many meshes have the layer on (tests).
func covered() -> int:
	var n := 0
	for ref in _lit:
		if (ref as WeakRef).get_ref() != null:
			n += 1
	return n


## On the ground where a body arrives (`at`: its feet, in the world): a ring of light
## spreading out over the floor and a short column of light, in `color`. Added to `parent`.
static func ground(parent: Node, at: Vector3, color: Color) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	var hot := Color(color.r, color.g, color.b).lerp(Color.WHITE, 0.3)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 28
	torus.ring_segments = 4
	ring.mesh = torus
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = hot
	glow.emission_enabled = true
	glow.emission = hot
	glow.emission_energy_multiplier = 2.5
	ring.material_override = glow
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = at + Vector3(0.0, 0.04, 0.0)
	ring.scale = Vector3(0.25, 0.03, 0.25)
	var spread := ring.create_tween().set_parallel()
	spread.tween_property(ring, "scale", Vector3(RING, 0.03, RING), RING_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	spread.tween_property(ring, "transparency", 1.0, RING_TIME).set_ease(Tween.EASE_IN)
	spread.chain().tween_callback(ring.queue_free)
	var column := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = COLUMN_RADIUS * 0.8
	tube.bottom_radius = COLUMN_RADIUS
	tube.height = COLUMN_HEIGHT
	tube.radial_segments = 16
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	column.mesh = tube
	var light := ShaderMaterial.new()
	light.shader = LIGHT
	light.set_shader_parameter("color", hot)
	light.set_shader_parameter("strength", 1.0)
	column.material_override = light
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(column)
	column.global_position = at + Vector3(0.0, COLUMN_HEIGHT * 0.5, 0.0)
	var fade := column.create_tween()
	fade.tween_method(func(s: float) -> void: light.set_shader_parameter("strength", s), 1.0, 0.0, COLUMN_TIME).set_ease(Tween.EASE_IN)
	fade.tween_callback(column.queue_free)
