shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// MapMagic's light: every piece of an effect is one instance of a MultiMesh, and all of
// its movement is worked out here from the clock and the random numbers the instance
// carries, so an effect costs nothing on the CPU while nobody is near it.
//
// INSTANCE_CUSTOM: xyz where the piece lives in the effect's box (-0.5..0.5), w a random
// number. COLOR: four more random numbers. Everything is in the node's own frame.
//
// mode: 0 motes (drifting specks), 1 sparks (rising), 4 droplets (rising, faster as they
// go), 5 bubbles (rising rings), 6 fish, 7 jellyfish, 8 moths, 10 stars (still, they
// twinkle), 11 arcs (caged lightning).

uniform int mode = 0;
uniform vec3 extent = vec3(6.0, 4.0, 6.0);
uniform vec3 tint_a : source_color = vec3(0.5, 0.9, 1.0);
uniform vec3 tint_b : source_color = vec3(1.0, 0.8, 0.45);
uniform float power = 1.4;
uniform float piece = 0.12;          // a piece's size (metres)
uniform float surge = 0.0;           // 0..1: the map's event is running (livelier, brighter)
uniform float swirl = 0.0;           // radians the whole effect has been turned by the surge
uniform float reach = 4.0;           // how near a player stirs it (metres)
uniform vec4 actor[4];               // players stirring it: where (the node's frame) and how much (0..1)

varying vec3 glow;
varying float shape_fade;

