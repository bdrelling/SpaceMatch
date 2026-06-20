// Inverted-hull outline: render back-faces pushed out along their normals, in a flat
// color. Used as a next_pass under another material to ink a silhouette (comic/toy look).
shader_type spatial;
render_mode cull_front, unshaded;

// Outline thickness in world units.
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
