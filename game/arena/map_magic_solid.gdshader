shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// MapMagic's solid-looking pieces (books, pages, candles): see map_magic_glow.gdshader
// for how an effect is laid out. These are drawn opaque, in flat colour.
//
// mode: 2 pages (loose sheets that tumble as they sink), 3 books (a flock, flapping
// their covers), 9 candles (they hang in the air and bob; a flame on each).

uniform int mode = 3;
uniform vec3 extent = vec3(6.0, 4.0, 6.0);
uniform vec3 tint_a : source_color = vec3(0.55, 0.16, 0.18);   // books: covers; candles: the flame
uniform vec3 tint_b : source_color = vec3(0.16, 0.26, 0.5);
uniform vec3 paper : source_color = vec3(0.87, 0.79, 0.6);
uniform float power = 2.4;           // candles: how bright the flame is
uniform float piece = 0.5;
uniform float surge = 0.0;
uniform float swirl = 0.0;
uniform float reach = 4.0;
uniform vec4 actor[4];

varying vec3 tone;
varying float part;       // 1: a flame
varying float lit;

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
	float size = piece * (0.7 + 0.6 * r.x);
	float stirred = 0.0;
	vec3 at = base;
	float turn = swirl * (0.5 + r.y);
	mat2 spin = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn)));
	part = 0.0;
	lit = 1.0;
	tone = paper;

	if (mode == 2) {
		// A loose page: sinks slowly through the box, swaying, turning over and over.
		float f = fract(c.w - t * 0.035 * (0.6 + 0.8 * r.x) * (1.0 + surge));
		at.y = (f - 0.5) * extent.y;
		at.x += 0.5 * sin(t * 0.7 * (0.5 + r.y) + 40.0 * r.z);
		at.z += 0.5 * cos(t * 0.6 * (0.5 + r.z) + 40.0 * r.w);
		at.xz = spin * at.xz;
		vec3 push = scatter(at, stirred);
		float a = t * (1.3 + r.y) * (1.0 + 2.0 * stirred) + 30.0 * r.z;
		float b = t * (0.9 + r.z) + 30.0 * r.w;
		vec3 v = VERTEX * size;
		v = vec3(v.x, v.y * cos(a) - v.z * sin(a), v.y * sin(a) + v.z * cos(a));
		v = vec3(v.x * cos(b) + v.z * sin(b), v.y, -v.x * sin(b) + v.z * cos(b));
		at += push * 1.8 + vec3(0.0, 0.5, 0.0) * stirred;
		VERTEX = at + v;
		lit = 0.8 + 0.2 * cos(a);
	} else if (mode == 3) {
		// A book in a flock: round and round on its own loop, spine first, covers beating.
		float way = r.w > 0.5 ? 1.0 : -1.0;
		float th = t * 0.3 * (0.6 + 0.8 * r.x) * (1.0 + 0.6 * surge) * way + 6.28 * c.w;
		vec2 radii = extent.xz * 0.5 * (0.3 + 0.7 * vec2(r.y, r.z));
		at = vec3(radii.x * sin(th), base.y + 0.5 * sin(th * 2.0 + 6.28 * r.w), radii.y * cos(th));
		vec3 fwd = normalize(vec3(radii.x * cos(th), 0.0, -radii.y * sin(th)) * way);
		vec3 side = cross(vec3(0.0, 1.0, 0.0), fwd);
		at.xz = spin * at.xz;
		vec3 push = scatter(at, stirred);
		float flap = 0.35 + 0.6 * sin(t * (6.0 + 5.0 * stirred) + 20.0 * r.x);
		vec3 v = VERTEX * size;
		v = vec3(v.x * cos(flap), abs(v.x) * sin(flap) + v.y, v.z);
		at += push * 2.6 + vec3(0.0, 1.1, 0.0) * stirred;
		VERTEX = at + side * v.x + vec3(0.0, 1.0, 0.0) * v.y + fwd * v.z;
		tone = mix(tint_a, tint_b, step(0.5, r.y));
		part = UV.y;      // (the fragment paints covers outside, pages inside)
		lit = 0.85 + 0.15 * sin(flap);
	} else {
		// A candle hanging in the air: it bobs, and its flame gutters when someone is near.
		at.y += 0.12 * sin(t * 0.8 * (0.6 + 0.8 * r.y) + 6.28 * c.w);
		scatter(at, stirred);
		vec3 v = VERTEX * vec3(1.0, UV.x > 0.5 ? 1.0 : 0.7 + 0.8 * r.x, 1.0) * piece;
		if (UV.x > 0.5) {
			float flick = 1.0 + 0.16 * sin(t * 11.0 + 30.0 * r.z) + 0.1 * sin(t * 23.0 + 30.0 * r.w);
			float low = 1.0 - 0.72 * stirred * (0.6 + 0.4 * sin(t * 31.0 + 30.0 * r.x));
			float foot = piece * 0.3 * (0.7 + 0.8 * r.x);     // the candle's top
			v.y = foot + (VERTEX.y * piece - piece * 0.3) * flick * low;
			v.x += 0.05 * piece * stirred * sin(t * 27.0 + 30.0 * r.y) * (VERTEX.y - 0.3) * 6.0;
			part = 1.0;
			lit = (0.85 + 0.15 * flick) * (1.0 - 0.5 * stirred) * (1.0 + 0.6 * surge);
		}
		VERTEX = at + v;
	}
}

void fragment() {
	if (mode == 9 && part > 0.5) {
		ALBEDO = tint_a * power * lit;
	} else if (mode == 3) {
		ALBEDO = (FRONT_FACING ? tone : paper) * lit;
	} else {
		ALBEDO = tone * lit;
	}
}
