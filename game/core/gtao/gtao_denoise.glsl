#[versions]

pass = "";
final = "#define FINAL_APPLY";

#[compute]
#version 450

#VERSION_DEFINES

// GTAO, step 3 of 3: smooths the noise out of step 2's result without blurring across
// edges (a 3x3 blur, weighted by the edges step 2 found; two passes make it about 5x5).
// The last pass ("final") gives the finished AO: at full resolution straight into the
// shared texture the map's surface shader reads (see Gtao), at half resolution for
// gtao_upsample.glsl.
//
// Ported to Godot's RenderingDevice from Intel's XeGTAO (XeGTAO_Denoise),
// https://github.com/GameTechDev/XeGTAO, which carries this notice:
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

// Each thread does two pixels side by side.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D src_ao;      // point sampling, clamped
layout(set = 0, binding = 1) uniform sampler2D src_edges;
layout(r8, set = 0, binding = 2) uniform restrict writeonly image2D out_ao;

layout(push_constant, std430) uniform Params {
	ivec2 size;
	vec2 pixel_size;
	float blur_beta;
	float pad0;
	float pad1;
	float pad2;
} pc;

#define OCCLUSION_TERM_SCALE 1.5

vec4 unpack_edges(float packed_val) {
	uint p = uint(packed_val * 255.5);
	vec4 e;
	e.x = float((p >> 6) & 3u) / 3.0;
	e.y = float((p >> 4) & 3u) / 3.0;
	e.z = float((p >> 2) & 3u) / 3.0;
	e.w = float((p >> 0) & 3u) / 3.0;
	return clamp(e, 0.0, 1.0);
}

void add_sample(float value, float weight, inout float sum, inout float sum_weight) {
	sum += weight * value;
	sum_weight += weight;
}

void main() {
	ivec2 base = ivec2(gl_GlobalInvocationID.xy) * ivec2(2, 1);

	if (base.y >= pc.size.y || base.x >= pc.size.x) {
		return;
	}

#ifdef FINAL_APPLY
	float blur_amount = pc.blur_beta;
#else
	float blur_amount = pc.blur_beta / 5.0;
#endif
	const float diag_weight = 0.85 * 0.5;

	vec2 gather_center = vec2(base) * pc.pixel_size;
	vec4 edges_q0 = textureGatherOffset(src_edges, gather_center, ivec2(0, 0));
	vec4 edges_q1 = textureGatherOffset(src_edges, gather_center, ivec2(2, 0));
	vec4 edges_q2 = textureGatherOffset(src_edges, gather_center, ivec2(1, 2));

	vec4 vis_q0 = textureGatherOffset(src_ao, gather_center, ivec2(0, 0));
	vec4 vis_q1 = textureGatherOffset(src_ao, gather_center, ivec2(2, 0));
	vec4 vis_q2 = textureGatherOffset(src_ao, gather_center, ivec2(0, 2));
	vec4 vis_q3 = textureGatherOffset(src_ao, gather_center, ivec2(2, 2));

	for (int side = 0; side < 2; side++) {
		ivec2 pix = ivec2(base.x + side, base.y);
		if (pix.x >= pc.size.x) {
			break;
		}

		vec4 edges_l = unpack_edges(side == 0 ? edges_q0.x : edges_q0.y);
		vec4 edges_t = unpack_edges(side == 0 ? edges_q0.z : edges_q1.w);
		vec4 edges_r = unpack_edges(side == 0 ? edges_q1.x : edges_q1.y);
		vec4 edges_b = unpack_edges(side == 0 ? edges_q2.w : edges_q2.z);
		vec4 edges_c = unpack_edges(side == 0 ? edges_q0.y : edges_q1.x);

		// Make the edges symmetrical (a left edge on one pixel is a right edge on the next).
		edges_c *= vec4(edges_l.y, edges_r.x, edges_t.w, edges_b.z);

		// Let a little AO leak in where there are 3 or 4 edges, so lone pixels do not stand out.
		const float leak_threshold = 2.5;
		const float leak_strength = 0.5;
		float edginess = (clamp(4.0 - leak_threshold - dot(edges_c, vec4(1.0)), 0.0, 1.0) / (4.0 - leak_threshold)) * leak_strength;
		edges_c = clamp(edges_c + edginess, 0.0, 1.0);

		float weight_tl = diag_weight * (edges_c.x * edges_l.z + edges_c.z * edges_t.x);
		float weight_tr = diag_weight * (edges_c.z * edges_t.y + edges_c.y * edges_r.z);
		float weight_bl = diag_weight * (edges_c.w * edges_b.x + edges_c.x * edges_l.w);
		float weight_br = diag_weight * (edges_c.y * edges_r.w + edges_c.w * edges_b.y);

		float v = side == 0 ? vis_q0.y : vis_q1.x;
		float v_l = side == 0 ? vis_q0.x : vis_q0.y;
		float v_t = side == 0 ? vis_q0.z : vis_q1.w;
		float v_r = side == 0 ? vis_q1.x : vis_q1.y;
		float v_b = side == 0 ? vis_q2.z : vis_q3.w;
		float v_tl = side == 0 ? vis_q0.w : vis_q0.z;
		float v_br = side == 0 ? vis_q3.w : vis_q3.z;
		float v_tr = side == 0 ? vis_q1.w : vis_q1.z;
		float v_bl = side == 0 ? vis_q2.w : vis_q2.z;

		float sum_weight = blur_amount;
		float sum = v * sum_weight;
		add_sample(v_l, edges_c.x, sum, sum_weight);
		add_sample(v_r, edges_c.y, sum, sum_weight);
		add_sample(v_t, edges_c.z, sum, sum_weight);
		add_sample(v_b, edges_c.w, sum, sum_weight);
		add_sample(v_tl, weight_tl, sum, sum_weight);
		add_sample(v_tr, weight_tr, sum, sum_weight);
		add_sample(v_bl, weight_bl, sum, sum_weight);
		add_sample(v_br, weight_br, sum, sum_weight);

		float ao = sum / sum_weight;
#ifdef FINAL_APPLY
		ao *= OCCLUSION_TERM_SCALE;
#endif
		imageStore(out_ao, pix, vec4(clamp(ao, 0.0, 1.0)));
	}
}
