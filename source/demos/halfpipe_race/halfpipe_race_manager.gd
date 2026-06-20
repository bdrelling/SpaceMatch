@tool
class_name HalfpipeRaceManager
extends Node3D
## Spawns and culls half-pipe chunks around the player.
##
## In the editor, tweak current_segment / segments_behind / segments_ahead to
## see the course appear and disappear in real-time. At runtime the window
## slides automatically with the player.

const CHUNK_LENGTH: float = 30.0
const ANCHOR_TRANSFORM: Transform3D = Transform3D(
	Basis(Vector3(0, 1, 0), PI), Vector3.ZERO,
)

@export var slope_angle: float = 20.0:
	set(value):
		slope_angle = value
		_invalidate()
@export var half_pipe_radius: float = 5.0:
	set(value):
		half_pipe_radius = value
		_invalidate()
@export var winding_intensity: float = 0.3:
	set(value):
		winding_intensity = value
		_invalidate()
@export var seed_value: int = 42:
	set(value):
		seed_value = value
		_invalidate()
@export var chunk_scene: PackedScene:
	set(value):
		chunk_scene = value
		_invalidate()

@export_group("Segment Window")
@export var current_segment: int = 0:
	set(value):
		current_segment = value
		_sync_window()
@export var segments_behind: int = 2:
	set(value):
		segments_behind = maxi(value, 0)
		_sync_window()
@export var segments_ahead: int = 5:
	set(value):
		segments_ahead = maxi(value, 0)
		_sync_window()

@export_group("Runtime Buffers")
@export var buffer_ahead: int = 5
@export var buffer_behind: int = 2

var _loaded_chunks: Dictionary[int, HalfpipeRaceChunk] = {}
var _chunk_end_transforms: Dictionary[int, Transform3D] = {}
var _spawn_platform: StaticBody3D
var _sync_suppressed: bool = false
var _player: Player


func _ready() -> void:
	if chunk_scene == null:
		return
	_chunk_end_transforms[-1] = ANCHOR_TRANSFORM
	_build_spawn_platform()
	_sync_window()


func setup(player: Player) -> void:
	_player = player
	_sync_suppressed = true
	segments_behind = buffer_behind
	segments_ahead = buffer_ahead
	_sync_suppressed = false
	current_segment = 0


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null:
		return
	var player_chunk: int = _estimate_player_chunk()
	if player_chunk != current_segment:
		current_segment = player_chunk


func _estimate_player_chunk() -> int:
	var best_chunk: int = 0
	var best_distance: float = INF
	for chunk_index: int in _loaded_chunks.keys():
		var chunk_start: Vector3 = _chunk_end_transforms.get(
			chunk_index - 1, ANCHOR_TRANSFORM,
		).origin
		var chunk_end: Vector3 = _chunk_end_transforms.get(
			chunk_index, ANCHOR_TRANSFORM,
		).origin
		var midpoint: Vector3 = (chunk_start + chunk_end) * 0.5
		var distance: float = _player.global_position.distance_squared_to(midpoint)
		if distance < best_distance:
			best_distance = distance
			best_chunk = chunk_index
	return best_chunk


func _invalidate() -> void:
	_evict_all()
	_chunk_end_transforms.clear()
	_chunk_end_transforms[-1] = ANCHOR_TRANSFORM
	_build_spawn_platform()
	_sync_window()


func _sync_window() -> void:
	if _sync_suppressed:
		return
	if not is_inside_tree():
		return
	if chunk_scene == null:
		return
	var start_index: int = maxi(0, current_segment - segments_behind)
	var end_index: int = current_segment + segments_ahead
	for index: int in _loaded_chunks.keys():
		if index < start_index or index > end_index:
			_loaded_chunks[index].free()
			_loaded_chunks.erase(index)
	_ensure_chain(end_index)
	for index: int in range(start_index, end_index + 1):
		if not _loaded_chunks.has(index):
			_spawn_chunk(index)


func _evict_all() -> void:
	for chunk: HalfpipeRaceChunk in _loaded_chunks.values():
		chunk.free()
	_loaded_chunks.clear()
	if is_instance_valid(_spawn_platform):
		_spawn_platform.free()
		_spawn_platform = null


func _ensure_chain(up_to_index: int) -> void:
	var highest: int = -1
	for index: int in _chunk_end_transforms.keys():
		if index > highest:
			highest = index
	for index: int in range(highest + 1, up_to_index + 1):
		var start: Transform3D = _chunk_end_transforms.get(index - 1, ANCHOR_TRANSFORM)
		var yaw_delta: float = _yaw_for_chunk(index)
		var previous_yaw_delta: float = _yaw_for_chunk(index - 1) if index > 0 else 0.0
		_chunk_end_transforms[index] = _compute_end_transform(start, yaw_delta, previous_yaw_delta)


func _spawn_chunk(index: int) -> void:
	var start: Transform3D = _chunk_end_transforms.get(index - 1, ANCHOR_TRANSFORM)
	var yaw_delta: float = _yaw_for_chunk(index)
	var previous_yaw_delta: float = _yaw_for_chunk(index - 1) if index > 0 else 0.0
	var chunk: HalfpipeRaceChunk = chunk_scene.instantiate() as HalfpipeRaceChunk
	chunk.chunk_index = index
	chunk.name = "HalfpipeRaceSegment%d" % index
	add_child(chunk)
	chunk.generate(
		start, CHUNK_LENGTH, half_pipe_radius, slope_angle, yaw_delta, previous_yaw_delta,
	)
	_chunk_end_transforms[index] = chunk.end_transform
	_loaded_chunks[index] = chunk


func _compute_end_transform(
	start: Transform3D, yaw_delta: float, previous_yaw_delta: float,
) -> Transform3D:
	var slope_radians: float = deg_to_rad(slope_angle)
	var step_length: float = CHUNK_LENGTH / float(HalfpipeRaceChunk.LENGTH_SEGMENTS)
	var current: Transform3D = start
	for i: int in range(1, HalfpipeRaceChunk.LENGTH_SEGMENTS + 1):
		var previous_t: float = float(i - 1) / float(HalfpipeRaceChunk.LENGTH_SEGMENTS)
		var t: float = float(i) / float(HalfpipeRaceChunk.LENGTH_SEGMENTS)
		var step_yaw: float = (
			HalfpipeRaceChunk._hermite_yaw(t, previous_yaw_delta, yaw_delta)
			- HalfpipeRaceChunk._hermite_yaw(previous_t, previous_yaw_delta, yaw_delta)
		)
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
	return current


func _build_spawn_platform() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_spawn_platform):
		_spawn_platform.free()
		_spawn_platform = null
	var diameter: float = half_pipe_radius * 2.0
	var thickness: float = 0.5
	_spawn_platform = StaticBody3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(diameter, thickness, diameter)
	mesh_instance.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.33, 0.32)
	material.roughness = 0.9
	mesh_instance.material_override = material
	_spawn_platform.add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = box.size
	collision.shape = box_shape
	_spawn_platform.add_child(collision)
	_spawn_platform.position = Vector3(0.0, -thickness * 0.5, 0.0)
	add_child(_spawn_platform)


func _yaw_for_chunk(index: int) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(seed_value + index)
	return rng.randf_range(-winding_intensity, winding_intensity)
