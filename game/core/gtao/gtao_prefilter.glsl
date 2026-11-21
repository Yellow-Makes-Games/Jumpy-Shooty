#[compute]
#version 450

// GTAO, step 1 of 3: the depth buffer as distances from the camera, in metres, with four
// smaller copies (MIPs) that the main step reads its far-off samples from.
//
// Ported to Godot's RenderingDevice from Intel's XeGTAO (XeGTAO_PrefilterDepths16x16),
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

// Each thread takes 2x2 pixels, so a group of 8x8 covers 16x16.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D src_depth;   // Godot's depth buffer (reversed Z)
layout(r16f, set = 0, binding = 1) uniform restrict writeonly image2D out_depth0;
layout(r16f, set = 0, binding = 2) uniform restrict writeonly image2D out_depth1;
layout(r16f, set = 0, binding = 3) uniform restrict writeonly image2D out_depth2;
layout(r16f, set = 0, binding = 4) uniform restrict writeonly image2D out_depth3;
layout(r16f, set = 0, binding = 5) uniform restrict writeonly image2D out_depth4;

layout(push_constant, std430) uniform Params {
	ivec2 size;           // the view, in pixels
	vec2 depth_unpack;    // distance = x / (y - depth)
	float effect_radius;  // metres (already times the radius multiplier)
	float falloff_range;
	vec2 pad;
} pc;

shared float scratch[8][8];

float view_depth(ivec2 p) {
	float d = texelFetch(src_depth, clamp(p, ivec2(0), pc.size - 1), 0).r;
	return clamp(pc.depth_unpack.x / (pc.depth_unpack.y - d), 0.0, 65504.0);
}

// A weighted average that leans towards the nearer depths, so a small thing in front
// of a far wall is not lost in the smaller copies.
float mip_filter(float d0, float d1, float d2, float d3) {
	float far_d = max(max(d0, d1), max(d2, d3));
	float radius = 0.75 * pc.effect_radius;   // XeGTAO's depthRangeScaleFactor
	float falloff = pc.falloff_range * radius;
	float from = radius * (1.0 - pc.falloff_range);
	float mul = -1.0 / falloff;
	float add = from / falloff + 1.0;
	float w0 = clamp((far_d - d0) * mul + add, 0.0, 1.0);
	float w1 = clamp((far_d - d1) * mul + add, 0.0, 1.0);
	float w2 = clamp((far_d - d2) * mul + add, 0.0, 1.0);
	float w3 = clamp((far_d - d3) * mul + add, 0.0, 1.0);
	return (w0 * d0 + w1 * d1 + w2 * d2 + w3 * d3) / (w0 + w1 + w2 + w3);
}

// Writes only inside the image (a MIP is not always exactly half the size above it).
#define put(img, p, v) if (all(lessThan(p, imageSize(img)))) { imageStore(img, p, vec4(v)); }

void main() {
	ivec2 base = ivec2(gl_GlobalInvocationID.xy);
	ivec2 gt = ivec2(gl_LocalInvocationID.xy);
	ivec2 pix = base * 2;

	float d0 = view_depth(pix);
	float d1 = view_depth(pix + ivec2(1, 0));
	float d2 = view_depth(pix + ivec2(0, 1));
	float d3 = view_depth(pix + ivec2(1, 1));
	put(out_depth0, pix, d0);
	put(out_depth0, pix + ivec2(1, 0), d1);
	put(out_depth0, pix + ivec2(0, 1), d2);
	put(out_depth0, pix + ivec2(1, 1), d3);

	float dm1 = mip_filter(d0, d1, d2, d3);
	put(out_depth1, base, dm1);
	scratch[gt.x][gt.y] = dm1;
	memoryBarrierShared();
	barrier();

	if (gt.x % 2 == 0 && gt.y % 2 == 0) {
		float dm2 = mip_filter(scratch[gt.x][gt.y], scratch[gt.x + 1][gt.y], scratch[gt.x][gt.y + 1], scratch[gt.x + 1][gt.y + 1]);
		put(out_depth2, base / 2, dm2);
		scratch[gt.x][gt.y] = dm2;
	}
	memoryBarrierShared();
	barrier();

	if (gt.x % 4 == 0 && gt.y % 4 == 0) {
		float dm3 = mip_filter(scratch[gt.x][gt.y], scratch[gt.x + 2][gt.y], scratch[gt.x][gt.y + 2], scratch[gt.x + 2][gt.y + 2]);
		put(out_depth3, base / 4, dm3);
		scratch[gt.x][gt.y] = dm3;
	}
	memoryBarrierShared();
	barrier();

	if (gt.x % 8 == 0 && gt.y % 8 == 0) {
		float dm4 = mip_filter(scratch[gt.x][gt.y], scratch[gt.x + 4][gt.y], scratch[gt.x][gt.y + 4], scratch[gt.x + 4][gt.y + 4]);
		put(out_depth4, base / 8, dm4);
	}
}
