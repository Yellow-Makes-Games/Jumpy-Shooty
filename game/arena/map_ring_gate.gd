@tool
class_name MapRingGate
extends Node3D
## One of a map's ring gates: a permanent metal ring a portal opens in while a
## PortalSurgeEvent runs (Empyrean Tower). Put the node at the middle of the ring's
## opening, its z axis square to the ring (the opening lies in its x-y plane); build
## the ring itself, its plinth and its emitter housings from MapBlocks round it. Two
## gates with the same Pair number are joined: in through one, out of the other, both
## ways, your speed carried through and turned to match.
##
## Between surges the gate is dormant: nothing in the ring but a faint glow at its
## emitter nodes, and walking through it is walking through a ring. When a surge
## starts the nodes light one after another round the rim and the portal's surface
## forms from the middle outward: violet and gold, turning slowly, with glyphs
## drifting across it. It never flashes.
##
## By default the portal faces both ways (a ring standing free can be entered from
## either side: front to front, back to back). Untick Two Sided for a gate that
## stands against a wall.
##
## It only draws and says where the portals are. The event opens and closes it, the
## arena's Portals node moves players through (the portal gun's own maths); nothing
## here is solid. The outline is editor-only.

const GROUP := "map_ring_gates"
const NODES := 8

## Which pair it belongs to (two gates share a number).
@export var pair := 1
## Half the opening's width and height (metres).
@export var opening := Vector2(1.4, 1.4):
	set(v):
		opening = v.max(Vector2(0.3, 0.3))
		_refresh_ghost()
## How far out from the middle the emitter nodes sit (on the ring's rim).
@export var rim := 1.95
## It can be gone through from behind too (it stands free). Off: front only.
@export var two_sided := true

## 0..1: how far open it is (the event sets it).
var power := 0.0
## People can go through it right now.
var open := false

var _fronts: Array = []     # its Portal frames: the front one, and the back one if it has two sides
var _surface: MeshInstance3D
var _surface_mat: ShaderMaterial
var _node_mats: Array = []
var _hum: AudioStreamPlayer3D
var _shown := -1.0
var _ghost: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_ghost()
		return
	add_to_group(GROUP)
	if DisplayServer.get_name() != "headless":
		_build_look()


## Its portals as Portals takes them: [front] or [front, back]. Made once (the gate
## never moves).
func frames() -> Array:
	if _fronts.is_empty():
		var xf := global_transform.orthonormalized()
		var front := Portal.make_frame(xf.origin, xf.basis.z, xf.basis.y, opening.x, opening.y)
		add_child(front)
		front.global_transform = Transform3D(front.frame.basis, front.frame.origin)
		_fronts.append(front)
		if two_sided:
			var back := Portal.make_frame(xf.origin, -xf.basis.z, xf.basis.y, opening.x, opening.y)
			add_child(back)
			back.global_transform = Transform3D(back.frame.basis, back.frame.origin)
			_fronts.append(back)
	return _fronts


## The event says how far open it is (0 dormant, 1 open) and whether it can be used.
func set_power(level: float, usable: bool) -> void:
	power = clampf(level, 0.0, 1.0)
	open = usable
	_show()


# ---------------------------------------------------------------------------
# What you see and hear

const SURFACE_SHADER := "
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float power = 0.0;
uniform vec3 violet : source_color = vec3(0.56, 0.3, 0.95);
uniform vec3 gold : source_color = vec3(1.0, 0.76, 0.3);
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// It forms from the middle outward as the gate powers up.
	float edge = power * 1.04;
	float inside = smoothstep(edge, edge - 0.12, r);
	// Two slow arms of colour winding into the middle.
	float arms = 0.5 + 0.5 * sin(a * 2.0 + r * 7.0 - TIME * 0.9);
	float fine = 0.5 + 0.5 * sin(a * 5.0 - r * 13.0 + TIME * 0.6);
	vec3 colour = mix(violet, gold, smoothstep(0.25, 0.85, arms * 0.75 + fine * 0.25));
	// Rune glyphs drifting round on rings.
	vec2 cell = vec2((a / 6.2831853 + 0.5) * 18.0 + TIME * 0.35 * (mod(floor(r * 5.0), 2.0) * 2.0 - 1.0), r * 5.0);
	vec2 id = floor(cell);
	vec2 q = fract(cell) - 0.5;
	float pick = hash(id);
	float glyph = 0.0;
	if (pick > 0.6 && r > 0.25) {
		float bar = step(abs(q.x), 0.08) * step(abs(q.y), 0.3);
		float cross_bar = step(abs(q.y - (pick - 0.8) * 1.2), 0.07) * step(abs(q.x), 0.28);
		float tick = step(abs(abs(q.x) - 0.24), 0.05) * step(abs(q.y + 0.1), 0.18) * step(0.82, pick);
		glyph = clamp(bar + cross_bar + tick, 0.0, 1.0);
	}
	float glow_rim = smoothstep(edge - 0.2, edge - 0.02, r) * inside;
	ALBEDO = colour * (0.75 + 0.35 * fine) + vec3(1.0, 0.9, 0.7) * (glyph * 0.6 + glow_rim * 0.5);
	ALPHA = inside * (0.78 + 0.12 * arms) * smoothstep(0.0, 0.08, power);
}
"


