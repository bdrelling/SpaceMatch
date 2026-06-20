// Silhouette stencil — pass 2 of 4 (see SilhouetteHighlighter). With the depth test ON, this
// overwrites the full-silhouette mark (1) with 2 only where the object actually wins the depth
// test, i.e. where it is VISIBLE. Pixels left at 1 are therefore the occluded part of the
// silhouette. This "visible vs occluded" split is what lets the x-ray fill show only through
// obstructions without any screen-space pass. Renders invisibly (ALPHA 0).
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;
// Writes 3 (bit0 + bit1): keeps the silhouette bit (bit0, set by pass 1) AND adds the
// "visible" bit (bit1). So occluded stays 1, visible becomes 3, and bit0 alone means "object"
// — which the outline CompositorEffect tests with a single mask bit.
stencil_mode write, compare_always, 3;

void fragment() {
	ALPHA = 0.0;
}
