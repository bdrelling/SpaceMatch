@tool
class_name CanyonChunk
extends StaticBody3D
## A single procedural canyon chunk with mesh and collision.
##
## The cross-section is the lower half of a superellipse: [member corner_rounding]
## 1.0 reproduces a semicircular half-pipe, lower values square it toward a flat
## floor and steep walls. FBM noise roughens the walls (fading to zero on the
## floor so riding stays smooth), and a dune skirt extends past each rim so the
## channel reads as carved into terrain.

const CROSS_SECTION_SEGMENTS: int = 48
const LENGTH_SEGMENTS: int = 20
const RIM_SEGMENTS: int = 8
const MIN_CORNER_ROUNDING: float = 0.05
const TERRAIN_TEXTURE_PATH: String = "res://demos/canyon/assets/sand_alb_ht.png"

var chunk_index: int = 0
var end_transform: Transform3D = Transform3D.IDENTITY

var half_width: float = 14.0
var wall_height: float = 45.0
var corner_rounding: float = 0.18
var rim_width: float = 50.0
var wall_noise_amplitude: float = 2.5
var wall_noise_frequency: float = 0.05
var rim_noise_amplitude: float = 3.0
var rim_noise_frequency: float = 0.01
var noise_seed: int = 42

var _wall_noise: FastNoiseLite
var _rim_noise: FastNoiseLite

func generate(
	start: Transform3D,
	chunk_length: float,
	slope_angle_degrees: float,
	prev_slope_angle_degrees: float,
	yaw_delta: float,
	prev_yaw_delta: float,
) -> void:
	var slope_radians: float = deg_to_rad(slope_angle_degrees)
	var prev_slope_radians: float = deg_to_rad(prev_slope_angle_degrees)
	var ring_transforms: Array[Transform3D] = compute_ring_transforms(
		start, chunk_length, slope_radians, prev_slope_radians, yaw_delta, prev_yaw_delta,
	)
	end_transform = ring_transforms[LENGTH_SEGMENTS]
	_build_noise()
	var mesh: ArrayMesh = _build_mesh(
		ring_transforms, chunk_length, slope_radians, prev_slope_radians, yaw_delta, prev_yaw_delta,
	)
	var mesh_instance: MeshInstance3D = %MeshInstance3D as MeshInstance3D
	var collision_shape: CollisionShape3D = %CollisionShape3D as CollisionShape3D
	mesh_instance.mesh = mesh
	var shader: Shader = load("res://demos/canyon/canyon_rock.gdshader")
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter(&"terrain_texture", load(TERRAIN_TEXTURE_PATH))
	mesh_instance.material_override = shader_material
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision_shape.shape = shape

static func compute_end_transform(
	start: Transform3D,
	chunk_length: float,
	slope_angle_degrees: float,
	prev_slope_angle_degrees: float,
	yaw_delta: float,
	prev_yaw_delta: float,
) -> Transform3D:
	var ring_transforms: Array[Transform3D] = compute_ring_transforms(
		start,
		chunk_length,
		deg_to_rad(slope_angle_degrees),
		deg_to_rad(prev_slope_angle_degrees),
		yaw_delta,
		prev_yaw_delta,
	)
	return ring_transforms[LENGTH_SEGMENTS]

static func compute_ring_transforms(
	start: Transform3D,
	chunk_length: float,
	slope_radians: float,
	prev_slope_radians: float,
	yaw_delta: float,
	prev_yaw_delta: float,
) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var step_length: float = chunk_length / float(LENGTH_SEGMENTS)
	var current: Transform3D = start
	transforms.append(current)
	for step_index: int in range(LENGTH_SEGMENTS):
		current = current * _step_transform(
			step_index, step_length, slope_radians, prev_slope_radians, yaw_delta, prev_yaw_delta,
		)
		transforms.append(current)
	return transforms

