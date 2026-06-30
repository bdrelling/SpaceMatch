class_name ChanceCondition
extends Condition
## Holds on a probabilistic roll — a [member chance] in 0..1 that an effect fires. Reads the context's seeded
## RNG, so the same seed always yields the same outcome. A chance of 1 always holds, 0 never does.

## Probability the gate opens, from 0 (never) to 1 (always).
@export_range(0.0, 1.0) var chance: float = 1.0


## Rolls the context RNG and holds when the roll lands under [member chance].
func holds(context: ResolutionContext) -> bool:
	return context.rng.randf() < chance
