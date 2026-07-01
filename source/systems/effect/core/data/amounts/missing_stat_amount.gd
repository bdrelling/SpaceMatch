class_name MissingStatAmount
extends Amount
## How far the source's [member stat] sits below its ceiling — the missing portion of its pool. Scales a change
## by absence: "damage equal to your missing hull", "heal more the lower you are". Never negative; zero when the
## stat is unbounded.

## The stat whose shortfall is measured (e.g. the health [EntityStat]). Its [StatPool] carries both the current
## value and the ceiling, so no companion max stat is needed.
@export var stat: EntityStat


## Returns the stat's [method StatPool.missing] on the source. Zero when there is no source, stat block, or pool.
func evaluate(context: ResolutionContext) -> int:
	if context.source == null or context.source.current_stats == null:
		return 0
	var pool := context.source.current_stats.pool_for(stat)
	return pool.missing() if pool != null else 0
