// X-ray fill — pass 4 of 4. Fills the OCCLUDED part of the silhouette (stencil still 1; the
// visible part was overwritten to 2 by pass 2) with a flat colour matching the rim, drawn on
// top via depth_test_disabled so it shows through the obstruction. Because it's gated by the
// stencil rather than a per-fragment depth test, stacked/concave geometry never self-fills —
// the whole occluded region reads as one solid silhouette. Emissive HDR so it blooms with the
// rim. blend_mix (alpha < 1) keeps the fill a flat, near-uniform colour instead of additively
// blowing out where stacked parts overlap, and still sorts into the transparent pass where the
// stencil can be read.
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;
stencil_mode read, compare_equal, 1;

uniform vec4 fill_color : source_color = vec4(0.5, 0.75, 1.0, 0.8);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.6;

void fragment() {
	ALBEDO = fill_color.rgb;
	EMISSION = fill_color.rgb * emission_energy;
	ALPHA = fill_color.a;
}
