class_name DrainAction
extends Action
## Drains [member amount] from each of the target's stat resource pools via
## [method EncounterState.drain_stat_resources] — the Siphon effect.

## How much to drain from each of the target's stat resources.
@export var amount: int = 2


static func make(drain: int) -> DrainAction:
	var action := DrainAction.new()
	action.amount = drain
	return action


func resolve(context: ResolutionContext, target: Entity) -> void:
	var match_context := context as MatchResolutionContext
	var combatant := target as Combatant
	if match_context == null or match_context.encounter == null or combatant == null:
		return
	match_context.encounter.drain_stat_resources(combatant, amount)
	match_context.add_visual({"kind": &"drain", "target": combatant})


func describe() -> String:
	return "Drain %d of each of the opponent's resources" % amount
