@tool
class_name OverworldLevel
extends GameLevel

# The heightmap is composed from blended layers: a dune base everywhere, plus
# sparse mountains and sparse valleys. Each feature layer is placed by a low
# frequency field and only rises/sinks where that field clears a threshold, so
# features land irregularly (few tall, several medium, many small) instead of
# being evenly distributed the way a single FBM field is.

# Dune layer — rolling sand across the whole map (the constant base). Smooth:
# low-octave FBM plus a directional wind ripple, no warp. Amplitude is high
# enough that the open desert between features genuinely rolls, not pancakes.
const DUNE_NOISE_FREQUENCY: float = 0.015
const DUNE_WAVE_FREQUENCY: float = 0.04
const DUNE_WAVE_AMPLITUDE: float = 0.3
const DUNE_AMPLITUDE: float = 12.0

# Mountain layer — sparse peaks. Placement is a single-octave low-frequency
# field; a mountain rises only where it clears NOISE_FLOOR, reaching full HEIGHT
# at NOISE_CEIL. The natural spread of placement maxima gives the few-tall /
# many-small hierarchy for free. The smoothstep profile is a smooth dome — no
# per-peak shape noise (that read as lumpy); only the gentle dune base drapes it.
const MOUNTAIN_PLACE_FREQUENCY: float = 0.0021
const MOUNTAIN_NOISE_FLOOR: float = 0.26
const MOUNTAIN_NOISE_CEIL: float = 0.60
const MOUNTAIN_HEIGHT: float = 50.0

# Valley layer — sparse carved basins, same masking idea inverted.
const VALLEY_PLACE_FREQUENCY: float = 0.0015
const VALLEY_NOISE_FLOOR: float = 0.30
const VALLEY_NOISE_CEIL: float = 0.60
const VALLEY_DEPTH: float = 18.0

const SLIDING_WINDOW_RADIUS: int = 2

## Texture slot index in the Terrain3DAssets texture list. Sand is the only
## terrain texture — height alone carries the visual interest.
const TEXTURE_SLOT_SAND: int = 0

enum ChunkSource {
	PROCEDURAL,
	AUTHORED,
}

## Directory Terrain3D persists baked regions to when [member should_cache_chunks]
## is on. The scene's Terrain3D node points its data_directory here.
const CHUNK_CACHE_DIRECTORY: String = "res://levels/overworld_level/chunks/"

@export var terrain_seed: int = 42
@export var terrain_stamps: Array[TerrainStampData] = []

## Scatter configs applied to every procedural chunk: stamps blit into the
## chunk's heightmap during generation, scenes spawn once the chunk is
## imported. Layouts are deterministic from (chunk coordinate, terrain_seed),
## so an evicted chunk regenerates identically. Authored chunks skip scatter.
@export var scatter_configs: Array[ScatterConfig] = []

## When false (default) terrain is regenerated from [member terrain_seed] every
## run and never written to disk — the seed makes it deterministic, and authored
## edits come from stamps, not baked regions. Set true only to bake regions for
## shipping (Terrain3D then saves them to [constant CHUNK_CACHE_DIRECTORY] on
## scene save and reuses them on load).
@export var should_cache_chunks: bool = false

@export var sand_tint: Color = Color(0.893984, 0.572693, 0.405394, 1.0):
	set(value):
		sand_tint = value
		_apply_terrain_tints()

@export var show_checkerboard: bool = false:
	set(value):
		show_checkerboard = value
		if _terrain != null and _terrain.material != null:
			_terrain.material.set_shader_param(&"enable_texturing", not show_checkerboard)

@onready var _terrain: Terrain3D = %Terrain

var _dune_noise: FastNoiseLite
var _mountain_place_noise: FastNoiseLite
var _valley_place_noise: FastNoiseLite
var _loaded_chunks: Dictionary[Vector2i, ChunkSource] = {}
var _last_player_chunk: Vector2i = Vector2i(2147483647, 2147483647)
var _pending_chunks: Dictionary[Vector2i, bool] = {}
var _results_mutex: Mutex = Mutex.new()
var _ready_results: Array[Dictionary] = []
var _chunk_task_ids: Dictionary[Vector2i, int] = {}
## Stamps collected from TerrainStamp nodes in this level's subtree and from
## register_stamp() at runtime. Not serialized — complements the exported
## terrain_stamps array.
var _runtime_stamps: Array[TerrainStampData] = []
## Runtime container for scene instances spawned by scatter placements.
var _scattered_parent: Node3D
## Scene instances spawned per chunk, freed when their chunk is evicted.
var _scattered_nodes: Dictionary[Vector2i, Array] = {}

