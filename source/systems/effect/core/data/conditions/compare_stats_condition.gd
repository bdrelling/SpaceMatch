class_name CompareStatsCondition
extends Condition
## True when [member target]'s [member stat] compares against [member other]'s [member stat] per
## [member comparison] — "I have more power than my foe", "this ally is lower than that one". Both sides read the
## same stat; the threshold version compares one target to a constant instead.

enum Comparison {
	LESS,
	EQUAL,
	GREATER,
}

@export var target: Target
@export var other: Target
@export var stat: EntityStat
@export var comparison: Comparison = Comparison.GREATER


## Reads [member stat] from the first entity each of [member target] and [member other] resolves to and compares
## them. False when either side resolves to nothing or lacks a stat block.
func holds(context: ResolutionContext) -> bool:
	if target == null or other == null:
		return false
	var targets := target.resolve(context)
	var others := other.resolve(context)
	if targets.is_empty() or others.is_empty():
		return false
	if targets[0].current_stats == null or others[0].current_stats == null:
		return false
	var value := targets[0].current_stats.get_stat(stat)
	var against := others[0].current_stats.get_stat(stat)
	match comparison:
		Comparison.LESS:
			return value < against
		Comparison.EQUAL:
			return value == against
		Comparison.GREATER:
			return value > against
	return false
