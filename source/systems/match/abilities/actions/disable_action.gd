class_name DisableAction
extends Action
## Disables one of the target's modules for [member turns] turns via [method EncounterState.disable_random_module]
## — board manipulation kept on the game side (the effect engine is entity-centric, not board-aware), picked from
## the context's seeded RNG so it stays reproducible.

## How many turns the disabled module stays down.
@export var turns: int = 3


static func make(turn_count: int) -> DisableAction:
	var action := DisableAction.new()
	action.turns = turn_count
	return action


func resolve(context: ResolutionContext, target: Entity) -> void:
	var match_context := context as MatchResolutionContext
	var combatant := target as Combatant
	if match_context == null or match_context.encounter == null or combatant == null:
		return
	match_context.encounter.disable_random_module(combatant, turns, match_context.rng)
	match_context.add_visual({"kind": &"disable", "target": combatant})


func describe() -> String:
	return "Disable an opponent module for %d turns" % turns
