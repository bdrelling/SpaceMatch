class_name AttackEffect
extends AbilityEffect
## Deal [member amount] damage to the opponent — shield absorbs it first, then health. (Named to avoid the
## grid engine's own [code]DamageEffect[/code], which is a board effect, not a combat one.)

## How much damage this effect deals.
@export var amount: int = 5

static func make(damage: int) -> AttackEffect:
	var effect := AttackEffect.new()
	effect.amount = damage
	return effect

func describe() -> String:
	return "Deal %d damage" % amount
