#[versions]

low = "#define SLICE_COUNT 1.0\n#define STEPS_PER_SLICE 2.0";
medium = "#define SLICE_COUNT 2.0\n#define STEPS_PER_SLICE 2.0";
high = "#define SLICE_COUNT 3.0\n#define STEPS_PER_SLICE 3.0";
ultra = "#define SLICE_COUNT 9.0\n#define STEPS_PER_SLICE 3.0";

#[compute]
#version 450

#VERSION_DEFINES

// GTAO, step 2 of 3: how much of the sky each pixel can see. For a few directions
// round the pixel ("slices") it walks out across the screen both ways, finds the
// highest point that blocks the view each way (the horizon) and works out how much of
// the half-sphere above the surface is left open. Also notes, for the denoiser, where
// the depth jumps between neighbouring pixels (edges it must not blur across).
//
// Ported to Godot's RenderingDevice from Intel's XeGTAO (XeGTAO_MainPass and
// XeGTAO_ComputeViewspaceNormal), https://github.com/GameTechDev/XeGTAO, which carries
// this notice:
//
// Copyright (C) 2016-2021, Intel Corporation
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the Software
// without restriction, including without limitation the rights to use, copy, modify,
// merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be included in all copies
// or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
// OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Space here is XeGTAO's, not Godot's: x right, y up, z the distance in front of the
// camera (positive). Everything, normals included, is worked out from the depth buffer
// in that one space, so the handedness never has to be turned round.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D src_depth;    // Godot's depth buffer (reversed Z), full precision
layout(set = 0, binding = 1) uniform sampler2D depth_mips;   // from step 1: distances, 5 MIPs
layout(r8, set = 0, binding = 2) uniform restrict writeonly image2D out_ao;
layout(r8, set = 0, binding = 3) uniform restrict writeonly image2D out_edges;

layout(push_constant, std430) uniform Params {
	ivec2 size;
	vec2 pixel_size;          // 1 / size
	vec2 depth_unpack;        // distance = x / (y - depth)
	vec2 ndc_to_view_mul;     // view xy = (mul * uv + add) * distance
	vec2 ndc_to_view_add;
	vec2 ndc_to_view_mul_x_pixel_size;
	float effect_radius;      // metres (already times the radius multiplier)
	float falloff_range;
	float stride;             // 1: full resolution; 2: half (one pixel in each 2x2, see below)
	float pad;
	float final_value_power;
	float depth_mip_sampling_offset;
	float fade_from;          // metres: AO fades out from here...
	float fade_to;            // ...to nothing here
} pc;

#define PI 3.1415926535897932384626433832795
#define PI_HALF 1.5707963267948966192313216916398
#define DEPTH_MIP_LEVELS 5.0
// The raw term can go a little over 1 before the denoiser averages it; stored divided by this.
#define OCCLUSION_TERM_SCALE 1.5

float raw_distance(ivec2 p) {
	float d = texelFetch(src_depth, clamp(p, ivec2(0), pc.size - 1), 0).r;
	return pc.depth_unpack.x / (pc.depth_unpack.y - d);
}

vec3 view_position(vec2 uv, float z) {
	return vec3((pc.ndc_to_view_mul * uv + pc.ndc_to_view_add) * z, z);
}

vec4 calculate_edges(float c, float l, float r, float t, float b) {
	vec4 e = vec4(l, r, t, b) - c;
	float slope_lr = (e.y - e.x) * 0.5;
	float slope_tb = (e.w - e.z) * 0.5;
	vec4 e_slope = e + vec4(slope_lr, -slope_lr, slope_tb, -slope_tb);
	e = min(abs(e), abs(e_slope));
	return clamp(1.25 - e / (c * 0.011), 0.0, 1.0);
}

// 2 bits per edge: 0, 1/3, 2/3 or 1.
float pack_edges(vec4 e) {
	e = round(clamp(e, 0.0, 1.0) * 2.9);
	return dot(e, vec4(64.0 / 255.0, 16.0 / 255.0, 4.0 / 255.0, 1.0 / 255.0));
}

vec3 calculate_normal(vec4 e, vec3 c, vec3 l, vec3 r, vec3 t, vec3 b) {
	vec4 accepted = clamp(vec4(e.x * e.z, e.z * e.y, e.y * e.w, e.w * e.x) + 0.01, 0.0, 1.0);
	l = normalize(l - c);
	r = normalize(r - c);
	t = normalize(t - c);
	b = normalize(b - c);
	vec3 n = accepted.x * cross(l, t) + accepted.y * cross(t, r) + accepted.z * cross(r, b) + accepted.w * cross(b, l);
	return normalize(n);
}

float fast_sqrt(float x) {
	return intBitsToFloat(0x1fbd1df5 + (floatBitsToInt(x) >> 1));
}

