// The sky engine: one sky made of layers, each switched on and tuned by a SkyPreset
// (game/maps/sky/sky_preset.gd). Made in code, no textures.
//
// Two shaders include this:
//  - sky_engine.gdshader, the Environment's sky: a still picture of it. It lights the
//    map (ambient light and reflections are captured from it once, not every frame)
//    and is the background on the Low graphics preset.
//  - sky_dome.gdshader, the moving sky drawn on a backdrop locked to the camera,
//    behind everything (Medium and High). Anything that moves lives here, so the
//    Environment's sky never has to be captured again.
//
// Every layer is off when its amount is 0, and costs nothing then.
// `t` is the time in seconds (0 for the still sky); `full` is false where detail is
// wasted (the lighting capture).

// -- Gradient: horizon up to the top of the sky ---------------------------------------
uniform vec3 zenith_color : source_color = vec3(0.1, 0.3, 0.75);
uniform vec3 sky_color : source_color = vec3(0.3, 0.55, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.85, 0.95);
uniform float horizon_band = 0.16;     // how high the horizon colour reaches
uniform float zenith_start = 0.1;      // where the top colour starts...
uniform float zenith_end = 0.75;       // ...and has taken over
uniform float zenith_power = 1.0;
uniform vec3 ground_color : source_color = vec3(0.35, 0.36, 0.38);   // below the horizon (floor_mode 0)
uniform float sky_energy = 1.0;
// A glow lying along the horizon (sunset air, a planet's air).
uniform vec3 glow_color : source_color = vec3(1.0, 0.7, 0.4);
uniform float glow_amount = 0.0;
uniform float glow_falloff = 12.0;

