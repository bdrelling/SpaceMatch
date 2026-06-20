// Silhouette stencil — pass 1 (see SilhouetteHighlighter). Stamps stencil value 1 (bit0 =
// "object") over the object's FULL projected silhouette: depth_test_disabled so occluded
// parts are marked too, cull_disabled + every mesh writing the same value so the mark is the
// union of all parts. Renders invisibly (ALPHA 0) — the stencil write is the whole point.
// Pass 2 adds bit1 (→ 3) on the visible pixels, so a leftover 1 means "occluded" (drives the
// x-ray fill) while bit0 alone marks "object" for the outline CompositorEffect.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;
stencil_mode write, compare_always, 1;

void fragment() {
	ALPHA = 0.0;
}