// [-1, 1] -> [0, PI]
float fast_acos(float x_in) {
	float x = abs(x_in);
	float res = -0.156583 * x + PI_HALF;
	res *= fast_sqrt(1.0 - x);
	return x_in >= 0.0 ? res : PI - res;
}

// A 64x64 tile of well spread numbers: a Hilbert curve through the tile drives the R2
// sequence. There is no TAA to spread the noise over frames, so it stays put
// (XeGTAO's temporal index 0) and the denoiser smooths it.
uint hilbert_index(uint x, uint y) {
	uint index = 0u;
	for (uint level = 32u; level > 0u; level /= 2u) {
		uint rx = (x & level) > 0u ? 1u : 0u;
		uint ry = (y & level) > 0u ? 1u : 0u;
		index += level * level * ((3u * rx) ^ ry);
		if (ry == 0u) {
			if (rx == 1u) {
				x = 63u - x;
				y = 63u - y;
			}
			uint tmp = x;
			x = y;
			y = tmp;
		}
	}
	return index;
}

vec2 spatial_noise(uvec2 pix) {
	uint index = hilbert_index(pix.x % 64u, pix.y % 64u);
	return fract(0.5 + float(index) * vec2(0.75487766624669276005, 0.5698402909980532659114));
}

void main() {
	// At half resolution each output pixel q stands for the top-left pixel of its 2x2
	// (pix = 2q): its AO is worked out exactly there, at full precision, and
	// gtao_upsample.glsl fills in the other three from the nearest of these that lie on
	// the same surface.
	ivec2 q = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(q, imageSize(out_ao)))) {
		return;
	}
	int stride = int(pc.stride);
	ivec2 pix = min(q * stride, pc.size - 1);
	vec2 uv = (vec2(pix) + 0.5) * pc.pixel_size;

	// The pixel and its four neighbours at full precision: the surface normal...
	float zc = raw_distance(pix);
	float zl = raw_distance(pix + ivec2(-1, 0));
	float zr = raw_distance(pix + ivec2(1, 0));
	float zt = raw_distance(pix + ivec2(0, -1));
	float zb = raw_distance(pix + ivec2(0, 1));
	vec4 edges = calculate_edges(zc, zl, zr, zt, zb);
	vec3 c_pos = view_position(uv, zc);
	vec3 normal = calculate_normal(edges, c_pos,
		view_position(uv + vec2(-1.0, 0.0) * pc.pixel_size, zl),
		view_position(uv + vec2(1.0, 0.0) * pc.pixel_size, zr),
		view_position(uv + vec2(0.0, -1.0) * pc.pixel_size, zt),
		view_position(uv + vec2(0.0, 1.0) * pc.pixel_size, zb));
	// ...and the edges the denoiser keeps to, between this output pixel and the next ones.
	if (stride > 1) {
		edges = calculate_edges(zc, raw_distance(pix + ivec2(-stride, 0)), raw_distance(pix + ivec2(stride, 0)),
			raw_distance(pix + ivec2(0, -stride)), raw_distance(pix + ivec2(0, stride)));
	}
	imageStore(out_edges, q, vec4(pack_edges(edges)));

	if (zc >= pc.fade_to) {
		// Too far off to matter (or the sky): fully open.
		imageStore(out_ao, q, vec4(1.0 / OCCLUSION_TERM_SCALE));
		return;
	}

	// Nudged towards the camera: the samples come from 16-bit copies, and without this a
	// flat surface would shade itself where their rounding lands in front of it.
	float view_z = zc * 0.9992;
	vec3 pix_center = view_position(uv, view_z);
	vec3 view_vec = normalize(-pix_center);

	float effect_radius = pc.effect_radius;
	float falloff_range = pc.falloff_range * effect_radius;
	float falloff_from = effect_radius * (1.0 - pc.falloff_range);
	float falloff_mul = -1.0 / falloff_range;
	float falloff_add = falloff_from / falloff_range + 1.0;

	float visibility = 0.0;
	vec2 noise = spatial_noise(uvec2(q));
	float noise_slice = noise.x;
	float noise_sample = noise.y;

	const float pixel_too_close_threshold = 1.3;
	vec2 pixel_dir_rb_viewspace_size = view_z * pc.ndc_to_view_mul_x_pixel_size;
	float screenspace_radius = effect_radius / pixel_dir_rb_viewspace_size.x;
	// fade out for small screen radii
	visibility += clamp((10.0 - screenspace_radius) / 100.0, 0.0, 1.0) * 0.5;
	float min_s = pixel_too_close_threshold / screenspace_radius;

	for (float slice = 0.0; slice < SLICE_COUNT; slice++) {
		float slice_k = (slice + noise_slice) / SLICE_COUNT;
		float phi = slice_k * PI;
		float cos_phi = cos(phi);
		float sin_phi = sin(phi);
		vec2 omega = vec2(cos_phi, -sin_phi) * screenspace_radius;   // in pixels; screen y runs down

		vec3 direction_vec = vec3(cos_phi, sin_phi, 0.0);
		vec3 ortho_direction_vec = direction_vec - dot(direction_vec, view_vec) * view_vec;
		vec3 axis_vec = normalize(cross(ortho_direction_vec, view_vec));
		vec3 projected_normal_vec = normal - axis_vec * dot(normal, axis_vec);
		float sign_norm = sign(dot(ortho_direction_vec, projected_normal_vec));
		float projected_normal_vec_length = length(projected_normal_vec);
		float cos_norm = clamp(dot(projected_normal_vec, view_vec) / projected_normal_vec_length, 0.0, 1.0);
		float n = sign_norm * fast_acos(cos_norm);

		float low_horizon_cos0 = cos(n + PI_HALF);
		float low_horizon_cos1 = cos(n - PI_HALF);
		float horizon_cos0 = low_horizon_cos0;
		float horizon_cos1 = low_horizon_cos1;

		for (float s_step = 0.0; s_step < STEPS_PER_SLICE; s_step++) {
			float step_base_noise = (slice + s_step * STEPS_PER_SLICE) * 0.6180339887498948482;
			float step_noise = fract(noise_sample + step_base_noise);
			float s = (s_step + step_noise) / STEPS_PER_SLICE;
			s = s * s;   // XeGTAO's sample distribution power, 2: more samples near the pixel, where small creases are
			s += min_s;

			vec2 sample_offset = s * omega;
			float sample_offset_length = length(sample_offset);
			float mip_level = clamp(log2(sample_offset_length) - pc.depth_mip_sampling_offset, 0.0, DEPTH_MIP_LEVELS);
			sample_offset = round(sample_offset) * pc.pixel_size;

			vec2 sample_screen_pos0 = uv + sample_offset;
			float sz0 = textureLod(depth_mips, sample_screen_pos0, mip_level).r;
			vec3 sample_pos0 = view_position(sample_screen_pos0, sz0);
			vec2 sample_screen_pos1 = uv - sample_offset;
			float sz1 = textureLod(depth_mips, sample_screen_pos1, mip_level).r;
			vec3 sample_pos1 = view_position(sample_screen_pos1, sz1);

			vec3 sample_delta0 = sample_pos0 - pix_center;
			vec3 sample_delta1 = sample_pos1 - pix_center;
			float sample_dist0 = length(sample_delta0);
			float sample_dist1 = length(sample_delta1);
			vec3 sample_horizon_vec0 = sample_delta0 / sample_dist0;
			vec3 sample_horizon_vec1 = sample_delta1 / sample_dist1;

			// Samples beyond the radius count for less, then nothing.
			float falloff_base0 = sample_dist0;   // (XeGTAO's thin occluder compensation is 0 by default)
			float falloff_base1 = sample_dist1;
			float weight0 = clamp(falloff_base0 * falloff_mul + falloff_add, 0.0, 1.0);
			float weight1 = clamp(falloff_base1 * falloff_mul + falloff_add, 0.0, 1.0);

			float shc0 = dot(sample_horizon_vec0, view_vec);
			float shc1 = dot(sample_horizon_vec1, view_vec);
			shc0 = mix(low_horizon_cos0, shc0, weight0);
			shc1 = mix(low_horizon_cos1, shc1, weight1);
			horizon_cos0 = max(horizon_cos0, shc0);
			horizon_cos1 = max(horizon_cos1, shc1);
		}

		// XeGTAO's fudge for slight over-darkening on steep slopes.
		projected_normal_vec_length = mix(projected_normal_vec_length, 1.0, 0.05);

		float h0 = -fast_acos(horizon_cos1);
		float h1 = fast_acos(horizon_cos0);
		float iarc0 = (cos_norm + 2.0 * h0 * sin(n) - cos(2.0 * h0 - n)) / 4.0;
		float iarc1 = (cos_norm + 2.0 * h1 * sin(n) - cos(2.0 * h1 - n)) / 4.0;
		visibility += projected_normal_vec_length * (iarc0 + iarc1);
	}
	visibility /= SLICE_COUNT;
	visibility = pow(visibility, pc.final_value_power);
	visibility = max(0.03, visibility);   // never fully black: the pixel can be seen, after all

	// Fade out with distance, as Godot's own SSAO does.
	visibility = mix(visibility, 1.0, smoothstep(pc.fade_from, pc.fade_to, zc));

	imageStore(out_ao, q, vec4(clamp(visibility / OCCLUSION_TERM_SCALE, 0.0, 1.0)));
}
