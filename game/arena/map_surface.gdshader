shader_type spatial;
// Patterns drawn on a map kind's surfaces without any extra blocks: panel seams on
// walls, tiles on floors, grating, vent slats, hazard stripes... A palette gives a
// kind one of these by name (MapPalette.surface; the names are in MapScenery.SURFACES).
//
// Everything is worked out from where the surface is in the map, in metres, so the
// pattern lines up across blocks, and it is the same on every copy of the game. Walls
// are measured along the wall, whichever way it is turned, so seams always run level
// and upright. Lines are smoothed and fade out with distance, so nothing shimmers.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.85;
// 0 panels, 1 tiles, 2 plates (rivets), 3 grating, 4 slats, 5 hazard stripes, 6 treads, 7 corrugated
uniform int style = 0;
uniform vec2 wall_cell = vec2(3.0, 2.0);    // a wall panel: width, height (m)
uniform vec2 floor_cell = vec2(2.0, 2.0);   // a floor or ceiling tile (m)
uniform float seam = 0.02;                  // half the width of a seam (m)
uniform float seam_shade = 0.6;             // how dark a seam is (1 = cannot be seen)
uniform float vary = 0.04;                  // how much one panel differs from the next
uniform float detail = 0.0;                 // panels: the share of wall panels with a hatch or vent slots

varying vec3 map_pos;
varying vec3 map_normal;

