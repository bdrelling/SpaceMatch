class_name ModifyStatAction
extends Action
## Applies a change to one named [member stat] on the target. This is the single value-changing action:
## damage is [member subtracts] = true on a vitality stat with [member tag] [code]&"damage"[/code]; healing
## and resource gain are [member subtracts] = false. The magnitude runs through the [ModificationPipeline]
## first, so a target's statuses can amplify, mitigate, absorb, or clamp it — for any [member tag], not just
## damage.

## The stat to change (health, a shield pool, a resource, ...).
@export var stat: StringName
## The magnitude of the change before transforms. A non-negative quantity; direction is [member subtracts].
@export var amount: Amount
## Names this change so transforms and hooks can scope themselves ("damage", "heal", ...).
@export var tag: StringName
## When true the magnitude is subtracted from the stat (damage, paying a cost); when false it is added
## (healing, resource gain).
@export var subtracts: bool = false
## Floor the stat lands on after the change. Defaults to 0 (stats that model pools never go negative).
@export var minimum: int = 0
## Optional ceiling, read from another stat (e.g. [code]&"max_health"[/code] so healing cannot overfill).
## Empty means no ceiling.
@export var maximum_stat: StringName = &""


## Builds a [Modification], runs it through the [ModificationPipeline], then writes the clamped result to the
## target's [member stat].
func resolve(context: ResolutionContext, target: Entity) -> void:
	if target == null or target.current_stats == null:
		return
	var modification := Modification.new()
	modification.source = context.source
	modification.target = target
	modification.stat = stat
	modification.amount = amount.evaluate(context) if amount != null else 0
	modification.tag = tag
	var magnitude := ModificationPipeline.resolve(modification, context)
	var current := int(target.current_stats.get_stat(stat))
	var result := (current - magnitude) if subtracts else (current + magnitude)
	if maximum_stat != &"" and maximum_stat in target.current_stats.stat_names():
		result = mini(result, int(target.current_stats.get_stat(maximum_stat)))
	result = maxi(result, minimum)
	target.current_stats.set_stat(stat, result)
