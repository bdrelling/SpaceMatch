shader_type sky;

uniform vec3 base_color : source_color = vec3(0.118, 0.165, 0.220);
uniform vec3 grid_color : source_color = vec3(0.30, 0.42, 0.52);
uniform float cell = 12.0;
uniform float line_width = 0.02;
uniform float pole_fade = 0.6;

void sky() {
	vec3 d = normalize(EYEDIR);
	vec2 uv = vec2(atan(d.x, d.z), asin(clamp(d.y, -1.0, 1.0)));
	vec2 g = abs(fract(uv * cell) - 0.5);
	float line = 1.0 - smoothstep(0.0, line_width, min(g.x, g.y));
	float fade = pow(1.0 - abs(d.y), pole_fade);
	COLOR = mix(base_color, grid_color, line * fade);
}
