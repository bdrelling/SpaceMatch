shader_type sky;
// Night sky: vertical gradient, procedural star field, Milky Way band, and a warm
// horizon glow. Every lever is a uniform so an AtmosphereConfig can drive the look.

uniform vec4 sky_top_color : source_color = vec4(0.015, 0.03, 0.08, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.06, 0.1, 0.2, 1.0);
// Lower = harder, more graphic transition between top and horizon.
uniform float sky_curve : hint_range(0.01, 1.0) = 0.25;
uniform vec4 ground_color : source_color = vec4(0.02, 0.015, 0.012, 1.0);

// Residual sunset light hugging the horizon in one compass direction.
uniform vec4 horizon_glow_color : source_color = vec4(0.45, 0.32, 0.2, 1.0);
uniform float horizon_glow_strength : hint_range(0.0, 4.0) = 1.0;
// How far the glow climbs above the horizon (0..1 of the upper hemisphere).
uniform float horizon_glow_height : hint_range(0.01, 1.0) = 0.18;
// Compass direction of the glow, degrees. Glow fades as you look away from it.
uniform float horizon_glow_azimuth_degrees = 150.0;
// How tightly the glow hugs its azimuth; 0 wraps the whole horizon.
uniform float horizon_glow_focus : hint_range(0.0, 8.0) = 2.0;

uniform float star_density : hint_range(0.0, 1.0) = 0.5;
// HDR-capable: >1 keeps stars bloom-ready once glow is enabled.
uniform float star_brightness : hint_range(0.0, 8.0) = 2.0;
uniform float star_twinkle_speed : hint_range(0.0, 4.0) = 0.6;

uniform float milky_way_intensity : hint_range(0.0, 4.0) = 1.0;
uniform vec4 milky_way_color : source_color = vec4(0.5, 0.6, 0.8, 1.0);
uniform float milky_way_width : hint_range(0.05, 1.0) = 0.3;
// Tilt and swing of the galactic band across the sky.
uniform float milky_way_tilt_degrees = 60.0;
uniform float milky_way_rotation_degrees = 0.0;

float hash13(vec3 point) {
	point = fract(point * 0.1031);
	point += dot(point, point.zyx + 31.32);
	return fract((point.x + point.y) * point.z);
}

float noise3(vec3 point) {
	vec3 cell = floor(point);
	vec3 offset = fract(point);
	offset = offset * offset * (3.0 - 2.0 * offset);
	float bottom = mix(
		mix(hash13(cell), hash13(cell + vec3(1, 0, 0)), offset.x),
		mix(hash13(cell + vec3(0, 1, 0)), hash13(cell + vec3(1, 1, 0)), offset.x), offset.y);
	float top = mix(
		mix(hash13(cell + vec3(0, 0, 1)), hash13(cell + vec3(1, 0, 1)), offset.x),
		mix(hash13(cell + vec3(0, 1, 1)), hash13(cell + vec3(1, 1, 1)), offset.x), offset.y);
	return mix(bottom, top, offset.z);
}

float fbm(vec3 point) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise3(point);
		point *= 2.1;
		amplitude *= 0.5;
	}
	return value;
}

// Star layer: cells on the unit sphere, one potential star per cell.
float stars(vec3 direction, float scale, float threshold) {
	vec3 cell = floor(direction * scale);
	float seed = hash13(cell);
	if (seed < threshold) {
		return 0.0;
	}
	vec3 center = (cell + 0.5 + 0.6 * (vec3(hash13(cell + 17.0), hash13(cell + 37.0), hash13(cell + 57.0)) - 0.5)) / scale;
	float distance_to_star = length(direction - normalize(center)) * scale;
	float core = smoothstep(0.35, 0.0, distance_to_star);
	// Per-star size/brightness variation.
	float magnitude = pow(hash13(cell + 71.0), 3.0);
	float twinkle = 1.0 - 0.4 * sin(TIME * star_twinkle_speed * (1.0 + 4.0 * hash13(cell + 91.0)) + seed * 40.0) * step(0.001, star_twinkle_speed);
	return core * core * magnitude * twinkle;
}

vec3 upper_sky(vec3 direction, float elevation, vec3 color) {
	// Milky Way: distance from a tilted great-circle plane, broken up with FBM.
	float tilt = radians(milky_way_tilt_degrees);
	float swing = radians(milky_way_rotation_degrees);
	vec3 band_normal = normalize(vec3(sin(tilt) * cos(swing), cos(tilt), sin(tilt) * sin(swing)));
	float band_distance = abs(dot(direction, band_normal));
	float band = smoothstep(milky_way_width, 0.0, band_distance);
	float band_detail = fbm(direction * 6.0 + 3.0);
	float band_clouds = fbm(direction * 14.0);
	float milky_way = band * band * (0.35 + 0.65 * band_detail) * milky_way_intensity;
	// Dark dust lanes carved out of the bright band.
	milky_way *= 0.55 + 0.45 * smoothstep(0.35, 0.65, band_clouds);
	color += milky_way_color.rgb * milky_way * clamp(elevation * 4.0, 0.0, 1.0);

	// Stars in two scales: dense faint field + sparse bright ones. Denser inside the band.
	float density_boost = 1.0 + band * 1.5;
	float field = stars(direction, 220.0, 1.0 - 0.05 * star_density * density_boost) * 0.5;
	field += stars(direction + 11.0, 90.0, 1.0 - 0.03 * star_density * density_boost);
	// Fade stars into the horizon haze.
	field *= smoothstep(0.0, 0.12, elevation);
	color += vec3(0.9, 0.95, 1.0) * field * star_brightness;

	// Warm horizon glow, focused around one compass direction.
	float azimuth = radians(horizon_glow_azimuth_degrees);
	vec3 glow_direction = vec3(sin(azimuth), 0.0, -cos(azimuth));
	float facing = clamp(dot(normalize(vec3(direction.x, 0.0, direction.z)), glow_direction) * 0.5 + 0.5, 0.0, 1.0);
	float focus = horizon_glow_focus <= 0.001 ? 1.0 : pow(facing, horizon_glow_focus);
	float glow = pow(1.0 - clamp(elevation / horizon_glow_height, 0.0, 1.0), 2.0) * focus;
	color += horizon_glow_color.rgb * glow * horizon_glow_strength;

	return color;
}

void sky() {
	vec3 direction = EYEDIR;
	float elevation = direction.y;

	// Base vertical gradient (upper hemisphere), flat ground color below.
	float gradient = pow(clamp(elevation, 0.0, 1.0), sky_curve);
	vec3 color = mix(sky_horizon_color.rgb, sky_top_color.rgb, gradient);

	if (elevation < 0.0) {
		COLOR = mix(sky_horizon_color.rgb, ground_color.rgb, clamp(-elevation * 12.0, 0.0, 1.0));
	} else {
		COLOR = upper_sky(direction, elevation, color);
	}
}