func _ready() -> void:
	# Detach the save location unless caching is explicitly on, so generated
	# regions stay in memory and never get persisted (Terrain3D's editor plugin
	# only writes regions to a non-empty data_directory on scene save).
	_terrain.data_directory = CHUNK_CACHE_DIRECTORY if should_cache_chunks else ""
	_build_dune_noise()
	_apply_terrain_tints()
	_collect_stamp_nodes()
	if should_cache_chunks:
		_invalidate_stale_chunks()
	if Engine.is_editor_hint():
		_refresh_chunk_window(Vector2i.ZERO, true)
		return
	for stamp: TerrainStampData in terrain_stamps:
		if stamp != null:
			stamp.ensure_images_loaded()
	for config: ScatterConfig in scatter_configs:
		if config != null:
			config.ensure_stamp_images_loaded()
	_refresh_chunk_window(Vector2i.ZERO, true)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if tracking_target == null:
		return
	_apply_ready_chunks()
	_update_chunk_window()

func _exit_tree() -> void:
	for coordinate: Vector2i in _chunk_task_ids.keys():
		WorkerThreadPool.wait_for_task_completion(_chunk_task_ids[coordinate])
	_chunk_task_ids.clear()

func _chunk_world_size() -> float:
	return float(_terrain.get_region_size()) * _terrain.get_vertex_spacing()

func _world_to_chunk(world_position: Vector3) -> Vector2i:
	var chunk_size: float = _chunk_world_size()
	return Vector2i(
		floori(world_position.x / chunk_size),
		floori(world_position.z / chunk_size),
	)

func _update_chunk_window() -> void:
	var player_chunk: Vector2i = _world_to_chunk(tracking_target.global_position)
	if player_chunk == _last_player_chunk:
		return
	_last_player_chunk = player_chunk
	_refresh_chunk_window(player_chunk, false)

func _apply_ready_chunks() -> void:
	_results_mutex.lock()
	if _ready_results.is_empty():
		_results_mutex.unlock()
		return
	var results: Array = _ready_results.duplicate()
	_ready_results.clear()
	_results_mutex.unlock()
	for result: Dictionary in results:
		var coordinate: Vector2i = result["coordinate"]
		var images: Array[Image] = result["images"]
		var origin: Vector3 = result["origin"]
		var placements: Array[ScatterPlacement] = result["placements"]
		_terrain.data.import_images(images, origin, 0.0, 1.0)
		_loaded_chunks[coordinate] = ChunkSource.PROCEDURAL
		_pending_chunks.erase(coordinate)
		_spawn_scatter_scenes(coordinate, placements)
		if _chunk_task_ids.has(coordinate):
			WorkerThreadPool.wait_for_task_completion(_chunk_task_ids[coordinate])
			_chunk_task_ids.erase(coordinate)
	_terrain.data.calc_height_range(true)


func _refresh_chunk_window(center: Vector2i, sync: bool) -> void:
	var radius: int = SLIDING_WINDOW_RADIUS
	var desired: Dictionary[Vector2i, bool] = {}
	for offset_z: int in range(-radius, radius + 1):
		for offset_x: int in range(-radius, radius + 1):
			desired[Vector2i(center.x + offset_x, center.y + offset_z)] = true
	var any_change: bool = false
	for coordinate: Vector2i in desired.keys():
		if _loaded_chunks.has(coordinate) or _pending_chunks.has(coordinate):
			continue
		if sync:
			_loaded_chunks[coordinate] = _load_chunk(coordinate)
			any_change = true
		else:
			var chunk_size: float = _chunk_world_size()
			var origin: Vector3 = Vector3(float(coordinate.x) * chunk_size, 0.0, float(coordinate.y) * chunk_size)
			if _terrain.data.has_regionp(origin):
				_loaded_chunks[coordinate] = ChunkSource.AUTHORED
			else:
				_pending_chunks[coordinate] = true
				_dispatch_chunk_generation(coordinate, origin)
	var evict: Array[Vector2i] = []
	for coordinate: Vector2i in _loaded_chunks.keys():
		if desired.has(coordinate):
			continue
		if _loaded_chunks[coordinate] == ChunkSource.AUTHORED:
			continue
		evict.append(coordinate)
	for coordinate: Vector2i in evict:
		_evict_chunk(coordinate)
		_loaded_chunks.erase(coordinate)
		any_change = true
	if any_change:
		_terrain.data.calc_height_range(true)


