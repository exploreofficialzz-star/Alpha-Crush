shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Instanced grass tufts / flowers (MultiMesh). Blades shrink away with distance instead of alpha-fading.

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint_a : source_color = vec3(0.85, 1.0, 0.70);
uniform vec3 tint_b : source_color = vec3(1.15, 1.0, 0.78);
uniform float wind = 0.16;
uniform float fade_start = 26.0;
uniform float fade_end = 40.0;
uniform float sway_amount = 1.0;
uniform vec2 atlas_scale = vec2(0.5, 1.0);

varying vec3 v_up;
varying float v_rand;
varying vec2 v_cell;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length((VIEW_MATRIX * vec4(wp, 1.0)).xyz);
	float fade = 1.0 - smoothstep(fade_start, fade_end, d);
	float w = COLOR.a * sway_amount;
	float ph = wp.x * 0.45 + wp.z * 0.37;
	VERTEX.y *= fade;
	VERTEX.x += sin(TIME * 1.7 + ph) * wind * w * w;
	VERTEX.z += cos(TIME * 1.3 + ph * 1.2) * wind * 0.6 * w * w;
	v_cell = INSTANCE_CUSTOM.xy;
	v_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	v_rand = fract(sin(dot(floor(wp.xz * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 t = texture(tex, UV * atlas_scale + v_cell);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = t.rgb * mix(tint_a, tint_b, v_rand);
	NORMAL = v_up;
	ROUGHNESS = 0.9;
	BACKLIGHT = ALBEDO * 0.25;
}