## The local transform from ring step_index to ring step_index + 1. The hermite
## yaw polynomial extrapolates smoothly outside [0, 1], so step_index -1 and
## LENGTH_SEGMENTS yield the ghost steps just beyond the chunk's ends. Pitch
## eases from the previous chunk's slope to this chunk's across the length, so
## a flat pad chunk tips smoothly into the descent.
static func _step_transform(
	step_index: int,
	step_length: float,
	slope_radians: float,
	prev_slope_radians: float,
	yaw_delta: float,
	prev_yaw_delta: float,
) -> Transform3D:
	var previous_t: float = float(step_index) / float(LENGTH_SEGMENTS)
	var t: float = float(step_index + 1) / float(LENGTH_SEGMENTS)
	var step_yaw: float = _hermite_yaw(t, prev_yaw_delta, yaw_delta) - _hermite_yaw(previous_t, prev_yaw_delta, yaw_delta)
	var pitch_t: float = clampf((previous_t + t) * 0.5, 0.0, 1.0)
	var eased: float = pitch_t * pitch_t * (3.0 - 2.0 * pitch_t)
	var pitch_radians: float = lerpf(prev_slope_radians, slope_radians, eased)
	var descent: float = -sin(pitch_radians) * step_length
	var horizontal: float = cos(pitch_radians) * step_length
	var local_offset: Vector3
	if absf(step_yaw) > 0.0001:
		var r: float = horizontal / step_yaw
		local_offset = Vector3(r * (1.0 - cos(step_yaw)), descent, r * sin(step_yaw))
	else:
		local_offset = Vector3(0.0, descent, horizontal)
	return Transform3D(Basis(Vector3.UP, step_yaw), local_offset)

static func _hermite_yaw(t: float, previous_yaw: float, yaw: float) -> float:
	var t2: float = t * t
	var t3: float = t2 * t
	return (t3 - 2.0 * t2 + t) * previous_yaw + (-t3 + 2.0 * t2) * yaw

func _build_noise() -> void:
	_wall_noise = FastNoiseLite.new()
	_wall_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_wall_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_wall_noise.fractal_octaves = 3
	_wall_noise.frequency = wall_noise_frequency
	_wall_noise.seed = noise_seed
	_rim_noise = FastNoiseLite.new()
	_rim_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_rim_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_rim_noise.fractal_octaves = 2
	_rim_noise.frequency = rim_noise_frequency
	_rim_noise.seed = noise_seed + 1

## Lower half of a superellipse, parameterized left rim → floor → right rim.
## At corner_rounding 1.0 this is exactly the half-pipe semicircle (stretched
## to half_width × wall_height); as rounding shrinks the floor flattens and the
## walls steepen toward a box channel.
func _cross_section_point(cross_fraction: float) -> Vector2:
	var rounding: float = clampf(corner_rounding, MIN_CORNER_ROUNDING, 1.0)
	var angle: float = PI + PI * cross_fraction
	var u: float = cos(angle)
	var v: float = sin(angle)
	var x: float = signf(u) * pow(absf(u), rounding) * half_width
	var y: float = (1.0 - pow(absf(v), rounding)) * wall_height
	return Vector2(x, y)

func _cross_section_outward_normal(cross_fraction: float) -> Vector2:
	var epsilon: float = 0.001
	var before: Vector2 = _cross_section_point(clampf(cross_fraction - epsilon, 0.0, 1.0))
	var after: Vector2 = _cross_section_point(clampf(cross_fraction + epsilon, 0.0, 1.0))
	var tangent: Vector2 = (after - before).normalized()
	return Vector2(tangent.y, -tangent.x)

## Channel wall point displaced along the cross-section's outward normal,
## fading to zero near the floor so riding stays smooth.
func _displaced_channel_point(
	base_point: Vector2,
	outward_normal: Vector2,
	arc: float,
	path_distance: float,
) -> Vector2:
	var envelope: float = smoothstep(0.08, 0.5, clampf(base_point.y / wall_height, 0.0, 1.0))
	var noise_value: float = _wall_noise.get_noise_2d(path_distance, arc)
	return base_point + outward_normal * noise_value * wall_noise_amplitude * envelope

