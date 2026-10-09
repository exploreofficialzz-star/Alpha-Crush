shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Height/slope/river blended ground: grass, dirt, rock and sand (world-space planar mapping).

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float grass_scale = 0.5;
uniform float dirt_scale = 0.5;
uniform float rock_scale = 0.35;
uniform vec4 river_rect = vec4(-48.0, -23.0, -6.0, -13.0);
uniform float normal_strength = 0.9;
uniform vec3 grass_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float sand_mix : hint_range(0.0, 1.0) = 0.0;
uniform float snow_mix : hint_range(0.0, 1.0) = 0.0;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = w_pos.xz;
	float slope = 1.0 - clamp(w_nrm.y, 0.0, 1.0);

	float macro_a = texture(grass_albedo, p * 0.011).g;
	float macro_b = texture(dirt_albedo, p * 0.0173 + vec2(0.31, 0.77)).r;

	vec2 rc = clamp(p, river_rect.xy, river_rect.zw);
	float bank = 1.0 - smoothstep(1.5, 9.0, length(p - rc));

	float w_rock = smoothstep(0.20, 0.36, slope + (macro_a - 0.5) * 0.14);
	float w_dirt = smoothstep(0.56, 0.78, macro_b * 0.75 + macro_a * 0.25) * 0.65;
	w_dirt = max(w_dirt, bank * 0.85) * (1.0 - w_rock);
	float w_grass = clamp(1.0 - w_rock - w_dirt, 0.0, 1.0);

	vec3 ga = texture(grass_albedo, p * grass_scale).rgb;
	vec3 gb = texture(grass_albedo, p * grass_scale * 0.23 + vec2(0.37, 0.11)).rgb;
	ga = mix(ga, gb, 0.35) * grass_tint;
	vec3 region_sand = texture(sand_albedo, p * 0.5).rgb;
	ga = mix(ga, region_sand, sand_mix);
	ga = mix(ga, vec3(0.90, 0.93, 0.97) * (0.9 + 0.1 * macro_a), snow_mix);
	vec3 da = texture(dirt_albedo, p * dirt_scale).rgb;
	vec3 sa = texture(sand_albedo, p * 0.5).rgb;
	da = mix(da, sa, smoothstep(0.35, 0.95, bank) * 0.7);
	vec3 ra = texture(rock_albedo, p * rock_scale).rgb;

	ALBEDO = ga * w_grass + da * w_dirt + ra * w_rock;

	vec3 gn = texture(grass_normal, p * grass_scale).xyz * 2.0 - 1.0;
	vec3 dn = texture(dirt_normal, p * dirt_scale).xyz * 2.0 - 1.0;
	vec3 rn = texture(rock_normal, p * rock_scale).xyz * 2.0 - 1.0;
	vec3 offset = vec3(gn.x, 0.0, -gn.y) * w_grass + vec3(dn.x, 0.0, -dn.y) * w_dirt + vec3(rn.x, 0.0, -rn.y) * w_rock;
	vec3 nw = normalize(w_nrm + offset * normal_strength);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	ROUGHNESS = mix(0.93, 0.82, w_rock);
	SPECULAR = 0.18;
}