func _dispatch_chunk_generation(coordinate: Vector2i, origin: Vector3) -> void:
	var region_size: int = _terrain.get_region_size()
	var vertex_spacing: float = _terrain.get_vertex_spacing()
	var chunk_size: float = _chunk_world_size()
	var origin_x: float = origin.x
	var origin_z: float = origin.z
	# Plan on the main thread — cheap pure math — so the worker only reads.
	var chunk_rectangle: Rect2 = Rect2(Vector2(origin_x, origin_z), Vector2(chunk_size, chunk_size))
	var placements: Array[ScatterPlacement] = ScatterPlanner.plan_chunk(scatter_configs, coordinate, terrain_seed, chunk_rectangle)
	var scatter_stamps: Array[TerrainStampData] = _scatter_stamps_for_chunk(coordinate, chunk_rectangle)
	var task_id: int = WorkerThreadPool.add_task(func() -> void:
		var height_image: Image = _build_height_image(region_size, vertex_spacing, origin_x, origin_z)
		_apply_stamps_to_chunk(height_image, region_size, vertex_spacing, origin_x, origin_z, chunk_size, scatter_stamps)
		var control_image: Image = _build_control_image(region_size)
		var images: Array[Image] = []
		images.resize(Terrain3DRegion.TYPE_MAX)
		images[Terrain3DRegion.TYPE_HEIGHT] = height_image
		images[Terrain3DRegion.TYPE_CONTROL] = control_image
		_results_mutex.lock()
		_ready_results.append({"coordinate": coordinate, "images": images, "origin": origin, "placements": placements})
		_results_mutex.unlock()
	)
	_chunk_task_ids[coordinate] = task_id

func _load_chunk(coordinate: Vector2i) -> ChunkSource:
	var chunk_size: float = _chunk_world_size()
	var origin_x: float = float(coordinate.x) * chunk_size
	var origin_z: float = float(coordinate.y) * chunk_size
	var origin: Vector3 = Vector3(origin_x, 0.0, origin_z)
	if _terrain.data.has_regionp(origin):
		return ChunkSource.AUTHORED
	var region_size: int = _terrain.get_region_size()
	var vertex_spacing: float = _terrain.get_vertex_spacing()
	var chunk_rectangle: Rect2 = Rect2(Vector2(origin_x, origin_z), Vector2(chunk_size, chunk_size))
	var placements: Array[ScatterPlacement] = ScatterPlanner.plan_chunk(scatter_configs, coordinate, terrain_seed, chunk_rectangle)
	var height_image: Image = _build_height_image(region_size, vertex_spacing, origin_x, origin_z)
	_apply_stamps_to_chunk(height_image, region_size, vertex_spacing, origin_x, origin_z, chunk_size, _scatter_stamps_for_chunk(coordinate, chunk_rectangle))
	var control_image: Image = _build_control_image(region_size)
	var images: Array[Image] = []
	images.resize(Terrain3DRegion.TYPE_MAX)
	images[Terrain3DRegion.TYPE_HEIGHT] = height_image
	images[Terrain3DRegion.TYPE_CONTROL] = control_image
	_terrain.data.import_images(images, origin, 0.0, 1.0)
	_spawn_scatter_scenes(coordinate, placements)
	return ChunkSource.PROCEDURAL

func _evict_chunk(coordinate: Vector2i) -> void:
	var chunk_size: float = _chunk_world_size()
	var center_x: float = (float(coordinate.x) + 0.5) * chunk_size
	var center_z: float = (float(coordinate.y) + 0.5) * chunk_size
	_terrain.data.remove_regionp(Vector3(center_x, 0.0, center_z), false)
	if _scattered_nodes.has(coordinate):
		for node: Node3D in _scattered_nodes[coordinate]:
			if is_instance_valid(node):
				node.queue_free()
		_scattered_nodes.erase(coordinate)

