shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

// Leaf-card foliage: alpha-scissor leaves, crown-spherical lighting normals (baked into the mesh),
// vertex-colour AO/tint and wind sway weighted by COLOR.a.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.45;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float wind_strength = 0.10;
uniform float wind_speed = 1.3;
uniform float translucency = 0.35;

varying vec3 v_normal_view;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = COLOR.a;
	float ph = wp.x * 0.35 + wp.z * 0.27;
	VERTEX.x += sin(TIME * wind_speed + ph) * wind_strength * sway;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + ph * 1.3) * wind_strength * sway * 0.7;
	VERTEX.y += sin(TIME * wind_speed * 1.7 + ph * 2.0) * wind_strength * 0.25 * sway;
	v_normal_view = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALBEDO = t.rgb * COLOR.rgb * tint;
	ROUGHNESS = 0.78;
	SPECULAR = 0.22;
	NORMAL = normalize(v_normal_view);
	BACKLIGHT = ALBEDO * translucency;
}
