shader_type particles;
render_mode disable_velocity, keep_data;

uniform vec3 ground_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 emission_box_extents = vec3(0.28, 0.04, 0.08);
uniform vec3 emission_direction = vec3(0.0, 0.4, 0.6);
uniform float spread_degrees = 55.0;
uniform float initial_velocity_min = 0.2;
uniform float initial_velocity_max = 0.7;
uniform vec3 gravity = vec3(0.0, -1.2, 0.0);
uniform float damping_min = 1.5;
uniform float damping_max = 3.0;
uniform float scale_min = 0.5;
uniform float scale_max = 1.0;

float random(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 spread_direction(vec3 base_direction, float spread_radians, vec2 seed) {
	vec3 axis = normalize(base_direction);
	vec3 helper = abs(axis.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(axis, helper));
	vec3 bitangent = cross(axis, tangent);
	float angle = (random(seed) * 2.0 - 1.0) * spread_radians;
	float azimuth = random(seed + vec2(7.13, 3.71)) * TAU;
	vec3 offset = (cos(azimuth) * tangent + sin(azimuth) * bitangent) * sin(angle);
	return normalize(axis * cos(angle) + offset);
}

void start() {
	float seed = fract(uintBitsToFloat(RANDOM_SEED & 0x7EFFFFFFu));
	vec2 base_seed = vec2(float(INDEX) * 0.137 + seed, float(INDEX) * 0.731 + seed);

	vec3 local_position = vec3(
		(random(base_seed) * 2.0 - 1.0) * emission_box_extents.x,
		(random(base_seed + vec2(1.3, 0.0)) * 2.0 - 1.0) * emission_box_extents.y,
		(random(base_seed + vec2(0.0, 1.7)) * 2.0 - 1.0) * emission_box_extents.z);
	TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(local_position, 1.0)).xyz;

	float spread_radians = radians(spread_degrees);
	vec3 local_direction = spread_direction(emission_direction, spread_radians, base_seed);
	vec3 world_direction = normalize((EMISSION_TRANSFORM * vec4(local_direction, 0.0)).xyz);
	float speed = mix(initial_velocity_min, initial_velocity_max, random(base_seed + vec2(4.2, 9.1)));
	VELOCITY = world_direction * speed;

	float particle_scale = mix(scale_min, scale_max, random(base_seed + vec2(2.5, 6.4)));
	TRANSFORM[0].xyz = vec3(particle_scale, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, particle_scale, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, particle_scale);

	CUSTOM.x = mix(damping_min, damping_max, random(base_seed + vec2(5.5, 1.2)));
	CUSTOM.y = 0.0;
	COLOR = vec4(ground_color, 0.75);
}

void process() {
	VELOCITY += gravity * DELTA;
	float damping = CUSTOM.x;
	float speed = length(VELOCITY);
	if (speed > 0.0) {
		float reduced = max(speed - damping * DELTA, 0.0);
		VELOCITY *= reduced / speed;
	}
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	CUSTOM.y += DELTA / LIFETIME;
	COLOR.a = 0.75 * clamp(1.0 - CUSTOM.y, 0.0, 1.0);
}
