shader_type spatial;
// Patterns drawn on a map kind's surfaces without any extra blocks: panel seams on
// walls, tiles on floors, grating, vent slats, hazard stripes... A palette gives a
// kind one of these by name (MapPalette.surface; the names are in MapScenery.SURFACES).
//
// Everything is worked out from where the surface is in the map, in metres, so the
// pattern lines up across blocks, and it is the same on every copy of the game. (On a
// moving part it is worked out from where the surface is in that part: see vertex().) Walls
// are measured along the wall, whichever way it is turned, so seams always run level
// and upright. Lines are smoothed and fade out with distance, so nothing shimmers.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.85;
// 0 panels, 1 tiles, 2 plates (rivets), 3 grating, 4 slats, 5 hazard stripes, 6 treads, 7 corrugated,
// 8 bricks, 9 blocks (dressed stone), 10 cobbles, 11 planks, 12 mottle (grass, dirt, gravel),
// 13 windows (far-off buildings), 14 strata (cliffs), 15 confetti (arcade carpet), 16 water,
// 17 shingles (and thatch), 18 bark
uniform int style = 0;
uniform vec2 wall_cell = vec2(3.0, 2.0);    // a wall panel: width, height (m)
uniform vec2 floor_cell = vec2(2.0, 2.0);   // a floor or ceiling tile (m)
uniform float seam = 0.02;                  // half the width of a seam (m)
uniform float seam_shade = 0.6;             // how dark a seam is (1 = cannot be seen)
uniform float vary = 0.04;                  // how much one panel differs from the next
uniform float detail = 0.0;                 // panels: the share of wall panels with a hatch or vent slots;
                                            // mottle: fine speckle; windows: the share that are lit;
                                            // shingles: 1 = cut into tiles, 0 = unbroken rows (thatch)
uniform float checker = 0.0;                // tiles: how much darker every other tile is
uniform bool turn = false;                  // planks: boards run the other way (upright on a wall)
uniform vec3 lit : source_color = vec3(1.0, 0.85, 0.55);       // windows: the light in a lit one
uniform float lit_power = 0.0;              // windows, confetti: how brightly they shine
uniform vec3 accent_a : source_color = vec3(1.0, 0.25, 0.7);   // confetti: its three colours
uniform vec3 accent_b : source_color = vec3(0.2, 0.95, 1.0);
uniform vec3 accent_c : source_color = vec3(1.0, 0.86, 0.2);

varying vec3 map_pos;
varying vec3 map_normal;

void vertex() {
	if (UV2.x > 0.5) {
		// Part of something that moves (MapMesher.riding() marked it): the pattern is
		// measured in its own frame, so it travels with the block instead of standing
		// still in the map while the block slides through it.
		map_pos = VERTEX;
		map_normal = NORMAL;
	} else {
		map_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		map_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
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

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(41.3, 17.9)));
}

// Smooth noise, 0..1, one blob about every 1 unit.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Soft blotches of two sizes, -1..1.
float blotch(vec2 p, vec2 px, float size) {
	float a = (noise(p / size) - 0.5) * clear_at(px, size * 0.5);
	float b = (noise(p / (size * 0.29) + vec2(7.3, 2.9)) - 0.5) * clear_at(px, size * 0.15);
	return a * 1.3 + b * 0.7;
}

// Round stones (or clumps of leaves) of about `size` metres: x = metres to the gap
// round the stone the spot is on, y = that stone's own random number.
vec2 stones(vec2 p, float size) {
	vec2 g = p / size;
	vec2 gi = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 best = gi;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = gi + vec2(float(x), float(y));
			float d = length(g - (c + 0.5 + (hash2(c) - 0.5) * 0.72));
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = c;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2((d2 - d1) * 0.5 * size, hash(best + vec2(3.1, 8.7)));
}

