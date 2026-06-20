class_name WeightedEntry
extends Resource
## One entry in a [WeightedCollection]: a payload [Resource] and its relative weight. Generic on
## purpose — the payload is any [Resource] (an [ItemBlueprint], a procgen def, …), and a typed
## facade like [LootTable] casts it back at its boundary. Higher weight = a bigger share of the
## roll; weights are relative and needn't sum to anything.

@export var value: Resource
@export var weight: float = 1.0

## Rollable only with a positive weight and an actual payload.
func is_valid() -> bool:
	return weight > 0.0 and value != null
