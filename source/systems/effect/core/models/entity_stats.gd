class_name EntityStats
extends Resource
## A collection of [StatPool]s keyed by [EntityStat]. Holds whatever stats it is given — no typed subclass
## required — so the same block works for any entity; stats match by key ([member EntityStat.name]), the way a
## [ResourcePool] matches an [AbilityResource]. Games may layer typed-field sugar over it (see [StarshipStats]),
## but the dictionary is the storage and the math lives here. Keys are stat names ([StringName]); values are
## [StatPool]s (authored as sub-resources in data), so one key owns both a stat's live value and its bounds.
@export var values: Dictionary = {}


func _init() -> void:
	# A fresh dict per instance so two blocks never share one (an exported default can be shared). A .tres load
	# overwrites this right after with its authored values.
	values = {}


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


## [param stat]'s ceiling (0 = unbounded); zero when this block holds none.
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


## The current value under raw stat-name [param key] (zero when absent). The seam typed-field sugar reads through.
func get_named(key: StringName) -> int:
	var pool: StatPool = values.get(key, null)
	return pool.current if pool != null else 0


## Sets the current value under raw stat-name [param key], clamped to its pool bounds.
func set_named(key: StringName, value: int) -> void:
	_pool_named(key).set_current(value)


## The ceiling under raw stat-name [param key] (0 = unbounded; zero when absent). The seam a cap-carrying stat's
## typed sugar (e.g. [member StarshipStats.health]) reads through.
func get_maximum_named(key: StringName) -> int:
	var pool: StatPool = values.get(key, null)
	return pool.maximum if pool != null else 0


## Sets the ceiling under raw stat-name [param key], then re-clamps its current value under the new bound.
func set_maximum_named(key: StringName, value: int) -> void:
	var pool := _pool_named(key)
	pool.maximum = value
	pool.set_current(pool.current)


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
