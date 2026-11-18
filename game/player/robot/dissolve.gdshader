// A robot's surface that can burn away (see Dissolve): `progress` 0 is whole, 1 is
// gone. Patches go first where a noise in the model's own space is lowest, each with a
// glowing rim in `edge_color` just before it does. The rest is a plain lit surface
// copied from the material it replaces.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform bool use_texture = false;
uniform bool use_vertex_color = false;
uniform float metallic = 0.0;
uniform float roughness = 0.6;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float edge_width = 0.08;
uniform float edge_energy = 4.0;
uniform float noise_scale = 6.0;

varying vec3 model_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void vertex() {
	model_pos = VERTEX;
}

void fragment() {
	float n = noise(model_pos * noise_scale) * 0.65 + noise(model_pos * noise_scale * 2.7) * 0.35;
	// At 0 nothing is cut (the cut sits below every value); at 1 everything is.
	float cut = mix(-edge_width, 1.0, progress);
	if (n < cut) {
		discard;
	}
	vec3 col = albedo.rgb;
	if (use_texture) {
		col *= texture(albedo_texture, UV).rgb;
	}
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	ALBEDO = col;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission * emission_energy;
	if (progress > 0.0 && n < cut + edge_width) {
		EMISSION += edge_color.rgb * edge_energy;
	}
}
