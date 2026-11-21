///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2018, Intel Corporation
//
// Licensed under the Apache License, Version 2.0 ( the "License" );
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Conservative Morphological Anti-Aliasing, version: 2.3
//
// Author(s):       Filip Strugar (filip.strugar@intel.com)
//
// More info:       https://github.com/GameTechDev/CMAA2
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// MODIFIED by the Jumpy Shooty project (2026): this file is a port of CMAA2.hlsl (commit 071c6b0) to GLSL for
// Godot's RenderingDevice, used by game/core/cmaa2/cmaa2_effect.gd. The full licence is in LICENSE.txt beside it.
// What changed from the original:
//  - HLSL to GLSL; the four kernels are the #[versions] of this one file.
//  - Fixed to these paths of the original: one sample (no MSAA path: it runs on Godot's resolved colour),
//    luma edge detection computed in place (CMAA2_EDGE_DETECTION_LUMA_PATH 1), HIGH quality preset, no extra
//    sharpness, the colour buffer's full HDR range (CMAA2_SUPPORT_HDR_COLOR_RANGE 1), edges packed two pixels to
//    a byte, blend items collected in shared memory.
//  - The colour stored for each blend item is four half floats (packHalf2x16) instead of R11G11B10: the full
//    HDR range as the HDR path wants, and alpha too, which is blended with the colour so a picture drawn on a
//    clear background (the menus' 3D pictures) keeps its edges right.
//  - The list heads are a storage buffer rather than an R32_UINT texture.
//  - Reads outside the picture are clamped to its edge pixels and writes outside it are skipped (HLSL reads
//    zero and drops the write); every write into a working buffer is checked against the buffer's length.
//  - A shared-memory blend item slot that a thread reserved but could not fill is marked empty and skipped.
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#[versions]

edges = "#define CMAA2_EDGES";
args = "#define CMAA2_DISPATCH_ARGS";
process = "#define CMAA2_PROCESS_CANDIDATES";
apply = "#define CMAA2_DEFERRED_APPLY";

#[compute]

#version 450

#VERSION_DEFINES

#define CMAA2_CS_INPUT_KERNEL_SIZE_X 16
#define CMAA2_CS_INPUT_KERNEL_SIZE_Y 16
#define CMAA2_CS_OUTPUT_KERNEL_SIZE_X (CMAA2_CS_INPUT_KERNEL_SIZE_X - 2)
#define CMAA2_CS_OUTPUT_KERNEL_SIZE_Y (CMAA2_CS_INPUT_KERNEL_SIZE_Y - 2)
#define CMAA2_PROCESS_CANDIDATES_NUM_THREADS 128
#define CMAA2_DEFERRED_APPLY_NUM_THREADS 32
#define CMAA2_BLEND_ITEM_SLM_SIZE 768

// Longest line search distance; must be an even number, at most 128.
const float c_maxLineLength = 86.0;

// HIGH preset (CMAA2_STATIC_QUALITY_PRESET 2), CMAA2_EXTRA_SHARPNESS 0.
#define g_CMAA2_EdgeThreshold 0.07
#define g_CMAA2_LocalContrastAdaptationAmount 0.10
#define g_CMAA2_SimpleShapeBlurinessAmount 0.10

// blendZ settings, determined empirically (CMAA2_EXTRA_SHARPNESS 0).
const float c_symmetryCorrectionOffset = 0.22;
const float c_dampeningEffect = 0.15;

const uint EMPTY = 0xFFFFFFFFu;
const float HALF_MAX = 65504.0;

