shader_type sky;

// Procedural day/night sky: gradient, sun glow + disc, animated cumulus, stars.
// All colours are driven every frame by Atmosphere (visuals/atmosphere.gd).

uniform vec3 sky_top : source_color = vec3(0.16, 0.38, 0.80);
uniform vec3 sky_horizon : source_color = vec3(0.62, 0.78, 0.95);
uniform vec3 ground_color : source_color = vec3(0.30, 0.36, 0.30);
uniform vec3 sun_color : source_color = vec3(1.0, 0.93, 0.80);
uniform vec3 sun_dir = vec3(0.35, 0.8, 0.45);
uniform float sun_energy = 1.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed = 0.012;
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_dark : source_color = vec3(0.62, 0.68, 0.80);
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 sd = normalize(sun_dir);

	vec3 col = mix(sky_horizon, sky_top, pow(clamp(h, 0.0, 1.0), 0.5));
	if (h < 0.0) {
		col = mix(sky_horizon, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}

	float s = max(dot(dir, sd), 0.0);
	col += sun_color * (pow(s, 6.0) * 0.10 + pow(s, 40.0) * 0.30) * sun_energy;

	if (!AT_CUBEMAP_PASS) {
		float disc = smoothstep(0.9993, 0.9998, s) * step(-0.05, sd.y);
		col = mix(col, sun_color * 8.0 * sun_energy, disc);

		if (h > 0.0) {
			vec2 uv = dir.xz / (h + 0.12);
			uv = uv * 0.55 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.3);
			float n = fbm(uv);
			float d = fbm(uv + sd.xz * 0.10);
			float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, n);
			c *= smoothstep(0.0, 0.18, h);
			float shade = clamp(0.55 + (n - d) * 3.5, 0.0, 1.0);
			vec3 ccol = mix(cloud_dark, cloud_light, shade);
			col = mix(col, ccol, c * 0.92);
		}

		vec3 cell = floor(dir * 170.0);
		float rnd = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		float star = step(0.9972, rnd) * star_amount * smoothstep(0.02, 0.25, h);
		col += vec3(star);
	}

	COLOR = col;
}
