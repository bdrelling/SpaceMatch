class_name AbilityRunner
extends RefCounted
## Runs an [Ability]: pays its [ResourceCost]s from the source's [ResourcePool]s via [ResourceEngine], then resolves
## every effect in order, awaiting each (an [Effect] may suspend for a player choice).


## Pays [param ability]'s costs from [member ResolutionContext.source] and resolves its effects against
## [param context]. Returns false and runs nothing when the source cannot afford it.
static func run(ability: Ability, context: ResolutionContext) -> bool:
	if ability == null:
		return false
	if not ResourceEngine.can_afford(context.source, ability.costs):
		return false
	ResourceEngine.spend(context.source, ability.costs)
	for effect in ability.effects:
		if effect != null:
			await effect.resolve(context)
	return true
