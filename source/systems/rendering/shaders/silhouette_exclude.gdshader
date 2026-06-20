// Silhouette exclusion mark (see SilhouetteHighlighter.set_excluded). Stamps stencil value 3
// over wherever this object is VISIBLE (normal depth test → only its front-most pixels). It
// renders after the highlight's mask passes but before the outline/x-ray readers, so those
// readers — which only act on stencil 0 (outline) or 1 (occluded fill) — skip anything marked
// 3. That stops a highlighted object's x-ray fill from drawing over, say, the player standing
// in front of it. Invisible (ALPHA 0); the stencil write is the whole point.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;
// Writes 4 (bit2) — deliberately NOT bit0, so the outline CompositorEffect (which tests bit0)
// skips these pixels, and the material x-ray fill (compare_equal 1) skips them too.
stencil_mode write, compare_always, 4;

void fragment() {
	ALPHA = 0.0;
}
