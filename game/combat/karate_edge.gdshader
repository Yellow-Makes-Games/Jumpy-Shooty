shader_type canvas_item;
// Karate's aura in your own view (KarateGear.edge_pulse): a soft glow of the trim colour
// round the edges of the screen, licking inward a little like flame. Never across the
// middle, and added light only, so nothing is hidden.
render_mode blend_add, unshaded;

uniform vec3 color : source_color = vec3(1.0, 0.5, 0.2);
uniform float strength = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	// Distance to the nearest edge, in screen heights.
	vec2 d2 = min(uv, 1.0 - uv) * aspect;
	float d = min(d2.x, d2.y);
	float flame = noise(vec2(uv.x * 9.0 + uv.y * 3.0, uv.y * 4.0 + TIME * 1.8));
	float reach = 0.06 + 0.05 * flame;
	float a = 1.0 - smoothstep(0.0, reach, d);
	COLOR = vec4(color * a * strength * 0.32, 1.0);
}
