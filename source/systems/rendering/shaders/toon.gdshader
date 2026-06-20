// Cel / toon shading: hard quantized light bands instead of PBR's smooth gradient.
// A fundamentally different render model from StandardMaterial3D — this is what makes
// the surface read "drawn" rather than "lit."
shader_type spatial;
render_mode specular_disabled, diffuse_burley;

uniform vec4 albedo : source_color = vec4(0.8, 0.3, 0.3, 1.0);
// Number of hard light steps. 2 = stark cartoon, 4 = softer.
uniform float bands : hint_range(1.0, 6.0) = 3.0;
// Lifts the dark side so shadowed faces stay colored (toy read) instead of going black.
uniform float wrap : hint_range(0.0, 1.0) = 0.35;
// Width of the warm/cool rim toward the silhouette.
uniform float rim_amount : hint_range(0.0, 1.0) = 0.25;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	// Wrap, then quantize NdotL into hard bands.
	float lit = clamp(ndl * (1.0 - wrap) + wrap, 0.0, 1.0);
	float banded = ceil(lit * bands) / bands;
	DIFFUSE_LIGHT += albedo.rgb * LIGHT_COLOR * ATTENUATION * banded;

	// Stylized rim on the light-facing silhouette.
	float rim = 1.0 - dot(normalize(NORMAL), normalize(VIEW));
	rim = smoothstep(1.0 - rim_amount, 1.0, rim) * step(0.0, ndl);
	DIFFUSE_LIGHT += rim_color.rgb * rim * ATTENUATION;
}
