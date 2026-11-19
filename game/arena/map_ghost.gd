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
## What it looks like. Sheet: a hooded sheet with hollow eyes. Wraith: a tall, thin
## figure in a tattered shroud with a void for a face and long hands. Apparition: a
## woman in a long dress and veil, pale and flickering, fading away below the knee.
## Shade: a shadow in the shape of a man, its edges smoking away. Mist: a column of
## cold vapour with only the hint of a head and shoulders.
@export_enum("Sheet", "Wraith", "Apparition", "Shade", "Mist") var look := 0

## The clock it flies by (a HauntEvent sets it each frame; otherwise its own).
var clock := 0.0
## 0..1: how stirred up it is (the house is about to shift).
var stir := 0.0

var _body: Node3D
var _mat: ShaderMaterial
var _dark: ShaderMaterial
var _mats: Array = []   # the other looks' materials (their stir and origin are set each frame)
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
	match look:
		1:
			_build_wraith()
			return
		2:
			_build_apparition()
			return
		3:
			_build_shade()
			return
		4:
			_build_mist()
			return
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
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("stir", stir)
		(m as ShaderMaterial).set_shader_parameter("origin", _body.global_position)
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


# ---------------------------------------------------------------------------
# The other looks: no outlines and no cartoon eyes. Each is drawn with one shader
# that leaves the body almost clear face on and keeps its edges, eats it away with
# drifting noise (so it is never quite solid or still), and fades it out toward its
# lower end.

const VAPOUR := "
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 tint : source_color = vec4(0.8, 0.85, 0.9, 1.0);
uniform vec3 origin;             // where the ghost is (the script sets it each frame)
uniform float body = 0.08;       // how much shows face on
uniform float rim = 0.55;        // how much shows at the edges
uniform float rim_power = 2.2;
uniform float wisp = 0.6;        // how much the drifting noise eats it (0..1)
uniform float scale = 2.6;       // the noise's size (bigger: finer)
uniform float rise = 0.35;       // metres a second the noise drifts up
uniform float top = 0.6;         // heights from its middle: whole above `top`...
uniform float bottom = -1.0;     // ...gone below `bottom`
uniform float sway = 0.0;        // metres its lower part trails and waves
uniform float flicker = 0.0;     // 0..1: now and then it all but goes out
uniform float glow = 1.0;        // brightness of its edges
uniform float stir = 0.0;
varying vec3 lp;
varying float low;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	return 0.55 * noise(p) + 0.3 * noise(p * 2.03 + 7.1) + 0.15 * noise(p * 4.1 + 2.3);
}
void vertex() {
	lp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - origin;
	low = clamp((top - lp.y) / max(top - bottom, 0.01), 0.0, 1.0);
	float s = sway * (1.0 + stir * 1.5) * low * low;
	VERTEX.x += sin(TIME * 1.3 + lp.y * 3.1) * s;
	VERTEX.z += cos(TIME * 1.05 + lp.y * 2.7) * s * 0.8;
}
void fragment() {
	float r = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), rim_power);
	float n = fbm(lp * scale + vec3(0.0, -TIME * rise * scale, TIME * 0.07));
	float a = mix(body, rim, r);
	a *= mix(1.0, smoothstep(0.25, 0.75, n), wisp);
	a *= 1.0 - smoothstep(0.0, 1.0, low);
	float blink = step(0.965, fract(sin(floor(TIME * 9.0) * 78.233) * 43758.5453));
	a *= 1.0 - flicker * (0.85 * blink + 0.25 * (0.5 + 0.5 * sin(TIME * 23.0)));
	a *= 1.0 + stir * 0.6;
	ALBEDO = tint.rgb * (0.55 + r * glow + stir * 0.4);
	ALPHA = clamp(a, 0.0, 1.0);
}
"