func _build_height_image(
	region_size: int,
	vertex_spacing: float,
	origin_x: float,
	origin_z: float,
) -> Image:
	var image: Image = Image.create_empty(region_size, region_size, false, Image.FORMAT_RF)
	for pixel_z: int in range(region_size):
		var world_z: float = origin_z + float(pixel_z) * vertex_spacing
		for pixel_x: int in range(region_size):
			var world_x: float = origin_x + float(pixel_x) * vertex_spacing
			var height: float = _sample_dune_height(world_x, world_z)
			image.set_pixel(pixel_x, pixel_z, Color(height, 0.0, 0.0, 1.0))
	return image

func _apply_stamps_to_chunk(
	height_image: Image,
	region_size: int,
	vertex_spacing: float,
	origin_x: float,
	origin_z: float,
	chunk_size: float,
	scatter_stamps: Array[TerrainStampData],
) -> void:
	if terrain_stamps.is_empty() and _runtime_stamps.is_empty() and scatter_stamps.is_empty():
		return
	var chunk_rectangle: Rect2 = Rect2(Vector2(origin_x, origin_z), Vector2(chunk_size, chunk_size))
	for stamp: TerrainStampData in terrain_stamps + _runtime_stamps + scatter_stamps:
		if stamp == null:
			continue
		if not stamp.overlaps_chunk(chunk_rectangle):
			continue
		stamp.ensure_images_loaded()
		var stamp_rectangle: Rect2 = stamp.get_world_rectangle()
		var min_world_x: float = max(chunk_rectangle.position.x, stamp_rectangle.position.x)
		var min_world_z: float = max(chunk_rectangle.position.y, stamp_rectangle.position.y)
		var max_world_x: float = min(chunk_rectangle.position.x + chunk_rectangle.size.x, stamp_rectangle.position.x + stamp_rectangle.size.x)
		var max_world_z: float = min(chunk_rectangle.position.y + chunk_rectangle.size.y, stamp_rectangle.position.y + stamp_rectangle.size.y)
		var pixel_min_x: int = clampi(floori((min_world_x - origin_x) / vertex_spacing), 0, region_size - 1)
		var pixel_min_z: int = clampi(floori((min_world_z - origin_z) / vertex_spacing), 0, region_size - 1)
		var pixel_max_x: int = clampi(ceili((max_world_x - origin_x) / vertex_spacing), 0, region_size - 1)
		var pixel_max_z: int = clampi(ceili((max_world_z - origin_z) / vertex_spacing), 0, region_size - 1)
		for pixel_z: int in range(pixel_min_z, pixel_max_z + 1):
			var world_z: float = origin_z + float(pixel_z) * vertex_spacing
			for pixel_x: int in range(pixel_min_x, pixel_max_x + 1):
				var world_x: float = origin_x + float(pixel_x) * vertex_spacing
				var sample: Vector2 = stamp.sample_at_world(world_x, world_z)
				var alpha: float = sample.y
				if alpha <= 0.0:
					continue
				var current_height: float = height_image.get_pixel(pixel_x, pixel_z).r
				var blended: float = lerpf(current_height, sample.x, alpha)
				height_image.set_pixel(pixel_x, pixel_z, Color(blended, 0.0, 0.0, 1.0))

func _sample_dune_height(x: float, z: float) -> float:
	# Dune base — gentle rolling sand everywhere.
	var raw: float = _dune_noise.get_noise_2d(x, z)
	var ripple: float = sin((x + z) * DUNE_WAVE_FREQUENCY + raw * 1.6) * DUNE_WAVE_AMPLITUDE
	var dunes: float = (raw + ripple) * DUNE_AMPLITUDE
	# Mountain layer — rises only past the placement floor; height scales with how
	# far past it, so rare high maxima are tall and common ones are small. The
	# smoothstep gives a smooth dome profile.
	var m_peak: float = smoothstep(MOUNTAIN_NOISE_FLOOR, MOUNTAIN_NOISE_CEIL, _mountain_place_noise.get_noise_2d(x, z))
	var mountains: float = m_peak * MOUNTAIN_HEIGHT
	# Valley layer — sparse carved basins.
	var v_peak: float = smoothstep(VALLEY_NOISE_FLOOR, VALLEY_NOISE_CEIL, _valley_place_noise.get_noise_2d(x, z))
	var valleys: float = v_peak * VALLEY_DEPTH
	return dunes + mountains - valleys

