shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Human avatar skin/cloth shader.  The mesh carries region masks:
//   COLOR.r shirt  COLOR.g trousers  COLOR.b leather (boots/gloves/belt)  COLOR.a eyebrows
//   UV.x boot sole  UV.y lips
// Triplanar micro-detail is applied in object space (the meshes have no real UV layout).

uniform vec3 skin_color : source_color = vec3(0.78, 0.58, 0.45);
uniform vec3 shirt_color : source_color = vec3(0.27, 0.36, 0.50);
uniform vec3 pants_color : source_color = vec3(0.31, 0.34, 0.22);
uniform vec3 leather_color : source_color = vec3(0.30, 0.19, 0.11);
uniform vec3 hair_color : source_color = vec3(0.13, 0.08, 0.05);
uniform vec3 sole_color : source_color = vec3(0.07, 0.065, 0.06);
uniform vec3 lip_color : source_color = vec3(0.62, 0.30, 0.28);
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 7.0;
uniform float detail_strength = 0.45;
uniform float rim_amount = 0.22;

varying vec3 v_obj_pos;
varying vec3 v_obj_nrm;

float sharpen(float x) {
	return smoothstep(0.35, 0.65, x);
}

void vertex() {
	v_obj_pos = VERTEX;
	v_obj_nrm = NORMAL;
}

void fragment() {
	float shirt = sharpen(COLOR.r);
	float pants = sharpen(COLOR.g);
	float leather = sharpen(COLOR.b);
	float brow = sharpen(COLOR.a);
	float sole = sharpen(UV.x);
	float lips = sharpen(UV.y);

	vec3 c = skin_color;
	c = mix(c, lip_color, lips * 0.85);
	c = mix(c, shirt_color, shirt);
	c = mix(c, pants_color, pants);
	c = mix(c, leather_color, leather);
	c = mix(c, hair_color, brow);
	c = mix(c, sole_color, sole);

	vec3 an = abs(v_obj_nrm);
	an = an / (an.x + an.y + an.z + 0.0001);
	vec3 dx = texture(detail_normal, v_obj_pos.zy * detail_scale).xyz * 2.0 - 1.0;
	vec3 dy = texture(detail_normal, v_obj_pos.xz * detail_scale).xyz * 2.0 - 1.0;
	vec3 dz = texture(detail_normal, v_obj_pos.xy * detail_scale).xyz * 2.0 - 1.0;
	vec3 off = vec3(0.0, dx.y, dx.x) * an.x + vec3(dy.x, 0.0, dy.y) * an.y + vec3(dz.x, dz.y, 0.0) * an.z;
	vec3 n_obj = normalize(v_obj_nrm + off * detail_strength);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n_obj, 0.0)).xyz);

	float cloth = max(max(shirt, pants), leather);
	ALBEDO = c;
	ROUGHNESS = mix(0.52, 0.86, cloth);
	SPECULAR = mix(0.5, 0.25, cloth);
	RIM = rim_amount;
	RIM_TINT = 0.4;
}
