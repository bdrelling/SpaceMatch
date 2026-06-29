class_name MissingStatAmount
extends Amount
## How far the source's [member stat] sits below its ceiling [member maximum_stat] — the missing portion of a
## pool. Scales a change by absence: "damage equal to your missing hull", "heal more the lower you are". Never
## negative.

## The current stat read from the source (e.g. [code]&"health"[/code]).
@export var stat: StringName
## The ceiling the shortfall is measured against (e.g. [code]&"max_health"[/code]).
@export var maximum_stat: StringName


## Returns [member maximum_stat] minus [member stat] on the source, floored at zero. Zero when there is no source
## or stat block.
func evaluate(context: ResolutionContext) -> int:
	if context.source == null or context.source.current_stats == null:
		return 0
	var current := int(context.source.current_stats.get_stat(stat))
	var ceiling := int(context.source.current_stats.get_stat(maximum_stat))
	return maxi(ceiling - current, 0)
