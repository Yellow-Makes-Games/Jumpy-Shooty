shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// MapMagicStream's light: a rope of liquid magic. UV.x runs along it in metres, UV.y
// round it; COLOR is its colour there (it changes along the way) and COLOR.a fades its ends.

uniform float flow = 0.0;        // metres the liquid has run (the script counts it up)
uniform float power = 1.2;
uniform float surge = 0.0;
uniform float wave = 0.18;       // how far it sways (metres)

varying float along;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	along = UV.x;
	// It sways and swells like something poured, the swells running with the flow.
	float swell = 1.0 + 0.22 * sin((UV.x - flow) * 1.3) + 0.1 * sin((UV.x - flow * 1.6) * 3.1);
	vec3 sway = vec3(sin(UV.x * 0.7 + TIME * 0.6), sin(UV.x * 0.9 + TIME * 0.45), cos(UV.x * 0.6 + TIME * 0.5)) * wave;
	VERTEX += NORMAL * (swell - 1.0) * 0.35 + sway;
}

void fragment() {
	// Bright threads running the way it flows, a soft body, a brighter rim.
	vec2 q = vec2((along - flow) * 0.9, UV.y * 6.0);
	float threads = noise(q * vec2(1.0, 2.0)) * 0.6 + noise(q * vec2(2.7, 3.0) + 7.0) * 0.4;
	threads = smoothstep(0.35, 0.9, threads);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	float glints = step(0.985, noise(vec2((along - flow * 1.4) * 5.0, UV.y * 20.0)));
	float a = (0.16 + 0.5 * threads + 0.5 * rim + glints) * COLOR.a;
	ALBEDO = COLOR.rgb * a * power * (1.0 + 0.9 * surge);
	ALPHA = clamp(a, 0.0, 1.0);
}
