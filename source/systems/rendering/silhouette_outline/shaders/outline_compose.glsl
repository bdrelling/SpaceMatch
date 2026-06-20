// Composes the outline into the scene colour buffer from the stencil mask. A pixel gets the
// outline colour when it is OUTSIDE the silhouette (mask 0) but within `thickness` pixels of an
// inside pixel (mask 1) — a pure screen-space dilation, so the outline is gap-free regardless
// of the model's geometry/normals. Writing into the HDR colour buffer before glow means the
// outline blooms when glow is enabled. debug != 0 tints the masked object instead, to verify
// the mask in isolation.
#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D u_color;
layout(rgba16f, set = 0, binding = 1) uniform image2D u_mask;

layout(push_constant, std430) uniform Params {
	vec4 color;
	int res_x;
	int res_y;
	int thickness;
	int debug;
} p;

void main() {
	ivec2 c = ivec2(gl_GlobalInvocationID.xy);
	if (c.x >= p.res_x || c.y >= p.res_y) {
		return;
	}

	float here = imageLoad(u_mask, c).r;

	if (p.debug != 0) {
		if (here > 0.5) {
			vec4 col = imageLoad(u_color, c);
			imageStore(u_color, c, mix(col, p.color, 0.6));
		}
		return;
	}

	// Inner outline: ink pixels INSIDE the silhouette that are within `thickness` of an outside
	// pixel. Inner (not outer) so the rim can never land on a foreground object that overwrote
	// the object's stencil bit — e.g. the player in front, which is excluded from the mask.
	if (here < 0.5) {
		return;
	}
	int t = p.thickness;
	int t_sq = t * t;
	for (int dy = -t; dy <= t; dy++) {
		for (int dx = -t; dx <= t; dx++) {
			if (dx * dx + dy * dy > t_sq) {
				continue;
			}
			ivec2 s = c + ivec2(dx, dy);
			if (s.x < 0 || s.y < 0 || s.x >= p.res_x || s.y >= p.res_y) {
				continue;
			}
			if (imageLoad(u_mask, s).r < 0.5) {
				imageStore(u_color, c, p.color);
				return;
			}
		}
	}
}
