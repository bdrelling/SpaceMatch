class_name DamageBuffAction
extends Action
## Raises the target's standing tile-damage bonus by [member amount] for the rest of the encounter (stacks) —
## applies the target-lock status via [method EncounterState.add_status].

## How much to add to the target's tile-damage bonus.
@export var amount: int = 1


static func make(bonus: int) -> DamageBuffAction:
	var action := DamageBuffAction.new()
	action.amount = bonus
	return action


func resolve(context: ResolutionContext, target: Entity) -> void:
	var match_context := context as MatchResolutionContext
	var combatant := target as Combatant
	if match_context == null or match_context.encounter == null or combatant == null:
		return
	match_context.encounter.add_status(combatant, EncounterState.TARGET_LOCK, amount)
	match_context.add_visual({"kind": &"damage_buff", "target": combatant, "amount": amount})


func describe() -> String:
	return "+%d to your tile damage (stacks)" % amount
