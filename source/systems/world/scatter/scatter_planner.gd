class_name ScatterPlanner
extends RefCounted
## Plans deterministic per-chunk placements from a set of [ScatterConfig]s. The
## RNG is seeded purely from (level seed, chunk coordinate, config index), so
## the same inputs always reproduce the same layout — re-entering an evicted
## chunk regenerates it identically.

static func plan_chunk(
	configs: Array[ScatterConfig],
	chunk_coordinate: Vector2i,
	level_seed: int,
	chunk_rectangle: Rect2,
) -> Array[ScatterPlacement]:
	var placements: Array[ScatterPlacement] = []
	for index: int in configs.size():
		var config: ScatterConfig = configs[index]
		if config == null:
			continue
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = chunk_seed(level_seed, chunk_coordinate, index)
		placements.append_array(config.plan(chunk_rectangle, rng))
	return placements

## Deterministic, platform-independent mix (spatial-hash primes) of the level
## seed, chunk coordinate, and config index, so each config decorrelates from
## its neighbours and from other configs on the same chunk.
static func chunk_seed(level_seed: int, chunk_coordinate: Vector2i, config_index: int) -> int:
	return (
		level_seed * 73856093
		^ chunk_coordinate.x * 19349663
		^ chunk_coordinate.y * 83492791
		^ config_index * 50331653
	)