func _apply_terrain_tints() -> void:
	if _terrain == null:
		return
	var assets: Terrain3DAssets = _terrain.assets as Terrain3DAssets
	if assets == null:
		return
	var sand_texture: Terrain3DTextureAsset = assets.get_texture(TEXTURE_SLOT_SAND) as Terrain3DTextureAsset
	if sand_texture != null:
		sand_texture.albedo_color = sand_tint

## Uniform clay across the whole chunk. The terrain is a single-texture clay
## field; height alone (dunes, craters) carries the visual interest.
func _build_control_image(region_size: int) -> Image:
	var image: Image = Image.create_empty(region_size, region_size, false, Image.FORMAT_RF)
	var clay: float = _uint_to_float(_encode_control_pixel(TEXTURE_SLOT_SAND, TEXTURE_SLOT_SAND, 0.0))
	image.fill(Color(clay, 0.0, 0.0, 1.0))
	return image

func _encode_control_pixel(base_id: int, overlay_id: int, blend_weight: float) -> int:
	var blend_byte: int = clampi(roundi(blend_weight * 255.0), 0, 255)
	return ((base_id & 0x1F) << 27) | ((overlay_id & 0x1F) << 22) | ((blend_byte & 0xFF) << 14)

static func _uint_to_float(value: int) -> float:
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(4)
	buffer.encode_u32(0, value)
	return buffer.decode_float(0)

## Register a stamp whose world_position is already set. If chunks that
## overlap its footprint are already loaded they are evicted and re-queued so
## the stamp appears on next generation. Call before terrain loads when
## possible to avoid the eviction cost.
func register_stamp(stamp: TerrainStampData) -> void:
	if stamp == null:
		return
	stamp.ensure_images_loaded()
	_runtime_stamps.append(stamp)
	_evict_stamp_footprint(stamp)

## Convenience wrapper: duplicates the resource, sets world_position to the
## XZ of [param at] (Y is ignored), then calls register_stamp.
func add_stamp_at(stamp: TerrainStampData, at: Vector3) -> void:
	var s: TerrainStampData = stamp.duplicate() as TerrainStampData
	s.world_position = Vector3(at.x, 0.0, at.z)
	register_stamp(s)

## Walks this level's own subtree and collects every TerrainStamp node as a
## resolved TerrainStampData (world_position taken from the node's transform).
## No global SceneTree/group scan — the level only owns stamps placed under it.
func _collect_stamp_nodes() -> void:
	_gather_stamp_nodes(self)

func _gather_stamp_nodes(node: Node) -> void:
	for child: Node in node.get_children():
		if child is TerrainStamp:
			var stamp_node: TerrainStamp = child as TerrainStamp
			if stamp_node.stamp != null:
				var s: TerrainStampData = stamp_node.stamp.duplicate() as TerrainStampData
				s.world_position = Vector3(stamp_node.global_position.x, 0.0, stamp_node.global_position.z)
				s.ensure_images_loaded()
				_runtime_stamps.append(s)
		_gather_stamp_nodes(child)

## Scatter stamps from this chunk's plan plus any neighbour-planned stamps
## whose footprint spills across the border, so a stamp near a chunk edge blits
## identically into every chunk it touches. Neighbour radius is one chunk:
## footprints wider than a chunk may clip at the second border.
func _scatter_stamps_for_chunk(coordinate: Vector2i, chunk_rectangle: Rect2) -> Array[TerrainStampData]:
	var stamps: Array[TerrainStampData] = []
	if scatter_configs.is_empty():
		return stamps
	var chunk_size: float = _chunk_world_size()
	for offset_z: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var neighbour: Vector2i = coordinate + Vector2i(offset_x, offset_z)
			var neighbour_rectangle: Rect2 = Rect2(
				Vector2(float(neighbour.x) * chunk_size, float(neighbour.y) * chunk_size),
				Vector2(chunk_size, chunk_size),
			)
			for placement: ScatterPlacement in ScatterPlanner.plan_chunk(scatter_configs, neighbour, terrain_seed, neighbour_rectangle):
				var stamp: TerrainStampData = placement.make_stamp()
				if stamp != null and stamp.overlaps_chunk(chunk_rectangle):
					stamps.append(stamp)
	return stamps

