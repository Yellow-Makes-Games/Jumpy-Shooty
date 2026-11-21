#[compute]
#version 450

// GTAO at half resolution, last step: the AO for every pixel, from the half-resolution
// result, into the shared texture the map's surface shader reads (see Gtao).
//
// Half-resolution pixel q was worked out exactly at full-resolution pixel 2q. Each
// thread fills one 2x2 block: 2q itself takes q's AO; the other three lie between q and
// its neighbours to the right and below, and take theirs, but only from those on the
// same surface: a neighbour whose depth is much further from this pixel's than the
// nearest one's is left out. On a flat or sloping surface every neighbour is about as
// near and all of them count; at the edge of a wall or a robot the ones beyond the
// edge drop out. So AO never bleeds across an edge, and edges stay as sharp as the
// picture (no blocks, no halo), without having to look at more pixels.
//
// This step is the project's own (XeGTAO runs at full resolution; its notes suggest
// half resolution with a bilateral upsample for anything cheaper).

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth0;      // distances (step 1's full-size MIP)
layout(set = 0, binding = 1) uniform sampler2D half_ao;     // finished AO at half resolution (clamped sampler)
layout(r8, set = 0, binding = 2) uniform restrict writeonly image2D out_ao;

layout(push_constant, std430) uniform Params {
	ivec2 size;           // full resolution
	ivec2 half_size;
	vec4 pad;
} pc;

float distance_at(ivec2 p) {
	return texelFetch(depth0, min(p, pc.size - 1), 0).r;
}

void put(ivec2 p, float ao) {
	if (all(lessThan(p, pc.size))) {
		imageStore(out_ao, p, vec4(ao));
	}
}

// The AO at a pixel of depth z, from samples of depths zs and AO aos, with weights w.
float blend(float z, vec4 zs, vec4 aos, vec4 w) {
	vec4 dz = abs(zs - z);
	// Ignore the samples with no weight here when finding the nearest.
	vec4 dz_used = mix(vec4(1e30), dz, step(1e-6, w));
	float nearest = min(min(dz_used.x, dz_used.y), min(dz_used.z, dz_used.w));
	float tolerance = 2.0 * nearest + 0.01 * z;
	w *= vec4(1.0) - smoothstep(vec4(tolerance), vec4(tolerance * 1.5), dz);
	return dot(aos, w) / max(dot(w, vec4(1.0)), 1e-6);
}

void main() {
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(q, pc.half_size))) {
		return;
	}
	ivec2 b = q * 2;
	// The four samples round this block: here, right, below, below right.
	vec4 zs = vec4(distance_at(b), distance_at(b + ivec2(2, 0)), distance_at(b + ivec2(0, 2)), distance_at(b + ivec2(2, 2)));
	// (A gather between q and q + (1, 1): x = below, y = below right, z = right, w = q.)
	vec4 g = textureGather(half_ao, vec2(q + 1) / vec2(pc.half_size));
	vec4 aos = vec4(g.w, g.z, g.x, g.y);

	put(b, aos.x);
	put(b + ivec2(1, 0), blend(distance_at(b + ivec2(1, 0)), zs, aos, vec4(0.5, 0.5, 0.0, 0.0)));
	put(b + ivec2(0, 1), blend(distance_at(b + ivec2(0, 1)), zs, aos, vec4(0.5, 0.0, 0.5, 0.0)));
	put(b + ivec2(1, 1), blend(distance_at(b + ivec2(1, 1)), zs, aos, vec4(0.25)));
}
