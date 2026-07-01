class_name AttackAction
extends Action
## Deals [member amount] damage to the target through the encounter's damage pipeline — shield absorbs it first, a
## dodge negates it whole. The match counterpart of a raw [ModifyStatAction]: it routes through
## [method EncounterState.deal_damage] so dodge-consume and shield-sync stay in one place.

## How much damage to deal before the target's shield/dodge apply.
@export var amount: int = 5


static func make(damage: int) -> AttackAction:
	var action := AttackAction.new()
	action.amount = damage
	return action


func resolve(context: ResolutionContext, target: Entity) -> void:
	var match_context := context as MatchResolutionContext
	var combatant := target as Combatant
	if match_context == null or match_context.encounter == null or combatant == null:
		return
	var result: int = match_context.encounter.deal_damage(combatant, amount)
	(
		match_context
		. add_visual(
			{
				"kind": &"attack",
				"source": match_context.source,
				"target": combatant,
				"amount": amount,
				"result": result,
			}
		)
	)


func describe() -> String:
	return "Deal %d damage" % amount
