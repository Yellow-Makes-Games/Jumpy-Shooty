shader_type spatial;
// A portal gun's portal: its face. With a view (once both of a pair are up and you
// are in front of it) it is a window: the live view from its other portal (Portal's
// own camera, see Portal.update_view), drawn onto the oval. Without one (`clear` 0:
// a lone portal, one seen through another portal, one just opening or closing) it is
// a slow whirl of light in the portal's colour.
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
// The portal's colour: the whirl, the rim, the ripple.
uniform vec4 tint : source_color = vec4(0.25, 0.7, 1.0, 1.0);
// 0: all whirl, 1: clear view. In between the view opens out from the middle.
uniform float clear = 1.0;
uniform float time = 0.0;
// Seconds since someone went through: a ring runs out across the face, bending the
// view as it goes (large: none).
uniform float ripple = 99.0;

varying vec2 local;

void vertex() {
	local = VERTEX.xz;
}

void fragment() {
	vec2 uv = local * 0.5 + 0.5;
	float r = length(local);
	float a = atan(local.y, local.x);
	// The ripple of someone going through.
	float wave = 0.0;
	if (ripple < 0.6) {
		float d = r - ripple * 2.4;
		wave = exp(-d * d * 30.0) * (1.0 - ripple / 0.6);
		uv += normalize(local + vec2(0.0001)) * wave * 0.035;
	}
	vec3 seen = texture(view, uv).rgb;
	// The whirl: arms of light turning in toward the middle.
	float arms = 0.5 + 0.5 * sin(a * 3.0 + r * 7.0 - time * 4.0);
	float fine = 0.5 + 0.5 * sin(a * 7.0 - r * 11.0 + time * 2.3);
	vec3 whirl = tint.rgb * (0.45 + 0.75 * arms * (0.6 + 0.4 * fine)) + vec3(0.9) * pow(max(1.0 - r, 0.0), 3.0) * 0.5;
	// The view opens out from the middle as it clears.
	float reach = clear * 1.3;
	float veil = clear >= 1.0 ? 0.0 : smoothstep(reach - 0.3, reach, r);
	vec3 col = mix(seen, whirl, veil);
	// A soft band of the portal's colour round the edge, gently shimmering.
	float edge = smoothstep(0.88, 1.0, r + 0.012 * sin(a * 7.0 + time * 3.0));
	col = mix(col, tint.rgb * 1.5, edge * 0.9);
	col += tint.rgb * wave * 1.2;
	ALBEDO = col;
}
