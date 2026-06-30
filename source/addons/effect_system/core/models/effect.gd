class_name Effect
extends Resource
## One atomic thing that happens: an [Action] resolved against a [Target], gated by [member conditions].
## The action only runs when every condition holds.

@export var target: Target
@export var action: Action
@export var conditions: Array[Condition] = []


## Resolves this effect in [param context]: bails unless every condition holds, selects the targets, then
## runs the action against each. Awaits target selection because a [ChosenTarget] may suspend for a player
## choice; most targets resolve synchronously.
func resolve(context: ResolutionContext) -> void:
	for condition in conditions:
		if not condition.holds(context):
			return
	if target == null or action == null:
		return
	@warning_ignore("redundant_await")
	var targets: Array[Entity] = await target.resolve(context)
	for entity in targets:
		@warning_ignore("redundant_await")
		await action.resolve(context, entity)
