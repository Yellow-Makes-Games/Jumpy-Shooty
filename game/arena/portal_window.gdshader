shader_type spatial;
// A portal gun's portal when you can see through it: the live view from its other
// portal (Portal's own camera, see Portal.update_view), drawn onto the oval.
//
// The camera looks straight out of the other portal with a frustum cut to exactly
// the portal's oval, so a point on this oval at (x, y) of its half size shows the
// texture at (x, y) too, wherever you stand: no screen maths. The mesh is the unit
// cylinder Portal squashes into the oval, so its x and z are that (x, -y).
//
// The camera renders without tonemapping, exposure or glow (linear, in HDR), so the
// main view applies them once, like everything else on screen, and fog too: the
// camera already drew the fog on the far side, so this adds none.
render_mode unshaded, fog_disabled, cull_back, shadows_disabled, depth_draw_opaque;

uniform sampler2D view : filter_linear, repeat_disable;
// The portal's colour, at the rim and while the view clears (just opened).
uniform vec4 tint : source_color = vec4(0.25, 0.7, 1.0, 1.0);
// 0: all tint (opening), 1: clear view.
uniform float clear = 1.0;
uniform float time = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX.xz;
}

void fragment() {
	vec2 uv = local * 0.5 + 0.5;
	vec3 seen = texture(view, uv).rgb;
	float r = length(local);
	// A soft band of the portal's colour round the edge, gently shimmering.
	float edge = smoothstep(0.9, 1.0, r + 0.01 * sin(atan(local.y, local.x) * 7.0 + time * 3.0));
	vec3 col = mix(seen, tint.rgb * 1.5, edge * 0.9);
	ALBEDO = mix(tint.rgb, col, clear);
}