// -- Sun (its direction always comes from the map's Sun light) ------------------------
uniform vec3 sun_dir = vec3(0.35, 0.79, 0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform float sun_disc = 2.5;          // the disc's brightness (0: no disc)
uniform float sun_radius = 0.04;       // radians
uniform float sun_glow = 0.22;
uniform float sun_glow_power = 12.0;
uniform float sun_core = 0.6;
uniform float sun_core_power = 200.0;

// -- Moon ---------------------------------------------------------------------------------
uniform float moon_amount = 0.0;
uniform vec3 moon_dir = vec3(-0.4, 0.5, -0.75);
uniform float moon_radius = 0.06;
uniform vec3 moon_color : source_color = vec3(0.86, 0.88, 0.95);
uniform float moon_phase = 0.25;       // 0 full, toward +-1 a crescent
uniform float moon_glow = 0.25;

// -- Stars ------------------------------------------------------------------------------
uniform float star_amount = 0.0;
uniform float star_density = 0.012;
uniform float star_scale = 190.0;
uniform vec3 star_tint_a : source_color = vec3(0.88, 0.93, 1.0);
uniform vec3 star_tint_b : source_color = vec3(1.0, 0.96, 0.9);
uniform float star_fade = 0.0;         // > 0: stars thin out within this height of the horizon
uniform float star_twinkle = 0.3;

// -- Nebula -----------------------------------------------------------------------------
uniform float nebula_amount = 0.0;
uniform vec3 nebula_color_a : source_color = vec3(0.35, 0.24, 0.44);
uniform vec3 nebula_color_b : source_color = vec3(0.15, 0.32, 0.38);
uniform float nebula_scale = 2.2;

// -- Aurora, shooting stars, a ribbon of magic ----------------------------------------------
uniform float aurora_amount = 0.0;
uniform vec3 aurora_color_a : source_color = vec3(0.48, 0.97, 0.8);
uniform vec3 aurora_color_b : source_color = vec3(0.8, 0.63, 1.0);
uniform float meteor_amount = 0.0;
uniform float ribbon_amount = 0.0;

// -- Clouds -----------------------------------------------------------------------------
// High thin streaks (cirrus).
uniform float streak_amount = 0.0;
uniform vec3 streak_color : source_color = vec3(1.0, 0.98, 0.95);
// Puffy fair-weather clouds round the horizon.
uniform float puff_amount = 0.0;
uniform vec3 puff_color : source_color = vec3(1.0, 1.0, 0.98);
uniform vec3 puff_shade : source_color = vec3(0.8, 0.84, 0.9);
uniform float puff_top = 0.6;          // how high in the sky they reach
// A grey or dusty overcast: flattens the sky and lays a soft deck of cloud over it.
uniform float overcast_amount = 0.0;
uniform vec3 overcast_color : source_color = vec3(0.78, 0.76, 0.72);
// Haze rising off the horizon (and hiding the far edge of the floor).
uniform float haze_amount = 0.0;
uniform float haze_height = 0.12;

// -- A planet (or a big moon) hanging in the sky ------------------------------------------
uniform float planet_amount = 0.0;
uniform vec3 planet_dir = vec3(-0.52, 0.2, 0.83);
uniform float planet_radius = 0.34;    // radians, from its middle to its edge
uniform int planet_style = 0;          // 0 banded (gas giant), 1 seas, land and cloud
uniform vec3 planet_color_a : source_color = vec3(0.93, 0.79, 0.68);
uniform vec3 planet_color_b : source_color = vec3(0.98, 0.92, 0.82);
uniform vec3 planet_color_c : source_color = vec3(0.86, 0.67, 0.64);
uniform vec3 planet_rim : source_color = vec3(0.48, 0.74, 0.95);
uniform float planet_haze = 0.0;       // sunk into the sky's haze (far off through a lot of air)
uniform vec3 planet_haze_color : source_color = vec3(0.99, 0.94, 0.86);
uniform float planet_ambient = 0.25;   // how lit its night side is
uniform float planet_wrap = 0.35;      // how far round the light reaches
uniform vec3 planet_light_dir = vec3(0.0);   // what lights it (0: the sun)
uniform float planet_tilt = 0.35;      // its bands' and ring's slant (radians)
uniform float ring_amount = 0.0;
uniform vec3 ring_color : source_color = vec3(0.99, 0.95, 0.88);
uniform float planet_spin = 0.004;

// -- Below the horizon ------------------------------------------------------------------
// 0 ground (ground_color), 1 a sea of cloud, 2 a planet seen from low orbit (its limb a
// little above the horizon), 3 open space (the sky carries on all round).
uniform int floor_mode = 0;
uniform float sea_height = -30.0;
uniform vec3 sea_lit : source_color = vec3(1.0, 1.0, 0.99);
uniform vec3 sea_shade : source_color = vec3(0.7, 0.85, 1.0);
uniform float sea_churn = 0.0;         // events turn it up: the layer swirls round the middle
uniform float sea_bumps = 0.36;        // where the billows start to light up
uniform float limb = 0.06;
uniform vec3 limb_color_a : source_color = vec3(0.25, 0.63, 0.67);
uniform vec3 limb_color_b : source_color = vec3(0.62, 0.41, 0.74);
uniform vec3 limb_color_c : source_color = vec3(0.44, 0.81, 0.79);
uniform vec3 limb_air : source_color = vec3(0.6, 0.89, 0.92);
uniform vec3 limb_air_2 : source_color = vec3(0.74, 0.58, 0.9);

// -- Far silhouettes standing on the horizon ----------------------------------------------
uniform int silhouette_mode = 0;       // 0 none, 1 city skyline, 2 hills, 3 mountains
uniform vec3 silhouette_color : source_color = vec3(0.35, 0.37, 0.42);
uniform float silhouette_height = 0.06;
uniform float silhouette_haze = 0.35;
uniform float silhouette_lights = 0.0;
uniform vec3 silhouette_light_color : source_color = vec3(1.0, 0.82, 0.5);
uniform float silhouette_seed = 0.0;
// A city's glow on the horizon at night.
uniform float city_glow = 0.0;
uniform vec3 city_glow_color : source_color = vec3(1.0, 0.6, 0.35);

// -- Psychedelic: slow-flowing colour, folded into a kaleidoscope ---------------------------
uniform float psy_amount = 0.0;
uniform float psy_speed = 1.0;
uniform float psy_segments = 6.0;
uniform float psy_scale = 1.4;
uniform float psy_hue_drift = 1.0;
uniform vec3 psy_color_a : source_color = vec3(0.98, 0.35, 0.78);
uniform vec3 psy_color_b : source_color = vec3(0.3, 0.85, 0.95);
uniform vec3 psy_color_c : source_color = vec3(1.0, 0.82, 0.3);

// -- Surreal: things the sky can't have -----------------------------------------------------
uniform float sun2_amount = 0.0;
uniform vec3 sun2_dir = vec3(0.6, 0.25, -0.75);
uniform vec3 sun2_color : source_color = vec3(0.6, 0.85, 1.0);
uniform float shapes_amount = 0.0;
uniform vec3 shapes_color : source_color = vec3(0.92, 0.86, 1.0);
uniform float mirror_amount = 0.0;     // an upside-down horizon hanging high overhead
uniform float mirror_line = 0.62;
uniform vec3 mirror_color : source_color = vec3(0.55, 0.45, 0.7);
uniform float orbit_amount = 0.0;
uniform vec3 orbit_color : source_color = vec3(1.0, 0.92, 0.8);

// -- Finish -------------------------------------------------------------------------------
uniform vec3 tint_mul = vec3(1.0);     // multiplies the whole sky (events deepen it with this)
uniform vec3 tint_add = vec3(0.0);
// Nothing right behind the players may be brighter than this (keeps them easy to see).
uniform float horizon_cap = 1.6;

// -- The map's own fog (set by SkyRig from the Environment, not by presets) --------------------
// fog_affect: how much of the fog colour lies over the sky (the Environment's Sky Affect;
// Godot does this itself for the still sky, so it is only set on the moving one).
// fog_floor: 1 where the map has distance fog: far ground melts into the fog colour, as
// the map's own ground does.
uniform vec3 fog_color : source_color = vec3(0.5);
uniform float fog_affect = 0.0;
uniform float fog_floor = 0.0;

const float SK_TAU = 6.2831853;

// -- Noise --------------------------------------------------------------------------------
float sk_hash2(vec2 p) {
	p = fract(p * vec2(0.3183099, 0.3678794) + vec2(0.11, 0.17));
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

float sk_noise2(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(sk_hash2(i), sk_hash2(i + vec2(1.0, 0.0)), f.x),
		mix(sk_hash2(i + vec2(0.0, 1.0)), sk_hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float sk_fbm2(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * sk_noise2(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

float sk_hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.23));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float sk_noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(sk_hash3(i), sk_hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(sk_hash3(i + vec3(0.0, 1.0, 0.0)), sk_hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(sk_hash3(i + vec3(0.0, 0.0, 1.0)), sk_hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(sk_hash3(i + vec3(0.0, 1.0, 1.0)), sk_hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float sk_fbm3(vec3 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * sk_noise3(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.3);
		a *= 0.5;
	}
	return v;
}

float sk_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// A frame round a direction: x and y across it, z along it.
mat3 sk_frame(vec3 along) {
	vec3 z = normalize(along);
	vec3 helper = abs(z.y) > 0.98 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 x = normalize(cross(z, helper));
	vec3 y = cross(x, z);
	return mat3(x, y, z);
}

// -- Layers -------------------------------------------------------------------------------

// One field of stars: the view direction cut into cells, a star in a few of them.
vec3 sk_stars(vec3 d, float scale, float size, float t, bool full) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	if (sk_hash3(cell) > star_density * (size > 0.3 ? 0.5 : 1.0)) {
		return vec3(0.0);
	}
	vec3 at = cell + 0.25 + 0.5 * vec3(sk_hash3(cell + 1.3), sk_hash3(cell + 2.7), sk_hash3(cell + 4.1));
	float spot = smoothstep(size, 0.0, length(p - at));
	vec3 tint = mix(star_tint_a, star_tint_b, sk_hash3(cell + 7.7));
	float shine = 0.5 + 1.8 * sk_hash3(cell + 5.5);
	if (full && star_twinkle > 0.0) {
		shine *= 1.0 - star_twinkle * (0.5 + 0.5 * sin(t * (1.5 + 3.0 * sk_hash3(cell + 9.1)) + sk_hash3(cell + 3.3) * SK_TAU));
	}
	return tint * spot * shine;
}

// A shooting star: one every `every` seconds somewhere above, lasting a second or so.
float sk_meteor(vec3 d, float t, float every, float salt) {
	float turn = floor(t / every);
	float along = fract(t / every) * every / 1.3;
	if (along > 1.0) {
		return 0.0;
	}
	float az = sk_hash3(vec3(turn, salt, 1.0)) * SK_TAU;
	float up = 0.3 + 0.55 * sk_hash3(vec3(turn, salt, 2.0));
	vec3 from = normalize(vec3(cos(az) * (1.0 - up), up, sin(az) * (1.0 - up)));
	float way = az + 1.6 + sk_hash3(vec3(turn, salt, 3.0)) * 1.4;
	vec3 heading = normalize(vec3(cos(way), -0.35, sin(way)));
	vec3 head = normalize(from + heading * along * 0.55);
	vec3 tail = normalize(from + heading * max(along - 0.3, 0.0) * 0.55);
	vec3 line = head - tail;
	float u = clamp(dot(d - tail, line) / max(dot(line, line), 0.00001), 0.0, 1.0);
	float off = length(d - (tail + line * u));
	return smoothstep(0.0035, 0.0, off) * u * u * sin(3.14159 * along) * 2.2;
}

// The skyline (or hills, or mountains) at an azimuth: how high it stands, in the same
// units as a direction's y. `layer` 0 is the far row, 1 the near.
float sk_ridge(float az, float layer) {
	float seed = silhouette_seed * 13.7 + layer * 41.3;
	if (silhouette_mode == 1) {
		// Blocks of buildings, a tower here and there, a gap now and then.
		float n = layer > 0.5 ? 70.0 : 120.0;
		float cell = floor(az / SK_TAU * n);
		float r = sk_hash2(vec2(cell, seed));
		float hgt = 0.25 + 0.55 * r;
		hgt += step(0.9, sk_hash2(vec2(cell, seed + 5.0))) * 0.7;          // a tower
		hgt *= step(0.12, sk_hash2(vec2(cell, seed + 9.0)));               // a gap
		// Groups of tall and short districts, so it reads as a city, not a comb.
		hgt *= 0.45 + 0.75 * sk_noise2(vec2(az * 3.0 + seed, 0.5));
		return hgt * silhouette_height * (layer > 0.5 ? 1.0 : 0.7);
	}
	float x = az * (silhouette_mode == 3 ? 5.0 : 3.0) + seed;
	if (silhouette_mode == 3) {
		// Ridged: sharp peaks.
		float v = 0.0;
		float a = 0.6;
		for (int i = 0; i < 4; i++) {
			v += a * (1.0 - abs(sk_noise2(vec2(x, seed)) * 2.0 - 1.0));
			x *= 2.1;
			a *= 0.45;
		}
		return pow(v * 0.8, 1.6) * silhouette_height * (layer > 0.5 ? 1.0 : 0.75);
	}
	// Rolling hills.
	float v = sk_noise2(vec2(x, seed)) * 0.7 + sk_noise2(vec2(x * 2.3, seed + 3.0)) * 0.3;
	return (0.3 + 0.7 * v) * silhouette_height * (layer > 0.5 ? 0.85 : 0.65);
}

// Lit windows on the near row of a skyline.
float sk_windows(float az, float y, float top) {
	vec2 g = vec2(az / SK_TAU * 70.0 * 6.0, y / max(silhouette_height, 0.001) * 26.0);
	vec2 c = floor(g);
	vec2 f = fract(g);
	float pane = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.75);
	float on = step(0.72, sk_hash2(c + silhouette_seed));
	return pane * on * step(y, top - 0.002);
}

// A cyclic gradient through three colours.
vec3 sk_cycle(float x, vec3 a, vec3 b, vec3 c) {
	x = fract(x) * 3.0;
	if (x < 1.0) return mix(a, b, smoothstep(0.0, 1.0, x));
	if (x < 2.0) return mix(b, c, smoothstep(1.0, 2.0, x));
	return mix(c, a, smoothstep(2.0, 3.0, x));
}

vec3 sk_hue(vec3 c, float turn) {
	// Turn round the grey axis (keeps brightness).
	vec3 k = vec3(0.57735);
	float co = cos(turn);
	return c * co + cross(k, c) * sin(turn) + k * dot(k, c) * (1.0 - co);
}

vec3 sk_psychedelic(vec3 d, float t, bool full) {
	float az = atan(d.z, d.x);
	float el = asin(clamp(abs(d.y), 0.0, 1.0));
	float seg = SK_TAU / max(psy_segments, 1.0);
	float a = abs(mod(az + t * 0.01 * psy_speed, seg) - seg * 0.5);     // folded: a kaleidoscope
	vec2 p = vec2(cos(a), sin(a)) * (1.5708 - el) * psy_scale;
	float s = t * psy_speed;
	int oct = full ? 4 : 2;
	vec2 w = vec2(sk_fbm2(p * 1.3 + vec2(s * 0.05, 0.0), oct), sk_fbm2(p * 1.3 + vec2(5.2, -s * 0.04), oct));
	float f = sk_fbm2(p * 2.0 + w * 2.5 + vec2(0.0, s * 0.03), oct);
	float bands = f * 2.2 + length(p) * 0.5 - s * 0.025;
	vec3 col = sk_cycle(bands, psy_color_a, psy_color_b, psy_color_c);
	col = max(sk_hue(col, t * 0.02 * psy_hue_drift), vec3(0.0));
	// Soft bright veins along the folds.
	col += col * smoothstep(0.08, 0.0, abs(fract(bands * 2.0) - 0.5) - 0.38) * 0.25;
	return col;
}

// A faceted low-poly shape (an octahedron's outline: four lit faces) floating far off.
vec3 sk_shape(vec3 d, vec3 at, float size, float spin, vec3 sun, inout float cover) {
	mat3 fr = sk_frame(at);
	float along = dot(d, fr[2]);
	if (along < 0.5) {
		return vec3(0.0);
	}
	vec2 q = vec2(dot(d, fr[0]), dot(d, fr[1])) / along / size;
	float c = cos(spin);
	float s = sin(spin);
	q = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
	q.y *= 1.35;                                         // taller than wide
	float r = abs(q.x) + abs(q.y);
	if (r > 1.0) {
		return vec3(0.0);
	}
	// Which face: lit from the sun's side, darker away from it.
	vec2 face = sign(q + 0.0001);
	vec2 sun2d = normalize(vec2(dot(sun, fr[0]), dot(sun, fr[1])) + 0.0001);
	float lit = 0.55 + 0.35 * dot(normalize(face), sun2d);
	lit += 0.12 * step(0.0, q.x * q.y);                  // the facets read as facets
	float edge = smoothstep(0.92, 1.0, r) * 0.35;
	cover = smoothstep(1.0, 0.97, r);
	return shapes_color * (lit + edge);
}

// -- The whole sky in one direction ---------------------------------------------------------
// `d` the direction (normalised), `eye` where the camera is (for the cloud sea).
vec3 sky_engine(vec3 d, vec3 eye, float t, bool full) {
	vec3 sun = normalize(sun_dir);
	float horizon_line = 0.0;
	if (floor_mode == 2) {
		// Low orbit: the planet's limb a nearly level line a little above the horizon,
		// sinking away to the sides.
		horizon_line = limb - 0.035 * (1.0 - d.x * sun.x - d.z * sun.z);
	}
	float h = d.y - horizon_line;
	float az = atan(d.z, d.x);

	// The gradient.
	float up = clamp(h, 0.0, 1.0);
	vec3 colour = mix(horizon_color, sky_color, smoothstep(0.0, max(horizon_band, 0.001), up));
	colour = mix(colour, zenith_color, pow(smoothstep(zenith_start, zenith_end, up), zenith_power));
	if (floor_mode == 3) {
		// Open space: the same all round (the gradient by height from the middle).
		float a = abs(d.y);
		colour = mix(horizon_color, sky_color, smoothstep(0.0, max(horizon_band, 0.001), a));
		colour = mix(colour, zenith_color, pow(smoothstep(zenith_start, zenith_end, a), zenith_power));
	}
	if (overcast_amount > 0.0) {
		vec3 flat_sky = mix(overcast_color, overcast_color * 0.82, smoothstep(0.0, 0.9, up));
		colour = mix(colour, flat_sky, overcast_amount);
	}
	if (glow_amount > 0.0 && h > 0.0) {
		colour += glow_color * exp(-h * glow_falloff) * glow_amount;
	}
	if (floor_mode == 2 && h > 0.0) {
		// The planet's air, glowing along the limb.
		colour += limb_air * exp(-h * 26.0) * 0.55 + limb_air_2 * exp(-h * 7.0) * 0.16;
	}
	if (city_glow > 0.0) {
		colour += city_glow_color * exp(-abs(h) * 14.0) * city_glow;
	}

	// Psychedelic colour, calmer close to the horizon (behind the players).
	if (psy_amount > 0.0 && (h > -0.02 || floor_mode == 3)) {
		float calm = mix(0.15, 1.0, smoothstep(0.03, 0.5, abs(h)));
		colour = mix(colour, sk_psychedelic(d, t, full), psy_amount * calm);
	}

	// Night things: stars, nebula, aurora, shooting stars, the ribbon.
	float clear = star_fade > 0.0 ? smoothstep(star_fade * 0.075, star_fade, h) : 1.0;
	bool sky_side = h > 0.0 || floor_mode == 3;
	if (nebula_amount > 0.0 && sky_side) {
		float cloud = sk_fbm3(d * nebula_scale + vec3(3.1, 1.7, 0.4), full ? 4 : 3);
		float wisp = sk_fbm3(d * nebula_scale * 2.1 - vec3(1.3, 0.2, 2.1), full ? 4 : 2);
		vec3 neb = nebula_color_a * smoothstep(0.42, 0.8, cloud) * 0.7 + nebula_color_b * smoothstep(0.48, 0.85, wisp) * 0.6;
		colour += neb * nebula_amount * clear;
	}
	if (star_amount > 0.0 && sky_side) {
		vec3 s = sk_stars(d, star_scale, 0.22, t, full) + sk_stars(d.zxy, star_scale * 0.58, 0.32, t, full);
		colour += s * star_amount * clear * (1.0 - overcast_amount);
	}
	if (aurora_amount > 0.0 && h > 0.0) {
		float curtain = sk_fbm3(vec3(d.x * 3.0, d.z * 3.0, t * 0.045), 4);
		float fold = sin(d.x * 9.0 + curtain * 6.0 + t * 0.11) * 0.5 + 0.5;
		float rise = smoothstep(0.04, 0.16, h) * smoothstep(0.66, 0.2, h);
		float rays = full ? 0.55 + 0.45 * sk_noise3(vec3(d.x * 40.0 + t * 0.35, d.z * 40.0, t * 0.2)) : 0.78;
		float breath = 0.8 + 0.2 * sin(t * 0.23 + d.x * 2.0);
		colour += mix(aurora_color_a, aurora_color_b, smoothstep(0.1, 0.5, h)) * pow(fold, 3.0) * rise * rays * breath * 0.21 * aurora_amount;
	}
	if (full && meteor_amount > 0.0 && h > 0.0) {
		colour += vec3(0.9, 0.95, 1.0) * (sk_meteor(d, t, 6.5, 1.0) + sk_meteor(d, t, 11.0, 5.0)) * clear * meteor_amount;
	}
	if (full && ribbon_amount > 0.0 && h > 0.0) {
		float path = 0.36 + 0.09 * sin(az * 2.0 + t * 0.05) + 0.035 * sin(az * 5.0 - t * 0.13);
		float off = abs(d.y - path);
		float shown = smoothstep(0.35, 0.8, sin(t * 0.07) * 0.5 + 0.5);
		float sparks = 0.6 + 0.4 * sk_noise3(vec3(az * 30.0 - t * 1.5, 3.0, 7.0));
		float thread = exp(-off * off * 16000.0) * sparks + exp(-off * 40.0) * 0.07;
		colour += mix(vec3(0.7, 0.45, 1.0), vec3(1.0, 0.82, 0.5), 0.5 + 0.5 * sin(az * 3.0 + t * 0.2)) * thread * shown * 0.3 * ribbon_amount;
	}

	// The sun: its glow along the sky, then the disc.
	float toward = max(dot(d, sun), 0.0);
	colour += sun_color * (pow(toward, sun_glow_power) * sun_glow + pow(toward, sun_core_power) * sun_core);
	if (sun_disc > 0.0 && h > -0.02) {
		colour += sun_color * smoothstep(cos(sun_radius * 1.2), cos(sun_radius * 0.8), toward) * sun_disc;
	}
	if (sun2_amount > 0.0) {
		float t2 = max(dot(d, normalize(sun2_dir)), 0.0);
		colour += sun2_color * (pow(t2, 10.0) * 0.25 + pow(t2, 120.0) * 0.6) * sun2_amount;
		colour += sun2_color * smoothstep(cos(0.05), cos(0.035), t2) * 2.2 * sun2_amount;
	}

	// The moon.
	if (moon_amount > 0.0) {
		mat3 fr = sk_frame(moon_dir);
		float along = dot(d, fr[2]);
		vec2 q = vec2(dot(d, fr[0]), dot(d, fr[1])) / sin(moon_radius);
		float r2 = dot(q, q);
		colour += moon_color * pow(max(along, 0.0), 300.0) * moon_glow * moon_amount;
		if (along > 0.0 && r2 < 1.0) {
			vec3 n = normalize(fr[0] * q.x + fr[1] * q.y - fr[2] * sqrt(1.0 - r2));
			vec3 light = normalize(-fr[2] + fr[0] * moon_phase * 2.4);
			float lit = smoothstep(-0.05, 0.15, dot(n, light));
			float seas = smoothstep(0.45, 0.7, sk_fbm3(n * 3.0 + 2.0, 3)) * 0.3;
			vec3 face = moon_color * (1.0 - seas) * (0.07 + lit);
			colour = mix(colour, face, moon_amount * smoothstep(1.0, 0.94, r2));
		}
	}

	// Surreal: orbit rings across the sky, faceted shapes floating far off.
	if (orbit_amount > 0.0 && h > 0.0) {
		// Two great tilted rings round the whole sky, beads of light riding them.
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			vec3 nrm = normalize(vec3(0.45 - fi * 0.9, 1.0, 0.3 + fi * 0.4));
			float band = abs(dot(d, nrm));
			float ring = smoothstep(0.03, 0.0, band) * 0.35 + smoothstep(0.006, 0.0, band) * 0.5;
			mat3 fr = sk_frame(nrm);
			float ang = atan(dot(d, fr[1]), dot(d, fr[0]));
			float beads = pow(max(sin(ang * 9.0 - t * (0.08 + fi * 0.04)), 0.0), 24.0) * smoothstep(0.012, 0.0, band);
			colour += orbit_color * (ring + beads * 2.0) * orbit_amount * smoothstep(0.0, 0.15, h);
		}
	}
	if (shapes_amount > 0.0 && h > 0.0) {
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float a = fi * 1.31 + 0.4 + t * 0.003 * (fi - 2.0);
			float e = 0.22 + 0.13 * sk_hash2(vec2(fi, 3.0)) + 0.012 * sin(t * 0.2 + fi);
			vec3 at = normalize(vec3(cos(a), e * 2.2, sin(a)));
			float cover = 0.0;
			vec3 c = sk_shape(d, at, 0.06 + 0.05 * sk_hash2(vec2(fi, 7.0)), t * 0.05 * (1.0 + fi * 0.3) + fi, sun, cover);
			colour = mix(colour, mix(colour, c, 0.85), cover * shapes_amount);
		}
	}

	// The planet in the sky.
	if (planet_amount > 0.0) {
		vec3 pd = normalize(planet_dir);
		float away = acos(clamp(dot(d, pd), -1.0, 1.0));
		float reach = ring_amount > 0.0 ? 2.6 : 1.12;
		if (away < planet_radius * reach) {
			vec3 side = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
			vec3 upv = cross(side, pd);
			vec2 q = vec2(dot(d, side), dot(d, upv)) / sin(planet_radius);
			float ct = cos(planet_tilt);
			float st = sin(planet_tilt);
			vec2 qt = vec2(q.x * ct - q.y * st, q.x * st + q.y * ct);
			float r2 = dot(q, q);
			float ring = 0.0;
			if (ring_amount > 0.0) {
				float ring_r = length(vec2(qt.x, qt.y * 3.6));
				ring = smoothstep(1.32, 1.4, ring_r) * smoothstep(2.3, 2.18, ring_r);
				ring *= (0.55 + 0.45 * sin(ring_r * 34.0) * sin(ring_r * 13.0 + 1.0)) * ring_amount;
			}
			bool behind = qt.y > 0.0;   // the far half of the ring passes behind the ball
			vec3 haze = mix(colour, planet_haze_color, 0.5);
			vec3 light = dot(planet_light_dir, planet_light_dir) > 0.0 ? normalize(planet_light_dir) : sun;
			if (r2 < 1.0) {
				vec3 n = normalize(side * q.x + upv * q.y - pd * sqrt(1.0 - r2));
				float spin = t * planet_spin;
				vec3 ns = vec3(n.x * cos(spin) - n.z * sin(spin), n.y, n.x * sin(spin) + n.z * cos(spin));
				float lit = clamp(dot(n, light) * (1.0 + planet_wrap * 0.4) + planet_wrap, 0.0, 1.0);
				vec3 ball;
				if (planet_style == 0) {
					float bands = 0.5 + 0.5 * sin(qt.y * 15.0 + sk_fbm2(qt * 3.0 + 4.0 + vec2(spin, 0.0), 4) * 3.0);
					vec3 ground = mix(planet_color_a, planet_color_b, bands);
					ground = mix(ground, planet_color_c, smoothstep(0.5, 0.9, sk_fbm2(qt * 5.0 + 9.0 + vec2(spin * 2.0, 0.0), 4)) * 0.5);
					ball = ground * (planet_ambient + lit * 0.85);
				} else {
					float land = smoothstep(0.5, 0.62, sk_fbm3(ns * 2.6 + 4.0, 4));
					float cover = smoothstep(0.52, 0.75, sk_fbm3(ns * 4.4 + vec3(0.0, 2.0, 7.0), 4));
					vec3 ground = mix(planet_color_a, planet_color_b, land);
					ground = mix(ground, planet_color_c, cover * 0.85);
					float rim = pow(r2, 3.0);
					ball = ground * (planet_ambient + lit) + planet_rim * rim * (0.1 + lit) * 0.7;
				}
				// Far off through a lot of air: it sinks into the sky's haze, palest at its foot.
				ball = mix(ball, haze, planet_haze * (0.38 + 0.3 * smoothstep(0.3, -0.9, q.y)));
				float edge = smoothstep(1.0, 0.985, r2);
				colour = mix(colour, ball, planet_amount * edge);
				if (!behind) {
					colour = mix(colour, mix(ring_color, haze, 0.3 * planet_haze), ring * 0.8 * planet_amount);
				}
			} else {
				colour = mix(colour, mix(ring_color, haze, 0.35 * planet_haze), ring * 0.7 * planet_amount);
				if (planet_style == 1) {
					float glow = 1.0 - (away - planet_radius) / (planet_radius * 0.12);
					colour += planet_rim * 0.5 * max(glow, 0.0) * max(glow, 0.0) * 0.35 * planet_amount;
				}
			}
		}
	}

	// High streaks and puffy clouds.
	if (streak_amount > 0.0 && h > 0.02) {
		vec2 upp = d.xz / (h + 0.25);
		float streak = sk_fbm2(vec2(upp.x * 1.1 + t * 0.004, upp.y * 4.2), full ? 4 : 3);
		float wisp = smoothstep(0.52, 0.78, streak) * smoothstep(0.02, 0.2, h) * 0.55;
		colour = mix(colour, streak_color, wisp * streak_amount);
	}
	if (puff_amount > 0.0 && h > 0.0) {
		vec2 upp = d.xz / (h + 0.12);
		vec2 drift = vec2(t * 0.006, t * 0.002);
		float puff = sk_fbm2(upp * 1.6 + drift, full ? 5 : 3) * 0.7 + sk_fbm2(upp * 4.5 - drift * 2.0, full ? 4 : 2) * 0.3;
		float cover = smoothstep(0.5, 0.68, puff) * smoothstep(0.0, 0.05, h) * smoothstep(puff_top, puff_top * 0.25, h);
		float lit = 0.75 + 0.25 * smoothstep(0.5, 0.8, puff) + pow(toward, 4.0) * 0.2;
		vec3 c = mix(puff_shade, puff_color, smoothstep(0.55, 0.8, puff)) * lit;
		colour = mix(colour, c, cover * 0.9 * puff_amount);
	}
	if (overcast_amount > 0.0 && h > 0.0) {
		// The deck: big soft lumps, a little brighter toward the sun.
		vec2 upp = d.xz / (h + 0.18);
		float deck = sk_fbm2(upp * 0.9 + vec2(t * 0.004, t * 0.0015), full ? 4 : 3);
		vec3 c = overcast_color * (0.88 + 0.22 * smoothstep(0.35, 0.75, deck)) + sun_color * pow(toward, 6.0) * 0.12;
		colour = mix(colour, c, overcast_amount * 0.6 * smoothstep(0.0, 0.08, h));
	}

	// Below the horizon.
	if (h < 0.0 && floor_mode != 3) {
		if (floor_mode == 0) {
			colour = mix(horizon_color, ground_color, smoothstep(0.0, 0.08, -h));
			colour = mix(colour, fog_color, fog_floor);
		} else if (floor_mode == 1) {
			float gap = eye.y - sea_height;
			float reach = gap / max(-d.y, 0.0005);
			vec2 p = eye.xz + d.xz * reach;
			// While an event churns it, the layer turns round the middle of the map.
			float turn = sea_churn * 0.9 * exp(-length(p) / 160.0);
			p = vec2(p.x * cos(turn) - p.y * sin(turn), p.x * sin(turn) + p.y * cos(turn));
			vec2 drift = vec2(t * 0.6, t * 0.25);
			float billow = sk_fbm2((p + drift) * 0.014, full ? 4 : 3) * 0.62 + sk_fbm2((p - drift * 1.7) * 0.048 + sea_churn * 2.0, full ? 4 : 2) * 0.38;
			float lump = smoothstep(sea_bumps - 0.04, sea_bumps + 0.38, billow);
			vec3 sea = mix(sea_shade, sea_lit, lump);
			sea += sun_color * pow(max(dot(normalize(vec3(d.x, 0.0, d.z) + 0.0001), normalize(vec3(sun.x, 0.0, sun.z) + 0.0001)), 0.0), 6.0) * 0.14 * lump;
			float far = smoothstep(130.0, 1450.0, reach);
			colour = mix(sea, horizon_color, far);
		} else if (floor_mode == 2) {
			// The planet below: bands and storms, darker toward its night side.
			float depth = clamp(-h * 1.4, 0.0, 1.0);
			vec2 map = d.xz / max(0.18 - d.y, 0.12);
			map += vec2(t * 0.006, t * 0.0015);
			int oct = full ? 4 : 3;
			float bands = sk_fbm3(vec3(map * 0.55 + vec2(sk_fbm3(vec3(map * 0.3, 0.0), oct) * 1.8, 0.0), 0.3), oct);
			float storms = sk_fbm3(vec3(map * 1.7, 4.0), oct);
			vec3 land = mix(limb_color_a, limb_color_b, smoothstep(0.35, 0.65, bands));
			land = mix(land, limb_color_c, smoothstep(0.55, 0.8, storms) * 0.6);
			land = mix(land, mix(limb_color_b, vec3(1.0), 0.4), smoothstep(0.7, 0.9, bands * storms * 2.2) * 0.5);
			float day = clamp(0.55 + 0.55 * (d.x * sun.x + d.z * sun.z), 0.12, 1.0);
			colour = land * day * mix(1.0, 0.55, depth);
			colour = mix(colour, limb_air * 0.92, exp(h * 30.0) * 0.75);
			colour += limb_air_2 * 0.7 * exp(h * 9.0) * 0.18;
		}
		if (haze_amount > 0.0) {
			colour = mix(colour, horizon_color, haze_amount * exp(h / max(haze_height, 0.001)));
		}
	}
	if (haze_amount > 0.0 && h >= 0.0) {
		colour = mix(colour, horizon_color, haze_amount * exp(-h / max(haze_height, 0.001)) * 0.8);
	}

	// Silhouettes on the horizon: a far row softened by haze, a near row in front.
	if (silhouette_mode > 0 && h > -0.01 && h < silhouette_height * 1.9) {
		float far_top = sk_ridge(az, 0.0);
		if (h < far_top) {
			colour = mix(silhouette_color, horizon_color, min(silhouette_haze + 0.3, 0.9));
		}
		float near_top = sk_ridge(az, 1.0);
		if (h < near_top) {
			vec3 c = mix(silhouette_color, horizon_color, silhouette_haze * smoothstep(0.0, near_top, h) * 0.4 + silhouette_haze * 0.6);
			if (silhouette_mode == 1 && silhouette_lights > 0.0) {
				c += silhouette_light_color * sk_windows(az, h, near_top) * silhouette_lights;
			}
			colour = c;
		}
	}

	// Surreal: an upside-down world hanging overhead: its own sea of cloud seen from
	// below and its mountains pointing down at you.
	if (mirror_amount > 0.0 && d.y > mirror_line - 0.2) {
		float hy = d.y - mirror_line;
		vec3 c = colour;
		float cover = 0.0;
		if (hy > 0.0) {
			vec2 p = d.xz / max(hy, 0.02);
			float billow = sk_fbm2(p * 0.9 + vec2(t * 0.01, 0.0), full ? 4 : 3);
			float lump = smoothstep(0.35, 0.75, billow);
			c = mix(mirror_color, mix(mirror_color, vec3(1.0), 0.45), lump);
			c = mix(horizon_color, c, smoothstep(0.0, 0.12, hy));
			cover = 1.0;
		} else {
			float top = (silhouette_mode > 0 ? sk_ridge(az + 3.14159, 1.0) : 0.03 + 0.03 * sk_noise2(vec2(az * 6.0, 2.0))) * 1.6;
			if (-hy < top) {
				c = mix(mix(silhouette_color, mirror_color, 0.5), horizon_color, 0.3);
				cover = 1.0;
			}
		}
		colour = mix(colour, c, mirror_amount * cover);
		colour += glow_color * exp(-abs(hy) * 40.0) * 0.2 * mirror_amount;
	}

	colour = colour * sky_energy * tint_mul + tint_add;
	colour = mix(colour, fog_color, fog_affect);
	// Keep the band behind the players from glaring.
	float band = smoothstep(0.16, 0.04, abs(h));
	float lum = sk_luma(colour);
	if (lum > horizon_cap && band > 0.0) {
		colour *= mix(1.0, horizon_cap / lum, band);
	}
	return max(colour, vec3(0.0));
}
