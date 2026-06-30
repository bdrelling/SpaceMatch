class_name RandomAmount
extends Amount
## A value rolled between [member minimum] and [member maximum] (inclusive). Reads the context's seeded RNG, so
## the same seed always rolls the same value — variance that stays deterministic and replayable.

@export var minimum: int = 0
@export var maximum: int = 0


## Rolls an integer in [member minimum]..[member maximum] from the context RNG. The bounds are ordered first so
## an authoring slip (maximum below minimum) still yields a valid roll.
func evaluate(context: ResolutionContext) -> int:
	var low := mini(minimum, maximum)
	var high := maxi(minimum, maximum)
	return context.rng.randi_range(low, high)
