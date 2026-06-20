shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.36, 0.40, 0.48, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.21, 0.24, 0.31, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.74, 0.92, 1.0);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.5;
uniform float checker_size = 1.5;
uniform float checker_contrast : hint_range(0.0, 0.5) = 0.2;

varying vec2 surface_uv;

void vertex() {
	surface_uv = UV;
}

void fragment() {
	vec2 cell = floor(surface_uv / checker_size);
	float checker = mod(cell.x + cell.y, 2.0);
	float tint = 1.0 - checker_contrast * 0.5 + checker * checker_contrast;
	ALBEDO = base_color.rgb * tint;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO += rim_color.rgb * fresnel * rim_strength;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT) * ATTENUATION;
	float stepped = step(shadow_threshold, n_dot_l);
	DIFFUSE_LIGHT += mix(shadow_color.rgb, ALBEDO * LIGHT_COLOR, stepped);
}
