extends GdUnitTestSuite
## Functional and timing coverage for [ItemSpawner] piles: settled items freeze,
## wake() is radius-local, and physics cost stays sane up to 10k bodies (DC-167).

## Simulated frames per measured timing window.
const _WINDOW_FRAMES: int = 120
## Cap on frames waited for a pile to settle (60s simulated).
const _SETTLE_FRAME_CAP: int = 3600
## Generous per-frame wall budget (ms) for a radius dig — the design's core promise:
## digging at a pile costs the same no matter how big the pile is. Headless frame
## floor is ~7ms; measured digs sit on it.
const _DIG_BUDGET_MS: float = 25.0
## Per-frame wall budget (ms) for a fully-awake cascade, asserted only up to
## [constant _CASCADE_ASSERT_MAX] items — beyond that the design never wakes
## everything at once, so larger sizes are recorded as information.
const _CASCADE_BUDGET_MS: float = 60.0
const _CASCADE_ASSERT_MAX: int = 3000

var _timing_lines: Array[String] = []

func _blueprint(item_id: int, item_radius: float, height: float) -> ItemBlueprint:
	var mesh := CylinderMesh.new()
	mesh.top_radius = item_radius
	mesh.bottom_radius = item_radius
	mesh.height = height
	var blueprint := ItemBlueprint.new()
	blueprint.id = item_id
	blueprint.name = "test_cylinder_%d" % item_id
	blueprint.world_mesh = mesh
	return blueprint

func _blueprints() -> Array[ItemBlueprint]:
	return [
		_blueprint(9001, 0.18, 0.4),
		_blueprint(9002, 0.26, 0.55),
		_blueprint(9003, 0.34, 0.72),
	]

func _build_pile(count: int) -> Node3D:
	var root := Node3D.new()
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	ground_shape.shape = box
	ground.add_child(ground_shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	root.add_child(ground)
	var spawner: ItemSpawner = ItemSpawner.create(_blueprints(), count)
	spawner.rng_seed = 167
	spawner.radius = 2.5 + count / 1000.0
	root.add_child(spawner)
	return root

func _settle(runner: GdUnitSceneRunner, spawner: ItemSpawner) -> int:
	var frames: int = 0
	while spawner.frozen_count() < spawner.items.size() and frames < _SETTLE_FRAME_CAP:
		await runner.simulate_frames(60)
		frames += 60
	return frames

## Wall ms per simulated frame across one window.
func _time_window(runner: GdUnitSceneRunner) -> float:
	var start: int = Time.get_ticks_usec()
	await runner.simulate_frames(_WINDOW_FRAMES)
	return (Time.get_ticks_usec() - start) / 1000.0 / _WINDOW_FRAMES

func test_settled_items_freeze_and_wake_is_radius_local() -> void:
	var root: Node3D = _build_pile(100)
	var runner: GdUnitSceneRunner = scene_runner(root)
	var spawner: ItemSpawner = root.get_node("ItemSpawner")
	await _settle(runner, spawner)
	assert_int(spawner.frozen_count()).is_equal(spawner.items.size())

	# Wake a small radius at the pile center: nearby items unfreeze, the rim stays frozen.
	spawner.wake(spawner.global_position, 1.0)
	var awake: int = spawner.items.size() - spawner.frozen_count()
	assert_int(awake).is_greater(0)
	assert_int(awake).is_less(spawner.items.size())
	for item: Item in spawner.items:
		if item.global_position.distance_to(spawner.global_position) > 1.0 + 0.5:
			assert_bool(item.freeze).is_true()
	root.queue_free()

func test_pile_timing(count: int, test_parameters := [[1000], [2000], [3000], [5000], [10000]]) -> void:
	var root: Node3D = _build_pile(count)
	var runner: GdUnitSceneRunner = scene_runner(root)
	var spawner: ItemSpawner = root.get_node("ItemSpawner")

	var settle_frames: int = await _settle(runner, spawner)
	var frozen_fraction: float = float(spawner.frozen_count()) / spawner.items.size()
	var rest_ms: float = await _time_window(runner)

	spawner.wake(spawner.global_position, 2.0, 4.0)
	var dig_ms: float = await _time_window(runner)

	spawner.wake_all(1.0)
	var cascade_ms: float = await _time_window(runner)

	var line: String = "| %d | %d | %.0f%% | %.2fms | %.2fms | %.2fms |" % [
		count, settle_frames, frozen_fraction * 100.0, rest_ms, dig_ms, cascade_ms]
	_timing_lines.append(line)
	print("ItemSpawner timing: items=%d settle_frames=%d frozen=%.0f%% rest=%.2fms/frame dig=%.2fms/frame cascade=%.2fms/frame" % [
		count, settle_frames, frozen_fraction * 100.0, rest_ms, dig_ms, cascade_ms])

	# Freeze-on-sleep must drain the pile, and a radius dig must stay cheap no
	# matter the pile size — that's the whole point of the freeze/wake design.
	assert_float(frozen_fraction).is_greater(0.9)
	assert_float(dig_ms).is_less(_DIG_BUDGET_MS)
	# The all-awake worst case only has to behave at sizes the game would ever
	# wake at once; larger sizes are recorded for the record, not asserted.
	if count <= _CASCADE_ASSERT_MAX:
		assert_float(cascade_ms).is_less(_CASCADE_BUDGET_MS)
	root.queue_free()

func after() -> void:
	if _timing_lines.is_empty():
		return
	var directory: String = Playtests.subdirectory("dc-167")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("test_timings.md"), FileAccess.WRITE)
	if not file:
		return
	file.store_string("# ItemSpawner pile timings (headless, wall ms/frame)\n\n")
	file.store_string("| items | settle frames | frozen | rest | dig (2m) | cascade |\n|---|---|---|---|---|---|\n")
	for line: String in _timing_lines:
		file.store_string(line + "\n")
