shader_type spatial;
// Karate's aura (KarateGear): the body's own mesh, pushed out along smoothed normals
// into a thin shell of flame-like energy in the player's trim colour. Added light only:
// brightest at the body's outline and clear across the middle, so it never hides
// anyone, and depth-tested like anything else, so it never shows through a wall.
// Tongues of it lick upward, more the harder the swing is wound up.
//
// first_person: drawn like the first-person arms (viewmodel.gdshader: its own field of
// view, its depth squeezed toward the camera).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.5, 0.2);
uniform float strength = 0.2;   // how bright overall (pulses)
uniform float level = 0.0;      // 0 at rest, 1 wound right up (more on a flare)
uniform float thick = 0.025;    // how far the shell stands off the body (m)
uniform bool first_person = false;
uniform bool outer = false;     // the outer layer: big licks of flame, only as the charge builds
uniform float view_fov = 70.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying float dim;   // the hands' many small parts would pile up: they are dimmed (COLOR.r)

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return 0.55 * noise(p) + 0.3 * noise(p * 2.03 + 3.1) + 0.15 * noise(p * 4.1 + 7.7);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float t = TIME;
	float l = clamp(level, 0.0, 1.4);
	vec3 moved;
	if (!outer) {
		// The inner shell: close to the body, flickering.
		float flick = noise(wp * 7.0 + vec3(0.0, -t * 3.2, 0.0));
		float upness = clamp(wn.y * 0.6 + 0.45, 0.0, 1.0);
		float lick = upness * smoothstep(0.45, 0.95, noise(wp * vec3(5.0, 1.5, 5.0) + vec3(0.0, -t * 2.4, 0.0)));
		moved = wp + wn * thick * (0.65 + 0.7 * flick) + vec3(0.0, lick * (0.02 + 0.06 * l), 0.0);
	} else {
		// The outer flames: pushed well out, and drawn up into tall tongues that stream
		// upward, more and taller the harder the swing is wound up (a fighter powering up).
		vec3 flat_n = normalize(vec3(wn.x, wn.y * 0.35, wn.z) + vec3(0.0001));
		float swell = noise(wp * 3.0 + vec3(0.0, -t * 2.0, 0.0));
		float out_by = (0.03 + 0.09 * l) * (0.6 + 0.8 * swell);
		float upness = clamp(wn.y * 0.5 + 0.6, 0.0, 1.0);
		float tongue = smoothstep(0.35, 0.9, noise(wp * vec3(4.0, 0.9, 4.0) + vec3(0.0, -t * 3.4, 0.0)));
		float tall = (0.05 + 0.42 * l) * tongue * upness;
		// Tongues lean in toward the middle as they rise, like a flame's tip.
		vec3 centre = (MODEL_MATRIX * vec4(0.0, wp.y - MODEL_MATRIX[3].y, 0.0, 1.0)).xyz;
		vec3 inward = normalize(vec3(centre.x - wp.x, 0.0, centre.z - wp.z) + vec3(0.0001));
		moved = wp + flat_n * out_by + vec3(0.0, tall, 0.0) + inward * tall * 0.18;
	}
	VERTEX = (inverse(MODEL_MATRIX) * vec4(moved, 1.0)).xyz;
	world_pos = moved;
	dim = COLOR.r;
	world_normal = wn;
	if (first_person) {
		float want = 1.0 / tan(radians(view_fov) * 0.5);
		float ratio = want / abs(PROJECTION_MATRIX[1][1]);
		mat4 proj = PROJECTION_MATRIX;
		proj[0][0] *= ratio;
		proj[1][1] *= ratio;
		POSITION = proj * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		POSITION.z = mix(POSITION.z, POSITION.w, 0.9);
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);   // (writing POSITION at all skips the usual projection)
	}
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float facing = abs(dot(n, VIEW));
	float t = TIME;
	float l = clamp(level, 0.0, 1.4);
	if (!outer) {
		float rim = pow(1.0 - facing, 2.2) * smoothstep(0.0, 0.18, facing);   // bright near the outline (soft at the very edge), clear across the middle
		float f = fbm(world_pos * vec3(6.0, 2.2, 6.0) + vec3(0.0, -t * 2.6, 0.0));
		float licks = smoothstep(0.38 - 0.1 * l, 0.78, f);
		float a = rim * (0.35 + 0.95 * licks);
		vec3 hot = mix(color, vec3(1.0), 0.45 * rim * licks);   // a hot core at the very edge, paler toward white
		ALBEDO = hot * a * strength * 1.25 * dim;
	} else {
		// Soft licks of flame: streaming noise, faded toward the middle of the body and
		// toward the tips, so the shell's own shape never shows as a hard edge.
		float rim = pow(1.0 - facing, 1.2) * smoothstep(0.0, 0.3, facing);   // faded right at the edge: no hard outline
		// Tall streaks (noise stretched up and streaming), broken up by a finer flicker.
		float f = fbm(world_pos * vec3(8.0, 1.1, 8.0) + vec3(0.0, -t * 3.4, 0.0));
		float g = fbm(world_pos * vec3(14.0, 3.5, 14.0) + vec3(1.3, -t * 5.0, 0.7));
		float flame = smoothstep(0.5, 0.88, f * 0.75 + g * 0.4);
		float a = rim * flame * smoothstep(0.08, 0.5, l);
		ALBEDO = mix(color, vec3(1.0), 0.25 * flame) * a * strength * 0.9 * dim;
	}
}
