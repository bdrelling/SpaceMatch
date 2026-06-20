// Highlight outline: an inverted-hull silhouette (back-faces pushed out along their
// normals) rendered in a flat, emissive colour. Sits on a duplicate mesh that overlays
// the item; toggling that mesh's visibility flips the highlight on/off. Emissive so it
// blooms when the environment has glow enabled, but still reads as a bright rim without.
shader_type spatial;
render_mode cull_front, unshaded;

// Outline thickness in world units.
uniform float outline_width : hint_range(0.0, 0.2) = 0.04;
uniform vec4 outline_color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
// Emission multiplier — pushes the colour past 1.0 so bloom catches it.
uniform float emission_energy : hint_range(0.0, 8.0) = 2.0;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * emission_energy;
}
