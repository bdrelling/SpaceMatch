class_name DamageBuffEffect
extends AbilityEffect
## Raise the user's standing tile-damage bonus by [member amount] for the rest of the encounter (stacks).

## How much to add to the user's tile-damage bonus.
@export var amount: int = 1

static func make(bonus: int) -> DamageBuffEffect:
	var effect := DamageBuffEffect.new()
	effect.amount = bonus
	return effect

func describe() -> String:
	return "+%d to your tile damage (stacks)" % amount
