// Stencil-copy mask. A fullscreen triangle whose fragments are gated by the hardware stencil
// TEST (configured in the pipeline's RDPipelineDepthStencilState, COMPARE_OP_EQUAL on bit0).
// Where the test passes — i.e. a highlighted object's pixels — the fragment writes 1.0 into
// the mask texture; everywhere else stays at the cleared 0. No stencil sampling involved.
#[vertex]
#version 450

layout(location = 0) in vec3 vertex_attrib;

void main() {
	gl_Position = vec4(vertex_attrib, 1.0);
}

#[fragment]
#version 450

layout(location = 0) out vec4 frag_color;

void main() {
	frag_color = vec4(1.0);
}
