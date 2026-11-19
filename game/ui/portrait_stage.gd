class_name PortraitStage
extends Node3D
## The stage a character stands on in the lobby's and the Character Creator's portrait
## (RobotPreview, staged): a pedestal of light in its player's colour (a ring round its
## feet, a faint honeycomb floor fading into the dark, a scan line crossing it every few
## seconds, the menu's own cyan dashes turning round the outside), a shaft of light
## falling on it from above, a soft glow on the dark behind it and dust drifting up
## through that. All real 3D in the portrait's own world, so it is anti-aliased and lit
## with the character, and none of it ever comes between the character and you: the
## floor is under its feet and the rest is behind it.

const RADIUS := 0.74          ## the ring round the character's feet (metres), at its biggest
const OUTSIDE := 1.2          ## the dashes turning round it reach this many times as far
const FLOOR := 3.0            ## the floor's whole width: the honeycomb fades out before its edge
const SCAN_EVERY := 4.5       ## seconds between scan lines
const PULSE := 0.7            ## seconds the ring's pulse takes (a new character building in)
const LEVEL := 1              ## physics layer 1: what a spent cell bounces on (see SpentCell)

const FLOOR_SHADER := "shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
// The pedestal: all of it one flat sheet of light under the character's feet.
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 cyan : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float radius = 0.74;      // the main ring (metres)
uniform float width = 3.0;        // the sheet's width
uniform float turn = 0.0;         // the dashes' turn (radians)
uniform float scan = -1.0;        // the scan line: -1..1 across the ring, front to back (outside that: none)
uniform float pulse = -1.0;       // the pulse: 0..1 from the middle outward (below 0: none)

float ring(float r, float at, float thick) {
	float w = fwidth(r) * 1.25;
	return smoothstep(thick + w, thick - w * 0.25, abs(r - at));
}

// How near the nearest honeycomb wall is, 0 at a wall.
float hex(vec2 p) {
	p /= 0.27;
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	g = abs(g);
	return 0.5 - max(g.x, g.x * 0.5 + g.y * 0.8660254);
}

void fragment() {
	vec2 p = (UV - 0.5) * width;      // metres from the middle: x right, y toward you
	float r = length(p);
	float inside = 1.0 - smoothstep(radius - 0.02, radius + 0.02, r);
	// A pool of light inside the ring, strongest at the rim, and a shadow under the feet.
	float pool = inside * (0.02 + 0.06 * smoothstep(0.0, radius, r));
	float shade = (1.0 - smoothstep(0.05, 0.42, r)) * 0.55;
	// The honeycomb: clear inside the ring, fading into the dark outside it.
	float cell = hex(p);
	float wall = 1.0 - smoothstep(0.0, fwidth(cell) * 1.5 + 0.006, cell);
	float grid = wall * (0.16 * inside + 0.10 * (1.0 - inside) * (1.0 - smoothstep(radius, width * 0.47, r)));
	// The rings.
	float rings = ring(r, radius, 0.011) * 0.95 + ring(r, radius * 0.74, 0.005) * 0.32;
	// The scan line, front to back, and the glow it leaves just behind it.
	float line = 0.0;
	if (abs(scan) < 1.0) {
		float d = p.y - (-scan * radius);
		float lw = fwidth(p.y) * 1.5 + 0.006;
		line = inside * (smoothstep(lw, 0.0, abs(d)) * 0.85 + smoothstep(0.32, 0.0, d) * step(0.0, d) * 0.16);
	}
	// The pulse: a ring spreading from the feet, lighting the floor as it passes.
	float burst = 0.0;
	if (pulse >= 0.0 && pulse < 1.0) {
		float at = mix(0.15, radius * 1.45, pulse);
		burst = (ring(r, at, 0.03) * 0.9 + smoothstep(0.35, 0.0, at - r) * step(r, at) * 0.25) * (1.0 - pulse);
	}
	float lit = pool + grid + rings + line + burst;
	// The menu's cyan dashes, turning round the outside.
	float a = atan(p.y, p.x) + turn;
	float seg = abs(mod(a, 6.2831853 / 6.0) - 0.25);
	float aw = min(fwidth(a), 0.1) * 1.5;
	float dash = ring(r, radius * 1.16, 0.014) * smoothstep(0.25 + aw, 0.25 - aw, seg) * 0.6;
	vec3 colour = tint.rgb * lit + cyan.rgb * dash;
	float alpha = clamp(lit + dash, 0.0, 1.0);
	// The shadow darkens what is under it; everything else is light.
	ALBEDO = colour / max(alpha + shade * (1.0 - alpha), 0.001);
	ALPHA = clamp(alpha + shade * (1.0 - alpha), 0.0, 1.0);
}"

const SHAFT_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
// A shaft of light falling on the pedestal: faint at the top, soft at its edges.
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float strength = 0.011;
void fragment() {
	float edge = abs(dot(normalize(NORMAL), normalize(VIEW)));   // 0 at the shaft's silhouette
	float down = clamp(UV.y * 2.0, 0.0, 1.0);                    // 0 at the top, 1 at the floor (a cylinder's side has the top half of its UVs)
	ALBEDO = tint.rgb;
	ALPHA = strength * pow(edge, 3.0) * (0.10 + 0.90 * down * down) * smoothstep(1.0, 0.93, down);
}"

const GLOW_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
// A soft glow on the dark behind the character.
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float strength = 0.019;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p * vec2(1.0, 0.82));
	ALBEDO = tint.rgb;
	ALPHA = strength * pow(1.0 - smoothstep(0.0, 1.0, r), 1.6);
}"

