class_name AbilityRunner
extends RefCounted
## Runs an [Ability]'s effects in order, awaiting each (an [Effect] may suspend for a player choice). Cost is the
## host's concern — the runner never reads [member Ability.cost]; affordability and spend stay with the game.


## Resolves each of [param ability]'s effects against [param context], in order.
static func run(ability: Ability, context: ResolutionContext) -> void:
	if ability == null:
		return
	for effect in ability.effects:
		if effect != null:
			await effect.resolve(context)