func _vapour(params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = VAPOUR
	mat.shader = shader
	for k in params:
		mat.set_shader_parameter(k, params[k])
	_mats.append(mat)
	return mat


func _shape(mesh: Mesh, mat: Material, at: Vector3, scale_by := Vector3.ONE, turn := Vector3.ZERO) -> MeshInstance3D:
	var m := _part(mesh, mat, at)
	m.scale = scale_by
	m.rotation = turn
	return m


func _ball(r: float, rings := 10) -> SphereMesh:
	var b := SphereMesh.new()
	b.radius = r
	b.height = r * 2.0
	b.radial_segments = 16
	b.rings = rings
	return b


func _tube(top_r: float, bottom_r: float, h: float, segments := 16, rings := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = segments
	c.rings = rings
	c.cap_top = false
	c.cap_bottom = false
	return c


func _limb(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	return c


## A tall, thin figure in a tattered shroud: a deep hood with nothing in it, long
## arms reaching, rags trailing far below where its feet would be.
func _build_wraith() -> void:
	var s := size
	var cloth := _vapour({"tint": Color(0.78, 0.82, 0.86), "body": 0.2, "rim": 0.7, "wisp": 0.55, "scale": 3.4, "rise": 0.25,
		"top": 0.4 * s, "bottom": -1.5 * s, "sway": 0.16 * s, "glow": 0.9})
	var hollow := _vapour({"tint": Color(0, 0, 0), "body": 0.95, "rim": 0.95, "wisp": 0.1, "scale": 6.0, "rise": 0.0,
		"top": 9.0, "bottom": -9.0, "glow": 0.0})
	_shape(_tube(0.17 * s, 0.34 * s, 1.9 * s, 14, 10), cloth, Vector3(0, -0.45 * s, 0))
	for k in 7:
		var a := TAU * float(k) / 7.0 + 0.4
		_shape(_tube(0.07 * s, 0.015 * s, 0.9 * s, 5, 4), cloth, Vector3(sin(a) * 0.26 * s, -1.25 * s - 0.08 * s * float(k % 3), cos(a) * 0.26 * s),
			Vector3.ONE, Vector3(cos(a) * 0.12, 0, -sin(a) * 0.12))
	_shape(_ball(0.25 * s), cloth, Vector3(0, 0.42 * s, 0), Vector3(1.25, 0.5, 0.8))
	_shape(_ball(0.21 * s), cloth, Vector3(0, 0.72 * s, 0.02 * s), Vector3(0.95, 1.35, 1.1))
	_shape(_ball(0.13 * s, 8), hollow, Vector3(0, 0.68 * s, -0.1 * s), Vector3(0.9, 1.25, 0.6))
	for side in [-1.0, 1.0]:
		_shape(_limb(0.05 * s, 0.85 * s), cloth, Vector3(0.3 * s * side, 0.12 * s, -0.28 * s), Vector3.ONE, Vector3(deg_to_rad(-62.0), 0.0, deg_to_rad(-10.0 * side)))
		for f in 4:
			var spread := (float(f) - 1.5) * 0.035 * s
			_shape(_limb(0.012 * s, 0.24 * s), cloth, Vector3(0.36 * s * side + spread, -0.12 * s, -0.66 * s), Vector3.ONE,
				Vector3(deg_to_rad(-40.0), 0.0, deg_to_rad(float(f) * 6.0 - 9.0)))


## A woman of the house: a long dress with a full skirt, a narrow waist, a veil over
## her head and down her back, arms at her sides. Pale and grey, she flickers, and
## fades away below the knee.
func _build_apparition() -> void:
	var s := size
	var dress := _vapour({"tint": Color(0.86, 0.84, 0.78), "body": 0.22, "rim": 0.7, "wisp": 0.45, "scale": 3.0, "rise": 0.18,
		"top": -0.1 * s, "bottom": -0.95 * s, "sway": 0.05 * s, "flicker": 0.6, "glow": 1.1})
	var veil := _vapour({"tint": Color(0.92, 0.92, 0.9), "body": 0.14, "rim": 0.45, "wisp": 0.65, "scale": 4.0, "rise": 0.12,
		"top": 0.8 * s, "bottom": -0.4 * s, "sway": 0.06 * s, "flicker": 0.6, "glow": 1.0})
	_shape(_tube(0.16 * s, 0.5 * s, 1.05 * s, 18, 8), dress, Vector3(0, -0.5 * s, 0))
	_shape(_tube(0.19 * s, 0.13 * s, 0.42 * s, 14, 3), dress, Vector3(0, 0.22 * s, 0))
	_shape(_ball(0.17 * s), dress, Vector3(0, 0.45 * s, 0), Vector3(1.35, 0.45, 0.8))
	_shape(_tube(0.045 * s, 0.05 * s, 0.12 * s, 8, 1), dress, Vector3(0, 0.56 * s, 0))
	_shape(_ball(0.1 * s), dress, Vector3(0, 0.7 * s, 0), Vector3(0.85, 1.12, 0.95))
	_shape(_ball(0.07 * s), dress, Vector3(0, 0.76 * s, 0.07 * s))
	for side in [-1.0, 1.0]:
		_shape(_limb(0.04 * s, 0.62 * s), dress, Vector3(0.2 * s * side, 0.2 * s, -0.04 * s), Vector3.ONE, Vector3(deg_to_rad(-14.0), 0.0, deg_to_rad(12.0 * side)))
	_shape(_tube(0.09 * s, 0.32 * s, 1.1 * s, 14, 8), veil, Vector3(0, 0.25 * s, 0.1 * s), Vector3.ONE, Vector3(deg_to_rad(10.0), 0, 0))


## A shadow in the shape of a man: dark, nearly solid at its middle, smoking away at
## its edges and from the waist down. No face.
func _build_shade() -> void:
	var s := size
	var dark := _vapour({"tint": Color(0.02, 0.02, 0.03), "body": 0.8, "rim": 0.35, "rim_power": 1.4, "wisp": 0.7, "scale": 3.6,
		"rise": 0.5, "top": 0.0, "bottom": -1.0 * s, "sway": 0.05 * s, "glow": 0.0})
	_shape(_ball(0.115 * s), dark, Vector3(0, 0.72 * s, 0), Vector3(0.9, 1.1, 1.0))
	_shape(_tube(0.05 * s, 0.06 * s, 0.12 * s, 8, 1), dark, Vector3(0, 0.58 * s, 0))
	_shape(_ball(0.22 * s), dark, Vector3(0, 0.44 * s, 0), Vector3(1.2, 0.42, 0.62))
	_shape(_tube(0.24 * s, 0.17 * s, 0.6 * s, 12, 4), dark, Vector3(0, 0.15 * s, 0), Vector3(1.0, 1.0, 0.6))
	_shape(_tube(0.17 * s, 0.1 * s, 0.95 * s, 12, 6), dark, Vector3(0, -0.6 * s, 0), Vector3(1.0, 1.0, 0.6))
	for side in [-1.0, 1.0]:
		_shape(_limb(0.055 * s, 0.72 * s), dark, Vector3(0.29 * s * side, 0.12 * s, 0), Vector3.ONE, Vector3(0.0, 0.0, deg_to_rad(6.0 * side)))


## A column of cold vapour, thicker at the top where a head and shoulders almost show.
func _build_mist() -> void:
	var s := size
	var mist := _vapour({"tint": Color(0.7, 0.82, 0.8), "body": 0.42, "rim": 0.0, "rim_power": 0.7, "wisp": 0.9, "scale": 2.2,
		"rise": 0.6, "top": 0.4 * s, "bottom": -1.1 * s, "sway": 0.14 * s, "glow": 0.8})
	_shape(_ball(0.16 * s), mist, Vector3(0, 0.66 * s, 0), Vector3(0.9, 1.15, 0.9))
	_shape(_ball(0.3 * s), mist, Vector3(0, 0.36 * s, 0), Vector3(1.15, 0.6, 0.75))
	for k in 5:
		var h := float(k)
		_shape(_ball((0.32 - h * 0.035) * s), mist, Vector3(sin(h * 1.7) * 0.06 * s, (0.1 - h * 0.28) * s, cos(h * 1.3) * 0.05 * s), Vector3(1.0, 1.3, 0.9))
