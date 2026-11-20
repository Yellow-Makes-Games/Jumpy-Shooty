shader_type spatial;
// The column of light a body arrives in (see SpawnIn.ground): an open cylinder, bright at
// the floor and gone by the top, added over what is behind it.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.5, 0.2);
uniform float strength = 1.0;

void fragment() {
	// (A CylinderMesh's side has v = 0 at its top and 1 at its bottom.)
	ALBEDO = color * 1.6;
	ALPHA = clamp(strength * pow(UV.y, 1.8) * 0.55, 0.0, 1.0);
}
