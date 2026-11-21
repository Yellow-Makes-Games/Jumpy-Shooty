shader_type spatial;
// The sky engine's moving sky (see sky_engine.gdshaderinc), drawn on a backdrop that is
// always centred on whichever camera is drawing it and pushed to the far plane, so it
// sits behind everything. Only the pixels where sky shows are drawn (it comes after the
// depth pre-pass and writes no depth of its own). Orthographic cameras (map plans) do
// not draw it: the Environment's still sky shows there instead.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://game/maps/sky/sky_engine.gdshaderinc"

varying vec3 dir;

void vertex() {
	dir = VERTEX;   // a unit sphere: each vertex is a direction
	vec3 view = (VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * vec4(view, 1.0);
	// Reverse-Z: depth 0 is the far plane.
	POSITION = vec4(clip.xy, 0.0, clip.w);
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);   // orthographic: leave it out
	}
}

void fragment() {
	ALBEDO = sky_engine(normalize(dir), CAMERA_POSITION_WORLD, TIME, true);
}
