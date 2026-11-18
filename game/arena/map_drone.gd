@tool
class_name MapDrone
extends Node3D
## A small maintenance drone that drifts round a spot: scenery only (Empyrean Tower).
## Put the node at the middle of its round; it flies a slow circle of Radius metres
## round the node's own y axis, bobbing gently, with a soft light. It is drawn by this
## script (a little hull, a ring and a lamp), has no collision, cannot be shot and
## cannot be hooked: pure ambience, and cheap (three small meshes, one material each).
## Every copy of the game flies it by its own clock.

## How far from the node it circles (metres).
@export var radius := 6.0:
	set(v):
		radius = v
		_place()
## Degrees a second (negative: the other way).
@export var speed := 8.0
## How far it bobs up and down (metres).
@export var bob := 0.6
## 0..1: where on its round it starts.
@export_range(0.0, 1.0) var phase := 0.0:
	set(v):
		phase = v
		_place()
## The colour of its lamp.
@export var lamp := Color(0.5, 0.95, 1.0)

var _body: Node3D
var _time := 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless" and not Engine.is_editor_hint():
		set_process(false)
		return
	_build()
	_place()


func _build() -> void:
	_body = Node3D.new()
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.8, 0.82, 0.88)
	hull_mat.roughness = 0.6
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.8, 0.6, 0.26)
	brass.roughness = 0.5
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = lamp * 1.6
	var hull := SphereMesh.new()
	hull.radius = 0.42
	hull.height = 0.6
	hull.radial_segments = 10
	hull.rings = 5
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.5
	hoop.outer_radius = 0.62
	hoop.rings = 14
	hoop.ring_segments = 5
	var eye := SphereMesh.new()
	eye.radius = 0.16
	eye.height = 0.32
	eye.radial_segments = 8
	eye.rings = 4
	for part in [[hull, hull_mat, Vector3.ZERO], [hoop, brass, Vector3.ZERO], [eye, glow, Vector3(0, -0.22, 0.3)]]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = part[0]
		mesh.material_override = part[1]
		mesh.position = part[2]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(mesh)


func _place() -> void:
	if _body == null:
		return
	var turn := TAU * phase + deg_to_rad(speed) * _time
	_body.position = Vector3(sin(turn) * radius, sin(_time * 0.9 + phase * 9.0) * bob, cos(turn) * radius)
	_body.rotation.y = turn + (PI * 0.5 if speed >= 0.0 else -PI * 0.5)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_place()
