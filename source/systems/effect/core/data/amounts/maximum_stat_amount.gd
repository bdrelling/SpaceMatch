class_name MaximumStatAmount
extends Amount
## Reads the ceiling of the source entity's [member stat] (its [member StatPool.maximum]); zero when the stat is
## unbounded.

@export var stat: EntityStat


## Reads [member stat]'s maximum from the source's current stats. Zero when there is no source or stat block.
func evaluate(context: ResolutionContext) -> int:
	if context.source == null or context.source.current_stats == null:
		return 0
	return context.source.current_stats.get_maximum(stat)
