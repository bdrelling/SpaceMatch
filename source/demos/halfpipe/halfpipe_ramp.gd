@tool
class_name HalfpipeRamp
extends StaticBody3D
## A large static skatepark half-pipe: a half-cylinder channel swept along Z,
## with a flat deck along each top lip and a wall closing each open end.

const CROSS_SECTION_SEGMENTS: int = 48
const LENGTH_SEGMENTS: int = 12
const DECK_SEGMENTS: int = 4

## Radius of the half-cylinder channel; the lips sit this high above the floor.
@export var radius: float = 12.0
## Length of the pipe along its axis.
@export var length: float = 60.0
## Width of the flat platform along each top lip.
@export var deck_width: float = 8.0
## How far the end walls extend above deck height.
@export var end_wall_height: float = 8.0

func _ready() -> void:
	_generate()

func _generate() -> void:
	var mesh: ArrayMesh = _build_mesh()
	var mesh_instance: MeshInstance3D = %MeshInstance3D as MeshInstance3D
	var collision_shape: CollisionShape3D = %CollisionShape3D as CollisionShape3D
	mesh_instance.mesh = mesh
	var shader: Shader = load("res://demos/halfpipe/halfpipe_ramp.gdshader")
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	mesh_instance.material_override = shader_material
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision_shape.shape = shape

func _build_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	_append_channel(vertices, normals, uvs, indices)
	_append_deck(-1.0, vertices, normals, uvs, indices)
	_append_deck(1.0, vertices, normals, uvs, indices)
	_append_end_wall(-1.0, vertices, normals, uvs, indices)
	_append_end_wall(1.0, vertices, normals, uvs, indices)
	var surface_array: Array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = indices
	var array_mesh: ArrayMesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return array_mesh

## The semicircular channel interior, lip to lip.
func _append_channel(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
) -> void:
	var first_vertex: int = vertices.size()
	var arc_length: float = PI * radius
	for length_index: int in range(LENGTH_SEGMENTS + 1):
		var z: float = -length * 0.5 + length * float(length_index) / float(LENGTH_SEGMENTS)
		for cross_index: int in range(CROSS_SECTION_SEGMENTS + 1):
			var cross_fraction: float = float(cross_index) / float(CROSS_SECTION_SEGMENTS)
			var angle: float = PI + PI * cross_fraction
			vertices.append(Vector3(cos(angle) * radius, sin(angle) * radius + radius, z))
			normals.append(Vector3(-cos(angle), -sin(angle), 0.0))
			uvs.append(Vector2(cross_fraction * arc_length, z))
	_append_grid_indices(indices, first_vertex, LENGTH_SEGMENTS + 1, CROSS_SECTION_SEGMENTS + 1)

## A flat platform along one top lip. side -1.0 is the -X lip, 1.0 the +X lip.
func _append_deck(
	side: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
) -> void:
	var first_vertex: int = vertices.size()
	var start_x: float = minf(side * radius, side * (radius + deck_width))
	var end_x: float = maxf(side * radius, side * (radius + deck_width))
	for length_index: int in range(LENGTH_SEGMENTS + 1):
		var z: float = -length * 0.5 + length * float(length_index) / float(LENGTH_SEGMENTS)
		for deck_index: int in range(DECK_SEGMENTS + 1):
			var x: float = lerpf(start_x, end_x, float(deck_index) / float(DECK_SEGMENTS))
			vertices.append(Vector3(x, radius, z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(x, z))
	_append_grid_indices(indices, first_vertex, LENGTH_SEGMENTS + 1, DECK_SEGMENTS + 1)

## Closes one open end with a wall from the riding surface up past the decks,
## facing back into the pipe. side -1.0 is the -Z end, 1.0 the +Z end.
func _append_end_wall(
	side: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
) -> void:
	var first_vertex: int = vertices.size()
	var z: float = side * length * 0.5
	var top_y: float = radius + end_wall_height
	var facing: Vector3 = Vector3(0.0, 0.0, -side)
	var profile: PackedVector2Array = _profile_points()
	for point: Vector2 in profile:
		vertices.append(Vector3(point.x, point.y, z))
		vertices.append(Vector3(point.x, top_y, z))
		normals.append(facing)
		normals.append(facing)
		uvs.append(Vector2(point.x, point.y))
		uvs.append(Vector2(point.x, top_y))
	for column: int in range(profile.size() - 1):
		var bottom_here: int = first_vertex + column * 2
		var top_here: int = bottom_here + 1
		var bottom_next: int = bottom_here + 2
		var top_next: int = bottom_here + 3
		if side < 0.0:
			indices.append(bottom_here)
			indices.append(top_here)
			indices.append(bottom_next)
			indices.append(bottom_next)
			indices.append(top_here)
			indices.append(top_next)
		else:
			indices.append(bottom_here)
			indices.append(bottom_next)
			indices.append(top_here)
			indices.append(bottom_next)
			indices.append(top_next)
			indices.append(top_here)

## Riding-surface profile across the full width, left deck outer edge through
## the channel to the right deck outer edge, ordered by ascending X.
func _profile_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for deck_index: int in range(DECK_SEGMENTS):
		var x: float = lerpf(-(radius + deck_width), -radius, float(deck_index) / float(DECK_SEGMENTS))
		points.append(Vector2(x, radius))
	for cross_index: int in range(CROSS_SECTION_SEGMENTS + 1):
		var angle: float = PI + PI * float(cross_index) / float(CROSS_SECTION_SEGMENTS)
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius + radius))
	for deck_index: int in range(1, DECK_SEGMENTS + 1):
		var x: float = lerpf(radius, radius + deck_width, float(deck_index) / float(DECK_SEGMENTS))
		points.append(Vector2(x, radius))
	return points

## Winding makes the channel interior / deck topside the FRONT face — Godot
## flips normals on back faces of double-sided materials, which would invert
## lighting for riders inside the pipe.
static func _append_grid_indices(
	indices: PackedInt32Array,
	first_vertex: int,
	row_count: int,
	column_count: int,
) -> void:
	for row: int in range(row_count - 1):
		for column: int in range(column_count - 1):
			var top_left: int = first_vertex + row * column_count + column
			var top_right: int = top_left + 1
			var bottom_left: int = top_left + column_count
			var bottom_right: int = bottom_left + 1
			indices.append(top_left)
			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(top_right)
			indices.append(bottom_right)
			indices.append(bottom_left)
