@tool
class_name CanyonManager
extends Node3D
## Spawns and culls canyon chunks around the player.
##
## In the editor, tweak current_segment / segments_behind / segments_ahead to
## see the course appear and disappear in real-time. At runtime the window
## slides automatically with the player.

const CHUNK_LENGTH: float = 30.0
const ANCHOR_TRANSFORM: Transform3D = Transform3D(
	Basis(Vector3(0, 1, 0), PI), Vector3.ZERO,
)
## Leading chunks generated flat — the spawn pad inside the canyon, before the
## descent eases in.
const FLAT_CHUNKS: int = 1
## How tightly spike stretches localize along the run. Kept low so a spike
## spans several chunks — higher values produce one-chunk jolts.
const SPIKE_NOISE_FREQUENCY: float = 0.04
## Spike noise level where a spike reaches full spike_steepness.
const SPIKE_FULL_NOISE_LEVEL: float = 0.9
## FBM output rarely leaves this band; divide it out so the slope actually
## sweeps the full min/max range instead of hugging the midpoint.
const NOISE_AMPLITUDE: float = 0.7

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

@export_group("Steepness")
@export var min_slope_angle: float = 20.0:
	set(value):
		min_slope_angle = value
		_invalidate()
@export var max_slope_angle: float = 60.0:
	set(value):
		max_slope_angle = value
		_invalidate()
## How quickly steepness wanders along the run; higher is busier.
@export var slope_frequency: float = 0.05:
	set(value):
		slope_frequency = value
		_invalidate()
## Extra degrees added across the rare spike stretches.
@export var spike_steepness: float = 15.0:
	set(value):
		spike_steepness = value
		_invalidate()
## Spike noise level where a spike starts ramping in; higher is rarer.
@export var spike_threshold: float = 0.55:
	set(value):
		spike_threshold = value
		_invalidate()

@export_group("Profile")
@export var half_width: float = 14.0:
	set(value):
		half_width = value
		_invalidate()
@export var wall_height: float = 45.0:
	set(value):
		wall_height = value
		_invalidate()
## 1.0 is a semicircular half-pipe; toward 0.0 the floor flattens and the
## walls steepen into a square channel.
@export_range(0.05, 1.0, 0.01) var corner_rounding: float = 0.18:
	set(value):
		corner_rounding = value
		_invalidate()
@export var rim_width: float = 50.0:
	set(value):
		rim_width = value
		_invalidate()

@export_group("Wall Noise")
@export var wall_noise_amplitude: float = 2.5:
	set(value):
		wall_noise_amplitude = value
		_invalidate()
@export var wall_noise_frequency: float = 0.05:
	set(value):
		wall_noise_frequency = value
		_invalidate()

@export_group("Rim Terrain")
@export var rim_noise_amplitude: float = 3.0:
	set(value):
		rim_noise_amplitude = value
		_invalidate()
@export var rim_noise_frequency: float = 0.01:
	set(value):
		rim_noise_frequency = value
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
@export var segments_ahead: int = 12:
	set(value):
		segments_ahead = maxi(value, 0)
		_sync_window()

@export_group("Runtime Buffers")
@export var buffer_ahead: int = 12
@export var buffer_behind: int = 2

var _loaded_chunks: Dictionary[int, CanyonChunk] = {}
var _chunk_end_transforms: Dictionary[int, Transform3D] = {}
var _slope_noise: FastNoiseLite
var _spike_noise: FastNoiseLite
var _sync_suppressed: bool = false
var _player: Player

func _ready() -> void:
	if chunk_scene == null:
		return
	_chunk_end_transforms[-1] = ANCHOR_TRANSFORM
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
	_slope_noise = null
	_spike_noise = null
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
	for chunk: CanyonChunk in _loaded_chunks.values():
		chunk.free()
	_loaded_chunks.clear()

