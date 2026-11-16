shader_type spatial;
// First-person arms and gun. Two tricks:
//  - its own field of view, so the gun looks the same whatever the player's FOV setting;
//  - its depth is squeezed toward the camera, so it is always drawn in front of
//    the world and never pokes into a wall you stand against.
// Lighting still uses the real position, so the arms sit in the scene's light and shadow.

uniform vec3 albedo : source_color = vec3(0.9);
uniform float roughness = 0.5;
uniform float metallic = 0.0;
uniform vec3 emission = vec3(0.0);
uniform float view_fov = 70.0;

void vertex() {
	float want = 1.0 / tan(radians(view_fov) * 0.5);
	float ratio = want / abs(PROJECTION_MATRIX[1][1]);
	mat4 proj = PROJECTION_MATRIX;
	proj[0][0] *= ratio;
	proj[1][1] *= ratio;
	POSITION = proj * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.z, POSITION.w, 0.9);
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission;
}
