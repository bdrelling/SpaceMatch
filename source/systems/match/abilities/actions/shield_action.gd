class_name ShieldAction
extends Action
## Grants the target [member amount] shield via [method EncounterState.add_shield] — the shield pool the damage
## pipeline's AbsorbStep soaks before health.

## How much shield to grant.
@export var amount: int = 10


static func make(shield: int) -> ShieldAction:
	var action := ShieldAction.new()
	action.amount = shield
	return action


func resolve(context: ResolutionContext, target: Entity) -> void:
	var match_context := context as MatchResolutionContext
	var combatant := target as Combatant
	if match_context == null or match_context.encounter == null or combatant == null:
		return
	match_context.encounter.add_shield(combatant, amount)
	match_context.add_visual({"kind": &"shield", "target": combatant, "amount": amount})


func describe() -> String:
	return "Gain %d shield" % amount
