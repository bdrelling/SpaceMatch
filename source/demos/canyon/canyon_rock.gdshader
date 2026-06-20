shader_type spatial;
render_mode cull_disabled;

uniform vec4 cliff_color : source_color = vec4(0.45, 0.29, 0.23, 1.0);
uniform vec4 band_color : source_color = vec4(0.34, 0.21, 0.17, 1.0);
// The main game's terrain look: demo_level's texture tinted with its exact
// albedo_color, tiled world-planar like Terrain3D tiles it.
uniform vec4 terrain_color : source_color = vec4(0.894, 0.573, 0.405, 1.0);
uniform sampler2D terrain_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float terrain_uv_scale : hint_range(0.001, 1.0) = 0.1;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float band_frequency : hint_range(0.0, 2.0) = 0.12;
uniform float band_warp : hint_range(0.0, 4.0) = 1.4;
uniform float band_strength : hint_range(0.0, 1.0) = 0.55;
// Surfaces flatter than the start threshold read as terrain, steeper than the
// end threshold as cliff; between them blends.
uniform float terrain_slope_start : hint_range(0.0, 1.0) = 0.85;
uniform float terrain_slope_end : hint_range(0.0, 1.0) = 0.7;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Sedimentary strata: horizontal bands by world height, warped so the
	// lines wander instead of reading as perfect contour rings.
	float warp = sin(world_position.x * 0.11) * sin(world_position.z * 0.07) * band_warp;
	float strata = fract((world_position.y + warp) * band_frequency);
	float band = smoothstep(0.30, 0.42, strata) - smoothstep(0.58, 0.72, strata);
	vec3 cliff = mix(cliff_color.rgb, band_color.rgb, band * band_strength);

	// Split ground from walls by slope: the floor and dune rims read as the
	// game's rust terrain, steep faces as banded cliff rock. Standard lighting
	// (no custom light pass) so shading matches the main demo's terrain.
	// Slope is measured against the ring's local up (packed into vertex color
	// by the mesh builder), not world up — the floor pitches with the descent,
	// and against world up a steep run's floor would read as cliff.
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 ring_up = normalize(COLOR.rgb * 2.0 - 1.0);
	float terrain_mix = smoothstep(terrain_slope_end, terrain_slope_start, dot(world_normal, ring_up));
	vec3 terrain = texture(terrain_texture, world_position.xz * terrain_uv_scale).rgb * terrain_color.rgb;
	ALBEDO = mix(cliff, terrain, terrain_mix);
	ROUGHNESS = surface_roughness;
}
