// Lá cây: cắt viền theo alpha, đung đưa theo gió, sáng xuyên khi ngược nắng.
// Màu đỉnh: RGB = độ sáng (trong tán tối, ngoài tán sáng), A = mức đung đưa (gốc cành lá 0 -> ngọn 1).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(0.92, 1.0, 0.9);
uniform float alpha_cut = 0.45;
uniform float wind_strength = 0.07;   // rung lá
uniform float sway_strength = 0.06;   // cả tán lắc
uniform float wind_speed = 1.4;
uniform vec3 backlight_col : source_color = vec3(0.32, 0.42, 0.12);

void vertex() {
	vec3 np = NODE_POSITION_WORLD;
	float t = TIME * wind_speed + np.x * 0.37 + np.z * 0.21;
	float w = COLOR.a;
	vec3 flutter = vec3(sin(t * 1.9 + VERTEX.x * 1.7 + VERTEX.z * 0.9),
			sin(t * 2.6 + VERTEX.y * 2.3) * 0.6,
			cos(t * 1.6 + VERTEX.z * 1.3 + VERTEX.x * 0.5)) * wind_strength * w;
	float hgt = clamp((VERTEX.y - 2.5) / 6.0, 0.0, 1.0);
	vec3 sway = vec3(sin(t * 0.45), 0.0, cos(t * 0.38)) * sway_strength * hgt;
	VERTEX += flutter + sway;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * COLOR.rgb * tint;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.78;
	SPECULAR = 0.25;
	BACKLIGHT = backlight_col * clamp(COLOR.r, 0.3, 1.2);
}
