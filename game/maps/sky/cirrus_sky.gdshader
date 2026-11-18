shader_type sky;
// Cirrus's sky: a warm golden afternoon over a sea of clouds, with a huge ringed
// planet low on the horizon. Made in code, no textures.
//
// The map's LayoutEvent drives three numbers:
//   sunset  0 = golden afternoon (the Hub layout), 1 = a deep sunset (Ring)
//   swirl   0..1 while the islands move: the clouds below churn
//   sun_dir where the sun is (it sinks as the sunset comes on)
// The clouds are a flat layer at `cloud_height`, worked out from where the camera is,
// so they stay put below the islands as you move and hide what is under them.

uniform float sunset : hint_range(0.0, 1.0) = 0.0;
uniform float swirl : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_dir = vec3(-0.67, 0.59, 0.45);
uniform vec3 planet_dir = vec3(-0.52, 0.2, 0.83);
uniform float planet_size : hint_range(0.02, 0.8) = 0.34;   // radians, from its middle to its edge
uniform float cloud_height = -30.0;

float hash(vec2 p) {
	p = fract(p * vec2(0.3183099, 0.3678794) + vec2(0.11, 0.17));
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(sun_dir);
	// The sky itself: deep above, glowing toward the horizon.
	vec3 top = mix(vec3(0.3, 0.52, 0.86), vec3(0.2, 0.2, 0.46), sunset);
	vec3 mid = mix(vec3(0.96, 0.8, 0.56), vec3(0.95, 0.42, 0.3), sunset);
	vec3 low = mix(vec3(1.0, 0.9, 0.7), vec3(1.0, 0.62, 0.3), sunset);
	float h = clamp(d.y, 0.0, 1.0);
	vec3 colour = mix(low, mid, smoothstep(0.0, 0.16, h));
	colour = mix(colour, top, smoothstep(0.1, 0.75, h));
	// The sun: a disc, and its glow spreading along the horizon.
	float toward = max(dot(d, sun), 0.0);
	vec3 sun_colour = mix(vec3(1.0, 0.93, 0.74), vec3(1.0, 0.56, 0.24), sunset);
	colour += sun_colour * (pow(toward, 9.0) * 0.32 + pow(toward, 90.0) * 0.7);
	colour += sun_colour * smoothstep(0.9988, 0.9994, toward) * 3.0;
	// High, thin cloud streaks (the cirrus the place is named for).
	if (d.y > 0.02) {
		vec2 up = d.xz / (d.y + 0.25);
		float streak = fbm(vec2(up.x * 1.1 + TIME * 0.004, up.y * 4.2));
		float wisp = smoothstep(0.52, 0.78, streak) * smoothstep(0.02, 0.2, d.y) * 0.55;
		colour = mix(colour, mix(vec3(1.0, 0.97, 0.9), vec3(1.0, 0.66, 0.5), sunset), wisp);
	}
	// The planet: a banded ball with a ring, low on the horizon.
	vec3 pd = normalize(planet_dir);
	float away = acos(clamp(dot(d, pd), -1.0, 1.0));
	if (away < planet_size * 2.6) {
		vec3 side = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
		vec3 upv = cross(side, pd);
		vec2 q = vec2(dot(d, side), dot(d, upv)) / sin(planet_size);
		// (tipped, so the ring crosses it at a slant)
		q = vec2(q.x * 0.94 - q.y * 0.34, q.x * 0.34 + q.y * 0.94);
		float r2 = dot(q, q);
		float ring_r = length(vec2(q.x, q.y * 3.6));
		float ring = smoothstep(1.32, 1.4, ring_r) * smoothstep(2.3, 2.18, ring_r);
		ring *= 0.55 + 0.45 * sin(ring_r * 34.0) * sin(ring_r * 13.0 + 1.0);
		bool behind = q.y > 0.0;   // the far half of the ring passes behind the ball
		vec3 haze = mix(colour, mix(vec3(0.98, 0.86, 0.7), vec3(0.9, 0.5, 0.42), sunset), 0.5);
		if (r2 < 1.0) {
			vec3 n = normalize(side * q.x + upv * q.y - pd * sqrt(1.0 - r2));
			float lit = clamp(dot(n, sun) * 0.9 + 0.35, 0.0, 1.0);
			float bands = 0.5 + 0.5 * sin(q.y * 15.0 + fbm(q * 3.0 + 4.0) * 3.0);
			vec3 ground = mix(vec3(0.86, 0.6, 0.42), vec3(0.96, 0.82, 0.62), bands);
			ground = mix(ground, vec3(0.7, 0.4, 0.36), smoothstep(0.5, 0.9, fbm(q * 5.0 + 9.0)) * 0.5);
			vec3 ball = ground * (0.25 + lit * 0.85);
			// Far off through a lot of air: it sits in the sky's own haze, palest at its foot.
			colour = mix(ball, haze, 0.38 + 0.3 * smoothstep(0.3, -0.9, q.y));
			if (!behind) {
				colour = mix(colour, mix(vec3(0.98, 0.9, 0.76), haze, 0.3), ring * 0.8);
			}
		} else {
			colour = mix(colour, mix(vec3(0.98, 0.9, 0.76), haze, 0.35), ring * 0.7);
		}
	}
	// The sea of clouds: everything below the horizon, as a layer far below the islands.
	float gap = POSITION.y - cloud_height;
	vec3 cloud_lit = mix(vec3(1.0, 0.95, 0.84), vec3(1.0, 0.68, 0.5), sunset);
	vec3 cloud_shade = mix(vec3(0.8, 0.68, 0.62), vec3(0.42, 0.3, 0.46), sunset);
	if (gap <= 0.5) {
		// Down in them (a moment before the fall ends): nothing but cloud.
		colour = mix(cloud_shade, cloud_lit, 0.5 + 0.5 * d.y);
	} else if (d.y < 0.0) {
		float reach = gap / max(-d.y, 0.0005);
		vec2 p = POSITION.xz + d.xz * reach;
		// While the islands move the layer churns round the middle of the map.
		float turn = swirl * 0.9 * exp(-length(p) / 160.0);
		p = vec2(p.x * cos(turn) - p.y * sin(turn), p.x * sin(turn) + p.y * cos(turn));
		vec2 drift = vec2(TIME * 0.6, TIME * 0.25);
		float billow = fbm((p + drift) * 0.016) * 0.65 + fbm((p - drift * 1.7) * 0.05 + swirl * 2.0) * 0.35;
		float lump = smoothstep(0.3, 0.72, billow);
		vec3 sea = mix(cloud_shade, cloud_lit, lump);
		sea += sun_colour * pow(max(dot(normalize(vec3(d.x, 0.0, d.z)), normalize(vec3(sun.x, 0.0, sun.z))), 0.0), 6.0) * 0.16 * lump;
		// Far away it melts into the horizon's glow.
		float far = smoothstep(120.0, 1400.0, reach);
		colour = mix(sea, low, far);
	}
	COLOR = colour;
}