const HOLOGRAM_SHADER := "shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, depth_draw_never;
// Drawn over a character as it builds in: above the line it is still a hologram
// (its player's colour, in scan lines), and the line climbing it leaves it solid.
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float line = 0.0;   // how high the solid part reaches (metres)
varying float height;
void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	float above = smoothstep(line - 0.01, line + 0.01, height);
	float bars = 0.5 + 0.5 * sin(height * 150.0 - TIME * 9.0);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float edge = smoothstep(0.09, 0.0, abs(height - line));      // the bright line itself
	vec3 ghost = tint.rgb * (0.30 + 0.45 * bars + 0.9 * rim);
	ALBEDO = mix(ghost, mix(tint.rgb, vec3(1.0), 0.6), edge);
	ALPHA = clamp(above * 0.93 + edge, 0.0, 1.0);
}"

static var _shaders := {}

var _floor: ShaderMaterial
var _shaft: ShaderMaterial
var _glow: ShaderMaterial
var _shaft_piece: MeshInstance3D
var _dust: GPUParticles3D
var _dust_material: StandardMaterial3D
var _time := 0.0
var _pulse := -1.0
var _radius := RADIUS


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## The shader a character building in is drawn over with (see RobotPreview).
static func hologram_shader() -> Shader:
	return _shader(HOLOGRAM_SHADER)


func _init() -> void:
	# The floor.
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(FLOOR, FLOOR)
	_floor = _material(FLOOR_SHADER)
	_floor.set_shader_parameter("radius", RADIUS)
	_floor.set_shader_parameter("width", FLOOR)
	_floor.set_shader_parameter("cyan", UiKit.CYAN)
	_piece(sheet, _floor, Vector3(0, 0.004, 0))
	# The shaft of light: a cone open at both ends, narrow at the top.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.22
	cone.bottom_radius = RADIUS * 0.98
	cone.height = 3.4
	cone.radial_segments = 48
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	_shaft = _material(SHAFT_SHADER)
	_shaft_piece = _piece(cone, _shaft, Vector3(0, 1.7, 0))
	# The glow behind.
	var wall := QuadMesh.new()
	wall.size = Vector2(4.2, 4.2)
	_glow = _material(GLOW_SHADER)
	_piece(wall, _glow, Vector3(0, 1.25, -1.9))
	# Dust drifting up, behind the character only.
	_dust = GPUParticles3D.new()
	_dust.amount = 18
	_dust.lifetime = 7.0
	_dust.preprocess = 7.0
	_dust.randomness = 1.0
	_dust.fixed_fps = 0
	_dust.visibility_aabb = AABB(Vector3(-2.5, -0.5, -2.5), Vector3(5.0, 4.5, 3.0))
	var flow := ParticleProcessMaterial.new()
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flow.emission_box_extents = Vector3(1.25, 1.1, 0.35)
	flow.direction = Vector3.UP
	flow.spread = 25.0
	flow.initial_velocity_min = 0.04
	flow.initial_velocity_max = 0.12
	flow.gravity = Vector3.ZERO
	flow.scale_min = 0.5
	flow.scale_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	flow.color_ramp = ramp
	_dust.process_material = flow
	var speck := QuadMesh.new()
	speck.size = Vector2(0.016, 0.016)
	_dust_material = StandardMaterial3D.new()
	_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_dust_material.vertex_color_use_as_albedo = true
	speck.material = _dust_material
	_dust.draw_pass_1 = speck
	_dust.position = Vector3(0, 1.2, -1.05)
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)
	# Something for a reload's spent cell to bounce on.
	var ground := StaticBody3D.new()
	ground.collision_layer = LEVEL
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(8.0, 0.2, 8.0)
	shape.shape = slab
	shape.position = Vector3(0, -0.1, 0)
	ground.add_child(shape)
	add_child(ground)
	set_color(Color(1.0, 0.8, 0.3))


func _material(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(code)
	return m


func _piece(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Make the ring this big (a narrow portrait has less room for it).
func set_radius(r: float) -> void:
	_radius = r
	_floor.set_shader_parameter("radius", r)
	_shaft_piece.scale = Vector3(r / RADIUS, 1.0, r / RADIUS)


func radius() -> float:
	return _radius


## Light the stage in this colour (the player's trim colour).
func set_color(trim: Color) -> void:
	var glow := trim.lerp(Color.WHITE, 0.15)
	_floor.set_shader_parameter("tint", glow)
	_shaft.set_shader_parameter("tint", glow)
	_glow.set_shader_parameter("tint", trim)
	_dust_material.albedo_color = Color(trim.lerp(Color.WHITE, 0.35), 0.55)


## A pulse spreading out from the character's feet (as it builds in).
func pulse() -> void:
	_pulse = 0.0


func update(delta: float) -> void:
	_time += delta
	_floor.set_shader_parameter("turn", _time * 0.5)
	# The scan line crosses in the first second of every SCAN_EVERY.
	var phase := fmod(_time, SCAN_EVERY)
	_floor.set_shader_parameter("scan", lerpf(-1.0, 1.0, phase / 1.1) if phase < 1.1 else 2.0)
	if _pulse >= 0.0:
		_pulse += delta / PULSE
		if _pulse >= 1.0:
			_pulse = -1.0
	_floor.set_shader_parameter("pulse", _pulse)
