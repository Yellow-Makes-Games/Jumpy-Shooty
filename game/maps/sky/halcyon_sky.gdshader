shader_type sky;
// Halcyon's sky: open space seen from the colony ship. A field of stars, a faint
// nebula and a blue-green planet low in the north (it fills the hangar's viewport).
// Made in code, no textures. `deepen` is turned up by the map's GravityEvent: the
// whole sky sinks into a deeper blue while gravity is low.

uniform float deepen : hint_range(0.0, 1.0) = 0.0;
uniform vec3 planet_dir = vec3(0.16, 0.3, -0.94);
uniform float planet_size : hint_range(0.02, 0.6) = 0.21;   // radians, from its middle to its edge
uniform vec3 sun_dir = vec3(0.75, 0.45, -0.3);
uniform float star_density : hint_range(0.0, 0.05) = 0.012;

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

// One layer of stars: the view direction cut into cells, a star in a few of them.
vec3 stars(vec3 d, float scale, float size) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float pick = hash(cell);
	if (pick > star_density * (size > 0.3 ? 0.5 : 1.0)) {
		return vec3(0.0);
	}
	vec3 at = cell + 0.25 + 0.5 * vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1));
	float spot = smoothstep(size, 0.0, length(p - at));
	float warm = hash(cell + 7.7);
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.92, 0.8), warm);
	return tint * spot * (0.5 + 1.8 * hash(cell + 5.5));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 colour = vec3(0.004, 0.006, 0.014);
	// Nebula: two soft clouds of colour.
	float cloud = fbm(d * 2.2 + vec3(3.1, 1.7, 0.4));
	float wisp = fbm(d * 4.6 - vec3(1.3, 0.2, 2.1));
	colour += vec3(0.1, 0.045, 0.16) * smoothstep(0.42, 0.8, cloud) * 0.7;
	colour += vec3(0.02, 0.085, 0.12) * smoothstep(0.48, 0.85, wisp) * 0.6;
	colour += stars(d, 190.0, 0.22) + stars(d.zxy, 110.0, 0.32);
	// The planet: a lit ball, with seas, land, cloud and a thin rim of air.
	vec3 pd = normalize(planet_dir);
	float away = acos(clamp(dot(d, pd), -1.0, 1.0));
	if (away < planet_size * 1.12) {
		vec3 disc = (d - pd * cos(away)) / sin(planet_size);
		float r2 = dot(disc, disc);
		if (r2 < 1.0) {
			vec3 n = normalize(disc - pd * sqrt(1.0 - r2));
			float lit = clamp(dot(n, normalize(sun_dir)) * 1.15 + 0.12, 0.0, 1.0);
			float land = smoothstep(0.5, 0.62, fbm(n * 2.6 + 4.0));
			float cover = smoothstep(0.52, 0.75, fbm(n * 4.4 + vec3(0.0, 2.0, 7.0)));
			vec3 ground = mix(vec3(0.06, 0.24, 0.5), vec3(0.16, 0.42, 0.24), land);
			ground = mix(ground, vec3(0.9, 0.94, 0.97), cover * 0.85);
			float rim = pow(r2, 3.0);
			colour = ground * (0.03 + lit) + vec3(0.2, 0.5, 0.9) * rim * (0.1 + lit) * 0.7;
		} else {
			float haze = 1.0 - (away - planet_size) / (planet_size * 0.12);
			colour += vec3(0.1, 0.3, 0.6) * haze * haze * 0.35;
		}
	}
	colour = mix(colour, colour * vec3(0.45, 0.7, 1.7) + vec3(0.0, 0.006, 0.04), deepen);
	COLOR = colour;
}
