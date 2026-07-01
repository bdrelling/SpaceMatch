class_name ModifyStatAction
extends Action
## Applies a change to one named [member stat] on the target. This is the single value-changing action:
## damage is [member subtracts] = true on a vitality stat with [member tag] [code]&"damage"[/code]; healing
## and resource gain are [member subtracts] = false. The magnitude runs through the [ModificationPipeline]
## first, so a target's statuses can amplify, mitigate, absorb, or clamp it — for any [member tag], not just
## damage.

## Hard ceiling on reaction depth, so reflections of reflections terminate instead of looping forever.
const MAX_CASCADE_DEPTH := 8

## The stat to change (health, a shield pool, a resource, ...).
@export var stat: EntityStat
## The magnitude of the change before transforms. A non-negative quantity; direction is [member subtracts].
@export var amount: Amount
## Names this change so transforms and hooks can scope themselves ("damage", "heal", ...).
@export var tag: StringName
## When true the magnitude is subtracted from the stat (damage, paying a cost); when false it is added
## (healing, resource gain).
@export var subtracts: bool = false
## Extra floor the stat lands on after the change, on top of its pool's own [member StatPool.minimum]. Defaults
## to 0 (stats that model pools never go negative).
@export var minimum: int = 0


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
	modification.depth = (context.modification.depth + 1) if context.modification != null else 0
	var magnitude := ModificationPipeline.resolve(modification, context)
	modification.amount = magnitude
	context.modification = modification
	var current := target.current_stats.get_stat(stat)
	var result := (current - magnitude) if subtracts else (current + magnitude)
	result = maxi(result, minimum)
	# set_stat clamps to the stat's own pool bounds, so its maximum is the healing ceiling.
	target.current_stats.set_stat(stat, result)
	# Let statuses react to the change: the actor's outgoing reactions, then the subject's. Depth-capped so a
	# reflection of a reflection terminates. Entities for the reactions come from the context, not the hook.
	if magnitude > 0 and modification.depth < MAX_CASCADE_DEPTH:
		var outgoing := OutgoingActionHook.new()
		outgoing.tag = tag
		await TriggerEngine.fire_hook(context.source, outgoing, context.reaction(context.source, context.instigator, modification))
		var landed := StatModifiedHook.new()
		landed.tag = tag
		await TriggerEngine.fire_hook(target, landed, context.reaction(target, context.source, modification))
