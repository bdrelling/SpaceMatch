@tool
class_name HalfpipeRaceChunk
extends StaticBody3D
## A single procedural half-pipe chunk with mesh and collision.

const CROSS_SECTION_SEGMENTS: int = 16
const LENGTH_SEGMENTS: int = 20

var chunk_index: int = 0
var end_transform: Transform3D = Transform3D.IDENTITY


func generate(
	start: Transform3D,
	chunk_length: float,
	half_pipe_radius: float,
	slope_angle_degrees: float,
	yaw_delta: float,
	prev_yaw_delta: float,
) -> void:
	var slope_radians: float = deg_to_rad(slope_angle_degrees)
	var ring_transforms: Array[Transform3D] = _compute_ring_transforms(
		start, chunk_length, slope_radians, yaw_delta, prev_yaw_delta,
	)
	end_transform = ring_transforms[LENGTH_SEGMENTS]
	var mesh: ArrayMesh = _build_mesh(ring_transforms, half_pipe_radius, chunk_length)
	var mesh_instance: MeshInstance3D = %MeshInstance3D as MeshInstance3D
	var collision_shape: CollisionShape3D = %CollisionShape3D as CollisionShape3D
	mesh_instance.mesh = mesh
	var shader: Shader = load("res://demos/halfpipe_race/halfpipe_race_toon.gdshader")
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	mesh_instance.material_override = shader_material
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision_shape.shape = shape


func _compute_ring_transforms(
	start: Transform3D,
	chunk_length: float,
	slope_radians: float,
	yaw_delta: float,
	prev_yaw_delta: float,
) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var step_length: float = chunk_length / float(LENGTH_SEGMENTS)
	var current: Transform3D = start
	transforms.append(current)
	for i: int in range(1, LENGTH_SEGMENTS + 1):
		var previous_t: float = float(i - 1) / float(LENGTH_SEGMENTS)
		var t: float = float(i) / float(LENGTH_SEGMENTS)
		var step_yaw: float = _hermite_yaw(t, prev_yaw_delta, yaw_delta) - _hermite_yaw(previous_t, prev_yaw_delta, yaw_delta)
		var descent: float = -sin(slope_radians) * step_length
		var horizontal: float = cos(slope_radians) * step_length
		var local_offset: Vector3
		if absf(step_yaw) > 0.0001:
			var r: float = horizontal / step_yaw
			local_offset = Vector3(
				r * (1.0 - cos(step_yaw)), descent, r * sin(step_yaw),
			)
		else:
			local_offset = Vector3(0.0, descent, horizontal)
		var yaw_basis: Basis = Basis(Vector3.UP, step_yaw)
		current = Transform3D(
			current.basis * yaw_basis,
			current.origin + current.basis * local_offset,
		)
		transforms.append(current)
	return transforms


static func _hermite_yaw(t: float, previous_yaw: float, yaw: float) -> float:
	var t2: float = t * t
	var t3: float = t2 * t
	return (t3 - 2.0 * t2 + t) * previous_yaw + (-t3 + 2.0 * t2) * yaw


func _build_mesh(
	ring_transforms: Array[Transform3D],
	half_pipe_radius: float,
	chunk_length: float,
) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var cross_count: int = CROSS_SECTION_SEGMENTS + 1
	var length_count: int = LENGTH_SEGMENTS + 1
	var arc_length: float = PI * half_pipe_radius
	var step_length: float = chunk_length / float(LENGTH_SEGMENTS)
	for length_index: int in range(length_count):
		var path_transform: Transform3D = ring_transforms[length_index]
		var path_distance: float = float(chunk_index * LENGTH_SEGMENTS + length_index) * step_length
		for cross_index: int in range(cross_count):
			var cross_fraction: float = float(cross_index) / float(CROSS_SECTION_SEGMENTS)
			var angle: float = PI + PI * cross_fraction
			var local_x: float = cos(angle) * half_pipe_radius
			var local_y: float = sin(angle) * half_pipe_radius + half_pipe_radius
			var local_position: Vector3 = Vector3(local_x, local_y, 0.0)
			var world_position: Vector3 = path_transform * local_position
			vertices.append(world_position)
			var normal_direction: Vector3 = Vector3(-cos(angle), -sin(angle), 0.0)
			var world_normal: Vector3 = (path_transform.basis * normal_direction).normalized()
			normals.append(world_normal)
			uvs.append(Vector2(cross_fraction * arc_length, path_distance))
	for length_index: int in range(LENGTH_SEGMENTS):
		for cross_index: int in range(CROSS_SECTION_SEGMENTS):
			var top_left: int = length_index * cross_count + cross_index
			var top_right: int = top_left + 1
			var bottom_left: int = (length_index + 1) * cross_count + cross_index
			var bottom_right: int = bottom_left + 1
			indices.append(top_left)
			indices.append(bottom_left)
			indices.append(top_right)
			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(bottom_right)
	var surface_array: Array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = indices
	var array_mesh: ArrayMesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return array_mesh
