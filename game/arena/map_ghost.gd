@tool
class_name MapGhost
extends Node3D
## A ghost that flies a round through a haunted house (the Haunted House): scenery only.
## It has no collision, cannot be shot or hooked, and drifts straight through walls and
## floors, as ghosts do. It is drawn by this script (a hooded sheet with a ragged hem
## that ripples, two arms reaching out, hollow eyes and a mouth), see-through and
## glowing at the edges.
##
## Route is a loop of points in the node's own frame; the ghost glides round it at Speed
## metres a second, on a smooth curve through the points, bobbing and facing the way it
## goes. With a HauntEvent in the map it flies by the event's clock, so it is in the same
## place on every copy of the game; it moans now and then, and glows brighter and
## writhes while the house is about to shift.

const GROUP := "map_ghosts"

## The loop it flies, in the node's frame (at least two points).
@export var route: Array[Vector3] = [Vector3(-3, 0, 0), Vector3(3, 0, 0)]:
	set(v):
		route = v
		_measured = false
		_place(0.0)
## Metres a second.
@export var speed := 1.6
## 0..1: where on its round it starts.
@export_range(0.0, 1.0) var phase := 0.0:
	set(v):
		phase = v
		_place(0.0)
## How big it is (1: about 1.7 m from the top of its hood to its hem).
@export var size := 1.0
## Metres it bobs up and down.
@export var bob := 0.22
## Its glow.
@export var tint := Color(0.72, 0.92, 1.0)
## Seconds between its moans (0: it is silent).
@export var moan_every := 17.0

## The clock it flies by (a HauntEvent sets it each frame; otherwise its own).
var clock := 0.0
## 0..1: how stirred up it is (the house is about to shift).
var stir := 0.0

var _body: Node3D
var _mat: ShaderMaterial
var _dark: ShaderMaterial
var _driven := false
var _own_time := 0.0
var _measured := false
var _lengths: Array = []   # metres along the loop at the start of each segment
var _total := 0.0
var _last_moan := -1

const SHADER := "
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 tint : source_color = vec4(0.72, 0.92, 1.0, 1.0);
uniform float stir = 0.0;
uniform float hem = 1.0;   // 1: the sheet's ragged hem ripples
varying float low;
void vertex() {
	low = clamp(-VERTEX.y * 1.2, 0.0, 1.0) * hem;
	float a = atan(VERTEX.x, VERTEX.z);
	float wave = sin(TIME * (2.6 + stir * 3.0) + a * 3.0 + VERTEX.y * 4.0);
	VERTEX.xz *= 1.0 + low * (0.12 * wave + 0.06 * sin(a * 7.0 + TIME * 4.0));
	VERTEX.y += low * 0.08 * sin(a * 5.0 - TIME * 3.3);
	VERTEX.x += sin(TIME * 1.3 + VERTEX.y * 2.0) * 0.03 * (1.0 + stir * 2.0);
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.8);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.1);
	ALBEDO = tint.rgb * (0.9 + rim * 1.6 + stir * 0.9) * pulse;
	ALPHA = clamp((0.16 + rim * 0.62 + stir * 0.18) * (1.0 - low * 0.55), 0.0, 1.0);
}
"

const DARK := "
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform float stir = 0.0;
void fragment() {
	ALBEDO = vec3(0.02, 0.0, 0.05) + vec3(0.25, 0.0, 0.35) * stir;
	ALPHA = 0.86;
}
"


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
	if DisplayServer.get_name() == "headless" and not Engine.is_editor_hint():
		set_process(false)
		return
	_build()
	_place(0.0)


## The HauntEvent's clock this frame.
func drive(t: float) -> void:
	clock = t
	_driven = true


