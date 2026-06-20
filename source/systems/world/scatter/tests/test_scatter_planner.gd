extends GdUnitTestSuite
## Determinism, bounds, and pool guarantees for chunk scatter planning.

const CHUNK_RECTANGLE: Rect2 = Rect2(Vector2(256.0, -512.0), Vector2(256.0, 256.0))
const LEVEL_SEED: int = 42

const ALL_DISTRIBUTIONS: Array[ScatterConfig.Distribution] = [
	ScatterConfig.Distribution.EVENLY_SCATTERED,
	ScatterConfig.Distribution.CLUSTERED,
	ScatterConfig.Distribution.SPARSE,
]

func _stamp_entry() -> ScatterEntry:
	var entry: ScatterEntry = ScatterEntry.new()
	entry.stamp = TerrainStampData.new()
	return entry

func _config(distribution: ScatterConfig.Distribution, min_count: int, max_count: int) -> ScatterConfig:
	var config: ScatterConfig = ScatterConfig.new()
	config.pool = [_stamp_entry()]
	config.distribution = distribution
	config.min_count = min_count
	config.max_count = max_count
	return config

func _layout_signature(placements: Array[ScatterPlacement]) -> String:
	var parts: Array[String] = []
	for placement: ScatterPlacement in placements:
		parts.append("%.5f,%.5f|%.3f|%.3f" % [
			placement.position.x,
			placement.position.z,
			placement.rotation_degrees,
			placement.scale,
		])
	return ";".join(parts)

func test_same_inputs_reproduce_identical_layout() -> void:
	var configs: Array[ScatterConfig] = [
		_config(ScatterConfig.Distribution.EVENLY_SCATTERED, 2, 5),
		_config(ScatterConfig.Distribution.CLUSTERED, 1, 4),
		_config(ScatterConfig.Distribution.SPARSE, 0, 3),
	]
	var first: Array[ScatterPlacement] = ScatterPlanner.plan_chunk(configs, Vector2i(3, -7), LEVEL_SEED, CHUNK_RECTANGLE)
	var second: Array[ScatterPlacement] = ScatterPlanner.plan_chunk(configs, Vector2i(3, -7), LEVEL_SEED, CHUNK_RECTANGLE)
	assert_str(_layout_signature(second)).is_equal(_layout_signature(first))
	for index: int in first.size():
		assert_object(second[index].entry).is_same(first[index].entry)

func test_different_chunks_yield_different_layouts() -> void:
	var configs: Array[ScatterConfig] = [_config(ScatterConfig.Distribution.EVENLY_SCATTERED, 4, 4)]
	var here: Array[ScatterPlacement] = ScatterPlanner.plan_chunk(configs, Vector2i.ZERO, LEVEL_SEED, CHUNK_RECTANGLE)
	var there: Array[ScatterPlacement] = ScatterPlanner.plan_chunk(configs, Vector2i(1, 0), LEVEL_SEED, CHUNK_RECTANGLE)
	assert_str(_layout_signature(there)).is_not_equal(_layout_signature(here))

func test_count_stays_within_inclusive_bounds() -> void:
	for distribution: ScatterConfig.Distribution in ALL_DISTRIBUTIONS:
		var configs: Array[ScatterConfig] = [_config(distribution, 2, 5)]
		for chunk_x: int in range(-3, 4):
			for chunk_z: int in range(-3, 4):
				var count: int = ScatterPlanner.plan_chunk(configs, Vector2i(chunk_x, chunk_z), LEVEL_SEED, CHUNK_RECTANGLE).size()
				assert_int(count).is_between(2, 5)

func test_equal_bounds_yield_exact_count() -> void:
	for distribution: ScatterConfig.Distribution in ALL_DISTRIBUTIONS:
		var configs: Array[ScatterConfig] = [_config(distribution, 3, 3)]
		assert_int(ScatterPlanner.plan_chunk(configs, Vector2i(5, 9), LEVEL_SEED, CHUNK_RECTANGLE).size()).is_equal(3)

func test_positions_stay_inside_chunk() -> void:
	var grown: Rect2 = CHUNK_RECTANGLE.grow(0.001)
	for distribution: ScatterConfig.Distribution in ALL_DISTRIBUTIONS:
		var configs: Array[ScatterConfig] = [_config(distribution, 8, 8)]
		for placement: ScatterPlacement in ScatterPlanner.plan_chunk(configs, Vector2i(-2, 6), LEVEL_SEED, CHUNK_RECTANGLE):
			assert_bool(grown.has_point(Vector2(placement.position.x, placement.position.z))).is_true()

