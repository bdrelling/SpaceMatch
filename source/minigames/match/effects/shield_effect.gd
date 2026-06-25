class_name ShieldEffect
extends AbilityEffect
## Grant the user [member amount] shield, which absorbs damage before health.

## How much shield this effect grants.
@export var amount: int = 10

static func make(shield: int) -> ShieldEffect:
	var effect := ShieldEffect.new()
	effect.amount = shield
	return effect

func describe() -> String:
	return "Gain %d shield" % amount
