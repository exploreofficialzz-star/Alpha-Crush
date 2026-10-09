shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Calm river/lake water: two scrolling normal maps, fresnel, shore foam from a world-space rectangle.

uniform sampler2D wave_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 shallow_color : source_color = vec3(0.10, 0.46, 0.50);
uniform vec3 deep_color : source_color = vec3(0.02, 0.20, 0.30);
uniform vec2 flow_dir = vec2(1.0, 0.0);
uniform float flow_speed = 0.035;
uniform float wave_strength = 0.55;
uniform float opacity = 0.80;
uniform vec4 water_rect = vec4(-48.0, -23.0, -6.0, -13.0);
uniform float foam_width = 0.9;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(w_pos.x * 0.6 + TIME * 1.1) + sin(w_pos.z * 0.8 - TIME * 0.9)) * 0.010;
}

void fragment() {
	vec2 uv1 = w_pos.xz * 0.09 + flow_dir * TIME * flow_speed;
	vec2 uv2 = w_pos.xz * 0.17 - vec2(flow_dir.y, flow_dir.x) * TIME * flow_speed * 0.7 + vec2(0.5, 0.25);
	vec3 n1 = texture(wave_normal, uv1).xyz * 2.0 - 1.0;
	vec3 n2 = texture(wave_normal, uv2).xyz * 2.0 - 1.0;
	vec3 nw = normalize(vec3((n1.x + n2.x) * 0.5 * wave_strength, 1.0, -(n1.y + n2.y) * 0.5 * wave_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec2 centre = vec2(water_rect.x + water_rect.z, water_rect.y + water_rect.w) * 0.5;
	vec2 half_size = vec2(water_rect.z - water_rect.x, water_rect.w - water_rect.y) * 0.5;
	vec2 q = half_size - abs(w_pos.xz - centre);
	float edge = min(q.x, q.y);
	float foam = (1.0 - smoothstep(0.0, foam_width, edge)) * (0.55 + 0.45 * (n1.x + n2.y));
	float depth_mix = smoothstep(0.0, 3.5, edge);

	vec3 col = mix(shallow_color, deep_color, depth_mix * 0.8);
	ALBEDO = mix(col, vec3(0.92, 0.96, 0.97), clamp(foam, 0.0, 1.0) * 0.8);
	ROUGHNESS = mix(0.05, 0.6, clamp(foam, 0.0, 1.0));
	SPECULAR = 0.7;
	METALLIC = 0.0;
	ALPHA = clamp(opacity + fres * 0.25 + foam * 0.2, 0.0, 0.97);
}