// The control buffer's slots (the original's byte offsets / 4).
#define CTRL_COUNT 3          // items for the indirect dispatch running now
#define CTRL_CANDIDATES 4     // shape candidates found by the edge pass
#define CTRL_LOCATIONS 8      // 2x2 quads with something to blend
#define CTRL_ITEMS 12         // blend items stored

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Resources. Each pass declares only what it uses (the effect builds each pass's uniform set to match).

#if defined(CMAA2_EDGES) || defined(CMAA2_PROCESS_CANDIDATES)
layout(set = 0, binding = 0) uniform sampler2D g_inoutColorReadonly;
#endif

#ifdef CMAA2_DEFERRED_APPLY
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D g_inoutColorWriteonly;
#endif

#ifdef CMAA2_EDGES
layout(r8ui, set = 0, binding = 2) uniform restrict writeonly uimage2D g_workingEdges;
#endif
#ifdef CMAA2_PROCESS_CANDIDATES
layout(r8ui, set = 0, binding = 2) uniform restrict readonly uimage2D g_workingEdges;
#endif

#if defined(CMAA2_EDGES) || defined(CMAA2_DISPATCH_ARGS) || defined(CMAA2_PROCESS_CANDIDATES)
layout(set = 0, binding = 3, std430) restrict buffer ShapeCandidates {
	uint data[];
} g_workingShapeCandidates;
#endif

#if defined(CMAA2_DISPATCH_ARGS) || defined(CMAA2_PROCESS_CANDIDATES) || defined(CMAA2_DEFERRED_APPLY)
layout(set = 0, binding = 4, std430) restrict buffer DeferredBlendLocationList {
	uint data[];
} g_workingDeferredBlendLocationList;
#endif

#if defined(CMAA2_PROCESS_CANDIDATES) || defined(CMAA2_DEFERRED_APPLY)
// Three uints an item: the next item's index (with its header), then rgba as two packHalf2x16.
layout(set = 0, binding = 5, std430) restrict buffer DeferredBlendItemList {
	uint data[];
} g_workingDeferredBlendItemList;
#endif

#if defined(CMAA2_EDGES) || defined(CMAA2_PROCESS_CANDIDATES) || defined(CMAA2_DEFERRED_APPLY)
// One linked list head per 2x2 quad, row by row ((width + 1) / 2 a row).
layout(set = 0, binding = 6, std430) restrict buffer DeferredBlendItemListHeads {
	uint data[];
} g_workingDeferredBlendItemListHeads;
#endif

layout(set = 0, binding = 7, std430) restrict buffer ControlBuffer {
	uint data[];
} g_workingControlBuffer;

#ifdef CMAA2_DISPATCH_ARGS
layout(set = 0, binding = 8, std430) restrict writeonly buffer ExecuteIndirectBuffer {
	uint data[];
} g_workingExecuteIndirectBuffer;
#endif

// The same push constant in every pass. The buffers' lengths come in here rather than from
// .length(), which not every part of Godot's shader pipeline supports.
layout(push_constant, std430) uniform Params {
	ivec2 size;              // the colour image's size in pixels
	int heads_width;         // list heads a row: (size.x + 1) / 2
	uint candidates_length;  // entries in g_workingShapeCandidates
	uint locations_length;   // entries in g_workingDeferredBlendLocationList
	uint items_length;       // items (3 uints each) in g_workingDeferredBlendItemList
	uint pad0;
	uint pad1;
} params;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// encoding/decoding of various data such as edges
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// how .rgba channels from the edge texture maps to pixel edges:
//
//                   A - 0x08               (A - there's an edge between us and a pixel above us)
//              |---------|                 (R - there's an edge between us and a pixel to the right)
//              |         |                 (G - there's an edge between us and a pixel at the bottom)
//     0x04 - B |  pixel  | R - 0x01        (B - there's an edge between us and a pixel to the left)
//              |         |
//              |_________|
//                   G - 0x02
uint PackEdges(vec4 edges) { // input edges are binary 0 or 1
	return uint(dot(edges, vec4(1.0, 2.0, 4.0, 8.0)));
}

vec4 UnpackEdgesFlt(uint value) {
	return vec4(bvec4((value & 0x01u) != 0u, (value & 0x02u) != 0u, (value & 0x04u) != 0u, (value & 0x08u) != 0u));
}

#ifndef CMAA2_DISPATCH_ARGS
bool InPicture(ivec2 pixelPos) {
	return all(greaterThanEqual(pixelPos, ivec2(0))) && all(lessThan(pixelPos, params.size));
}
#endif

#if defined(CMAA2_EDGES) || defined(CMAA2_PROCESS_CANDIDATES)
vec4 LoadSourceColor(ivec2 pixelPos, ivec2 offset) {
	return texelFetch(g_inoutColorReadonly, clamp(pixelPos + offset, ivec2(0), params.size - 1), 0);
}
#endif

#ifdef CMAA2_PROCESS_CANDIDATES
uint LoadEdge(ivec2 pixelPos, ivec2 offset) {
	ivec2 p = pixelPos + offset;
	if (!InPicture(p)) {
		return 0u;
	}
	uint a = uint(p.x) % 2u;
	uint edge = imageLoad(g_workingEdges, ivec2(p.x / 2, p.y)).x;
	return (edge >> (a * 4u)) & 0xFu;
}

uint InternalPackCount() {
	return params.items_length;
}

void StoreColorSample(ivec2 pixelPos, vec4 color, bool isComplexShape) {
	if (!InPicture(pixelPos)) {
		return;
	}
	uint counterIndex = atomicAdd(g_workingControlBuffer.data[CTRL_ITEMS], 1u);
	if (counterIndex >= InternalPackCount() || counterIndex >= (1u << 26)) {
		return;
	}

	// quad coordinates
	uvec2 quadPos = uvec2(pixelPos) / 2u;
	// 2x2 inter-quad coordinates
	uint offsetXY = (uint(pixelPos.y) % 2u) * 2u + (uint(pixelPos.x) % 2u);
	// encode item-specific info: {2 bits for 2x2 quad location}, {3 bits for MSAA sample index}, {1 bit for isComplexShape flag}, {26 bits left for address (index)}
	uint header = (offsetXY << 30) | (uint(isComplexShape) << 26);

	uint counterIndexWithHeader = counterIndex | header;

	uint originalIndex = atomicExchange(g_workingDeferredBlendItemListHeads.data[quadPos.y * uint(params.heads_width) + quadPos.x], counterIndexWithHeader);
	color = clamp(color, vec4(-HALF_MAX), vec4(HALF_MAX));
	g_workingDeferredBlendItemList.data[counterIndex * 3u + 0u] = originalIndex;
	g_workingDeferredBlendItemList.data[counterIndex * 3u + 1u] = packHalf2x16(color.rg);
	g_workingDeferredBlendItemList.data[counterIndex * 3u + 2u] = packHalf2x16(color.ba);

	// First one added?
	if (originalIndex == EMPTY) {
		// Make a list of all edge pixels - these cover all potential pixels where AA is applied.
		uint edgeListCounter = atomicAdd(g_workingControlBuffer.data[CTRL_LOCATIONS], 1u);
		if (edgeListCounter < params.locations_length) {
			g_workingDeferredBlendLocationList.data[edgeListCounter] = (quadPos.x << 16) | quadPos.y;
		}
	}
}
#endif

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Edge detection compute shader
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef CMAA2_EDGES

// color -> luma-for-edges conversion: what original FXAA (and consequently CMAA2) use by default; Rec. 601
// coefficients on (roughly) gamma-compressed components.
float RGBToLumaForEdges(vec3 linearRGB) {
	return dot(sqrt(max(linearRGB, vec3(0.0))), vec3(0.299, 0.587, 0.114));
}

vec2 ComputeEdgeLuma(int x, int y, float pixelLumas[3 * 3 - 1]) {
	vec2 temp;
	temp.x = abs(pixelLumas[x + y * 3] - pixelLumas[x + 1 + y * 3]);
	temp.y = abs(pixelLumas[x + y * 3] - pixelLumas[x + (y + 1) * 3]);
	return temp;
}

float ComputeLocalContrastV(int x, int y, vec2 neighbourhood[4][4]) {
	// new, small kernel 4-connecting-edges-only local contrast adaptation
	return max(max(neighbourhood[x + 1][y + 0].y, neighbourhood[x + 1][y + 1].y), max(neighbourhood[x + 2][y + 0].y, neighbourhood[x + 2][y + 1].y)) * g_CMAA2_LocalContrastAdaptationAmount;
}

float ComputeLocalContrastH(int x, int y, vec2 neighbourhood[4][4]) {
	// new, small kernel 4-connecting-edges-only local contrast adaptation
	return max(max(neighbourhood[x + 0][y + 1].x, neighbourhood[x + 1][y + 1].x), max(neighbourhood[x + 0][y + 2].x, neighbourhood[x + 1][y + 2].x)) * g_CMAA2_LocalContrastAdaptationAmount;
}

shared vec4 g_groupShared2x2FracEdgesH[CMAA2_CS_INPUT_KERNEL_SIZE_X * CMAA2_CS_INPUT_KERNEL_SIZE_Y];
shared vec4 g_groupShared2x2FracEdgesV[CMAA2_CS_INPUT_KERNEL_SIZE_X * CMAA2_CS_INPUT_KERNEL_SIZE_Y];

void GroupsharedLoadQuadHV(uint addr, out vec2 e00, out vec2 e10, out vec2 e01, out vec2 e11) {
	vec4 valH = g_groupShared2x2FracEdgesH[addr];
	e00.y = valH.x;
	e10.y = valH.y;
	e01.y = valH.z;
	e11.y = valH.w;
	vec4 valV = g_groupShared2x2FracEdgesV[addr];
	e00.x = valV.x;
	e10.x = valV.y;
	e01.x = valV.z;
	e11.x = valV.w;
}

layout(local_size_x = CMAA2_CS_INPUT_KERNEL_SIZE_X, local_size_y = CMAA2_CS_INPUT_KERNEL_SIZE_Y, local_size_z = 1) in;

void main() {
	uvec2 groupID = gl_WorkGroupID.xy;
	uvec2 groupThreadID = gl_LocalInvocationID.xy;

	// screen position in the input (expanded) kernel (shifted one 2x2 block up/left)
	ivec2 pixelPos = ivec2(groupID) * ivec2(CMAA2_CS_OUTPUT_KERNEL_SIZE_X, CMAA2_CS_OUTPUT_KERNEL_SIZE_Y) + ivec2(groupThreadID) - ivec2(1, 1);
	pixelPos *= ivec2(2, 2);

	const ivec2 qeOffsets[4] = ivec2[4](ivec2(0, 0), ivec2(1, 0), ivec2(0, 1), ivec2(1, 1));
	const uint rowStride2x2 = CMAA2_CS_INPUT_KERNEL_SIZE_X;
	uint centerAddr2x2 = groupThreadID.x + groupThreadID.y * rowStride2x2;
	bool inOutputKernel = !any(bvec4(groupThreadID.x == (CMAA2_CS_INPUT_KERNEL_SIZE_X - 1), groupThreadID.x == 0, groupThreadID.y == (CMAA2_CS_INPUT_KERNEL_SIZE_Y - 1), groupThreadID.y == 0));

	vec2 qe0, qe1, qe2, qe3;
	uvec4 outEdges = uvec4(0u);

	// edge detection (CMAA2_EDGE_DETECTION_LUMA_PATH 1: luma computed in place)
	float pixelLumas[3 * 3 - 1];
	for (int i = 0; i < 3 * 3 - 1; i++) {
		vec3 color = LoadSourceColor(pixelPos, ivec2(i % 3, i / 3)).rgb;
		pixelLumas[i] = RGBToLumaForEdges(color);
	}
	qe0 = ComputeEdgeLuma(0, 0, pixelLumas);
	qe1 = ComputeEdgeLuma(1, 0, pixelLumas);
	qe2 = ComputeEdgeLuma(0, 1, pixelLumas);
	qe3 = ComputeEdgeLuma(1, 1, pixelLumas);

	g_groupShared2x2FracEdgesV[centerAddr2x2 + rowStride2x2 * 0] = vec4(qe0.x, qe1.x, qe2.x, qe3.x);
	g_groupShared2x2FracEdgesH[centerAddr2x2 + rowStride2x2 * 0] = vec4(qe0.y, qe1.y, qe2.y, qe3.y);

	memoryBarrierShared();
	barrier();

	if (inOutputKernel) {
		vec2 topRow = g_groupShared2x2FracEdgesH[centerAddr2x2 - rowStride2x2].zw; // top row's bottom edge
		vec2 leftColumn = g_groupShared2x2FracEdgesV[centerAddr2x2 - 1].yw; // left column's right edge

		bool someNonZeroEdges = any(notEqual(vec4(qe0, qe1) + vec4(qe2, qe3) + vec4(topRow[0], topRow[1], leftColumn[0], leftColumn[1]), vec4(0.0)));

		if (someNonZeroEdges) {
			// Clear deferred color list heads to empty (if potentially needed - even though some edges might get culled by local contrast adaptation
			// step below, it's still cheaper to just clear it without additional logic)
			ivec2 quadPos = pixelPos / 2;
			if (quadPos.x < params.heads_width && quadPos.y < (params.size.y + 1) / 2) {
				g_workingDeferredBlendItemListHeads.data[quadPos.y * params.heads_width + quadPos.x] = EMPTY;
			}

			vec4 ce[4];

			// local contrast adaptation
			vec2 dummyd0, dummyd1, dummyd2;
			vec2 neighbourhood[4][4];

			////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// load & unpack kernel data from SLM
			GroupsharedLoadQuadHV(centerAddr2x2 - rowStride2x2 - 1, dummyd0, dummyd1, dummyd2, neighbourhood[0][0]);
			GroupsharedLoadQuadHV(centerAddr2x2 - rowStride2x2, dummyd0, dummyd1, neighbourhood[1][0], neighbourhood[2][0]);
			GroupsharedLoadQuadHV(centerAddr2x2 - rowStride2x2 + 1, dummyd0, dummyd1, neighbourhood[3][0], dummyd2);
			GroupsharedLoadQuadHV(centerAddr2x2 - 1, dummyd0, neighbourhood[0][1], dummyd1, neighbourhood[0][2]);
			GroupsharedLoadQuadHV(centerAddr2x2 + 1, neighbourhood[3][1], dummyd0, neighbourhood[3][2], dummyd1);
			GroupsharedLoadQuadHV(centerAddr2x2 - 1 + rowStride2x2, dummyd0, neighbourhood[0][3], dummyd1, dummyd2);
			GroupsharedLoadQuadHV(centerAddr2x2 + rowStride2x2, neighbourhood[1][3], neighbourhood[2][3], dummyd0, dummyd1);
			neighbourhood[1][0].y = topRow[0]; // already in registers
			neighbourhood[2][0].y = topRow[1]; // already in registers
			neighbourhood[0][1].x = leftColumn[0]; // already in registers
			neighbourhood[0][2].x = leftColumn[1]; // already in registers
			neighbourhood[1][1] = qe0; // already in registers
			neighbourhood[2][1] = qe1; // already in registers
			neighbourhood[1][2] = qe2; // already in registers
			neighbourhood[2][2] = qe3; // already in registers
			////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			topRow[0] = float((topRow[0] - ComputeLocalContrastH(0, -1, neighbourhood)) > g_CMAA2_EdgeThreshold);
			topRow[1] = float((topRow[1] - ComputeLocalContrastH(1, -1, neighbourhood)) > g_CMAA2_EdgeThreshold);
			leftColumn[0] = float((leftColumn[0] - ComputeLocalContrastV(-1, 0, neighbourhood)) > g_CMAA2_EdgeThreshold);
			leftColumn[1] = float((leftColumn[1] - ComputeLocalContrastV(-1, 1, neighbourhood)) > g_CMAA2_EdgeThreshold);

			ce[0].x = float((qe0.x - ComputeLocalContrastV(0, 0, neighbourhood)) > g_CMAA2_EdgeThreshold);
			ce[0].y = float((qe0.y - ComputeLocalContrastH(0, 0, neighbourhood)) > g_CMAA2_EdgeThreshold);
			ce[1].x = float((qe1.x - ComputeLocalContrastV(1, 0, neighbourhood)) > g_CMAA2_EdgeThreshold);
			ce[1].y = float((qe1.y - ComputeLocalContrastH(1, 0, neighbourhood)) > g_CMAA2_EdgeThreshold);
			ce[2].x = float((qe2.x - ComputeLocalContrastV(0, 1, neighbourhood)) > g_CMAA2_EdgeThreshold);
			ce[2].y = float((qe2.y - ComputeLocalContrastH(0, 1, neighbourhood)) > g_CMAA2_EdgeThreshold);
			ce[3].x = float((qe3.x - ComputeLocalContrastV(1, 1, neighbourhood)) > g_CMAA2_EdgeThreshold);
			ce[3].y = float((qe3.y - ComputeLocalContrastH(1, 1, neighbourhood)) > g_CMAA2_EdgeThreshold);

			// left
			ce[0].z = leftColumn[0];
			ce[1].z = ce[0].x;
			ce[2].z = leftColumn[1];
			ce[3].z = ce[2].x;

			// top
			ce[0].w = topRow[0];
			ce[1].w = topRow[1];
			ce[2].w = ce[0].y;
			ce[3].w = ce[1].y;

			for (int i = 0; i < 4; i++) {
				ivec2 localPixelPos = pixelPos + qeOffsets[i];

				vec4 edges = ce[i];

				// if there's at least one two edge corner, this is a candidate for simple or complex shape processing...
				bool isCandidate = (edges.x * edges.y + edges.y * edges.z + edges.z * edges.w + edges.w * edges.x) != 0.0;
				if (isCandidate && InPicture(localPixelPos)) {
					uint counterIndex = atomicAdd(g_workingControlBuffer.data[CTRL_CANDIDATES], 1u);
					if (counterIndex < params.candidates_length) {
						g_workingShapeCandidates.data[counterIndex] = (uint(localPixelPos.x) << 18) | uint(localPixelPos.y);
					}
				}

				// Write out edges - we write out all, including empty pixels, to make sure shape detection edge tracing
				// doesn't continue on previous frame's edges that no longer exist.
				outEdges[i] = PackEdges(edges);
			}
		}
	}

	// finally, write the edges!
	if (inOutputKernel) {
		ivec2 edgesPos = ivec2(pixelPos.x / 2, pixelPos.y);
		if (edgesPos.x < (params.size.x + 1) / 2) {
			if (edgesPos.y < params.size.y) {
				imageStore(g_workingEdges, edgesPos, uvec4((outEdges[1] << 4) | outEdges[0]));
			}
			if (edgesPos.y + 1 < params.size.y) {
				imageStore(g_workingEdges, edgesPos + ivec2(0, 1), uvec4((outEdges[3] << 4) | outEdges[2]));
			}
		}
	}
}
#endif // CMAA2_EDGES

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Compute shaders used to generate DispatchIndirect() control buffer
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef CMAA2_DISPATCH_ARGS

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

// Compute dispatch arguments for the DispatchIndirect() that calls ProcessCandidatesCS and DeferredColorApply2x2CS
void main() {
	uvec3 groupID = gl_WorkGroupID;
	// activated once on Dispatch( 2, 1, 1 )
	if (groupID.x == 1u) {
		// get current count
		uint shapeCandidateCount = g_workingControlBuffer.data[CTRL_CANDIDATES];

		// check for overflow!
		shapeCandidateCount = min(shapeCandidateCount, params.candidates_length);

		// write dispatch indirect arguments for ProcessCandidatesCS
		g_workingExecuteIndirectBuffer.data[0] = (shapeCandidateCount + CMAA2_PROCESS_CANDIDATES_NUM_THREADS - 1) / CMAA2_PROCESS_CANDIDATES_NUM_THREADS;
		g_workingExecuteIndirectBuffer.data[1] = 1u;
		g_workingExecuteIndirectBuffer.data[2] = 1u;

		// write actual number of items to process in ProcessCandidatesCS
		g_workingControlBuffer.data[CTRL_COUNT] = shapeCandidateCount;
	}
	// activated once on Dispatch( 1, 2, 1 )
	else if (groupID.y == 1u) {
		// get current count
		uint blendLocationCount = g_workingControlBuffer.data[CTRL_LOCATIONS];

		// check for overflow!
		blendLocationCount = min(blendLocationCount, params.locations_length);

		// write dispatch indirect arguments for DeferredColorApply2x2CS (CMAA2_DEFERRED_APPLY_THREADGROUP_SWAP 1)
		g_workingExecuteIndirectBuffer.data[0] = 1u;
		g_workingExecuteIndirectBuffer.data[1] = (blendLocationCount + CMAA2_DEFERRED_APPLY_NUM_THREADS - 1) / CMAA2_DEFERRED_APPLY_NUM_THREADS;
		g_workingExecuteIndirectBuffer.data[2] = 1u;

		// write actual number of items to process in DeferredColorApply2x2CS
		g_workingControlBuffer.data[CTRL_COUNT] = blendLocationCount;

		// clear counters for next frame
		g_workingControlBuffer.data[CTRL_CANDIDATES] = 0u;
		g_workingControlBuffer.data[CTRL_LOCATIONS] = 0u;
		g_workingControlBuffer.data[CTRL_ITEMS] = 0u;
	}
}
#endif // CMAA2_DISPATCH_ARGS

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Process candidates
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef CMAA2_PROCESS_CANDIDATES

vec4 ComputeSimpleShapeBlendValues(vec4 edges, vec4 edgesLeft, vec4 edgesRight, vec4 edgesTop, vec4 edgesBottom, bool dontTestShapeValidity) {
	// a 3x3 kernel for higher quality handling of L-based shapes (still rather basic and conservative)

	float fromRight = edges.r;
	float fromBelow = edges.g;
	float fromLeft = edges.b;
	float fromAbove = edges.a;

	float blurCoeff = g_CMAA2_SimpleShapeBlurinessAmount;

	float numberOfEdges = dot(edges, vec4(1.0, 1.0, 1.0, 1.0));

	float numberOfEdgesAllAround = dot(edgesLeft.bga + edgesRight.rga + edgesTop.rba + edgesBottom.rgb, vec3(1.0, 1.0, 1.0));

	// skip if already tested for before calling this function
	if (!dontTestShapeValidity) {
		// No blur for straight edge
		if (numberOfEdges == 1.0) {
			blurCoeff = 0.0;
		}

		// L-like step shape ( only blur if it's a corner, not if it's two parallel edges)
		if (numberOfEdges == 2.0) {
			blurCoeff *= ((1.0 - fromBelow * fromAbove) * (1.0 - fromRight * fromLeft));
		}
	}

	// L-like step shape
	if (numberOfEdges == 2.0) {
		blurCoeff *= 0.75;

		float k = 0.9;
		fromRight += k * (edges.g * edgesTop.r * (1.0 - edgesLeft.g) + edges.a * edgesBottom.r * (1.0 - edgesLeft.a));
		fromBelow += k * (edges.b * edgesRight.g * (1.0 - edgesTop.b) + edges.r * edgesLeft.g * (1.0 - edgesTop.r));
		fromLeft += k * (edges.a * edgesBottom.b * (1.0 - edgesRight.a) + edges.g * edgesTop.b * (1.0 - edgesRight.g));
		fromAbove += k * (edges.r * edgesLeft.a * (1.0 - edgesBottom.r) + edges.b * edgesRight.a * (1.0 - edgesBottom.b));
	}

	// Dampen the blurring effect when lots of neighbouring edges - additionally preserves text and texture detail
	blurCoeff *= clamp(1.30 - numberOfEdgesAllAround / 10.0, 0.0, 1.0);

	return vec4(fromLeft, fromAbove, fromRight, fromBelow) * blurCoeff;
}

void FindZLineLengths(out float lineLengthLeft, out float lineLengthRight, ivec2 screenPos, bool horizontal, bool invertedZShape, vec2 stepRight) {
	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	uint maskLeft, bitsContinueLeft, maskRight, bitsContinueRight;
	{
		// Horizontal (vertical is the same, just rotated 90- counter-clockwise)
		// Inverted Z case:              // Normal Z case:
		//   __                          // __
		//  X|                           //  X|
		// --                            //   --
		uint maskTraceLeft, maskTraceRight;
		if (horizontal) {
			maskTraceLeft = 0x08u; // tracing top edge
			maskTraceRight = 0x02u; // tracing bottom edge
		} else {
			maskTraceLeft = 0x04u; // tracing left edge
			maskTraceRight = 0x01u; // tracing right edge
		}
		if (invertedZShape) {
			uint temp = maskTraceLeft;
			maskTraceLeft = maskTraceRight;
			maskTraceRight = temp;
		}
		maskLeft = maskTraceLeft;
		bitsContinueLeft = maskTraceLeft;
		maskRight = maskTraceRight;
		bitsContinueRight = maskTraceRight;
	}
	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	bool continueLeft = true;
	bool continueRight = true;
	lineLengthLeft = 1.0;
	lineLengthRight = 1.0;
	for (;;) {
		uint edgeLeft = LoadEdge(ivec2(vec2(screenPos) - stepRight * lineLengthLeft), ivec2(0, 0));
		uint edgeRight = LoadEdge(ivec2(vec2(screenPos) + stepRight * (lineLengthRight + 1.0)), ivec2(0, 0));

		// stop on encountering 'stopping' edge (as defined by masks)
		continueLeft = continueLeft && ((edgeLeft & maskLeft) == bitsContinueLeft);
		continueRight = continueRight && ((edgeRight & maskRight) == bitsContinueRight);

		lineLengthLeft += float(continueLeft);
		lineLengthRight += float(continueRight);

		float maxLR = max(lineLengthRight, lineLengthLeft);

		// both stopped? cause the search end by setting maxLR to max length.
		if (!continueLeft && !continueRight) {
			maxLR = c_maxLineLength;
		}

		// either the longer one is ahead of the smaller (already stopped) one by more than a factor of x, or both
		// are stopped - end the search.
		if (maxLR >= min(c_maxLineLength, (1.25 * min(lineLengthRight, lineLengthLeft) - 0.25))) {
			break;
		}
	}
}

shared uint g_groupSharedBlendItemCount;
shared uvec2 g_groupSharedBlendItems[CMAA2_BLEND_ITEM_SLM_SIZE];

// HLSL's x % 2 on a float (fmod: the result takes the sign of x, unlike GLSL's mod).
float HlslFmod2(float x) {
	return x - 2.0 * trunc(x / 2.0);
}

bool CollectBlendZs(ivec2 screenPos, bool horizontal, bool invertedZShape, float shapeQualityScore, float lineLengthLeft, float lineLengthRight, vec2 stepRight) {
	float leftOdd = c_symmetryCorrectionOffset * HlslFmod2(lineLengthLeft);
	float rightOdd = c_symmetryCorrectionOffset * HlslFmod2(lineLengthRight);

	float dampenEffect = clamp(float(lineLengthLeft + lineLengthRight - shapeQualityScore) * c_dampeningEffect, 0.0, 1.0);

	float loopFrom = -floor((lineLengthLeft + 1.0) / 2.0) + 1.0;
	float loopTo = floor((lineLengthRight + 1.0) / 2.0);

	uint blendItemCount = uint(loopTo - loopFrom + 1.0);
	uint itemIndex = atomicAdd(g_groupSharedBlendItemCount, blendItemCount);
	// safety
	if ((itemIndex + blendItemCount) > CMAA2_BLEND_ITEM_SLM_SIZE) {
		// (Not in the original:) the slots this reserved below the end are counted but would never be filled.
		for (uint j = itemIndex; j < CMAA2_BLEND_ITEM_SLM_SIZE; j++) {
			g_groupSharedBlendItems[j] = uvec2(EMPTY);
		}
		return false;
	}

	float totalLength = float(loopTo - loopFrom) + 1.0 - leftOdd - rightOdd;
	float lerpStep = 1.0 / totalLength;

	float lerpFromK = (0.5 - leftOdd - loopFrom) * lerpStep;

	uint itemHeader = (uint(screenPos.x) << 18) | uint(screenPos.y);
	uint itemValStatic = (uint(horizontal) << 31) | (uint(invertedZShape) << 30);

	for (float i = loopFrom; i <= loopTo; i++) {
		float secondPart = float(i > 0.0);
		float srcOffset = 1.0 - secondPart * 2.0;

		float lerpK = (lerpStep * i + lerpFromK) * srcOffset + secondPart;
		lerpK *= dampenEffect;

		uvec2 encodedItem;
		encodedItem.x = itemHeader;
		encodedItem.y = itemValStatic | ((uint(i + 256.0)) << 20) | ((uint(srcOffset + 256.0)) << 10) | uint(clamp(lerpK, 0.0, 1.0) * 1023.0 + 0.5);
		g_groupSharedBlendItems[itemIndex++] = encodedItem;
	}
	return true;
}

void BlendZs(ivec2 screenPos, bool horizontal, bool invertedZShape, float shapeQualityScore, float lineLengthLeft, float lineLengthRight, vec2 stepRight) {
	vec2 blendDir = (horizontal) ? (vec2(0.0, -1.0)) : (vec2(-1.0, 0.0));

	if (invertedZShape) {
		blendDir = -blendDir;
	}

	float leftOdd = c_symmetryCorrectionOffset * HlslFmod2(lineLengthLeft);
	float rightOdd = c_symmetryCorrectionOffset * HlslFmod2(lineLengthRight);

	float dampenEffect = clamp(float(lineLengthLeft + lineLengthRight - shapeQualityScore) * c_dampeningEffect, 0.0, 1.0);

	float loopFrom = -floor((lineLengthLeft + 1.0) / 2.0) + 1.0;
	float loopTo = floor((lineLengthRight + 1.0) / 2.0);

	float totalLength = float(loopTo - loopFrom) + 1.0 - leftOdd - rightOdd;
	float lerpStep = 1.0 / totalLength;

	float lerpFromK = (0.5 - leftOdd - loopFrom) * lerpStep;

	for (float i = loopFrom; i <= loopTo; i++) {
		float secondPart = float(i > 0.0);
		float srcOffset = 1.0 - secondPart * 2.0;

		float lerpK = (lerpStep * i + lerpFromK) * srcOffset + secondPart;
		lerpK *= dampenEffect;

		vec2 pixelPos = vec2(screenPos) + stepRight * i;

		vec4 colorCenter = LoadSourceColor(ivec2(pixelPos), ivec2(0, 0));
		vec4 colorFrom = LoadSourceColor(ivec2(pixelPos + blendDir * srcOffset), ivec2(0, 0));

		vec4 outputColor = mix(colorCenter, colorFrom, lerpK);

		StoreColorSample(ivec2(pixelPos), outputColor, true);
	}
}

// TODO (from the original):
// There were issues with moving this (including the calling code) to half-float on some hardware (broke in certain cases on RX 480).
// Further investigation is required.
void DetectZsHorizontal(vec4 edges, vec4 edgesM1P0, vec4 edgesP1P0, vec4 edgesP2P0, out float invertedZScore, out float normalZScore) {
	// Inverted Z case:
	//   __
	//  X|
	// --
	{
		invertedZScore = edges.r * edges.g * edgesP1P0.a;
		invertedZScore *= 2.0 + ((edgesM1P0.g + edgesP2P0.a)) - (edges.a + edgesP1P0.g) - 0.7 * (edgesP2P0.g + edgesM1P0.a + edges.b + edgesP1P0.r);
	}

	// Normal Z case:
	// __
	//  X|
	//   --
	{
		normalZScore = edges.r * edges.a * edgesP1P0.g;
		normalZScore *= 2.0 + ((edgesM1P0.a + edgesP2P0.g)) - (edges.g + edgesP1P0.a) - 0.7 * (edgesP2P0.a + edgesM1P0.g + edges.b + edgesP1P0.r);
	}
}

layout(local_size_x = CMAA2_PROCESS_CANDIDATES_NUM_THREADS, local_size_y = 1, local_size_z = 1) in;

void main() {
	uint dispatchThreadID = gl_GlobalInvocationID.x;
	uint groupThreadID = gl_LocalInvocationID.x;

	if (groupThreadID == 0u) {
		g_groupSharedBlendItemCount = 0u;
	}
	memoryBarrierShared();
	barrier();

	uint numCandidates = g_workingControlBuffer.data[CTRL_COUNT];
	if (dispatchThreadID < numCandidates) {
		uint pixelID = g_workingShapeCandidates.data[dispatchThreadID];

		ivec2 pixelPos = ivec2(int(pixelID >> 18), int(pixelID & 0x3FFFu));

		uint edgesCenterPacked = LoadEdge(pixelPos, ivec2(0, 0));
		vec4 edges = UnpackEdgesFlt(edgesCenterPacked);
		vec4 edgesLeft = UnpackEdgesFlt(LoadEdge(pixelPos, ivec2(-1, 0)));
		vec4 edgesRight = UnpackEdgesFlt(LoadEdge(pixelPos, ivec2(1, 0)));
		vec4 edgesBottom = UnpackEdgesFlt(LoadEdge(pixelPos, ivec2(0, 1)));
		vec4 edgesTop = UnpackEdgesFlt(LoadEdge(pixelPos, ivec2(0, -1)));

		// simple shapes
		{
			vec4 blendVal = ComputeSimpleShapeBlendValues(edges, edgesLeft, edgesRight, edgesTop, edgesBottom, true);

			float fourWeightSum = dot(blendVal, vec4(1.0, 1.0, 1.0, 1.0));
			float centerWeight = 1.0 - fourWeightSum;

			vec4 outColor = LoadSourceColor(pixelPos, ivec2(0, 0)) * centerWeight;
			if (blendVal.x > 0.0) { // from left
				vec4 pixelL = LoadSourceColor(pixelPos, ivec2(-1, 0));
				outColor += blendVal.x * pixelL;
			}
			if (blendVal.y > 0.0) { // from above
				vec4 pixelT = LoadSourceColor(pixelPos, ivec2(0, -1));
				outColor += blendVal.y * pixelT;
			}
			if (blendVal.z > 0.0) { // from right
				vec4 pixelR = LoadSourceColor(pixelPos, ivec2(1, 0));
				outColor += blendVal.z * pixelR;
			}
			if (blendVal.w > 0.0) { // from below
				vec4 pixelB = LoadSourceColor(pixelPos, ivec2(0, 1));
				outColor += blendVal.w * pixelB;
			}

			StoreColorSample(pixelPos, outColor, false);
		}

		// complex shapes - detect
		{
			float invertedZScore;
			float normalZScore;
			float maxScore;
			bool horizontal = true;
			bool invertedZ = false;

			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// horizontal
			{
				vec4 edgesM1P0 = edgesLeft;
				vec4 edgesP1P0 = edgesRight;
				vec4 edgesP2P0 = UnpackEdgesFlt(LoadEdge(pixelPos, ivec2(2, 0)));

				DetectZsHorizontal(edges, edgesM1P0, edgesP1P0, edgesP2P0, invertedZScore, normalZScore);
				maxScore = max(invertedZScore, normalZScore);

				if (maxScore > 0.0) {
					invertedZ = invertedZScore > normalZScore;
				}
			}
			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// vertical
			{
				// Reuse the same code for vertical (used for horizontal above), but rotate input data 90 degrees counter-clockwise, so that:
				// left     becomes     bottom
				// top      becomes     left
				// right    becomes     top
				// bottom   becomes     right

				// we also have to rotate edges, thus .argb
				vec4 edgesM1P0 = edgesBottom;
				vec4 edgesP1P0 = edgesTop;
				vec4 edgesP2P0 = UnpackEdgesFlt(LoadEdge(pixelPos, ivec2(0, -2)));

				DetectZsHorizontal(edges.argb, edgesM1P0.argb, edgesP1P0.argb, edgesP2P0.argb, invertedZScore, normalZScore);
				float vertScore = max(invertedZScore, normalZScore);

				if (vertScore > maxScore) {
					maxScore = vertScore;
					horizontal = false;
					invertedZ = invertedZScore > normalZScore;
				}
			}
			/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			if (maxScore > 0.0) {
				float shapeQualityScore = floor(clamp(4.0 - maxScore, 0.0, 3.0)); // 0 - best quality, 1 - some edges missing but ok, 2 & 3 - dubious but better than nothing

				vec2 stepRight = (horizontal) ? (vec2(1.0, 0.0)) : (vec2(0.0, -1.0));
				float lineLengthLeft, lineLengthRight;
				FindZLineLengths(lineLengthLeft, lineLengthRight, pixelPos, horizontal, invertedZ, stepRight);

				lineLengthLeft -= shapeQualityScore;
				lineLengthRight -= shapeQualityScore;

				if ((lineLengthLeft + lineLengthRight) >= (5.0)) {
					// try adding to SLM but fall back to in-place processing if full (which only really happens in synthetic test cases)
					if (!CollectBlendZs(pixelPos, horizontal, invertedZ, shapeQualityScore, lineLengthLeft, lineLengthRight, stepRight)) {
						BlendZs(pixelPos, horizontal, invertedZ, shapeQualityScore, lineLengthLeft, lineLengthRight, stepRight);
					}
				}
			}
		}
	}

	memoryBarrierShared();
	barrier();

	uint totalItemCount = min(uint(CMAA2_BLEND_ITEM_SLM_SIZE), g_groupSharedBlendItemCount);

	// spread items into waves
	uint loops = (totalItemCount + (CMAA2_PROCESS_CANDIDATES_NUM_THREADS - 1) - groupThreadID) / CMAA2_PROCESS_CANDIDATES_NUM_THREADS;

	for (uint loop = 0u; loop < loops; loop++) {
		uint index = loop * CMAA2_PROCESS_CANDIDATES_NUM_THREADS + groupThreadID;

		uvec2 itemVal = g_groupSharedBlendItems[index];
		if (itemVal.x == EMPTY) {
			continue;
		}

		ivec2 startingPos = ivec2(int(itemVal.x >> 18), int(itemVal.x & 0x3FFFu));

		bool itemHorizontal = ((itemVal.y >> 31) & 1u) != 0u;
		bool itemInvertedZ = ((itemVal.y >> 30) & 1u) != 0u;
		float itemStepIndex = float((itemVal.y >> 20) & 0x3FFu) - 256.0;
		float itemSrcOffset = float((itemVal.y >> 10) & 0x3FFu) - 256.0;
		float itemLerpK = float(itemVal.y & 0x3FFu) / 1023.0;

		vec2 itemStepRight = (itemHorizontal) ? (vec2(1.0, 0.0)) : (vec2(0.0, -1.0));
		vec2 itemBlendDir = (itemHorizontal) ? (vec2(0.0, -1.0)) : (vec2(-1.0, 0.0));
		if (itemInvertedZ) {
			itemBlendDir = -itemBlendDir;
		}

		ivec2 itemPixelPos = startingPos + ivec2(itemStepRight * itemStepIndex);

		vec4 colorCenter = LoadSourceColor(itemPixelPos, ivec2(0, 0));
		vec4 colorFrom = LoadSourceColor(itemPixelPos + ivec2(itemBlendDir * itemSrcOffset), ivec2(0, 0));

		vec4 outputColor = mix(colorCenter, colorFrom, itemLerpK);

		StoreColorSample(itemPixelPos, outputColor, true);
	}
}
#endif // CMAA2_PROCESS_CANDIDATES

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Deferred colour apply
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef CMAA2_DEFERRED_APPLY

// CMAA2_DEFERRED_APPLY_THREADGROUP_SWAP 1
layout(local_size_x = 4, local_size_y = CMAA2_DEFERRED_APPLY_NUM_THREADS, local_size_z = 1) in;

void main() {
	uint numCandidates = g_workingControlBuffer.data[CTRL_COUNT];
	uint currentCandidate = gl_GlobalInvocationID.y;
	uint currentQuadOffsetXY = gl_LocalInvocationID.x;

	if (currentCandidate >= numCandidates) {
		return;
	}

	uint pixelID = g_workingDeferredBlendLocationList.data[currentCandidate];
	uvec2 quadPos = uvec2((pixelID >> 16), pixelID & 0xFFFFu);
	const ivec2 qeOffsets[4] = ivec2[4](ivec2(0, 0), ivec2(1, 0), ivec2(0, 1), ivec2(1, 1));
	ivec2 pixelPos = ivec2(quadPos * 2u) + qeOffsets[currentQuadOffsetXY];

	uint counterIndexWithHeader = g_workingDeferredBlendItemListHeads.data[quadPos.y * uint(params.heads_width) + quadPos.x];

	vec4 outColors = vec4(0.0);
	float outWeight = 0.0;
	uint itemCount = params.items_length;

	const uint maxLoops = 32u; // do the loop to prevent bad data hanging the GPU <- probably not needed
	for (uint i = 0u; (counterIndexWithHeader != EMPTY) && (i < maxLoops); i++) {
		// decode item-specific info: {2 bits for 2x2 quad location}, {3 bits for MSAA sample index}, {1 bit for isComplexShape flag}, {26 bits for address}
		uint offsetXY = (counterIndexWithHeader >> 30) & 0x03u;
		bool isComplexShape = ((counterIndexWithHeader >> 26) & 0x01u) != 0u;
		uint index = counterIndexWithHeader & ((1u << 26) - 1u);
		if (index >= itemCount) {
			break;
		}

		counterIndexWithHeader = g_workingDeferredBlendItemList.data[index * 3u + 0u];

		if (offsetXY == currentQuadOffsetXY) {
			vec4 color = vec4(unpackHalf2x16(g_workingDeferredBlendItemList.data[index * 3u + 1u]), unpackHalf2x16(g_workingDeferredBlendItemList.data[index * 3u + 2u]));
			float weight = 0.8 + 1.0 * float(isComplexShape);
			outColors += color * weight;
			outWeight += weight;
		}
	}

	if (outWeight == 0.0 || !InPicture(pixelPos)) {
		return;
	}

	imageStore(g_inoutColorWriteonly, pixelPos, outColors / outWeight);
}
#endif // CMAA2_DEFERRED_APPLY
