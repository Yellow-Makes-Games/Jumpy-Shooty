shader_type spatial;
// A body arriving (see SpawnIn): laid over every one of its meshes (material_overlay), it
// is solid light at first, and a line of brighter light climbs it from the feet, leaving
// the body itself below. The body is never see-through: what is not yet the robot is light.
//
// `view_model`: the first-person arms and gun, which are drawn with their own field of
// view and squeezed toward the camera (viewmodel.gdshader: the same vertex code here, so
// the light lies exactly on them). There the line runs out from the eye, not up from the feet.
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform vec3 color : source_color = vec3(1.0, 0.5, 0.2);
uniform float progress = 0.0;      // 0: all light, 1: all body
uniform float feet = 0.0;          // where the line starts: the feet's height in the world (the arms: metres from the eye)
uniform float height = 2.2;        // ...and how far it has to go
uniform float band = 0.14;         // how wide the bright line is, metres
uniform bool view_model = false;
uniform float view_fov = 70.0;

varying float along;

void vertex() {
	if (view_model) {
		float want = 1.0 / tan(radians(view_fov) * 0.5);
		float ratio = want / abs(PROJECTION_MATRIX[1][1]);
		mat4 proj = PROJECTION_MATRIX;
		proj[0][0] *= ratio;
		proj[1][1] *= ratio;
		POSITION = proj * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		POSITION.z = mix(POSITION.z, POSITION.w, 0.9);
		along = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	} else {
		along = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
		// A hair nearer the eye than the body it lies on (the same place on screen), so that it is not lost to it.
		vec4 seen = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		if (PROJECTION_MATRIX[3][3] == 0.0) {
			seen.xyz *= 0.994;   // (along the line of sight)
		} else {
			seen.z += 0.02;      // (a camera with no perspective: straight toward it)
		}
		POSITION = PROJECTION_MATRIX * seen;
	}
}

void fragment() {
	float line = feet + progress * (height + band * 2.0) - band;
	float light = smoothstep(line - 0.015, line + 0.015, along);        // above the line: still light
	float edge = 1.0 - smoothstep(0.0, band, abs(along - line));         // the line itself
	edge *= step(0.001, progress) * step(progress, 0.999);
	ALBEDO = mix(color, vec3(1.0), 0.3 + 0.6 * edge) * (1.5 + 2.0 * edge);
	ALPHA = max(light, edge * 0.9);
}