func _build_look() -> void:
	var shader := Shader.new()
	shader.code = SURFACE_SHADER
	_surface_mat = ShaderMaterial.new()
	_surface_mat.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2(opening.x * 2.0 + 0.2, opening.y * 2.0 + 0.2)
	_surface = MeshInstance3D.new()
	_surface.name = "Surface"
	_surface.mesh = quad
	_surface.material_override = _surface_mat
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface.visible = false
	add_child(_surface)
	# The emitter nodes round the rim: they light one after another as it powers up.
	var ball := SphereMesh.new()
	ball.radius = 0.16
	ball.height = 0.32
	ball.radial_segments = 10
	ball.rings = 5
	for i in NODES:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = _node_colour(0.0, i)
		var node := MeshInstance3D.new()
		node.mesh = ball
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var turn := TAU * (float(i) + 0.5) / NODES
		for side in [-1.0, 1.0]:
			var copy := node.duplicate() as MeshInstance3D
			copy.material_override = mat
			copy.position = Vector3(sin(turn) * rim, cos(turn) * rim, 0.22 * side)
			add_child(copy)
		node.free()
		_node_mats.append(mat)
	_show()


## An emitter node's colour: a faint violet ember when dormant, gold-white when lit.
func _node_colour(lit: float, i: int) -> Color:
	var idle := Color(0.2, 0.12, 0.34)
	var on := Color(1.0, 0.82, 0.45) if i % 2 == 0 else Color(0.78, 0.55, 1.0)
	return idle.lerp(on * 1.6, lit)


func _show() -> void:
	if _surface == null or is_equal_approx(power, _shown):
		return
	_shown = power
	_surface.visible = power > 0.01
	_surface_mat.set_shader_parameter("power", smoothstep(0.35, 1.0, power))
	for i in _node_mats.size():
		# The first two thirds of powering up light the nodes in turn; then the surface forms.
		var lit := clampf(power * 1.5 * NODES - float(i), 0.0, 1.0)
		(_node_mats[i] as StandardMaterial3D).albedo_color = _node_colour(lit, i)
	_hum_level()


func _hum_level() -> void:
	var sound := get_node_or_null("/root/Sound") if is_inside_tree() else null
	if sound == null or sound.silent:
		return
	if power > 0.02 and _hum == null:
		var stream: AudioStream = sound.stream("gate_hum")
		if stream == null:
			return
		stream = stream.duplicate()
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = stream
		_hum.bus = sound.BUS_SFX
		_hum.unit_size = 7.0
		_hum.max_distance = 45.0
		add_child(_hum)
	if _hum == null:
		return
	if power > 0.02:
		_hum.volume_db = lerpf(-40.0, SfxList.VOLUME.get("gate_hum", -14.0), sqrt(power))
		if not _hum.playing:
			_hum.play(randf() * maxf(_hum.stream.get_length() - 0.1, 0.0))
	elif _hum.playing:
		_hum.stop()


func _refresh_ghost() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _ghost == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.45, 1.0, 0.25)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ghost = MeshInstance3D.new()
		_ghost.material_override = mat
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ghost, false, Node.INTERNAL_MODE_FRONT)
	var quad := QuadMesh.new()
	quad.size = opening * 2.0
	_ghost.mesh = quad
