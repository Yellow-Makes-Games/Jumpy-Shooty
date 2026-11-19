shader_type spatial;
// The band of energy round a portal gun's portal: a bright glow just inside the rim
// and licks of light that reach out past it, always on the move. `power` makes it
// flare (someone going through, opening, closing); `shown` fades it in and out.
//
// Drawn on a flat plane lying on the portal, RIM_REACH times the oval each way (see
// Portal._build): `local` is in units of the oval, so its edge is at length 1.
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.25, 0.7, 1.0, 1.0);
uniform float time = 0.0;
uniform float power = 1.0;
uniform float shown = 1.0;

varying vec2 local;

void vertex() {
	local = VERTEX.xz;
}

void fragment() {
	float r = length(local);
	float a = atan(local.y, local.x);
	// How far the light licks out at this angle: a few waves going round at their own speeds.
	float lick = 0.5 + 0.22 * sin(a * 5.0 + time * 2.1) + 0.16 * sin(a * 9.0 - time * 3.4) + 0.12 * sin(a * 15.0 + time * 5.3);
	float reach = 1.2 + (0.08 + 0.2 * lick) * clamp(power, 0.0, 2.5);
	float inside = smoothstep(0.78, 0.99, r) * (1.0 - step(1.0, r));
	// (Brightest against the rim, thinning out to the tip of each lick.)
	float along = clamp((r - 1.18) / max(reach - 1.18, 0.001), 0.0, 1.0);
	float outside = step(1.0, r) * (1.0 - along) * (1.0 - along * along);
	vec3 hot = mix(tint.rgb, vec3(1.0), 0.6);
	ALBEDO = mix(tint.rgb, hot, inside * inside) * (1.0 + 0.5 * (power - 1.0));
	ALPHA = clamp(inside * inside * 0.85 + outside * (0.55 + 0.35 * lick), 0.0, 1.0) * shown;
}
