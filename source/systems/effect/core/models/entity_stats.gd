class_name EntityStats
extends Resource
## A collection of [StatPool]s keyed by [EntityStat]. Holds whatever stats it is given — no typed subclass
## required — so the same block works for any entity; stats match by key ([member EntityStat.name]), the way a
## [ResourcePool] matches an [AbilityResource]. Games may layer typed-field sugar over it (see [StarshipStats]),
## but the dictionary is the storage and the math lives here. Keys are stat names ([StringName]); values are
## [StatPool]s, so one key owns both a stat's live value and its bounds.

# Backing storage for [member values]; the export normalizes assignment so authoring stays simple.
var _values: Dictionary = {}

## A [StatPool] per stat key. Authoring may use a bare int as shorthand for a pool whose current is that int
## (bounds zero, i.e. unbounded); it is lifted into a [StatPool] on load and any assigned pool is copied, so the
## runtime is uniformly independent pools.
@export var values: Dictionary:
	get:
		return _values
	set(incoming):
		var source_values: Dictionary = incoming
		_values = {}
		for key: StringName in source_values:
			_values[key] = _as_pool(source_values[key])


func _init() -> void:
	# A fresh dict per instance so two blocks never share one (an exported default can be shared). A .tres load
	# overwrites this right after with its authored values.
	_values = {}


## The [StatPool] for [param stat], or null when this block holds none.
func pool_for(stat: EntityStat) -> StatPool:
	if stat == null:
		return null
	var pool: StatPool = values.get(stat.name, null)
	return pool


## This block's current value for [param stat] (zero when it holds none).
func get_stat(stat: EntityStat) -> int:
	var pool := pool_for(stat)
	return pool.current if pool != null else 0


## Sets [param stat]'s current value, clamped to its pool's [member StatPool.minimum]..[member StatPool.maximum].
func set_stat(stat: EntityStat, value: int) -> void:
	if stat == null:
		return
	_pool(stat).set_current(value)


## [param stat]'s ceiling (0 = unlimited); zero when this block holds none.
func get_maximum(stat: EntityStat) -> int:
	var pool := pool_for(stat)
	return pool.maximum if pool != null else 0


## Sets [param stat]'s ceiling, then re-clamps its current value under the new bound.
func set_maximum(stat: EntityStat, value: int) -> void:
	if stat == null:
		return
	var pool := _pool(stat)
	pool.maximum = value
	pool.set_current(pool.current)


## [param stat]'s floor; zero when this block holds none.
func get_minimum(stat: EntityStat) -> int:
	var pool := pool_for(stat)
	return pool.minimum if pool != null else 0


## Sets [param stat]'s floor, then re-clamps its current value above the new bound.
func set_minimum(stat: EntityStat, value: int) -> void:
	if stat == null:
		return
	var pool := _pool(stat)
	pool.minimum = value
	pool.set_current(pool.current)


## The current value stored under raw stat-name [param key] (zero when absent). The seam typed-field sugar
## (see [StarshipStats]) reads through.
func get_named(key: StringName) -> int:
	var pool: StatPool = values.get(key, null)
	return pool.current if pool != null else 0


## Sets the current value under raw stat-name [param key], clamped to its pool bounds. The seam typed-field sugar
## writes through.
func set_named(key: StringName, value: int) -> void:
	_pool_named(key).set_current(value)


## Sums [param other]'s pools into this block, key by key: current, minimum, and maximum each add (raw — a stat
## contribution may be negative, e.g. a module's −1 energy). Pools are copied, never shared, so a summed block
## (e.g. base + loadout) is independent of its sources.
func add(other: EntityStats) -> void:
	if other == null:
		return
	for key: StringName in other.values:
		var addend: StatPool = other.values[key]
		if addend == null:
			continue
		var pool: StatPool = values.get(key, null)
		if pool == null:
			values[key] = addend.copy()
			continue
		pool.current += addend.current
		pool.minimum += addend.minimum
		pool.maximum += addend.maximum


## The keys this block holds a value for.
func stat_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: StringName in values:
		names.append(key)
	return names


## Lifts authored values into [StatPool]s: a bare int becomes a pool whose current is that int; an existing pool
## is copied so instances never share one.
static func _as_pool(value: Variant) -> StatPool:
	if value is StatPool:
		var existing: StatPool = value
		return existing.copy()
	var pool := StatPool.new()
	var number: float = value
	pool.current = int(number)
	return pool


## Finds [param stat]'s pool, creating an empty (unbounded) one when absent.
func _pool(stat: EntityStat) -> StatPool:
	return _pool_named(stat.name)


# Finds the pool under raw [param key], creating an empty (unbounded) one when absent.
func _pool_named(key: StringName) -> StatPool:
	var pool: StatPool = values.get(key, null)
	if pool == null:
		pool = StatPool.new()
		values[key] = pool
	return pool