func _ensure_chain(up_to_index: int) -> void:
	var highest: int = -1
	for index: int in _chunk_end_transforms.keys():
		if index > highest:
			highest = index
	for index: int in range(highest + 1, up_to_index + 1):
		var start: Transform3D = _chunk_end_transforms.get(index - 1, ANCHOR_TRANSFORM)
		var yaw_delta: float = _yaw_for_chunk(index)
		var previous_yaw_delta: float = _yaw_for_chunk(index - 1) if index > 0 else 0.0
		_chunk_end_transforms[index] = CanyonChunk.compute_end_transform(
			start,
			CHUNK_LENGTH,
			_slope_for_chunk(index),
			_slope_for_chunk(index - 1),
			yaw_delta,
			previous_yaw_delta,
		)

func _spawn_chunk(index: int) -> void:
	var start: Transform3D = _chunk_end_transforms.get(index - 1, ANCHOR_TRANSFORM)
	var yaw_delta: float = _yaw_for_chunk(index)
	var previous_yaw_delta: float = _yaw_for_chunk(index - 1) if index > 0 else 0.0
	var chunk: CanyonChunk = chunk_scene.instantiate() as CanyonChunk
	chunk.chunk_index = index
	chunk.name = "CanyonSegment%d" % index
	chunk.half_width = half_width
	chunk.wall_height = wall_height
	chunk.corner_rounding = corner_rounding
	chunk.rim_width = rim_width
	chunk.wall_noise_amplitude = wall_noise_amplitude
	chunk.wall_noise_frequency = wall_noise_frequency
	chunk.rim_noise_amplitude = rim_noise_amplitude
	chunk.rim_noise_frequency = rim_noise_frequency
	chunk.noise_seed = seed_value
	add_child(chunk)
	chunk.generate(
		start,
		CHUNK_LENGTH,
		_slope_for_chunk(index),
		_slope_for_chunk(index - 1),
		yaw_delta,
		previous_yaw_delta,
	)
	_chunk_end_transforms[index] = chunk.end_transform
	_loaded_chunks[index] = chunk

func _yaw_for_chunk(index: int) -> float:
	# Keep the first stretch straight so the spawn looks down an open run.
	if index < 2:
		return 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(seed_value + index)
	return rng.randf_range(-winding_intensity, winding_intensity)

## Steepness is 1D noise sampled at the chunk index and remapped to
## [min_slope_angle, max_slope_angle], so it wanders in smooth gradients. A
## second sparse layer adds occasional steeper spike stretches: only the rare
## peaks of the spike noise clear spike_threshold, and smoothstep eases each
## spike in and out so it never kinks.
func _slope_for_chunk(index: int) -> float:
	if index < FLAT_CHUNKS:
		return 0.0
	_ensure_slope_noise()
	var wander: float = clampf(
		(_slope_noise.get_noise_1d(float(index)) / NOISE_AMPLITUDE + 1.0) * 0.5, 0.0, 1.0,
	)
	var slope: float = lerpf(min_slope_angle, max_slope_angle, wander)
	var spike: float = smoothstep(
		spike_threshold, SPIKE_FULL_NOISE_LEVEL, _spike_noise.get_noise_1d(float(index)),
	)
	return clampf(slope + spike * spike_steepness, min_slope_angle, max_slope_angle)

func _ensure_slope_noise() -> void:
	if _slope_noise != null:
		return
	# Simplex, not Perlin: Perlin is zero at every integer lattice point, which
	# pinned the slope back to the midpoint on a fixed period.
	_slope_noise = FastNoiseLite.new()
	_slope_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	# Two octaves, not three: a third octave varies at chunk scale and reads as
	# per-chunk chatter once stretched over the slope range.
	_slope_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_slope_noise.fractal_octaves = 2
	_slope_noise.frequency = slope_frequency
	_slope_noise.seed = seed_value + 2
	_spike_noise = FastNoiseLite.new()
	_spike_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_spike_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_spike_noise.frequency = SPIKE_NOISE_FREQUENCY
	_spike_noise.seed = seed_value + 3
