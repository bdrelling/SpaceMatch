class_name ScatterConfig
extends Resource
## Declares what to scatter across each procedurally generated chunk: a pool of
## entries, how they spread, and how many land per chunk (inclusive bounds).
## Planning is pure — the caller provides the RNG, so the same RNG state always
## yields the same layout.

enum Distribution {
	## Stratified jittered grid: instances land roughly one per grid cell.
	EVENLY_SCATTERED,
	## Instances bunch around a single random center within the chunk.
	CLUSTERED,
	## Uniform random with a minimum separation between instances.
	SPARSE,
}

## How many candidate positions SPARSE tries per instance before accepting the
## last one regardless, so the planned count always stays within bounds.
const SPARSE_PLACEMENT_ATTEMPTS: int = 12

@export var pool: Array[ScatterEntry] = []

@export var distribution: Distribution = Distribution.EVENLY_SCATTERED

## Inclusive per-chunk instance count bounds.
@export_range(0, 64) var min_count: int = 1
@export_range(0, 64) var max_count: int = 1

## Chance that a chunk receives this config at all, rolled before the count.
## Below 1.0 chunks can stay empty regardless of min_count — the count bounds
## then apply only to chunks that pass the gate. Use it to keep features rare
## at world scale (min_count 0 alone can't push the empty-chunk share past
## 1/(max_count+1)).
@export_range(0.0, 1.0, 0.01) var chunk_chance: float = 1.0

## Inclusive per-instance uniform scale bounds.
@export_range(0.1, 10.0, 0.01) var min_scale: float = 1.0
@export_range(0.1, 10.0, 0.01) var max_scale: float = 1.0

## When true each instance gets a random Y-axis rotation.
@export var randomize_rotation: bool = true

## Plans this config's placements for one chunk. Deterministic for a given RNG
## state; consumes the RNG in a fixed order (chunk gate, count, positions, then
## per-instance entry/rotation/scale).
func plan(chunk_rectangle: Rect2, rng: RandomNumberGenerator) -> Array[ScatterPlacement]:
	var valid_entries: Array[ScatterEntry] = []
	for entry: ScatterEntry in pool:
		if entry != null and entry.is_valid():
			valid_entries.append(entry)
	if valid_entries.is_empty():
		return []
	if chunk_chance < 1.0 and rng.randf() >= chunk_chance:
		return []
	var count: int = rng.randi_range(min_count, maxi(max_count, min_count))
	var points: Array[Vector2] = _plan_points(count, chunk_rectangle, rng)
	var placements: Array[ScatterPlacement] = []
	for point: Vector2 in points:
		var placement: ScatterPlacement = ScatterPlacement.new()
		placement.entry = _pick_entry(valid_entries, rng)
		placement.position = Vector3(point.x, 0.0, point.y)
		placement.rotation_degrees = rng.randf_range(-180.0, 180.0) if randomize_rotation else 0.0
		placement.scale = rng.randf_range(min_scale, maxf(max_scale, min_scale))
		placements.append(placement)
	return placements

## Idempotent: pre-loads every pool stamp's images so worker threads only ever
## duplicate stamps whose images are already resident.
func ensure_stamp_images_loaded() -> void:
	for entry: ScatterEntry in pool:
		if entry != null and entry.stamp != null:
			entry.stamp.ensure_images_loaded()

## Stable description of everything that changes a planned layout — fold into a
## level's terrain generation key so baked chunk caches invalidate when a
## config changes. Stamp/scene resources are keyed by path: parameter edits
## inside an existing resource file are not detected.
func cache_key() -> String:
	var parts: Array[String] = ["%d|%d|%d|%.3f|%.3f|%s|%.3f" % [
		distribution,
		min_count,
		max_count,
		min_scale,
		max_scale,
		randomize_rotation,
		chunk_chance,
	]]
	for entry: ScatterEntry in pool:
		if entry == null:
			parts.append("null")
			continue
		parts.append("%s:%s:%.3f" % [
			entry.stamp.resource_path if entry.stamp != null else "",
			entry.scene.resource_path if entry.scene != null else "",
			entry.weight,
		])
	return "|".join(parts)

## Weighted random pick; entries arriving here are valid, so weights are > 0.
static func _pick_entry(entries: Array[ScatterEntry], rng: RandomNumberGenerator) -> ScatterEntry:
	var total_weight: float = 0.0
	for entry: ScatterEntry in entries:
		total_weight += entry.weight
	var roll: float = rng.randf() * total_weight
	for entry: ScatterEntry in entries:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return entries[entries.size() - 1]

func _plan_points(count: int, chunk_rectangle: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	match distribution:
		Distribution.CLUSTERED:
			return _plan_clustered_points(count, chunk_rectangle, rng)
		Distribution.SPARSE:
			return _plan_sparse_points(count, chunk_rectangle, rng)
		_:
			return _plan_even_points(count, chunk_rectangle, rng)

func _plan_even_points(count: int, chunk_rectangle: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if count <= 0:
		return points
	var grid: int = ceili(sqrt(float(count)))
	var cell_size: Vector2 = chunk_rectangle.size / float(grid)
	var cells: Array[int] = []
	for cell: int in range(grid * grid):
		cells.append(cell)
	# Fisher-Yates with the provided RNG — Array.shuffle() would consume the
	# global RNG and break determinism.
	for index: int in range(cells.size() - 1, 0, -1):
		var swap: int = rng.randi_range(0, index)
		var held: int = cells[index]
		cells[index] = cells[swap]
		cells[swap] = held
	for index: int in range(count):
		var cell: int = cells[index]
		var column: int = cell % grid
		var row: int = floori(float(cell) / float(grid))
		points.append(chunk_rectangle.position + Vector2(
			(float(column) + rng.randf()) * cell_size.x,
			(float(row) + rng.randf()) * cell_size.y,
		))
	return points

func _plan_clustered_points(count: int, chunk_rectangle: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if count <= 0:
		return points
	var center: Vector2 = chunk_rectangle.position + Vector2(
		rng.randf_range(0.2, 0.8) * chunk_rectangle.size.x,
		rng.randf_range(0.2, 0.8) * chunk_rectangle.size.y,
	)
	var deviation: float = minf(chunk_rectangle.size.x, chunk_rectangle.size.y) * 0.12
	for index: int in range(count):
		points.append(_clamp_to_rectangle(center + Vector2(
			rng.randfn(0.0, deviation),
			rng.randfn(0.0, deviation),
		), chunk_rectangle))
	return points

func _plan_sparse_points(count: int, chunk_rectangle: Rect2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if count <= 0:
		return points
	var separation: float = minf(chunk_rectangle.size.x, chunk_rectangle.size.y) / (2.0 * sqrt(float(count)))
	for index: int in range(count):
		var candidate: Vector2 = Vector2.ZERO
		for attempt: int in range(SPARSE_PLACEMENT_ATTEMPTS):
			candidate = chunk_rectangle.position + Vector2(
				rng.randf() * chunk_rectangle.size.x,
				rng.randf() * chunk_rectangle.size.y,
			)
			var separated: bool = true
			for point: Vector2 in points:
				if point.distance_to(candidate) < separation:
					separated = false
					break
			if separated:
				break
		points.append(candidate)
	return points

static func _clamp_to_rectangle(point: Vector2, rectangle: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, rectangle.position.x, rectangle.position.x + rectangle.size.x),
		clampf(point.y, rectangle.position.y, rectangle.position.y + rectangle.size.y),
	)