void vertex() {
	map_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	map_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 1 on a line of half-width w, at distance d from its middle, smoothed by the pixel size px.
float stroke(float d, float w, float px) {
	return 1.0 - smoothstep(w - px * 0.5, w + px * 0.5 + 0.0001, d);
}

// 0..1: how clearly a pattern that repeats every `size` metres can still be drawn.
float clear_at(vec2 px, float size) {
	return 1.0 - smoothstep(0.12, 0.45, max(px.x, px.y) / size);
}

void fragment() {
	vec3 n = normalize(map_normal);
	bool flat_face = abs(n.y) > 0.7;
	bool wall = !flat_face;
	vec2 p;
	if (flat_face) {
		p = map_pos.xz;
	} else {
		vec2 along = normalize(vec2(n.z, -n.x));   // level, along the wall
		p = vec2(dot(map_pos.xz, along), map_pos.y);
	}
	vec2 px = fwidth(p);
	vec2 cell = wall ? wall_cell : floor_cell;
	vec2 q = p / cell;
	vec2 id = floor(q);
	vec2 in_cell = (q - id) * cell;                    // metres from the cell's corner
	vec2 to_edge = min(in_cell, cell - in_cell);       // metres to the nearest seam, each way
	float clear = clear_at(px, min(cell.x, cell.y));
	float seams = max(stroke(to_edge.x, seam, px.x), stroke(to_edge.y, seam, px.y)) * clear;
	float shade = 1.0;      // multiplied into the colour
	float rnd = hash(id + (wall ? vec2(0.0) : vec2(17.0, 5.0)));

	if (style == 0 || style == 1) {
		// Panels and tiles: seams, each panel a touch lighter or darker than the next,
		// and a thin light edge inside the seam.
		shade *= 1.0 + (rnd - 0.5) * 2.0 * vary * clear;
		float lip = max(stroke(abs(to_edge.x - seam * 2.5), seam * 0.8, px.x), stroke(abs(to_edge.y - seam * 2.5), seam * 0.8, px.y));
		shade *= 1.0 + lip * 0.05 * clear;
		if (wall && detail > 0.0) {
			float pick = hash(id + vec2(3.7, 9.1));
			vec2 inset = to_edge - vec2(0.32);
			if (pick < detail * 0.5 && cell.x > 1.2 && cell.y > 1.2) {
				// an access hatch: a thin frame set in from the seams, a little darker inside
				float inside = step(0.0, min(inset.x, inset.y));
				float frame = max(stroke(abs(inset.x), 0.012, px.x) * step(-0.012, inset.y), stroke(abs(inset.y), 0.012, px.y) * step(-0.012, inset.x));
				shade *= mix(1.0, 0.965, inside * clear);
				shade *= mix(1.0, seam_shade + 0.12, frame * clear);
			} else if (pick < detail && cell.y > 1.2) {
				// vent slots: a few short level slits across the middle of the panel
				float in_x = step(0.5, in_cell.x) * step(in_cell.x, cell.x - 0.5);
				float y = in_cell.y - cell.y * 0.5;
				float slot = stroke(abs(fract(y / 0.16 + 0.5) - 0.5) * 0.16, 0.022, px.y) * step(abs(y), 0.4);
				shade *= mix(1.0, seam_shade - 0.1, slot * in_x * clear_at(px, 0.16));
			}
		}
		shade *= mix(1.0, seam_shade, seams);
	} else if (style == 2) {
		// Plates: seams with a rivet in each corner.
		shade *= 1.0 + (rnd - 0.5) * 2.0 * vary * clear;
		float r = length(to_edge - vec2(0.14));
		float rivet = stroke(r, 0.035, max(px.x, px.y)) * clear_at(px, 0.3);
		shade *= mix(1.0, seam_shade, max(seams, rivet));
	} else if (style == 3) {
		// Grating: a fine mesh inside framed plates.
		float m = 0.2;
		vec2 f = abs(fract(p / m + 0.5) - 0.5) * m;
		float mesh = max(stroke(f.x, 0.03, px.x), stroke(f.y, 0.03, px.y));
		float fine = clear_at(px, m);
		shade *= mix(mix(1.0, 0.86, 1.0 - fine), seam_shade, mesh * fine);
		shade *= mix(1.0, seam_shade, max(stroke(to_edge.x, 0.04, px.x), stroke(to_edge.y, 0.04, px.y)) * clear);
	} else if (style == 4) {
		// Slats: level on a wall (a vent's louvres), across z on a floor or ceiling.
		float m = 0.14;
		float y = wall ? p.y : p.x;
		float ypx = wall ? px.y : px.x;
		float f = fract(y / m);
		float fine = clear_at(vec2(ypx), m);
		float dark = smoothstep(0.0, 0.25, f) * (1.0 - smoothstep(0.55, 0.62, f));   // each slat shades the gap under it
		shade *= mix(0.8, mix(1.15, 0.55, dark), fine);
	} else if (style == 5) {
		// Hazard stripes: slanted dark bands.
		float m = 0.7;
		float d = (p.x + p.y) / m;
		float f = abs(fract(d) - 0.5) * 2.0;                 // 0..1..0 across one stripe and gap
		float w = (px.x + px.y) / m;
		float band = smoothstep(0.5 - w, 0.5 + w, f);
		shade *= mix(1.0, 0.12, mix(0.5, band, clear_at(px, m)));
	} else if (style == 6) {
		// Treads: grip lines across a ramp (square to the way it slopes).
		vec2 down = n.xz;
		float slope = length(down);
		float d = slope > 0.05 ? dot(map_pos.xz, down / slope) : p.y;
		float dpx = fwidth(d);
		float m = 0.5;
		float f = abs(fract(d / m + 0.5) - 0.5) * m;
		shade *= mix(1.0, seam_shade, stroke(f, 0.04, dpx) * clear_at(vec2(dpx), m) * step(0.3, n.y));   // (the top only)
	} else {
		// Corrugated: upright ridges on the sides (a shipping container), plain on top.
		if (wall) {
			float m = 0.32;
			float f = fract(p.x / m);
			float fine = clear_at(px, m);
			float ridge = smoothstep(0.0, 0.18, f) * (1.0 - smoothstep(0.5, 0.68, f));
			shade *= mix(0.93, mix(0.8, 1.06, ridge), fine);
		}
		shade *= mix(1.0, seam_shade, seams * 0.6);
	}

	ALBEDO = albedo.rgb * COLOR.rgb * shade;
	ROUGHNESS = roughness;
}
