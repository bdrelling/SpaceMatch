class_name StatPool
extends Resource
## The live value of one stat plus its bounds — the [EntityStats] counterpart of [ResourcePool] (which does the
## same for an [AbilityResource]). One key in a stat block owns its current amount and the floor/ceiling it is
## held within, so a stat's value and its cap never live in two places.

## The stat's live value, kept within [member minimum]..[member maximum].
@export var current: int = 0
## The least this stat may hold. Universally 0 for pools, but authorable per stat.
@export var minimum: int = 0
## The most this stat may hold; 0 means unlimited (mirrors [member ResourcePool.maximum]). Owned by the pool, not
## the [EntityStat] definition, so one entity can cap a stat without touching the shared stat.
@export var maximum: int = 0


## An independent copy — same current/minimum/maximum, no shared reference. Used when a stat block is duplicated
## so two blocks never share a pool instance.
func copy() -> StatPool:
	var pool := StatPool.new()
	pool.current = current
	pool.minimum = minimum
	pool.maximum = maximum
	return pool


## Clamps [param value] to [member minimum]..[member maximum] (no ceiling when maximum is 0) and stores it.
func set_current(value: int) -> void:
	if maximum > 0:
		value = mini(value, maximum)
	current = maxi(value, minimum)


## [member maximum] minus [member current], floored at zero — the room left below the ceiling. Zero when the
## pool is unbounded ([member maximum] of 0).
func missing() -> int:
	if maximum <= 0:
		return 0
	return maxi(maximum - current, 0)