func _build() -> void:
	_body = Node3D.new()
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	_mat.shader = shader
	_mat.set_shader_parameter("tint", tint)
	var still := _mat.duplicate() as ShaderMaterial
	still.set_shader_parameter("hem", 0.0)
	_dark = ShaderMaterial.new()
	var dark_shader := Shader.new()
	dark_shader.code = DARK
	_dark.shader = dark_shader
	var s := size
	# The sheet: wide at the hem, drawn in to the shoulders.
	var sheet := CylinderMesh.new()
	sheet.top_radius = 0.24 * s
	sheet.bottom_radius = 0.56 * s
	sheet.height = 1.15 * s
	sheet.radial_segments = 18
	sheet.rings = 6
	sheet.cap_bottom = false
	_part(sheet, _mat, Vector3(0, -0.2 * s, 0))
	# The hood.
	var head := SphereMesh.new()
	head.radius = 0.31 * s
	head.height = 0.66 * s
	head.radial_segments = 16
	head.rings = 8
	_part(head, still, Vector3(0, 0.5 * s, 0))
	# Arms reaching forward (-z), drooping at the wrist.
	for side in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.075 * s
		arm.height = 0.62 * s
		arm.radial_segments = 8
		arm.rings = 2
		var m := _part(arm, still, Vector3(0.27 * s * side, 0.12 * s, -0.24 * s))
		m.rotation = Vector3(deg_to_rad(-72.0), 0.0, deg_to_rad(-14.0 * side))
		var hand := SphereMesh.new()
		hand.radius = 0.07 * s
		hand.height = 0.12 * s
		hand.radial_segments = 8
		hand.rings = 4
		_part(hand, still, Vector3(0.33 * s * side, 0.0, -0.5 * s))
	# Hollow eyes and a wailing mouth.
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.06 * s
		eye.height = 0.13 * s
		eye.radial_segments = 8
		eye.rings = 4
		_part(eye, _dark, Vector3(0.11 * s * side, 0.56 * s, -0.27 * s))
	var mouth := SphereMesh.new()
	mouth.radius = 0.055 * s
	mouth.height = 0.17 * s
	mouth.radial_segments = 8
	mouth.rings = 4
	_part(mouth, _dark, Vector3(0, 0.38 * s, -0.27 * s))


func _part(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(m)
	return m


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_own_time += delta
	var t := clock if _driven else _own_time
	_driven = false
	_place(t)
	if _mat:
		_mat.set_shader_parameter("stir", stir)
		_dark.set_shader_parameter("stir", stir)
	_moan(t)


# ---------------------------------------------------------------------------
# Its round

func _measure() -> void:
	_measured = true
	_lengths = []
	_total = 0.0
	var n := route.size()
	if n < 2:
		return
	for i in n:
		_lengths.append(_total)
		var seg := 0.0
		var last := _curve(i, 0.0)
		for k in range(1, 9):
			var pt := _curve(i, float(k) / 8.0)
			seg += last.distance_to(pt)
			last = pt
		_total += seg


## A smooth curve through the loop's points: segment i from point i to point i + 1.
func _curve(i: int, u: float) -> Vector3:
	var n := route.size()
	var p0: Vector3 = route[posmod(i - 1, n)]
	var p1: Vector3 = route[posmod(i, n)]
	var p2: Vector3 = route[posmod(i + 1, n)]
	var p3: Vector3 = route[posmod(i + 2, n)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


## Where on its round it is at `t` seconds (in the node's frame).
func at_time(t: float) -> Vector3:
	if not _measured:
		_measure()
	if _total <= 0.0:
		return route[0] if not route.is_empty() else Vector3.ZERO
	var s := fposmod(t * speed + phase * _total, _total)
	var i := _lengths.size() - 1
	while i > 0 and float(_lengths[i]) > s:
		i -= 1
	var seg_len := (_total if i == _lengths.size() - 1 else float(_lengths[i + 1])) - float(_lengths[i])
	var u := clampf((s - float(_lengths[i])) / maxf(seg_len, 0.001), 0.0, 1.0)
	return _curve(i, u)


func _place(t: float) -> void:
	if _body == null or route.is_empty():
		return
	var here := at_time(t)
	var ahead := at_time(t + 0.25)
	var flat := Vector3(ahead.x - here.x, 0.0, ahead.z - here.z)
	_body.position = here + Vector3(0, bob * sin(t * 1.7 + phase * 11.0), 0)
	if flat.length() > 0.001:
		_body.rotation.y = atan2(-flat.x, -flat.z)
	# Leaning into its flight, a little.
	_body.rotation.x = clampf((ahead.y - here.y) * -0.6, -0.35, 0.35) - 0.12


## A low moan now and then, from where it is (the same moments on every copy).
func _moan(t: float) -> void:
	if moan_every <= 0.0 or _body == null:
		return
	var beat := int(floorf((t + phase * moan_every) / moan_every))
	if beat == _last_moan:
		return
	var first := _last_moan < 0
	_last_moan = beat
	if first:
		return
	var sound := get_node_or_null("/root/Sound")
	if sound == null or sound.silent:
		return
	var player: AudioStreamPlayer3D = sound.play_at("ghost_moan", _body.global_position, "body", 0.0, 0.12)
	if player:
		player.unit_size = 6.0
		player.max_distance = 40.0
