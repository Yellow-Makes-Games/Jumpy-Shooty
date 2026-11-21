shader_type spatial;
// An afterimage of a spinning blow (KarateGear.ghost): the body's outline in the trim
// colour, fading out. Added light only, so it never hides anything behind it.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.5, 0.2);
uniform float fade = 1.0;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), VIEW));
	float rim = pow(1.0 - facing, 1.6);
	ALBEDO = mix(color, vec3(1.0), 0.3 * rim) * (0.12 + 0.75 * rim) * fade * fade * 0.9;
}