// Where a jagged line of stone ends falls in a course: the edge near whole number k.
float joint(float k, float row) {
	return k + (hash(vec2(k, row)) - 0.5) * 0.56;
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
	vec3 paint = vec3(0.0); // a colour laid over the kind's own (confetti, lit windows)...
	float painted = 0.0;    // ...and how much of it
	vec3 shine = vec3(0.0); // light given off
	float rnd = hash(id + (wall ? vec2(0.0) : vec2(17.0, 5.0)));

	if (style == 0 || style == 1) {
		// Panels and tiles: seams, each panel a touch lighter or darker than the next,
		// and a thin light edge inside the seam.
		shade *= 1.0 + (rnd - 0.5) * 2.0 * vary * clear;
		float lip = max(stroke(abs(to_edge.x - seam * 2.5), seam * 0.8, px.x), stroke(abs(to_edge.y - seam * 2.5), seam * 0.8, px.y));
		shade *= 1.0 + lip * 0.05 * clear;
		if (style == 1 && checker > 0.0) {
			shade *= 1.0 - checker * mix(0.5, mod(id.x + id.y, 2.0), clear);
		}
		if (style == 0 && wall && detail > 0.0) {
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
	} else if (style == 8) {
		// Bricks: level rows, every other row shifted half a brick, mortar between.
		float row = floor(q.y);
		vec2 bq = vec2(q.x + 0.5 * mod(row, 2.0), q.y);
		vec2 bid = floor(bq);
		vec2 bin = (bq - bid) * cell;
		vec2 bedge = min(bin, cell - bin);
		float mortar = max(stroke(bedge.x, seam, px.x), stroke(bedge.y, seam, px.y));
		float cover = 2.0 * seam / cell.x + 2.0 * seam / cell.y;
		shade *= 1.0 + (hash(bid + vec2(11.0, 3.0)) - 0.5) * 2.0 * vary * clear;
		shade *= 1.0 + blotch(p, px, 5.0) * vary * 1.2;
		shade *= mix(1.0, seam_shade, mix(cover, mortar, clear));
	} else if (style == 9) {
		// Blocks: dressed stone in level courses, every block its own length and tone.
		float row = floor(q.y);
		float f = q.x + hash(vec2(row, 7.0)) * 5.0;
		float k = floor(f);
		float left = joint(k, row);
		float right = joint(k + 1.0, row);
		if (f < left) {
			right = left;
			k -= 1.0;
			left = joint(k, row);
		} else if (f >= right) {
			left = right;
			k += 1.0;
			right = joint(k + 1.0, row);
		}
		float ex = min(f - left, right - f) * cell.x;
		float ey = to_edge.y;
		float mortar = max(stroke(ex, seam, px.x), stroke(ey, seam, px.y));
		float cover = 2.0 * seam / cell.x + 2.0 * seam / cell.y;
		float tone = hash(vec2(k, row) + vec2(5.0, 13.0));
		shade *= 1.0 + (tone - 0.5) * 2.0 * vary * clear;
		shade *= 1.0 + blotch(p, px, 6.0) * vary;
		// a thin light edge on the upper side of each block, where the light catches it
		float lip = stroke(abs((cell.y - in_cell.y) - seam * 2.6), seam * 0.9, px.y);
		shade *= 1.0 + lip * 0.045 * clear;
		shade *= mix(1.0, seam_shade, mix(cover, mortar, clear));
	} else if (style == 10) {
		// Cobbles: round stones with dark gaps (seam_shade 1 = no gaps: clumps of leaves).
		float size = min(cell.x, cell.y);
		vec2 st = stones(p, size);
		float fine = clear_at(px, size);
		float gap = stroke(st.x, seam, max(px.x, px.y));
		float cover = min(4.0 * seam / size, 0.6);
		shade *= 1.0 + (st.y - 0.5) * 2.0 * vary * fine;
		shade *= 1.0 + blotch(p, px, 7.0) * vary * 0.8;
		// each stone is a little rounded: darker toward its edge
		shade *= 1.0 - (1.0 - smoothstep(0.0, size * 0.22, st.x)) * 0.07 * fine * step(seam_shade, 0.999);
		shade *= mix(1.0, seam_shade, mix(cover, gap, fine));
	} else if (style == 11) {
		// Planks: boards side by side, their ends staggered, each its own tone.
		vec2 pp = turn ? p.yx : p;
		vec2 ppx = turn ? px.yx : px;
		float width = cell.y;
		float len = cell.x;
		float row = floor(pp.y / width);
		float across = pp.y - row * width;
		float along = pp.x / len + hash(vec2(row, 3.0)) * 7.0;
		float board = floor(along);
		float to_end = min(along - board, board + 1.0 - along) * len;
		float fine = clear_at(ppx, width);
		float gaps = max(stroke(min(across, width - across), seam, ppx.y), stroke(to_end, seam, ppx.x));
		float cover = 2.0 * seam / width;
		shade *= 1.0 + (hash(vec2(board, row) + vec2(1.7, 9.2)) - 0.5) * 2.0 * vary * fine;
		// grain: faint streaks along the board
		float grain = noise(vec2(pp.x * 0.9 + row * 3.7, pp.y / width * 5.0)) - 0.5;
		shade *= 1.0 + grain * vary * 1.1 * clear_at(ppx, width * 0.25);
		shade *= mix(1.0, seam_shade, mix(cover, gaps, fine));
	} else if (style == 12) {
		// Mottle: soft blotches (grass, dirt, tarmac) and, with detail, a fine speckle (gravel).
		float size = cell.x;
		shade *= 1.0 + blotch(p, px, size) * vary * 2.0;
		if (detail > 0.0) {
			float grit = 0.09;
			float fine = (noise(p / grit) - 0.5) * 1.4 + (noise(p / (grit * 2.7) + vec2(3.3, 9.1)) - 0.5) * 0.9;
			shade *= 1.0 + fine * detail * clear_at(px, grit * 1.2);
		}
	} else if (style == 13) {
		// Windows: rows of them on the walls of far-off buildings, some lit.
		if (wall) {
			vec2 half_w = cell * vec2(0.27, 0.3);
			vec2 off = abs(in_cell - cell * 0.5) - half_w;       // below 0 = on the glass
			float glass = (1.0 - smoothstep(-px.x * 0.5, px.x * 0.5 + 0.0001, off.x)) * (1.0 - smoothstep(-px.y * 0.5, px.y * 0.5 + 0.0001, off.y));
			float cover = 0.54 * 0.6;
			float on = step(hash(id + vec2(2.3, 8.1)), detail);
			float bars = max(stroke(abs(in_cell.x - cell.x * 0.5), 0.05, px.x), stroke(abs(in_cell.y - cell.y * 0.5 - half_w.y * 0.2), 0.05, px.y));
			float pane = glass * (1.0 - bars * 0.8 * clear_at(px, 0.5));
			shade *= 1.0 + (rnd - 0.5) * 0.04 * clear;
			shade *= mix(1.0, seam_shade, mix(cover, pane, clear) * (1.0 - on * 0.5));
			// a pale sill under each window
			float sill = stroke(abs(in_cell.y - (cell.y * 0.5 - half_w.y - 0.07)), 0.07, px.y) * (1.0 - smoothstep(0.1, 0.1 + px.x + 0.0001, off.x));
			shade *= 1.0 + sill * 0.1 * clear;
			shine = lit * lit_power * mix(cover * detail, pane * on * (0.75 + 0.5 * hash(id + vec2(6.1, 1.2))), clear);
		}
	} else if (style == 14) {
		// Strata: a cliff in level beds of rock, each a little different, with cracks.
		if (wall) {
			float bed = cell.y;
			float h = p.y / bed + (noise(vec2(p.x * 0.11, 0.0)) - 0.5) * 1.4;
			float row = floor(h);
			float in_bed = (h - row) * bed;
			float fine = clear_at(px, bed);
			shade *= 1.0 + (hash(vec2(row, 4.0)) - 0.5) * 2.0 * vary * fine;
			shade *= mix(1.0, seam_shade, stroke(min(in_bed, bed - in_bed), seam, px.y) * fine * 0.8);
			// upright cracks, a few to each bed
			float cx = p.x / cell.x + hash(vec2(row, 9.0)) * 3.0;
			float ck = floor(cx);
			float at = (hash(vec2(ck, row)) * 0.6 + 0.2);
			float crack = stroke(abs(cx - ck - at) * cell.x, seam * 0.8, px.x) * step(hash(vec2(ck, row) + vec2(8.0, 2.0)), 0.6);
			shade *= mix(1.0, seam_shade + 0.1, crack * clear_at(px, cell.x * 0.5));
		}
		shade *= 1.0 + blotch(p, px, 4.0) * vary * 1.6;
	} else if (style == 15) {
		// Confetti: an arcade carpet. Small bright shapes scattered over it, one to a cell.
		float size = cell.x;
		vec2 g = p / size;
		vec2 c = floor(g);
		float pick = hash(c + vec2(4.4, 1.9));
		vec2 at = (g - c - 0.5 - (hash2(c) - 0.5) * 0.4) * size;      // metres from the shape's middle
		float ang = hash(c + vec2(9.7, 3.3)) * 6.2832;
		at = vec2(at.x * cos(ang) - at.y * sin(ang), at.x * sin(ang) + at.y * cos(ang));
		float w = max(px.x, px.y);
		float mark = 0.0;
		if (pick < 0.16) {
			mark = stroke(length(at), 0.07, w);                                   // a dot
		} else if (pick < 0.32) {
			mark = stroke(abs(length(at) - 0.13), 0.022, w);                      // a ring
		} else if (pick < 0.5) {
			mark = stroke(abs(at.y), 0.022, w) * stroke(abs(at.x), 0.17, w);      // a dash
		} else if (pick < 0.66) {
			float zig = abs(fract(at.x / 0.16) - 0.5) * 0.16 - 0.04;
			mark = stroke(abs(at.y - zig), 0.02, w) * stroke(abs(at.x), 0.22, w); // a zigzag
		} else if (pick < 0.8) {
			float tri = max(abs(at.x) * 0.866 + at.y * 0.5, -at.y) - 0.09;
			mark = stroke(abs(tri), 0.02, w);                                     // a triangle
		}
		float fine = clear_at(px, 0.22);
		float which = hash(c + vec2(2.2, 7.1));
		paint = which < 0.34 ? accent_a : (which < 0.67 ? accent_b : accent_c);
		painted = mark * fine * 0.9;
		shine = paint * painted * lit_power;
		shade *= 1.0 + blotch(p, px, 3.0) * vary * 2.0;
	} else if (style == 16) {
		// Water: slow ripples of light on top, streaks running down a fall.
		if (wall) {
			float fall = noise(vec2(p.x * 3.4, p.y * 0.5 + TIME * 2.2));
			shade *= 0.92 + fall * 0.3 * clear_at(px, 0.4);
		} else {
			vec2 wv = p * 1.1 + vec2(sin(p.y * 0.7 + TIME * 0.5), cos(p.x * 0.6 - TIME * 0.4)) * 0.6;
			float ripple = noise(wv + vec2(TIME * 0.25, 0.0)) * 0.6 + noise(wv * 2.3 - vec2(0.0, TIME * 0.3)) * 0.4;
			float fine = clear_at(px, 0.6);
			shade *= 1.0 + (smoothstep(0.52, 0.62, ripple) * 0.22 - 0.05) * fine;
		}
	} else if (style == 17) {
		// Shingles: rows of roof tiles down the slope, each row lapping the next (detail 0:
		// unbroken rows with streaks, for thatch).
		vec2 rp = p;
		if (n.y > 0.2 && n.y < 0.995) {
			vec3 down = normalize(vec3(0.0, -1.0, 0.0) + n * n.y);        // straight down the slope
			rp = vec2(dot(map_pos, cross(n, down)), dot(map_pos, down));
		}
		vec2 rpx = fwidth(rp);
		float row = floor(rp.y / cell.y);
		float t = rp.y / cell.y - row;                                    // 0 at the top of a row
		float fine = clear_at(rpx, cell.y);
		shade *= mix(0.93, mix(seam_shade, 1.04, smoothstep(0.0, 0.34, t)), fine);
		float along = rp.x / cell.x + 0.5 * mod(row, 2.0) + hash(vec2(row, 1.0)) * 0.3;
		float tile = floor(along);
		if (detail > 0.5) {
			shade *= 1.0 + (hash(vec2(tile, row)) - 0.5) * 2.0 * vary * fine;
			shade *= mix(1.0, seam_shade + 0.08, stroke(min(along - tile, tile + 1.0 - along) * cell.x, seam, rpx.x) * clear_at(rpx, min(cell.x, cell.y)));
		} else {
			shade *= 1.0 + (noise(vec2(rp.x * 7.0, rp.y * 0.8 + row * 3.1)) - 0.5) * 2.0 * vary * clear_at(rpx, 0.3);
		}
	} else if (style == 18) {
		// Bark: long upright ridges on the sides (a tree trunk, a rough post), blotches on top.
		if (wall) {
			float ridge = noise(vec2(p.x * 4.2, p.y * 0.45));
			float deep = smoothstep(0.52, 0.7, ridge);
			shade *= 1.0 - deep * (1.0 - seam_shade) * clear_at(px, 0.3);
			shade *= 1.0 + (noise(vec2(p.x * 0.9, p.y * 0.2 + 3.0)) - 0.5) * 2.0 * vary;
		} else {
			shade *= 1.0 + blotch(p, px, 1.2) * vary * 2.0;
		}
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

	ALBEDO = mix(albedo.rgb * COLOR.rgb * shade, paint, painted);
	EMISSION = shine;
	ROUGHNESS = roughness;
}