func test_scale_stays_within_inclusive_bounds() -> void:
	var config: ScatterConfig = _config(ScatterConfig.Distribution.EVENLY_SCATTERED, 6, 6)
	config.min_scale = 0.5
	config.max_scale = 2.0
	var configs: Array[ScatterConfig] = [config]
	for placement: ScatterPlacement in ScatterPlanner.plan_chunk(configs, Vector2i(7, 7), LEVEL_SEED, CHUNK_RECTANGLE):
		assert_float(placement.scale).is_between(0.5, 2.0)

func test_invalid_pool_yields_nothing() -> void:
	var config: ScatterConfig = _config(ScatterConfig.Distribution.EVENLY_SCATTERED, 2, 2)
	config.pool = [null, ScatterEntry.new()]
	var configs: Array[ScatterConfig] = [config]
	assert_array(ScatterPlanner.plan_chunk(configs, Vector2i.ZERO, LEVEL_SEED, CHUNK_RECTANGLE)).is_empty()

func test_null_config_is_skipped() -> void:
	var configs: Array[ScatterConfig] = [null, _config(ScatterConfig.Distribution.EVENLY_SCATTERED, 1, 1)]
	assert_int(ScatterPlanner.plan_chunk(configs, Vector2i.ZERO, LEVEL_SEED, CHUNK_RECTANGLE).size()).is_equal(1)

func test_make_stamp_applies_placement_transform() -> void:
	var entry: ScatterEntry = _stamp_entry()
	var placement: ScatterPlacement = ScatterPlacement.new()
	placement.entry = entry
	placement.position = Vector3(12.0, 0.0, -8.0)
	placement.rotation_degrees = 45.0
	placement.scale = 1.5
	var stamp: TerrainStampData = placement.make_stamp()
	assert_vector(stamp.world_position).is_equal(Vector3(12.0, 0.0, -8.0))
	assert_float(stamp.rotation_degrees).is_equal(45.0)
	assert_float(stamp.scale).is_equal(1.5)
	# The pool's source stamp must stay untouched — placements get duplicates.
	assert_vector(entry.stamp.world_position).is_equal(Vector3.ZERO)
	assert_float(entry.stamp.scale).is_equal(1.0)

func test_make_stamp_is_null_for_scene_only_entry() -> void:
	var entry: ScatterEntry = ScatterEntry.new()
	entry.scene = PackedScene.new()
	var placement: ScatterPlacement = ScatterPlacement.new()
	placement.entry = entry
	assert_object(placement.make_stamp()).is_null()

func test_zero_weight_entry_is_never_picked() -> void:
	var wanted: ScatterEntry = _stamp_entry()
	var unwanted: ScatterEntry = _stamp_entry()
	unwanted.weight = 0.0
	var config: ScatterConfig = _config(ScatterConfig.Distribution.EVENLY_SCATTERED, 8, 8)
	config.pool = [unwanted, wanted]
	var configs: Array[ScatterConfig] = [config]
	for placement: ScatterPlacement in ScatterPlanner.plan_chunk(configs, Vector2i(2, 2), LEVEL_SEED, CHUNK_RECTANGLE):
		assert_object(placement.entry).is_same(wanted)
	# A pool with only zero-weight entries is an invalid pool.
	config.pool = [unwanted]
	assert_array(ScatterPlanner.plan_chunk(configs, Vector2i(2, 2), LEVEL_SEED, CHUNK_RECTANGLE)).is_empty()

func test_zero_chunk_chance_yields_nothing() -> void:
	var config: ScatterConfig = _config(ScatterConfig.Distribution.EVENLY_SCATTERED, 2, 4)
	config.chunk_chance = 0.0
	var configs: Array[ScatterConfig] = [config]
	for chunk_x: int in range(-3, 4):
		assert_array(ScatterPlanner.plan_chunk(configs, Vector2i(chunk_x, 0), LEVEL_SEED, CHUNK_RECTANGLE)).is_empty()

func test_chunk_chance_gates_some_chunks_and_keeps_bounds() -> void:
	var config: ScatterConfig = _config(ScatterConfig.Distribution.EVENLY_SCATTERED, 2, 4)
	config.chunk_chance = 0.5
	var configs: Array[ScatterConfig] = [config]
	var empty_chunks: int = 0
	var hit_chunks: int = 0
	for chunk_x: int in range(-4, 5):
		for chunk_z: int in range(-4, 5):
			var count: int = ScatterPlanner.plan_chunk(configs, Vector2i(chunk_x, chunk_z), LEVEL_SEED, CHUNK_RECTANGLE).size()
			if count == 0:
				empty_chunks += 1
			else:
				hit_chunks += 1
				assert_int(count).is_between(2, 4)
	assert_int(empty_chunks).is_greater(0)
	assert_int(hit_chunks).is_greater(0)
