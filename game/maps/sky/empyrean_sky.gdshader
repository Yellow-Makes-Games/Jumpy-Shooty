shader_type sky;
// Empyrean Tower's sky: low orbit at twilight. A huge teal-and-purple planet fills the
// sky below the horizon line and bulges up over it, lit along its rim; above it a
// violet dusk deepening to near-black, a field of stars and a faint aurora. No rings
// (that is Cirrus's planet). Made in code, no textures.

uniform vec3 sun_dir = vec3(-0.86, 0.4, 0.31);
uniform float star_density : hint_range(0.0, 0.05) = 0.014;
// How far above the level line the planet's limb stands, straight ahead (radians).
uniform float limb : hint_range(-0.5, 0.5) = 0.06;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.23));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.3);
		a *= 0.5;
	}
	return v;
}

vec3 stars(vec3 d, float scale, float size) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float pick = hash(cell);
	if (pick > star_density * (size > 0.3 ? 0.5 : 1.0)) {
		return vec3(0.0);
	}
	vec3 at = cell + 0.25 + 0.5 * vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1));
	float spot = smoothstep(size, 0.0, length(p - at));
	vec3 tint = mix(vec3(0.78, 0.8, 1.0), vec3(1.0, 0.86, 0.95), hash(cell + 7.7));
	return tint * spot * (0.5 + 1.8 * hash(cell + 5.5));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	// The planet is straight below and enormous: seen from low orbit its limb is a
	// nearly level line a little above the horizon, sinking away to the sides.
	float edge = limb - 0.035 * (1.0 - d.x * sun_dir.x - d.z * sun_dir.z);
	float h = d.y - edge;                 // above (+) or below (-) the limb
	vec3 colour;
	if (h > 0.0) {
		// Space: violet twilight near the limb, deepening upward.
		vec3 dusk = mix(vec3(0.34, 0.2, 0.52), vec3(0.75, 0.42, 0.62), smoothstep(0.35, 0.0, h) * 0.6);
		colour = mix(dusk, vec3(0.03, 0.02, 0.07), smoothstep(0.0, 0.75, h));
		colour = mix(colour, vec3(0.012, 0.01, 0.03), smoothstep(0.5, 1.0, d.y));
		// The planet's air, glowing along the limb.
		colour += vec3(0.3, 0.75, 0.8) * exp(-h * 26.0) * 0.55 + vec3(0.6, 0.4, 0.9) * exp(-h * 7.0) * 0.16;
		// Stars, fewer near the bright limb.
		float clear = smoothstep(0.03, 0.4, h);
		colour += (stars(d, 90.0, 0.22) + stars(d, 46.0, 0.34) * 1.4) * clear;
		// A faint aurora: tall, slow curtains of green and violet over the limb.
		float curtain = fbm(vec3(d.x * 3.0, d.z * 3.0, TIME * 0.02));
		float fold = sin(d.x * 9.0 + curtain * 6.0 + TIME * 0.05) * 0.5 + 0.5;
		float rise = smoothstep(0.04, 0.16, h) * smoothstep(0.62, 0.2, h);
		float rays = 0.6 + 0.4 * noise(vec3(d.x * 40.0, d.z * 40.0, 1.0));
		colour += mix(vec3(0.2, 0.9, 0.6), vec3(0.6, 0.35, 1.0), smoothstep(0.1, 0.5, h)) * pow(fold, 3.0) * rise * rays * 0.16;
	} else {
		// The planet: bands and storms of teal and purple, darker toward the night side.
		float depth = clamp(-h * 1.4, 0.0, 1.0);
		vec2 map = d.xz / max(0.18 - d.y, 0.12);          // stretched as it falls away below
		float bands = fbm(vec3(map * 0.55 + vec2(fbm(vec3(map * 0.3, 0.0)) * 1.8, 0.0), 0.3));
		float storms = fbm(vec3(map * 1.7, 4.0));
		vec3 land = mix(vec3(0.05, 0.36, 0.4), vec3(0.34, 0.14, 0.5), smoothstep(0.35, 0.65, bands));
		land = mix(land, vec3(0.16, 0.62, 0.6), smoothstep(0.55, 0.8, storms) * 0.6);
		land = mix(land, vec3(0.6, 0.5, 0.85), smoothstep(0.7, 0.9, bands * storms * 2.2) * 0.5);
		float day = clamp(0.55 + 0.55 * (d.x * sun_dir.x + d.z * sun_dir.z), 0.12, 1.0);
		colour = land * day * mix(1.0, 0.55, depth);
		// Its air thickens to a bright rim at the limb.
		colour = mix(colour, vec3(0.42, 0.82, 0.86), exp(h * 30.0) * 0.75);
		colour += vec3(0.5, 0.3, 0.8) * exp(h * 9.0) * 0.18;
	}
	COLOR = colour;
}