func _build_mesh(
	ring_transforms: Array[Transform3D],
	chunk_length: float,
	slope_radians: float,
	prev_slope_radians: float,
	yaw_delta: float,
	prev_yaw_delta: float,
) -> ArrayMesh:
	var cross_count: int = RIM_SEGMENTS * 2 + CROSS_SECTION_SEGMENTS + 1
	var base_points: PackedVector2Array = PackedVector2Array()
	var outward_normals: PackedVector2Array = PackedVector2Array()
	var skirt_fractions: PackedFloat32Array = PackedFloat32Array()
	for cross_index: int in range(cross_count):
		if cross_index < RIM_SEGMENTS:
			var fraction: float = float(RIM_SEGMENTS - cross_index) / float(RIM_SEGMENTS)
			base_points.append(Vector2(-(half_width + rim_width * fraction), wall_height))
			outward_normals.append(Vector2.ZERO)
			skirt_fractions.append(fraction)
		elif cross_index <= RIM_SEGMENTS + CROSS_SECTION_SEGMENTS:
			var cross_fraction: float = float(cross_index - RIM_SEGMENTS) / float(CROSS_SECTION_SEGMENTS)
			base_points.append(_cross_section_point(cross_fraction))
			outward_normals.append(_cross_section_outward_normal(cross_fraction))
			skirt_fractions.append(0.0)
		else:
			var fraction: float = float(cross_index - RIM_SEGMENTS - CROSS_SECTION_SEGMENTS) / float(RIM_SEGMENTS)
			base_points.append(Vector2(half_width + rim_width * fraction, wall_height))
			outward_normals.append(Vector2.ZERO)
			skirt_fractions.append(fraction)
	var arcs: PackedFloat32Array = PackedFloat32Array()
	arcs.append(0.0)
	for cross_index: int in range(1, cross_count):
		arcs.append(arcs[cross_index - 1] + base_points[cross_index].distance_to(base_points[cross_index - 1]))

	# Extend one ghost ring past each end so seam-ring normals accumulate the
	# same faces the neighbouring chunk sees — without this, shading snaps at
	# every chunk boundary.
	var step_length: float = chunk_length / float(LENGTH_SEGMENTS)
	var extended_transforms: Array[Transform3D] = []
	extended_transforms.append(
		ring_transforms[0] * _step_transform(
			-1, step_length, slope_radians, prev_slope_radians, yaw_delta, prev_yaw_delta,
		).affine_inverse()
	)
	extended_transforms.append_array(ring_transforms)
	extended_transforms.append(
		ring_transforms[LENGTH_SEGMENTS] * _step_transform(
			LENGTH_SEGMENTS, step_length, slope_radians, prev_slope_radians, yaw_delta, prev_yaw_delta,
		)
	)

	# Displaced world positions over the extended grid. Both noises sample by
	# global path distance / world position, so chunk seams stay continuous.
	var extended_count: int = LENGTH_SEGMENTS + 3
	var positions: PackedVector3Array = PackedVector3Array()
	for extended_index: int in range(extended_count):
		var path_transform: Transform3D = extended_transforms[extended_index]
		var path_distance: float = float(chunk_index * LENGTH_SEGMENTS + extended_index - 1) * step_length
		for cross_index: int in range(cross_count):
			var local_point: Vector2 = base_points[cross_index]
			var skirt_fraction: float = skirt_fractions[cross_index]
			if skirt_fraction == 0.0:
				local_point = _displaced_channel_point(
					base_points[cross_index], outward_normals[cross_index], arcs[cross_index], path_distance,
				)
			var world_position: Vector3 = path_transform * Vector3(local_point.x, local_point.y, 0.0)
			if skirt_fraction > 0.0:
				# Dune skirt: undulate vertically in world space, ramping in past
				# the rim lip.
				var ramp: float = smoothstep(0.0, 0.4, skirt_fraction)
				world_position.y += _rim_noise.get_noise_2d(world_position.x, world_position.z) * rim_noise_amplitude * ramp
			positions.append(world_position)

	# Accumulate area-weighted face normals over the extended grid (noise
	# displacement breaks analytic normals).
	var extended_normals: PackedVector3Array = PackedVector3Array()
	extended_normals.resize(positions.size())
	for extended_index: int in range(extended_count - 1):
		for cross_index: int in range(cross_count - 1):
			var top_left: int = extended_index * cross_count + cross_index
			var top_right: int = top_left + 1
			var bottom_left: int = (extended_index + 1) * cross_count + cross_index
			var bottom_right: int = bottom_left + 1
			var first: Vector3 = (positions[bottom_left] - positions[top_left]).cross(positions[top_right] - positions[top_left])
			var second: Vector3 = (positions[bottom_left] - positions[top_right]).cross(positions[bottom_right] - positions[top_right])
			extended_normals[top_left] += first
			extended_normals[top_right] += first + second
			extended_normals[bottom_left] += first + second
			extended_normals[bottom_right] += second

	# Emit only the real rings; ghost rings exist solely for normal context.
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for length_index: int in range(LENGTH_SEGMENTS + 1):
		var extended_row: int = length_index + 1
		var path_distance: float = float(chunk_index * LENGTH_SEGMENTS + length_index) * step_length
		# The ring's local up, packed into vertex color so the shader can split
		# terrain from cliff relative to the pitched floor instead of world up —
		# otherwise steep descents repaint the floor as cliff rock.
		var ring_up_color: Color = _direction_color(ring_transforms[length_index].basis.y)
		for cross_index: int in range(cross_count):
			var extended_vertex: int = extended_row * cross_count + cross_index
			vertices.append(positions[extended_vertex])
			var normal: Vector3 = extended_normals[extended_vertex]
			normals.append(normal.normalized() if normal.length_squared() > 0.0 else Vector3.UP)
			uvs.append(Vector2(arcs[cross_index], path_distance))
			colors.append(ring_up_color)
	# Winding makes the channel interior the FRONT face — Godot flips normals
	# on back faces of double-sided materials, which would invert the shader's
	# slope split.
	for length_index: int in range(LENGTH_SEGMENTS):
		for cross_index: int in range(cross_count - 1):
			var top_left: int = length_index * cross_count + cross_index
			var top_right: int = top_left + 1
			var bottom_left: int = (length_index + 1) * cross_count + cross_index
			var bottom_right: int = bottom_left + 1
			indices.append(top_left)
			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(top_right)
			indices.append(bottom_right)
			indices.append(bottom_left)

	if chunk_index == 0:
		_append_head_wall(ring_transforms[0], base_points, outward_normals, skirt_fractions, arcs, vertices, normals, uvs, colors, indices)

	var surface_array: Array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_COLOR] = colors
	surface_array[Mesh.ARRAY_INDEX] = indices
	var array_mesh: ArrayMesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return array_mesh

