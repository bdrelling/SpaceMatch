class_name DisableEffect
extends AbilityEffect
## Disable one of the opponent's module cells for [member turns] turns — deactivating the module covering it,
## so it stops counting toward the opponent's stats until it re-enables.

## How many turns the disabled module stays down.
@export var turns: int = 3

static func make(turn_count: int) -> DisableEffect:
	var effect := DisableEffect.new()
	effect.turns = turn_count
	return effect

func describe() -> String:
	return "Disable an opponent module for %d turns" % turns