## Spawns the scene halves of a chunk's scatter placements, snapped to the
## terrain height at their position. Runtime only — editor chunk previews show
## scatter stamps but not scenes.
func _spawn_scatter_scenes(coordinate: Vector2i, placements: Array[ScatterPlacement]) -> void:
	if Engine.is_editor_hint() or placements.is_empty():
		return
	var spawned: Array[Node3D] = []
	for placement: ScatterPlacement in placements:
		if placement.entry == null or placement.entry.scene == null:
			continue
		var instance: Node3D = placement.entry.scene.instantiate() as Node3D
		if instance == null:
			continue
		if _scattered_parent == null:
			_scattered_parent = Node3D.new()
			_scattered_parent.name = "Scattered"
			add_child(_scattered_parent)
		_scattered_parent.add_child(instance)
		var ground_height: float = _terrain.data.get_height(placement.position)
		if is_nan(ground_height):
			ground_height = 0.0
		instance.global_position = Vector3(placement.position.x, ground_height, placement.position.z)
		instance.rotate_y(deg_to_rad(placement.rotation_degrees))
		instance.scale *= placement.scale
		spawned.append(instance)
	if not spawned.is_empty():
		_scattered_nodes[coordinate] = spawned

func _evict_stamp_footprint(stamp: TerrainStampData) -> void:
	var chunk_size: float = _chunk_world_size()
	var rectangle: Rect2 = stamp.get_world_rectangle()
	var evicted: bool = false
	for coordinate: Vector2i in _loaded_chunks.keys():
		if _loaded_chunks[coordinate] == ChunkSource.AUTHORED:
			continue
		var chunk_rectangle: Rect2 = Rect2(
			Vector2(float(coordinate.x) * chunk_size, float(coordinate.y) * chunk_size),
			Vector2(chunk_size, chunk_size),
		)
		if rectangle.intersects(chunk_rectangle):
			_evict_chunk(coordinate)
			_loaded_chunks.erase(coordinate)
			evicted = true
	if evicted:
		_terrain.data.calc_height_range(true)
		_refresh_chunk_window(_last_player_chunk, false)

func _terrain_generation_key() -> int:
	var key: String = "%d|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f" % [
		terrain_seed,
		DUNE_NOISE_FREQUENCY,
		DUNE_WAVE_FREQUENCY,
		DUNE_WAVE_AMPLITUDE,
		DUNE_AMPLITUDE,
		MOUNTAIN_PLACE_FREQUENCY,
		MOUNTAIN_NOISE_FLOOR,
		MOUNTAIN_NOISE_CEIL,
		MOUNTAIN_HEIGHT,
		VALLEY_PLACE_FREQUENCY,
		VALLEY_NOISE_FLOOR,
		VALLEY_NOISE_CEIL,
		VALLEY_DEPTH,
	]
	for config: ScatterConfig in scatter_configs:
		key += "|" + (config.cache_key() if config != null else "null")
	return key.hash()

func _invalidate_stale_chunks() -> void:
	var directory_path: String = _terrain.data_directory
	var key_path: String = directory_path.path_join(".gen_key")
	var current_key: int = _terrain_generation_key()
	var file: FileAccess = FileAccess.open(key_path, FileAccess.READ)
	if file != null:
		var stored_key: int = file.get_64()
		file.close()
		if stored_key == current_key:
			return
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory != null:
		for fname: String in directory.get_files():
			if fname.ends_with(".res"):
				directory.remove(fname)
	var write_file: FileAccess = FileAccess.open(key_path, FileAccess.WRITE)
	if write_file != null:
		write_file.store_64(current_key)
		write_file.close()

func _build_dune_noise() -> void:
	# Dune base — smooth low-octave FBM.
	_dune_noise = FastNoiseLite.new()
	_dune_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_dune_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_dune_noise.frequency = DUNE_NOISE_FREQUENCY
	_dune_noise.fractal_octaves = 2
	_dune_noise.fractal_gain = 0.35
	_dune_noise.seed = terrain_seed

	# Mountain placement — single-octave low-freq field with clean, separated
	# maxima so mountains land sparsely.
	_mountain_place_noise = FastNoiseLite.new()
	_mountain_place_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_mountain_place_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_mountain_place_noise.frequency = MOUNTAIN_PLACE_FREQUENCY
	_mountain_place_noise.seed = terrain_seed + 1

	# Valley placement — single-octave low-freq field for sparse basins.
	_valley_place_noise = FastNoiseLite.new()
	_valley_place_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_valley_place_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_valley_place_noise.frequency = VALLEY_PLACE_FREQUENCY
	_valley_place_noise.seed = terrain_seed + 3
