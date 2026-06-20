class_name ItemSpawner
extends Node3D
## Spawns loose physical [Item]s that drop and settle into a pile around this node.
## Settled items freeze solid (zero simulation cost) until [method wake] disturbs them,
## so arbitrarily large piles only simulate where something is digging.

const SCENE_PATH := "res://systems/inventory/item_spawner/item_spawner.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## Max bodies the force-settle backstop freezes per physics frame — freezing
## thousands in one pass stalls (or aborts) the physics server.
const _FORCE_FREEZES_PER_FRAME: int = 200

## Items per square meter in each spawn layer — keeps piles wide and shallow
## instead of stacking into a drop tower as counts grow.
const _LAYER_DENSITY: float = 2.0

## Emitted once every spawned item has settled and frozen.
signal settled

## Blueprints to draw from, picked uniformly per item.
@export var blueprints: Array[ItemBlueprint] = []
@export_range(1, 10000) var count: int = 100
## Radius of the pile's footprint around this node.
@export var radius: float = 2.5
@export var spawn_on_ready: bool = true
## Spawned items collide with each other — required for actual piling. Plain items
## ignore each other (PROPS isn't in the item mask), so piles opt in here.
@export var items_collide: bool = true
## Freeze each item once it has been calm for [member settle_delay]; [method wake]
## unfreezes locally. Spawner-driven rather than Jolt sleep because dense piles
## micro-jitter below visible motion but above the sleep threshold forever.
@export var freeze_when_settled: bool = true
## Speed (m/s) below which an item counts as calm.
@export var settle_speed: float = 0.15
## Seconds an item must stay calm before it freezes.
@export var settle_delay: float = 0.5
## Deadline after spawn at which still-unfrozen items freeze outright — a backstop
## for the pile's initial settle only, never after a wake. Dense piles trap items
## between frozen neighbors where depenetration jitter keeps them above
## [member settle_speed] forever.
@export var force_settle_after: float = 20.0
## Seed for deterministic spawns; 0 randomizes.
@export var rng_seed: int = 0

## Items this spawner created, in spawn order.
var items: Array[Item] = []

## Per-item seconds spent calm, aligned with [member items].
var _calm_times: PackedFloat32Array = []
var _frozen_count: int = 0
var _pile_age: float = 0.0
## True once the whole pile has frozen at least once — disarms the force backstop.
var _settled_once: bool = false

func _ready() -> void:
	if spawn_on_ready:
		spawn()

## Spawns [member count] items layered above this node so they drop into a pile.
func spawn() -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	var items_per_layer: int = maxi(1, int(PI * radius * radius * _LAYER_DENSITY))
	for i in count:
		var item: Item = Item.create(blueprints[rng.randi() % blueprints.size()])
		if items_collide:
			item.collision_mask |= CollisionLayer.PROPS
		var angle: float = rng.randf() * TAU
		var distance: float = sqrt(rng.randf()) * radius
		var layer: int = i / items_per_layer
		item.position = position + Vector3(
			cos(angle) * distance,
			0.6 + layer * 0.5 + rng.randf() * 0.3,
			sin(angle) * distance)
		item.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		add_sibling.call_deferred(item)
		items.append(item)
		_calm_times.append(0.0)

## Frees every item this spawner created.
func clear() -> void:
	for item: Item in items:
		if is_instance_valid(item):
			item.queue_free()
	items.clear()
	_calm_times.clear()
	_frozen_count = 0

## Unfreezes every item within [param wake_radius] of [param point] and optionally
## yanks it toward a spot just above the point — the disturbance half of the
## freeze-when-settled cycle (a dig, an explosion, a grab).
func wake(point: Vector3, wake_radius: float, pull_strength: float = 0.0) -> void:
	var target: Vector3 = point + Vector3.UP * 2.0
	for i in items.size():
		var item: Item = items[i]
		if not is_instance_valid(item):
			continue
		if item.global_position.distance_to(point) > wake_radius:
			continue
		_unfreeze(i)
		if pull_strength > 0.0:
			item.apply_central_impulse((target - item.global_position).normalized() * pull_strength)

## Unfreezes and nudges every item at once — the worst-case wake cascade.
func wake_all(impulse_strength: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	for i in items.size():
		var item: Item = items[i]
		if not is_instance_valid(item):
			continue
		_unfreeze(i)
		if impulse_strength > 0.0:
			item.apply_central_impulse(Vector3(
				rng.randf_range(-0.5, 0.5),
				rng.randf_range(0.5, 1.0),
				rng.randf_range(-0.5, 0.5)) * impulse_strength)

## How many items are currently frozen solid.
func frozen_count() -> int:
	return _frozen_count

func _physics_process(delta: float) -> void:
	if not freeze_when_settled or _frozen_count == items.size():
		return
	var force_budget: int = 0
	if not _settled_once:
		_pile_age += delta
		if _pile_age >= force_settle_after:
			force_budget = _FORCE_FREEZES_PER_FRAME
	var speed_squared: float = settle_speed * settle_speed
	for i in items.size():
		var item: Item = items[i]
		if not is_instance_valid(item) or item.freeze:
			continue
		var forced: bool = force_budget > 0
		if not forced and item.linear_velocity.length_squared() > speed_squared:
			_calm_times[i] = 0.0
			continue
		_calm_times[i] += delta
		if forced or _calm_times[i] >= settle_delay:
			if forced:
				force_budget -= 1
			item.freeze = true
			_frozen_count += 1
			if _frozen_count == items.size():
				_settled_once = true
				settled.emit()

func _unfreeze(index: int) -> void:
	var item: Item = items[index]
	if item.freeze:
		_frozen_count -= 1
		item.freeze = false
	_calm_times[index] = 0.0
	item.sleeping = false

static func create(_blueprints: Array[ItemBlueprint], _count: int) -> ItemSpawner:
	var spawner: ItemSpawner = SCENE.instantiate()
	spawner.blueprints = _blueprints
	spawner.count = _count
	return spawner
