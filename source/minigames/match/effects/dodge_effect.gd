class_name DodgeEffect
extends AbilityEffect
## Dodge (negate) the next attack against the user. Carries no amount — a dodge is all-or-nothing, the case
## that motivated dropping the shared magnitude from [AbilityEffect].

static func make() -> DodgeEffect:
	return DodgeEffect.new()

func describe() -> String:
	return "Dodge the next attack"