## A unit direction packed into a color's 0..1 channels.
static func _direction_color(direction: Vector3) -> Color:
	return Color(
		direction.x * 0.5 + 0.5,
		direction.y * 0.5 + 0.5,
		direction.z * 0.5 + 0.5,
	)

## Closes the canyon mouth with a cliff headwall — a curtain from the first
## ring's floor curve up to rim height, so the spawn pad dead-ends like a box
## canyon instead of opening onto the void. Shares the ring's noise-displaced
## edge exactly, so there are no gaps against the walls.
func _append_head_wall(
	anchor: Transform3D,
	base_points: PackedVector2Array,
	outward_normals: PackedVector2Array,
	skirt_fractions: PackedFloat32Array,
	arcs: PackedFloat32Array,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
) -> void:
	# Faces into the canyon (+Z in ring space, matching the path direction).
	var facing: Vector3 = (anchor.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var ring_up_color: Color = _direction_color(anchor.basis.y)
	var first_column: int = vertices.size()
	var column_count: int = 0
	for cross_index: int in range(base_points.size()):
		if skirt_fractions[cross_index] > 0.0:
			continue
		var bottom: Vector2 = _displaced_channel_point(
			base_points[cross_index], outward_normals[cross_index], arcs[cross_index], 0.0,
		)
		vertices.append(anchor * Vector3(bottom.x, bottom.y, 0.0))
		vertices.append(anchor * Vector3(bottom.x, wall_height, 0.0))
		normals.append(facing)
		normals.append(facing)
		uvs.append(Vector2(arcs[cross_index], bottom.y))
		uvs.append(Vector2(arcs[cross_index], wall_height))
		colors.append(ring_up_color)
		colors.append(ring_up_color)
		column_count += 1
	for column: int in range(column_count - 1):
		var bottom_here: int = first_column + column * 2
		var top_here: int = bottom_here + 1
		var bottom_next: int = bottom_here + 2
		var top_next: int = bottom_here + 3
		indices.append(bottom_here)
		indices.append(top_here)
		indices.append(bottom_next)
		indices.append(bottom_next)
		indices.append(top_here)
		indices.append(top_next)
