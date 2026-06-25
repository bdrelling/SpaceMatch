class_name DrainEffect
extends AbilityEffect
## Remove [member amount] from each of the opponent's matched stat resources.

## How much to drain from each of the opponent's resources.
@export var amount: int = 2

static func make(drain: int) -> DrainEffect:
	var effect := DrainEffect.new()
	effect.amount = drain
	return effect

func describe() -> String:
	return "Drain %d of each of the opponent's resources" % amount