float hash1(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

// How hard the players near `at` push it, and which way.
vec3 scatter(vec3 at, out float stirred) {
	vec3 push = vec3(0.0);
	stirred = 0.0;
	for (int i = 0; i < 4; i++) {
		vec3 away = at - actor[i].xyz;
		float far = length(away);
		float s = actor[i].w * smoothstep(reach, reach * 0.15, far);
		push += away / max(far, 0.05) * s;
		stirred = max(stirred, s);
	}
	return push;
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec4 r = COLOR;
	float t = TIME;
	vec3 base = c.xyz * extent;
	mat3 to_local = transpose(mat3(MODEL_MATRIX));
	vec3 cam_right = normalize(to_local * INV_VIEW_MATRIX[0].xyz);
	vec3 cam_up = normalize(to_local * INV_VIEW_MATRIX[1].xyz);
	float bright = 1.0;
	float size = piece * (0.6 + 0.8 * r.x);
	float stirred = 0.0;
	vec3 at = base;
	shape_fade = 1.0;
	bool card = true;        // a flat piece turned to the camera
	vec3 up_axis = cam_up;
	float tall = 1.0;

	// The surge turns everything slowly round the effect's middle.
	float turn = swirl * (0.5 + r.y);
	mat2 spin = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn)));

	if (mode == 0 || mode == 10) {
		float roam = mode == 10 ? 0.0 : 0.45 * (1.0 + surge * 0.8);
		at += roam * vec3(sin(t * 0.31 * (0.5 + r.x) + 6.28 * c.w), 0.7 * sin(t * 0.23 * (0.5 + r.y) + 6.28 * r.z), cos(t * 0.27 * (0.5 + r.z) + 6.28 * r.w));
		bright = 0.6 + 0.4 * sin(t * (0.8 + 2.0 * r.w) + 6.28 * r.y);
	} else if (mode == 1) {
		float f = fract(c.y + 0.5 + t * (0.5 + 0.7 * r.x) * (1.0 + surge) / max(extent.y, 0.5));
		at.y = (f - 0.5) * extent.y;
		at.x += 0.12 * sin(t * 3.0 * (0.5 + r.y) + 40.0 * r.z);
		at.z += 0.12 * cos(t * 2.6 * (0.5 + r.z) + 40.0 * r.w);
		bright = sin(3.14159 * f) * (0.7 + 0.3 * sin(t * 17.0 + 60.0 * r.w));
	} else if (mode == 4) {
		float f = fract(c.w + t * 0.16 * (0.6 + 0.8 * r.x) * (1.0 + surge));
		at.y = (f * f - 0.5) * extent.y;
		bright = smoothstep(0.0, 0.08, f) * smoothstep(1.0, 0.8, f);
		up_axis = vec3(0.0, 1.0, 0.0);
		tall = 1.6 + 2.0 * f;
	} else if (mode == 5) {
		float f = fract(c.w + t * 0.05 * (0.6 + 0.8 * r.x) * (1.0 + surge));
		at.y = (f - 0.5) * extent.y;
		at.x += 0.2 * sin(t * 0.9 * (0.5 + r.y) + 40.0 * r.z);
		at.z += 0.2 * cos(t * 0.8 * (0.5 + r.z) + 40.0 * r.w);
		bright = smoothstep(0.0, 0.1, f) * smoothstep(1.0, 0.85, f);
		size *= 1.0 + 0.6 * f;
	} else if (mode == 6 || mode == 8) {
		// Swimmers and flutterers: each on its own slow loop round the box, nose first.
		card = false;
		float way = r.w > 0.5 ? 1.0 : -1.0;
		float rate = (mode == 8 ? 0.5 : 0.22) * (0.6 + 0.8 * r.x) * (1.0 + 0.6 * surge);
		float th = t * rate * way + 6.28 * c.w;
		vec2 radii = extent.xz * 0.5 * (0.3 + 0.7 * vec2(r.y, r.z));
		at = vec3(radii.x * sin(th), base.y + 0.4 * sin(th * 2.0 + 6.28 * r.w), radii.y * cos(th));
		if (mode == 8) {
			at += 0.35 * vec3(sin(t * 2.3 + 30.0 * r.x), sin(t * 3.1 + 30.0 * r.y), cos(t * 2.7 + 30.0 * r.z));
		}
		vec3 fwd = normalize(vec3(radii.x * cos(th), 0.0, -radii.y * sin(th)) * way);
		vec3 side = cross(vec3(0.0, 1.0, 0.0), fwd);
		vec3 v = VERTEX * size;
		if (mode == 6) {
			v.x += sin(t * 5.0 + UV.x * 4.0 + 20.0 * r.x) * 0.5 * size * (1.0 - UV.x);     // the tail swings
		} else {
			float flap = sin(t * 17.0 + 20.0 * r.x) * 0.95;                               // wings beat
			v = vec3(v.x * cos(flap), abs(v.x) * sin(flap) + v.y, v.z);
		}
		at.xz = spin * at.xz;
		vec3 push = scatter(at, stirred);
		at += push * 2.4 + vec3(0.0, 0.9, 0.0) * stirred;
		VERTEX = at + side * v.x + vec3(0.0, 1.0, 0.0) * v.y + fwd * v.z;
		shape_fade = 0.35 + 0.65 * UV.x;
	} else if (mode == 7) {
		// Jellyfish: they hang, pulse and trail.
		card = false;
		at += vec3(0.3 * sin(t * 0.21 + 6.28 * r.x), 0.6 * sin(t * 0.17 * (0.6 + r.y) + 6.28 * c.w), 0.3 * cos(t * 0.19 + 6.28 * r.z));
		float beat = sin(t * 1.6 * (0.7 + 0.6 * r.w) + 6.28 * r.x);
		vec3 v = VERTEX * size;
		if (UV.y > 0.5) {
			v.xz *= 1.0 + 0.16 * beat;            // the bell
			v.y *= 1.0 - 0.1 * beat;
		} else {
			v.xz += 0.07 * size * vec2(sin(t * 1.4 + v.y * 6.0 / size + 9.0 * r.y), cos(t * 1.2 + v.y * 5.0 / size)) * (1.0 - UV.x) * 3.0;
		}
		at.xz = spin * at.xz;
		vec3 push = scatter(at, stirred);
		at += push * 1.8 + vec3(0.0, 0.7, 0.0) * stirred;
		VERTEX = at + v;
		shape_fade = 0.3 + 0.7 * UV.x;
	} else if (mode == 11) {
		// Caged lightning: a jagged line the box's whole height that jumps many times a second.
		card = false;
		float tick = floor(t * (11.0 + 6.0 * r.x) + 10.0 * c.w);
		float knot = floor(UV.y * 8.0 + 0.5);
		vec2 off = vec2(hash1(tick * 3.1 + knot * 7.7 + r.y * 50.0), hash1(tick * 5.3 + knot * 3.3 + r.z * 50.0)) - 0.5;
		float pinned = sin(3.14159 * UV.y);
		vec3 v = vec3(VERTEX.x * piece, (UV.y - 0.5) * extent.y, VERTEX.z * piece);
		v.xz += off * extent.xz * 0.8 * pinned + base.xz * 0.5;
		VERTEX = v;
		bright = step(0.3 - 0.3 * surge, hash1(tick * 1.7 + r.w * 9.0)) * (0.7 + 0.6 * hash1(tick));
	}

	if (card) {
		at.xz = spin * at.xz;
		vec3 push = scatter(at, stirred);
		at += push * 1.5 + 0.12 * stirred * vec3(sin(t * 9.0 + 40.0 * r.x), sin(t * 11.0 + 40.0 * r.y), cos(t * 10.0 + 40.0 * r.z));
		VERTEX = at + (cam_right * (UV.x - 0.5) + up_axis * (UV.y - 0.5) * tall) * size * 2.0;
	}
	glow = mix(tint_a, tint_b, r.y) * power * max(bright, 0.0) * (1.0 + 0.8 * surge + 1.3 * stirred);
}

void fragment() {
	float a = shape_fade;
	if (mode == 0 || mode == 1 || mode == 10) {
		float d = length(UV - 0.5) * 2.0;
		a = pow(max(1.0 - d, 0.0), 2.0);
	} else if (mode == 4) {
		vec2 q = (UV - 0.5) * 2.0;
		q.y = q.y * 0.5 + 0.5 * q.y * q.y * sign(q.y) + 0.2;      // a teardrop: round head, drawn-out tail below
		a = pow(max(1.0 - length(vec2(q.x, q.y * 0.9)), 0.0), 1.5);
	} else if (mode == 5) {
		float d = length(UV - 0.5) * 2.0;
		a = smoothstep(0.62, 0.86, d) * smoothstep(1.0, 0.9, d) + 0.1 * smoothstep(1.0, 0.0, d);
		a += 0.6 * pow(max(1.0 - length(UV - vec2(0.36, 0.66)) * 6.0, 0.0), 2.0);   // a glint
	}
	ALBEDO = glow * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
