shader_type sky;
// Sky Island's sky: a clear midday blue with fair-weather clouds drifting round the
// horizon, and below the islands a bright sea of cloud. Made in code, no textures.
//
// The cloud sea is a flat layer at `cloud_height`, worked out from where the camera
// is, so it stays put below the islands as you move and hides the drop under them.

uniform vec3 sun_dir = vec3(0.35, 0.79, 0.5);
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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.02 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(sun_dir);
	// The sky: deep blue overhead, paling to a soft haze at the horizon.
	vec3 top = vec3(0.05, 0.26, 0.78);
	vec3 low = vec3(0.36, 0.64, 0.97);
	float h = clamp(d.y, 0.0, 1.0);
	vec3 colour = mix(low, top, pow(smoothstep(0.0, 0.85, h), 0.6));
	// The sun: a white disc and a warm glow round it.
	float toward = max(dot(d, sun), 0.0);
	vec3 sun_colour = vec3(1.0, 0.95, 0.82);
	colour += sun_colour * (pow(toward, 12.0) * 0.22 + pow(toward, 200.0) * 0.6);
	colour += sun_colour * smoothstep(0.9990, 0.9995, toward) * 2.5;
	// Fair-weather clouds: puffy, flat-bottomed, thickest low in the sky.
	if (d.y > 0.0) {
		vec2 up = d.xz / (d.y + 0.12);
		vec2 drift = vec2(TIME * 0.006, TIME * 0.002);
		float puff = fbm(up * 1.6 + drift) * 0.7 + fbm(up * 4.5 - drift * 2.0) * 0.3;
		float cover = smoothstep(0.5, 0.68, puff) * smoothstep(0.0, 0.05, d.y) * smoothstep(0.6, 0.15, d.y);
		float lit = 0.75 + 0.25 * smoothstep(0.5, 0.8, puff) + pow(toward, 4.0) * 0.2;
		colour = mix(colour, vec3(1.0, 0.99, 0.97) * lit, cover * 0.9);
	}
	// The sea of clouds below: everything under the horizon.
	float gap = POSITION.y - cloud_height;
	vec3 cloud_lit = vec3(1.0, 1.0, 0.98);
	vec3 cloud_shade = vec3(0.44, 0.68, 1.0);
	if (gap <= 0.5) {
		// Down in them (a moment before the fall ends): nothing but cloud.
		colour = mix(cloud_shade, cloud_lit, 0.5 + 0.5 * d.y);
	} else if (d.y < 0.0) {
		float reach = gap / max(-d.y, 0.0005);
		vec2 p = POSITION.xz + d.xz * reach;
		vec2 drift = vec2(TIME * 0.5, TIME * 0.2);
		float billow = fbm((p + drift) * 0.012) * 0.6 + fbm((p - drift * 1.6) * 0.045) * 0.4;
		float lump = smoothstep(0.38, 0.74, billow);
		vec3 sea = mix(cloud_shade, cloud_lit, lump);
		sea += sun_colour * pow(max(dot(normalize(vec3(d.x, 0.0, d.z)), normalize(vec3(sun.x, 0.0, sun.z))), 0.0), 5.0) * 0.12 * lump;
		// Far away it melts into the horizon's haze.
		float far = smoothstep(150.0, 1500.0, reach);
		colour = mix(sea, low, far);
	}
	COLOR = colour;
}
