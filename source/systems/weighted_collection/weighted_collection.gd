class_name WeightedCollection
extends Resource
## A pool you pick from at random in proportion to each entry's weight — the weighted-random
## ("roulette-wheel") pattern, as authored data. Generic and reusable: loot, procedural
## generation, random encounters. [method pick] returns the chosen entry's [member
## WeightedEntry.value]; wrap this in a typed facade (see [LootTable]) when you want a checked
## return type. Shared, immutable — [method pick] only reads, so one collection can back many uses.

@export var entries: Array[WeightedEntry] = []

## Returns the [member WeightedEntry.value] of a random entry chosen in proportion to weight, or
## null when the pool is empty or every entry is invalid (see [method WeightedEntry.is_valid]).
func pick() -> Resource:
	var total: float = 0.0
	for entry: WeightedEntry in entries:
		if entry != null and entry.is_valid():
			total += entry.weight

	if total <= 0.0:
		return null

	var roll: float = randf() * total
	for entry: WeightedEntry in entries:
		if entry == null or not entry.is_valid():
			continue
		roll -= entry.weight
		if roll <= 0.0:
			return entry.value

	return null
